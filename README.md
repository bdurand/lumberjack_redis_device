# Lumberjack Redis Device

[![Continuous Integration](https://github.com/bdurand/lumberjack_redis_device/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/lumberjack_redis_device/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/lumberjack_redis_device.svg)](https://badge.fury.io/rb/lumberjack_redis_device)

This is a simple reference implementation of a device for the [lumberjack](https://github.com/bdurand/lumberjack) to send logs to a data store.

Log data will be stored in a Redis list. This will likely not scale to handle permanent or large log storage, but it can be useful as a temporary store in log shipment, or as a debug tool for seeing only recent log entries.

The number of entries in the list can be capped with the `:limit` paramter on the constructor. An expiration time can also be set on the redis key as well with the `:ttl` parameter.

```ruby
# create a device to save to the app.log key in redis
# with a limit of 1000 entries that expires one hour after the last write.
device = Lumberjack::RedisDevice.new("app.log", redis: Redis.new, limit: 1000, ttl: 3600)
```

The log entries can then be read out again with the `read` method. The result will be an array of `Lumberjack::LogEntry` objects in the reverse order that they were written in (i.e. newest first).

```ruby
entries = device.read
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem "lumberjack_redis_device"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install lumberjack_redis_device
```

## Contributing

Open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

You'll need a redis server running to run the tests. You can spin one up using Docker:

```bash
$ docker run --rm -p 6379:6379 redis
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
