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
  def create_event(*args)
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

    m = Module.new
    m.module_eval do
      keys.each {|key|
        define_method(key) do |v|
          with(key=>v)
        end
        define_method(:"#{key}!") do |v|
          with!(key=>v)
        end
      }
      define_method(:MODULE) { m }
    end

    e = TerminalEvent.new(self, map)
    e.extend(m)
    e
  end

  #def post(map)
  #end

  #def close(map)
  #end
end


class TextLogger < LoggerBase
  def initialize
    require 'json'
    @time_format = "%b %e %H:%M:%S"
  end

  def post(map)
    a = [Time.now.strftime(@time_format), ":"]
    map.each_pair {|k,v|
      a << " #{k}="
      a << v.to_json
    }
    post_text a.join
  end

  #def post_text(text)
  #end
end


end
end
