
require 'spec_helper'
require 'fluent/load'
require 'tempfile'
require 'logger'
require 'socket'
require 'stringio'

$log = Fluent::Log.new(StringIO.new) # XXX should remove $log from fluentd 

describe Fluent::Logger::FluentLogger do
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

  let (:output) {
    sleep 0.0001 # next tick
    Fluent::Engine.match?('logger-test').output # XXX Fluent::Engine match interface
  }

  let(:queue) {
    queue = []
    output.emits.each {|tag,events|
      events.each {|time,record|
        queue << [tag, record]
      }
    }
    queue
  }

  after(:each) do
    output.emits.clear
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
      Thread.new {
        @coolio_default_loop = Coolio::Loop.default
        Fluent::Engine.run
      }
      sleep 0.001 # next tick
    end

    after(:each) do
      Fluent::Engine.send :shutdown
      @coolio_default_loop.stop
    end

    context('fluent logger interface') do
      it ('post') { 
        logger.post('tag', {'a' => 'b'})
        queue.last.should == ['logger-test.tag', {'a' => 'b'}]
      }

      it ('close and post') {
        logger.should be_connect
        logger.close
        logger.should_not be_connect

        logger.post('tag', {'b' => 'c'})
        logger.should be_connect
        queue.last.should == ['logger-test.tag', {'b' => 'c'}]
      }

      it ('post large data') {
        data = {'a' => ('b' * 1000000)}
        logger.post('tag', data)
        sleep 0.01 # wait write
        queue.last.should == ['logger-test.tag', data]
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
        logger.post('tag', {'a' => 'b'})
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
        queue.last.should be_nil

        logger_io.rewind
        logger_io.read.should_not =~ /Can't send logs to/

        logger.post('tag', {'a' => ('c' * 1000)})
        logger_io.rewind
        logger_io.read.should =~ /Can't send logs to/
      end
    end
  end

end

