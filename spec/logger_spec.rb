
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
      expect(test_logger).to receive(:post).with('tag1', {:foo => :bar})
      #allow_any_instance_of(test_logger).to receive(:post).with('tag1', {:foo => :bar})
      Fluent::Logger.post('tag1', {:foo => :bar})
    }

    it('close') {
      expect(test_logger).to receive(:close)
      Fluent::Logger.close
    }

    it('open') {
      expect(test_logger).to receive(:close)
      klass = Class.new(Fluent::Logger::LoggerBase)
      fluent_logger_logger_io = StringIO.new
      Fluent::Logger.open('tag-prefix', {
        :logger => ::Logger.new(fluent_logger_logger_io)
      })
      expect(Fluent::Logger.default.kind_of?(Fluent::Logger::FluentLogger)).to be true
    }

    it('open with BaseLogger class') {
      expect(test_logger).to receive(:close)
      klass = Class.new(Fluent::Logger::LoggerBase)
      Fluent::Logger.open(klass)
      expect(Fluent::Logger.default.class).to be klass
    }
  end
end
