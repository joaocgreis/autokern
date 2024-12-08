fs = require 'node:fs/promises'

Image = require './lib/image'
{ texFile, toImg } = require './lib/teximg'



CALIBRATION_LOW_KERN = 100
CALIBRATION_HIGH_KERN = 2100
RUN_KERN = CALIBRATION_HIGH_KERN
FONT = 'Ormin-Regular.otf'
CACHE_DIR = 'cache'
SHAVIANCHARS = [ ('𐑐'.codePointAt 0) .. ('𐑿'.codePointAt 0) ].map (c) -> String.fromCodePoint c
KERNCHARS = SHAVIANCHARS

ALGO_KEEP_POS = false



kernDefs = {}
kernSet = (left, right, kern) ->
  leftMap = kernDefs[left]
  if not leftMap
    leftMap = {}
    kernDefs[left] = leftMap
  leftMap[right] = kern
kernAfter = (left, right, minpx, strid) ->
  (not left) and throw "ERROR: result missing expected left #{JSON.stringify result}"
  (not right) and throw "ERROR: result missing expected right #{JSON.stringify result}"
  (not minpx) and throw "ERROR: result missing expected minpx #{JSON.stringify result}"
  (not strid) and throw "ERROR: result missing expected strid #{JSON.stringify result}"
  kern = RUN_KERN - (minpx / CALIBRATION_PX_PER_KERN)
  if ALGO_KEEP_POS or kern < 0
    kernSet left, right, kern
    console.log "(#{strid}) Kerning between #{left} and #{right} : #{kern}"
  else
    console.log "(#{strid}) Kerning between #{left} and #{right} : #{kern} NOT APPLIED"



console.log "Loading font information for '#{FONT}'..."
fontdata = await fs.readFile FONT
fontsha = require('crypto').createHash('sha1').update(fontdata).digest('hex')
fontinfo = (require 'fonteditor-core').Font.create fontdata, {type: ((FONT.match /\.([a-z]*)$/i)[1])}
fontinfo.chars = (Object.keys fontinfo.data.cmap).map (c) -> String.fromCodePoint c
charlist = []
charlist.push "#{JSON.stringify ch}\n" for ch in fontinfo.chars
await fs.writeFile "_charlist.txt", charlist.join ''
console.log "Done."



console.log "Calibrating..."
CAL_LEFT = '𐑐'
CAL_RIGHT = '𐑨'
[img100, img4100] = await Promise.all (
  for ck in [ CALIBRATION_LOW_KERN, CALIBRATION_HIGH_KERN ]
    (toImg 'CALIBRATION', "#{CAL_LEFT}#{CAL_RIGHT}", {[CAL_LEFT]:{[CAL_RIGHT]:ck}}, "_c_#{ck}", FONT, fontsha, CACHE_DIR)
      .then Image.loadJson
)
h100 = img100.hAreasImg()
h4100 = img4100.hAreasImg()
(h100.length isnt 2) and throw "CALIBRATION ERROR: h100.length isnt 2 #{JSON.stringify {h100,h4100}}"
(h4100.length isnt 2) and throw "CALIBRATION ERROR: h4100.length isnt 2 #{JSON.stringify {h100,h4100}}"
(h100[0].s isnt h4100[0].s) and throw "CALIBRATION ERROR: h100[0].s isnt h4100[0].s #{JSON.stringify {h100,h4100}}"
(h100[0].e isnt h4100[0].e) and throw "CALIBRATION ERROR: h100[0].e isnt h4100[0].e #{JSON.stringify {h100,h4100}}"
((h100[1].e - h100[1].s) isnt (h4100[1].e - h4100[1].s)) and throw "CALIBRATION ERROR: (h100[1].e-h100[1].s)=#{h100[1].e-h100[1].s} isnt (h4100[1].e-h4100[1].s)=#{h4100[1].e-h4100[1].s} #{JSON.stringify {h100,h4100}}"
(h100[1].s >= h4100[1].s) and throw "CALIBRATION ERROR: h100[1].s >= h4100[1].s #{JSON.stringify {h100,h4100}}"
CALIBRATION_PX_PER_KERN = (h4100[1].s * 1.0 - h100[1].s) / (CALIBRATION_HIGH_KERN - CALIBRATION_LOW_KERN)
console.log "Calibrated: #{CALIBRATION_PX_PER_KERN} px/kern"



workerpool = require 'workerpool'
pool = workerpool.pool './worker.js', { workerType: 'process' }
{ kernWorker } = await pool.proxy()
# { kernWorker } = require './lib/kernalgorithm'

progress_i = 0
await Promise.all (
  for left in KERNCHARS
    for right in KERNCHARS
      do (left, right, this_i = progress_i++) ->
        strid = "#{1 + this_i}/#{KERNCHARS.length * KERNCHARS.length}"
        minpx = await kernWorker strid, left, right, "_f_#{this_i}", RUN_KERN, FONT, fontsha, CACHE_DIR
        #console.log {minpx}
        kernAfter left, right, minpx, strid
).flat()

pool.terminate()



await fs.writeFile "_kern.json", JSON.stringify kernDefs, null, 2
# kernDefs = JSON.parse await fs.readFile "_kern.json", 'utf8'



# acc = avgImgWeight img, t
# for r in [ 0 ... img.rows ]
#   racc = avgRowWeight img, r, t
#   img.data[ r ][ acc ] = 0
#   img.data[ r ][ acc+1 ] = 255
#   img.data[ r ][ racc ] = 0
#   img.data[ r ][ racc+1 ] = 255
# img.savePng 'out.png', 0



t=[]

sorted_kerns = (
  for i in KERNCHARS
    for j in KERNCHARS
      [ (kernDefs[i]?[j] or 0), "#{i}#{j}" ]
  ).flat(1).sort((a,b)->(parseFloat a[0])-(parseFloat b[0]))
t_kern_group = -100000
for [ k, s ] in sorted_kerns
  kg = Math.floor k/100
  if t_kern_group isnt kg
    t_kern_group = kg
    t.push ''
    t.push ">= #{kg*100}"
    t.push ''
  t.push s
t.push ''

t.push '---'
t.push ''
T_GROUP_SIZE = 24
t_n_groups = Math.ceil KERNCHARS.length * 1.0 / T_GROUP_SIZE
for i in [ 0 ... KERNCHARS.length ]
  for t_group in [ 0 ... t_n_groups ]
    l = [ KERNCHARS[i] ]
    for j in [ (KERNCHARS.length * t_group / t_n_groups) ... (KERNCHARS.length * (t_group+1) / t_n_groups) ]
      l.push KERNCHARS[j]
      l.push KERNCHARS[i]
    t.push l.join ''
    t.push ''

t.push '---'
t.push ''
t.push fontinfo.chars.join ' '

await texFile 'TESTER', "_tester_default", (t.join ' \n'), {}, FONT
await texFile 'TESTER', "_tester_autokern", (t.join ' \n'), kernDefs, FONT
