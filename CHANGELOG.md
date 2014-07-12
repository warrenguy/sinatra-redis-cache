## 0.2.0

Fixes:

 * `flush` no longer errors when there's nothing to flush

Improvements:

 * add methods for deleting key(s)
 * change how cache is stored in redis (breaks compatibility)
   * now uses redis hashes
   * add `properties` field to stored hash
 * add `age` method
 * implement locking on `cache_do` to prevent the same block from being
   re-run while another thread/process is already doing so

## 0.1.3

Fixes:

 * serialize/deserialize should be private methods

## 0.1.2

Fixes:

 * fix rake 'namespace' task

Improvements:

 * marshal objects properly in to redis

## 0.1.1

Fixes:

 * fix dependencies for gem

## 0.1

Initial release
