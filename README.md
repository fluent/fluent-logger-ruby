# Fluent logger

[![Build Status](https://travis-ci.org/fluent/fluent-logger-ruby.svg?branch=master)](https://travis-ci.org/fluent/fluent-logger-ruby)

A structured event logger

## Examples

### Simple

```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new(nil, :host=>'localhost', :port=>24224)
unless log.post("myapp.access", {"agent"=>"foo"})
  p log.last_error # You can get last error object via last_error method
end

# output: myapp.access {"agent":"foo"}
```

### Singleton
```ruby
require 'fluent-logger'

Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)
Fluent::Logger.post("myapp.access", {"agent"=>"foo"})

# output: myapp.access {"agent":"foo"}
```

### Tag prefix
```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new('myapp', :host=>'localhost', :port=>24224)
log.post("access", {"agent"=>"foo"})

# output: myapp.access {"agent":"foo"}
```

## Loggers

### Fluent
```ruby
Fluent::Logger::FluentLogger.open('tag_prefix', :host=>'localhost', :port=>24224)
```

### Console
```ruby
Fluent::Logger::ConsoleLogger.open(io)
```

### Null
```ruby
Fluent::Logger::NullLogger.open
```

## Buffer overflow

You can inject your own custom proc to handle buffer overflow in the event of connection failure. This will mitigate the loss of data instead of simply throwing data away.

Your proc must accept a single argument, which will be the internal buffer of messages from the logger. A typical use-case for this would be writing to disk or possibly writing to Redis.

##### Example
```
class BufferOverflowHandler
  attr_accessor :buffer

  def flush(messages)
    @buffer ||= []
    messages.each do |tag, msg, option|
      @buffer << [tag, MessagePack.unpack(msg), option]
    end
  end
end

handler = Proc.new { |messages| BufferOverflowHandler.new.flush(messages) }

Fluent::Logger::FluentLogger.new(nil,
  :host => 'localhost', :port => 24224,
  :buffer_overflow_handler => handler)
```

|name|description|
|---|---|
|Web site|http://fluentd.org/|
|Documents|http://docs.fluentd.org/|
|Source repository|https://github.com/fluent/fluent-logger-ruby|
|Author|Sadayuki Furuhashi|
|Copyright|(c) 2011 FURUHASHI Sadayuki|
|License|Apache License, Version 2.0|
