// Editable textbook figures. Coordinates use points, with y increasing downward.
// White cells are records/files; red marks the operation or version under discussion.
#import "@preview/cetz:0.5.2"
#import "rocksdb-theme.typ": ink, muted, red, rule, sans-font, mono-font

#let label(x, y, body, size: 18pt, color: ink, anchor: "center", mono: false) = cetz.draw.content(
  (x, -y), {
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
#let frame(x, y, w, h, color: ink, width: .9pt) = cetz.draw.rect(
  (x, -y), (x+w, -y - h), fill: white, stroke: width + color,
)
#let file(x, y, w, h, color: ink) = {
  line(((x,y),(x+w - 10,y),(x+w,y+10),(x+w,y+h),(x,y+h),(x,y)), color: color)
  line(((x+w - 10,y),(x+w - 10,y+10),(x+w,y+10)), color: color)
}
#let cells(x, y, values, w: 70, h: 42, size: 18pt, highlights: ()) = {
  for (i, value) in values.enumerate() {
    frame(x+i*w, y, w, h, color: if i in highlights { red } else { ink })
    label(x+(i+.5)*w, y+h/2, value, size: size, mono: true,
      color: if i in highlights { red } else { ink })
  }
}
#let record(x, y, key, value, seq, w: 98, accent: false, obsolete: false) = {
  frame(x, y, w, 60)
  label(x+w/2, y+21, [#key : #value], size: 21pt, mono: true, color: if accent { red } else { ink })
  label(x+w/2, y+46, [seq #seq], size: 13pt, color: muted, mono: true)
  if obsolete { line(((x+10,y+31),(x+w - 10,y+11)), color: red, width: 1.2pt) }
}
#let diagram(body, height: 275) = cetz.canvas(length: 1pt, {
  cetz.draw.rect((0,0),(850,-height), stroke: none)
  body
})

#let architecture() = diagram(height: 275, {
  frame(15, 8, 820, 167)
  label(32, 28, [Application process], size: 17pt, color: muted, anchor: "west")
  label(425, 64, [SQL · replication · sharding · recovery], size: 24pt)
  line(((32,96),(818,96)), color: rule)
  label(44, 131, [RocksDB library], size: 23pt, anchor: "west")
  label(600, 131, [Get(k)   Put(k,v)   Iterator], size: 20pt, mono: true)
  arrow(425, 177, 425, 208)
  label(444, 192, [filesystem calls], size: 16pt, color: muted, anchor: "west")
  for (x,t) in ((80,[WAL]),(324,[SST files]),(568,[MANIFEST])) {
    file(x, 219, 196, 48)
    label(x+98, 243, t, size: 21pt)
  }
})

#let write-path(stage: 1) = diagram(height: 274, {
  label(8, 77, [Put(k,9)], size: 23pt, mono: true, anchor: "west")
  arrow(124, 77, 205, 77)
  label(167, 55, [insert], size: 15pt, color: muted)
  label(331, 24, [Active memtable], size: 21pt)
  cells(213, 54, ([c=8],[k=9],[w=4]), w: 77, h: 45, highlights: (1,))
  label(329, 122, [sorted by key], size: 16pt, color: muted)
  line(((59,100),(59,180)), color: red)
  arrow(59, 180, 89, 180, color: red)
  label(93, 153, [WAL: append order], size: 20pt, anchor: "west")
  cells(93, 169, ([c=8],[w=4],[k=9]), w: 77, h: 43, highlights: (2,))
  arrow(329, 190, 382, 190, color: red)
  label(393, 190, [append], size: 16pt, color: red, anchor: "west")
  if stage >= 2 {
    arrow(450, 77, 588, 77)
    label(520, 54, [freeze when full], size: 15pt, color: muted)
    label(711, 24, [Immutable memtable], size: 21pt)
    cells(594, 54, ([c=8],[k=9],[w=4]), w: 77, h: 45)
  }
  if stage >= 3 {
    arrow(710, 103, 710, 160)
    label(728, 132, [flush], size: 17pt, anchor: "west")
    file(583, 165, 253, 64)
    cells(594, 181, ([c=8],[k=9],[w=4]), w: 73, h: 35, size: 17pt)
    label(710, 249, [L0 SST: sorted records], size: 18pt)
  }
  label(93, 253, [WAL and sync settings determine durability.], size: 16pt, color: muted, anchor: "west")
})

