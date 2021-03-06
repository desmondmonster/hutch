![](http://cl.ly/image/3h0q3F3G142K/hutch.png)

Hutch is a Ruby library for enabling asynchronous inter-service communication
in a service-oriented architecture, using RabbitMQ.

[![Gem Version](https://badge.fury.io/rb/hutch.png)](http://badge.fury.io/rb/hutch)
[![Build Status](https://travis-ci.org/gocardless/hutch.png?branch=master)](https://travis-ci.org/gocardless/hutch)
[![Dependency Status](https://gemnasium.com/gocardless/hutch.png)](https://gemnasium.com/gocardless/hutch)
[![Code Climate](https://codeclimate.com/github/gocardless/hutch.png)](https://codeclimate.com/github/gocardless/hutch)

To install with RubyGems:

```
$ gem install hutch
```

## Overview

Hutch is a conventions-based framework for writing services that communicate
over RabbitMQ. Hutch is opinionated: it uses topic exchanges for message
distribution and makes some assumptions about how consumers and publishers
should work.

Hutch uses [Bunny](http://rubybunny.info) under the hood.

## Fork Notes

This fork adds support for connecting to multiple brokers, daemonizing the
Hutch executable, running consumers from within a Padrino project, and
a handful of other tweaks


## Defining Consumers

Consumers receive messages from a RabbitMQ queue. That queue may be bound to
one or more topics (represented by routing keys).

To create a consumer, include the `Hutch::Consumer` module in a class that
defines a `#process` method. `#process` should take a single argument, which
will be a `Message` object. The `Message` object encapsulates the message data,
along with any associated metadata. To access properties of the message, use
Hash-style indexing syntax:

```ruby
message[:id]  # => "02ABCXYZ"
```

To subscribe to a topic, pass a routing key to `consume` in the class
definition. To bind to multiple routing keys, simply pass extra routing keys
in as additional arguments. Refer to the [RabbitMQ docs on topic exchanges
][topic-docs] for more information about how to use routing keys. Here's an
example consumer:

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

By default, the queue name will be named using the consumer class. You can set
the queue name explicitly by using the `queue_name` method:

```ruby
class FailedPaymentConsumer
  include Hutch::Consumer
  consume 'gc.ps.payment.failed'
  queue_name 'failed_payments'

  def process(message)
    mark_payment_as_failed(message[:id])
  end
end
```

If you are using Hutch with Rails and want to make Hutch log to the Rails
logger rather than `stdout`, add this to `config/initializers/hutch.rb`

```ruby
Hutch::Logging.logger = Rails.logger
```

See this [RabbitMQ tutorial on topic exchanges](http://www.rabbitmq.com/tutorials/tutorial-five-ruby.html)
to learn more.


## Running Hutch

After installing the Hutch gem, you should be able to start it by simply
running `hutch` on the command line. `hutch` takes a number of options:

```console
$ hutch -h
usage: hutch [options]
        --mq-host HOST               Set the RabbitMQ host
        --mq-port PORT               Set the RabbitMQ port
    -t, --[no-]mq-tls                Use TLS for the AMQP connection
        --mq-tls-cert FILE           Certificate  for TLS client verification
        --mq-tls-key FILE            Private key for TLS client verification
        --mq-exchange EXCHANGE       Set the RabbitMQ exchange
        --mq-vhost VHOST             Set the RabbitMQ vhost
        --mq-username USERNAME       Set the RabbitMQ username
        --mq-password PASSWORD       Set the RabbitMQ password
        --mq-api-host HOST           Set the RabbitMQ API host
        --mq-api-port PORT           Set the RabbitMQ API port
    -s, --[no-]mq-api-ssl            Use SSL for the RabbitMQ API
    -d, --daemonize                  Run Hutch as a background process
        --config FILE                Load Hutch configuration from a file
        --require PATH               Require a Rails or Padrino app or path
        --[no-]autoload-app          Require the current app directory
        --logfile FILE               Log output to a file
    -q, --quiet                      Quiet logging
    -v, --verbose                    Verbose logging
        --version                    Print the version and exit
    -h, --help                       Show this message and exit
```

The first three are for configuring which RabbitMQ instance to connect to.
`--require` is covered in the next section. Configurations can also be
specified in a YAML file by passing the file location to the `--config`
option.  This is recommended over passing many arguments on the command line,
especially when running Hutch as a daemon.  The file should look like:

```yaml
mq_username: peter
mq_password: rabbit
mq_host: broker.yourhost.com
mq_vhost: <%= ENV['RACK_ENV'] == 'production' ? 'production' : '/' %>
```

Note the hypens are now underscores.  Passing a setting as a command-line
option will overwrite what's specified in the config file, allowing for
run-time customization.



### Loading Consumers

Hutch can be easily used with a Rails or Padrino app. Either start Hutch in the working
directory of the app, or pass the path to an app in with the
`--require` option. Consumers defined in Rails apps should be placed with in
the `app/consumers/` directory, to allow them to be auto-loaded when Rails
boots.  Consumers in a Padrino app should be placed in `shared/lib/consumers`.

To require files that define consumers manually, simply pass each file as an
option to `--require`. Hutch will automatically detect whether you've provided
a Rails app or a standard file, and take the appropriate behaviour:

```bash
$ hutch --require path/to/app        # loads a rails or padrino app
$ hutch --require path/to/file.rb    # loads a ruby file
$ hutch                              # loads the current directory as a rails/padrino app
```

## Producers

Hutch includes a `publish` method for sending messages to Hutch consumers. When
possible, this should be used, rather than directly interfacing with RabbitMQ
libraries.

This fork allows you to publish to many different exchanges on your broker, which
is useful if you have separate exchanges for events, logs, worker queues, etc.
Simply add an `exchange: '<exchange-name>'` option to the `publish` method and
Hutch will declare it as a topic exchange, if it hasn't been declared already,
and publish your message there.  Omitting this option will publish to the 
exchange declared in your Hutch configuration, making this branch a drop-in
replacement for the original.

```ruby
Hutch.connect
Hutch.publish('routing.key', subject: 'payment', action: 'received') # => publishes to exchange specified in configs
Hutch.publish('routing.key', subject: 'payment', action: 'received', exchange: 'events') # => publishes to exchange named 'events'
```

The exchange is declared the first time you publish to a named exchange in this way.
Nothing else needs to be done to connect to it.  Hutch maintains a pool of known 
exchanges under the hood, so you only incur the connection cost the first time you
publish.


### Writing Well-Behaved Publishers

You may need to send messages to Hutch from languages other than Ruby. This
prevents the use of `Hutch.publish`, requiring custom publication code to be
written. There are a few things to keep in mind when writing producers that
send messages to Hutch.

- Make sure that the producer exchange name matches the exchange name that
  Hutch is using.
- Hutch works with topic exchanges, check the producer is also using topic
  exchanges.
- Use message routing keys that match those used in your Hutch consumers.
- Be sure your exchanges are marked as durable. In the Ruby AMQP gem, this is
  done by passing `durable: true` to the exchange creation method.
- Mark your messages as persistent. This is done by passing `persistent: true`
  to the publish method in Ruby AMQP.
- Wrapping publishing code in transactions or using publisher confirms is
  highly recommended. This can be slightly tricky, see [this issue][pc-issue]
  and [this gist][pc-gist] for more info.

Here's an example of a well-behaved publisher, minus publisher confirms:

```ruby
AMQP.connect(host: config[:host]) do |connection|
  channel  = AMQP::Channel.new(connection)
  exchange = channel.topic(config[:exchange], durable: true)

  message = JSON.dump({ subject: 'Test', id: 'abc' })
  exchange.publish(message, routing_key: 'test', persistent: true)
end
```

## Running in the Background

Hutch can be run as a daemon by passing the `-d` or `--daemonize` option to
the `hutch` command.  If you do this, it's a good idea to set a logfile
for Hutch to send output to, otherwise your output will be redirected
to `/dev/null` and the messages lost.

A pidfile will be written to `tmp/hutch.pid`.  You can change the location
by adding a `pidfile: <your-pidfile>` setting to your config file.


## Supported RabbitMQ Versions

Hutch requires RabbitMQ 2.x or later. 3.x releases
are recommended.


[pc-issue]: https://github.com/ruby-amqp/amqp/issues/92
[pc-gist]: https://gist.github.com/3042381

---
