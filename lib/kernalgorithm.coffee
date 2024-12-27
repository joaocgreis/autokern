assert = require 'node:assert/strict'

tmpfile = require './tmpfile'
Image = require './Image'
{ toImg } = require './teximg'



ALGO_DEBUG = false

ALGO_BLUR = 10
ALGO_THRESHOLD = 128
ALGO_GROW = 40
ALGO_GROW_HADD = 0
ALGO_GROW_HSTRECH = 2



kernWorker = (prefix, left, right, tmpf, RUN_KERN, font) ->
  (not prefix) and throw new Error "ERROR: worker missing expected prefix"
  (not left) and throw new Error "ERROR: worker missing expected left"
  (not right) and throw new Error "ERROR: worker missing expected right"
  (not tmpf) and throw new Error "ERROR: worker missing expected tmpf"
  (not RUN_KERN) and throw new Error "ERROR: worker missing expected RUN_KERN"
  (not font) and throw new Error "ERROR: worker missing expected font"

  img = await toImg prefix, "#{left}#{right}", {[left]:{[right]:RUN_KERN}}, tmpf, font
  ALGO_DEBUG and console.log "Processing #{tmpf}..."

  hA = img.hAreasImg()
  (hA.length isnt 2) and throw new Error "ERROR: hA.length isnt 2 #{JSON.stringify {hA,tmpf}}"
  mid = Math.floor (hA[0].e + hA[1].s) / 2
  minpx = img.minHDistance mid
  leftcenter = img.avgImgWeight mid
  rightcenter = img.avgImgWeight 0, mid
  centerpx = leftcenter - rightcenter

  rowdiffs = (img.rowHDistance r, mid for r in [ 0 ... img.rows ])
  min_i_row = 0
  for r in [ 0 ... img.rows ]
    break if rowdiffs[min_i_row] isnt -1
    min_i_row++
  assert min_i_row < img.rows
  max_i_row = min_i_row
  for r in [ min_i_row ... img.rows ]
    break if rowdiffs[max_i_row] is -1
    max_i_row++
  assert max_i_row < img.rows
  for r in [ max_i_row ... img.rows ]
    assert rowdiffs[r] is -1

  img.vline leftcenter
  img.vline rightcenter
  rowdiffs = (img.rowHDistance r, mid for r in [ 0 ... img.rows ])

  # img.blurImg ALGO_BLUR, ALGO_THRESHOLD
  # ALGO_DEBUG and await img.savePng tmpfile "#{tmpf}_z0.png"

  img.growImg ALGO_GROW, ALGO_GROW_HADD, ALGO_GROW_HSTRECH
  ALGO_DEBUG and await img.savePng tmpfile "#{tmpf}_z1.png"
  hB = img.hAreasImg()
  (hB.length isnt 2) and throw new Error "ERROR: hB.length isnt 2 #{JSON.stringify {hA,mid,hB,tmpf}}"
  not (hB[0].e < mid < hB[1].s) and throw new Error "ERROR: not (hB[0].e < mid < hB[1].s) #{JSON.stringify {hA,mid,hB,tmpf}}"
  grownpx = img.minHDistance mid

  return { minpx, centerpx, grownpx, rowdiffs, min_i_row, max_i_row }



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
