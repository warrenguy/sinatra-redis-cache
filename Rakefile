namespace :sinatra_cache do
  desc 'Flush the cache'
  task :flush do
    include Sinatra::RedisCache
    cache_flush
  end

  desc 'Print configured namespace'
  task :namespace do
    puts Sinatra::RedisCache::Config.namespace
  end

  desc 'Show all cache keys'
  task :list_keys do
    include Sinatra::RedisCache
    puts cache_list_keys.map{|k| "#{k} [age: #{cache_key_age(k).to_i}, ttl: #{cache_key_ttl(k)}]"}
  end
end
