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
module Fluent
module Logger


class FluentLogger < LoggerBase
  BUFFER_LIMIT = 8*1024*1024

  def initialize(tag, host, port=24224)
    super()
    require 'msgpack'
    require 'socket'
    require 'monitor'
    require 'logger'
    @mon = Monitor.new

    @tag = tag

    @pending = nil
    @host = host
    @port = port
    connect!

    @limit = BUFFER_LIMIT
    @logger = ::Logger.new(STDERR)

    FluentLogger.close_on_exit(self)
  end

  attr_accessor :limit, :logger

  def post(tag, map)
    time = Time.now.to_i
    write ["#{@tag}.#{tag}", time, map]
  end

  def close
    if @pending
      @logger.error("FluentLogger: Can't send logs to #{@host}:#{@port}")
    end
    @con.close if @con
    @con = nil
    @pending = nil
    self
  end

  private
  def write(msg)
    data = msg.to_msgpack
    @mon.synchronize {
      if @pending
        @pending << data
        data = @pending
      end
      begin
        unless @con
          connect!
        end
        while true
          n = @con.syswrite(data)
          if n >= data.bytesize
            break
          end
          data = data[n..-1]
        end
        @pending = nil
      rescue
        if @pending
          if @pending.bytesize > @limit
            @logger.error("FluentLogger: Can't send logs to #{@host}:#{@port}")
            @pending = nil
          end
        else
          @pending = data
        end
        @con.close if @con
        @con = nil
      end
    }
  end

  def connect!
    @con = TCPSocket.new(@host, @port)
  end

  def self.close_on_exit(logger)
    ObjectSpace.define_finalizer(logger, self.finalizer(logger))
  end

  def self.finalizer(logger)
    proc {
      logger.close
    }
  end
end


end
end
