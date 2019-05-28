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
require 'json'

module Fluent
  module Logger
    class EventTime
      TYPE = 0

      def initialize(sec, nsec = 0)
        @sec = sec
        @nsec = nsec
      end

      def to_msgpack(io = nil)
        @sec.to_msgpack(io)
      end

      def to_msgpack_ext
        [@sec, @nsec].pack('NN')
      end

      def self.from_msgpack_ext(data)
        new(*data.unpack('NN'))
      end

      def to_json(*args)
        @sec
      end
    end

    class FluentLogger < LoggerBase
      BUFFER_LIMIT = 8*1024*1024
      RECONNECT_WAIT = 0.5
      RECONNECT_WAIT_INCR_RATE = 1.5
      RECONNECT_WAIT_MAX = 60
      RECONNECT_WAIT_MAX_COUNT =
        (1..100).inject(RECONNECT_WAIT_MAX / RECONNECT_WAIT) { |r, i|
        break i + 1 if r < RECONNECT_WAIT_INCR_RATE
        r / RECONNECT_WAIT_INCR_RATE
      }

      def initialize(tag_prefix = nil, *args)
        super()

        options = {
          :host => 'localhost',
          :port => 24224,
          :use_nonblock => false
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
        @socket_path = options[:socket_path]
        @nanosecond_precision = options[:nanosecond_precision]
        @use_nonblock = options[:use_nonblock]

        @factory = MessagePack::Factory.new
        if @nanosecond_precision
          @factory.register_type(EventTime::TYPE, EventTime)
        end
        @packer = @factory.packer

        @mon = Monitor.new
        @pending = nil
        @connect_error_history = []

        @limit = options[:buffer_limit] || BUFFER_LIMIT
        @log_reconnect_error_threshold = options[:log_reconnect_error_threshold] || RECONNECT_WAIT_MAX_COUNT

        @buffer_overflow_handler = options[:buffer_overflow_handler]
        if options[:logger]
          @logger = options[:logger]
        else
          @logger = ::Logger.new(STDERR)
          if options[:debug]
            @logger.level = ::Logger::DEBUG
          else
            @logger.level = ::Logger::INFO
          end
        end

        @wait_writeable = true
        @wait_writeable = options[:wait_writeable] if options.key?(:wait_writeable)

        @last_error = {}

        begin
          connect!
        rescue => e
          set_last_error(e)
          @logger.error "Failed to connect fluentd: #{$!}"
          @logger.error "Connection will be retried."
        end

        at_exit { close }
      end

      attr_accessor :limit, :logger, :log_reconnect_error_threshold

      def last_error
        @last_error[Thread.current.object_id]
      end

      def post_with_time(tag, map, time)
        @logger.debug { "event: #{tag} #{map.to_json}" rescue nil } if @logger.debug?
        tag = "#{@tag_prefix}.#{tag}" if @tag_prefix
        if @nanosecond_precision && time.is_a?(Time)
          write [tag, EventTime.new(time.to_i, time.nsec), map]
        else
          write [tag, time.to_i, map]
        end
      end

      def close
        @mon.synchronize {
          if @pending
            begin
              send_data(@pending)
            rescue => e
              set_last_error(e)
              @logger.error("FluentLogger: Can't send logs to #{connection_string}: #{$!}")
              call_buffer_overflow_handler(@pending)
            end
          end
          @con.close if connect?
          @con = nil
          @pending = nil
        }
        self
      end

      def connect?
        @con && !@con.closed?
      end

      def create_socket!
        if @socket_path
          @con = UNIXSocket.new(@socket_path)
        else
          @con = TCPSocket.new(@host, @port)
        end
      end

      def connection_string
        @socket_path ? "#{@socket_path}" : "#{@host}:#{@port}"
      end

      def pending_bytesize
        if @pending
          @pending.bytesize
        else
          0
        end
      end

      private

      def to_msgpack(msg)
        @mon.synchronize {
          res = begin
                  @packer.pack(msg).to_s
                rescue NoMethodError
                  JSON.parse(JSON.generate(msg)).to_msgpack
                end
          @packer.clear
          res
        }
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
        rescue => e
          set_last_error(e)
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
          if !@connect_error_history.empty? && pending_bytesize <= @limit
            if Time.now.to_i - @connect_error_history.last < suppress_sec
              return false
            end
          end

          begin
            written = send_data(@pending)
            if @pending.bytesize != written
              raise "Actual written data size(#{written} bytes) is different from the received data size(#{@pending.bytesize} bytes)."
            end

            @pending = nil
            true
          rescue => e
            unless wait_writeable?(e)
              raise e
            end
            set_last_error(e)
            if pending_bytesize > @limit
              @logger.error("FluentLogger: Can't send logs to #{connection_string}: #{$!}")
              call_buffer_overflow_handler(@pending)
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
        if @use_nonblock
          send_data_nonblock(data)
        else
          @con.write data
        end
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
      end

      def send_data_nonblock(data)
        written = @con.write_nonblock(data)
        remaining = data.bytesize - written

        while remaining > 0
          len = @con.write_nonblock(data.byteslice(written, remaining))
          remaining -= len
          written += len
        end

        written
      end

      def connect!
        create_socket!
        @con.sync = true
        @connect_error_history.clear
        @logged_reconnect_error = false
      rescue => e
        @connect_error_history << Time.now.to_i
        if @connect_error_history.size > RECONNECT_WAIT_MAX_COUNT
          @connect_error_history.shift
        end

        if @connect_error_history.size >= @log_reconnect_error_threshold && !@logged_reconnect_error
          log_reconnect_error
          @logged_reconnect_error = true
        end

        raise e
      end

      def call_buffer_overflow_handler(pending)
        if @buffer_overflow_handler
          @buffer_overflow_handler.call(pending)
        end
      rescue Exception => e
        @logger.error("FluentLogger: Can't call buffer overflow handler: #{$!}")
      end

      def log_reconnect_error
        @logger.error("FluentLogger: Can't connect to #{connection_string}(#{@connect_error_history.size} retried): #{$!}")
      end

      def set_last_error(e)
        # TODO: Check non GVL env
        @last_error[Thread.current.object_id] = e
      end

      def wait_writeable?(e)
        if e.instance_of?(IO::EAGAINWaitWritable)
          @wait_writeable
        else
          true
        end
      end
    end
  end
end
