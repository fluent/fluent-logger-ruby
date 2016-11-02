
require 'spec_helper'
require 'support/dummy_serverengine'
require 'support/dummy_fluentd'

require 'logger'
require 'stringio'
require 'fluent/logger/fluent_logger/cui'

describe Fluent::Logger::FluentLogger do
  let(:fluentd) {
    DummyFluentd.new
  }

  let(:logger) {
    @logger_io = StringIO.new
    logger = ::Logger.new(@logger_io)
    Fluent::Logger::FluentLogger.new('logger-test', {
      :host   => 'localhost',
      :port   => fluentd.port,
      :logger => logger,
      :buffer_overflow_handler => buffer_overflow_handler
    })
  }

  let(:buffer_overflow_handler) { nil }

  let(:logger_io) {
    @logger_io
  }

  context "running fluentd" do
    before(:all) do
      @serverengine = DummyServerengine.new
      @serverengine.startup
    end

    before(:each) do
      fluentd.startup
    end

    after(:each) do
      fluentd.shutdown
    end

    after(:all) do
      @serverengine.shutdown
    end

    context('Post by CUI') do
      it('post') {
        args = %W(-h localhost -p #{fluentd.port} -t logger-test.tag -v a=b -v foo=bar)
        Fluent::Logger::FluentLogger::CUI.post(args)
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.tag', {'a' => 'b', 'foo' => 'bar'}]
      }
    end

    context('post') do
      it ('success') {
        expect(logger.post('tag', {'a' => 'b'})).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.tag', {'a' => 'b'}]
      }

      it ('close after post') {
        expect(logger).to be_connect
        logger.close
        expect(logger).not_to be_connect

        logger.post('tag', {'b' => 'c'})
        expect(logger).to be_connect
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.tag', {'b' => 'c'}]
      }

      it ('large data') {
        data = {'a' => ('b' * 1000000)}
        logger.post('tag', data)
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.tag', data]
      }

      it ('msgpack unsupport data') {
        data = {
          'time'   => Time.utc(2008, 9, 1, 10, 5, 0),
          'object' => Object.new,
          'proc'   => proc { 1 },
        }
        logger.post('tag', data)
        fluentd.wait_transfer
        logger_data = fluentd.queue.last.last
        expect(logger_data['time']).to eq '2008-09-01 10:05:00 UTC'
        expect(logger_data['proc']).to be_truthy
        expect(logger_data['object']).to be_truthy
      }

      it ('msgpack and JSON unsupport data') {
        data = {
          'time'   => Time.utc(2008, 9, 1, 10, 5, 0),
          'object' => Object.new,
          'proc'   => proc { 1 },
          'NaN'    => (0.0/0.0) # JSON don't convert
        }
        logger.post('tag', data)
        fluentd.wait_transfer
        expect(fluentd.queue.last).to be_nil
        logger_io.rewind
        logger_io.read =~ /FluentLogger: Can't convert to msgpack:/
      }

      it ('should raise an error when second argument is non hash object') {
        data = 'FooBar'
        expect {
          logger.post('tag', data)
        }.to raise_error(ArgumentError)

        data = nil
        expect {
          logger.post('tag', data)
        }.to raise_error(ArgumentError)
      }
    end

    context "initializer" do
      it "backward compatible" do
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', 'localhost', fluentd.port)
        host, port = fluent_logger.instance_eval { [@host, @port] }
        expect(host).to eq 'localhost'
        expect(port).to eq fluentd.port
      end

      it "hash argument" do
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', {
          :host => 'localhost',
          :port => fluentd.port
        })

        host, port = fluent_logger.instance_eval { [@host, @port] }
        expect(host).to eq 'localhost'
        expect(port).to eq fluentd.port
      end
    end
  end

  context "not running fluentd" do
    context('fluent logger interface') do
      it ('post & close') {
        expect(logger.post('tag', {'a' => 'b'})).to be false
        fluentd.wait_transfer  # even if wait
        expect(fluentd.queue.last).to be_nil
        logger.close
        logger_io.rewind
        log = logger_io.read
        expect(log).to match /Failed to connect/
        expect(log).to match /Can't send logs to/
      }

      it ('post limit over') do
        logger.limit = 100
        logger.post('tag', {'a' => 'b'})
        fluentd.wait_transfer  # even if wait
        expect(fluentd.queue.last).to be_nil

        logger_io.rewind
        expect(logger_io.read).not_to match /Can't send logs to/

        logger.post('tag', {'a' => ('c' * 1000)})
        logger_io.rewind
        expect(logger_io.read).to match /Can't send logs to/
      end

      it ('log connect error once') do
        allow_any_instance_of(Fluent::Logger::FluentLogger).to receive(:suppress_sec).and_return(-1)
        logger.log_reconnect_error_threshold = 1
        expect_any_instance_of(Fluent::Logger::FluentLogger).to receive(:log_reconnect_error).once.and_call_original

        logger.post('tag', {'a' => 'b'})
        fluentd.wait_transfer  # even if wait
        logger.post('tag', {'a' => 'b'})
        fluentd.wait_transfer  # even if wait
        logger_io.rewind
        expect(logger_io.read).to match /Failed to connect/
      end
    end

    context "when a buffer overflow handler is provided" do
      class BufferOverflowHandler
        attr_accessor :buffer

        def flush(messages)
          @buffer ||= []
          MessagePack::Unpacker.new.feed_each(messages) do |msg|
            @buffer << msg
          end
        end
      end

      let(:handler) { BufferOverflowHandler.new }
      let(:buffer_overflow_handler) { Proc.new { |messages| handler.flush(messages) } }

      it ('post limit over') do
        logger.limit = 100
        event_1 = {'a' => 'b'}
        logger.post('tag', event_1)
        fluentd.wait_transfer  # even if wait
        expect(fluentd.queue.last).to be(nil)

        logger_io.rewind
        expect(logger_io.read).not_to match(/Can't send logs to/)

        event_2 = {'a' => ('c' * 1000)}
        logger.post('tag', event_2)
        logger_io.rewind
        expect(logger_io.read).to match(/Can't send logs to/)

        buffer = handler.buffer

        expect(buffer[0][0]).to eq('logger-test.tag')
        expect(buffer[0][1].to_s).to match(/\d{10}/)
        expect(buffer[0][2]).to eq(event_1)

        expect(buffer[1][0]).to eq('logger-test.tag')
        expect(buffer[1][1].to_s).to match(/\d{10}/)
        expect(buffer[1][2]).to eq(event_2)
      end
    end
  end
end
