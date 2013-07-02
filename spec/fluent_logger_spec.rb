
require 'spec_helper'
if RUBY_VERSION < "1.9.2"

describe Fluent::Logger::FluentLogger do
  pending "fluentd don't work RUBY < 1.9.2"
end

else

require 'fluent/load'
require 'tempfile'
require 'logger'
require 'socket'
require 'stringio'
require 'fluent/logger/fluent_logger/cui'

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
    })
  }

  let(:logger_io) {
    @logger_io
  }

  let(:output) {
    sleep 0.0001 # next tick
    Fluent::Engine.match('logger-test').output
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
      tmp = Tempfile.new('fluent-logger-config')
      tmp.close(false)

      File.open(tmp.path, 'w') {|f|
        f.puts <<EOF
<source>
  type tcp
  port #{fluentd_port}
</source>
<match logger-test.**>
  type test
</match>
EOF
      }
      Fluent::Test.setup
      Fluent::Engine.read_config(tmp.path)
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
        queue.last.should == ['logger-test.tag', {'a' => 'b', 'foo' => 'bar'}]
      }
    end

    context('post') do
      it ('success') { 
        logger.post('tag', {'a' => 'b'}).should be_true
        wait_transfer
        queue.last.should == ['logger-test.tag', {'a' => 'b'}]
      }

      it ('close after post') {
        logger.should be_connect
        logger.close
        logger.should_not be_connect

        logger.post('tag', {'b' => 'c'})
        logger.should be_connect
        wait_transfer
        queue.last.should == ['logger-test.tag', {'b' => 'c'}]
      }

      it ('large data') {
        data = {'a' => ('b' * 1000000)}
        logger.post('tag', data)
        wait_transfer
        queue.last.should == ['logger-test.tag', data]
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
        logger_data['time'].should == '2008-09-01 10:05:00 UTC'
        logger_data['proc'].should be
        logger_data['object'].should be
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
        queue.last.should be_nil
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
        port = fluentd_port
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', 'localhost', port)
        fluent_logger.method_missing(:instance_eval) { # fluent_logger is delegetor
          @host.should == 'localhost'
          @port.should == port
        }
      end

      it "hash argument" do
        port = fluentd_port
        fluent_logger = Fluent::Logger::FluentLogger.new('logger-test', {
          :host => 'localhost',
          :port => port
        })
        fluent_logger.method_missing(:instance_eval) { # fluent_logger is delegetor
          @host.should == 'localhost'
          @port.should == port
        }
      end
    end
  end
  
  context "not running fluentd" do
    context('fluent logger interface') do
      it ('post & close') {
        logger.post('tag', {'a' => 'b'}).should be_false
        wait_transfer  # even if wait
        queue.last.should be_nil
        logger.close
        logger_io.rewind
        log = logger_io.read
        log.should =~ /Failed to connect/
        log.should =~ /Can't send logs to/
      }

      it ('post limit over') do
        logger.limit = 100
        logger.post('tag', {'a' => 'b'})
        wait_transfer  # even if wait
        queue.last.should be_nil

        logger_io.rewind
        logger_io.read.should_not =~ /Can't send logs to/

        logger.post('tag', {'a' => ('c' * 1000)})
        logger_io.rewind
        logger_io.read.should =~ /Can't send logs to/
      end

      it ('log connect error once') do
        logger.stub(:suppress_sec).and_return(-1)
        logger.log_reconnect_error_threshold = 1
        logger.should_receive(:log_reconnect_error).once.and_call_original

        logger.post('tag', {'a' => 'b'})
        wait_transfer  # even if wait
        logger.post('tag', {'a' => 'b'})
        wait_transfer  # even if wait
        logger_io.rewind
        logger_io.read.should =~ /Can't connect to/
      end
    end
  end

end

end
