# Fluent logger

[![Build Status](https://travis-ci.org/fluent/fluent-logger-ruby.svg?branch=master)](https://travis-ci.org/fluent/fluent-logger-ruby)

A structured event logger

## Examples

### Simple

```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new(nil, :host => 'localhost', :port => 24224)
unless log.post("myapp.access", {"agent" => "foo"})
  p log.last_error # You can get last error object via last_error method
end

# output: myapp.access {"agent":"foo"}
```

### UNIX socket

```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new(nil, :socket_path => "/tmp/fluent.sock")
unless log.post("myapp.access", {"agent" => "foo"})
  p log.last_error # You can get last error object via last_error method
end

# output: myapp.access {"agent":"foo"}
```

### Singleton
```ruby
require 'fluent-logger'

Fluent::Logger::FluentLogger.open(nil, :host => 'localhost', :port => 24224)
Fluent::Logger.post("myapp.access", {"agent" => "foo"})

# output: myapp.access {"agent":"foo"}
```

### Tag prefix
```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new('myapp', :host => 'localhost', :port => 24224)
log.post("access", {"agent" => "foo"})

# output: myapp.access {"agent":"foo"}
```

### Standard ::Logger compatible interface

#### Example1

```ruby
require 'fluent-logger'
f = Fluent::Logger::LevelFluentLogger.new('fluent')

f.info("some application running.")
# output: fluent.info: {"level":"INFO","message":"some application running."}

f.warn("some application running.")
# output: fluent.warn: {"level":"WARN","message":"some application running."}
```

#### Example2(add progname)

```ruby
require 'fluent-logger'
f = Fluent::Logger::LevelFluentLogger.new('fluent')
f.info("some_application") {"some application running."}
# output: fluent.info: {"level":"INFO","message":"some application running.","progname":"some_application"}
```

#### Example3(set log level)

```ruby
require 'fluent-logger'
f = Fluent::Logger::LevelFluentLogger.new('fluent')
f.level = Logger::WARN
f.info("some_application") {"some application running."}
```

Log level is ERROR so no output.

default log level is debug.


#### Example4(customize format for Rails)

```ruby
require 'fluent-logger'
f = Fluent::Logger::LevelFluentLogger.new('fluent')

f.formatter = proc do |severity, datetime, progname, message|
  map = { level: severity }
  map[:message] = message if message
  map[:progname] = progname if progname
  map[:stage] = ENV['RAILS_ENV']
  map[:service_name] = "SomeApp"
  map
end

f.info("some_application"){"some application running."}
# output: fluent.info: {"level":"INFO","message":"some application running.","progname":"some_application","stage":"production","service_name":"SomeApp"}
```

## Loggers

### Fluent
```ruby
Fluent::Logger::FluentLogger.open('tag_prefix', :host => 'localhost', :port => 24224)
```

### Console
```ruby
Fluent::Logger::ConsoleLogger.open(io)
```

### Null
```ruby
Fluent::Logger::NullLogger.open
```

## Tips

### Use nanosecond-precision time

To send events with nanosecond-precision time (Fluent 0.14 and up), specify `nanosecond_precision` to `FluentLogger` constructor.

```rb
log = Fluent::Logger::FluentLogger.new(nil, :host => 'localhost', :port => 24224, :nanosecond_precision => true)
# Use nanosecond time instead
log.post("myapp.access", {"agent" => "foo"})
log.post_with_time("myapp.access", {"agent" => "foo"}, Time.now) # Need Time object for post_with_time
```

### Buffer overflow

You can inject your own custom proc to handle buffer overflow in the event of connection failure. This will mitigate the loss of data instead of simply throwing data away.

Your proc must accept a single argument, which will be the internal buffer of messages from the logger. A typical use-case for this would be writing to disk or possibly writing to Redis.

##### Example
```
class BufferOverflowHandler
  attr_accessor :buffer

  def flush(messages)
    @buffer ||= []
    MessagePack::Unpacker.new.feed_each(messages) do |msg|
      @buffer << msg
    end
  end
end

handler = Proc.new { |messages| BufferOverflowHandler.new.flush(messages) }

Fluent::Logger::FluentLogger.new(nil,
  :host => 'localhost', :port => 24224,
  :buffer_overflow_handler => handler)
```

## Information

|name|description|
|---|---|
|Web site|http://fluentd.org/ |
|Documents|http://docs.fluentd.org/ |
|Source repository|https://github.com/fluent/fluent-logger-ruby |
|Author|Sadayuki Furuhashi|
|Copyright|(c) 2011 FURUHASHI Sadayuki|
|License|Apache License, Version 2.0|
