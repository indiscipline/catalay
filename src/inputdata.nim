import std/[options, strutils, strformat, streams, unicode]
import pkg/[parseToml, zero_functional]
import yaml, yaml/serialization, yaml/taglib, yaml/stream
import common

{.push raises: [].}

const
  WhitespacePlusQuoteUC = toRunes("\"\t\n\x0b\x0c\r\x1c\x1d\x1e\x1f \x85\xa0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000")

var gl_ItemSeps = {'\t', ';'} # TODO: find a way to do without a global

type
  ConfigFormat* = enum Toml, Yaml
  Size* = object #tuple[width, height: int]
    width*, height*: int
  Item* = object #tuple[id, imagePath: string]
    id*: string
    imagePath*: string
  Items* = seq[Item]
  Weight = Option[float] # valid in (0 .. 100)
  Group* = object
    title*: string
    itemSize*: Size
    items*: Items
    weight* {.sparse defaultVal: none(float).}: Weight #
  Page* = object
    title* {.sparse defaultVal: none(string).}: Option[string]
    groups*: seq[Group]
  Catalogue* = object
    pageSize*: Size
    titleSize*: int
    groupTitleSize*: int
    itemLabelSize*: int
    pages*: seq[Page]

setTag(Items, Tag("!nim:items"))

converter toSizeTuple*(x: Size): tuple[width, height: int] =
  (width: x.width, height: x.height)
converter toSize*(x: tuple[width, height: int]): Size =
  Size(width: x.width, height: x.height)

converter toItem*(x: tuple[id, imagePath: string]): Item =
  Item(id: x.id, imagePath: x.imagePath)
converter toItemTuple*(x: Item ): tuple[id, imagePath: string] =
  (id: x.id, imagePath: x.imagePath)

proc parseItems(s: string; seps: set[char] = gl_ItemSeps): Items {.raises: [ref IOError, IOError, ref ValueError, ValueError].} =
  for line in s.splitLines():
    let itemStr = line.strip(runes = WhitespacePlusQuoteUC)
    if itemStr != "":
      let parts = itemStr.split(seps = seps, maxsplit = 1)
      if parts.len != 2:
        panic(&"Error parsing item '{itemStr}' using separators {seps}")
      let id = parts[0].strip(runes = WhitespacePlusQuoteUC, leading = false)
      let path = parts[1].strip(runes = WhitespacePlusQuoteUC, trailing = false).replace('\\', '/')
      result.add(Item(id: id, imagePath: path))

func `$`(items: Items): string =
  for item in items:
    result.add(item.id & ";" & item.imagePath & "\n")

proc representObject*(value: Items, ts: TagStyle, c: SerializationContext,
                      tag = presentTag(Items, tsNone)){.raises: [].} =
   c.put(scalarEvent($value, tag, yAnchorNone))

proc constructObject*(s: var YamlStream, c: ConstructionContext, result: var Items)
                      {.raises: [YamlConstructionError, YamlStreamError].} =
  constructScalarItem(s, item, Items):
    result = parseItems(item.scalarContent, gl_ItemSeps)

proc readYamlConfig(filepath: string): Catalogue  {.raises: [YamlConstructionError, IOError, OSError, YamlParserError, Exception].} =
  var s = newFileStream(filepath)
  try: load(s, result)
  finally: s.close()

proc getSize(t: TomlValueRef; key: string): Size  {.raises: [ref KeyError].} =
  (t[key]["width"].getInt(), t[key]["height"].getInt()).Size

proc readTomlConfig(filepath: string): Catalogue {.raises: [IOError, OSError, Exception].} =
  let toml = parsetoml.parseFile(filepath)

  result.pageSize = toml.getSize("pageSize")
  result.titleSize = toml["titleSize"].getInt(14)
  result.groupTitleSize = toml["groupTitleSize"].getInt(12)
  result.itemLabelSize = toml["itemLabelSize"].getInt(7)
  #result.minMargin = toml["minMargin"].getInt(3)
  for page in toml["pages"].getElems():
    var newpage: Page
    newpage.title = block:
      let s = page.getOrDefault("title").getStr("").strip(runes = WhitespacePlusQuoteUC)
      if s == "": none(string) else: some(s)
    for group in page["groups"].getElems():
      var newgroup: Group
      newgroup.title = group["title"].getStr("").strip(runes = WhitespacePlusQuoteUC)
      newgroup.itemSize = group.getSize("itemSize")
      newgroup.weight = block:
        let f = group.getOrDefault("weight").getFloat()
        if f == 0: none(float) else: some(f)
      newgroup.items = group["items"].getStr("").strip(runes = WhitespacePlusQuoteUC)
                                     .parseItems(gl_ItemSeps)
      newpage.groups.add(newgroup)
    result.pages.add(newpage)

# TODO: migrate to std/paths.nim when in stable
proc readConfig*(filepath: string; format: ConfigFormat; itemSeps: set[char]): Catalogue
  {.raises: [IOError, OSError, Exception].} =
  gl_ItemSeps = itemSeps
  case format
    of Toml: filepath.readTomlConfig()
    of Yaml: filepath.readYamlConfig()

when isMainModule:
  import std/unittest

  suite "Test `parseItem`":
    let expected = @[Item(id: "1", imagePath: "image1.png"),
                      Item(id: "2", imagePath: "image2.png")]

    test "two items":
      let input = "1;image1.png\n2;image2.png"
      check parseItems(input) == expected

    test "empty input":
      check parseItems("").len == 0

    test "input with an empty line":
      let inputWithEmptyLine = "1;image1.png\n\n2;image2.png\n\n"
      check parseItems(inputWithEmptyLine) == expected

    test "input with mixed separators":
      let inputWithMixedSeps = "1\timage1.png\n2;image2.png\n"
      check parseItems(inputWithMixedSeps) == expected

    test "input with whitespace":
      let inputWithMixedSeps = "1  \timage1.png \n   2; image2.png\r\n"
      check parseItems(inputWithMixedSeps) == expected












