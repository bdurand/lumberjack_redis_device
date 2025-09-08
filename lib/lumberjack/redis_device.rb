# frozen_string_literal: true

require "lumberjack"
require "redis"
require "json"

# Lumberjack logging framework with device support for Redis
module Lumberjack
  # This Lumberjack device logs output to a redis list. The redis list will automatically truncate
  # to a given size to prevent running out of memory on the server. This is not intended to be a
  # scalable logging solution, but it can be useful as an additional logging tool to expose recent logs.
  class RedisDevice < Device
    VERSION = ::File.read(::File.join(__dir__, "..", "..", "VERSION")).strip.freeze

    DeviceRegistry.add(:redis, self)

    attr_reader :name, :ttl, :limit

    # Create a device. The name will be used as the key for the log entries in redis.
    #
    # The redis object can either be a `Redis` instance or a block that yields a `Redis`
    # instance.
    #
    # You can also specify a time to live in seconds (ttl) and set the limit for the size of the list.
    def initialize(name:, redis:, limit: 10_000, ttl: nil)
      @name = name
      @redis = redis
      @ttl = ttl.to_i
      @limit = limit
    end

    # Write an entry to the list in redis
    def write(entry)
      data = entry_as_json(entry)
      json = dump_json(data)
      redis.multi do |transaction|
        transaction.lpush(name, json)
        transaction.ltrim(name, 0, limit - 1)
        transaction.expire(name, ttl) if ttl && ttl > 0
      end
    end

    # Read a set number of entries from the list. The result will be an array of
    # Lumberjack::LogEntry objects.
    def read(count = limit)
      docs = redis.lrange(name, 0, count - 1)
      docs.collect { |json| entry_from_json(json) }
    end

    # Return true if the logs exist in redis. Will return false if the
    # logs have expired.
    def exists?
      retval = redis.exists(name)
      if retval.is_a?(Integer)
        retval = (retval > 0)
      end
      retval
    end

    # Return the timestamp of the last log entry.
    def last_written_at
      entry = read(1).first
      entry&.time
    end

    # Get the datetime format used for formatting time values in log entries.
    # @return [String, nil] the datetime format string, or nil if no custom format is set
    def datetime_format
      @time_formatter&.format
    end

    # Set the datetime format for formatting time values in log entries.
    # @param format [String] the datetime format string to use for time formatting
    def datetime_format=(format)
      @time_formatter = Lumberjack::Formatter::DateTimeFormatter.new(format)
    end

    # Get the Redis connection instance.
    # @return [Redis] the Redis connection, either from the stored instance or by calling the proc
    def redis
      if @redis.is_a?(Proc)
        @redis.call
      else
        @redis
      end
    end

    private

    def entry_as_json(entry)
      data = {}
      set_attribute(data, "timestamp", entry.time.to_f) unless entry.time.nil?
      set_attribute(data, "time", entry.time)
      set_attribute(data, "severity", entry.severity_label)
      set_attribute(data, "progname", entry.progname)
      set_attribute(data, "pid", entry.pid)
      set_attribute(data, "message", entry.message)
      set_attribute(data, "attributes", entry.attributes)

      data = @formatter.format(data) if @formatter
      data
    end

    def entry_from_json(json)
      data = JSON.parse(json)
      time = Time.at(data["timestamp"]) if data["timestamp"]
      severity = data["severity"]
      progname = data["progname"]
      pid = data["pid"]
      message = data["message"]
      attributes = data["attributes"] || data["tags"] # Fallback to tags for compatibility with 1.x format
      LogEntry.new(time, severity, message, progname, pid, attributes)
    end

    def set_attribute(data, key, value)
      return if value.nil?

      if (value.is_a?(Time) || value.is_a?(DateTime)) && @time_formatter
        value = @time_formatter.call(value)
      end

      if key.is_a?(Array)
        unless key.empty?
          if key.size == 1
            data[key.first] = value
          else
            data[key.first] ||= {}
            set_attribute(data[key.first], key[1, key.size], value)
          end
        end
      elsif key.respond_to?(:call)
        hash = key.call(value)
        if hash.is_a?(Hash)
          data.merge!(hash)
        end
      else
        data[key] = value unless key.nil?
      end
    end

    def default_formatter
      formatter = Lumberjack::Formatter.new.clear
      object_formatter = Lumberjack::Formatter::ObjectFormatter.new
      formatter.add(String, object_formatter)
      formatter.add(Object, object_formatter)
      formatter.add(Enumerable, Formatter::StructuredFormatter.new(formatter))
      formatter.add(Exception, Formatter::InspectFormatter.new)
    end

    def dump_json(data)
      JSON.generate(json_safe(data))
    end

    def json_safe(value)
      return nil if value.nil?

      # Check if the as_json method is defined takes no parameters
      as_json_arity = value.method(:as_json).arity if value.respond_to?(:as_json)

      if as_json_arity == 0 || as_json_arity == -1
        value.as_json
      elsif value.is_a?(Hash)
        value.transform_values { |v| json_safe(v) }
      elsif value.is_a?(Enumerable)
        value.collect { |v| json_safe(v) }
      else
        value
      end
    end
  end
end