// The same key axis and file coordinates are used for lookup and input selection.
#let lsm(mode: "base") = diagram(height: 294, {
  let x(k) = 170 + k*25
  let selected = mode in ("select", "merge")
  label(7, 20, [Memtable], anchor: "west")
  cells(x(2), 1, ([c=8],[k=9],[w=4]), w: 175, h: 38, size: 19pt)
  label(7, 80, [L0 · newer], anchor: "west")
  label(7, 137, [L0 · older], anchor: "west")
  label(7, 218, [L1], anchor: "west")
  frame(x(0), 58, 13*25, 44, color: if selected { red } else { ink })
  label(x(0)+14, 80, [a–m], size: 17pt, anchor: "west")
  cells(x(5), 58, ([g=7],), w: 88, h: 44, highlights: if selected or mode == "lookup" { (0,) } else { () })
  frame(x(7), 115, 12*25, 44, color: if selected { red } else { ink })
  label(x(7)+14, 137, [h–s], size: 17pt, anchor: "west")
  cells(x(11), 115, ([k=6],), w: 88, h: 44, highlights: if selected { (0,) } else { () })
  for (a,b,t) in ((0,7,[a–g]),(7,14,[h–n]),(14,26,[o–z])) {
    frame(x(a), 196, (b - a)*25-5, 44, color: if selected { red } else { ink })
    label(x(a)+13, 218, t, size: 17pt, anchor: "west")
  }
  cells(x(3), 196, ([g=2],), w: 90, h: 44, size: 18pt)
  if mode == "lookup" {
    arrow(548, 80, x(5)+92, 80, color: red)
    label(690, 80, [Return g=7], color: red, size: 24pt)
    label(646, 177, [Older files need not be read], size: 16pt, color: muted)
  }
  arrow(x(0), 272, x(26), 272, color: muted)
  label(x(0), 289, [a], size: 15pt, color: muted)
  label(x(26), 289, [z], size: 15pt, color: muted)
  label(x(13), 289, [Increasing user key], size: 15pt, color: muted)
})

// Concrete records from the selected ranges. Unshown keys are omitted, not deleted.
#let compaction-records() = diagram(height: 294, {
  label(135, 13, [L0 · newer], size: 20pt)
  label(425, 13, [L0 · older], size: 20pt)
  label(715, 13, [Selected L1 files], size: 20pt)
  record(37, 35, "g", "7", 105, accent: true)
  record(135, 35, "m", "1", 103)
  record(327, 35, "k", "6", 90, accent: true)
  record(425, 35, "s", "4", 86)
  record(617, 35, "g", "2", 81, obsolete: true)
  record(715, 35, "k", "3", 80, obsolete: true)
  line(((135,106),(135,132),(370,132)))
  arrow(370,132,410,170)
  arrow(425,106,425,170)
  line(((715,106),(715,132),(480,132)))
  arrow(480,132,440,170)
  label(203, 169, [merge by key and sequence], size: 16pt, color: muted)
  record(148,185,"g","7",105,w:120,accent:true)
  record(289,185,"k","6",90,w:120,accent:true)
  record(409,185,"m","1",103,w:120)
  record(550,185,"s","4",86,w:120)
  label(120,215,[L1],size:21pt,anchor:"east")
  label(208,269,[a–g],size:17pt)
  label(409,269,[h–n],size:17pt)
  label(610,269,[o–z],size:17pt)
  label(766,213,[output\ SSTs],size:19pt,color:muted)
})

