import std/[math, strformat, enumerate, random, algorithm, monotimes, options, sequtils]
import pkg/zero_functional
import inputdata, distribute

const
  T0 = 1.0 # Initial temerature
  Iters = 10000.0 # Number of iterations
  MaxJump = 0.2 # Max

type
  Point* = tuple[x, y: float]
  SizeF* = tuple[width, height: float]
  Rectangle* = tuple[pt: Point, sz: tuple[w, h:float]]
  Efficiency* = tuple[area, scaleScore, agg: float]

  Grid* = object
    cellSize*: SizeF
    cellSizeWLabel*: SizeF
    rows*: int
    cols*: int
    scaleWLabel*: float
    scale*: float

  PageLayout* = object
    pageTitle*: Option[Rectangle]
    groupTitleRects*: seq[Rectangle]
    groupLabels*: seq[seq[Rectangle]]
    groups*: seq[seq[Rectangle]]

  CatalogueLayout* = object
    ## Contains rectangle dimensions of the layout
    pageSize*: Size
    pages*: seq[PageLayout]

const
  PagePadding* = 5.0 # TODO: Lift to input config
  PT* = 0.35278
  MaxItemDistanceFactor* = 0.33
  A4*: Size = (210, 297)
  A5*: Size = (148, 210)

template warn(msg: varargs[string, `$`]) =
  stderr.write("⚠\t"); stderr.write(msg); stderr.write("\n")

func `$`(eff: Efficiency): string =
  let areaPct = (eff.area*100.0).round(4)
  let scalePct = (eff.scaleScore*100.0).round(4)
  &"optimality: {eff.agg:<10.8f}; area covered: {areaPct:7.4f}%; scaling tightness: {scalePct:7.4f}%"

converter sizeF(s: Size): SizeF = (s.width.float, s.height.float)
func area(s: SizeF): float {.inline.} = s.width * s.height
func area(s: Size): Natural {.inline.} = s.width * s.height

func rect(x, y, w, h: float): Rectangle = ((x, y).Point, (w, h))
func ptToMm(pt: int): int = ceil(pt.float * PT).int

func bestFit(src: Size, dst: tuple[width, height: float]): float =
  let a = dst.width / src.width.float
  let b = dst.height / src.height.float
  min(a, b)

func pageWidthAvailable(pageSz: Size; pagePadding: float): float =
  pageSz.width.float - pagePadding*2
func pageHeightAvailable(pageSz: Size; pagePadding, titleHeight, groupTitleHeight: float; nTitledGroups: int): float =
  pageSz.height.float - pagePadding*2 - titleHeight - (nTitledGroups.float * groupTitleHeight)

func findBestGridShape(sz: Size; n: int; wP, hP, labelReserve: float): Grid =
  ## Find the optimal arrangement of `n` items of size `sz` in a grid in a way
  ## which maximises the covered area of a parent rectangle `wP` by `hP` and a
  ## scale factor necessary to fit the items into the resulting grid.
  # TODO: replace wP, hP with SizeF
  let arNorm = (wP / hP) / (sz.width.float / sz.height.float)
  let colF = sqrt(n.float * arNorm)
  let rowF = sqrt(n.float / arNorm)
  var bestGridCapacity = high(int)
  var (bestScale, bestScaleWLabel) = (0.0, 0.0)
  for (rows, cols) in [
      (rowF.floor, colF.ceil),
      (rowF.ceil, colF.floor),
      (rowF.ceil, colF.ceil)]:
    let cells = (rows * cols).int
    if cells >= n and cells <= bestGridCapacity:
      let cellSize = (wP / cols, hP / rows)
      let scale = bestFit(sz, cellSize)
      let cellSizeWLabel = (cellSize[0], cellSize[1] - labelReserve)
      let scaleWLabel = bestFit(sz, cellSizeWLabel)
      if scale > bestScale:
        bestGridCapacity = cells
        (bestScale, bestScaleWLabel) = (scale, scaleWLabel)
        result = Grid(cellSize: cellSize, cellSizeWLabel: cellSizeWLabel,
                      rows: rows.int, cols: cols.int, scale: scale, scaleWLabel: scaleWLabel)

