import layout, inputdata
import std/[options]

type
  GeometricBounds* =array[4, float] # [y1, x1, y2, x2], top-left to bottom right

  JSONLabel* = object
    bounds*: GeometricBounds
    text*: string
    textSize*: int

  JSONCatalogue* = object
    pageSize*: tuple[width, height: int]
    pages*: seq[JSONPage]

  JSONPage* = object
    title*: JSONLabel
    groups*: seq[JSONGroup]

  JSONGroup* = object
    title*: JSONLabel
    items*: seq[JSONItem]
    labels*: seq[JSONLabel]

  JSONItem* = object
    bounds*: GeometricBounds
    id*: string
    imagePath*: string

func rectToGeometricBounds(r: Rectangle): GeometricBounds =
  [r.pt.y, r.pt.x, r.pt.y + r.sz.h, r.pt.x + r.sz.w]

func toJSONObject*(cat: Catalogue; lay: CatalogueLayout): JSONCatalogue =
  result.pageSize = cat.pageSize
  for pIdx in 0..<cat.pages.len:
    let (page, pageLt) = (cat.pages[pIdx], lay.pages[pIdx])
    var jsonGroups: seq[JSONGroup]
    for gIdx in 0..<page.groups.len:
      let
        (group, labels) = (page.groups[gIdx], pageLt.groupLabels[gIdx])
        (items, itemLts) = (group.items, pageLt.groups[gIdx])
        gTitleBounds = pageLt.groupTitleRects[gIdx].rectToGeometricBounds()
        gTitle = JSONLabel(bounds: gTitleBounds, text: group.title, textSize: cat.groupTitleSize)
      var jsonItems: seq[JSONItem]
      var jsonLabels: seq[JSONLabel]
      for iIdx in 0..<items.len:
        let
          (id, path) = items[iIdx].toItemTuple
          iBounds = itemLts[iIdx].rectToGeometricBounds()
          jsonItem = JSONItem(bounds: iBounds, id: id, imagePath: path)
        jsonItems.add(jsonItem)
        let
          lBounds = labels[iIdx].rectToGeometricBounds()
          jsonLabel = JSONLabel(bounds: lBounds, text: id, textSize: cat.itemLabelSize)
        jsonLabels.add(jsonLabel)
      jsonGroups.add(JSONGroup(title: gTitle, items: jsonItems, labels: jsonLabels))
    let pTitle = if pageLt.pageTitle.isSome():
        let pTitleBounds = pageLt.pageTitle.get().rectToGeometricBounds()
        JSONLabel(bounds: pTitleBounds, text: page.title.get(""), textSize: cat.titleSize)
      else:
        JSONLabel(bounds: [0.0,0.0,0.0,0.0], text: "", textSize: 0)
    result.pages.add(JSONPage(title: pTitle, groups: jsonGroups))