#let hdd-page-update() = diagram(height: 246, {
  label(520,13,[Same disk block],size:21pt)
  label(8,66,[Before],size:20pt,anchor:"west")
  label(8,190,[After],size:20pt,anchor:"west")
  cells(230,40,([A1],[B],[C],[D]),w:145,h:52,size:24pt)
  cells(230,164,([A2],[B],[C],[D]),w:145,h:52,size:24pt,highlights:(0,))
  arrow(302.5,101,302.5,155,color:red)
  label(192,128,[Overwrite A],size:20pt,color:red,anchor:"east")
  label(592.5,128,[B, C, D stay in place],size:20pt,color:muted)
})

// One update plus reclamation, not a mandatory block copy on every host write.
#let ssd-block-copy() = diagram(height: 246, {
  label(8,40,[Old erase block],size:20pt,anchor:"west")
  label(8,70,[erase after copying],size:17pt,color:muted,anchor:"west")
  cells(230,24,([A1],[B],[C],[D]),w:145,h:52,size:24pt)
  line(((250,65),(355,35)),color:red,width:1.4pt)
  label(8,111,[A2 update],size:21pt,color:red,anchor:"west")
  line(((143,111),(302.5,111)),color:red,width:1.2pt)
  arrow(302.5,111,302.5,135,color:red)
  for x in (447.5,592.5,737.5) {
    arrow(x,85,x,135,color:red)
  }
  label(8,162,[Fresh block],size:20pt,anchor:"west")
  label(8,192,[initially empty],size:17pt,color:muted,anchor:"west")
  cells(230,144,([A2],[B],[C],[D]),w:145,h:52,size:24pt,highlights:(0,1,2,3))
  label(302.5,230,[1 updated page],size:19pt,color:red)
  label(592.5,230,[3 unchanged pages copied],size:19pt,color:red)
})

#let lsm-flash-writes() = diagram(height: 207, {
  label(92,22,[Small updates],size:22pt)
  label(369,22,[Memtable],size:22pt)
  label(718,22,[SST files],size:22pt)
  cells(8,61,([k=1],[g=7]),w:86,h:49,size:21pt)
  arrow(189,85,264,85)
  cells(281,61,([g=7],[k=1]),w:88,h:49,size:21pt)
  arrow(473,85,594,85)
  label(534,59,[flush],size:18pt,color:muted)
  file(609,55,218,59)
  label(718,84,[sorted batch],size:21pt)
  line(((718,121),(718,163),(486,163)),color:red)
  arrow(486,163,451,163,color:red)
  label(662,194,[compaction rewrites retained data],size:18pt,color:red)
  file(269,137,180,53,color:red)
  label(359,163,[new SSTs],size:21pt,color:red)
})

#let leveled-policy() = diagram(height: 219, {
  label(75,49,[L1],size:22pt)
  label(75,133,[L2],size:22pt)
  frame(285,24,240,48,color:red)
  label(405,48,[g–n],size:22pt,color:red)
  for (x,w,t,chosen) in ((150,115,[a–f],false),(270,125,[g–k],true),(400,125,[l–p],true),(530,125,[q–z],false)) {
    frame(x,109,w,48,color:if chosen {red} else {ink})
    label(x+w/2,133,t,size:21pt,color:if chosen {red} else {ink})
  }
  arrow(405,77,405,99,color:red)
  label(684,47,[Pick a file],size:20pt,color:red,anchor:"west")
  label(684,132,[Merge only\ overlaps],size:20pt,color:red,anchor:"west")
  line(((278,169),(278,182),(517,182),(517,169)),color:red)
  label(398,208,[Output replaces the selected g–p range],size:19pt)
})

