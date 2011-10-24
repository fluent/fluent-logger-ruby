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
  autoload :ConsoleLogger , 'fluent/logger/console_logger'
  autoload :FluentLogger  , 'fluent/logger/fluent_logger'
  autoload :LoggerBase    , 'fluent/logger/logger_base'
  autoload :TestLogger    , 'fluent/logger/test_logger'
  autoload :TextLogger    , 'fluent/logger/text_logger'

  class DefaultLogger < LoggerBase
    INSTANCE = self.new

    def self.instance
      INSTANCE
    end

    def self.new
      INSTANCE
    end

    def post(tag, map)
      Fluent::Logger.default.post(tag, map)
    end

    def close
      Fluent::Logger.default.close
    end
  end

  @@default_logger = nil

  def self.new(*args)
    if args.first.is_a?(Class) && args.first.ancestors.include?(LoggerBase)
      type = args.shift
    else
      type = FluentLogger
    end
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

  def self.post(tag, map)
    DefaultLogger.instance.post(tag, map)
  end

  def self.default
    @@default_logger ||= ConsoleLogger.new(STDOUT)
  end

  def self.default=(logger)
    @@default_logger = logger
  end
end

end
