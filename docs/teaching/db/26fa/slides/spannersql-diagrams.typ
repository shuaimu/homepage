// Editable textbook figures for the Spanner SQL deck. Coordinates use points, with y
// increasing downward. White boxes are operators, shards, servers and rows; red marks the
// operator, shard, call or range under discussion. The primitives are the query-optimization
// deck's, copied rather than imported so that the two decks can change independently.
#import "@preview/cetz:0.5.2"
#import "spannersql-theme.typ": ink, muted, red, rule, sans-font, mono-font

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
#let arrow(x1, y1, x2, y2, color: ink, width: 1.2pt, dashed: false) = cetz.draw.line(
  (x1, -y1), (x2, -y2),
  stroke: (paint: color, thickness: width, dash: if dashed { "dashed" } else { "solid" }),
  mark: (end: ">", fill: color),
)
// fill: none draws an outline over what is already there (a "runs remotely" bracket).
#let frame(x, y, w, h, color: ink, width: .9pt, dashed: false, fill: white) = cetz.draw.rect(
  (x, -y), (x+w, -y - h), fill: fill,
  stroke: (paint: color, thickness: width, dash: if dashed { "dashed" } else { "solid" }),
)
// One box with centred text: an operator, a shard, a server.
#let node(x, y, w, h, body, size: 19pt, color: ink, mono: false, dashed: false, sub: none,
  width: .9pt, sub-color: muted) = {
  frame(x, y, w, h, color: color, dashed: dashed, width: width)
  if body == none {
  } else if sub == none {
    label(x+w/2, y+h/2, body, size: size, color: color, mono: mono)
  } else {
    label(x+w/2, y+h/2 - 9, body, size: size, color: color, mono: mono)
    label(x+w/2, y+h/2 + 14, sub, size: 14pt, color: sub-color)
  }
}
// Multi-line figure prose gets the body text's 1.5x baseline spacing: label() itself keeps
// Typst's default text edges, so a bare paragraph would be set nearly solid.
#let spaced(body) = {
  set text(top-edge: .8em, bottom-edge: -.2em)
  set par(leading: .5em)
  body
}
// A box holding several left-aligned lines: a scan with its filter and what it emits.
#let text-box(x, y, w, h, lines, color: ink, size: 13pt, mono: true, dashed: false) = {
  frame(x, y, w, h, color: color, dashed: dashed)
  label(x + 10, y + h/2, spaced(lines.join(linebreak())), size: size, color: color, mono: mono,
    anchor: "west")
}
#let edge(x1, y1, x2, y2, color: ink, dashed: false, width: 1pt) = line(((x1,y1),(x2,y2)),
  color: color, dashed: dashed, width: width)
#let dot(x, y, color: ink, r: 5, filled: true) = cetz.draw.circle((x, -y), radius: r,
  stroke: 1pt + color, fill: if filled { color } else { white })
#let diagram(body, height: 275, width: 850) = cetz.canvas(length: 1pt, {
  cetz.draw.rect((0,0),(width,-height), stroke: none)
  body
})

// ---- The locked scenario ----
// Customer is sharded on ckey into four shards; Sales is interleaved in Customer and has
// no shards of its own. Every figure that draws Customer's shards uses this map and this
// strip geometry, so the shards sit at the same place from slide to slide.
// Q1's @arr = [7, 412, 7, 950] reaches S1, S2 and S4. Denver's index entries, the batch of
// the DistributedApply slides, are ckeys 7, 300, 310, 820 and 990: S1, S2, S2, S4, S4.
#let shard-map = (
  (name: "S1", lo: "−∞", hi: "250", group: "G1"),
  (name: "S2", lo: "250", hi: "500", group: "G2"),
  (name: "S3", lo: "500", hi: "750", group: "G1"),
  (name: "S4", lo: "750", hi: "+∞", group: "G3"),
)
#let shard-range(i) = "[" + shard-map.at(i).lo + ", " + shard-map.at(i).hi + ")"
#let strip = (x: 40, w: 185, pitch: 195)
#let shard-x(i) = strip.x + i * strip.pitch
#let shard-cx(i) = shard-x(i) + strip.w / 2
// Where a ckey sits inside its shard, for points drawn on the strip. S1 and S4 are open
// at one end, so their keys are placed by eye; S2 and S3 are proportional.
#let key-x(k) = {
  if k < 250 { shard-x(0) + 30 + k * 0.4 }
  else if k < 500 { shard-x(1) + (k - 250) / 250 * strip.w }
  else if k < 750 { shard-x(2) + (k - 500) / 250 * strip.w }
  else { shard-x(3) + 20 + (k - 750) * 0.5 }
}
#let shard-row(y, h: 56, highlights: (), greyed: (), sub: (i) => shard-range(i), size: 20pt) = {
  for i in range(4) {
    let c = if i in highlights { red } else if i in greyed { muted } else { ink }
    node(shard-x(i), y, strip.w, h, shard-map.at(i).name, size: size, color: c,
      dashed: i in greyed, sub: sub(i), sub-color: if i in greyed { muted } else { muted },
      width: if i in highlights { 1.4pt } else { .9pt })
  }
}

// ---- Two ways to add SQL ----
// Left: a SQL service on its own servers, reading key ranges through the storage API
// (F1 over Spanner). Right: the compiler and executor inside every Spanner server, which
// ship subplans to each other. The client box is the same on both sides.
// step 1: the loose design alone. step 2: both.
#let coupling(step: 2) = diagram(height: 266, {
  label(205, 12, [Loosely coupled: SQL beside the store], size: 17pt, color: muted)
  line(((425, 0), (425, 266)), color: rule)
  // Left: a SQL service above the storage servers, reading key ranges.
  node(55, 36, 300, 56, [SQL service], sub: [its own servers, e.g. F1])
  for x in (60, 160, 260) {
    node(x, 164, 90, 64, [storage], size: 16pt, sub: [shards])
    arrow(x + 45, 162, x + 45, 94, color: ink)
  }
  label(205, 254, [The SQL service reads key ranges; rows come up.], size: 15pt, color: muted)
  // Right: SQL inside every storage server; subplans go between servers.
  if step >= 2 {
  label(645, 12, [Tightly coupled: SQL inside the store], size: 17pt, color: muted)
  label(500, 52, [query], size: 15pt, color: muted, anchor: "east")
  arrow(510, 36, 510, 94)
  for x in (450, 580, 710) {
    frame(x, 96, 110, 136)
    node(x + 8, 104, 94, 52, [SQL], size: 18pt, color: red, sub: [compile, run])
    node(x + 8, 170, 94, 54, [storage], size: 16pt, sub: [shards])
  }
  // Subplans from the first server to the other two.
  line(((540, 96), (540, 78), (765, 78)), color: red, width: 1.2pt)
  arrow(635, 78, 635, 94, color: red)
  arrow(765, 78, 765, 94, color: red)
  label(700, 64, [subplans], size: 14pt, color: red)
  label(645, 254, [The servers that hold the shards run the plan.], size: 15pt, color: muted)
  }
})

