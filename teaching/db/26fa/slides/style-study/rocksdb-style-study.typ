#import "@preview/cetz:0.5.2"

#let ink = rgb("#222222")
#let gray = rgb("#666666")
#let red = rgb("#A82025")
#set document(title: "RocksDB: theme and diagram study", author: "Shuai Mu")
#set page(width: 960pt, height: 540pt,
  margin: (x: 48pt, top: 30pt, bottom: 32pt),
  fill: white,
  footer: context {
    set text(font: "Helvetica Neue", size: 11pt, fill: gray)
    grid(columns: (1fr, auto), [CSE 532 · Fall 2026 · RocksDB / visual study], counter(page).display())
  },
)
#set text(font: ("Helvetica Neue", "Arial"), size: 22pt, fill: ink)
#set par(leading: .6em, spacing: 0pt)

#let heading(title, detail) = [
  #text(size: 12pt, fill: gray, tracking: 1.4pt)[ROCKSDB / STORAGE ENGINE]
  #v(16pt)
  #text(font: ("STIX Two Text", "Times New Roman"), size: 39pt, weight: "semibold", title)
  #v(16pt)
  #text(size: 16pt, fill: gray, detail)
  #v(26pt)
]

#let label(x, y, body, size: 18pt, color: ink, anchor: "center", mono: false) = cetz.draw.content(
  (x, -y), text(font: if mono { "Menlo" } else { "Helvetica Neue" }, size: size, fill: color, body), anchor: anchor,
)
#let record(x, y, key, value, seq, width: 100, accent: false, obsolete: false) = {
  cetz.draw.rect((x, -y), (x + width, -y - 60), stroke: .9pt + ink, fill: white)
  label(x + width / 2, y + 21, [#key : #value], size: 22pt, color: if accent { red } else { ink }, mono: true)
  label(x + width / 2, y + 46, [seq #seq], size: 13pt, color: gray, mono: true)
  if obsolete {
    cetz.draw.line((x + 10, -y - 31), (x + width - 10, -y - 11), stroke: 1.2pt + red)
  }
}
#let arrow(points) = cetz.draw.line(..points.map(p => (p.at(0), -p.at(1))), stroke: 1.2pt + ink, mark: (end: ">", fill: ink))

#heading([Compaction is a sorted merge], [Textbook theme · precisely placed record diagram · CeTZ])
#cetz.canvas(length: 1pt, {
  cetz.draw.rect((0, 0), (864, -280), stroke: none)
  label(40, 14, [Input SST A], size: 19pt, anchor: "west")
  label(514, 14, [Input SST B], size: 19pt, anchor: "west")
  record(40, 40, "a", "1", 105, accent: true)
  record(140, 40, "b", "8", 104)
  record(240, 40, "d", "4", 103, accent: true)
  record(514, 40, "a", "9", 90, obsolete: true)
  record(614, 40, "c", "2", 86)
  record(714, 40, "d", "0", 81, obsolete: true)
  arrow(((190, 112), (190, 145), (361, 145), (401, 186)))
  arrow(((664, 112), (664, 145), (493, 145), (453, 186)))
  label(427, 120, [merge], size: 19pt)
  record(197, 197, "a", "1", 105, width: 115, accent: true)
  record(312, 197, "b", "8", 104, width: 115)
  record(427, 197, "c", "2", 86, width: 115)
  record(542, 197, "d", "4", 103, width: 115, accent: true)
  label(175, 226, [Output], size: 19pt, anchor: "east")
})
#v(9pt)
#text(size: 23pt)[Here, the larger sequence number wins for each key.]
#v(7pt)
#text(size: 14pt, fill: gray)[Illustrative inputs. Older versions shown here have no snapshot that needs them. Output remains sorted by key.]

#pagebreak()
#heading([Put writes a log and an ordered buffer], [Textbook theme · automatic layout · D2, clean rendering])
#align(center)[#image("write-path-clean.svg", width: 864pt, height: 280pt, fit: "contain")]
#v(15pt)
#text(size: 23pt)[The WAL preserves write order; the SST preserves key order.]
#v(8pt)
#text(size: 14pt, fill: gray)[Ordinary WAL-enabled path. A synchronous write also waits for WAL sync; background flush creates an L0 SST.]

#pagebreak()
#heading([Put writes a log and an ordered buffer], [Textbook theme · same D2 source · sketch rendering])
#align(center)[#image("write-path-sketch.svg", width: 864pt, height: 280pt, fit: "contain")]
#v(15pt)
#text(size: 23pt)[The WAL preserves write order; the SST preserves key order.]
#v(8pt)
#text(size: 14pt, fill: gray)[Ordinary WAL-enabled path. A synchronous write also waits for WAL sync; background flush creates an L0 SST.]
