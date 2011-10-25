
require 'spec_helper'
require 'stringio'

describe Fluent::Logger do
  context "default logger" do
    let(:test_logger) {
      Fluent::Logger::TestLogger.new
    }
    before(:each) do
      Fluent::Logger.default = test_logger
    end

    it('post') {
      test_logger.should_receive(:post).with('tag1', {:foo => :bar})
      Fluent::Logger.post('tag1', {:foo => :bar})
    }

    it('close') {
      test_logger.should_receive(:close)
      Fluent::Logger.close
    }

    it('open') {
      test_logger.should_receive(:close)
      klass = Class.new(Fluent::Logger::LoggerBase)
      fluent_logger_logger_io = StringIO.new
      Fluent::Logger.open('tag-prefix', {
        :logger => ::Logger.new(fluent_logger_logger_io)
      })
      # Fluent::Logger::FluentLogger is delegator
      Fluent::Logger.default.method_missing(:kind_of?, Fluent::Logger::FluentLogger).should be_true
    }

    it('open with BaseLogger class') {
      test_logger.should_receive(:close)
      klass = Class.new(Fluent::Logger::LoggerBase)
      Fluent::Logger.open(klass)
      Fluent::Logger.default.class.should == klass
    }
  end
end
