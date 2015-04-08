require 'pathname'

require File.join(File.expand_path(File.dirname(__FILE__)), '../src/scripts/classes/IlluminatorFramework.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '../src/scripts/classes/IlluminatorArgumentParsing.rb')
require File.join(File.expand_path(File.dirname(__FILE__)), '../src/scripts/classes/HostUtils.rb')


options = {}
parserFactory = IlluminatorParserFactory.new

parserFactory.prepare({"b" => 'iPhone 5'}, # the default sim devie is iPhone 5
                      {},                  # no extra parse flags are being defined
                      {})                  # no argument processing overrides are being provided
parser = parserFactory.buildParser(options, 'asdq#xtoni#rvmw#bzl#Bfek#')

optionStruct = parser.parse ARGV

# hard code the project-specific information we have
optionStruct.xcode.appName = 'AutomatorSampleApp'
optionStruct.xcode.scheme = 'AutomatorSampleApp'
optionStruct.xcode.workspaceFile = 'AutomatorSampleApp.xcworkspace'
optionStruct.javascript.implementation = 'iPhone'
optionStruct.javascript.testPath = HostUtils.realpath('../SampleTests/tests/AllTests.js') # must be full path

Dir.chdir 'SampleApp/AutomatorSampleApp'
workspace = Dir.pwd


success = IlluminatorFramework.runWithOptions optionStruct, workspace
exit 1 unless success