// ---- Shards and Paxos groups ----
// The shard map every later example uses. G1 holds two shards, S1 and S3, which is what
// "one call per Paxos group" later saves.
#let shard-groups() = diagram(height: 280, {
  label(strip.x, 12, [Customer, in ckey order, cut into four shards], size: 16pt, color: muted,
    anchor: "west")
  shard-row(30, h: 62)
  for i in range(4) {
    let g = shard-map.at(i).group
    label(shard-cx(i), 112, [in #g], size: 17pt, color: if g == "G1" { red } else { ink })
  }
  let groups = (
    (x: 40, w: 300, name: [G1 holds S1 and S3], c: red),
    (x: 360, w: 215, name: [G2 holds S2], c: ink),
    (x: 595, w: 215, name: [G3 holds S4], c: ink),
  )
  for g in groups {
    frame(g.x, 150, g.w, 104, color: g.c, width: if g.c == red { 1.4pt } else { .9pt })
    label(g.x + g.w / 2, 172, g.name, size: 17pt, color: g.c)
    let rw = (g.w - 40) / 3
    for j in range(3) {
      node(g.x + 10 + j * (rw + 10), 194, rw, 46, ([dc A], [dc B], [dc C]).at(j), size: 15pt,
        sub: none)
    }
  }
  label(425, 274, [Each Paxos group: one replica in each of three datacenters, A, B and C.],
    size: 15pt, color: muted)
})

// ---- Calls go to key ranges ----
// The coprocessor framework turns "run this on keys [250, 500)" into a replica of G2.
#let key-range-call() = diagram(height: 250, {
  node(0, 74, 220, 74, [a caller], size: 18pt, sub: "run this on keys [250, 500)")
  arrow(222, 111, 282, 111)
  node(284, 64, 236, 94, [coprocessor framework], size: 17pt,
    sub: "who owns [250, 500) now? G2")
  let reps = (
    (y: 14, t: [dc A: farther away], c: muted),
    (y: 90, t: [dc B: nearest, fresh enough], c: red),
    (y: 166, t: [dc C: behind the read time], c: muted),
  )
  for r in reps {
    node(590, r.y, 260, 52, [G2 replica], size: 16pt, color: r.c, sub: r.t,
      sub-color: r.c, width: if r.c == red { 1.4pt } else { .9pt })
  }
  arrow(522, 111, 588, 116, color: red, width: 1.6pt)
  arrow(522, 92, 588, 44, color: muted, dashed: true)
  arrow(522, 130, 588, 190, color: muted, dashed: true)
  label(425, 240, [If the range moves mid-call, the framework reroutes; a transient fault, it retries.],
    size: 15pt, color: muted)
})

// ---- Interleaving ----
// Rows in stored key order: each customer followed by its sales. The boundary between
// S1 and S2 falls between customers 249 and 250, never inside one customer's rows.
#let interleaved-rows() = diagram(width: 400, height: 318, {
  let rows = (
    (0, "Customer(7)", ink), (1, "Sales(7, 1)", ink), (1, "Sales(7, 2)", ink),
    (0, "Customer(8)", ink), (1, "Sales(8, 1)", ink), (0, "…", muted),
    (0, "Customer(249)", ink), (1, "Sales(249, 1)", ink),
  )
  for (i, r) in rows.enumerate() {
    let (indent, t, c) = r
    if t == "…" { label(30, 2 + i * 31 + 14, t, size: 16pt, color: muted, mono: true) }
    else { node(indent * 34, 2 + i * 31, 210, 27, t, size: 15pt, mono: true, color: c) }
  }
  // The boundary: between Customer(249)'s group and Customer(250).
  line(((0, 260), (320, 260)), color: red, width: 1.4pt, dashed: true)
  label(330, 260, [boundary], size: 15pt, color: red, anchor: "west")
  node(0, 266, 210, 27, "Customer(250)", size: 15pt, mono: true)
  label(30, 308, "…", size: 16pt, color: muted, mono: true)
  // Which shard each run of rows is in.
  line(((262, 4), (262, 252)), color: muted)
  label(274, 128, [S1], size: 18pt, anchor: "west")
  line(((262, 268), (262, 314)), color: muted)
  label(274, 290, [S2], size: 18pt, anchor: "west")
})

// ---- Parent and child: two unions merge ----
// step 1: the tables: interleaving keeps each customer's sales in its shard. 2: the join
// with a union under each input. 3: after the merge, one union over the join.
#let parent-child-merge(step: 3) = diagram(height: 272, {
  let du(x, y, c) = node(x, y, 160, 44, "DistributedUnion", size: 13pt, mono: true,
    sub: [over Customer], color: c, width: if c == red { 1.4pt } else { .9pt })
  // The tables: each customer's sales are stored in its shard.
  text-box(0, 0, 230, 74, ("S1  Customer(7)", "      Sales(7, 1)", "      Sales(7, 2)"), size: 13pt)
  text-box(250, 0, 230, 74, ("S2  Customer(300)", "      Sales(300, 1)", "      Sales(300, 2)"), size: 13pt)
  label(505, 37, spaced[Sales is interleaved in Customer:\ each sale sits in its customer’s shard,\ so no match is ever in another shard.],
    size: 15pt, anchor: "west")
  if step >= 2 {
    // Before.
    let c1 = if step == 2 { red } else { ink }
    label(170, 106, [before: a union under each input], size: 15pt, color: muted)
    node(100, 122, 140, 28, "CrossApply", size: 14pt, mono: true)
    edge(170, 150, 80, 170)
    edge(170, 150, 260, 170)
    du(0, 170, c1)
    du(180, 170, c1)
    edge(80, 214, 80, 234, color: c1, width: if step == 2 { 2.4pt } else { 1pt })
    edge(260, 214, 260, 234, color: c1, width: if step == 2 { 2.4pt } else { 1pt })
    node(15, 234, 130, 28, "Scan(Customer)", size: 13pt, mono: true)
    node(195, 234, 130, 28, "Scan(Sales)", size: 13pt, mono: true)
  }
  if step >= 3 {
    // After.
    label(418, 162, [merge], size: 15pt, color: muted)
    label(418, 192, [⇒], size: 34pt)
    label(660, 106, [after: one union over the join], size: 15pt, color: muted)
    du(580, 122, red)
    edge(660, 166, 660, 184, color: red, width: 2.4pt)
    node(590, 184, 140, 28, "CrossApply", size: 14pt, mono: true)
    edge(660, 212, 570, 234)
    edge(660, 212, 750, 234)
    node(505, 234, 130, 28, "Scan(Customer)", size: 13pt, mono: true)
    node(685, 234, 130, 28, "Scan(Sales)", size: 13pt, mono: true)
    label(740, 198, spaced[join inside\ each shard], size: 15pt, color: red, anchor: "west")
  }
})

