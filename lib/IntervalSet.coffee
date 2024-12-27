module.exports = class IntervalSet
  constructor: (@intset=[]) -> {}

  binarysearch_first_false: (pred, hint_start = 0) =>
    left = hint_start
    right = @intset.length
    while left isnt right
      mid = (left + right) / 2
      mid -= mid % 2
      # console.log '1,5', {is:@intset,hint_start,left,mid,right}
      # mid can be left, but never right
      if pred mid
      then left = mid + 2
      else right = mid
    # console.log '2,6', {is:@intset,hint_start,left,mid,right}
    left

  addInterval: (s, e) =>
    # console.log '0', {is:@intset,s,e}
    pos = @binarysearch_first_false (i) => @intset[ i + 1 ] < s
    if (pos is @intset.length) or (e < @intset[ pos ])
      # console.log '3', {is:@intset,s,e,pos}
      @intset.splice pos, 0, s, e
    else
      # console.log '4', {is:@intset,s,e,pos}
      @intset[ pos ] = Math.min @intset[ pos ], s
      endpos = (@binarysearch_first_false ((i) => @intset[ i ] <= e), pos + 2)
      # console.log '7', {is:@intset,s,e,pos,endpos}
      @intset[ pos + 1 ] = Math.max @intset[ endpos - 1 ], e
      @intset.splice (pos + 2), (endpos - pos - 2)
    # console.log '8', {is:@intset,s,e,pos}
    this

  foreachInterval: (func) =>
    for i in [ 0 ... @intset.length ] by 2
      func @intset[ i ], @intset[ i + 1 ]
    this



if require.main is module
  check = (json, obj) ->
    objjson = JSON.stringify obj
    if json isnt objjson
      throw "ERROR: Failed test\nExpd: #{json}\nRcvd: #{objjson}"

  check '[10,20]', ((new IntervalSet()).addInterval 10, 20).intset
  check '[7,8,10,20]', ((new IntervalSet([7,8])).addInterval 10, 20).intset
  check '[9,20]', ((new IntervalSet([9,10])).addInterval 10, 20).intset
  check '[9,20]', ((new IntervalSet([9,11])).addInterval 10, 20).intset
  check '[9,21]', ((new IntervalSet([9,21])).addInterval 10, 20).intset
  check '[10,20]', ((new IntervalSet([10,11])).addInterval 10, 20).intset
  check '[10,20]', ((new IntervalSet([11,12])).addInterval 10, 20).intset
  check '[10,20]', ((new IntervalSet([19,20])).addInterval 10, 20).intset
  check '[10,21]', ((new IntervalSet([19,21])).addInterval 10, 20).intset
  check '[10,21]', ((new IntervalSet([20,21])).addInterval 10, 20).intset
  check '[10,20,22,23]', ((new IntervalSet([22,23])).addInterval 10, 20).intset
  check '[7,8,10,20,22,23]', ((new IntervalSet([7,8,22,23])).addInterval 10, 20).intset
  check '[358,464,3182,3285]', ((new IntervalSet([362,464,3182,3285])).addInterval 358, 464).intset
  check '[273,605,3150,3575,3577,3608]', ((new IntervalSet([273,605,3150,3352,3353,3575,3577,3608])).addInterval 3277, 3353).intset
  console.log 'All tests passed.'
