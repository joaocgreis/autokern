fs = require 'node:fs/promises'
util = require 'node:util'
exec = util.promisify (require 'node:child_process').exec
run = (prefix, a, b={}) ->
  console.log "(#{prefix}) #{a}"
  await exec a, b

Image = require './Image'
#cache = require './cache'
tmpfile = require './tmpfile'



RUN_PREFIX = if process.platform is 'win32' then 'wsl ' else ''
PNGCONV_ZOOM = 200



kernStr = (defs) ->
  ret = []
  for left, rightMap of defs
    left = left.replace /([\\"~])/u, '\\string\\$1'
    s = [ "[\"#{left}\"] = {" ]
    for right, kern of rightMap
      right = right.replace /([\\"~])/u, '\\string\\$1'
      s.push " [\"#{right}\"] = #{kern},"
    s.push " },\n"
    ret.push s.join ''
  ret.join ''
kernFile = (file, defs) ->
  await fs.writeFile file, """
    \\directlua{
    fonts.handlers.otf.addfeature{
    name = "calculatedautokern",
    type = "kern",
    data =
    {
    #{kernStr defs}},
    }
    }
    """

texFile = (prefix, file, content, defs, font, small=false) ->
  content = (content
    .replaceAll /\\/ug, '\\textbackslash{}'
    .replaceAll /([{}%$&_#])/ug, '\\$1'
    .replaceAll /([~^])/ug, '\\$1{}'
  )
  await fs.copyFile font.file.real, tmpfile "#{file}#{font.file.ext}"
  await fs.writeFile (tmpfile "#{file}.tex"), """
    \\documentclass[12pt]{article}
    \\usepackage[#{if small then 'paperheight=1cm,paperwidth=2cm,margin=0.1cm' else 'a4paper,margin=1cm'}]{geometry}
    \\usepackage{fontspec}
    \\include{#{file}_kern.tex}
    \\setmainfont{#{file}#{font.file.ext}}[RawFeature=+calculatedautokern]
    \\begin{document}
    \\pagestyle{empty}
    \\begin{flushleft}
    #{content}
    \\end{flushleft}
    \\end{document}
    """
  await kernFile (tmpfile "#{file}_kern.tex"), defs
  await run prefix, "#{RUN_PREFIX}lualatex --halt-on-error #{file}.tex", { cwd: tmpfile() }
  return tmpfile "#{file}.pdf"

toImg = (prefix, content, defs, f, font, CACHE_DIR) ->
  contentsha = Buffer.from(content, 'utf8').toString('hex')
  defssha = Buffer.from((JSON.stringify defs)+PNGCONV_ZOOM, 'utf8').toString('hex')
  cache_file_name = "#{font.hash}_#{contentsha}_#{defssha}.json"
  cache_full_file_name = "#{CACHE_DIR}/#{cache_file_name}"
  try
    await fs.access cache_full_file_name, fs.constants.R_OK
    # console.log 'HIT', cache_full_file_name, prefix, content, defs, f, font.file.base, CACHE_DIR
    return cache_full_file_name
  # console.log 'MISS', cache_full_file_name, prefix, content, defs, f, font.file.base, CACHE_DIR

  svgfile = tmpfile "#{f}.svg"
  pngfile = tmpfile "#{f}.png"
  jsonfile = tmpfile "#{f}.json"

  genpdf = await texFile prefix, f, content, defs, font, true
  await run prefix, "#{RUN_PREFIX}pdf2svg #{genpdf} #{svgfile}"
  await run prefix, "#{RUN_PREFIX}rsvg-convert -z #{PNGCONV_ZOOM} -b white #{svgfile} -o #{pngfile}"

  img = await Image.loadPng pngfile
  await img.saveJson jsonfile

  if cache_file_name.length < 255
    await fs.mkdir CACHE_DIR, { recursive: true }
    await fs.copyFile jsonfile, cache_full_file_name
  return jsonfile



module.exports = { texFile, kernFile, toImg }
if require.main is module
  console.log ''
