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
      def do(key, expires, lock, block)
        debug_log "do #{key_without_namespace(key)}"
        if Sinatra::RedisCache::Config.environments.include? Sinatra::Base.settings.environment
          try = 0
          begin
            redis.watch(key = key_with_namespace(key)) do |watched|
              object = get(key)
              unless object.empty?
                if lock && object['locked']
                  raise SinatraRedisCacheKeyLocked
                end
                object['object']
              else
                if lock then lock_key(key, watched, lock.class == Integer ? lock : 2) end
                new_object = block.call
                store(key, new_object, expires)
                new_object
              end
            end
          rescue SinatraRedisCacheKeyLocked
            sleeptime = (((try += 1)*50 + rand(100).to_f)/1000)
            debug_log "key is locked, waiting #{sleeptime}s for retry ##{try}."
            sleep sleeptime
            retry
          rescue SinatraRedisCacheKeyAlreadyLocked
            sleeptime = (((try += 1)*50 + rand(100).to_f)/1000)
            debug_log "failed to obtain lock, waiting #{sleeptime}s for retry ##{try}."
            sleep sleeptime
            retry
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

      def store(key, object, expires=config.default_expires)
        debug_log "store #{key_without_namespace(key)}"
        properties = { created_at: Time.now.utc.to_i }
        redis.watch(key = key_with_namespace(key)) do |watched|
          watched.multi do |multi|
            multi.hset(key, 'object',     serialize(object))
            multi.hset(key, 'properties', serialize(properties))
            multi.hdel(key, 'locked')
            multi.expire(key, expires)
          end
        end
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

      def lock_key(key, redis, timeout=2)
        debug_log "locking #{key_without_namespace(key)}"
        unless redis.multi do |multi|
          multi.hsetnx(key, 'locked', serialize(true))
          multi.expire(key, timeout)
        end.eql? [true,true]
          raise SinatraRedisCacheKeyAlreadyLocked
        end

      end
    end

    def cache_do(key, expires=nil, lock=false, &block)
      cache = Cache.new
      cache.do(key, expires, lock, block)
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
  parameter :environments
  parameter :logger
end

Sinatra::RedisCache::Config.config do
  # Default values
  redis_conn      Redis.new
  namespace       'sinatra_cache'
  default_expires 3600
  environments    [:production]
  logger          Logger.new(STDERR)
end

unless defined?(Rake).nil?
    Rake.load_rakefile("#{File.dirname(__FILE__)}/../../Rakefile")
end
