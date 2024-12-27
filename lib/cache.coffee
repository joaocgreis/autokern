fs = require 'node:fs/promises'
fsold = require 'fs'
os = require 'os'
path = require 'path'
crypto = require 'crypto'
util = require 'util'



CACHE_DEBUG = false



CACHE_DIR = 'cache'
console.log "Using cache dir: #{CACHE_DIR}"
fsold.mkdirSync CACHE_DIR, { recursive: true }



# If includefile is defined, it will be copied to cache and restored when there is a hit.
module.exports = (name, keys, includefile, contentfunc) ->
  hashkeys = [ name, keys..., contentfunc.toString() ]
  hash = crypto.createHash 'sha512'
  hash.update JSON.stringify hashkeys
  cache_file_name = path.join CACHE_DIR, "#{name}_#{hash.digest 'hex'}"

  debug = (op) -> if CACHE_DEBUG
    console.log "CACHE #{op} #{JSON.stringify { cache_file_name }}"
  cacheSet = () ->
    debug 'MISS and SET'
    if not util.isDeepStrictEqual hashkeys, JSON.parse JSON.stringify hashkeys
      throw new Error """
        ERROR: Constructed hashkeys cannot be used for cache
        Provided keys = #{JSON.stringify keys}
        Constructed hashkeys = #{JSON.stringify hashkeys}
        ERROR: Constructed hashkeys cannot be used for cache
        """
    content = await contentfunc()
    if includefile
      await fs.copyFile includefile, "#{cache_file_name}_file"
    await fs.writeFile cache_file_name, JSON.stringify { content, hashkeys }
    return content
  cacheHit = (cached) ->
    debug 'HIT'
    if not util.isDeepStrictEqual hashkeys, cached.hashkeys
      throw new Error """
        ERROR: CACHE COLISION
        Provided hashkeys = #{JSON.stringify hashkeys}
        Cached hashkeys   = #{JSON.stringify cached.hashkeys}
        ERROR: CACHE COLISION
        """
    if includefile
      await fs.copyFile "#{cache_file_name}_file", includefile
    return cached.content

  try
    cached = JSON.parse await fs.readFile cache_file_name
  catch
    return cacheSet()
  return cacheHit cached
