fs = require 'node:fs/promises'
util = require 'node:util'
exec = util.promisify (require 'node:child_process').exec
run = (log_header, a, b={}) ->
  if process.platform is 'win32'
    a = "wsl #{a}"
  console.log "(#{log_header}) #{a}"
  await exec a, b

cache = require './cache'
tmpfile = require './tmpfile'
Image = require './Image'



PNGCONV_ZOOM = 200



kernStr = (kern_defs) ->
  ret = []
  for left, rightMap of kern_defs
    left = left.replace /([\\"~])/u, '\\string\\$1'
    s = [ "[\"#{left}\"] = {" ]
    for right, kern of rightMap
      right = right.replace /([\\"~])/u, '\\string\\$1'
      s.push " [\"#{right}\"] = #{kern},"
    s.push " },\n"
    ret.push s.join ''
  ret.join ''
kernFile = (file, kern_defs) ->
  await fs.writeFile file, """
    \\directlua{
    fonts.handlers.otf.addfeature{
    name = "calculatedautokern",
    type = "kern",
    data =
    {
    #{kernStr kern_defs}},
    }
    }
    """

texFile = (log_header, file, content, kern_defs, font, small=false) ->
  pdf_file = tmpfile "#{file}.pdf"
  await cache 'texFile', [ content, kern_defs, font.hash, small ], pdf_file, ->
    content = (content
      .replaceAll /\\/ug, '\\textbackslash{}'
      .replaceAll /([{}%$&_#])/ug, '\\$1'
      .replaceAll /([~^])/ug, '\\$1{}'
    )
    tmpfontfile = "#{file}#{font.file.ext}"
    tmpkernfile = "#{file}_kern.tex"
    await fs.copyFile font.file.real, tmpfile tmpfontfile
    await kernFile (tmpfile tmpkernfile), kern_defs
    await fs.writeFile (tmpfile "#{file}.tex"), """
      \\documentclass[12pt]{article}
      \\usepackage[#{if small then 'paperheight=1cm,paperwidth=2cm,margin=0.1cm' else 'a4paper,margin=1cm'}]{geometry}
      \\usepackage{fontspec}
      \\include{#{tmpkernfile}}
      \\setmainfont{#{tmpfontfile}}[RawFeature=+calculatedautokern]
      \\begin{document}
      \\pagestyle{empty}
      \\begin{flushleft}
      #{content}
      \\end{flushleft}
      \\end{document}
      """
    await run log_header, "lualatex --halt-on-error #{file}.tex", { cwd: tmpfile() }
    return null
  return pdf_file

toImg = (log_header, content, kern_defs, f, font) ->
  img = undefined
  imgobj = await cache 'toImg', [ content, kern_defs, font.hash, texFile.toString(), PNGCONV_ZOOM ], null, ->
    svg_file = tmpfile "#{f}.svg"
    png_file = tmpfile "#{f}.png"
    pdf_file = await texFile log_header, f, content, kern_defs, font, true
    await run log_header, "pdf2svg #{pdf_file} #{svg_file}"
    await run log_header, "rsvg-convert -z #{PNGCONV_ZOOM} -b white #{svg_file} -o #{png_file}"
    img = await Image.loadPng png_file
    return img.toObj()
  return img if img
  return Image.fromObj imgobj



module.exports = { texFile, kernFile, toImg }
if require.main is module
  console.log ''
