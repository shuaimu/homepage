// Editable textbook figures. Coordinates use points, with y increasing downward.
// White cells are rows/pages/plans; red marks the choice or cost under discussion.
#import "@preview/cetz:0.5.2"
#import "queryopt-theme.typ": ink, muted, red, rule, sans-font, mono-font

#let label(x, y, body, size: 18pt, color: ink, anchor: "center", mono: false) = cetz.draw.content(
  (x, -y), {
    // Figure text is technical: an apostrophe is a SQL quote, never a contraction.
    set smartquote(enabled: false)
    show raw: set text(font: mono-font, size: 1em)
    text(font: if mono { mono-font } else { sans-font }, size: size, fill: color, body)
  }, anchor: anchor,
)
#let line(points, color: ink, width: 1pt, dashed: false) = cetz.draw.line(
  ..points.map(p => (p.at(0), -p.at(1))),
  stroke: (paint: color, thickness: width, dash: if dashed { "dashed" } else { "solid" }),
)
#let arrow(x1, y1, x2, y2, color: ink) = cetz.draw.line(
  (x1, -y1), (x2, -y2), stroke: 1.2pt + color, mark: (end: ">", fill: color),
)
#let frame(x, y, w, h, color: ink, width: .9pt, dashed: false) = cetz.draw.rect(
  (x, -y), (x+w, -y - h), fill: white,
  stroke: (paint: color, thickness: width, dash: if dashed { "dashed" } else { "solid" }),
)
#let file(x, y, w, h, color: ink) = {
  line(((x,y),(x+w - 10,y),(x+w,y+10),(x+w,y+h),(x,y+h),(x,y)), color: color)
  line(((x+w - 10,y),(x+w - 10,y+10),(x+w,y+10)), color: color)
}
#let cells(x, y, values, w: 70, h: 42, size: 18pt, highlights: (), mono: true) = {
  for (i, value) in values.enumerate() {
    frame(x+i*w, y, w, h, color: if i in highlights { red } else { ink })
    label(x+(i+.5)*w, y+h/2, value, size: size, mono: mono,
      color: if i in highlights { red } else { ink })
  }
}
// One box with centred text: a plan-tree node, a subset in the DP lattice, a table.
#let node(x, y, w, h, body, size: 19pt, color: ink, mono: false, dashed: false, sub: none) = {
  frame(x, y, w, h, color: color, dashed: dashed)
  if sub == none {
    label(x+w/2, y+h/2, body, size: size, color: color, mono: mono)
  } else {
    label(x+w/2, y+h/2 - 9, body, size: size, color: color, mono: mono)
    label(x+w/2, y+h/2 + 14, sub, size: 14pt, color: muted)
  }
}
// Tree edge: a plain line from the bottom of a parent to the top of a child.
#let edge(x1, y1, x2, y2, color: ink, dashed: false) = line(((x1,y1),(x2,y2)), color: color, dashed: dashed)
#let diagram(body, height: 275) = cetz.canvas(length: 1pt, {
  cetz.draw.rect((0,0),(850,-height), stroke: none)
  body
})

// One fixed scenario throughout: EMP 10,000 rows on 500 pages (20 per page), clustered on DNO;
// DEPT 100 rows on 5 pages; JOB 50 rows on 2 pages. Every table has its own segment, so a scan reads pages(T).
// The running query is the paper's own; SAL > 20000 (F = 1/4, 2,500 EMP rows) is only the
// separate one-table example. Every cost label in this file is computed from these.
// Page strips draw 10 of EMP's 500 pages; a muted ellipsis stands for the rest.
#let emp-stats = (rows: 10000, pages: 500, per-page: 20)
#let dept-stats = (rows: 100, pages: 5)
#let job-stats = (rows: 50, pages: 2)
// Matched trio: clustered-scan, nonclustered-scatter and buffer-rescue-g share these exactly.
#let leaf-strip = (x: 60, y: 60, w: 72, h: 32, pitch: 76)
#let page-strip = (x: 60, y: 180, w: 72, h: 60, pitch: 76)

// ---- g1 ----
// The optimizer is one stage among five, and the only one that reads the statistics.
// Box widths are set by their widest contained string, so the 14pt subs clear the borders.
// The loop under the algebra tree is rewrite (in System R only CNF and pushdown; views,
// subquery flattening and unnesting came later), which works on the tree before any plan is chosen.
// The plan's operators use strawman 2's word, lookup; probe is defined with the join methods.
#let pipeline-stages() = diagram(height: 215, {
  node(10, 62, 104, 84, [SQL text])
  node(134, 62, 190, 84, [Query blocks], sub: [SELECT / FROM / WHERE])
  node(344, 62, 130, 84, [Algebra tree], sub: [σ π ⋈ ×])
  node(494, 62, 188, 84, [Plan], color: red, sub: [scan · lookup · sort · merge])
  node(702, 62, 140, 84, [Machine code])
  arrow(114, 104, 134, 104)
  arrow(324, 104, 344, 104)
  arrow(474, 104, 494, 104)
  arrow(682, 104, 702, 104)
  label(229, 34, [catalog: names and types], size: 16pt, color: muted)
  label(588, 34, [catalog: the four statistics], size: 16pt, color: muted)
  arrow(229, 58, 229, 45, color: muted)
  arrow(588, 58, 588, 45, color: muted)
  line(((384,146),(384,168),(434,168)), color: muted)
  arrow(434, 168, 434, 150, color: muted)
  label(409, 186, [rewrite], size: 16pt, color: muted)
  line(((772,146),(772,180),(612,180),(612,146)), color: muted)
  label(692, 195, [stored, re-run many times], size: 16pt, color: muted)
})

