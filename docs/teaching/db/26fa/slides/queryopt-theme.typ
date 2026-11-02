// Shared look for the query-optimization deck. Same template as rocksdb-theme.typ:
// identical geometry, palette, type scale, and spacing rules; only the lecture
// metadata and the two extra display helpers (sql, formula) differ.
#import "@preview/touying:0.7.4": *
#import "@preview/touying:0.7.4": themes

#let ink = rgb("#222222")
#let muted = rgb("#666666")
#let red = rgb("#A82025")
#let rule = rgb("#BBBBBB")
// Arial and STIX Two Math are per-glyph fallbacks only: Helvetica Neue and Menlo
// have no bowtie (U+22C8) or outer-join signs, which this lecture needs.
#let sans-font = ("Helvetica Neue", "Arial", "STIX Two Math")
#let title-font = ("STIX Two Text", "Times New Roman", "STIX Two Math")
#let mono-font = ("Menlo", "Arial", "STIX Two Math")
#let paper-url = "https://doi.org/10.1145/582095.582099"
#let companion-url = "https://doi.org/10.14778/2850583.2850594"

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
        grid(columns: (1fr, auto), [CSE 532 · Fall 2026 · Query Optimization], utils.slide-counter.display())
      },
    ),
    config-info(
      title: [Query Optimization],
      subtitle: [CSE 532 · Database Systems · Fall 2026],
      author: [Shuai Mu],
      date: datetime(year: 2026, month: 11, day: 2),
    ),
  )
  set document(title: "Query Optimization — CSE 532, Fall 2026", author: "Shuai Mu")
  // Explicit 1em line boxes + .5em leading give 1.5em baseline spacing.
  // Typst leading is the gap between text edges, not the baseline distance.
  set text(font: sans-font, size: 24pt, fill: ink, top-edge: .8em, bottom-edge: -.2em)
  set par(leading: .5em, spacing: .8em)
  set list(indent: 17pt, body-indent: 8pt, spacing: .65em)
  set enum(indent: 23pt, body-indent: 8pt, spacing: .65em)
  show raw: set text(font: mono-font, size: .85em)
  // Typst already sets raw text at .8em, which compounds with the .85em above. Undo that
  // for inline code so it sits at .85 of the text around it; code blocks keep the size
  // their slides were laid out at.
  show raw.where(block: false): set text(size: 1.25em)
  show strong: set text(weight: "bold", fill: ink)
  show link: set text(fill: ink)
  body
}

#let lecture-slide(title, body, source: none, notes: none, section: false) = themes.default.slide[
  #if section {
    v(135pt)
    text(font: title-font, size: 44pt, weight: "semibold", fill: ink, title)
  } else {
    block(height: 46pt, above: 0pt, below: 0pt)[#text(font: title-font, size: 37pt, weight: "semibold", fill: ink, title)]
    v(18pt)
  }
  #body
  #if notes != none {
    speaker-note(subslide: none)[#notes #if source != none { [\ Source: #source. #paper-url] }]
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
// SQL and relational algebra, set off by a left rule rather than a box.
// Highlighting is off: the palette is ink/muted/red, and red is reserved for
// the clause under discussion, which a slide marks itself.
#let sql(body, size: 24pt) = block(
  above: 14pt, below: 14pt,
  inset: (left: 15pt, y: 9pt),
  stroke: (left: 2pt + rule),
  {
    set raw(theme: none)
    text(font: mono-font, size: size, body)
  },
)
// One centered cost or selectivity formula, for slides that are about the formula.
#let formula(body, size: 27pt) = block(
  above: 22pt, below: 22pt, width: 100%,
  align(center, text(font: mono-font, size: size, body)),
)
