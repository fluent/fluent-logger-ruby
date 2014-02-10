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
    class TestLogger < LoggerBase
      def initialize(queue=[])
        @queue = queue
        @max = 1024
      end

      attr_accessor :max
      attr_reader :queue

      def post_with_time(tag, map, time)
        while @queue.size > @max-1
          @queue.shift
        end
        (class<<map;self;end).module_eval do
          define_method(:tag) { tag }
          define_method(:time) { time }
        end
        @queue << map
        true
      end

      def tag_queue(tag)
        @queue.find_all {|map| map.tag == tag }
      end

      def close
      end
    end
  end
end
