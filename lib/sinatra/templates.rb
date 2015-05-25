module Sinatra 
  module Templates 
    private
    alias_method :orig_render, :render

    def render(*args, &block)
      # args [0]=engine [1]=data [2]=options [3]=locals
      key = "template/#{args[0..1].join('/')}/#{Digest::MD5.hexdigest(args[0..3].to_s)}"

      if !settings.nil? and defined?(settings.redis_cache_automatic) and settings.redis_cache_automatic
        cache_do(key) { orig_render(*args, &block) }
      else
        orig_render(*args, &block)
      end
    end
  end
end