// Row counts are the paper's Figure 1 query on this lecture's sizes: 10,000 × 100 × 50 =
// 50,000,000 before pushdown; F(LOC) = 1/10 and F(TITLE) = 1/50 give 10 and 1, EMP is
// not filtered at all, the DNO join keeps 10,000 × 10 × 1/100 = 1,000, and result_rows = 20.
// The three leaves keep identical coordinates in both stages; only the interior changes.
#let algebra-tree(stage: 1, counts: true) = diagram(height: 262, {
  node(70, 204, 150, 52, [EMP], sub: [10,000])
  node(350, 204, 150, 52, [DEPT], sub: [100])
  node(630, 204, 150, 52, [JOB], sub: [50])
  if stage == 1 {
    node(295, 12, 260, 44, [π NAME, TITLE, SAL, DNAME], size: 17pt)
    node(150, 72, 550, 52,
      [σ TITLE = 'CLERK' AND LOC = 'DENVER'\
       #h(1.2em)AND EMP.DNO = DEPT.DNO AND EMP.JOB = JOB.JOB],
      size: 16pt, mono: true)
    node(70, 140, 710, 46, [×], size: 25pt, sub: [cross product])
    edge(425, 56, 425, 72)
    edge(425, 124, 425, 140)
    edge(145, 186, 145, 204)
    edge(425, 186, 425, 204)
    edge(705, 186, 705, 204)
    // The count sits inside the × node, right-aligned: there is no room outside it.
    // counts: false holds it back, so slide 9 can show the tree before its price.
    if counts { label(766, 163, [50,000,000 rows], size: 24pt, color: red, anchor: "east") }
  }
  if stage >= 2 {
    label(465, 10, [π applied on the way out], size: 15pt, color: muted)
    node(365, 26, 200, 46, [#text(size: 1.3em)[⋈] EMP.JOB = JOB.JOB], size: 15pt)
    node(145, 88, 200, 46, [#text(size: 1.3em)[⋈] EMP.DNO = DEPT.DNO], size: 15pt)
    // EMP has no local predicate, so its σ slot stays empty: all 10,000 rows go up.
    node(70, 152, 150, 38, [no filter], size: 15pt, color: muted, dashed: true)
    node(350, 152, 150, 38, [σ LOC = 'DENVER'], size: 15pt, color: red)
    node(630, 152, 150, 38, [σ TITLE = 'CLERK'], size: 15pt, color: red)
    edge(465, 72, 245, 88)
    edge(465, 72, 705, 152)
    edge(245, 134, 145, 152)
    edge(245, 134, 425, 152)
    edge(145, 190, 145, 204)
    edge(425, 190, 425, 204)
    edge(705, 190, 705, 204)
    label(62, 171, [10,000], size: 17pt, color: muted, anchor: "east")
    label(342, 171, [10], size: 17pt, color: muted, anchor: "east")
    label(622, 171, [1], size: 17pt, color: muted, anchor: "east")
    label(372, 96, [1,000], size: 17pt, color: muted, anchor: "west")
    label(590, 49, [20 rows], size: 24pt, color: red, anchor: "west")
    line(((565,49),(583,49)), color: red, width: 1.3pt)
  }
})

// Appendix slide 75: the rule book of slide 12 against the cost-based winner, on
// the paper's own query. Rule book: FROM order puts EMP first, and nothing in the WHERE
// clause filters EMP, so no index matches and it is scanned, 500, 10,000 rows. Each row
// looks DEPT up through its unique DNO index: 500 + 10,000 × 2 = 20,500, and 1,000 pairs
// survive LOC. Each pair looks JOB up through its unique index: 20,500 + 1,000 × 2 = 22,500,
// and 20 rows survive TITLE. Winner:
// DEPT scan 5, ten lookups of EMP's clustered DNO index at 5.5, 60; sort the 1,000 pairs on
// JOB, 2 × ceil(1,000 / 20) = 100; one pass of JOB, 1 + 2 = 3; 163. 22,500 / 163 = 138.0.
// The node subs are running totals, each carrying the step below it up. Stage 1 draws the
// two plan shapes with every number held back as a "?", so the room can guess before the
// reveal; stage 2, the default, adds the costs. Every coordinate is identical in both stages.
#let rule-vs-cost(stage: 2) = diagram(height: 256, {
  // Stage 1 holds each node's cost back behind a muted "?", so the boxes are already
  // balanced and the labels do not move on the reveal.
  // cetz centres a label on its glyph bounds, so a label with descenders (g, p, a comma)
  // would sit higher than its partner across the divider. A cap-height-to-baseline box
  // gives every label in a row the same baseline. Local, because label() is shared.
  let nl(body) = text(top-edge: "cap-height", bottom-edge: "baseline", body)
  let cost(body) = nl(if stage >= 2 { body } else { [?] })
  // Each column hangs on one centre line, x = 190 and x = 650: heading, nodes, edges and
  // total. The nodes taper symmetrically about it, and the divider sits midway at 420.
  label(190, 11, [Fixed rules], size: 21pt)
  label(650, 11, [Cost-based], size: 21pt)
  node(30, 36, 320, 52, nl[⋈ JOB by index], sub: cost[22,500 = 20,500 + 1,000 × 2])
  node(40, 98, 300, 52, nl[⋈ DEPT by index], sub: cost[20,500 = 500 + 10,000 × 2])
  node(60, 160, 260, 52, nl[EMP segment scan], sub: cost[500])
  edge(190, 88, 190, 98)
  edge(190, 150, 190, 160)
  node(490, 36, 320, 52, nl[sort, then merge JOB], sub: cost[163 = 60 + 100 + 3])
  node(500, 98, 300, 52, nl[⋈ EMP via DNO index], sub: cost[60 = 5 + 10 × 5.5])
  node(520, 160, 260, 52, nl[DEPT scan], sub: cost[5])
  edge(650, 88, 650, 98)
  edge(650, 150, 650, 160)
  line(((420,10),(420,212)), color: rule, width: .6pt)
  if stage >= 2 {
    label(190, 236, nl[22,500], size: 25pt, color: red)
    label(650, 236, nl[163], size: 25pt)
    label(420, 236, nl[138× apart, same 20 rows], size: 18pt, color: muted)
  } else {
    label(190, 236, nl[?], size: 25pt, color: red)
    label(650, 236, nl[?], size: 25pt)
    // The hidden prefix keeps this label as wide as the stage-2 one, so "same 20 rows" stays put.
    label(420, 236, nl[#hide[138× apart, ]same 20 rows], size: 18pt, color: muted)
  }
})

// ---- g2 ----
// ---- g2 ----
// Slide 20: where each of the four catalog numbers is measured, in the deck's
// plain names. index_pages and distinct come off the index, rows and pages off the
// table's data pages. Every page drawn holds rows of T (each table has its own disk
// segment, so a scan reads exactly pages(T)); the bracket spans all ten. The one red
// idea is distinct counted per index. The paper's names (NCARD, TCARD, ICARD, NINDX)
// appear on no slide; slide 20's note gives them.
#let statistics-catalog() = diagram(height: 226, {
  // Two-line labels get the body text's 1.5x baseline pitch (1em line box + .5em leading)
  // instead of label()'s tighter default. Local, because label() is a shared helper.
  let spaced(body) = {
    set text(top-edge: .8em, bottom-edge: -.2em)
    set par(leading: .5em)
    body
  }
  // The index: a root page and three leaf pages, with one tick per key entry.
  // label() turns smart quotes off, so possessives use a typed ’ (U+2019).
  label(26, 12, [index_pages: the index’s own pages], size: 16pt, color: muted, anchor: "west")
  frame(22, 24, 404, 82, color: rule, dashed: true)
  frame(154, 32, 96, 26)
  label(202, 45, [root], size: 13pt, color: muted)
  for i in range(3) {
    frame(36 + i * 128, 70, 112, 30)
    for j in range(5) { line(((54 + i * 128 + j * 19, 76), (54 + i * 128 + j * 19, 94))) }
    edge(202, 58, 92 + i * 128, 70)
  }
  // The one red idea: distinct is counted per index, so an un-indexed column has
  // none, which is where Table 1's constants come from on slide 23. The label says
  // so itself; the col form is named in passing, as what an indexed column has.
  arrow(476, 78, 412, 78, color: red)
  label(486, 70, spaced[distinct: distinct keys, kept per index,\ so an un-indexed column has none],
    size: 17pt, color: red, anchor: "west")
  // The table: ten data pages, every one holding rows of T.
  label(26, 128, [the table T: a scan reads all of its pages and nothing else], size: 16pt, color: muted, anchor: "west")
  for i in range(10) {
    frame(30 + i * 48, 146, 44, 56)
    for j in range(4) {
      line(((37 + i * 48, 156 + j * 12), (67 + i * 48, 156 + j * 12)))
    }
  }
  arrow(524, 168, 510, 168)
  label(530, 168, [rows(T): rows of T], size: 17pt, anchor: "west")
  line(((30, 208), (30, 216), (506, 216), (506, 208)))
  label(518, 214, [pages(T): the pages that hold them], size: 17pt, anchor: "west")
})

// Slide 25: the FROM list's product, then one boolean factor at a time in slide
// 24's order, local factors first. Bar length is 46 x log10(rows), so 50,000,000 and
// 20 share one picture: 50 x 10 x 100 x 50 = 2,500,000 and 50,000,000 / 2,500,000 = 20 =
// result_rows.
#let selectivity-funnel() = diagram(height: 228, {
  for (i, predicate, factor, w, count) in (
    (0, [], [10,000 × 100 × 50], 354, [50,000,000]),
    (1, [TITLE = 'CLERK'], [× 1/50], 276, [1,000,000]),
    (2, [LOC = 'DENVER'], [× 1/10], 230, [100,000]),
    (3, [EMP.DNO = DEPT.DNO], [× 1/100], 138, [1,000]),
    (4, [EMP.JOB = JOB.JOB], [× 1/50], 60, [20 rows]),
  ) {
    let y = 18 + i * 44
    let last = i == 4
    let c = if last { red } else { ink }
    label(20, y + 12, predicate, size: 16pt, mono: true, anchor: "west")
    label(306, y + 12, factor, size: 18pt, mono: true, anchor: "east")
    frame(320, y, w, 24, color: c)
    label(334 + w, y + 12, count, size: if last { 22pt } else { 20pt },
      mono: true, color: c, anchor: "west")
  }
})

// Private: the centre of leaf entry i and of data page i. Every arrow in the triple
// starts and lands on these, so a leaf and its page can never drift apart.
#let _lx(i) = leaf-strip.x + i * leaf-strip.pitch + leaf-strip.w / 2
#let _px(i) = page-strip.x + i * page-strip.pitch + page-strip.w / 2
// Private: the shared geometry of the matched triple. clustered-scan,
// nonclustered-scatter and buffer-rescue-g all draw their strips through this, so the
// three slides are the same picture with a different arrow pattern. page-label names
// the lower row; hot is the one page drawn in red, or -1 for none.
#let _strips(page-label, hot) = {
  // Ten of the 2,500 EMP.SAL entries that satisfy SAL > 20000, in key order.
  let keys = ([20,100], [20,400], [20,900], [21,300], [21,800],
              [22,200], [22,700], [23,400], [24,100], [25,000])
  label(leaf-strip.x - 14, leaf-strip.y + leaf-strip.h / 2, [index],
    size: 16pt, color: muted, anchor: "east")
  for (i, k) in keys.enumerate() {
    frame(leaf-strip.x + i * leaf-strip.pitch, leaf-strip.y, leaf-strip.w, leaf-strip.h)
    label(_lx(i), leaf-strip.y + leaf-strip.h / 2, k, size: 15pt, mono: true)
  }
  // Ten of EMP's 500 data pages; the muted ellipsis stands for the other 490.
  label(page-strip.x - 14, page-strip.y + page-strip.h / 2, page-label,
    size: 16pt, color: muted, anchor: "east")
  for i in range(10) {
    let c = if i == hot { red } else { ink }
    frame(page-strip.x + i * page-strip.pitch, page-strip.y, page-strip.w, page-strip.h, color: c)
    label(_px(i), page-strip.y + page-strip.h / 2, [#(i + 1)], size: 17pt, mono: true, color: c)
  }
  label(834, page-strip.y + page-strip.h / 2, [...], size: 18pt, color: muted)
}
// Private: the one scatter pattern, shared by nonclustered-scatter and buffer-rescue-g.
// Ten entries in SAL order reach six pages in DNO order, and page 4 takes five of
// them, which is 2,500 qualifying rows spread over 500 pages.
#let _scatter(color) = {
  for (i, p) in (6, 3, 7, 3, 2, 3, 5, 3, 4, 3).enumerate() {
    arrow(_lx(i), leaf-strip.y + leaf-strip.h, _px(p), page-strip.y, color: color)
  }
}