// ---- The Q1 plan tree ----
// One geometry for every state, so that only the union moves. The tree is the notes'
// single-machine tree; DistributedUnion boxes sit in the gaps between operators.
// Spine x = 285; the Customer branch at x = 150, the Sales branch at x = 420.
// Rows (centres): 13 TopF, 51 slot U5, 89 slot U4 / local Top, 127 GroupBy, 165 slot U3,
// 203 CrossApply, 241 slots U1 / U2, 285 Filters (two lines), 329 slots U0, 367 Scans.
// stage: "plain" (one machine, no unions), 0 (a union over each scan), 1 to 5 (after each
// pull-up step), "final" (stage 5 annotated with where each part runs).
#let q1-tree(stage: 0) = diagram(height: 382, {
  let X = 285
  let L = 150
  let R = 420
  let op(cx, cy, w, body, h: 26, color: ink) = node(cx - w/2, cy - h/2, w, h, body,
    size: 14pt, mono: true, color: color)
  let union(cx, cy) = node(cx - 109, cy - 12, 218, 24, "DistributedUnion(Customer)",
    size: 13pt, mono: true, color: red, width: 1.4pt)
  let n = if stage == "plain" { -1 } else if stage == "final" { 5 } else { stage }
  // Where the union(s) are: a list of (x, y) centres.
  let unions = if n < 0 { () }
    else if n == 0 { ((L, 329), (R, 329)) }
    else if n == 1 { ((L, 241), (R, 329)) }
    else if n == 2 { ((L, 241), (R, 241)) }
    else if n == 3 { ((X, 165),) }
    else if n == 4 { ((X, 89),) }
    else { ((X, 51),) }
  let local-top = n >= 5
  // Spine, top to bottom: (y-centre, half-height, kind) of what is present.
  let spine = ((13, 13, "op"),)
  if n >= 5 { spine.push((51, 12, "u")) }
  if local-top { spine.push((89, 13, "op")) }
  if n == 4 { spine.push((89, 12, "u")) }
  spine.push((127, 13, "op"))
  if n == 3 { spine.push((165, 12, "u")) }
  spine.push((203, 13, "op"))
  for i in range(spine.len() - 1) {
    let (y1, h1, k1) = spine.at(i)
    let (y2, h2, _) = spine.at(i + 1)
    edge(X, y1 + h1, X, y2 - h2, color: if k1 == "u" { red } else { ink },
      width: if k1 == "u" { 2.4pt } else { 1pt })
  }
  // Branches, top to bottom below CrossApply.
  for bx in (L, R) {
    let items = ()
    if unions.any(u => u.at(0) == bx and u.at(1) == 241) { items.push((241, 12, "u")) }
    items.push((285, 20, "op"))
    if unions.any(u => u.at(0) == bx and u.at(1) == 329) { items.push((329, 12, "u")) }
    items.push((367, 13, "op"))
    let (fy, fh, _) = items.at(0)
    edge(X + (if bx == L { -20 } else { 20 }), 216, bx, fy - fh)
    for i in range(items.len() - 1) {
      let (y1, h1, k1) = items.at(i)
      let (y2, h2, _) = items.at(i + 1)
      edge(bx, y1 + h1, bx, y2 - h2, color: if k1 == "u" { red } else { ink },
        width: if k1 == "u" { 2.4pt } else { 1pt })
    }
  }
  op(X, 13, 236, "Top(5) ORDER BY total DESC")
  if local-top { op(X, 89, 236, "Top(5) ORDER BY total DESC") }
  op(X, 127, 142, "GroupBy(c.ckey)")
  op(X, 203, 108, "CrossApply")
  node(L - 94, 265, 188, 40, none, color: ink)
  label(L, 276, "Filter", size: 13pt, mono: true)
  label(L, 294, "c.ckey IN UNNEST(@arr)", size: 13pt, mono: true)
  node(R - 94, 265, 188, 40, none, color: ink)
  label(R, 276, "Filter s.ckey = c.ckey", size: 13pt, mono: true)
  label(R, 294, "AND s.type = 'global'", size: 13pt, mono: true)
  op(L, 367, 150, "Scan(Customer c)")
  op(R, 367, 126, "Scan(Sales s)")
  for u in unions { union(..u) }
  // The sharding-key filter is picked up at step 1, on the Customer side, and travels with
  // the union: beside the left union for steps 1 and 2, beside the merged one from step 3.
  if n >= 1 and n < 3 {
    label(41, 190, [sharding-key filter], size: 13pt, color: red, anchor: "west")
    label(41, 208, "ckey IN UNNEST(@arr)", size: 13pt, color: red, mono: true, anchor: "west")
  }
  if n >= 3 {
    let uy = unions.at(0).at(1)
    label(170, uy - 9, [sharding-key filter], size: 13pt, color: red, anchor: "east")
    label(170, uy + 9, "ckey IN UNNEST(@arr)", size: 13pt, color: red, mono: true,
      anchor: "east")
  }
  if local-top {
    label(160, 13, [final], size: 15pt, color: muted, anchor: "east")
    label(160, 89, [local], size: 15pt, color: muted, anchor: "east")
  }
  // The panel: what the last step did, with the steps before it.
  let px = 550
  if stage == "plain" {
    label(px, 20, spaced[One machine.\ Filters pushed down;\ the join is a CrossApply:\ its input on the left,\ its map on the right.],
      size: 17pt, anchor: "north-west")
    label(px, 250, spaced[Filter over Scan is logical:\ how a filter becomes seeks\ comes later.],
      size: 15pt, color: muted, anchor: "north-west")
  } else if stage != "final" {
    // One line of reason per step, stacked by real height, so every gap is the same.
    let steps = (
      ([Start: a union over each scan.], [Sales is interleaved: Customer’s union.]),
      ([1 · Filter on c: passes.], [Its ckey test: the sharding-key filter.]),
      ([2 · Filter on s: passes.], [Its sharding-key filter: s.ckey = c.ckey.]),
      ([3 · CrossApply: merge.], [Same table, joined on all of ckey.]),
      ([4 · GroupBy(c.ckey): passes.], [A customer’s rows share one shard.]),
      ([5 · Top(5) by total: fails.], [Local Top below, final Top above.]),
    )
    label(px, 0, spaced({
      for (i, s) in steps.enumerate() {
        if i > n { break }
        let (head, why) = s
        block(above: if i == 0 { 0pt } else { 13pt }, below: 0pt,
          text(size: 16pt, fill: if i == n { red } else { ink }, head))
        block(above: 5pt, below: 0pt, text(size: 14pt, fill: if i == n { red } else { muted }, why))
      }
    }), size: 16pt, anchor: "north-west")
  } else {
    // Where each part runs.
    // The root runs the final Top and the union, which makes the calls; the shards run
    // everything from the local Top down.
    line(((432, 2), (442, 2), (442, 63), (432, 63)), color: muted)
    label(452, 13, [root server], size: 16pt, anchor: "west")
    label(452, 51, [≤ 5 rows from each shard], size: 15pt, color: red, anchor: "west")
    line(((548, 78), (558, 78), (558, 380), (548, 380)), color: muted)
    label(568, 210, spaced[each shard\ the union calls,\ all in parallel], size: 16pt, anchor: "west")
    label(568, 300, spaced[Everything below\ the union runs\ on the shards.], size: 17pt,
      color: red, anchor: "north-west")
  }
})

// ---- Strawman 1: SQL beside the store ----
// step 1: with the array, a few point reads. step 2: no array (top 5 overall), every row of both tables
// crosses the network to keep five.
#let beside(step: 2) = diagram(height: 300, {
  node(250, 8, 350, 60, [one SQL server], sub: [runs all of Q1])
  arrow(602, 38, 680, 38)
  label(690, 38, [5 rows], size: 18pt, anchor: "west")
  shard-row(160, h: 60, greyed: if step == 1 { (2,) } else { () },
    sub: (i) => if step == 1 and i == 2 { [none in the array] } else { [Customer + Sales] })
  for i in range(4) {
    let target = 300 + i * 84
    if step == 1 {
      if i != 2 { arrow(shard-cx(i), 158, target, 72, color: ink) }
    } else {
      arrow(shard-cx(i), 158, target, 72, color: red, width: 3pt)
    }
  }
  if step == 1 {
    label(425, 252, [With the array: point reads for its few customers and their sales.],
      size: 17pt, color: muted)
  } else {
    label(425, 252, [No array, top 5 overall: every Customer and Sales row, global or not.], size: 17pt,
      color: red)
    label(425, 282, [A key-range read cannot test type.], size: 15pt, color: muted)
  }
})

