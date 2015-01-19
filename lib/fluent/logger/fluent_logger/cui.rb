require 'fluent/logger'
require 'optparse'

module Fluent
  module Logger
    class FluentLogger
      module CUI
        def post(args)
          options = {
            :port => '24224',
            :host => 'localhost'
          }

          o = OptionParser.new
          o.version = Fluent::Logger::VERSION
          o.on('-t [tag (default nil)]') {|v| options[:tag] = v }
          o.on('-p [port (default 24224)]') {|v| options[:port] = v }
          o.on('-h [host (default localhost)]') {|v| options[:host] = v }
          o.on('-v [key=value]') {|v| 
            key, value = v.split('=')
            (options[:data] ||= {})[key] = value
          }
          o.banner = 'Usage: fluent-post -t tag.foo.bar -v key1=value1 -v key2=value2'
          args = args.to_a
          args << '--help' if args.empty?
          o.parse(args)
          
          f = Fluent::Logger::FluentLogger.new(nil, {
              :host => options[:host],
              :port => options[:port]
            })

          {
            :success => f.post(options[:tag], options[:data]),
            :data    => options[:data]
          }
        end

        extend self
      end
    end
  end
end
