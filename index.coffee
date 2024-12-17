fs = require 'node:fs/promises'

Image = require './lib/image'
{ texFile, kernFile, toImg } = require './lib/teximg'



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
fontinfo = (require 'fonteditor-core').Font.create fontdata, {type: ((FONT.match /\.([-_a-zA-Z0-9]*)$/i)[1])}
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

t.push 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc laoreet purus nisi, id fermentum nisl convallis mollis. Vivamus suscipit gravida nisl et consequat. Vestibulum pharetra eu turpis ac lacinia. Curabitur lacinia magna at odio blandit, eu sollicitudin augue consequat. Mauris pulvinar velit nec ligula molestie pulvinar. Phasellus ut mollis orci. In at mollis ante. In vitae lacinia nulla. Nunc vel dignissim odio. Ut at pellentesque nulla. Fusce semper auctor dui ac ultricies. Pellentesque eget nunc non diam molestie placerat.'
t.push ''
t.push '·𐑖𐑻𐑤𐑪𐑒 𐑣𐑴𐑥𐑟 𐑖𐑰 𐑦𐑟 𐑷𐑤𐑢𐑱𐑟 𐑞 𐑢𐑫𐑥𐑩𐑯. 𐑲 𐑣𐑨𐑝 𐑕𐑧𐑤𐑛𐑩𐑥 𐑣𐑻𐑛 𐑣𐑦𐑥 𐑥𐑧𐑯𐑖𐑩𐑯 𐑣𐑻 𐑳𐑯𐑛𐑼 𐑧𐑯𐑦 𐑳𐑞𐑼 𐑯𐑱𐑥. 𐑦𐑯 𐑣𐑦𐑟 𐑲𐑟 𐑖𐑰 𐑦𐑒𐑤𐑦𐑐𐑕𐑩𐑟 𐑯 𐑐𐑮𐑦𐑛𐑪𐑥𐑦𐑯𐑱𐑑𐑕 𐑞 𐑣𐑴𐑤 𐑝 𐑣𐑻 𐑕𐑧𐑒𐑕. 𐑦𐑑 𐑢𐑪𐑟 𐑯𐑪𐑑 𐑞𐑨𐑑 𐑣𐑰 𐑓𐑧𐑤𐑑 𐑧𐑯𐑦 𐑦𐑥𐑴𐑖𐑩𐑯 𐑩𐑒𐑦𐑯 𐑑 𐑤𐑳𐑝 𐑓 ·𐑲𐑮𐑰𐑯 𐑨𐑛𐑤𐑼. 𐑷𐑤 𐑦𐑥𐑴𐑖𐑩𐑯𐑟, 𐑯 𐑞𐑨𐑑 𐑢𐑳𐑯 𐑐𐑼𐑑𐑦𐑒𐑘𐑩𐑤𐑼𐑤𐑦, 𐑢𐑻 𐑩𐑚𐑣𐑪𐑮𐑩𐑯𐑑 𐑑 𐑣𐑦𐑟 𐑒𐑴𐑤𐑛, 𐑐𐑮𐑦𐑕𐑲𐑕 𐑚𐑳𐑑 𐑨𐑛𐑥𐑼𐑩𐑚𐑤𐑦 𐑚𐑨𐑤𐑩𐑯𐑕𐑑 𐑥𐑲𐑯𐑛. 𐑣𐑰 𐑢𐑪𐑟, 𐑲 𐑑𐑱𐑒 𐑦𐑑, 𐑞 𐑥𐑴𐑕𐑑 𐑐𐑻𐑓𐑦𐑒𐑑 𐑮𐑰𐑟𐑩𐑯𐑦𐑙 𐑯 𐑩𐑚𐑟𐑻𐑝𐑦𐑙 𐑥𐑩𐑖𐑰𐑯 𐑞𐑨𐑑 𐑞 𐑢𐑻𐑤𐑛 𐑣𐑨𐑟 𐑕𐑰𐑯, 𐑚𐑳𐑑 𐑨𐑟 𐑩 𐑤𐑳𐑝𐑼 𐑣𐑰 𐑢𐑫𐑛 𐑣𐑨𐑝 𐑐𐑤𐑱𐑕𐑑 𐑣𐑦𐑥𐑕𐑧𐑤𐑓 𐑦𐑯 𐑩 𐑓𐑷𐑤𐑕 𐑐𐑩𐑟𐑦𐑖𐑩𐑯. 𐑣𐑰 𐑯𐑧𐑝𐑼 𐑕𐑐𐑴𐑒 𐑝 𐑞 𐑕𐑪𐑓𐑑𐑼 𐑐𐑨𐑖𐑩𐑯𐑟, 𐑕𐑱𐑝 𐑢𐑦𐑞 𐑩 𐑡𐑲𐑚 𐑯 𐑩 𐑕𐑯𐑽. 𐑞𐑱 𐑢𐑻 𐑨𐑛𐑥𐑼𐑩𐑚𐑩𐑤 𐑔𐑦𐑙𐑟 𐑓 𐑞 𐑩𐑚𐑟𐑻𐑝𐑼—𐑧𐑒𐑕𐑩𐑤𐑩𐑯𐑑 𐑓 𐑛𐑮𐑷𐑦𐑙 𐑞 𐑝𐑱𐑤 𐑓𐑮𐑪𐑥 𐑥𐑧𐑯𐑟 𐑥𐑴𐑑𐑦𐑝𐑟 𐑯 𐑨𐑒𐑖𐑩𐑯𐑟. 𐑚𐑳𐑑 𐑓 𐑞 𐑑𐑮𐑱𐑯𐑛 𐑮𐑰𐑟𐑩𐑯𐑼 𐑑 𐑩𐑛𐑥𐑦𐑑 𐑕𐑳𐑗 𐑦𐑯𐑑𐑮𐑵𐑠𐑩𐑯𐑟 𐑦𐑯𐑑𐑵 𐑣𐑦𐑟 𐑴𐑯 𐑛𐑧𐑤𐑦𐑒𐑩𐑑 𐑯 𐑓𐑲𐑯𐑤𐑦 𐑩𐑡𐑳𐑕𐑑𐑩𐑛 𐑑𐑧𐑥𐑐𐑼𐑩𐑥𐑩𐑯𐑑 𐑢𐑪𐑟 𐑑 𐑦𐑯𐑑𐑮𐑩𐑛𐑿𐑕 𐑩 𐑛𐑦𐑕𐑑𐑮𐑨𐑒𐑑𐑦𐑙 𐑓𐑨𐑒𐑑𐑼 𐑢𐑦𐑗 𐑥𐑲𐑑 𐑔𐑮𐑴 𐑩 𐑛𐑬𐑑 𐑩𐑐𐑪𐑯 𐑷𐑤 𐑣𐑦𐑟 𐑥𐑧𐑯𐑑𐑩𐑤 𐑮𐑦𐑟𐑳𐑤𐑑𐑕. 𐑜𐑮𐑦𐑑 𐑦𐑯 𐑩 𐑕𐑧𐑯𐑕𐑦𐑑𐑦𐑝 𐑦𐑯𐑕𐑑𐑮𐑩𐑥𐑩𐑯𐑑, 𐑹 𐑩 𐑒𐑮𐑨𐑒 𐑦𐑯 𐑢𐑳𐑯 𐑝 𐑣𐑦𐑟 𐑴𐑯 𐑣𐑲-𐑐𐑬𐑼 𐑤𐑧𐑯𐑟𐑩𐑟, 𐑢𐑫𐑛 𐑯𐑪𐑑 𐑚𐑰 𐑥𐑹 𐑛𐑦𐑕𐑑𐑻𐑚𐑦𐑙 𐑞𐑨𐑯 𐑩 𐑕𐑑𐑮𐑪𐑙 𐑦𐑥𐑴𐑖𐑩𐑯 𐑦𐑯 𐑩 𐑯𐑱𐑗𐑼 𐑕𐑳𐑗 𐑨𐑟 𐑣𐑦𐑟. 𐑯 𐑘𐑧𐑑 𐑞𐑺 𐑢𐑪𐑟 𐑚𐑳𐑑 𐑢𐑳𐑯 𐑢𐑫𐑥𐑩𐑯 𐑑 𐑣𐑦𐑥, 𐑯 𐑞𐑨𐑑 𐑢𐑫𐑥𐑩𐑯 𐑢𐑪𐑟 𐑞 𐑤𐑱𐑑 ·𐑲𐑮𐑰𐑯 𐑨𐑛𐑤𐑼, 𐑝 𐑛𐑿𐑚𐑾𐑕 𐑯 𐑒𐑢𐑧𐑕𐑗𐑩𐑯𐑩𐑚𐑩𐑤 𐑥𐑧𐑥𐑼𐑦.'
t.push ''

t.push '---'
t.push ''
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

genpdf = await texFile 'TESTER', "_tester_default", (t.join ' \n'), {}, FONT
await fs.copyFile genpdf, "_tester_default.pdf"
genpdf = await texFile 'TESTER', "_tester_autokern", (t.join ' \n'), kernDefs, FONT
await fs.copyFile genpdf, "_tester_autokern.pdf"
await kernFile "_kern.tex", kernDefs
