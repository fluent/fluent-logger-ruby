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


class Event
  def initialize(link, map)
    @link = link
    @map = map
  end

  def to_hash(o={})
    @link.to_hash(o)
    o.merge!(@map)
    o
  end

  def logger
    @link.logger
  end

  def logger=(logger)
    @link.logger = logger
  end

  def post!
    logger.post(to_hash)
    self
  end

  alias post post!

  def with(a)
    if a.is_a?(Event)
      ma = MODULE()
      mb = a.MODULE()
      m = Module.new
      m.module_eval do
        include ma
        include mb
        define_method(:MODULE) { m }
      end
      map = a.to_hash(to_hash)
      e = TerminalEvent.new(LOGGER(), map)
      e.extend(m)
    else
      map = a.to_hash
      e = Event.new(self, map)
      e.extend(MODULE())
    end
    e
  end

  alias + with

  def with!(a)
    if a.is_a?(Event)
      self.extend a.MODULE()
      a.to_hash(@map)
    else
      @map.merge!(a.to_hash)
    end
    self
  end

  def create_event(*args)
    self.with(LOGGER().create_event(*args))
  end

  def LOGGER
    @link.LOGGER()
  end
end


class TerminalEvent < Event
  def initialize(logger, map)
    @logger = logger
    @map = map
  end

  def to_hash(o={})
    o.merge!(@map)
    o
  end

  attr_accessor :logger

  def LOGGER
    @logger
  end
end


end
end
