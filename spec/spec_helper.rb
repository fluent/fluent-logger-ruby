$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

if ENV['SIMPLE_COV']
  require 'simplecov'
  require 'simplecov-vim/formatter'
  class SimpleCov::Formatter::MergedFormatter
    def format(result)
      SimpleCov::Formatter::HTMLFormatter.new.format(result)
      SimpleCov::Formatter::VimFormatter.new.format(result)
    end
  end
  SimpleCov.start do
    formatter SimpleCov::Formatter::MergedFormatter
    add_filter 'spec/'
    add_filter 'test/'
    add_filter 'pkg/'
    add_filter 'vendor/'
  end
end

require 'rspec'
require 'rspec/its'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'fluent-logger'

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true

  config.mock_with :rspec
end
