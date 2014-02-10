# Fluent logger
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
Fluent::Logger::FluentLogger.open('tag_prefix', :host=>'localhost', :port=24224)
```

### Console
```ruby
Fluent::Logger::ConsoleLogger.open(io)
```

### Null
```ruby
Fluent::Logger::NullLogger.open
```

|name|description|
|---|---|
|Web site|http://fluent.github.com/|
|Documents|http://fluent.github.com/doc/|
|Source repository|https://github.com/fluent/fluent-logger-ruby|
|Author|Sadayuki Furuhashi|
|Copyright|(c) 2011 FURUHASHI Sadayuki|
|License|Apache License, Version 2.0|
