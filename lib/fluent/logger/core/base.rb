require 'fluent/logger'
require 'optparse'

module Fluent
  module Logger
    module Core
      module Base

        def post(tag, map)
          raise ArgumentError.new("Second argument should kind of Hash (tag: #{map})") unless map.kind_of? Hash
          post_with_time(tag, map, Time.now)
        end

        #def post_with_time(tag, map)
        #end

        def close
        end
      end
    end
  end
end