// Slide 29, on rule 1's one-table query SELECT NAME FROM EMP WHERE SAL > 20000.
// Two panels over one shared page strip: the index panel above it, the segment panel
// below, so the pages are drawn once and read twice. Red: SAL > 20000 becomes a start key
// of 20,000 and no stop key, which is why F multiplies the whole bracket in Table 2 rather
// than one term of it. Clustering is two slides away, so the three pointers fan out
// monotonically and nothing crosses yet.
// step: 0 the page strip alone, 1 adds the segment scan, 2 adds the index scan. Every
// element keeps its position across steps.
#let access-paths(step: 2) = diagram(height: 230, {
  if step >= 2 {
    label(40, 10, [Index scan], size: 20pt, anchor: "west")
    label(196, 12, [the EMP.SAL leaves, in key order], size: 16pt, color: muted, anchor: "west")
    // The matching range is leaf entries 7 to 9, bracketed above the strip, to the end.
    label(652, 34, [start key 20,000], size: 16pt, color: red)
    label(816, 34, [no stop key], size: 16pt, color: red, anchor: "east")
    line(((592, 56), (592, 48), (816, 48), (816, 56)), color: red)
    label(816, 10, [the predicate becomes the range], size: 17pt, color: red, anchor: "east")
    label(46, 73, [index], size: 16pt, color: muted, anchor: "east")
    for (i, k) in ([5,000], [7,500], [9,000], [11,000], [13,500],
                   [15,000], [17,500], [20,500], [22,500], [25,000]).enumerate() {
      frame(60 + i * 76, 58, 72, 30, color: if i >= 7 { red } else { ink })
      label(96 + i * 76, 73, k, size: 15pt, mono: true, color: if i >= 7 { red } else { ink })
    }
    for (sx, px) in ((628, 476), (704, 628), (780, 780)) { arrow(sx, 88, px, 128) }
  }
  label(46, 153, [pages], size: 16pt, color: muted, anchor: "east")
  for i in range(10) {
    frame(60 + i * 76, 128, 72, 50)
    label(96 + i * 76, 153, [#(i + 1)], size: 17pt, mono: true)
  }
  label(834, 153, [...], size: 18pt, color: muted)
  // The segment panel reads the same strip from underneath, one page at a time.
  if step >= 1 {
    for i in range(10) { line(((96 + i * 76, 178), (96 + i * 76, 188)), color: muted) }
    arrow(60, 192, 816, 192)
    label(40, 214, [Segment scan], size: 20pt, anchor: "west")
    label(196, 216, [every page of the table, once · no order],
      size: 16pt, color: muted, anchor: "west")
  }
})

// Slide 31, the first of the matched pair, still on the one-table query
// SAL > 20000. Leaf order and page order agree, so each bracket of entries sits on one
// page, the fetches never cross, and the qualifying pages are a contiguous run with the
// rest of the table left alone: ten rows, five fetches. Cost is Table 2's clustered
// matching row on EMP's SAL index, F × (index_pages + pages) = 1/4 × (40 + 500) = 135.
#let clustered-scan() = diagram(height: 268, {
  label(60, 26, [EMP.SAL index, clustered], size: 19pt, anchor: "west")
  label(816, 26, [data pages in the same order as the keys],
    size: 16pt, color: muted, anchor: "east")
  _strips([pages], -1)
  for i in range(5) {
    let x1 = leaf-strip.x + 2 * i * leaf-strip.pitch
    let x2 = x1 + leaf-strip.pitch + leaf-strip.w
    line(((x1, 96), (x1, 104), (x2, 104), (x2, 96)))
    arrow((x1 + x2) / 2, 104, _px(i), page-strip.y, color: red)
  }
  label(816, 158, [the rest of the table is never read],
    size: 16pt, color: muted, anchor: "east")
  label(60, 255, [F × (index_pages + pages)], size: 16pt, color: muted, mono: true, anchor: "west")
  label(816, 255, [1/4 × (40 + 500) = 135], size: 18pt, color: red, mono: true, anchor: "east")
})

// Slide 32, the matched partner. Nothing has moved: the same leaf strip,
// the same pages, the same 2,500 qualifying rows. The index is ordered by SAL and the pages
// by DNO, so consecutive entries point at unrelated pages and page 4 is fetched five
// separate times. That is Table 2's non-clustered matching row,
// F × (index_pages + rows) = 1/4 × (40 + 10,000) = 2,510.
#let nonclustered-scatter() = diagram(height: 268, {
  label(60, 26, [EMP.SAL index, non-clustered], size: 19pt, anchor: "west")
  label(816, 26, [data pages in DNO order, not SAL order],
    size: 16pt, color: muted, anchor: "east")
  _strips([pages], 3)
  _scatter(red)
  label(60, 255, [page 4 is fetched five separate times], size: 17pt, color: red, anchor: "west")
  label(816, 255, [1/4 × (40 + 10,000) = 2,510], size: 18pt, color: red, mono: true, anchor: "east")
})

// ---- g4 ----
// Slide 33: three access paths to the same 2,500 EMP rows of the one-table query
// (SAL > 20000, F = 1/4). Bars are linear, 0.2pt per page fetch, so the red bar is five scans long:
// a clustered SAL index would cost F × (index_pages + pages) = 135, the segment scan costs
// pages = 500, and the real non-clustered SAL index costs
// F × (index_pages + rows) = 2,510. All three return the same 2,500 rows.
#let access-path-costs() = diagram(height: 240, {
  label(16, 12, [same predicate, same 2,500 rows],
    size: 17pt, color: muted, anchor: "west")
  // Row pitch 66 leaves the red caption 13pt of clearance above the canvas floor.
  for (y, name, w, cost, loser) in (
    (26, [Clustered SAL index], 27, [135], false),
    (92, [Segment scan], 100, [500], false),
    (158, [Non-clustered SAL index], 502, [2,510], true),
  ) {
    let c = if loser { red } else { ink }
    frame(250, y, w, 44, color: c)
    label(236, y + 22, name, size: 20pt, anchor: "east")
    label(262 + w, y + 22, cost, size: 23pt, color: c, anchor: "west")
  }
  // The segment scan is the yardstick; the red bar runs five times past it.
  line(((350, 24), (350, 202)), color: muted, dashed: true)
  label(356, 81, [the scan], size: 16pt, color: muted, anchor: "west")
  label(250, 219, [what rule 1 picks: 5× worse], size: 19pt, color: red, anchor: "west")
})

// Slide 34, for EMP's non-clustered SAL index on the one-table query. The index
// pays F × (index_pages + rows) = 1.004 fetches per surviving row; the segment scan pays
// pages = 500 whatever F is. The lines cross at 498 rows, just under EMP's 500
// pages; at 100 rows the index costs 100.4, at 500 rows 502.
// Scale: x = 100 + 0.252 × rows, y = 214 − 0.0733 × page fetches, so the x axis sits at
// 214 and the tick row and the axis name get a row each above the canvas floor.
#let crossover() = diagram(height: 266, {
  arrow(100, 214, 800, 214, color: muted)
  arrow(100, 214, 100, 28, color: muted)
  label(100, 14, [page fetches], size: 17pt, color: muted, anchor: "west")
  label(540, 247, [rows the predicate keeps], size: 17pt, color: muted)
  for (x, t) in ((100, [0]), (226, [500]), (352, [1,000]), (730, [2,500])) {
    line(((x, 214), (x, 218)), color: muted)
    label(x, 228, t, size: 15pt, color: muted)
  }
  line(((100, 177), (800, 177)))
  label(798, 159, [segment scan: 500], size: 17pt, anchor: "east")
  // The red line ends on its own 2,500-row marker rather than running past it.
  line(((100, 214), (730, 30)), color: red)
  label(600, 48, [F × (40 + 10,000)], size: 17pt, color: red, anchor: "east")
  line(((226, 214), (226, 177)), color: red, dashed: true)
  label(238, 195, [about 500 rows = pages(EMP)], size: 18pt, color: red, anchor: "west")
  for (x, y) in ((125, 207), (226, 177), (730, 30)) { frame(x - 4, y - 4, 8, 8, color: red) }
  label(128, 190, [100.4], size: 15pt, color: red)
  label(226, 160, [502], size: 15pt, color: red)
  label(744, 44, [2,510], size: 15pt, color: red, anchor: "west")
  label(160, 120, [index wins], size: 18pt, color: muted)
  label(640, 195, [scan wins], size: 18pt, color: muted)
})


// Slide 36. A join written as two loops, before any algorithm or price: the outer loop reads
// DEPT once, row by row; the inner loop reads EMP again for every outer row. The two boxes
// name the loops' tables, outer and inner, and the arrows tie each to its line. The code is
// drawn as mono labels with the code block's grey bar, so it matches slide 37's code.
#let join-loops() = diagram(height: 190, {
  line(((8, 4), (8, 172)), color: rule, width: 2pt)
  for (y, code) in ((30, "for each d in DEPT:"), (70, "    for each e in EMP:"),
                    (110, "        if e.DNO = d.DNO:"), (150, "            emit (d, e)")) {
    label(26, y, raw(code), size: 24pt, mono: true, anchor: "west")
  }
  // Outer: the outside loop's table.
  frame(486, 2, 360, 74)
  label(504, 26, [*Outer*: DEPT], size: 21pt, anchor: "west")
  label(504, 56, [read once, row by row], size: 18pt, color: muted, anchor: "west")
  arrow(482, 36, 272, 30)
  // Inner: the inside loop's table, paid again per outer row.
  frame(486, 92, 360, 96)
  label(504, 116, [*Inner*: EMP], size: 21pt, anchor: "west")
  label(504, 146, [read again for every outer row;], size: 18pt, color: muted, anchor: "west")
  label(504, 172, [one lookup into it is a *probe*], size: 18pt, color: muted, anchor: "west")
  arrow(482, 120, 312, 70)
})

