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
    class FluentLogger < LoggerBase
      BUFFER_LIMIT = 8*1024*1024
      RECONNECT_WAIT = 0.5
      RECONNECT_WAIT_INCR_RATE = 1.5
      RECONNECT_WAIT_MAX = 60
      RECONNECT_WAIT_MAX_COUNT =
        (1..100).inject(RECONNECT_WAIT_MAX / RECONNECT_WAIT) {|r,i|
        break i + 1 if r < RECONNECT_WAIT_INCR_RATE
        r / RECONNECT_WAIT_INCR_RATE
      }

      module Severity
        # Low-level information, mostly for developers.
        DEBUG = 0
        # Generic (useful) information about system operation.
        INFO = 1
        # A warning.
        WARN = 2
        # A handleable error condition.
        ERROR = 3
        # An unhandleable error that results in a program crash.
        FATAL = 4
        # An unknown message that should always be logged.
        UNKNOWN = 5
      end
      include Severity

      def initialize(tag_prefix = nil, *args)
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

        @buffer_overflow_handler = options[:buffer_overflow_handler]

        @level = format_severity_index(options[:level]) || DEBUG

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
      attr_reader :last_error

      def last_error
        @last_error[Thread.current.object_id]
      end

      def post_with_time(tag, map, time)
        @logger.debug { "event: #{tag} #{map.to_json}" rescue nil } if @logger.debug?
        tag = "#{@tag_prefix}.#{tag}" if @tag_prefix
        write [tag, time.to_i, map]
      end

      def close
        @mon.synchronize {
          if @pending
            begin
              send_data(@pending)
            rescue => e
              set_last_error(e)
              @logger.error("FluentLogger: Can't send logs to #{@host}:#{@port}: #{$!}")
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

      def add(severity, message = nil, progname = nil, &block)
        severity ||= UNKNOWN
        if severity < @level
          return true
        end
        progname ||= @progname
        if message.nil?
          if block_given?
            message = yield
          else
            message = progname
            progname = @progname
          end
        end
        map = {}
        map[:level] = format_severity(severity)
        map[:message] = message if message
        map[:progname] = progname if progname
        post(format_severity(severity).downcase, map)
        true
      end

      #
      # Log a +DEBUG+ message.
      #
      # See #info for more information.
      #
      def debug(progname = nil, &block)
        add(DEBUG, nil, progname, &block)
      end

      #
      # :call-seq:
      #   info(message)
      #   info(progname, &block)
      #
      # Log an +INFO+ message.
      #
      # +message+:: The message to log; does not need to be a String.
      # +progname+:: In the block form, this is the #progname to use in the
      #              log message.  The default can be set with #progname=.
      # +block+:: Evaluates to the message to log.  This is not evaluated unless
      #           the logger's level is sufficient to log the message.  This
      #           allows you to create potentially expensive logging messages that
      #           are only called when the logger is configured to show them.
      #
      # === Examples
      #
      #   logger.info("MainApp") { "Received connection from #{ip}" }
      #   # ...
      #   logger.info "Waiting for input from user"
      #   # ...
      #   logger.info { "User typed #{input}" }
      #
      # You'll probably stick to the second form above, unless you want to provide a
      # program name (which you can do with #progname= as well).
      #
      # === Return
      #
      # See #add.
      #
      def info(progname = nil, &block)
        add(INFO, nil, progname, &block)
      end

      #
      # Log a +WARN+ message.
      #
      # See #info for more information.
      #
      def warn(progname = nil, &block)
        add(WARN, nil, progname, &block)
      end

      #
      # Log an +ERROR+ message.
      #
      # See #info for more information.
      #
      def error(progname = nil, &block)
        add(ERROR, nil, progname, &block)
      end

      #
      # Log a +FATAL+ message.
      #
      # See #info for more information.
      #
      def fatal(progname = nil, &block)
        add(FATAL, nil, progname, &block)
      end

      private
      SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

      def format_severity(severity)
        SEV_LABEL[severity] || 'ANY'
      end

      def format_severity_index(sev_label)
        return nil unless sev_label
        SEV_LABEL.index(sev_label.upcase)
      end

      def to_msgpack(msg)
        begin
          msg.to_msgpack
        rescue NoMethodError
          JSON.parse(JSON.generate(msg)).to_msgpack
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
          if !@connect_error_history.empty? && @pending.bytesize <= @limit
            if Time.now.to_i - @connect_error_history.last < suppress_sec
              return false
            end
          end

          begin
            send_data(@pending)
            @pending = nil
            true
          rescue => e
            set_last_error(e)
            if @pending.bytesize > @limit
              @logger.error("FluentLogger: Can't send logs to #{@host}:#{@port}: #{$!}")
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
        @logger.error("FluentLogger: Can't connect to #{@host}:#{@port}(#{@connect_error_history.size} retried): #{$!}")
      end

      def set_last_error(e)
        # TODO: Check non GVL env
        @last_error[Thread.current.object_id] = e
      end
    end
  end
end
