# sinatra/redis-cache

A simple redis backed cache for Sinatra applications.

## Installing

 * Add the gem to your Gemfile

   ```ruby
   source 'https://rubygems.org'
   gem 'sinatra-redis-cache'
   ```

 * Require it in your app after including Sinatra

   ```ruby
   require 'sinatra/redis-cache'
   ```

## Using in your app

Use `cache_do` anywhere you want to cache the output of a block of code.

The following will be cached for 60 seconds with the key `test-key`.

  ```ruby
  cache_do('test-key', 60) do
    'do something here'
  end
  ```

If there is an unexpired object in the cache with the same key, it will be returned. If not, the code will be executed, returned, and stored in the cache.

## Configuration

Include the following block in your app after including `sinatra/redis-cache` to configure. Defaults are shown.

```ruby
Sinatra::RedisCache::Config.config do
  redis_conn      Redis.new
  namespace       'sinatra_cache'
  default_expires 3600
  environments    [:production]
end
```