// Slide 38: DEPT outer, scanned in 5 pages with LOC = 'DENVER' as a search argument,
// outer_rows = 10 rows survive; EMP inner through the clustered DNO index, one probe
// 1/100 x (50 + 500) = 5.5 pages. C = 5 + 10 x 5.5 = 60. The loop is the red arrow, so its
// repeat count sits on it.
#let nested-loop() = diagram(height: 272, {
  // Multi-line labels get the body text's 1.5x baseline pitch (1em line box + .5em leading)
  // instead of label()'s tighter default. Local, because label() is a shared helper.
  let spaced(body) = {
    set text(top-edge: .8em, bottom-edge: -.2em)
    set par(leading: .5em)
    body
  }
  label(40, 28, [Outer: DEPT, LOC = 'DENVER'], size: 21pt, anchor: "west")
  // Row 3 (y 98 to 122) is the current outer row the red arrow at y = 110 leaves from,
  // drawn red.
  for i in range(6) { frame(40, 42 + i * 28, 150, 24, color: if i == 2 { red } else { ink }) }
  label(115, 222, [outer_rows = 10 survive], size: 16pt, color: muted)
  // One surviving outer row at a time supplies the inner index's search constant.
  label(320, 80, spaced[one outer row supplies\ the constant], size: 17pt, color: red)
  arrow(190, 110, 450, 110, color: red)
  label(320, 134, [repeat outer_rows times], size: 17pt, color: red)
  // Inner apparatus: index root, leaf strip, clustered data pages. Entered once per outer row.
  frame(460, 38, 370, 196, color: red, dashed: true)
  label(600, 26, [EMP.DNO index], size: 19pt)
  frame(540, 48, 80, 30)
  for i in range(4) {
    edge(580, 78, 510 + i * 70, 98)
    frame(480 + i * 70, 98, 60, 28)
  }
  for i in range(4) { frame(480 + i * 76, 160, 72, 46) }
  for i in range(4) { arrow(510 + i * 70, 126, 516 + i * 76, 160) }
  label(640, 222, [one clustered probe: 5.5 pages], size: 16pt, color: muted)
  label(40, 258, [C = C_outer + outer_rows × C_inner = 5 + 10 × 5.5 = 60], size: 21pt, mono: true, anchor: "west")
})

// ---- g6 ----
// Slide 44. Both {EMP, DEPT} plans come from numbers.md: DEPT scan outer then an
// EMP.DNO probe is 5 + 10 x 5.5 = 60; EMP scan outer then a DEPT.DNO probe is
// 500 + 10,000 x 2 = 20,500. Either way 1,000 rows come out, LOC and the DNO join applied.
// The continuation prices a merge with JOB at + 3 if the composite is already in JOB order and
// + sort(1,000) 100 + 3 if not, or 1,000 x 2 = 2,000 nested-loop probes, so only the order of
// the sub-plan survives the state box. Stage 1 is the question: the two trees, their costs and
// the state box. Stage 2 adds the answer, the red continuation; stage 3 adds the order caveat.
#let dp-prefix-irrelevance(stage: 3) = diagram(height: 240, {
  // Upper plan tree: DEPT outer, EMP inner.
  label(72, 33, [60], size: 17pt, color: muted, anchor: "east")
  node(80, 18, 48, 30, [⋈], size: 21pt)
  edge(104, 48, 50, 66)
  edge(104, 48, 158, 66)
  node(8, 66, 84, 30, [DEPT], size: 17pt)
  node(116, 66, 84, 30, [EMP], size: 17pt)
  arrow(132, 31, 296, 92)
  // Lower plan tree: EMP outer, DEPT inner.
  label(72, 131, [20,500], size: 17pt, color: muted, anchor: "east")
  node(80, 116, 48, 30, [⋈], size: 21pt)
  edge(104, 146, 50, 164)
  edge(104, 146, 158, 164)
  node(8, 164, 84, 30, [EMP], size: 17pt)
  node(116, 164, 84, 30, [DEPT], size: 17pt)
  arrow(132, 131, 296, 121)
  // The one state box both trees collapse into.
  label(420, 56, [LOC and the DNO join applied], size: 15pt, color: muted)
  node(300, 76, 240, 62, [{EMP, DEPT}], sub: [1,000 rows])
  if stage >= 2 {
    // Red: the continuation is priced once, off the state box alone.
    label(715, 56, [the same cost, either way], size: 18pt, color: red)
    node(620, 76, 190, 62, [⋈ JOB], size: 21pt, color: red)
    arrow(544, 107, 616, 107, color: red)
  }
  if stage >= 3 {
    // The one property the state box does not absorb.
    label(300, 162, [unless they differ in order], size: 17pt, color: red, anchor: "west")
    node(300, 182, 170, 40, [sorted on JOB?], size: 17pt, color: muted)
    line(((474, 188), (516, 188)), color: red, dashed: true)
    arrow(516, 188, 540, 188, color: red)
    label(548, 188, [merge: + 3 if yes, + 100 + 3 if not], size: 17pt, color: muted, anchor: "west")
    line(((474, 216), (516, 216)), color: red, dashed: true)
    arrow(516, 216, 540, 216, color: red)
    label(548, 216, [nested loops: + 2,000 in any order], size: 17pt, color: muted, anchor: "west")
  }
})

// Slide 46. EMP in DNO order costs 50 + 500 = 550 and merges DEPT's own 7-page
// path for 557; the 500-page segment scan must pay sort(10,000) = 2 x 500 = 1,000 first, so
// the same 7-page merge lands at 500 + 1,000 + 7 = 1,507. Both routes carry the + 7, so only
// SORT differs. Both totals sit right-aligned at the canvas edge, clear of the merge boxes.
// The two merge boxes share one geometry, so the routes line up; the takeaway carries the moral.
// The subs starting with a plus sign are escaped: a bare + opens a Typst enum item.
// step: 0 two of EMP's four paths, the scan the cheaper one on its own; 1 adds the lower route, what
// keeping only the scan costs at the merge; 2 adds the upper route, the kept ordered path.
// Every element keeps its position across steps.
#let order-in-state(step: 2) = diagram(height: 214, {
  node(40, 90, 140, 52, [EMP], size: 21pt)
  arrow(184, 106, 226, 58)
  arrow(184, 126, 226, 158)
  // Upper route: the order is kept, so no sort is ever needed.
  node(230, 20, 250, 52, [DNO index scan], sub: [550, in DNO order])
  if step >= 2 {
    arrow(484, 46, 596, 46)
    node(600, 20, 150, 52, [merge DEPT], sub: [\+ 7])
    label(846, 46, [557], size: 24pt, anchor: "east")
  }
  line(((220, 112), (846, 112)), color: rule, width: .6pt)
  // Lower route: identical except for one red box.
  node(230, 152, 198, 52, [segment scan], sub: [500, unordered])
  if step >= 1 {
    arrow(428, 178, 450, 178)
    node(454, 152, 120, 52, [SORT], sub: [1,000], color: red)
    arrow(574, 178, 596, 178)
    node(600, 152, 150, 52, [merge DEPT], sub: [\+ 7])
    label(846, 178, [1,507], size: 24pt, color: red, anchor: "east")
  }
})

// Slide 49. The join graph has edges EMP-DEPT and EMP-JOB only, so the two orders that start
// with DEPT and JOB would open with a cross product: they are struck, and {DEPT, JOB} is never entered.
// Step 0 lists the six orders plain, for the room to find the two; step 1 strikes them in place.
#let no-cross-products(step: 1) = diagram(height: 236, {
  line(((440, 6), (440, 226)), color: rule, width: .6pt)
  // Left: the join graph, and the edge that is not there.
  label(20, 14, text(bottom-edge: "descender")[Join predicates], size: 20pt, anchor: "west")
  node(170, 50, 120, 46, [EMP], size: 21pt)
  node(40, 156, 120, 46, [DEPT], size: 21pt)
  node(290, 156, 120, 46, [JOB], size: 21pt)
  line(((205, 96), (100, 156)))
  line(((255, 96), (350, 156)))
  label(115, 124, [DNO], size: 15pt, color: muted)
  label(335, 124, [JOB], size: 15pt, color: muted)
  line(((160, 179), (290, 179)), color: red, dashed: true)
  line(((215, 191), (235, 167)), color: red, width: 1.6pt)
  label(225, 220, [no predicate], size: 17pt, color: red)
  // Right: the six orders of three tables; two open with DEPT and JOB side by side.
  label(470, 14, text(bottom-edge: "descender")[The six orders], size: 20pt, anchor: "west")
  for (i, order, legal) in (
    (0, [DEPT, EMP, JOB], true), (1, [EMP, DEPT, JOB], true), (2, [EMP, JOB, DEPT], true),
    (3, [JOB, EMP, DEPT], true), (4, [DEPT, JOB, EMP], false), (5, [JOB, DEPT, EMP], false),
  ) {
    let y = 54 + i * 33
    let struck = not legal and step >= 1
    label(480, y, order, size: 18pt, mono: true, anchor: "west", color: if struck { red } else { ink })
    if struck {
      line(((476, y), (638, y)), color: red, width: 1.3pt)
      label(652, y, [cross product first], size: 15pt, color: red, anchor: "west")
    }
  }
})

