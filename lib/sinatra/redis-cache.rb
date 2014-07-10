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
        if Sinatra::RedisCache::Config.environments.include? Sinatra::Base.settings.environment
          begin
            object = get(key)
            if object
              if lock && object[:properties][:locked]
                raise SinatraRedisCacheKeyLocked
              end
              object[:object]
            else
              lock(key, lock.class == Integer ? lock : 2)
              new_object = block.call
              store(key, new_object, expires)
              new_object
            end
          rescue SinatraRedisCacheKeyLocked
            sleep ((50 + rand(100).to_f)/1000)
            retry
          end
          else
          # Just run the block without cache if we're not in an allowed environment
          block.call
        end
      end

      def get(key)
        unless (string = redis.get(key_with_namespace(key))).nil?
          deserialize(string)
        else
          false
        end
      end

      def store(key, object, expires=config.default_expires)
        properties = {
          locked:     false,
          created_at: Time.now
        }
        redis.set(key = key_with_namespace(key), serialize({properties: properties, object: object}))
        redis.expire(key, expires)
      end

      def lock(key, timeout=2)
        redis.set(key = key_with_namespace(key), serialize({properties: {locked: true}}))
        redis.expire(key, timeout)
      end

      def properties(key)
        unless (string = redis.get(key_with_namespace(key))).nil?
          deserialize(string)[:properties]
        end
      end

      def ttl(key)
        redis.ttl(key_with_namespace(key))
      end

      def all_keys(params={with_namespace: true})
        redis.keys("#{namespace}:*").map{|k| params[:with_namespace] ? k : key_without_namespace(k) }
      end

      def del(keys)
        redis.del(keys)
      end

      def flush
        del(all_keys)
      end

      private

      def config
        Sinatra::RedisCache::Config
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
      Time.now - cache.properties(key)[:created_at]
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

Sinatra::RedisCache::Config.config do
  # Set up configurable values
  parameter :redis_conn
  parameter :namespace
  parameter :default_expires
  parameter :environments
end

Sinatra::RedisCache::Config.config do
  # Default values
  redis_conn      Redis.new
  namespace       'sinatra_cache'
  default_expires 3600
  environments    [:production]
end

unless defined?(Rake).nil?
    Rake.load_rakefile("#{File.dirname(__FILE__)}/../../Rakefile")
end
