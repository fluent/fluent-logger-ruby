#
# Fluent
#
# Copyright (C) 2011 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
require 'msgpack'
require 'socket'
require 'monitor'
require 'logger'
require 'yajl'

module Fluent
module Logger


class FluentLogger < LoggerBase
  module Finalizable
    require 'delegate'
    def new(*args, &block)
      obj = allocate
      obj.instance_eval { initialize(*args, &block) }
      dc = DelegateClass(obj.class).new(obj)
      ObjectSpace.define_finalizer(dc, finalizer(obj))
      dc
    end

    def finalizer(obj)
      fin = obj.method(:finalize)
      proc {|id|
        fin.call
      }
    end
  end
  extend Finalizable

  BUFFER_LIMIT = 8*1024*1024
  RECONNECT_WAIT = 0.5
  RECONNECT_WAIT_INCR_RATE = 1.5
  RECONNECT_WAIT_MAX = 60
  RECONNECT_WAIT_MAX_COUNT =
      (1..100).inject(RECONNECT_WAIT_MAX / RECONNECT_WAIT) {|r,i|
        break i + 1 if r < RECONNECT_WAIT_INCR_RATE
        r / RECONNECT_WAIT_INCR_RATE
      }

  def initialize(tag_prefix, *args)
    super()

    options = {
      :host => 'localhost',
      :port => 24224
    }

    case args.first
    when String, Symbol
      # backward compatible
      options[:host] = args[0]
      options[:port] = args[1] if args[1]
    when Hash
      options.update args.first
    end

    @tag_prefix = tag_prefix
    @host = options[:host]
    @port = options[:port]

    @mon = Monitor.new
    @pending = nil
    @connect_error_history = []

    @limit = options[:buffer_limit] || BUFFER_LIMIT
    @log_reconnect_error_threshold = options[:log_reconnect_error_threshold] ||  RECONNECT_WAIT_MAX_COUNT

    if logger = options[:logger]
      @logger = logger
    else
      @logger = ::Logger.new(STDERR)
      if options[:debug]
        @logger.level = ::Logger::DEBUG
      else
        @logger.level = ::Logger::INFO
      end
    end

    begin
      connect!
    rescue
      @logger.error "Failed to connect fluentd: #{$!}"
      @logger.error "Connection will be retried."
    end
  end

  attr_accessor :limit, :logger, :log_reconnect_error_threshold

  def post_with_time(tag, map, time)
    @logger.debug { "event: #{tag} #{map.to_json}" rescue nil }
    tag = "#{@tag_prefix}.#{tag}" if @tag_prefix
    write [tag, time.to_i, map]
  end

  def close
    @mon.synchronize {
      if @pending
        begin
          send_data(@pending)
        rescue
          @logger.error("FluentLogger: Can't send logs to #{@host}:#{@port}: #{$!}")
        end
      end
      @con.close if connect?
      @con = nil
      @pending = nil
    }
    self
  end

  def connect?
    !!@con
  end

  def finalize
    close
  end

  private
  def to_msgpack(msg)
    begin
      msg.to_msgpack
    rescue NoMethodError
      Yajl::Parser.parse( Yajl::Encoder.encode(msg) ).to_msgpack
    end
  end

  def suppress_sec
    if (sz = @connect_error_history.size) < RECONNECT_WAIT_MAX_COUNT
      RECONNECT_WAIT * (RECONNECT_WAIT_INCR_RATE ** (sz - 1))
    else
      RECONNECT_WAIT_MAX
    end
  end

  def write(msg)
    begin
      data = to_msgpack(msg)
    rescue
      @logger.error("FluentLogger: Can't convert to msgpack: #{msg.inspect}: #{$!}")
      return false
    end

    @mon.synchronize {
      if @pending
        @pending << data
      else
        @pending = data
      end

      # suppress reconnection burst
      if !@connect_error_history.empty? && @pending.bytesize <= @limit
        if Time.now.to_i - @connect_error_history.last < suppress_sec
          return false
        end
      end

      begin
        send_data(@pending)
        @pending = nil
        true
      rescue
        if @pending.bytesize > @limit
          @logger.error("FluentLogger: Can't send logs to #{@host}:#{@port}: #{$!}")
          @pending = nil
        end
        @con.close if connect?
        @con = nil
        false
      end
    }
  end

  def send_data(data)
    unless connect?
      connect!
    end
    @con.write data
    #while true
    #  puts "sending #{data.length} bytes"
    #  if data.length > 32*1024
    #    n = @con.syswrite(data[0..32*1024])
    #  else
    #    n = @con.syswrite(data)
    #  end
    #  puts "sent #{n}"
    #  if n >= data.bytesize
    #    break
    #  end
    #  data = data[n..-1]
    #end
    true
  end

  def connect!
    @con = TCPSocket.new(@host, @port)
    @con.sync = true
    @connect_error_history.clear
    @logged_reconnect_error = false
  rescue
    @connect_error_history << Time.now.to_i
    if @connect_error_history.size > RECONNECT_WAIT_MAX_COUNT
      @connect_error_history.shift
    end

    if @connect_error_history.size >= @log_reconnect_error_threshold && !@logged_reconnect_error
      log_reconnect_error
      @logged_reconnect_error = true
    end

    raise
  end

  def log_reconnect_error
    @logger.error("FluentLogger: Can't connect to #{@host}:#{@port}(#{@connect_error_history.size} retried): #{$!}")
  end
end


end
end
