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
  KEYS = []
  DEFAULT_VALUES = {}
  LOGGER = nil

  def initialize(logger=self.class::LOGGER)
    @logger = logger || Logger.default
    @map = self.class::DEFAULT_VALUES.dup
  end

  attr_accessor :map

  def +(e)
    @map.merge!(e)
    self
  end

  def [](k)
    @map[k.to_sym]
  end

  def []=(k, v)
    @map[k.to_sym] = v
  end

  def post!
    @logger.post_defined(self.class, @map)
    self
  end

  alias post post!

  def with(a)
    if a.is_a?(Class) && a.ancestors.include?(Event)
      return (self.class + a).with(self)
    end
    map = case a
      when Event
        a.map
      else
        a
      end
    @map.merge!(map)
    self
  end

  class << self
    def post!
      new.post!
    end

    alias post post!

    def with(a)
      if a.is_a?(Class) && a.ancestors.include?(Event)
        return self + a
      end
      map = case a
        when Event
          a.map
        else
          a
        end

      nmap = self::DEFAULT_VALUES.merge(map)
      name = "#{self.name}+#{map.keys.join('+')}"

      c = Class.new(self) do
        const_set(:DEFAULT_VALUES, nmap)
      end
      (class<<c;self;end).module_eval do
        define_method(:name) do
          name
        end
      end

      c
    end

    def +(other)
      keys = self::KEYS + other::KEYS
      map = self::DEFAULT_VALUES.merge(other::DEFAULT_VALUES)
      name = "#{self.name}+#{other.name}"

      c = self::LOGGER.define_event(*(keys << map))
      (class<<c;self;end).module_eval do
        define_method(:name) do
          name
        end
      end

      c
    end
  end
end


end
end
