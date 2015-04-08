require 'ostruct'

require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationBuilder.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'AutomationRunner.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'DeviceInstaller.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'BuildArtifacts.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'HostUtils.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), 'XcodeUtils.rb')


class IlluminatorFramework

  def self.willClean options
    return true if options.illuminator.clean.derived
    return true if options.illuminator.clean.artifacts
    return true if options.illuminator.clean.xcode
    return false
  end

  def self.cleanCountdown
    countdown = "3....2....1...."
    print "Cleaning in ".yellow
    countdown.split("").each do |c|
      print c.yellow
      sleep(0.2)
    end
    print "\n"
  end

  def self.validateOptions(options)

    # fail quickly if simulator device and/or version are wrong
    if options.illuminator.hardwareID.nil?
      device = options.simulator.device
      version = options.simulator.version
      devices = XcodeUtils.instance.getSimulatorDeviceTypes()
      versions = XcodeUtils.instance.getSimulatorRuntimes()

      noproblems = true

      unless devices.include? device
        puts "Specified simulator device '#{device}' does not appear to be installed -  options are #{devices}".red
        noproblems = false
      end

      unless versions.include? version
        puts "Specified simulator iOS version '#{version}' does not appear to be installed -  options are #{versions}".red
        noproblems = false
      end
    end

    return noproblems
  end

  ################################################################################################
  # MAIN ENTRY POINT
  ################################################################################################
  def self.runWithOptions(originalOptions, workspace)

    options = IlluminatorOptions.new(originalOptions.to_h) # immediately create a copy of the options, because we may mangle them

    hardwareID = options.illuminator.hardwareID
    appName    = options.xcode.appName

    # validate some inputs
    return false unless self.validateOptions(options)

    # do any initial cleaning
    cleanDirs = {
      HostUtils.realpath("~/Library/Developer/Xcode/DerivedData") => options.illuminator.clean.derived,
      BuildArtifacts.instance.root(true)                          => options.illuminator.clean.artifacts,
    }
    self.cleanCountdown if self.willClean(options) and (not options.illuminator.clean.noDelay)
    cleanDirs.each do |d, doClean|
      dir = HostUtils.realpath d
      if doClean
        puts "Illuminator cleanup: removing #{dir}"
        FileUtils.rmtree dir
      end
    end

    # Initialize builder and build
    if (not options.instruments.appLocation.nil?)
      puts "Skipping build because appLocation was provided".yellow if options.illuminator.task.build
    elsif (not options.illuminator.task.build)
      options.instruments.appLocation = BuildArtifacts.instance.appLocation(appName) # assume app is here
    else
      builder = AutomationBuilder.new
      builder.workspace = workspace
      builder.doClean   = options.illuminator.clean.xcode
      builder.project   = options.xcode.project
      builder.scheme    = options.xcode.scheme
	  builder.workspaceFile = options.xcode.workspaceFile
      unless options.xcode.environmentVars.nil?
        options.xcode.environmentVars.each { |name, value| builder.addEnvironmentVariable(name, value) }
      end
	  
      # if app name is not specified, make sure that we will only have one to run
      XcodeUtils.removeExistingApps(BuildArtifacts.instance.xcode) if appName.nil?
      if builder.buildForAutomation(options.xcode.sdk, hardwareID)
        puts 'Build succeded'.green
        options.instruments.appLocation = BuildArtifacts.instance.appLocation(appName)
      else
        puts 'Build failed, check logs for results'.red
        exit builder.exitCode
      end
    end

    return true unless options.illuminator.task.automate

    # Install on real device
    unless hardwareID.nil?
      DeviceInstaller.instance.installOnDevice(options.instruments.appLocation, hardwareID)
    end

    # Initialize automation
    runner = AutomationRunner.new
    runner.workspace = workspace
    runner.appName   = appName
    runner.cleanup
    return runner.runWithOptions(options)

  end

  # overrideOptions is a lambda function that acts on the options object
  def self.reRun(configPath, workspace, overrideOptions = nil)

    # load config from supplied path
    jsonConfig = IO.read(configPath)

    # process any overrides
    options = overrideOptions.(IlluminatorOptions.new(JSON.parse(jsonConfig))) unless overrideOptions.nil?

    return self.runWithOptions options, workspace
  end

end