// Slide 50. Left: a left-deep tree, where every join's inner (right child) is one base
// table, so the plan is the order A, B, C, D. Right: a bushy tree, whose top join has a
// composite as its inner; System R never prices that shape. Tables are generic, as on the
// tree-shape slide in the appendix: a bushy tree needs four tables, and the running query has three.
#let left-deep() = diagram(height: 200, {
  line(((430, 6), (430, 196)), color: rule, width: .6pt)
  // Left-deep, considered. Inner leaves in red.
  label(20, 12, [Left-deep: considered], size: 20pt, anchor: "west")
  for (x1, y1, x2, y2) in ((286, 54, 206, 70), (286, 54, 348, 70), (206, 98, 126, 114),
                           (206, 98, 268, 114), (126, 142, 70, 158), (126, 142, 188, 158)) {
    edge(x1, y1, x2, y2)
  }
  node(262, 26, 48, 28, [⋈], size: 21pt)
  node(182, 70, 48, 28, [⋈], size: 21pt)
  node(102, 114, 48, 28, [⋈], size: 21pt)
  node(40, 158, 60, 28, [A], size: 19pt)
  node(158, 158, 60, 28, [B], size: 19pt, color: red)
  node(238, 114, 60, 28, [C], size: 19pt, color: red)
  node(318, 70, 60, 28, [D], size: 19pt, color: red)
  label(240, 57, [outer], size: 14pt, color: muted, anchor: "east")
  label(324, 57, [inner], size: 14pt, color: red, anchor: "west")
  label(250, 172, [order: A, B, C, D], size: 16pt, color: muted, anchor: "west")
  // Bushy, not considered: the top join's inner is the composite C ⋈ D.
  label(450, 12, [Bushy: not considered], size: 20pt, color: muted, anchor: "west")
  frame(662, 76, 166, 102, color: red, dashed: true)
  for (x1, y1, x2, y2) in ((646, 54, 546, 84), (646, 54, 746, 84), (546, 112, 500, 142),
                           (546, 112, 592, 142), (746, 112, 700, 142), (746, 112, 792, 142)) {
    edge(x1, y1, x2, y2, color: muted, dashed: true)
  }
  node(622, 26, 48, 28, [⋈], size: 21pt, color: muted, dashed: true)
  node(522, 84, 48, 28, [⋈], size: 21pt, color: muted, dashed: true)
  node(722, 84, 48, 28, [⋈], size: 21pt, color: muted, dashed: true)
  for (x, t) in ((470, [A]), (562, [B]), (670, [C]), (762, [D])) {
    node(x, 142, 60, 28, t, size: 19pt, color: muted, dashed: true)
  }
  label(745, 191, [inner: a composite], size: 16pt, color: red)
})

// Appendix slide 83. EMP.DNO = DEPT.DNO and DEPT.DNO = F.DNO put all three names
// in one order equivalence class, so the DP keeps one entry for the whole class, not three.
// F is a third, hypothetical table; the running query has two classes, DNO and JOB.
#let equivalence-class() = diagram(height: 202, {
  label(290, 18, [E.DNO = D.DNO], size: 17pt, mono: true)
  label(560, 18, [D.DNO = F.DNO], size: 17pt, mono: true)
  frame(30, 40, 790, 86, color: red, width: 1.3pt)
  node(65, 56, 180, 54, [E.DNO], size: 21pt, mono: true)
  node(335, 56, 180, 54, [D.DNO], size: 21pt, mono: true)
  node(605, 56, 180, 54, [F.DNO], size: 21pt, mono: true)
  line(((245, 83), (335, 83)))
  line(((515, 83), (605, 83)))
  label(425, 150, [one order equivalence class], size: 20pt, color: red)
  label(425, 180, [a plan sorted on any one of them is sorted on all three], size: 17pt, color: muted)
})