// ---- DistributedUnion: one tree at compile time, 1-to-N calls at run time ----
// The thick red edge under the union is where the calls happen, as in the paper's figures.
// step 1: the compiled tree alone. step 2: the run-time calls too.
#let du-fanout(step: 2) = diagram(height: 262, {
  label(150, 10, [compile time: one tree], size: 16pt, color: muted)
  node(30, 34, 220, 40, [everything above], size: 17pt)
  edge(140, 74, 140, 110)
  node(30, 110, 220, 32, "DistributedUnion(T)", size: 15pt, mono: true, color: red, width: 1.4pt)
  edge(140, 142, 140, 190, color: red, width: 2.4pt)
  node(30, 190, 220, 40, "Scan(shard), …", size: 15pt, mono: true)
  line(((258, 34), (266, 34), (266, 142), (258, 142)), color: muted)
  label(272, 88, [root], size: 16pt, anchor: "west")
  line(((258, 190), (266, 190), (266, 230), (258, 230)), color: muted)
  label(272, 210, [each shard], size: 16pt, anchor: "west")
  line(((372, 0), (372, 262)), color: rule)
  if step >= 2 {
    label(620, 10, [run time: 1-to-N calls], size: 16pt, color: muted)
    node(510, 34, 220, 32, "DistributedUnion(T)", size: 15pt, mono: true, color: red, width: 1.4pt)
    for (i, x) in (392, 508, 624, 740).enumerate() {
      node(x, 176, 104, 56, "S" + str(i + 1), size: 18pt, sub: [subtree])
      arrow(620, 68, x + 52, 174, color: red, width: 1.8pt)
    }
    label(620, 254, [results come back and are concatenated], size: 15pt, color: muted)
  }
})

// ---- Pull the union up ----
// Slide 14's compiled tree again, with the direction of optimization: the union moves up,
// so more of the plan runs below it, on every shard.
#let pull-up() = diagram(width: 445, height: 250, {
  node(100, 10, 220, 40, [everything above], size: 17pt)
  edge(210, 50, 210, 96)
  node(100, 96, 220, 32, "DistributedUnion(T)", size: 15pt, mono: true, color: red, width: 1.4pt)
  edge(210, 128, 210, 186, color: red, width: 2.4pt)
  node(100, 186, 220, 40, "Scan(shard), …", size: 15pt, mono: true)
  arrow(80, 170, 80, 60, color: red, width: 2pt)
  label(72, 115, [pull up], size: 16pt, color: red, anchor: "east")
  line(((328, 10), (336, 10), (336, 128), (328, 128)), color: muted)
  label(344, 69, spaced[above:\ on the root], size: 16pt, anchor: "west")
  line(((328, 186), (336, 186), (336, 226), (328, 226)), color: muted)
  label(344, 206, spaced[below:\ every shard,\ in parallel], size: 16pt, anchor: "west")
})

// ---- Partitionability ----
// F on the whole table equals F on each shard, concatenated in key order.
#let partition-equiv() = diagram(height: 250, {
  label(150, 10, [F on the whole table], size: 16pt, color: muted)
  node(50, 36, 200, 36, [rows], size: 17pt, color: muted)
  edge(150, 72, 150, 112)
  node(100, 112, 100, 38, "F", size: 18pt, mono: true, color: red)
  edge(150, 150, 150, 190)
  node(20, 190, 260, 40, "Scan(T)", size: 16pt, mono: true)
  label(345, 124, [=], size: 40pt)
  label(620, 10, [F on each shard, concatenated in key order], size: 16pt, color: muted)
  node(410, 36, 420, 36, [OrderedUnionAll], size: 17pt, sub: none)
  for (i, x) in (410, 520, 630, 740).enumerate() {
    edge(x + 45, 72, x + 45, 112)
    node(x + 20, 112, 50, 38, "F", size: 18pt, mono: true, color: red)
    edge(x + 45, 150, x + 45, 190)
    node(x, 190, 90, 40, "S" + str(i + 1), size: 17pt, mono: true)
  }
})

// ---- Shard pruning for Q1 ----
// step 1: the array, deduplicated, as points. step 2: the shards they fall in.
#let pruning(step: 2) = diagram(height: 262, {
  label(strip.x, 14, "@arr = [7, 412, 7, 950]", size: 19pt, mono: true, anchor: "west")
  if step >= 1 {
    label(strip.x, 50, [remove duplicates: the points 7, 412 and 950], size: 17pt, anchor: "west")
    for k in (7, 412, 950) {
      label(key-x(k), 92, str(k), size: 17pt, color: red, mono: true)
      arrow(key-x(k), 104, key-x(k), 150, color: red)
    }
  }
  shard-row(152, h: 60, highlights: if step >= 2 { (0, 1, 3) } else { () },
    greyed: if step >= 2 { (2,) } else { () })
  if step >= 2 {
    for i in (0, 1, 3) { label(shard-cx(i), 234, [called], size: 16pt, color: red) }
    label(shard-cx(2), 234, [never contacted], size: 16pt, color: muted)
  }
})

// ---- Fewer calls: one per Paxos group, none when the shard is local ----
#let group-calls() = diagram(height: 250, {
  label(260, 10, [All four shards: one call per group], size: 16pt, color: muted)
  node(160, 30, 200, 40, [root server], size: 17pt)
  let gs = ((x: 0, w: 210, t: [G1], s: [S1 and S3]), (x: 230, w: 140, t: [G2], s: [S2]),
            (x: 390, w: 140, t: [G3], s: [S4]))
  for g in gs {
    node(g.x, 150, g.w, 64, g.t, size: 19pt, sub: g.s)
    arrow(260, 72, g.x + g.w / 2, 148, color: red, width: 1.8pt)
  }
  label(265, 238, [4 shards, 3 calls], size: 17pt, color: red)
  line(((560, 0), (560, 250)), color: rule)
  label(705, 10, [Shard affinity], size: 16pt, color: muted)
  frame(590, 40, 230, 150)
  label(705, 58, [one server], size: 15pt, color: muted)
  node(610, 80, 80, 50, [root], size: 17pt)
  node(720, 80, 80, 50, [S2], size: 17pt)
  arrow(690, 105, 718, 105, color: red)
  label(705, 160, [in-process: no call], size: 16pt, color: red)
  label(705, 220, [The shard is here, so the subtree runs here.], size: 14pt, color: muted)
})