proc guessProportionalDistribution(groups: openArray[Group]): seq[float] =
  ## Derive proportions of the page height using the ratio of each group's
  ## cumulative absolute area to the total absolute area occupied by all groups.
  ## Returns a sequence of proportions of 1.0.
  var totalArea: float = 0.0
  var groupAreas: seq[float]
  for group in groups:
    let weight = block:
      let w = group.weight.get(1.0)
      if w <= 0.0 or w >= 100:
        warn(&"'{group.title}' weight '{w}' is invalid!")
        1.0
      else:
        w
    let groupArea = weight * (group.itemSize.area() * group.items.len).float
    totalArea += groupArea
    groupAreas.add(groupArea)
  var pageSplits = @[0.0]
  for groupArea in groupAreas:
    let groupProportion = (groupArea / totalArea)
    pageSplits.add(pageSplits[^1] + groupProportion)
  pageSplits[1..^2]

iterator heightFractions(splits: openArray[float]): float =
  var prevSplit = 0.0
  var newsplits = splits.mapIt((let s = it - prevSplit; prevsplit = it; s))
  newsplits.add(1.0-prevsplit)
  for s in newsplits: yield s

proc allocatePageParts(groups: openArray[Group]; splits: openArray[float]; pageSize: SizeF): seq[SizeF] =
  #var prevSplit = 0.0
  for grHf in heightFractions(splits):
    let grH = grHf * pageSize.height
    result.add((pageSize.width, grH))

iterator gridifyRects(nItems, rows, cols: int; areaSize: SizeF; itemSize: Size; scale, maxDist, labelH: float): (float, float) =
  ## Distributes and places `nItems` rectangles in a given grid inside an area of `areaSize`.
  ## Rectangles are scaled by the factor `scale`. The horizontal distance between rectangles
  ## is limited by `maxDist` which is a factor of `itemSize.width`.
  # TODO: add minimal distance between elements
  let
    (itemWidth, itemHeight) = (itemSize.width.float * scale, itemSize.height.float * scale)
    cols = min(nItems, cols)
    itemXSpacing = min(maxDist*itemWidth, ((areaSize.width - cols.float * itemWidth) / max(1, (cols - 1)).float))
    itemYSpacing = block:
      let maxSpacing = maxDist*itemHeight
      let spacing = (areaSize.height - rows.float * (itemHeight + labelH)) / max(1, (rows - 1)).float
      min(maxSpacing, spacing)
    realWidth = cols.float * itemWidth + ((cols - 1).float * itemXSpacing)
    itemXOffset = (areaSize.width - realWidth) / 2
  for i in 0..<nItems:
    let
      (row, col) = (i div cols, i mod cols)
      x = itemXOffset + col.float * (itemWidth + itemXSpacing)
      y = row.float * (itemHeight + itemYSpacing + labelH)
    yield (x, y)

proc efficiency(splits: openArray[float]; groups: openArray[Group]; pW, pH: float; itemLabelHeight: float): Efficiency =
  ## A function to compute the efficiency of a given split
  var usedArea = 0.0
  var factors = newSeq[float](groups.len)
  for i, grHf in enumerate(heightFractions(splits)):
    let
      grH = max(0, grHf * pH) # Absolute group heights from page fraction
      (size, n) = (groups[i].itemSize, groups[i].items.len)
    #echo " n", n, " pW", pW, " grH", grH, " ILH", itemLabelHeight
      grid = findBestGridShape(size, n, pW, grH, itemLabelHeight)
      groupArea = float(n * size.area()) * grid.scale^2
    usedArea += groupArea
    factors[i] = grid.scale
  let (area, score) = (usedArea / (pW*pH), similarityScore(factors))
  (area, score, area*score)

func decliningSigmoidNormalized(currentIter: int): float =
  ## Returns the temperature for Fast Annealing normalized to the total number of iterations.
  const
    alpha = 0.99
    offset = 1 - alpha
    B = 6 # Declining slope  (4.5:soft .. 16:steep)
    P = 1.8 # initial plato
  alpha / E.pow(B * (currentIter.float/Iters).pow(P)) + offset

