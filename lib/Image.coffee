assert = require 'node:assert/strict'

IntervalSet = require './IntervalSet'



module.exports = class Image
  @new: (rows, cols, data=undefined) ->
    img = new Image()
    img.rows = rows
    img.cols = cols
    img.data = if data
      assert.deepStrictEqual rows, data.length
      data.map (e) -> new IntervalSet e
    else
      new IntervalSet() for _ in [ 0 ... rows ]
    img.orig =
      width: cols
      height: rows
      depth: 8
      interlace: false
      palette: false
      color: true
      alpha: false
      bpp: 3
      colorType: 2
      data: []
      gamma: 0
    img.outdatedOrig = true
    img

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
    img.orig = PNG.sync.read await fs.readFile filename
    img.loadOrig margin, threshold
    img

  savePng: (file, margin=0) =>
    fs = require 'node:fs/promises'
    {PNG} = require 'pngjs'
    @updateOrig margin
    await fs.writeFile file, PNG.sync.write @orig
    this

  @fromObj: (obj) ->
    return Image.new obj.rows, obj.cols, obj.data

  @loadJson: (filename) ->
    fs = require 'node:fs/promises'
    try
      return Image.fromObj JSON.parse await fs.readFile filename
    catch err
      console.error "ERROR reading #{filename}"
      throw err

  toObj: =>
    rows: @rows
    cols: @cols
    data: (@data.map (e)->e.intset)

  saveJson: (file) =>
    fs = require 'node:fs/promises'
    await fs.writeFile file, JSON.stringify @toObj()
    this

  blurImg: (radius, threshold=32) =>
    glur = require 'glur'
    @updateOrig 0
    glur @orig.data, @cols, @rows, radius
    @loadOrig 0, threshold
    this

  xx_cache = {}
  @xx = (radius, hadd=0, hstretch=1) ->
    xx_cache_radius = xx_cache[radius]
    xx_cache[radius] = xx_cache_radius = {} if not xx_cache_radius
    xx_cache_hadd = xx_cache_radius[hadd]
    xx_cache_radius[hadd] = xx_cache_hadd = {} if not xx_cache_hadd
    return xx_cache_hadd[hstretch] if xx_cache_hadd[hstretch]
    xx = [ radius ]
    for y in [ 1 ... radius ]
      xx.push Math.floor hadd + hstretch * Math.sqrt ((radius+0.5) * (radius+0.5)) - (y * y)
    xx_cache_hadd[hstretch] = xx
    xx

  growImg: (radius, hadd=0, hstretch=1) =>
    xx = Image.xx radius, hadd, hstretch
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

  line: (row, start, end) =>
    if row < 0 or row >= @rows
      throw "ERROR: row=#{row} OOB rows=#{@rows}"
    if start < 0
      throw "ERROR: row=#{row} start=#{start} < 0"
    if end < 0
      throw "ERROR: row=#{row} end=#{end} < 0"
    #console.log 'line', row, start, end
    if end > @cols
      #console.log "Expanding cols from #{@cols} to #{end}"
      @cols = end
    @data[row].addInterval start, end
    @outdatedOrig = true
    this
  vline: (col, start=0, end=@rows) =>
    if col < 0 or col >= @cols
      throw "ERROR: col=#{col} OOB cols=#{@cols}"
    if not (0 <= start < end <= @rows)
      throw "ERROR: col=#{col} not (0 <= start=#{start} < end=#{end} <= @rows=#{@rows})"
    for r in [ start ... end ]
      @line r, col, col + 1
    @outdatedOrig = true
    this
  
  semiCircunference: (r, c, iradius, oradius, flipdown, flipleft, hadd=0, hstretch=1) =>
    ixx = Image.xx iradius, hadd, hstretch
    oxx = Image.xx oradius, hadd, hstretch
    for dy in [ 0 ... oradius ]
      ixxx = ixx[dy] or 0
      oxxx = oxx[dy]
      if not flipdown
        dy = -dy
      continue if ((r+dy) < 0) or ((r+dy) >= @rows)
      if flipleft
        [ ixxx, oxxx ] = [ -oxxx, -ixxx]
      start = Math.max 0, c+ixxx
      end = Math.max 0, c+oxxx
      if c+oxxx >= 0
        @line (r+dy), start, end
    @outdatedOrig = true
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

  avgImgWeight: (mins=0, maxe=@cols) =>
    acc = 0
    div = 0
    for r in [ 0 ... @rows ]
      @data[r].foreachInterval (s, e) =>
        if mins <= s and e <= maxe
          num = e - s
          acc += (s + e - 1) * num / 2
          div += num
    if div is 0
      return null
    Math.floor (acc / div)

  rowHDistance: (r, mid) =>
    pos = @data[r].binarysearch_first_false (i) => @data[r].intset[ i + 1 ] < mid
    if pos is 0 or pos is @data[r].intset.length
      return -1
    lc = @data[r].intset[ pos - 1 ]
    rc = @data[r].intset[ pos ]
    return rc - lc

  minHDistance: (mid) =>
    minpx = @cols
    for r in [ 0 ... @rows ]
      rd = @rowHDistance r, mid
      if rd >=0
        minpx = Math.min minpx, rd
    (minpx is @cols) and throw "ERROR: minpx is @cols (no intersection) #{JSON.stringify {hA,mid,hB}}"
    minpx