// ---- A global secondary index and the base table ----
// mode: "index" (the index and the shards alone, no arrows), "scatter" (where Denver's
// rows live), "row" (one call per row, in sequence), "batch" (one call per shard
// touched, in parallel). Same geometry in all four.
#let index-calls(mode: "scatter") = diagram(height: 266, {
  label(strip.x, 8, [CustomerByCity: key (city, ckey), sharded on city], size: 16pt,
    color: muted, anchor: "west")
  node(strip.x, 24, 125, 74, [I1], size: 18pt, color: muted, sub: "[−∞, Chicago)")
  frame(175, 24, 510, 74, color: ink)
  label(430, 38, "I2: [Chicago, Miami)", size: 15pt)
  node(695, 24, 115, 74, [I3], size: 18pt, color: muted, sub: "[Miami, +∞)")
  let keys = (7, 300, 310, 820, 990)
  let cx(j) = 230 + j * 100
  for (j, k) in keys.enumerate() {
    node(cx(j) - 48, 54, 96, 32, "Denver, " + str(k), size: 13pt, mono: true,
      color: if mode in ("scatter", "index") { ink } else { red })
  }
  shard-row(162, h: 54, greyed: if mode == "batch" { (2,) } else { () },
    highlights: if mode == "batch" { (0, 1, 3) } else { () },
    sub: (i) => "Customer " + shard-range(i))
  let target(k) = (key-x(k), 160)
  // mode "index": the index and the shards alone, no arrows yet.
  if mode == "index" {
  } else if mode == "scatter" {
    for (j, k) in keys.enumerate() { arrow(cx(j), 88, ..target(k), color: ink) }
    label(425, 246, [One index shard holds Denver; its rows are in three Customer shards.],
      size: 16pt, color: muted)
  } else if mode == "row" {
    for (j, k) in keys.enumerate() {
      arrow(cx(j), 88, ..target(k), color: red)
      label(cx(j) + 8, 114, str(j + 1), size: 14pt, color: red, anchor: "west")
    }
    label(425, 246, [5 rows, 5 calls, one after another], size: 18pt, color: red)
  } else {
    // One call per shard touched, carrying that shard's rows.
    let calls = ((0, (0,)), (1, (1, 2)), (3, (3, 4)))
    for (i, js) in calls {
      for j in js { line(((cx(j), 86), (cx(j), 92)), color: red, width: 1.4pt) }
      let x0 = cx(js.first())
      let x1 = cx(js.last())
      if js.len() > 1 { line(((x0, 92), (x1, 92)), color: red, width: 1.4pt) }
      arrow((x0 + x1) / 2, 92, shard-cx(i), 160, color: red, width: 2.4pt)
    }
    label(shard-cx(2), 232, [not called], size: 15pt, color: muted)
    label(425, 258, [5 rows, 3 calls, all in parallel], size: 18pt, color: red)
  }
})

// ---- The paper's Figure 2: batching an apply ----
#let batched-apply() = diagram(height: 284, {
  label(165, 10, [one call per input row], size: 16pt, color: muted)
  node(80, 30, 170, 54, [Apply], size: 18pt, sub: [Cross or Outer])
  node(0, 140, 120, 38, "<input>", size: 15pt, mono: true)
  node(150, 132, 190, 38, "DistributedUnion", size: 14pt, mono: true, color: red, width: 1.4pt)
  node(185, 214, 120, 38, "<map>", size: 15pt, mono: true)
  edge(165, 84, 60, 140)
  edge(165, 84, 245, 132)
  edge(245, 170, 245, 214, color: red, width: 2.4pt)
  label(380, 140, [⇒], size: 34pt)
  label(640, 10, [one call per batch per shard], size: 16pt, color: muted)
  node(540, 30, 210, 54, "DistributedApply", size: 15pt, mono: true, color: red, width: 1.4pt,
    sub: [Cross or Outer])
  node(420, 124, 150, 54, "Batch", size: 15pt, mono: true, sub: "=> $batch")
  node(435, 214, 120, 38, "<input>", size: 15pt, mono: true)
  node(670, 128, 140, 34, "CrossApply", size: 14pt, mono: true)
  node(615, 214, 140, 38, "Unnest($batch)", size: 13pt, mono: true)
  node(770, 214, 76, 38, "<map>", size: 14pt, mono: true)
  edge(645, 84, 495, 124)
  edge(645, 84, 740, 128, color: red, width: 2.4pt)
  edge(495, 178, 495, 214)
  edge(740, 162, 685, 214)
  edge(740, 162, 808, 214)
  frame(604, 116, 246, 144, color: red, dashed: true, fill: none)
  label(727, 276, [runs on each shard the batch touches], size: 14pt, color: red)
})

// ---- Q2's plan: two levels of distribution ----
#let q2-plan() = diagram(height: 312, {
  node(40, 0, 340, 30, "DistributedUnion(CustomerByCity)", size: 14pt, mono: true, color: red,
    width: 1.4pt)
  label(392, 15, [sharding-key filter: city = 'Denver'], size: 15pt, color: muted, anchor: "west")
  edge(210, 30, 210, 66, color: red, width: 2.4pt)
  label(222, 48, [above the apply, as above a Filter: the map runs once per input row],
    size: 14pt, color: muted, anchor: "west")
  node(110, 66, 200, 30, "DistributedApply", size: 14pt, mono: true, color: red, width: 1.4pt)
  label(322, 81, [runs on each index shard with Denver], size: 15pt, color: muted, anchor: "west")
  text-box(0, 150, 300, 52, ("Batch(Scan(CustomerByCity)", "  city = 'Denver') => $batch"),
    size: 13pt)
  edge(210, 96, 150, 150)
  edge(210, 96, 470, 150, color: red, width: 2.4pt)
  node(400, 150, 140, 30, "CrossApply", size: 14pt, mono: true)
  node(330, 236, 150, 30, "Unnest($batch)", size: 13pt, mono: true)
  text-box(500, 226, 260, 50, ("Scan(Customer)", "ckey = the row's ckey"), size: 13pt)
  edge(470, 180, 405, 236)
  edge(470, 180, 600, 226)
  frame(318, 140, 456, 146, color: red, dashed: true, fill: none)
  label(546, 302, [on each Customer shard the batch touches], size: 14pt, color: red)
})

// ---- Parallel consumers ----
#let parallel-consumer() = diagram(height: 288, {
  node(0, 10, 230, 60, [a pipeline], size: 18pt, sub: [e.g. a MapReduce job])
  node(440, 10, 220, 60, [Spanner], size: 18pt, sub: [any server])
  arrow(232, 28, 438, 28)
  label(335, 16, [the query, and “2 parts”], size: 14pt, color: muted)
  arrow(438, 54, 232, 54)
  label(335, 70, [descriptors D1 and D2], size: 14pt, color: red)
  let ws = ((x: 75, t: [worker 1 runs D1], s: (0, 1)), (x: 455, t: [worker 2 runs D2], s: (2, 3)))
  let sx = (55, 185, 435, 565)
  for w in ws {
    node(w.x, 112, 220, 46, w.t, size: 16pt, color: red)
    for i in w.s {
      arrow(w.x + 110, 160, sx.at(i) + 55, 208, color: red)
      node(sx.at(i), 210, 110, 46, "S" + str(i + 1), size: 18pt)
    }
  }
  label(345, 280, [Each worker calls its shards directly; all read at one timestamp.], size: 15pt,
    color: muted)
})

