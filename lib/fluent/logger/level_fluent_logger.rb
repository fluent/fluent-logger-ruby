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
    class LevelFluentLogger < ::Logger

      def initialize(tag_prefix = nil, *args)
        @level = ::Logger::DEBUG
        @default_formatter = proc do |severity, datetime, progname, message|
          map = { level: severity }
          map[:message] = message if message
          map[:progname] = progname if progname
          map
        end
        @fluent_logger = FluentLogger.new(tag_prefix, *args)
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
        map = format_message(format_severity(severity), Time.now, progname, message)
        @fluent_logger.post(format_severity(severity).downcase, map)
        true
      end

      def close
        @fluent_logger.close
      end

      def reopen
        @fluent_logger.close
        # we do not call #connect! here because 1) FluentLogger#connect! is not a public method
        # 2) #post automatically connects if its connection is closed
      end

      def connect?
        @fluent_logger.connect?
      end
    end
  end
end
