Image = require './image'
{ toImg } = require './teximg'



ALGO_DEBUG = false

ALGO_BLUR = 10
ALGO_THRESHOLD = 128
ALGO_GROW = 50
ALGO_GROW_HADD = 0
ALGO_GROW_HSTRECH = 2



kernWorker = (prefix, left, right, tmpf, RUN_KERN, FONT, fontsha, CACHE_DIR) ->
  (not prefix) and throw new Error "ERROR: worker missing expected prefix"
  (not left) and throw new Error "ERROR: worker missing expected left"
  (not right) and throw new Error "ERROR: worker missing expected right"
  (not tmpf) and throw new Error "ERROR: worker missing expected tmpf"
  (not RUN_KERN) and throw new Error "ERROR: worker missing expected RUN_KERN"
  (not FONT) and throw new Error "ERROR: worker missing expected FONT"
  (not fontsha) and throw new Error "ERROR: worker missing expected fontsha"
  (not CACHE_DIR) and throw new Error "ERROR: worker missing expected CACHE_DIR"

  jsonfilename = await toImg prefix, "#{left}#{right}", {[left]:{[right]:RUN_KERN}}, tmpf, FONT, fontsha, CACHE_DIR

  ALGO_DEBUG and console.log 'kernWorker', JSON.stringify {jsonfilename, tmpf}
  img = await Image.loadJson jsonfilename

  ALGO_DEBUG and console.log "Processing #{img.filename}..."
  hA = img.hAreasImg()
  (hA.length isnt 2) and throw new Error "ERROR: hA.length isnt 2 #{JSON.stringify {hA,jsonfilename,tmpf}}"
  mid = Math.floor (hA[0].e + hA[1].s) / 2
  img.blurImg ALGO_BLUR, ALGO_THRESHOLD
  ALGO_DEBUG and await img.savePng "#{tmpf}_z0.png"
  img.growImg ALGO_GROW, ALGO_GROW_HADD, ALGO_GROW_HSTRECH
  ALGO_DEBUG and await img.savePng "#{tmpf}_z1.png"
  hB = img.hAreasImg()
  (hB.length isnt 2) and throw new Error "ERROR: hB.length isnt 2 #{JSON.stringify {hA,mid,hB,jsonfilename,tmpf}}"
  not (hB[0].e < mid < hB[1].s) and throw new Error "ERROR: not (hB[0].e < mid < hB[1].s) #{JSON.stringify {hA,mid,hB,jsonfilename,tmpf}}"
  minpx = img.minHDistance mid
  #console.log {minpx}
  minpx



module.exports = { kernWorker }
if require.main is module
  console.log await kernWorker 'cache/4733f86296b9845b056cc08f25d35a16bee9d7f3_f0909190f09091b3_7b22f0909190223a7b22f09091b3223a343130307d7d.png', '_zz_0'

# console.log await kernWorker
#   left: '𐑨'
#   right: '𐑐'
#   strid: 'Z'
#   tmpf: '_z_0'

# ALGO_DEBUG_STR = [...('𐑩𐑨𐑐𐑗𐑠𐑥𐑥'.matchAll /./ug)].map (m)->m[0]
# await texFile "_algo_grow_base", (ALGO_DEBUG_STR.join ''), {}, true
# for i in [ 40 .. 300 ] by 10
#   kernDefs = {}
#   ALGO_GROW = i
#   for j in [ 0 ... (ALGO_DEBUG_STR.length - 1) ]
#     kernAfter await kernWorker
#       left: ALGO_DEBUG_STR[j]
#       right: ALGO_DEBUG_STR[j+1]
#       strid: 'Z'
#       tmpf: "_z_#{i}_#{j}"
#   await texFile "_algo_grow_#{i}", (ALGO_DEBUG_STR.join ''), kernDefs, true
#   break if (Object.keys kernDefs).length is 0
# return