// ---- Documents: one range against seeks per document ----
// mode "range": one start key and one stop key, every version read. mode "seek": the
// correlated scans skip to the one wanted version of each document.
// Keys sort by (ProjectId, DocumentPath, Version); ten documents under /proposals,
// 1,000 versions each, at most one of them dated 2017-01-01.
#let doc-keys(mode: "range") = diagram(height: 262, {
  label(0, 12, [Documents in key order: (ProjectId, DocumentPath, Version)], size: 16pt,
    color: muted, anchor: "west")
  let y = 96
  let h = 56
  node(0, y, 90, h, [P000 …], size: 15pt, color: muted, dashed: true)
  let docs = ((x: 104, t: "/proposals/doc1"), (x: 314, t: "/proposals/doc10"))
  let hot = mode == "range"
  for d in docs {
    frame(d.x, y, 196, h, color: if hot { red } else { ink }, width: if hot { 1.4pt } else { .9pt })
    label(d.x + 90, y + 16, d.t, size: 13pt, mono: true, color: if hot { red } else { ink })
    for j in range(13) { line(((d.x + 12 + j * 10, y + 32), (d.x + 12 + j * 10, y + 48)), color: muted) }
    frame(d.x + 158, y + 28, 24, 24, color: red, width: 1.6pt)
  }
  frame(524, y, 196, h, color: if hot { red } else { ink }, width: if hot { 1.4pt } else { .9pt })
  label(622, y + 16, [8 more documents], size: 15pt, color: if hot { red } else { ink })
  label(622, y + 40, [1,000 versions each], size: 13pt, color: muted)
  node(734, y, 116, h, [/reports …], size: 15pt, color: muted, dashed: true)
  label(202, y + h + 14, [1,000 versions each], size: 13pt, color: muted)
  label(412, y + h + 14, [1,000 versions each], size: 13pt, color: muted)
  if mode == "range" {
    label(281, y - 6, [2017-01-01 ↓], size: 13pt, color: red, anchor: "south-east")
  }
  if mode == "range" {
    line(((104, 70), (104, 60), (720, 60), (720, 70)), color: red, width: 1.4pt)
    label(412, 52, "start (P001, '/proposals') … stop (P001, '/proposalt')", size: 14pt,
      color: red, mono: true, anchor: "south")
    label(425, 204, [one range: 10 × 1,000 = 10,000 rows read, 10 kept], size: 18pt, color: red)
    label(425, 236, [Version = `@param2` is tested on every row; it narrows nothing.], size: 15pt,
      color: muted)
  } else {
    // Seek to each document's first key, then to its wanted version, then past it.
    for d in docs {
      arrow(d.x + 6, 50, d.x + 6, y - 2, color: red)
      arrow(d.x + 170, 50, d.x + 170, y + 26, color: red)
    }
    arrow(530, 50, 530, y - 2, color: red)
    label(110, 40, [Scan2], size: 13pt, color: red)
    label(274, 40, [Scan3], size: 13pt, color: red)
    label(266, 72, [the 2017-01-01 version], size: 13pt, color: red, anchor: "east")
    label(425, 204, [about 2 seeks per document: about 20 rows read, 10 kept], size: 18pt,
      color: red)
    label(425, 236, [Scan2 finds a path, Scan3 seeks its version, Scan2 skips to the next path.],
      size: 15pt, color: muted)
  }
})

// ---- The paper's Figure 3: correlated self-joins over the key columns ----
// Built bottom up, one box per click: 0 Scan1, 1 Scan2, 2 the lower CrossApply that runs
// Scan2 per project Scan1 emits, 3 Scan3, 4 the upper CrossApply that runs Scan3 per path,
// 5 the whole tree and a summary, which is also the handout page. The box that just
// appeared, with its edges, is red.
#let self-join-tree(step: 5) = diagram(height: 340, {
  let c(i) = if step == i { red } else { ink }
  let w(i) = if step == i { 2.4pt } else { 1pt }
  text-box(0, 176, 264, 92, (
    "Scan1(Documents.ProjectId)",
    "filter ProjectId = @param1",
    "emits @project_id: no read",
  ), size: 13pt, color: c(0))
  if step >= 1 {
    text-box(280, 196, 420, 102, (
      "Scan2(Documents.DocumentPath)",
      "filter ProjectId = @project_id",
      "  AND STARTS_WITH(DocumentPath, '/proposals')",
      "emits @document_path: one per path",
    ), size: 13pt, color: c(1))
  }
  if step >= 2 {
    node(140, 60, 150, 30, "CrossApply", size: 14pt, mono: true, color: c(2), width: w(2) / 2 + .4pt)
    edge(215, 90, 120, 176, color: c(2), width: w(2))
    edge(215, 90, 380, 196, color: c(2), width: w(2))
  }
  if step >= 3 {
    text-box(450, 60, 400, 112, (
      "Scan3(Documents.*)",
      "filter ProjectId = @project_id",
      "  AND DocumentPath = @document_path",
      "  AND Version = @param2",
      "emits the rows: one seek per path",
    ), size: 13pt, color: c(3))
  }
  if step >= 4 {
    node(330, 0, 150, 30, "CrossApply", size: 14pt, mono: true, color: c(4), width: w(4) / 2 + .4pt)
    edge(405, 30, 215, 60, color: c(4), width: w(4))
    edge(405, 30, 645, 60, color: c(4), width: w(4))
  }
  let say(body, color: red) = label(425, 328, body, size: 17pt, color: color)
  if step == 0 {
    say([Scan1 handles the first key column, ProjectId: the filter pins it to P001.], color: muted)
  } else if step == 1 {
    say([Scan2 handles DocumentPath, but needs a `@project_id` from somewhere.], color: muted)
  } else if step == 2 {
    say([For each `@project_id` Scan1 emits (only P001), run Scan2: it emits the ten paths.])
  } else if step == 3 {
    say([Scan3 handles Version, but needs a `@document_path` from somewhere.], color: muted)
  } else if step == 4 {
    say([For each `@document_path`, run Scan3: one seek to its 2017-01-01 version. Ten rows.])
  } else {
    say([Scan1 pins the project; Scan2 lists its paths; Scan3 seeks each path’s version.],
      color: ink)
  }
})

