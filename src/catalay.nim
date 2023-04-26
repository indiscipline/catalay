import std/[streams, random, os, strformat, strutils, terminal]
import pkg/[yaml, zero_functional, argparse, os_files/dialog]
import inputdata, renderpreviews, layout, renderjson

const
  HelpStr = """Generate catalogue layout based on TOML/YAML text representation."""

template panic(msg: varargs[untyped, `$`]) =
  stderr.styledWrite(fgRed, msg); write(stderr, "\n"); quit(1)

proc exportFile(contents: string; fileName: string; dir: string = ""): bool =
  var s = newFileStream(dir / fileName, fmWrite)
  try:
    s.write(contents)
    result = true
  finally: s.close()

proc exportSvgs(svgs: openArray[string]; namePrefix: string = "page_"; dir: string = "") =
  for i, svg in svgs:
    let name = &"{namePrefix}{i+1:08}.svg"
    discard svg.exportFile(name, dir)

proc main(input, outDir, outFName: string; genHtml: bool = true, genSvgs: bool = false) =
  randomize()

  let (dir, name, extension) = input.splitFile()

  let cat: Catalogue = case extension.toLowerAscii():
    of ".toml": readTomlConfig(input)
    of ".yaml": readYamlConfig(input)
    else: raise new Defect

  let catlayout: CatalogueLayout = layoutCatalogue(cat)

  if genHtml or genSvgs:
    let svgs = catlayout.composeSvgs()
    if genSvgs: svgs.exportSvgs(dir = outDir)
    let html = composeHtml(svgs)
    discard html.exportFile(outDir / "preview.html")

  let jsonObject = toJSONObject(cat, catlayout)
  var s = newFileStream(outDir / outFName, fmWrite)
  try: dump(jsonObject, s, options = defineOptions(style = psJson))
  finally: s.close()


when isMainModule:
  var p = newParser:
    help(HelpStr)
    flag("-d", "--dialog", help="Use Open File Dialog for Input config (takes precedence)")
    flag("-H", "--nohtml", help="Skip generation of `preview.html` in the output folder")
    flag("-s", "--svg", help="Generate individual SVG page previews in the output folder")
    option("-o", "--out", help="Path for saving JSON layout file. Parent directory reused for HTML and SVG previews", default = some("out.json"))
    arg("Input", nargs = 1, help = "Path to input configuration file, TOML or YAML", default = some("in.toml"))
    run:
      if opts.dialog:
        var di:DialogInfo
        di.kind = dkOpenFile
        di.title = "Open input config"
        di.filters = @[(name:"TOML", ext:"*.toml"),(name: "YAML", ext:"*.yaml")]
        let path = di.show()
        opts.Input = path

      let (outDir, outFName) = block:
        let (outDir, outFBase, outFExt) = opts.out.splitFile()
        ((if outDir == "": getCurrentDir() else: outDir), outFBase & outFExt)
      if not fileExists(opts.Input):
        panic("Input file does not exist or is not accessible!")
      elif not dirExists(outDir):
        panic("Output directory does not exist or is not accessible!")
      else:
        main(opts.Input, outDir, outFName, not opts.nohtml, opts.svg)

  try: p.run(commandLineParams())
  except ShortCircuit as e:
    if e.flag == "argparse_help": echo p.help; quit(0)
  except UsageError: panic(getCurrentExceptionMsg())
