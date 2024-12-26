fs = require 'node:fs/promises'
fsold = require 'fs'
util = require 'node:util'
exec = util.promisify (require 'node:child_process').exec
run = (prefix, a, b={}) ->
  console.log "(#{prefix}) #{a}"
  await exec a, b

Image = require './image'



RUN_PREFIX = ''
PNGCONV_DENSITY = 5000
PNGCONV_ZOOM = 200
TMP_DIR = '_tmp'
fsold.mkdirSync TMP_DIR, { recursive: true }



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
texFile = (prefix, file, content, defs, FONT, small=false) ->
  content = (content
    .replaceAll /\\/ug, '\\textbackslash{}'
    .replaceAll /([{}%$&_#])/ug, '\\$1'
    .replaceAll /([~^])/ug, '\\$1{}'
  )
  fontext = (FONT.match /\.([-_a-zA-Z0-9]*)$/i)[1]
  await fs.copyFile FONT, "#{TMP_DIR}/#{file}.#{fontext}"
  await fs.writeFile "#{TMP_DIR}/#{file}.tex", """
    \\documentclass[12pt]{article}
    \\usepackage[#{if small then 'paperheight=1cm,paperwidth=2cm,margin=0.1cm' else 'a4paper,margin=1cm'}]{geometry}
    \\usepackage{fontspec}
    \\include{#{file}_kern.tex}
    \\setmainfont{#{file}.#{fontext}}[RawFeature=+calculatedautokern]
    \\begin{document}
    \\pagestyle{empty}
    \\begin{flushleft}
    #{content}
    \\end{flushleft}
    \\end{document}
    """
  await kernFile "#{TMP_DIR}/#{file}_kern.tex", defs
  await run prefix, "#{RUN_PREFIX}lualatex --halt-on-error #{file}.tex", { cwd: TMP_DIR }
  "#{TMP_DIR}/#{file}.pdf"
toImg = (prefix, content, defs, f, FONT, fontsha, CACHE_DIR) ->
  contentsha = Buffer.from(content, 'utf8').toString('hex')
  defssha = Buffer.from((JSON.stringify defs)+PNGCONV_ZOOM, 'utf8').toString('hex')
  cache_file_name = "#{fontsha}_#{contentsha}_#{defssha}.json"
  cache_full_file_name = "#{CACHE_DIR}/#{cache_file_name}"
  try
    await fs.access cache_full_file_name, fs.constants.R_OK
    # console.log 'HIT', cache_full_file_name, prefix, content, defs, f, FONT, fontsha, CACHE_DIR
    return cache_full_file_name
  # console.log 'MISS', cache_full_file_name, prefix, content, defs, f, FONT, fontsha, CACHE_DIR

  genpdf = await texFile prefix, f, content, defs, FONT, true
  #await run "convert -background white -alpha remove -alpha off -density #{PNGCONV_DENSITY} #{genpdf} #{TMP_DIR}/#{f}.png"
  await run prefix, "#{RUN_PREFIX}pdf2svg  #{genpdf} #{TMP_DIR}/#{f}.svg"
  await run prefix, "#{RUN_PREFIX}rsvg-convert -z #{PNGCONV_ZOOM} -b white #{TMP_DIR}/#{f}.svg -o #{TMP_DIR}/#{f}.png"

  img = await Image.loadPng "#{TMP_DIR}/#{f}.png"
  await img.saveJson "#{TMP_DIR}/#{f}.json"

  if cache_file_name.length < 255
    await fs.mkdir CACHE_DIR, { recursive: true }
    await fs.copyFile "#{TMP_DIR}/#{f}.json", cache_full_file_name
  return "#{TMP_DIR}/#{f}.json"

tmpPathJoin = (file) -> "#{TMP_DIR}/#{file}"


module.exports = { texFile, kernFile, toImg, tmpPathJoin }
if require.main is module
  console.log ''