#let universal-policy() = diagram(height: 221, {
  for (y,t,v,chosen) in ((39,[Newest run],([a=9],[g=7],[z=8]),false),(104,[Older run],([a=5],[m=3],[z=6]),true),(169,[Oldest run],([a=1],[g=2],[z=4]),true)) {
    label(7,y+17,t,size:19pt,anchor:"west")
    cells(169,y,v,w:89,h:38,size:18pt,highlights:if chosen {(0,1,2)} else {()})
  }
  line(((451,123),(480,123),(480,188),(451,188)),color:red)
  arrow(480,155,558,155,color:red)
  label(673,91,[One merged run],size:21pt)
  cells(569,121,([a=5],[g=2],[m=3],[z=6]),w:67,h:50,size:16pt,highlights:(0,1,2,3))
  label(673,199,[Newest run stays separate],size:17pt,color:muted)
  label(427,13,[Each run spans the key space; runs may overlap],size:19pt,color:muted)
})

#let fifo-policy() = diagram(height: 215, {
  label(8,19,[Four equal-size SSTs; capacity limit = three files],size:21pt,anchor:"west")
  for (x,t,s) in ((10,[F1],[oldest]),(229,[F2],[]),(448,[F3],[]),(667,[F4],[newest])) {
    file(x,65,171,62,color:if x == 10 {red} else {ink})
    label(x+85,96,t,size:25pt,color:if x == 10 {red} else {ink})
    label(x+85,149,s,size:18pt,color:muted)
  }
  line(((24,120),(166,74)),color:red,width:1.8pt)
  label(95,193,[Delete F1],size:22pt,color:red)
  label(534,193,[Keep F2, F3, F4 without rewriting them],size:21pt)
})

#let policies() = diagram(height: 263, {
  label(137, 16, [Leveled], size: 23pt)
  label(428, 16, [Tiered / Universal], size: 23pt)
  label(719, 16, [FIFO], size: 23pt)
  for (y,t) in ((64,[L0]),(126,[L1]),(190,[L2])) { label(0,y,t,size:16pt,anchor:"west",color:muted) }
  frame(34,47,125,30)
  label(96,62,[a–m],size:16pt)
  frame(132,82,130,28)
  label(197,96,[h–z],size:16pt)
  cells(34,116,([a–g],[h–n],[o–z]),w:76,h:32,size:16pt)
  cells(34,174,([a–f],[g–m],[n–s],[t–z]),w:57,h:32,size:14pt)
  for (y,vals) in ((50,([a:4],[g:7],[z:1])),(111,([a:2],[m:3],[z:6])),(172,([a:1],[g:2],[z:5]))) {
    cells(323,y,vals,w:70,h:35,size:16pt)
  }
  label(428,222,[Overlapping sorted runs],size:16pt,color:muted)
  for (y,t) in ((50,[newest]),(111,[older]),(172,[oldest])) {
    file(638,y,191,35, color: if y == 172 { red } else { ink })
    label(731,y+18,t,size:18pt)
  }
  line(((630,157),(839,157)),color:red,dashed:true)
  line(((650,201),(815,178)),color:red,width:1.3pt)
  label(735,222,[discard past size cap],size:16pt,color:red)
  label(136,252,[Merge overlapping ranges],size:17pt,color:muted)
  label(428,252,[Merge whole runs lazily],size:17pt,color:muted)
  label(723,252,[Retain bounded history],size:17pt,color:muted)
})

#let bloom-membership() = diagram(height: 240, {
  label(8,20,[Question: does this SST contain key g?],size:23pt,anchor:"west")
  label(30,124,[Get(g)],size:24pt,mono:true,anchor:"west")
  arrow(144,124,257,124)
  frame(270,94,212,60)
  label(376,124,[Bloom filter],size:23pt)
  label(376,192,[Small summary of keys],size:20pt,color:muted)
  line(((492,124),(537,124),(537,65)))
  arrow(537,65,589,65,color:red)
  line(((537,124),(537,185)))
  arrow(537,185,589,185)
  label(607,55,[Definitely absent],size:22pt,color:red,anchor:"west")
  label(607,88,[Skip this SST],size:20pt,anchor:"west")
  label(607,175,[Maybe present],size:22pt,anchor:"west")
  label(607,208,[Look up the key],size:20pt,anchor:"west")
})

