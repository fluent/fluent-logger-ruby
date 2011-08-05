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


def self.new(*args)
  Logger.new(*args)
end

def self.open(*args)
  Logger.open(*args)
end

def self.close
  Logger.close
end

def self.create_event(*args)
  Logger.create_event(*args)
end

def self.post(map)
  Logger.post(map)
end


module Logger
  require 'fluent/logger/version'
  require 'fluent/logger/event'
  require 'fluent/logger/base'

  class DefaultLogger < LoggerBase
    INSTANCE = self.new

    def self.instance
      INSTANCE
    end

    def self.new
      INSTANCE
    end

    def post(map)
      Fluent::Logger.default.post(map)
    end

    def close
      Fluent::Logger.default.close
    end
  end

  @@default_logger = nil
  LOGGER_TYPES = {}

  def self.new(*args)
    if args.first.is_a?(Symbol)
      t = args.shift
      type = LOGGER_TYPES[t]
      unless type
        raise ArgumentError, "Unknown logger type '#{t}'"
      end
    end
    type ||= FluentLogger
    type.new(*args)
  end

  def self.open(*args)
    close
    @@default_logger = new(*args)
  end

  def self.close
    if @@default_logger
      @@default_logger.close
      @@default_logger = nil
    end
  end

  def self.create_event(*args)
    DefaultLogger.instance.create_event(*args)
  end

  def self.post(map)
    DefaultLogger.instance.post(map)
  end

  def self.default
    @@default_logger ||= ConsoleLogger.new(STDOUT)
  end

  def self.default=(logger)
    @@default_logger = logger
  end

  require 'fluent/logger/fluent'
  require 'fluent/logger/console'
  require 'fluent/logger/syslog'
  require 'fluent/logger/test'
end


end

