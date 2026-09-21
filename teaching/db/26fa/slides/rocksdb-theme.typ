#import "@preview/touying:0.7.4": *
#import "@preview/touying:0.7.4": themes

#let ink = rgb("#222222")
#let muted = rgb("#666666")
#let red = rgb("#A82025")
#let rule = rgb("#BBBBBB")
#let sans-font = ("Helvetica Neue", "Arial")
#let title-font = ("STIX Two Text", "Times New Roman")
#let mono-font = ("Menlo", "DejaVu Sans Mono")
#let paper-url = "https://www.usenix.org/conference/fast21/presentation/dong"
#let talk-url = "https://www.usenix.org/sites/default/files/conference/protected-files/fast21_slides_dong.pdf"

#let lecture-theme(body) = {
  show: themes.default.default-theme.with(
    config-common(
      handout: sys.inputs.at("handout", default: "false") == "true",
      zero-margin-footer: false,
    ),
    config-page(
      width: 960pt,
      height: 540pt,
      margin: (left: 48pt, right: 48pt, top: 34pt, bottom: 38pt),
      fill: white,
      footer-descent: 0pt,
      footer: context {
        set text(size: 11pt, fill: muted)
        grid(columns: (1fr, auto), [CSE 532 · Fall 2026 · RocksDB], utils.slide-counter.display())
      },
    ),
    config-info(
      title: [RocksDB],
      subtitle: [CSE 532 · Database Systems · Fall 2026],
      author: [Shuai Mu],
      date: datetime(year: 2026, month: 9, day: 21),
    ),
  )
  set document(title: "RocksDB — CSE 532, Fall 2026", author: "Shuai Mu")
  // Explicit 1em line boxes + .5em leading give 1.5em baseline spacing.
  // Typst leading is the gap between text edges, not the baseline distance.
  set text(font: sans-font, size: 24pt, fill: ink, top-edge: .8em, bottom-edge: -.2em)
  set par(leading: .5em, spacing: .8em)
  set list(indent: 17pt, body-indent: 8pt, spacing: .65em)
  set enum(indent: 23pt, body-indent: 8pt, spacing: .65em)
  show raw: set text(font: mono-font, size: .85em)
  show strong: set text(weight: "bold", fill: ink)
  show link: set text(fill: ink)
  body
}

#let lecture-slide(title, body, source: none, talk-pages: none, notes: none, section: false) = themes.default.slide[
  #if section {
    v(135pt)
    text(font: title-font, size: 44pt, weight: "semibold", fill: ink, title)
  } else {
    block(height: 46pt, above: 0pt, below: 0pt)[#text(font: title-font, size: 37pt, weight: "semibold", fill: ink, title)]
    v(18pt)
  }
  #body
  #if notes != none {
    speaker-note(subslide: none)[#notes #if source != none { [\ Source: #source. #paper-url] } #if talk-pages != none { [\ Talk pages #talk-pages. #talk-url] }]
  }
]

#let small(body) = block(above: 0pt, below: 0pt, text(size: 20pt, body))
#let caption(body) = block(above: 16pt, below: 0pt, text(size: 18pt, fill: muted, body))
#let takeaway(body) = {
  block(above: 28pt, below: 16pt, text(size: 24pt, weight: "medium", fill: ink, body))
}
#let columns(left, right, widths: (1fr, 1fr)) = grid(
  columns: widths,
  column-gutter: 34pt,
  left,
  right,
)
#let comparison(..cells, columns: (1.2fr, 1fr, 1fr)) = {
  set text(size: 21pt)
  table(
    columns: columns,
    inset: (x: 12pt, y: 12pt),
    align: left + horizon,
    stroke: (top: none, bottom: .6pt + rule, left: none, right: none),
    fill: none,
    ..cells,
  )
}
