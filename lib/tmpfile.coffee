fs = require 'node:fs/promises'
fsold = require 'fs'
path = require 'path'
assert = require 'node:assert/strict'

workerpool = require 'workerpool'



tmpDir = path.join '.', '_tmp'
if workerpool.isMainThread
  # Create tmp dir
  try
    tmp_archive_dir = path.join '.', '_delete_this'
    fsold.mkdirSync tmp_archive_dir, { recursive: true }
    for f in fsold.readdirSync tmpDir
      fsold.renameSync (path.join tmpDir, f), (path.join tmp_archive_dir, f)
  workingDir = path.join tmpDir, new Date().toISOString().replace /[^0-9A-Z]/g, ''
  fsold.mkdirSync workingDir, { recursive: true }
else
  # Use existing tmp dir
  tmpdirs = fsold.readdirSync tmpDir
  assert tmpdirs.length is 1
  workingDir = path.join tmpDir, tmpdirs[0]



module.exports = (filename) ->
  return workingDir if not filename
  return path.join workingDir, filename
