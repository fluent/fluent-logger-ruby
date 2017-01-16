require 'fluent/load'
require 'fluent/test'
require 'socket'
require 'plugin/out_test'
require 'stringio'

class DummyFluentd
  def initialize
    output.emits.clear rescue nil
  end

  WAIT = ENV['WAIT'] ? ENV['WAIT'].to_f : 0.3
  SOCKET_PATH = ENV['SOCKET_PATH'] || "/tmp/dummy_fluent.sock"

  def wait_transfer
    sleep WAIT
  end

  def port
    return @port if @port
    @port = 60001
    loop do
      begin
        TCPServer.open('localhost', @port).close
        break
      rescue Errno::EADDRINUSE
        @port += 1
      end
    end
    @port
  end

  def socket_path
    SOCKET_PATH
  end

  def output
    sleep 0.0001 # next tick
    if Fluent::Engine.respond_to?(:match)
      Fluent::Engine.match('logger-test').output
    else
      Fluent::Engine.root_agent.event_router.match('logger-test')
    end
  end

  def queue
    queue = []
    output.emits.each { |tag, time, record|
      queue << [tag, record]
    }
    queue
  end

  def startup
    config = Fluent::Config.parse(<<EOF, '(logger-spec)', '(logger-spec-dir)', true)
<source>
  type forward
  port #{port}
</source>
<match logger-test.**>
  type test
</match>
EOF
    Fluent::Test.setup
    Fluent::Engine.run_configure(config)
    @coolio_default_loop = nil
    @thread = Thread.new {
      @coolio_default_loop = Coolio::Loop.default
      Fluent::Engine.run
    }
    wait_transfer
  end

  def socket_startup
    config = Fluent::Config.parse(<<EOF, '(logger-spec)', '(logger-spec-dir)', true)
<source>
  type unix
  path #{socket_path}
</source>
<match logger-test.**>
  type test
</match>
EOF
    Fluent::Test.setup
    Fluent::Engine.run_configure(config)
    @coolio_default_loop = nil
    @thread = Thread.new {
      @coolio_default_loop = Coolio::Loop.default
      Fluent::Engine.run
    }
    wait_transfer
  end

  def shutdown
    @coolio_default_loop.stop rescue nil
    begin
      Fluent::Engine.stop
    rescue => e
      # for v0.12, calling stop may cause "loop not running" by internal default loop
      if e.message == "loop not running"
        Fluent::Engine.send :shutdown
      end
    end
    @thread.join
    @coolio_default_loop = @thread = nil
  end
end