// One consistent toy hash mapping throughout: k -> 0,2,4; m -> 2,5,7;
// g -> 1,3,5; w -> 0,5,7. The represented set is exactly {k,m}.
#let bloom-bits = ([1],[0],[1],[0],[1],[1],[0],[1])
#let bloom-build() = diagram(height: 245, {
  label(324,13,[Bit position],size:18pt,color:muted,anchor:"east")
  for i in range(8) { label(370+i*60,13,str(i),size:18pt,color:muted,mono:true) }
  label(8,56,[Start empty],size:21pt,anchor:"west")
  cells(340,35,([0],[0],[0],[0],[0],[0],[0],[0]),w:60,h:42,size:24pt)
  for (y,key,positions,bits,selected) in (
    (105,[Insert k],[0, 2, 4],([1],[0],[1],[0],[1],[0],[0],[0]),(0,2,4)),
    (175,[Insert m],[2, 5, 7],bloom-bits,(2,5,7)),
  ) {
    label(8,y+21,key,size:21pt,anchor:"west")
    label(158,y+21,positions,size:19pt,mono:true,anchor:"west")
    arrow(289,y+21,329,y+21)
    cells(340,y,bits,w:60,h:42,size:24pt,highlights:selected)
  }
})

#let bloom-negative() = diagram(height: 242, {
  label(8,14,[Stored keys: k, m],size:21pt,anchor:"west")
  for i in range(8) { label(370+i*60,33,str(i),size:18pt,color:muted,mono:true) }
  label(8,84,[Query g],size:22pt,mono:true,anchor:"west")
  label(158,84,[1, 3, 5],size:19pt,mono:true,anchor:"west")
  arrow(289,84,329,84)
  cells(340,60,bloom-bits,w:60,h:48,size:24pt,highlights:(1,3,5))
  arrow(430,118,430,158,color:red)
  label(430,183,[Bit 1 is 0: g is absent],size:24pt,color:red)
  label(430,222,[Inserting g would have set this bit to 1.],size:20pt,color:muted)
})

#let bloom-positive() = diagram(height: 250, {
  label(8,14,[Stored keys: k, m],size:21pt,anchor:"west")
  label(750,14,[Actual SST lookup],size:18pt,color:muted)
  for i in range(8) { label(293+i*46,43,str(i),size:18pt,color:muted,mono:true) }
  for (y,key,positions,selected) in (
    (65,[Query k],[0, 2, 4],(0,2,4)),
    (170,[Query w],[0, 5, 7],(0,5,7)),
  ) {
    label(8,y+15,key,size:22pt,mono:true,anchor:"west")
    label(8,y+47,positions,size:18pt,mono:true,color:muted,anchor:"west")
    arrow(169,y+24,257,y+24)
    cells(270,y,bloom-bits,w:46,h:48,size:24pt,highlights:selected)
  }
  label(665,80,[k is in the SST],size:19pt,anchor:"west")
  label(665,111,[True positive],size:19pt,color:muted,anchor:"west")
  label(665,185,[w is not in the SST],size:19pt,anchor:"west")
  label(665,216,[False positive],size:20pt,color:red,anchor:"west")
})

#let bloom-ssts() = diagram(height: 202, {
  for (x,name,result,action,maybe) in (
    (62,[SST 1],[g absent],[Skip this SST],false),
    (336,[SST 2],[g may exist],[Read index + data],true),
    (610,[SST 3],[g absent],[Skip this SST],false),
  ) {
    file(x,20,180,55)
    label(x+90,47,name,size:23pt)
    label(x+90,109,result,size:21pt,color:if maybe {red} else {ink})
    if maybe { arrow(x+90,129,x+90,150,color:red) }
    label(x+90,177,action,size:20pt,color:if maybe {red} else {muted})
  }
})

