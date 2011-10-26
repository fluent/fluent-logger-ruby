
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

  let(:output) {
    sleep 0.0001 # next tick
    Fluent::Engine.match('logger-test').output
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
      output.emits.clear rescue nil
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
      @coolio_default_loop.stop
      Fluent::Engine.send :shutdown
    end

    context('post') do
      it ('success') { 
        logger.post('tag', {'a' => 'b'}).should be_true
        queue.last.should == ['logger-test.tag', {'a' => 'b'}]
      }

      it ('close after post') {
        logger.should be_connect
        logger.close
        logger.should_not be_connect

        logger.post('tag', {'b' => 'c'})
        logger.should be_connect
        queue.last.should == ['logger-test.tag', {'b' => 'c'}]
      }

      it ('large data') {
        data = {'a' => ('b' * 1000000)}
        logger.post('tag', data)
        sleep 0.01 # wait write
        queue.last.should == ['logger-test.tag', data]
      }

      it ('msgpack unsupport data') {
        data = {
          'time'   => Time.utc(2008, 9, 1, 10, 5, 0),
          'object' => Object.new,
          'proc'   => proc { 1 },
        }
        logger.post('tag', data)
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
        queue.last.should be_nil
        logger_io.rewind
        logger_io.read =~ /FluentLogger: Can't convert to msgpack:/
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

end
