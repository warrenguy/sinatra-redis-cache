module Sinatra 
  module Templates 
    private
    alias_method :orig_render, :render

    def render(*args)
      key = 'auto/' + Digest::SHA256.hexdigest(args.to_s)
      cache_do(key) { orig_render(*args) }
    end
  end
end