#let resources() = diagram(height: 274, {
  frame(7,5,836,262,color:muted)
  label(27,26,[One host],size:19pt,anchor:"west",color:muted)
  for (x,t) in ((31,[RocksDB A]),(308,[RocksDB B]),(585,[RocksDB C])) {
    frame(x,52,233,42)
    label(x+116,73,t,size:21pt)
    line(((x+116,98),(x+116,115)))
  }
  line(((147,115),(701,115)))
  arrow(425,115,425,142)
  label(35,163,[Block cache],size:19pt,anchor:"west")
  label(35,214,[Write buffers],size:19pt,anchor:"west")
  cells(225,144,([A],[B],[C],[free]),w:143,h:36,size:18pt)
  cells(225,195,([A],[B],[C],[free]),w:143,h:36,size:18pt)
  label(425,250,[Compaction workers and I/O rate are also shared budgets.],size:17pt,color:muted)
})

#let delete-chain() = diagram(height: 242, {
  label(10,14,[Illustrative timing: each tick is one file deletion],size:20pt,anchor:"west")
  label(10,66,[Burst deletion],size:21pt,anchor:"west")
  label(10,165,[Rate-limited],size:21pt,anchor:"west")
  for y in (69,168) { arrow(188,y,832,y,color:muted) }
  for x in (213,222,231,240,249) { line(((x,52),(x,78)),color:red,width:1.5pt) }
  frame(282,88,382,26,color:red)
  label(474,102,[TRIM / GC work can delay foreground reads],size:16pt,color:red)
  for x in (213,332,451,570,689) {
    line(((x,151),(x,177)),color:red,width:1.5pt)
    frame(x+24,185,78,20,color:red)
  }
  label(506,228,[Spread deletion work over time],size:21pt)
  label(817,146,[time],size:15pt,color:muted)
})

#let checksums() = diagram(height: 294, {
  label(5,12,[Boundary],size:17pt,color:muted,anchor:"west")
  label(284,12,[Protected data],size:17pt,color:muted,anchor:"west")
  label(633,12,[Check],size:17pt,color:muted,anchor:"west")
  line(((5,31),(841,31)),color:rule)
  for y in (97,162,227) { line(((5,y),(841,y)),color:rule,width:.6pt) }
  label(5,62,[In-memory records],size:19pt,anchor:"west")
  cells(270,43,([key],[value],[check]),w:98,h:37,size:17pt,highlights:(2,))
  label(622,57,[Per-KV protection],size:18pt,anchor:"west")
  label(622,81,[In progress in 2021],size:15pt,color:red,anchor:"west")
  label(5,127,[Write handoff],size:19pt,anchor:"west")
  cells(270,109,([WAL bytes],[check]),w:147,h:37,size:17pt)
  label(622,126,[Storage API verifies],size:18pt,anchor:"west")
  label(5,192,[Data-block read],size:19pt,anchor:"west")
  cells(270,174,([block data],[check]),w:147,h:37,size:17pt)
  label(622,191,[Compare on read],size:18pt,anchor:"west")
  label(5,258,[File transfer],size:19pt,anchor:"west")
  file(270,241,185,36)
  label(360,259,[all SST bytes],size:17pt)
  label(516,258,[C(file)],size:17pt,mono:true)
  label(622,257,[Verify complete file],size:18pt,anchor:"west")
})

