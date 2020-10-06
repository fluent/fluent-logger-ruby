# Fluent logger

[![Build Status](https://travis-ci.org/fluent/fluent-logger-ruby.svg?branch=master)](https://travis-ci.org/fluent/fluent-logger-ruby)

A structured event logger

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-logger'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install fluent-logger

## Examples

### Simple

```ruby
require 'fluent-logger'

# API: FluentLogger.new(tag_prefix, options)
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
  # Passed records are stored into logger's internal buffer so don't re-post same event.
  p log.last_error # You can get last error object via last_error method
end

# output: myapp.access {"agent":"foo"}
```

### Tag prefix
```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new('myapp', :host => 'localhost', :port => 24224)
log.post("access", {"agent" => "foo"})

# output: myapp.access {"agent":"foo"}
```

### Nonblocking write

```ruby
require 'fluent-logger'

log = Fluent::Logger::FluentLogger.new(nil, :host => 'localhost', :port => 24224, :use_nonblock => true, :wait_writeable => false)
# When wait_writeable is false
begin
  log.post("myapp.access", {"agent" => "foo"})
rescue IO::EAGAINWaitWritable => e
  # wait code for avoding "Resource temporarily unavailable"
  # Passed records are stored into logger's internal buffer so don't re-post same event.
end

# When wait_writeable is true
unless log.post("myapp.access", {"agent" => "foo"})
  # same as other example
end

# output: myapp.access {"agent":"foo"}
```

### TLS setting

```ruby
require 'fluent-logger'

tls_opts = {
  :ca   => '/path/to/cacert.pem',
  :cert => '/path/to/client-cert.pem',
  :key  => '/path/to/client-key.pem',
  :key_passphrase => 'test'
}
log = Fluent::Logger::FluentLogger.new(nil, :host => 'localhost', :port => 24224, :tls_options => tls_opts)
```

`in_forward` config example:

```
<source>
  @type forward
  <transport tls>
    version TLS1_2
    ca_path /path/to/cacert.pem
    cert_path /path/to/server-cert.pem
    private_key_path /path/to/server-key.pem
    private_key_passphrase test
    client_cert_auth true
  </transport>
</source>
```

### Singleton
```ruby
require 'fluent-logger'

Fluent::Logger::FluentLogger.open(nil, :host => 'localhost', :port => 24224)
Fluent::Logger.post("myapp.access", {"agent" => "foo"})

# output: myapp.access {"agent":"foo"}
```

### Logger options

#### host (String)

fluentd instance host

#### port (Integer)

fluentd instance port

#### socket_path (String)

If specified, fluentd uses unix domain socket instead of TCP.

#### nanosecond_precision (Bool)

Use nano second event time instead of epoch. See also "Tips" section.

#### use_nonblock (Bool)

Use nonblocking write(`IO#write_nonblock`) instead of normal write(`IO#write`). If `Logger#post` stuck on your environment, specify `true`.  Default: `false`

#### wait_writeable (Bool)

If `false`, `Logger#post` raises an error when nonblocking write gets `EAGAIN` (i.e. `use_nonblock` must be `true`, otherwise this will have no effect).  Default: `true`

#### buffer_overflow_handler (Proc)

Pass callback for handling buffer overflow with pending data. See "Buffer overflow" section.

#### tls_options (Hash)

Pass TLS related options.

- use_default_ca: Set `true` if you want to use default CA
- ca: CA file path
- cert: Certificate file path
- key: Private key file path
- key_passphrase: Private key passphrase
- version: TLS version. Default is `OpenSSL::SSL::TLS1_2_VERSION`
- ciphers: The list of cipher suites. Default is `ALL:!aNULL:!eNULL:!SSLv2`
- insecure: Set `true` when `in_forward` uses `insecure true`

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
