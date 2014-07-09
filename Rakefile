namespace :sinatra_cache do
  desc 'Flush the cache'
  task :flush do
    include Sinatra::RedisCache
    cache_flush
  end

  desc 'Print configured namespace'
  task :namespace do
    include Sinatra::RedisCache
    Sinatra::RedisCache.config.namespace
  end
end