#let timestamp-versions() = diagram(height: 263, {
  label(5,17,[One user key: account/7],size:22pt,anchor:"west")
  let positions = ((100,10,100),(400,20,80),(700,30,95))
  for (x,t,v) in positions {
    frame(x - 83,57,166,48,color:if t == 20 { red } else { ink })
    label(x,81,[balance=#v],size:20pt,mono:true,color:if t == 20 { red } else { ink })
    line(((x,107),(x,158)),color:rule)
    label(x,178,[t=#t],size:18pt,mono:true)
  }
  arrow(16,149,831,149,color:muted)
  for (x,t,v) in positions { line(((x,143),(x,155)),width:1.2pt) }
  line(((550,51),(550,159)),color:red,dashed:true)
  label(550,33,[read at t=25],size:21pt,color:red)
  arrow(549,124,403,124,color:red)
  label(700,217,[Not yet visible],size:17pt,color:muted)
  label(400,240,[Return balance=80],size:23pt,color:red)
})

#let sstable() = diagram(height: 238, {
  label(5,15,[One immutable file],size:22pt,anchor:"west")
  let parts = ((5,160,[a … f]),(165,160,[g … m]),(325,160,[n … z]),(485,110,[Filter]),(595,110,[Index]),(705,75,[Meta.]),(780,65,[Footer]))
  for (x,w,t) in parts {
    frame(x,66,w,58,color:if x == 165 { red } else { ink })
    label(x+w/2,95,t,size:if w == 65 { 15pt } else { 20pt })
  }
  for (x,t) in ((85,[Data block 1]),(245,[Data block 2]),(405,[Data block 3])) { label(x,46,t,size:16pt,color:muted) }
  arrow(5,142,845,142,color:muted)
  label(425,162,[Increasing file offset],size:16pt,color:muted)
  label(650,202,[Index entry: m → block 2],size:19pt,mono:true)
  line(((595,216),(246,216),(246,169)),color:red)
  arrow(246,169,246,127,color:red)
})

#let bottlenecks() = diagram(height: 238, {
  arrow(65,137,810,137,color:muted)
  for (x,t,sub) in ((124,[Write amplification],[Flash endurance]),(425,[Space amplification],[Capacity per server]),(721,[CPU / DRAM],[Cost per workload])) {
    cetz.draw.circle((x,-137),radius:3,fill:ink,stroke:none)
    label(x,64,t,size:23pt)
    label(x,101,sub,size:19pt,color:muted)
  }
  label(125,170,[Early priority],size:17pt,color:muted)
  label(720,170,[Later cost targets],size:17pt,color:muted)
  label(425,221,[Priorities accumulated as deployments changed.],size:22pt)
})

#let copy-files() = diagram(height: 242, {
  label(137,16,[Source replica],size:23pt)
  label(719,16,[Destination replica],size:23pt)
  for (y,t) in ((53,[MANIFEST]),(108,[WAL]),(163,[SST files])) {
    file(36,y,203,39)
    label(137,y+20,t,size:19pt)
    file(617,y,203,39)
    label(718,y+20,t,size:19pt)
  }
  line(((260,53),(276,53),(276,202),(260,202)),color:red,width:1.2pt)
  label(425,76,[Pin a consistent file set],size:20pt,color:red)
  arrow(284,127,607,127)
  label(440,108,[Copy + verify checksums],size:20pt)
  label(439,178,[Release pins after copying],size:18pt,color:muted)
  label(425,234,[MANIFEST identifies the SST set. WAL holds writes not yet in SSTs.],size:18pt,color:muted)
})

#let bitflip() = diagram(height: 211, {
  label(133,18,[In memory],size:21pt)
  label(425,18,[During flush],size:21pt)
  label(725,18,[On a later read],size:21pt)
  label(133,62,[01010000 = 80],size:19pt,mono:true)
  line(((56,72),(210,53)),color:red)
  label(133,107,[01010001 = 81],size:19pt,mono:true,color:red)
  label(133,154,[One bit changes],size:18pt,color:muted)
  arrow(250,102,302,102)
  cells(311,80,([81],[C(81)]),w:111,h:45,size:20pt)
  label(423,154,[Checksum is generated],size:18pt,color:muted)
  arrow(541,102,591,102)
  label(725,68,[computed = stored],size:16pt,color:muted)
  label(725,101,[C(81) = C(81)],size:20pt,mono:true)
  label(725,154,[Check passes],size:21pt,color:red)
  label(425,199,[The file faithfully preserves an already-corrupted value.],size:19pt,color:muted)
})

