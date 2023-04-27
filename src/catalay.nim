import std/[streams, random, os, strformat, strutils]
import pkg/[yaml, zero_functional, argparse, os_files/dialog]
import inputdata, renderpreviews, layout, renderjson, common

const
  ## Autodefined by Nimble. If built using pure nim, use git tag
  NimblePkgVersion {.strdefine.} = staticExec("git describe --tags HEAD").strip()
  HelpStr = &"Catalay v{NimblePkgVersion}\n" &
            "Generate catalogue layout based on TOML/YAML text representation.\n" &
            "Home page, docs and bug reports: https://github.com/indiscipline/catalay"
  ExampleConfigToml = staticRead("example.toml")
  ExampleConfigYaml = staticRead("example.yaml")

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

proc main(input, outDir, outFName: string; genHtml: bool = true, genSvgs: bool = false; itemSeps: set[char]) =
  randomize()

  let (dir, name, extension) = input.splitFile()

  let cat: Catalogue = case extension.toLowerAscii():
    of ".toml": readConfig(input, Toml, itemSeps)
    of ".yaml": readConfig(input, Yaml, itemSeps)
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
    option("--separators", help="""Separators used inside the `items` strings in the input config.
                             1: use ';', 2: use '\t', 3: use both.""", default = some("3"))
    option("-o", "--out", help="""Path for saving JSON layout file.
                             Parent directory reused for HTML and SVG previews""", default = some("out.json"))
    flag("--exampleToml", help="""Print an annotated example of the TOML input config.
                             (Use redirection to save to a file.)""", shortcircuit = true)
    flag("--exampleYaml", help="""Print an annotated example of the YAML input config.
                             (Use redirection to save to a file.)""", shortcircuit = true)
    flag("-v", "--version", help="Print version and exit", shortcircuit = true)
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
      elif opts.separators.len != 1 or opts.separators[0] notin "123":
        panic("Wrong value for the `separators` option! Use the number 1, 2 or 3.")
      else:
        let seps = case opts.separators[0]:
          of '1': {';'}
          of '2': {'\t'}
          of '3': {';', '\t'}
          else: raise new Defect
        main(opts.Input, outDir, outFName, not opts.nohtml, opts.svg, seps)
  try: p.run(commandLineParams())
  except ShortCircuit as e:
    case e.flag
      of "argparse_help": echo p.help
      of "version": echo &"Catalay v{NimblePkgVersion}"
      of "exampleToml": echo ExampleConfigToml
      of "exampleYaml": echo ExampleConfigYaml
      else: panic(getCurrentExceptionMsg())
    quit(0)
  except UsageError: panic(getCurrentExceptionMsg())
