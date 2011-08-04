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


class LoggerBase
  def define_event(*args)
    map = {}
    keys = []
    args.each {|a|
      case a
      when Hash
        a.each_pair {|k,v|
          keys << k.to_sym
          map[k.to_sym] = v
        }
      else
        keys << a.to_sym
      end
    }

    c = Class.new(Event)
    logger = self

    c.module_eval do
      const_set(:LOGGER, logger)
      const_set(:KEYS, keys)
      const_set(:DEFAULT_VALUES, map)

      keys.each {|key|
        define_method(key) do |v|
          self[key] = v
          self
        end
      }
    end

    (class<<c;self;end).module_eval do
      keys.each {|key|
        define_method(key) do |v|
          self.new(logger).__send__(key, v)
        end
      }

      define_method(:post) do
        self.new.post!
      end

      define_method(:post!) do
        self.new(logger).post!
      end
    end

    c
  end

  def post_defined(name, map)
    post(map)
  end

  #def post(map)
  #end

  #def close(map)
  #end

  def self.register_logger(name)
    LOGGER_TYPES[name.to_sym] = self
  end
end


class TextLogger < LoggerBase
  def initialize
    require 'json'
    @time_format = "%b %e %H:%M:%S"
  end

  def post(map)
    post_impl(":", map)
  end

  def post_defined(c, map)
    name = c.name.gsub(/[A-Z][a-zA-Z0-9_]*::/,'')
    post_impl(" #{name}:", map)
  end

  #def post_text(text)
  #end

  private
  def post_impl(extra, map)
    a = [Time.now.strftime(@time_format), extra]
    map.each_pair {|k,v|
      a << " #{k}="
      a << v.to_json
    }
    post_text a.join
  end
end


class Default < LoggerBase
  INSTANCE = self.new

  def self.instance
    INSTANCE
  end

  def self.new
    INSTANCE
  end

  def post_defined(name, map)
    Fluent::Logger.default.post_defined(name, map)
  end

  def post(map)
    Fluent::Logger.default.post(map)
  end

  def close
    Fluent::Logger.default.close
  end
end


@@default_logger = nil
LOGGER_TYPES = {}  # :name => Class


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

def self.define_event(*args)
  Default.instance.define_event(*args)
end

def self.post(map)
  Default.instance.post(map)
end

def self.default
  @@default_logger ||= ConsoleLogger.new(STDOUT)
end


end
end
