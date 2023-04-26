import std/[strformat, options]
import pkg/zero_functional
import layout, inputdata

const
  ImgClass = "img_"
  TxtClass = "txt_"
  SvgStyling = """
<style>
  rect {
    stroke-width: 0.1;
  }
  line {
    stroke-dasharray: 1;
    stroke-width:0.15;
  }
  .txt_ {
    stroke: maroon;
    fill: url("#hatchTxt");
  }
  .img_ {
    stroke: navy;
    fill: url("#hatchImg");
  }
</style>
<defs>
<pattern id="hatchImg" width="4" height="2" patternTransform="rotate(45 0 0)" patternUnits="userSpaceOnUse">
  <line x1="0" y1="0" x2="0" y2="1" style="stroke:blue;" />
</pattern>
<pattern id="hatchTxt" width="3" height="1.5" patternTransform="rotate(45 0 0)" patternUnits="userSpaceOnUse">
  <line x1="0" y1="0" x2="0" y2="1" style="stroke:red;" />
</pattern>
</defs>
"""
  LogoSvg = staticRead("../catalay.svg")

include "preview.nimf"

func rectToSVG(rect: Rectangle; class: string = ""): string =
  let class = if class != "": fmt"""class="{class}" """ else: ""
  let (x, y, w, h) = (rect.pt.x, rect.pt.y, rect.sz.w, rect.sz.h)
  fmt"""<rect {class}x="{x}" y="{y}" width="{w}" height="{h}" />"""

func groupToSVG(group: seq[Rectangle]): string =
  for r in group.items() --> map(rectToSVG):
    result.add(r)
    result.add("\n")

func layoutToSVG*(layout: PageLayout; size: Size; withStyling: bool = false): string =
  let (pw, ph) = size.toSizeTuple
  let styling = if withStyling: SvgStyling else: ""
  let pageTitle = if layout.pageTitle.isSome():
      rectToSVG(layout.pageTitle.get(), TxtClass)
    else:
      ""
  var svg = fmt"""
<svg xmlns="http://www.w3.org/2000/svg"
      width="{pw}mm" height="{ph}mm"
      viewBox="0 0 {pw} {ph}"
      version="1.0"
      encoding="UTF-8"
      xml:space="preserve"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      xmlns:svg="http://www.w3.org/2000/svg">
  {styling}
  <!-- title -->{pageTitle}"""
  for i in 0..<layout.groups.len:
    let group = layout.groups[i]
    let labels = layout.groupLabels[i]
    svg.add("\n\n    <!-- groupTitle -->")
    svg.add(rectToSVG(layout.groupTitleRects[i], TxtClass))
    for rect in group: svg.add("\n      " & rectToSVG(rect, ImgClass))
    svg.add("\n\n      <!-- groupLabels -->")
    for rect in labels: svg.add("\n      " & rectToSVG(rect, TxtClass))
  svg.add("\n</svg>")
  svg



proc composeSvgs*(layout: CatalogueLayout): seq[string] =
  layout.pages --> map(layoutToSVG(it, layout.pageSize, true)).to(seq)

proc composeHtml*(svgs:openArray[string]): string =
  genHtml(svgs)

proc composeHtml*(layout: CatalogueLayout): string =
  genHtml(composeSvgs(layout))
