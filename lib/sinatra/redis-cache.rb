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

    class RedisCache
      def do(key, expires, params={}, block)
        key = key_with_namespace(key)
        if Sinatra::RedisCache::Config.environments.include? Sinatra::Base.settings.environment
          object = get(key)
          if object
            object
          else
            object = block.call
            store(key, object, expires)
            object
          end
        else
          # Just run the block without cache if we're not in an allowed environment
          block.call
        end
      end

      def get(key, params={})
        key = key_with_namespace(key)
        redis.get(key)
      end

      def store(key, value, expires, params={})
        key = key_with_namespace(key)
        expires = expires || config.default_expires
        redis.set(key, value)
        redis.expire(key, expires)
      end

      def flush
        redis.del(all_keys)
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

      def all_keys
        redis.keys(namespace + '*')
      end
    end

    def cache_do(key, expires=nil, params={}, &block)
      cache = RedisCache.new
      cache.do(key, expires, params, block)
    end

    def cache_get(key, params={})
      cache = RedisCache.new
      cache.get(key, params)
    end

    def cache_store(key, value, expires, params={})
      cache = RedisCache.new
      cache.store(key, value, expires, params)
    end

    def cache_flush
      cache = RedisCache.new
      cache.flush
    end

  end

  helpers RedisCache
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
