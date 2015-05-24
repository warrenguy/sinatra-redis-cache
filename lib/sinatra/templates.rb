module Sinatra 
  module Templates 
    private
    alias_method :orig_render, :render

    def render(*args, &block)
      key = 'auto/' + Digest::SHA256.hexdigest(args.to_s)
      cache_do(key) { orig_render(*args, &block) }
    end
  end
end
