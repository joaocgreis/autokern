IntervalSet = require './intervalset'



module.exports = class Image
  updateOrig: (margin=0) =>
    if (not @outdatedOrig) and (@orig.width is (@cols - margin - margin))
      return this
    @orig.width = (@cols - margin - margin)
    @orig.height = (@rows - margin - margin)
    @orig.data = Buffer.alloc @orig.width * @orig.height * 4, 255
    for r in [ 0 ... @orig.height ]
      @data[r].foreachInterval (s, e) =>
        for c in [ (Math.max 0, s - margin) ... (Math.min @orig.width, e - margin) ]
          pos = (r * @orig.width + c) * 4
          @orig.data[ pos + 0 ] = 0
          @orig.data[ pos + 1 ] = 0
          @orig.data[ pos + 2 ] = 0
    @outdatedOrig = false
    this

  loadOrig: (margin=0, threshold=32) =>
    @cols = @orig.width + margin + margin
    @rows = @orig.height + margin + margin
    @data = (new IntervalSet() for _ in [ 0 ... @rows ])
    for r in [ 0 ... @rows ]
      rpos = (r * @orig.width) * 4
      c = 0
      loop
        while c < @cols
          pos = rpos + (c * 4)
          grey = (@orig.data[ pos + 0 ] + @orig.data[ pos + 1 ] + @orig.data[ pos + 2 ]) / 3
          break if grey < threshold
          c++
        cstart = c
        while c < @cols
          pos = rpos + (c * 4)
          grey = (@orig.data[ pos + 0 ] + @orig.data[ pos + 1 ] + @orig.data[ pos + 2 ]) / 3
          break if grey >= threshold
          c++
        cend = c
        break if cstart is @cols
        @data[margin + r].addInterval (margin + cstart), (margin + cend)
    @outdatedOrig = false
    this

  @loadPng: (filename, margin=0, threshold=32) ->
    fs = require 'node:fs/promises'
    {PNG} = require 'pngjs'
    img = new Image()
    img.filename = filename
    img.orig = PNG.sync.read await fs.readFile filename
    img.loadOrig margin, threshold
    img

  savePng: (file, margin=0) =>
    fs = require 'node:fs/promises'
    {PNG} = require 'pngjs'
    @updateOrig margin
    await fs.writeFile file, PNG.sync.write @orig
    this

  @loadJson: (filename) ->
    fs = require 'node:fs/promises'
    img = new Image()
    try
      Object.assign img, JSON.parse await fs.readFile filename
    catch err
      console.error "ERROR reading #{filename}"
      throw err
    img.data = img.data.map (e) -> new IntervalSet e
    img.filename = filename
    img

  saveJson: (file) =>
    fs = require 'node:fs/promises'
    await fs.writeFile file, JSON.stringify
      rows: @rows
      cols: @cols
      data: (@data.map (e)->e.intset)
      outdatedOrig: true
      orig: (Object.assign {}, @orig, {data:[]})
    this

  blurImg: (radius, threshold=32) =>
    glur = require 'glur'
    @updateOrig 0
    glur @orig.data, @cols, @rows, radius
    @loadOrig 0, threshold
    this

  growImg: (radius, hadd=0, hstretch=1) =>
    xx = [ radius ]
    for y in [ 1 ... radius ]
      xx.push Math.floor hadd + hstretch * Math.sqrt (radius * radius) - (y * y)
    newData = (new IntervalSet() for _ in [ 0 ... @rows ])
    for r in [ 0 ... @rows ]
      @data[r].foreachInterval (s, e) =>
        for dy in [ (-radius + 1 ) ... radius ] when ((r+dy) >= 0) and ((r+dy) < @rows)
          gstart = Math.max 0, s - xx[Math.abs dy]
          gend = Math.min @cols, e + xx[Math.abs dy]
          newData[ r + dy ].addInterval gstart, gend
    @outdatedOrig = true
    @data = newData
    this

  hAreasImg: () =>
    merged = new IntervalSet()
    for ris in @data
      ris.foreachInterval merged.addInterval
    ret = []
    merged.foreachInterval (s, e) -> ret.push { s, e }
    ret

  # avgRowWeight: (r, threshold) =>
  #   acc = 0
  #   div = 0
  #   for c in [ 0 ... @cols ]
  #     if @data[ r ][ c ] < threshold
  #       acc += c
  #       div++
  #   if div is 0
  #     return null
  #   Math.floor (acc / div)

  # avgImgWeight: (threshold) =>
  #   acc = 0
  #   div = 0
  #   for r in [ 0 ... @rows ]
  #     avgRow = @avgRowWeight r, threshold
  #     if avgRow
  #       acc += avgRow
  #       div++
  #   if div is 0
  #     return null
  #   Math.floor (acc / div)

  minHDistance: (mid) =>
    minpx = @cols
    for r in [ 0 ... @rows ]
      pos = @data[r].binarysearch_first_false (i) => @data[r].intset[ i + 1 ] < mid
      lc = if pos is 0 then 0 else @data[r].intset[ pos - 1 ]
      rc = if pos is @data[r].intset.length then @cols else @data[r].intset[ pos ]
      minpx = Math.min minpx, (rc-lc)
    (minpx is @cols) and throw "ERROR: minpx is @cols (no intersection) #{JSON.stringify {hA,mid,hB,f:@filename}}"
    minpx