// ---- g7 ----
// ---- g7 ----
// Slides 51 and 52. The dynamic-programming table drawn as a lattice that grows upward, like
// slide 53's plan tree: singles at the bottom, then pairs, then the triple. Every number is from
// numbers.md. Level one is slide 80's ten single-table paths, seven kept; level two is slide
// 81's fourteen pair plans, six kept; the triple is 60 + sort(1,000) 100 + merge JOB 3
// = 163. A sub holds the entries kept for that subset, tagged with the order each one delivers;
// the struck list to its right was priced and discarded. DEPT, EMP and JOB sit in that order so
// EMP, the hub of the join graph, is in the middle and no edge crosses another. {DEPT, JOB}
// shares no join predicate, is never entered, and so has no node.
// Under the lattice, a panel explains the box under discussion, which turns red: one row per
// price, the kept entries first, each with its arithmetic and why it is kept or struck.
// stage: 2 draws slide 51 (singles and pairs, then the question), 3 draws slide 52 (the triple).
// step: how far into the stage's reveal. Stage 2: 0 singles and the keep rule (red on this
// step, grey after); 1 to 3 explain DEPT, EMP and JOB; 4 adds and explains {EMP, DEPT}; 5 adds
// and explains {EMP, JOB}, with the {DEPT, JOB} note and "extended by one table"; 6 clears the
// panel and asks the question, with the two dear entries red in their subs. Stage 3: 0 the finished pairs; 1 adds and explains the triple
// and the plans it beats; 2 marks the winner in red. Every element keeps its position across
// steps; only the panel and the red box change.
#let dp-lattice(stage: 2, step: 6) = diagram(height: 376, {
  // Two-line labels get the body text's 1.5x baseline pitch (1em line box + .5em leading)
  // instead of label()'s tighter default. Local, because label() is a shared helper.
  let spaced(body) = {
    set text(top-edge: .8em, bottom-edge: -.2em)
    set par(leading: .5em)
    body
  }
  let pair-one = stage >= 3 or step >= 4
  let pair-two = stage >= 3 or step >= 5
  let triple = stage >= 3 and step >= 1
  let winner = stage >= 3 and step >= 2
  // The box under discussion, and the colour that marks it.
  let focus = if stage == 2 { (none, "DEPT", "EMP", "JOB", "ED", "EJ", none).at(step) }
    else if triple { "all" } else { none }
  let mark(key) = if focus == key { red } else { ink }
  // The two dear ordered entries turn red in their subs on the question step.
  let asked = if stage == 2 and step >= 6 { red } else { muted }
  // Level one, at the bottom: one stored relation each. 550 and 10,050 are dearer than the
  // 500 scan and survive only because they arrive in DNO and in JOB order. EMP's SAL index
  // matches nothing in this query, so it is a 10,040-page full pass in an order nobody wants.
  // JOB's segment scan reads its 2 pages and ties the unique TITLE index's 1 + 1 = 2; one
  // unordered entry is kept, so the scan is struck and labelled a tie.
  label(76, 202, [singles], size: 15pt, color: muted, anchor: "east")
  node(84, 174, 160, 56, [DEPT], size: 19pt, color: mark("DEPT"), sub: [5 · 7 DNO])
  label(252, 202, [#strike[10.2]], size: 14pt, color: muted, anchor: "west")
  node(330, 174, 200, 56, [EMP], size: 19pt, color: mark("EMP"), sub: [500 · 550 DNO · 10,050 JOB])
  label(538, 202, [#strike[10,040]], size: 14pt, color: muted, anchor: "west")
  node(620, 174, 160, 56, [JOB], size: 19pt, color: mark("JOB"), sub: [2 · 3 JOB])
  label(788, 202, [#strike[2], a tie], size: 14pt, color: muted, anchor: "west")
  // The keep rule applies at every level: red on the click that introduces it, grey after.
  label(846, 248, [kept: the cheapest, plus the cheapest in each useful order], size: 15pt,
    color: if stage == 2 and step == 0 { red } else { muted }, anchor: "east")
  // Level two: each level-one entry extended by one relation, both join methods priced.
  // Seven plans priced per pair, three kept: one unordered and one per interesting order.
  if pair-one {
    edge(164, 174, 277, 146)
    edge(430, 174, 277, 146)
    label(179, 118, [pairs], size: 15pt, color: muted, anchor: "east")
    node(187, 90, 180, 56, [{EMP, DEPT}], size: 17pt, color: mark("ED"),
      sub: [60 · 62 DNO · #text(fill: asked)[30,050 JOB]])
    label(375, 118, spaced[#strike[557 · 1,507]\ #strike[20,500 · 20,550]], size: 14pt, color: muted, anchor: "west")
  }
  if pair-two {
    label(846, 158, [extended by one table], size: 14pt, color: muted, anchor: "east")
    edge(430, 174, 595, 146)
    edge(700, 174, 595, 146)
    node(495, 90, 200, 56, [{EMP, JOB}], size: 17pt, color: mark("EJ"),
      sub: [203 · 204 JOB · #text(fill: asked)[20,550 DNO]])
    label(705, 118, spaced[#strike[1,503 · 10,053]\ #strike[20,500 · 30,050]],
      size: 14pt, color: muted, anchor: "west")
    // The subset with no join predicate between its relations is never priced at all.
    label(0, 248, [{DEPT, JOB}: no join predicate, never entered], size: 15pt, color: muted, anchor: "west")
  }
  if stage == 2 and step >= 6 {
    // The question slide 52 answers, asked where the triple will stand: each entry produces
    // the same rows as its subset's cheap plan, 30,050 as 60 and 20,550 as 203, and is held
    // only for its order. Kept inside the canvas's top edge, so this step does not grow the
    // figure and shift it.
    arrow(277, 88, 380, 76, color: red)
    arrow(595, 88, 482, 76, color: red)
    label(431, 11, [30,050 and 20,550 are kept only for their order], size: 20pt, color: red)
    label(431, 36, [the same rows as the 60 and the 203, already in JOB and DNO order], size: 16pt, color: muted)
    label(431, 60, [Will the triple use either?], size: 16pt, color: muted)
  }
  // Level three, at the top, and the answer: both dear ordered entries lose, 30,053 and 20,557.
  // The red thread is the winning path: DEPT, then {EMP, DEPT}, then the triple.
  if triple {
    edge(277, 90, 431, 60)
    edge(595, 90, 431, 60)
    label(308, 32, [the triple], size: 15pt, color: muted, anchor: "east")
    label(554, 32, spaced[#strike[230 · 603 · 2,060]\ #strike[20,557 · 30,053]],
      size: 14pt, color: muted, anchor: "west")
  }
  if winner {
    line(((164, 174), (277, 146)), color: red, width: 1.8pt)
    line(((277, 90), (431, 60)), color: red, width: 1.8pt)
  }
  if triple {
    node(316, 4, 230, 56, [{EMP, DEPT, JOB}], size: 17pt, color: mark("all"),
      sub: if winner { text(fill: red)[60 + 100 + 3 = 163] } else { [60 + 100 + 3 = 163] })
  }
  // The box under discussion gets a 1.8pt red outline over its hairline frame, the weight of
  // the winning path, so it reads at projector distance.
  let boxes = (DEPT: (84, 174, 160, 56), EMP: (330, 174, 200, 56), JOB: (620, 174, 160, 56),
    ED: (187, 90, 180, 56), EJ: (495, 90, 200, 56), all: (316, 4, 230, 56))
  if focus != none {
    let (x, y, w, h) = boxes.at(focus)
    cetz.draw.rect((x, -y), (x + w, -y - h), stroke: 1.8pt + red)
  }
  // The panel: a hairline under the lattice, then one row per price on the red box: the value
  // (red if kept, struck if not), its arithmetic, and in grey why it is kept or struck. 5.5 is
  // one probe of EMP's clustered DNO index, 201 one of its JOB index, and 2 one lookup through
  // a unique index; sort is 2 x ceil(rows / 20).
  let kept(value) = text(fill: red, value)
  let lost(value) = text(fill: muted, strike(value))
  let rows = (
    DEPT: (
      (kept[5], [segment scan: all 5 pages, LOC = 'DENVER' tested as rows are read], [the cheapest]),
      (kept[7 DNO], [DNO index, clustered, read end to end: 2 + 5], [the cheapest in DNO order]),
      (lost[10.2], [LOC index, non-clustered, matching LOC: 1/10 × (2 + 100)], [dearer than 5, and no join wants LOC order]),
    ),
    EMP: (
      (kept[500], [segment scan: all 500 pages], [the cheapest]),
      (kept[550 DNO], [DNO index, clustered, read end to end: 50 + 500], [the cheapest in DNO order]),
      (kept[10,050 JOB], [JOB index, non-clustered, read end to end: 50 + 10,000], [the only path in JOB order]),
      (lost[10,040], [SAL index, non-clustered, read end to end: 40 + 10,000], [dearer than 500, and no join wants SAL order]),
    ),
    JOB: (
      (kept[2], [TITLE index, unique, TITLE = 'CLERK': 1 index page + 1 data page], [the cheapest]),
      (kept[3 JOB], [JOB index, clustered, read end to end: 1 + 2], [the cheapest in JOB order]),
      (lost[2], [segment scan: both pages], [ties the TITLE index; one unordered plan is kept]),
    ),
    ED: (
      (kept[60], [DEPT’s scan 5 + a probe of EMP’s DNO index per Denver row: 10 × 5.5], [the cheapest]),
      (kept[62 DNO], [DEPT’s DNO index 7 + the same 10 probes, 55], [the cheapest in DNO order]),
      (kept[30,050 JOB], [EMP’s JOB index 10,050 + a lookup in DEPT per row: 10,000 × 2], [the only plan in JOB order]),
      (lost[557 · 1,507], [merges: EMP in DNO order (index 550, or scan + sort 1,500) + DEPT’s 7], [dearer than 62]),
      (lost[20,500 · 20,550], [EMP outside (scan 500 or DNO index 550) + 10,000 × 2], [dearer than 60 and 62]),
    ),
    EJ: (
      (kept[203], [JOB’s TITLE index 2 + a probe of EMP’s JOB index for its 1 row: 201], [the cheapest]),
      (kept[204 JOB], [JOB’s JOB index 3 + the same probe, 201], [the cheapest in JOB order]),
      (kept[20,550 DNO], [EMP’s DNO index 550 + a lookup in JOB per row: 10,000 × 2], [the only plan in DNO order]),
      (lost[1,503 · 10,053], [merges: EMP in JOB order (scan + sort 1,500, or index 10,050) + JOB’s 3], [dearer than 204]),
      (lost[20,500 · 30,050], [EMP outside (scan 500 or JOB index 10,050) + 10,000 × 2], [dearer than 203 and 204]),
    ),
    all: (
      (kept[163], [{EMP, DEPT}’s 60 + 100 to sort its 1,000 rows on JOB + 3 to merge with JOB], [the cheapest;\ with no ORDER BY, the only plan kept]),
      (lost[230 · 603], [{EMP, JOB}’s 203, then DEPT by sort 20 + merge 7, or by 200 × 2 lookups], [dearer than 163]),
      (lost[2,060], [{EMP, DEPT}’s 60 + a lookup in JOB per row: 1,000 × 2], [dearer than 163]),
      (lost[20,557 · 30,053], [the ordered entries need no sort: 20,550 + 7 and 30,050 + 3], [the sort they save costs 20 or 100]),
    ),
  )
  if focus != none {
    line(((0, 262), (846, 262)), color: rule, width: .6pt)
    label(0, 270, anchor: "north-west", size: 15pt, box(width: 846pt, {
      set text(top-edge: .8em, bottom-edge: -.2em)
      set par(leading: .5em)
      // A fixed value column, wide enough for two struck numbers, so the text never shifts.
      grid(columns: (112pt, 1fr), column-gutter: 18pt, row-gutter: 7.5pt,
        ..rows.at(focus).map(((value, how, why)) => (value,
          if why == none { how } else { [#how #text(fill: muted)[· #why]] })).flatten())
    }))
  }
})

// Slide 53. The plan the search returns, read bottom-up: DEPT's five-page segment scan with
// LOC as a search argument (10 rows), ten probes of EMP's clustered DNO index at 5.5 pages each
// (5 + 55 = 60, 1,000 rows), a sort of the 1,000-row composite on JOB (2 x ceil(1,000 / 20) =
// 100, so 160 so far), then a merge against JOB's clustered index with TITLE as a search
// argument (1 + 2 = 3). 160 + 3 = 163 page fetches for 20 rows. EMP has no local predicate, so
// its probe carries only the DNO value. The ledger prices the same 20 rows three other ways:
// slide 75's rule book at 138x (22,500), the user's own FROM order at 126x (20,603), and
// slide 9's tree as parsed at about 31,000x (5,000,000 / 163 = 30,675).
#let winning-plan() = diagram(height: 266, {
  // The plan tree, root at the top: merge(sort(nested loop(DEPT, EMP)), JOB). Levels sit
  // 68 apart.
  node(197, 8, 230, 46, [⋈ merge], size: 18pt, sub: [20 rows out])
  edge(312, 54, 205, 76)
  edge(312, 54, 433, 76)
  node(80, 76, 250, 46, [SORT on JOB], size: 18pt, sub: [100 pages · 160 so far])
  node(338, 76, 190, 46, [JOB], size: 19pt, sub: [TITLE = 'CLERK' · 3])
  edge(205, 122, 205, 144)
  node(80, 144, 250, 46, [⋈ nested loop], size: 18pt, sub: [5 + 55 = 60 · 1,000 rows])
  edge(205, 190, 98, 212)
  edge(205, 190, 320, 212)
  node(8, 212, 180, 46, [DEPT], size: 19pt, sub: [LOC = 'DENVER' · 5])
  node(212, 212, 216, 46, [EMP], size: 19pt, sub: [DNO index · 10 × 5.5])
  // The number the hour was for.
  arrow(427, 31, 452, 31, color: red)
  label(460, 31, [163], size: 28pt, color: red, anchor: "west")
  // Ledger: the same 20 rows, priced three other ways. Name, then cost and factor.
  line(((548, 8), (548, 258)), color: rule, width: .6pt)
  label(564, 24, [the same 20 rows, priced three other ways],
    size: 15pt, color: muted, anchor: "west")
  for (y, name, cost, factor) in (
    (64, [the rule book], [22,500], [138×]),
    (134, [the FROM order as written], [20,603], [126×]),
    (204, [the tree as parsed], [≈ 5,000,000], [≈ 31,000×]),
  ) {
    label(564, y, name, size: 16pt, color: muted, anchor: "west")
    label(564, y + 28, cost, size: 21pt, anchor: "west")
    label(846, y + 28, factor, size: 18pt, color: muted, anchor: "east")
  }
})

// ---- g8 ----
// Uncorrelated and correlated subqueries on one geometry: only the arrow pattern, the
// subquery text and the badge change. AVG(SAL) = 15000 is the midpoint of the EMP.SAL
// index keys (low 5,000, high 25,000), illustrative. The correlated example stays inside
// the lecture's schema: each employee against their own department's average, the
// reference X.DNO carried from the outer row. Row boxes are placeholders -- the figure
// is about how often the inner block runs, not about row values.
#let subquery(mode: "uncorrelated") = diagram(height: 215, {
  // Multi-line labels get the body text's 1.5x baseline pitch (1em line box + .5em leading)
  // instead of label()'s tighter default. Local, because label() is a shared helper.
  let spaced(body) = {
    set text(top-edge: .8em, bottom-edge: -.2em)
    set par(leading: .5em)
    body
  }
  // Shared geometry, identical in both modes.
  label(175, 16, if mode == "correlated" { [Outer block: EMP X] } else { [Outer block: EMP] }, size: 21pt)
  frame(25, 32, 300, 152)
  for k in range(5) {
    cells(37, 44 + 26 * k, ([EMP row #(k + 1)],), w: 276, h: 24, size: 17pt)
  }
  // The outer predicate names the column the subquery feeds: SAL both times,
  // = for the overall average, > for the department's. Same position in both modes.
  label(175, 201, if mode == "correlated" { [WHERE SAL > ?] } else { [WHERE SAL = ?] },
    size: 18pt, color: muted, mono: true)
  label(700, 34, [Subquery], size: 19pt)
  frame(560, 54, 280, 92)
  if mode == "uncorrelated" {
    label(700, 100, [SELECT AVG(SAL) FROM EMP], size: 17pt, mono: true)
    node(392, 78, 100, 44, [15000], size: 21pt, color: red, mono: true)
    arrow(556, 100, 496, 100, color: red)
    arrow(388, 100, 329, 100, color: red)
    label(700, 170, [1 ×], size: 25pt, color: red)
    label(700, 198, [evaluate once, substitute 15000], size: 18pt, color: red)
  }
  if mode == "correlated" {
    label(700, 100, spaced[SELECT AVG(SAL) FROM EMP\ WHERE EMP.DNO = X.DNO], size: 17pt, mono: true)
    // One probe out (carrying X.DNO) and one answer back for every outer row. The
    // endpoints are spread 10pt apart down the box's left edge, and each return leg
    // runs 6pt under its own outbound leg at both ends, so no two legs cross.
    for k in range(5) {
      arrow(329, 56 + 26 * k, 556, 76 + 10 * k, color: red)
      arrow(556, 82 + 10 * k, 329, 62 + 26 * k, color: muted)
    }
    label(700, 170, [outer_rows ×], size: 25pt, color: red)
    label(700, 198, [re-evaluate per outer row], size: 18pt, color: red)
  }
})

// Leis et al., VLDB 2015: fraction of cardinality estimates off by more than a factor
// of ten, by number of joins, for PostgreSQL and for the best estimator they tested.
// Bars run right from x 220 at 10 points per percentage point.
#let qerror-by-joins() = diagram(height: 219, {
  // Legend: a swatch in each bar style, so black and grey outlines read as a key.
  // Both labels are boxed down to the descender line, so the g and Q of PostgreSQL
  // do not lift it above its neighbour; the swatches sit on the capital letters.
  frame(220, 5, 16, 12)
  label(242, 13, text(bottom-edge: "descender")[PostgreSQL], size: 16pt, anchor: "west")
  frame(420, 5, 16, 12, color: muted)
  label(442, 13, text(bottom-edge: "descender")[best estimator tested], size: 16pt, color: muted, anchor: "west")
  line(((220, 28), (220, 186)))
  // 4pt inside a pair, 11pt between pairs, so the three groups read as three.
  for (y, name, pg, best, pgval, bestval, hot) in (
    (30, [1 join], 160, 150, [16%], [15%], false),
    (85, [2 joins], 320, 250, [32%], [25%], false),
    (140, [3 joins], 520, 360, [52%], [36%], true),
  ) {
    label(206, y + 22, name, size: 19pt, anchor: "east")
    frame(220, y, pg, 20, color: if hot { red } else { ink })
    label(230 + pg, y + 10, pgval, size: 20pt, color: if hot { red } else { ink }, anchor: "west")
    frame(220, y + 24, best, 20, color: muted)
    label(230 + best, y + 34, bestval, size: 20pt, color: muted, anchor: "west")
  }
  label(220, 204, [base-table median q-error: 1.00 to 1.06], size: 17pt, color: muted, anchor: "west")
})

// Leis et al., VLDB 2015, Table 3 with primary-key and foreign-key indexes: cost of
// the best plan of each shape relative to the best plan overall, as median on the
// first line and 95th percentile / maximum on the second.
#let tree-shape-penalty() = diagram(height: 226, {
  // Slot-local geometry per shape: leaf boxes (x, y, name) at 56 x 28, and the join
  // vertices they hang from, in F18's tree style. Levels: root 32, upper leaf 44,
  // inner join 60, middle leaf 76, lower join 92, bottom leaves 110.
  let shapes = (
    (40, [Zig-zag], false,
      ((2, 44, [A]), (60, 110, [B]), (122, 110, [C]), (154, 76, [D])),
      ((90, 32, 30, 44), (90, 32, 150, 60), (150, 60, 182, 76),
       (150, 60, 119, 92), (119, 92, 88, 110), (119, 92, 150, 110))),
    (320, [Left-deep], true,
      ((4, 110, [A]), (66, 110, [B]), (96, 76, [C]), (154, 44, [D])),
      ((137, 32, 182, 44), (137, 32, 93, 60), (93, 60, 124, 76),
       (93, 60, 63, 92), (63, 92, 32, 110), (63, 92, 94, 110))),
    (600, [Right-deep], false,
      ((0, 44, [A]), (58, 76, [B]), (88, 110, [C]), (150, 110, [D])),
      ((73, 32, 28, 44), (73, 32, 117, 60), (117, 60, 86, 76),
       (117, 60, 147, 92), (147, 92, 116, 110), (147, 92, 178, 110))),
  )
  for (x0, title, hot, leaves, edges) in shapes {
    let c = if hot { red } else { ink }
    label(x0 + 105, 14, title, size: 20pt)
    for (ax, ay, bx, by) in edges { edge(x0 + ax, ay, x0 + bx, by, color: c) }
    for (lx, ly, t) in leaves {
      frame(x0 + lx, ly, 56, 28, color: c)
      label(x0 + lx + 28, ly + 14, t, size: 19pt, color: c)
    }
  }
  for (x, med, tail, hot) in (
    (145, [1.00], [1.16 / 1.88], false),
    (425, [1.94], [48.2 / 1,252], true),
    (705, [6.46], [140 / 6,108], false),
  ) {
    label(x, 162, med, size: 23pt, mono: true, color: if hot { red } else { ink })
    // Boxed to the descender line so the commas in 1,252 and 6,108 do not lift their labels.
    label(x, 188, text(bottom-edge: "descender", tail), size: 17pt, color: muted)
  }
  label(425, 213, [System R’s space], size: 18pt, color: red)
})

// ---- figures added in the notes-driven rewrite, section A ----
// Slide 4: the notes' schema block as one aligned table. Each table's row is bold
// with its columns in grey; its indexes sit indented beneath it; pages are right-aligned
// so the sizes read straight down. Sizes are this lecture's, not the paper's; the index
// sizes (SAL 40, DNO and JOB 50) are assumed.
#let tables-a() = {
  set text(size: 20pt)
  let t(name, cols, size, pages, first: false) = (
    table.cell(colspan: 2, inset: (top: if first { 6pt } else { 15pt }, bottom: 6pt, x: 0pt),
      [*#name* #h(3pt) #text(fill: muted)[(#cols)]]),
    table.cell(inset: (top: if first { 6pt } else { 15pt }, bottom: 6pt, x: 0pt), size),
    table.cell(inset: (top: if first { 6pt } else { 15pt }, bottom: 6pt, x: 0pt), align(right, strong(pages))),
  )
  let i(col, kind, values, pages) = (
    pad(left: 26pt)[index on #col], kind, values, align(right, pages),
  )
  table(
    columns: (auto, auto, 1fr, auto),
    column-gutter: 28pt,
    inset: (x: 0pt, y: 6pt),
    stroke: none,
    align: left + horizon,
    ..t([EMP], [NAME, DNO, JOB, SAL], [10,000 rows, stored in DNO order], [500 pages], first: true),
    ..i([DNO], [clustered], [100 values, 100 rows each], [50 pages]),
    ..i([JOB], [non-clustered], [50 values, 200 rows each], [50 pages]),
    ..i([SAL], [non-clustered], [values 5,000 to 25,000], [40 pages]),
    table.hline(stroke: .6pt + rule),
    ..t([DEPT], [DNO, DNAME, LOC], [100 rows, stored in DNO order], [5 pages]),
    ..i([DNO], [clustered, unique], [100 values, 1 row each], [2 pages]),
    ..i([LOC], [non-clustered], [10 cities, 10 rows each], [2 pages]),
    table.hline(stroke: .6pt + rule),
    ..t([JOB], [JOB, TITLE], [50 rows, stored in JOB order], [2 pages]),
    ..i([JOB], [clustered, unique], [50 values, 1 row each], [1 page]),
    ..i([TITLE], [non-clustered, unique], [50 titles, 1 row each], [1 page]),
  )
}

// Slide 5: twelve of EMP's 500 pages in stored order, each labelled with the
// department its 20 rows belong to; one department is 100 rows, exactly 5 pages. Above,
// the clustered DNO index finds DNO = 50 on five adjacent pages; below, the non-clustered
// JOB index finds job code 5's 200 rows scattered, about one page each. These are the two
// one-table queries rule 1 opens with. step: 0 draws the pages and the clustered DNO index
// only; step: 1, the default, adds the JOB index below. Nothing drawn at step 0 moves.
#let stored-order-a(step: 1) = diagram(height: 236, {
  let x0 = 140
  let w = 50
  let pitch = 54
  let y0 = 96
  let h = 46
  let px(i) = x0 + i * pitch + w / 2
  let dno = (49, 50, 50, 50, 50, 50, 51, 51, 51, 51, 51, 52)
  label(x0 - 16, 30, [DNO index], size: 16pt, color: muted, anchor: "east")
  label(x0 - 16, y0 + h / 2, [EMP pages], size: 16pt, color: muted, anchor: "east")
  if step >= 1 { label(x0 - 16, 210, [JOB index], size: 16pt, color: muted, anchor: "east") }
  for (i, d) in dno.enumerate() {
    let c = if d == 50 { red } else { ink }
    frame(x0 + i * pitch, y0, w, h, color: c)
    label(px(i), y0 + h / 2, [#d], size: 17pt, mono: true, color: c)
  }
  label(x0 + 12 * pitch + 16, y0 + h / 2, [...], size: 18pt, color: muted)
  // Clustered: one key, one run of adjacent pages.
  node(px(3) - 70, 12, 140, 36, [DNO = 50], size: 17pt, mono: true, color: red)
  arrow(px(3), 48, px(3), 78, color: red)
  line(((x0 + pitch - 2, y0 - 6), (x0 + pitch - 2, 78), (x0 + 5 * pitch + w + 2, 78),
    (x0 + 5 * pitch + w + 2, y0 - 6)), color: red)
  label(420, 30, [clustered: 100 rows on 5 adjacent pages], size: 17pt, color: red, anchor: "west")
  // Non-clustered: one key, pointers to pages all over the table.
  if step >= 1 {
    node(px(3) - 70, 192, 140, 36, [JOB = 5], size: 17pt, mono: true)
    for i in (0, 2, 4, 7, 9, 11) { arrow(px(3), 192, px(i), y0 + h + 4) }
    label(420, 210, [non-clustered: 200 rows, about a page each], size: 17pt, anchor: "west")
  }
})

// ---- figures added in the notes-driven rewrite, section B ----
// ---- b ----
// The merge join, step by step, on the paper's own Figure 1 rows (p. 8): DEPT with EMP on
// DNO, the pair slides 38 and 41 use. LOC = 'DENVER' has already run on DEPT, leaving 50
// MFG and 52 SHIPPING; EMP is stored in DNO order (SMITH 50, JONES 50, DOE 51), so neither
// side is sorted. step: 0 shows the two lists with both cursors at the top; step: k (1 to 4)
// adds trace row k in red, moves the red pair onto the two rows it compares, and greys the
// rows already passed. Coordinates are identical in all five states, so a reveal moves only
// the red.
#let merge-trace-b(step: 4) = diagram(height: 236, {
  let dept = ([50 MFG], [52 SHIPPING])
  let emp = ([SMITH 50], [JONES 50], [DOE 51])
  // (DEPT row, EMP row, as compared, then) for steps 1 to 4.
  let steps = (
    (0, 0, [50 MFG], [SMITH 50], [equal: output (MFG, SMITH), next EMP row]),
    (0, 1, [50 MFG], [JONES 50], [equal: output (MFG, JONES), next EMP row]),
    (0, 2, [50 MFG], [DOE 51], [50 < 51: next DEPT row]),
    (1, 2, [52 SHIPPING], [DOE 51], [51 < 52: next EMP row: none left, done]),
  )
  let (ci, cj) = if step == 0 { (0, 0) } else { (steps.at(step - 1).at(0), steps.at(step - 1).at(1)) }
  let w = 150
  let h = 36
  let dy = 2
  let ey = 56
  // One sorted list as a strip: grey = passed, red = the row under comparison, drawn
  // last so its border sits on top of its neighbours'.
  let strip(y, values, cur) = {
    for (i, v) in values.enumerate() {
      if i != cur {
        frame(i * w, y, w, h, color: if i < cur { rule } else { ink })
        label(i * w + w / 2, y + h / 2, v, size: 18pt, mono: true, color: if i < cur { muted } else { ink })
      }
    }
    frame(cur * w, y, w, h, color: red, width: 1.4pt)
    label(cur * w + w / 2, y + h / 2, values.at(cur), size: 18pt, mono: true, color: red)
  }
  strip(dy, dept, ci)
  strip(ey, emp, cj)
  label(2 * w + 22, dy + h / 2, [DEPT, LOC = 'DENVER', in DNO order], size: 17pt, anchor: "west")
  label(3 * w + 22, ey + h / 2, [EMP, stored in DNO order], size: 17pt, anchor: "west")
  line(((ci * w + w / 2, dy + h), (cj * w + w / 2, ey)), color: red, width: 1.4pt)
  // The trace: one row per comparison, the newest in red.
  let top = 110
  label(40, top, [DEPT row], size: 15pt, color: muted, anchor: "west")
  label(206, top, [EMP row], size: 15pt, color: muted, anchor: "west")
  label(330, top, [then], size: 15pt, color: muted, anchor: "west")
  line(((0, top + 12), (850, top + 12)), color: rule, width: .6pt)
  let y0 = top + 32
  let pitch = 25
  if step == 0 {
    label(330, y0, [both cursors start at the top of their list], size: 17pt, color: muted, anchor: "west")
  }
  for k in range(step) {
    let (_, _, d, e, then) = steps.at(k)
    let c = if k == step - 1 { red } else { ink }
    let y = y0 + k * pitch
    label(14, y, [#(k + 1)], size: 16pt, color: muted)
    label(40, y, d, size: 17pt, mono: true, color: c, anchor: "west")
    label(186, y, [vs], size: 16pt, color: muted)
    label(206, y, e, size: 17pt, mono: true, color: c, anchor: "west")
    label(330, y, then, size: 17pt, color: c, anchor: "west")
  }
})

// ---- figures added in the notes-driven rewrite, section C ----
// Appendix slide 79 (section G reuses it): System R's two layers, the picture
// the paper's CPU term is drawn on. The compiled plan sits above the RSI line and never
// touches a page; the RSS sits below it,
// reads pages from disk and tests search arguments. The one red idea: a NEXT call returns
// one row across the line, and that crossing is the RSI call the W term counts. Rows a
// search argument rejects (the struck cells) cost page reads below the line but no call.
#let rss-rsi-c() = diagram(height: 276, {
  // Above the line: the plan.
  frame(22, 4, 778, 48)
  label(40, 28, [compiled plan], size: 19pt, anchor: "west")
  label(196, 28, [joins, sorts, tests the predicates the RSS cannot], size: 16pt, color: muted, anchor: "west")
  // The interface.
  line(((22, 86), (800, 86)), width: 1.8pt)
  label(26, 102, [RSI: the RSS’s interface], size: 16pt, color: muted, anchor: "west")
  // Below the line: the storage system. Frames fill white, so it is drawn before the
  // arrows that cross its top edge.
  frame(22, 124, 778, 90)
  label(40, 146, [RSS], size: 19pt, anchor: "west")
  label(92, 146, [keeps the tables and indexes on disk], size: 16pt, color: muted, anchor: "west")
  label(40, 184, [reads pages, tests search arguments, skips rows that fail], size: 16pt, anchor: "west")
  // Rows tested inside one NEXT call: four fail a search argument and are skipped, the
  // fifth passes and is returned. The skipped rows never reach the line.
  for i in range(4) {
    let x = 524 + i * 28
    frame(x, 160, 22, 24, color: muted)
    line(((x + 3, 181), (x + 19, 163)), color: muted)
  }
  frame(636, 160, 24, 24, color: red, width: 1.4pt)
  label(578, 200, [skipped: no call], size: 14pt, color: muted)
  // The crossing: NEXT goes down, one row comes back up, and that is one RSI call.
  arrow(704, 56, 704, 120)
  label(716, 70, [NEXT], size: 16pt, anchor: "west")
  arrow(648, 158, 648, 56, color: red)
  label(636, 70, [each NEXT returns one row: one RSI call], size: 17pt, color: red, anchor: "east")
  // Below the RSS: the disk, and the page fetches the I/O term counts.
  for i in range(6) { file(40 + i * 34, 244, 26, 28, color: muted) }
  label(256, 258, [disk: data pages and index pages], size: 16pt, color: muted, anchor: "west")
  arrow(140, 242, 140, 218)
  label(152, 230, [page fetches], size: 16pt, anchor: "west")
})

// ---- figures added in the notes-driven rewrite, section G ----
// Appendix slide 78: section G's copy of buffer-rescue, the third panel of the
// clustered-fetch / nonclustered-fetch pair. Same strips and the same muted scatter; the
// one new thing is the dashed rectangle. If the fetched pages stay resident the repeat
// visits are free, so Table 2's second non-clustered formula charges pages instead of
// rows and the answer is the clustered answer, 1/4 × (40 + 500) = 135. Differences from
// buffer-rescue: 1/4 is typed out, not the precomposed fraction glyph; "without the
// buffer" ends at x = 525 to clear the longer formula; the two red labels sit at y = 262,
// 20pt below the frame's bottom edge (242) instead of 13.
#let buffer-rescue-g() = diagram(height: 276, {
  label(60, 26, [EMP.SAL index, non-clustered], size: 19pt, anchor: "west")
  label(525, 26, [without the buffer], size: 16pt, color: muted, anchor: "east")
  label(816, 26, [1/4 × (40 + 10,000) = 2,510], size: 17pt, color: muted, mono: true, anchor: "east")
  frame(52, 162, 770, 80, color: red, dashed: true)
  _strips([pages], -1)
  _scatter(muted)
  label(60, 262, [the fetched pages stay resident], size: 17pt, color: red, anchor: "west")
  label(816, 262, [1/4 × (40 + 500) = 135], size: 18pt, color: red, mono: true, anchor: "east")
})
