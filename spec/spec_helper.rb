$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

if ENV['SIMPLE_COV']
   require 'simplecov'
  SimpleCov.start do 
    add_filter 'spec/'
    add_filter 'test/'
    add_filter 'pkg/'
    add_filter 'vendor/'
  end
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'fluent-logger'

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true

  config.mock_with :rspec
end
