require 'sinatra/base'
require 'redis'

require 'sinatra/templates'

module Sinatra

  module RedisCache

    module Helpers

      def cache_do(key, expires=settings.redis_cache_default_expires, &block)
        raise ArgumentError, "No block given" unless block_given?

        if settings.redis_cache_environments.include? settings.environment
          settings.redis_cache_connection.watch(key_with_namespace(key)) do |watched|
            cache_item = cache_get(key)

            unless cache_item.empty?
              return cache_item['object']
            else
              new_cache_item = block.call
              cache_store(key, new_cache_item, expires)
              return new_cache_item
            end
          end
        else
          return block.call
        end
      end

      def cache_get(key)
        unless (hash = settings.redis_cache_connection.hgetall(key_with_namespace(key))).nil?
          return hash.each{|k,v| hash[k]=deserialize(v)}
        else
          return nil
        end
      end

      def cache_store(key, object, expires)
        properties = { 'created_at' => Time.now.utc.to_i }
        settings.redis_cache_connection.watch(key = key_with_namespace(key)) do |watched|
          watched.multi do |multi|
            multi.hset(key, 'object',     serialize(object))
            multi.hset(key, 'properties', serialize(properties))
            multi.expire(key, expires)
          end
        end
      end

      private

      def key_with_namespace(key)
        settings.redis_cache_namespace + ':' + key
      end

      def key_without_namespace(key)
        if key.start_with? settings.redis_cache_namespace
          return key.gsub(/^#{namespace}:/,'')
        else
          return key
        end
      end

      def serialize(object)
        Marshal.dump(object)
      end

      def deserialize(string)
        Marshal.load(string)
      end

    end

    def self.registered(app)
      app.helpers RedisCache::Helpers

      app.set :redis_cache_default_expires, 60
      app.set :redis_cache_environments,    [:production, :development]
      app.set :redis_cache_namespace,       'redis_cache'
      app.set :redis_cache_connection,      Redis.new
      app.set :redis_cache_automatic,       false

      ## add the extension specific options to those inspectable by :settings_inspect method
      if app.respond_to?(:sinatra_settings_for_inspection)
        %w( redis_cache_default_expires redis_cache_environments redis_cache_namespace redis_cache_connection redis_cache_automatic ).each do |m|
          app.sinatra_settings_for_inspection << m
        end
      end

    end

  end

end