// ---- The paper's Figure 4: the filter tree ----
// step 0: the tree. 1: k1 ranges. 2: k2 ranges given k1 = 1. 3: given k1 = 2. 4: the result.
#let filter-tree(step: 0) = diagram(height: 336, {
  let pass1 = step == 1
  let given1 = step == 2
  let given2 = step == 3
  // Which subtrees are pruned in this pass.
  let lpruned = given2
  let rpruned = given1
  let lc = if lpruned { muted } else { ink }
  let rc = if rpruned { muted } else { ink }
  node(230, 0, 80, 32, [OR], size: 17pt)
  node(110, 84, 80, 32, [AND], size: 17pt, color: lc, dashed: lpruned)
  node(400, 84, 80, 32, [AND], size: 17pt, color: rc, dashed: rpruned)
  edge(270, 32, 150, 84)
  edge(270, 32, 440, 84)
  let leaf(x, w, body, c, h: 32) = node(x, 176, w, h, body, size: 14pt, mono: true, color: c)
  let true1 = given1
  let false1 = given2
  leaf(0, 80, "k1 = 1", if true1 or lpruned { muted } else { ink })
  leaf(92, 92, "k2 = \"a\"", lc)
  node(196, 176, 140, 44, none, color: lc)
  label(266, 189, "REGEXP_MATCH", size: 13pt, mono: true, color: lc)
  label(266, 207, "(value, @param)", size: 13pt, mono: true, color: lc)
  leaf(358, 80, "k1 = 2", if given2 or rpruned { muted } else { ink })
  leaf(450, 92, "k2 < \"b\"", rc)
  for x in (40, 138, 266) { edge(150, 116, x, 176, color: lc) }
  for x in (398, 496) { edge(440, 116, x, 176, color: rc) }
  let ann(x, y, body, anchor: "center", color: red) = label(x, y, body, size: 14pt, color: color,
    mono: true, anchor: anchor)
  // The result state, which is the handout page, keeps the k1 pass in grey.
  if step == 4 {
    ann(104, 100, "[1, 1]", anchor: "east", color: muted)
    ann(486, 100, "[2, 2]", anchor: "west", color: muted)
    ann(316, 16, "k1 in [1, 2]", anchor: "west", color: muted)
  }
  if pass1 {
    ann(40, 230, "[1, 1]")
    ann(138, 230, "(−∞, +∞)")
    ann(266, 238, "(−∞, +∞)")
    ann(398, 230, "[2, 2]")
    ann(496, 230, "(−∞, +∞)")
    ann(104, 100, "[1, 1]", anchor: "east")
    ann(486, 100, "[2, 2]", anchor: "west")
    ann(316, 16, "[1, 2]", anchor: "west")
  } else if given1 {
    ann(40, 230, "true")
    ann(138, 230, "[\"a\", \"a\"]")
    ann(266, 238, "(−∞, +∞)")
    ann(398, 230, "false")
    ann(104, 100, "[\"a\", \"a\"]", anchor: "east")
    ann(486, 100, "empty", anchor: "west")
    ann(316, 16, "[\"a\", \"a\"]", anchor: "west")
  } else if given2 {
    ann(40, 230, "false")
    ann(398, 230, "true")
    ann(496, 230, "(−∞, \"b\")")
    ann(104, 100, "empty", anchor: "east")
    ann(486, 100, "(−∞, \"b\")", anchor: "west")
    ann(316, 16, "(−∞, \"b\")", anchor: "west")
  }
  // The panel: which pass this is, and the rule it used.
  let px = 590
  let panel(head, lines) = {
    label(px, 0, head, size: 17pt, color: red, anchor: "north-west")
    label(px, 32, spaced(lines), size: 15pt, anchor: "north-west")
  }
  if step == 0 {
    panel([Key (k1, k2)], [Ranges are computed\ one key column at a time,\ bottom up, at run time.\ \ The scans drive the tree:\ Scan1 asks for k1 ranges;\ for each k1 it emits,\ Scan2 asks for k2 ranges.])
  } else if pass1 {
    panel([k1 ranges], [A leaf: the interval it allows.\ Says nothing usable: (−∞, +∞).\ AND: intersect.\ OR: union.\ \ [1, 1] ∪ [2, 2] = [1, 2]:\ integers, so adjacent points\ merge. Scan1 emits 1, then 2.])
  } else if given1 {
    panel([k2 ranges, given k1 = 1], [k1 = 1 is decided: true,\ so it drops out of its AND.\ k1 = 2 is false: its AND\ is empty, so it is pruned.\ \ REGEXP_MATCH says nothing\ about k2: (−∞, +∞).])
  } else if given2 {
    panel([k2 ranges, given k1 = 2], [k1 = 1 is false: the left\ AND is empty, pruned.\ k1 = 2 is true: drops out.\ \ Range: k1 = 2, k2 < "b".])
  } else {
    panel([Result], [k1 in [1, 2]: Scan1 emits 1, 2.\ Given 1: right AND empty, so\ k2 in ["a", "a"]: seek (1, "a"),\ REGEXP_MATCH as post-filter.\ Given 2: left AND empty, so\ k2 < "b": a range, nothing\ left to test.])
  }
  label(0, 318, "(k1 = 1 AND k2 = \"a\" AND REGEXP_MATCH(value, @param)) OR (k1 = 2 AND k2 < \"b\")",
    size: 13pt, mono: true, anchor: "west")
})

// ---- A long query meets failures ----
// step 0: the query and its stream. 1-3: one failure per click.
#let long-query(step: 3) = diagram(height: 262, {
  node(0, 10, 250, 76, [one long query], size: 18pt, sub: [50 shards, one timestamp])
  label(310, 22, [rows streamed to the client], size: 15pt, color: muted, anchor: "west")
  frame(310, 40, 520, 36)
  frame(310, 40, 208, 36, color: red, width: 2pt)
  label(414, 58, [400,000 consumed], size: 15pt, color: red)
  label(674, 58, [of 1,000,000, in 30 s], size: 15pt, color: muted)
  let events = (
    (x: 0, t: [a server restarts], s: [an upgrade, somewhere, always]),
    (x: 290, t: [a shard splits, half moves], s: [data movement]),
    (x: 580, t: [a replica is overloaded], s: [or behind the read time]),
  )
  for (i, e) in events.enumerate() {
    if i >= step { continue }
    node(e.x, 160, 270, 68, e.t, size: 17pt, color: red, sub: e.s, width: 1.4pt)
    arrow(e.x + 135, 158, 504 + i * 14, 80, color: red)
  }
})

// ---- Why a restart token carries the timestamp ----
// A scan returns keys up to 50 at ts 100 and fails. Without the timestamp the rest is read
// at ts 120, after a transaction at ts 110 moved one row. mode "dup": 10 → 90; "both" adds
// the reverse move, 90 → 10.
#let resume-ts(mode: "both") = diagram(height: 200, {
  let kx(k) = 110 + k * 5.6
  let row(y, from, to, verdict) = {
    line(((kx(0), y), (kx(100), y)), color: rule)
    line(((kx(0), y), (kx(50), y)), color: ink, width: 3pt)
    line(((kx(50), y), (kx(100), y)), color: red, width: 3pt, dashed: true)
    label(kx(25), y - 16, [ts 100], size: 14pt, color: ink)
    label(kx(75), y - 16, [resumed at ts 120], size: 14pt, color: red)
    for k in (0, 50, 100) { label(kx(k), y + 18, str(k), size: 13pt, mono: true, color: muted) }
    dot(kx(from), y, color: ink, r: 6)
    dot(kx(to), y, color: red, r: 6)
    label(kx(from), y + 18, str(from), size: 13pt, mono: true)
    label(kx(to), y + 18, str(to), size: 13pt, mono: true, color: red)
    label(kx(100) + 22, y, verdict, size: 17pt, color: red, anchor: "west")
  }
  label(0, 10, [At timestamp (ts) 110, row r’s key changes, between the two halves of one scan:], size: 16pt,
    color: muted, anchor: "west")
  label(0, 70, [10 → 90], size: 17pt, anchor: "west")
  row(70, 10, 90, [returned twice])
  if mode == "both" {
    label(0, 170, [90 → 10], size: 17pt, anchor: "west")
    row(170, 90, 10, [never returned])
  }
})

// ---- Resuming after resharding ----
// step 1: server A stops after key 24. 2: the token it leaves. 3: after resharding, one
// shard on server B. 4: the resume from the token.
#let reshard-trace(step: 4) = diagram(height: 276, {
  let kx(k) = 120 + (k - 10) * 20
  label(0, 46, [before], size: 16pt, color: muted, anchor: "west")
  node(kx(20), 24, kx(30) - kx(20), 44, none)
  line(((kx(20), 62), (kx(24.5), 62)), color: red, width: 3pt)
  label((kx(20) + kx(30)) / 2, 38, "[20, 30) on server A, ts 105", size: 14pt)
  label(kx(22), 82, [20 … 24 returned], size: 13pt, color: red)
  label(kx(30) + 14, 46, [A restarts], size: 16pt, color: red, anchor: "west")
  if step >= 2 {
    node(240, 104, 370, 34, "token: ts 105; [20, 30) done up to 24", size: 14pt, mono: true,
      color: red, width: 1.4pt)
  }
  if step >= 3 {
    label(0, 186, [after], size: 16pt, color: muted, anchor: "west")
    node(kx(10), 164, kx(40) - kx(10), 44, none)
    label((kx(10) + kx(40)) / 2, 178, "[10, 40): one shard now, on server B", size: 14pt)
  }
  if step >= 4 {
    arrow(kx(24.5), 200, kx(30), 200, color: red, width: 2pt)
    line(((kx(30), 192), (kx(30), 208)), color: red, width: 2pt)
    label(kx(30) + 10, 226, [seek just past 24, stop at 30, read at ts 105], size: 15pt, color: red,
      anchor: "north-east")
  }
  for k in (10, 20, 24, 30, 40) {
    label(kx(k), 266, str(k), size: 13pt, mono: true, color: muted)
  }
})

