
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

  let(:internal_logger) {
    @logger_io = StringIO.new
    ::Logger.new(@logger_io)
  }

  let(:logger_config) {
    {
      :host   => 'localhost',
      :port   => fluentd.port,
      :logger => internal_logger,
      :buffer_overflow_handler => buffer_overflow_handler
    }
  }

  let(:logger) {
    Fluent::Logger::FluentLogger.new('logger-test', logger_config)
  }

  let(:logger_with_nanosec) {
    Fluent::Logger::FluentLogger.new('logger-test', logger_config.merge(:nanosecond_precision => true))
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

    describe('testing interaction of use_nonblock and wait_writeable') do
      before(:example) do
        allow_any_instance_of(TCPSocket).to receive(:write_nonblock).and_raise(IO::EAGAINWaitWritable)
        allow_any_instance_of(TCPSocket).to receive(:write) { |_, buf| buf.size }
      end

      context('use_nonblock is false') do
        let(:block_config) { logger_config.merge(use_nonblock: false) }

        it('post returns true when wait_writeable is false') {
          cfg = block_config.merge(wait_writeable: false)
          l = Fluent::Logger::FluentLogger.new('logger-test', cfg)
          expect(l.post('hello', foo: 'bar')).to eq true
        }

        it('post returns true when wait_writeable is true') {
          cfg = block_config.merge(wait_writeable: true)
          l = Fluent::Logger::FluentLogger.new('logger-test', cfg)
          expect(l.post('hello', {foo: 'bar'})).to eq true
        }
      end

      context('use_nonblock is true') do
        let(:nonblock_config) { logger_config.merge(use_nonblock: true) }

        it('post raises IO::EAGAINWaitWritable when wait_writeable is false') {
          cfg = nonblock_config.merge(wait_writeable: false)
          l = Fluent::Logger::FluentLogger.new('logger-test', cfg)
          expect { l.post('hello', foo: 'bar') }.to raise_error(IO::EAGAINWaitWritable)
        }

        it('post returns false when wait_writeable is true') {
          cfg = nonblock_config.merge(wait_writeable: true)
          l = Fluent::Logger::FluentLogger.new('logger-test', cfg)
          expect(l.post('hello', {foo: 'bar'})).to eq false
        }

        context 'when write_nonblock returns the size less than received data' do
          before do
            allow_any_instance_of(TCPSocket).to receive(:write_nonblock).and_return(1) # write 1 bytes per call
          end

          it 'buffering data and flush at closed time' do
            logger = Fluent::Logger::FluentLogger.new('logger-test', nonblock_config)
            expect(logger.post('hello', foo: 'bar')).to eq(true)
            expect(logger.pending_bytesize).to eq(0)
          end
        end
      end
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
        expect(logger.pending_bytesize).to eq 0
        expect(logger.post('tag', {'a' => 'b'})).to be true
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.tag', {'a' => 'b'}]
        expect(logger.pending_bytesize).to eq 0
      }

      if defined?(Fluent::EventTime)
        it ('success with nanosecond') {
          expect(logger_with_nanosec.pending_bytesize).to eq 0
          expect(logger_with_nanosec.post('tag', {'a' => 'b'})).to be true
          fluentd.wait_transfer
          expect(fluentd.queue.last).to eq ['logger-test.tag', {'a' => 'b'}]
          expect(fluentd.output.emits.first[1]).to be_a_kind_of(Fluent::EventTime)
        }
      end

      it ('close after post') {
        expect(logger).to be_connect
        logger.close
        expect(logger).not_to be_connect

        logger.post('tag', {'b' => 'c'})
        expect(logger).to be_connect
        fluentd.wait_transfer
        expect(fluentd.queue.last).to eq ['logger-test.tag', {'b' => 'c'}]
        expect(logger.pending_bytesize).to eq 0
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

      it ('msgpack unsupport data and support data') {
        logger.post('tag', {'time' => Time.utc(2008, 9, 1, 10, 5, 0)})
        logger.post('tag', {'time' => '2008-09-01 10:05:00 UTC'})

        fluentd.wait_transfer

        logger_data1 = fluentd.queue.first.last
        expect(logger_data1['time']).to eq '2008-09-01 10:05:00 UTC'

        logger_data2 = fluentd.queue.last.last
        expect(logger_data2['time']).to eq '2008-09-01 10:05:00 UTC'
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

        fluentd.wait_transfer # ensure the fluentd accepted the connection
      }
    end

    context "initializer" do
      it "backward compatible" do
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', 'localhost', fluentd.port)
        host, port = fluent_logger.instance_eval { [@host, @port] }
        expect(host).to eq 'localhost'
        expect(port).to eq fluentd.port
        fluentd.wait_transfer # ensure the fluentd accepted the connection
      end

      it "hash argument" do
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', {
          :host => 'localhost',
          :port => fluentd.port
        })

        host, port = fluent_logger.instance_eval { [@host, @port] }
        expect(host).to eq 'localhost'
        expect(port).to eq fluentd.port
        fluentd.wait_transfer # ensure the fluentd accepted the connection
      end
    end
  end

  context "not running fluentd" do
    context('fluent logger interface') do
      it ('post & close') {
        expect(logger.pending_bytesize).to eq 0
        expect(logger.post('tag', {'a' => 'b'})).to be false
        fluentd.wait_transfer  # even if wait
        expect(fluentd.queue.last).to be_nil
        expect(logger.pending_bytesize).to be > 0
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
        expect(logger.pending_bytesize).to eq 0
        logger.limit = 100
        event_1 = {'a' => 'b'}
        logger.post('tag', event_1)
        fluentd.wait_transfer  # even if wait
        expect(fluentd.queue.last).to be(nil)
        expect(logger.pending_bytesize).to be > 0

        logger_io.rewind
        expect(logger_io.read).not_to match(/Can't send logs to/)

        event_2 = {'a' => ('c' * 1000)}
        logger.post('tag', event_2)
        logger_io.rewind
        expect(logger.pending_bytesize).to eq 0
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

  context "using socket_path" do

    let(:socket_logger) {
      @logger_io = StringIO.new
      logger = ::Logger.new(@logger_io)
      Fluent::Logger::FluentLogger.new('logger-test', {
        :socket_path => fluentd.socket_path,
        :logger => logger,
        :buffer_overflow_handler => buffer_overflow_handler
      })
    }

    context "running fluentd" do
      before(:all) do
        @serverengine = DummyServerengine.new
        @serverengine.startup
      end

      before(:each) do
        fluentd.socket_startup
      end

      after(:each) do
        fluentd.shutdown
      end

      after(:all) do
        @serverengine.shutdown
      end

      context('post') do
        it ('success') {
          expect(socket_logger.post('tag', {'b' => 'a'})).to be true
          fluentd.wait_transfer
          expect(fluentd.queue.last).to eq ['logger-test.tag', {'b' => 'a'}]
        }
      end
    end
  end
end