// FAST talk pp. 16-20: changing local disk count cannot finely match both budgets.
#let disaggregation() = diagram(height: 266, {
  label(208,16,[Locally attached SSDs],size:22pt)
  label(665,16,[Disaggregated storage],size:22pt)
  for (y,count) in ((58,2),(136,3)) {
    frame(9,y,87,43)
    label(52,y+22,[CPU],size:20pt)
    arrow(102,y+22,132,y+22)
    cells(140,y,range(count).map(i => [2 TB]),w:73,h:43,size:17pt)
  }
  label(205,209,[More disks shift the CPU/space ratio.],size:17pt,color:muted)
  label(205,240,[One resource can still sit idle.],size:19pt)
  for x in (507,685) {
    frame(x,58,146,43)
    label(x+73,79,[CPU + RocksDB],size:17pt)
    line(((x+73,106),(x+73,137)))
  }
  line(((580,137),(758,137)))
  arrow(669,137,669,178)
  label(726,157,[network],size:16pt,color:muted)
  cells(507,185,([SSD],[SSD],[SSD],[SSD]),w:81,h:43,size:18pt)
  label(669,254,[Provision CPU and flash separately],size:18pt,color:red)
})

// FAST talk pp. 33-36, with the same host replacement sequence.
#let replica-loss() = diagram(height: 281, {
  let stages = (
    (15, [Initially], ((1,true),(2,false),(3,false))),
    (325, [After one replacement], ((1,true),(4,true),(3,false))),
    (635, [After two replacements], ((1,true),(4,true),(5,true))),
  )
  for (x,title,hosts) in stages {
    label(x+100,15,title,size:19pt)
    for (i,(host,bad)) in hosts.enumerate() {
      let y=57+i*56
      file(x,y,200,40,color:if bad { red } else { ink })
      label(x+100,y+20,[Host #host: #if bad {[bad]} else {[good]}],size:18pt,color:if bad {red} else {ink})
    }
  }
  arrow(220,35,312,35)
  arrow(530,35,622,35)
  label(115,248,[One undetected\ corrupt replica],size:17pt,color:muted)
  label(425,248,[Copy 1 → 4;\ retire healthy host 2],size:17pt)
  label(735,248,[Copy 4 → 5;\ retire healthy host 3],size:17pt)
})

#let verified-transfer() = diagram(height: 260, {
  label(425,15,[Save C(F), the checksum of file F computed at SST creation.],size:21pt)
  for (x,title) in ((25,[Original SST]),(325,[Backup]),(625,[Restored SST])) {
    label(x+100,65,title,size:21pt)
    file(x,86,200,56)
    label(x+100,114,[file bytes F],size:19pt,mono:true)
    label(x+100,164,[saved C(F)],size:18pt,mono:true)
  }
  arrow(230,131,319,131)
  arrow(530,131,619,131)
  label(275,111,[verify],size:17pt,color:red)
  label(575,111,[verify],size:17pt,color:red)
  label(425,213,[C(received bytes) must equal the saved C(F)],size:22pt,color:red)
  label(425,249,[Use this check for replica file copies, backup, and restore.],size:19pt)
})

#let handoff() = diagram(height: 275, {
  label(5,16,[Without a caller-supplied handoff checksum],size:21pt,anchor:"west")
  cells(20,48,([b],),w:175,h:45,size:22pt)
  arrow(201,70,326,70,color:red)
  label(263,49,[bit flip],size:16pt,color:red)
  cells(332,48,([b′],),w:175,h:45,size:22pt,highlights:(0,))
  arrow(513,70,634,70)
  label(736,57,[Storage accepts b′],size:20pt,color:red)
  label(736,86,[and checksums b′],size:17pt,color:muted)
  label(5,145,[With a checksum computed before copying],size:21pt,anchor:"west")
  cells(20,180,([b],[H(b)]),w:100,h:45,size:19pt)
  arrow(226,202,326,202,color:red)
  label(276,178,[bit flip],size:16pt,color:red)
  cells(332,180,([b′],[H(b)]),w:100,h:45,size:19pt,highlights:(0,))
  arrow(538,202,634,202)
  label(739,189,[H(b′) ≠ H(b)],size:20pt,mono:true,color:red)
  label(739,217,[Reject the write],size:19pt,color:red)
  label(425,264,[b is the write buffer, including the WAL record's internal checksum.],size:17pt,color:muted)
})
