require 'sinatra/base'
require 'redis'

module Sinatra

  module RedisCache

    module Config
      extend self

      def parameter(*names)
        names.each do |name|
          attr_accessor name

          define_method name do |*values|
            value = values.first
            if value
              self.send("#{name}=", value)
            else
              instance_variable_get("@#{name}")
            end
          end
        end
      end

      def config(&block)
        instance_eval &block
      end
    end

    class Cache
      def do(key, expires=config.default_expires, grace=config.default_grace, block)
        debug_log "do #{key_without_namespace(key)}"
        if Sinatra::RedisCache::Config.environments.include? Sinatra::Base.settings.environment
          try = 0
          starttime = Time.now.utc.to_i
          begin
            redis.watch(key = key_with_namespace(key)) do |watched|
              object = get(key)
              unless object.empty?
                if object['locked']
                  raise SinatraRedisCacheKeyLocked
                else
                  if (
                    ((Time.now.utc.to_i - object['properties'][:created_at]) > expires) &&
                    ((Time.now.utc.to_i - object['properties'][:created_at]) < (expires + grace))
                  )
                    unless lock_key(key, watched, config.lock_timeout, 'update_lock') == false
                      Thread.new { grace_store(key, block, expires, grace) }
                    end
                  end
                  object['object']
                end
              else
                if lock_key(key, watched, config.lock_timeout) == false
                  raise SinatraRedisCacheKeyAlreadyLocked
                else
                  new_object = block.call
                  Thread.new { store(key, new_object, expires, grace) }.priority=3
                  new_object
                end
              end
            end
          rescue SinatraRedisCacheKeyLocked
            redis.unwatch
            sleeptime = (((try += 1)*50 + rand(100).to_f)/1000)
            debug_log "key is locked, waiting #{sleeptime}s for retry ##{try}."
            sleep sleeptime
            retry if (Time.now.utc.to_i - starttime) < (config.lock_timeout * 2)
          rescue SinatraRedisCacheKeyAlreadyLocked
            redis.unwatch
            sleeptime = (((try += 1)*50 + rand(100).to_f)/1000)
            debug_log "failed to obtain lock, waiting #{sleeptime}s for retry ##{try}."
            sleep sleeptime
            retry if (Time.now.utc.to_i - starttime) < (config.lock_timeout * 2)
          end
        else
          # Just run the block without cache if we're not in an allowed environment
          block.call
        end
      end

      def get(key)
        debug_log "get #{key_without_namespace(key)}"
        unless (hash = redis.hgetall(key_with_namespace(key))).nil?
          hash.each{|k,v| hash[k]=deserialize(v)}
        else
          false
        end
      end

      def store(key, object, expires=config.default_expires, grace=config.default_grace)
        debug_log "store #{key_without_namespace(key)}"
        properties = { created_at: Time.now.utc.to_i }
        redis.watch(key = key_with_namespace(key)) do |watched|
          watched.multi do |multi|
            multi.hset(key, 'object',     serialize(object))
            multi.hset(key, 'properties', serialize(properties))
            multi.hdel(key, ['locked', 'update_locked'])
            multi.expire(key, expires + grace)
          end
        end
      end

      def grace_store(key, proc, expires=config.default_expires, grace=config.default_grace)
        debug_log "grace store #{key_without_namespace(key)}"
        new_object = proc.call
        store(key, new_object, expires, grace)
      end

      def properties(key)
        unless (string = redis.hget(key_with_namespace(key), 'properties')).nil?
          deserialize(string)
        end
      end

      def ttl(key)
        redis.ttl(key_with_namespace(key))
      end

      def all_keys(params={with_namespace: true})
        redis.keys("#{namespace}:*").map{|k| params[:with_namespace] ? k : key_without_namespace(k) }
      end

      def del(keys)
        debug_log "del #{keys.map{|k| key_without_namespace(k)}}"
        redis.del(keys)
      end

      def flush
        unless (keys = all_keys).empty?
          del(keys)
        end
      end

      private

      def config
        Sinatra::RedisCache::Config
      end

      def debug_log(message)
        if config.logger
          config.logger.debug("sinatra-redis-cache/#{Process.pid}/#{Thread.current.__id__}") { message }
        end
      end

      def redis
        config.redis_conn
      end

      def namespace
        config.namespace
      end

      def key_with_namespace(key)
        if key.start_with? namespace
          key
        else
          "#{namespace}:#{key}"
        end
      end

      def key_without_namespace(key)
        if key.start_with? namespace
          key.gsub(/^#{namespace}:/,'')
        else
          key
        end
      end

      def serialize(object)
        Marshal.dump(object)
      end

      def deserialize(string)
        Marshal.load(string)
      end

      def lock_key(key, redis, timeout=config.lock_timeout, lock_name='locked')
        debug_log "locking #{key_without_namespace(key)} for #{timeout}s [#{lock_name}]"
        unless redis.multi do |multi|
          multi.hsetnx(key, lock_name, serialize(true))
          multi.expire(key, timeout)
        end.eql? [true,true]
          false
        end
      end
    end

    def cache_do(key, expires=nil, &block)
      cache = Cache.new
      cache.do(key, expires, block)
    end

    def cache_get(key)
      cache = Cache.new
      cache.get(key)
    end

    def cache_key_properties(key)
      cache = Cache.new
      cache.properties(key)
    end

    def cache_key_age(key)
      cache = Cache.new
      Time.now.utc.to_i - cache.properties(key)[:created_at]
    end

    def cache_key_ttl(key)
      cache = Cache.new
      cache.ttl(key)
    end

    def cache_store(key, value, expires=nil)
      cache = Cache.new
      cache.store(key, value, expires)
    end

    def cache_list_keys
      cache = Cache.new
      cache.all_keys(with_namespace: false)
    end

    def cache_del(keys)
      cache = Cache.new
      cache.del(keys)
    end

    def cache_flush
      cache = Cache.new
      cache.flush
    end

  end

  helpers RedisCache
end

class SinatraRedisCacheKeyLocked < Exception
end

class SinatraRedisCacheKeyAlreadyLocked < Exception
end

Sinatra::RedisCache::Config.config do
  # Set up configurable values
  parameter :redis_conn
  parameter :namespace
  parameter :default_expires
  parameter :default_grace
  parameter :lock_timeout
  parameter :environments
  parameter :logger
end

Sinatra::RedisCache::Config.config do
  # Default values
  redis_conn      Redis.new
  namespace       'sinatra_cache'
  default_expires 3600
  default_grace   60
  lock_timeout    5
  environments    [:production]
  logger          Logger.new(STDERR)
end

unless defined?(Rake).nil?
    Rake.load_rakefile("#{File.dirname(__FILE__)}/../../Rakefile")
end
