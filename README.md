# Lumberjack Redis Device

[![Build Status](https://travis-ci.org/bdurand/lumberjack_redis_device.svg?branch=master)](https://travis-ci.org/bdurand/lumberjack_redis_device)
[![Maintainability](https://api.codeclimate.com/v1/badges/7785eba72f9a92b686b2/maintainability)](https://codeclimate.com/github/bdurand/lumberjack_redis_device/maintainability)

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
