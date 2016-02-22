
require 'spec_helper'

require 'fluent/load'
require 'fluent/test'
require 'tempfile'
require 'logger'
require 'socket'
require 'stringio'
require 'fluent/logger/fluent_logger/cui'
require 'plugin/out_test'

$log = Fluent::Log.new(StringIO.new) # XXX should remove $log from fluentd

describe Fluent::Logger::FluentLogger do
  WAIT = ENV['WAIT'] ? ENV['WAIT'].to_f : 0.1

  let(:fluentd_port) {
    port = 60001
    loop do
      begin
        TCPServer.open('localhost', port).close
        break
      rescue Errno::EADDRINUSE
        port += 1
      end
    end
    port
  }

  let(:logger) {
    @logger_io = StringIO.new
    logger = ::Logger.new(@logger_io)
    Fluent::Logger::FluentLogger.new('logger-test', {
      :host   => 'localhost',
      :port   => fluentd_port,
      :logger => logger,
      :buffer_overflow_handler => buffer_overflow_handler
    })
  }

  let(:buffer_overflow_handler) { nil }

  let(:logger_io) {
    @logger_io
  }

  let(:output) {
    sleep 0.0001 # next tick
    if Fluent::Engine.respond_to?(:match)
      Fluent::Engine.match('logger-test').output
    else
      Fluent::Engine.root_agent.event_router.match('logger-test')
    end
  }

  let(:queue) {
    queue = []
    output.emits.each {|tag, time, record|
      queue << [tag, record]
    }
    queue
  }

  after(:each) do
    output.emits.clear rescue nil
  end

  def wait_transfer
    sleep WAIT
  end

  context "running fluentd" do
    before(:each) do
      @config = Fluent::Config.parse(<<EOF, '(logger-spec)', '(logger-spec-dir)', true)
<source>
  type forward
  port #{fluentd_port}
</source>
<match logger-test.**>
  type test
</match>
EOF
      Fluent::Test.setup
      Fluent::Engine.run_configure(@config)
      @coolio_default_loop = nil
      @thread = Thread.new {
        @coolio_default_loop = Coolio::Loop.default
        Fluent::Engine.run
      }
      wait_transfer
    end

    after(:each) do
      @coolio_default_loop.stop
      Fluent::Engine.send :shutdown
      @thread.join
    end

    context('Post by CUI') do
      it('post') {
        args = %W(-h localhost -p #{fluentd_port} -t logger-test.tag -v a=b -v foo=bar)
        Fluent::Logger::FluentLogger::CUI.post(args)
        wait_transfer
        expect(queue.last).to eq ['logger-test.tag', {'a' => 'b', 'foo' => 'bar'}]
      }
    end

    context('post') do
      it ('success') {
        expect(logger.post('tag', {'a' => 'b'})).to be true
        wait_transfer
        expect(queue.last).to eq ['logger-test.tag', {'a' => 'b'}]
      }

      it ('close after post') {
        expect(logger).to be_connect
        logger.close
        expect(logger).not_to be_connect

        logger.post('tag', {'b' => 'c'})
        expect(logger).to be_connect
        wait_transfer
        expect(queue.last).to eq ['logger-test.tag', {'b' => 'c'}]
      }

      it ('large data') {
        data = {'a' => ('b' * 1000000)}
        logger.post('tag', data)
        wait_transfer
        expect(queue.last).to eq ['logger-test.tag', data]
      }

      it ('msgpack unsupport data') {
        data = {
          'time'   => Time.utc(2008, 9, 1, 10, 5, 0),
          'object' => Object.new,
          'proc'   => proc { 1 },
        }
        logger.post('tag', data)
        wait_transfer
        logger_data = queue.last.last
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
        wait_transfer
        expect(queue.last).to be_nil
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
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', 'localhost', fluentd_port)
        host, port = fluent_logger.instance_eval { [@host, @port] }
        expect(host).to eq 'localhost'
        expect(port).to eq fluentd_port
      end

      it "hash argument" do
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', {
          :host => 'localhost',
          :port => fluentd_port
        })

        host, port = fluent_logger.instance_eval { [@host, @port] }
        expect(host).to eq 'localhost'
        expect(port).to eq fluentd_port
      end
    end
  end

  context "not running fluentd" do
    context('fluent logger interface') do
      it ('post & close') {
        expect(logger.post('tag', {'a' => 'b'})).to be false
        wait_transfer  # even if wait
        expect(queue.last).to be_nil
        logger.close
        logger_io.rewind
        log = logger_io.read
        expect(log).to match /Failed to connect/
        expect(log).to match /Can\'t send logs to/
      }

      it ('post limit over') do
        logger.limit = 100
        logger.post('tag', {'a' => 'b'})
        wait_transfer  # even if wait
        expect(queue.last).to be_nil

        logger_io.rewind
        expect(logger_io.read).not_to match /Can\'t send logs to/

        logger.post('tag', {'a' => ('c' * 1000)})
        logger_io.rewind
        expect(logger_io.read).to match /Can\'t send logs to/
      end

      it ('log connect error once') do
        allow_any_instance_of(Fluent::Logger::FluentLogger).to receive(:suppress_sec).and_return(-1)
        logger.log_reconnect_error_threshold = 1
        expect_any_instance_of(Fluent::Logger::FluentLogger).to receive(:log_reconnect_error).once.and_call_original

        logger.post('tag', {'a' => 'b'})
        wait_transfer  # even if wait
        logger.post('tag', {'a' => 'b'})
        wait_transfer  # even if wait
        logger_io.rewind
        expect(logger_io.read).to match /Failed to connect/
      end
    end

    context "when a buffer overflow handler is provided" do
      class BufferOverflowHandler
        attr_accessor :buffer

        def flush(messages)
          @buffer ||= []
          messages.each do |tag, msg, option|
            @buffer << [tag, MessagePack.unpack(msg)].flatten
          end
        end
      end

      let(:handler) { BufferOverflowHandler.new }
      let(:buffer_overflow_handler) { Proc.new { |messages| handler.flush(messages) } }

      it ('post limit over') do
        logger.limit = 100
        event_1 = {'a' => 'b'}
        logger.post('tag', event_1)
        wait_transfer  # even if wait
        expect(queue.last).to be(nil)

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