proc findBestSplit(startSplit: seq[float]; groups: openArray[Group]; pW, pH: float; itemLabelHeight: float): seq[float] =
  ## Search for optimal page splits using simulated annealing
  # TODO: integrate group weights
  if groups.len < 2:
    echo "optimality: 1.0; Optimal layout is used for a single group."
    return @[1.0]
  #when defined(debug): var strm = newFileStream("temp-" & groups[0].title & ".csv", fmWrite)
  var
    rng = initRand(getMonoTime().ticks())
    bestSplit, currentSplit, nextSplit = startSplit
    bestEff = efficiency(startSplit, groups, pW, pH, itemLabelHeight)
    currentEff = bestEff
    prevSplitIdxSucced = none(Natural)
  let initialScaleScore = bestEff.scaleScore
  #when defined(debug): strm.writeLine("currentS;scorC", ";", "nextS", ";", "scoreN",";" ,"bestS", ";", "scoreB")
  for i in 1..Iters.int:
    let temp = decliningSigmoidNormalized(i)
    nextSplit = currentSplit
    let pIdx = prevSplitIdxSucced.get(rng.rand(startSplit.len - 1))  # if previous mutation was successful, try again
    nextSplit[pIdx] += (rng.rand(MaxJump * 2.0) - MaxJump) #* temp

    # Keep the splits in page bounds (0..1)
    if  nextSplit[pIdx] >= 1: nextSplit[pIdx] = 1 - rng.rand(0.5)
    elif  nextSplit[pIdx] <= 0: nextSplit[pIdx] = rng.rand(0.5)
    nextSplit.sort() # Note: Do we care to check how slow it is?

    let nextEff = efficiency(nextSplit, groups, pW, pH, itemLabelHeight)
    let improved = nextEff.agg >= currentEff.agg
    if improved or rng.rand(1.0) < temp:
      currentSplit = nextSplit
      currentEff = nextEff
    if not improved: prevSplitIdxSucced = none(Natural)
    elif nextEff.agg > bestEff.agg:
      bestSplit = nextSplit
      bestEff = nextEff
  #when defined(debug): strm.close()
  echo bestEff
  return bestSplit

proc layoutPage(page: Page; pageSize: Size; titleSize, groupTitleSize, itemLabelSize: int): PageLayout =
  var vOffset = PagePadding
  let
    titleHeight = if page.title.isSome() and titleSize > 0: ptToMM(titleSize).float else: 0.0
    groupTitleHeight = ptToMm(groupTitleSize).float
    itemLabelHeight = ptToMm(itemLabelSize).float
    heuristicSplits = guessProportionalDistribution(page.groups)
    totalPageWidth = pageWidthAvailable(pageSize, PagePadding)
    nTitledGroups = page.groups --> filter(it.title != "").fold(0, a + 1)
    totalPageHeight = pageHeightAvailable(pageSize, PagePadding, titleHeight, groupTitleHeight, nTitledGroups)
  #when defined(debug):
  #  echo "Initial splits:", heuristicSplits, " eff:", efficiency(heuristicSplits, page.groups, totalPageWidth, totalPageHeight, itemLabelHeight)
  let splits = findBestSplit(heuristicSplits, page.groups, totalPageWidth, totalPageHeight, itemLabelHeight)
  let groupRects = allocatePageParts(page.groups, splits, (totalPageWidth, totalPageHeight))

  if titleHeight > 0.0:
    result.pageTitle = some(rect(PagePadding, vOffset, (pageSize.width.float-PagePadding*2), titleHeight))
    vOffset += titleHeight
  else:
    result.pageTitle = none(Rectangle)

  for gIdx, group in page.groups:
    result.groupTitleRects.add(
      rect(PagePadding, vOffset, (pageSize.width.float-PagePadding*2), groupTitleHeight) )
    vOffset += groupTitleHeight
    var itemRects, labelRects: seq[Rectangle]
    let
      area = groupRects[gidx]
      nItems = group.items.len
      grid = findBestGridShape(group.itemSize, nItems, area.width, area.height, itemLabelHeight)
      (rows, cols, scale) = (grid.rows, grid.cols, grid.scaleWLabel)
      (w, h) = (group.itemSize.width.float * scale, group.itemSize.height.float * scale)
    for (x, y) in gridifyrects(nItems, rows, cols, area, group.itemSize, scale, MaxItemDistanceFactor, itemLabelHeight):
      let itemRect = rect(PagePadding+x, vOffset+y, w, h)
      let labelRect = rect(itemRect.pt.x + w*0.1, itemRect.pt.y+h, w*0.8, itemLabelHeight)
      itemRects.add(itemRect)
      labelRects.add(labelRect)
    result.groups.add(itemRects)
    result.groupLabels.add(labelRects)
    vOffset += area.height

proc layoutCatalogue*(cat: Catalogue): CatalogueLayout =
  let (pageSz, titleSz, groupTitleSz, itemLabelSz) = (cat.pageSize, cat.titleSize, cat.groupTitleSize, cat.itemLabelSize)
  result.pageSize = pageSz
  echo "# Page layout stats:"
  for i, page in cat.pages.pairs():
    stdout.write(&" -{(i+1):3}: ") # stats printed in `findBestSplit`
    let pageLayout = layoutPage(page, pageSz, titleSz, groupTitleSz, itemLabelSz)
    result.pages.add(pageLayout)
