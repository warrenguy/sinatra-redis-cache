module Sinatra 
  module Templates 
    private
    alias_method :orig_render, :render

    def render(*args, &block)
      key = 'auto/' + Digest::SHA256.hexdigest(args.to_s)
      if !settings.nil? and defined?(settings.redis_cache_automatic) and settings.redis_cache_automatic
        cache_do(key) { orig_render(*args, &block) }
      else
        orig_render(*args, &block)
      end
    end
  end
end
