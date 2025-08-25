# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::RedisDevice do
  let(:entry_1) { Lumberjack::LogEntry.new(Time.at(Time.now.to_f.round(6)), Logger::INFO, "message 1", "test", 12345, "foo" => "bar", "baz" => "boo") }
  let(:entry_2) { Lumberjack::LogEntry.new(Time.at(Time.now.to_f.round(6)), Logger::INFO, "message 2", "test", 12345, "foo" => "bar", "baz" => "boo") }
  let(:redis) { Redis.new }

  before :each do
    redis.flushdb
  end

  describe "registry" do
    it "should register the device" do
      expect(Lumberjack::DeviceRegistry.get(:redis)).to eq Lumberjack::RedisDevice
    end
  end

  describe "redis" do
    it "should use a redis connection" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis)
      expect(device.redis).to eq redis
    end

    it "should use a redis connection from a block" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: lambda { redis })
      expect(device.redis).to eq redis
    end
  end

  describe "write" do
    it "should write log entry to a redis list" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis)
      device.write(entry_1)
      expect(redis.llen(device.name)).to eq 1
    end
  end

  describe "read" do
    it "should read log entries from the redis list in reverse order" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis)
      device.write(entry_1)
      device.write(entry_2)
      entries = device.read

      expect(entries.size).to eq 2

      e = entries.first
      expect(e.time.to_f.round(3)).to eq entry_2.time.to_f.round(3)
      expect(e.severity).to eq entry_2.severity
      expect(e.progname).to eq entry_2.progname
      expect(e.pid).to eq entry_2.pid
      expect(e.message).to eq entry_2.message
      expect(e.attributes).to eq entry_2.attributes

      expect(entries.last.message).to eq entry_1.message
    end

    it "should read only a specified number of lines" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis)
      device.write(entry_1)
      device.write(entry_2)
      expect(device.read(1).size).to eq 1
      expect(device.read(2).size).to eq 2
      expect(device.read(3).size).to eq 2
    end
  end

  describe "limit" do
    it "should limit the number of entries in the list" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis, limit: 1)
      device.write(entry_1)
      entries = device.read
      expect(entries.size).to eq 1
      expect(entries.first.message).to eq entry_1.message

      device.write(entry_2)
      entries = device.read
      expect(entries.size).to eq 1
      expect(entries.first.message).to eq entry_2.message
    end
  end

  describe "ttl" do
    it "should set a ttl on the redis key" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis, ttl: 1)
      device.write(entry_1)
      expect(device.read.size).to eq 1
      sleep(1.1)
      expect(device.read.size).to eq 0
    end
  end

  describe "exists?" do
    it "returns true if the log exists in redis" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis)
      expect(device.exists?).to eq false
      device.write(entry_1)
      expect(device.exists?).to eq true
    end
  end

  describe "last_written_at" do
    it "returns the timestamp of the last entry" do
      device = Lumberjack::RedisDevice.new(name: "lumberjack.log", redis: redis)
      expect(device.last_written_at).to eq nil
      device.write(entry_1)
      expect(device.last_written_at).to eq entry_1.time
      device.write(entry_2)
      expect(device.last_written_at).to eq entry_2.time
    end
  end
end
