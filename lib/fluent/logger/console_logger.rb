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
require 'fluent/logger/text_logger'

module Fluent
  module Logger
    class ConsoleLogger < TextLogger
      def initialize(out)
        super()
        require 'time'

        if out.is_a?(String)
          @io = File.open(out, "a")
          @on_reopen = Proc.new { @io.reopen(out, "a") }
        elsif out.respond_to?(:write)
          @io = out
          @on_reopen = Proc.new { }
        else
          raise "Invalid output: #{out.inspect}"
        end
      end

      attr_accessor :time_format

      def reopen!
        @on_reopen.call
      end

      def post_text(text)
        @io.puts text
      end

      def close
        @io.close unless @io == STDOUT
        self
      end
    end
  end
end