// ---- Appendix: one block, row-major against PAX ----
#let pax-block() = diagram(height: 220, {
  label(190, 10, [row-major block (SSTable)], size: 16pt, color: muted)
  let rows = (("7", "Ann", "Denver"), ("8", "Bob", "Boston"), ("9", "Cy", "Denver"))
  for (i, r) in rows.enumerate() {
    for (j, v) in r.enumerate() {
      node(40 + j * 100, 40 + i * 50, 100, 44, v, size: 16pt, mono: true)
    }
  }
  label(190, 205, [one row after another], size: 15pt, color: muted)
  label(645, 10, [PAX block (Ressi)], size: 16pt, color: muted)
  let cols = (("ckey", "7", "8", "9"), ("name", "Ann", "Bob", "Cy"), ("city", "Denver", "Boston", "Denver"))
  for (i, c) in cols.enumerate() {
    label(470, 62 + i * 50, c.first(), size: 15pt, mono: true, color: muted, anchor: "east")
    for (j, v) in c.slice(1).enumerate() {
      node(480 + j * 110, 40 + i * 50, 110, 44, v, size: 16pt, mono: true,
        color: if i >= 1 { red } else { ink })
    }
  }
  label(645, 205, [one array per column, inside the block], size: 15pt, color: muted)
})

// ---- Lessons: SQL adoption ----
// SQL query volume, relative to a year before the common dialect: doubled in the year
// before it, five times in the year after (1, 2, 10).
#let sql-growth() = diagram(height: 262, {
  let base = 214
  let unit = 17
  let bars = ((x: 150, v: 1, t: [a year before]), (x: 380, v: 2, t: [one dialect ships]),
    (x: 610, v: 10, t: [a year after]))
  label(40, 8, [SQL query volume, relative], size: 15pt, color: muted, anchor: "west")
  line(((90, base), (760, base)))
  for (i, b) in bars.enumerate() {
    let h = b.v * unit
    let c = if i == 2 { red } else { ink }
    frame(b.x, base - h, 90, h, color: c, fill: if i == 2 { red } else { muted.lighten(55%) })
    label(b.x + 45, base - h - 14, str(b.v), size: 16pt, color: c)
    label(b.x + 45, base + 22, b.t, size: 16pt, color: if i == 2 { red } else { ink })
  }
  // Growth over each year, between the bar tops.
  arrow(250, base - 1 * unit - 12, 370, base - 2 * unit - 12, color: muted)
  label(310, base - 2 * unit - 40, [×2], size: 18pt, color: muted)
  arrow(480, base - 2 * unit - 12, 600, base - 10 * unit + 20, color: red, width: 2pt)
  label(520, base - 6 * unit - 30, [×5], size: 22pt, color: red)
})

// ---- Lessons: one optimizer change, two queries ----
// Illustrative step curves: at one release a changed rule or estimate makes query A faster
// and query B ten times slower. Releases come about every two weeks.
#let plan-regression() = diagram(height: 254, {
  let ax = 60
  let ay = 226
  line(((ax, ay), (820, ay)))
  line(((ax, ay), (ax, 16)))
  label(ax - 10, 30, [latency], size: 15pt, color: muted, anchor: "east")
  for i in range(8) {
    let x = 110 + i * 95
    line(((x, ay), (x, ay + 8)), color: muted)
  }
  label(440, ay + 24, [releases, about every two weeks], size: 15pt, color: muted)
  let rx = 110 + 4 * 95
  line(((rx, 28), (rx, ay)), color: muted, dashed: true)
  label(rx, 14, [one optimizer change], size: 15pt, color: muted)
  // Query A: halves.
  line(((ax, 146), (rx, 146), (rx, 186), (820, 186)), width: 1.6pt)
  label(ax + 14, 130, [query A], size: 16pt, anchor: "west")
  label(rx + 20, 170, [query A: faster], size: 16pt, anchor: "west")
  // Query B: ten times slower (15 above the axis to 150).
  line(((ax, 211), (rx, 211), (rx, 76), (820, 76)), color: red, width: 2.4pt)
  label(ax + 14, 196, [query B], size: 16pt, color: red, anchor: "west")
  label(rx + 20, 58, [query B: 10× slower], size: 18pt, color: red, anchor: "west")
})

// ---- Lessons: the path to SQL, and the advice ----
// The milestones in order, as a staircase; the advice jumps from a scalable, available
// storage core (scalability plus manageability) straight to the relational model.
#let sql-path() = diagram(height: 282, {
  let steps = (([scalability], [scales out]), ([manageability], [stays up, reshards]),
    ([ACID], [across rows]), ([relational], [tables, schema]), ([schema DDL], [nested data]),
    ([SQL], [one dialect]))
  let w = 126
  let h = 46
  let bx(i) = 8 + i * 140
  let by(i) = 196 - i * 36
  for (i, s) in steps.enumerate() {
    let c = if i == 3 { red } else { ink }
    node(bx(i), by(i), w, h, s.at(0), sub: s.at(1), size: 16pt, color: c,
      width: if i == 3 { 1.6pt } else { .9pt })
    // A step up: from the top of this box to the left side of the next.
    if i < 5 {
      let cx = bx(i) + w / 2
      let y = by(i + 1) + h / 2
      line(((cx, by(i)), (cx, y)), color: muted)
      arrow(cx, y, bx(i + 1) - 2, y, color: muted, width: 1pt)
    }
  }
  // The advice: from scalability plus manageability, the storage core, to the relational model.
  let x0 = bx(1) + w / 2
  let x3 = bx(3) + w / 2
  line(((x0, by(1) + h), (x0, 256), (x3, 256)), color: red, width: 1.6pt, dashed: true)
  arrow(x3, 256, x3, by(3) + h + 2, color: red, width: 1.6pt, dashed: true)
  label((x0 + x3) / 2, 272, [advice: go relational once storage scales and stays up], size: 16pt,
    color: red)
})

// ---- Lessons: SQL vs. NoSQL, and one size fits all ----
// Left: the stack, built bottom up: a key-value core for scale and failover, then ACID across
// rows, then SQL. Right: several specialised systems against the one system customers ask for.
#let nosql-stack() = diagram(height: 262, {
  label(190, 8, [SQL vs. NoSQL], size: 16pt, color: muted)
  let layer(y, t, s, c) = node(10, y, 360, 52, t, size: 16pt, sub: s, color: c)
  layer(28, [SQL on top], [loose (F1) or tight (Spanner)], red)
  layer(90, [ACID transactions across rows], [the next-hardest barrier], ink)
  layer(152, [a key-value core: scale, failover], [what NoSQL was built for], ink)
  arrow(390, 200, 390, 34, color: muted, width: 1pt)
  label(190, 228, [built bottom up: a stack, not a choice], size: 16pt, color: red)
  line(((425, 0), (425, 262)), color: rule)
  label(645, 8, [One size fits all?], size: 16pt, color: muted)
  for (i, t) in ([OLTP], [analytics], [text search]).enumerate() {
    node(460 + i * 128, 28, 118, 52, t, size: 16pt, sub: [own system])
  }
  label(645, 112, spaced[each with its own availability, transactions,\ rollout cycle and API quirks: a burden], size: 14pt, color: muted)
  arrow(645, 136, 645, 156, color: red, width: 1.4pt)
  node(470, 158, 360, 52, [one system for all three], size: 16pt, sub: [what customers ask for],
    color: red, width: 1.4pt)
  label(645, 228, [the goal: do well across that range, over time], size: 15pt, color: muted)
})
