# RocksDB visual study

Three sample pages to compare a restrained textbook theme and diagram renderers:

1. A CeTZ compaction figure with actual keys, values, sequence numbers, and
   discarded versions. Thin black rules, white cells, and a single red accent.
2. A WAL-enabled write-path diagram, laid out with D2/ELK and rendered cleanly.
3. The same D2 source rendered with `--sketch`.

The theme uses STIX Two Text titles and Helvetica Neue / Arial body text. It is
the prototype chosen for the full lecture's redesign.
The figures are teaching illustrations, not reproductions of a paper figure.

## Build

The SVG outputs are included, so rebuilding the PDF only needs Typst and CeTZ:

```sh
typst compile rocksdb-style-study.typ
```

To regenerate the diagrams, install [D2](https://d2lang.com/tour/install/).
These samples were built with D2 0.9.0:

```sh
d2 --layout elk --theme 0 --pad 16 write-path.d2 write-path-clean.svg
d2 --layout elk --theme 0 --sketch --pad 16 write-path.d2 write-path-sketch.svg
typst compile rocksdb-style-study.typ
```

D2 SVGs embed their own fonts for browser viewing. Typst may substitute installed
fonts when importing these SVGs; inspect the PDF after changing the renderer or
fonts. The PDF was rendered and visually checked on the lecture's build machine.

## Design direction

- Encode a concept with its structure: sorted record cells, append-only logs,
  file offsets, and ranges drawn on a shared key axis.
- Use red for the operation or records currently under discussion. Avoid a
  separate pastel panel for every noun.
- Keep coordinates stable between successive steps of the same example.
- Use CeTZ for exact data-structure geometry, and D2 for high-level relationships.
  Sketch strokes alone do not improve the explanatory structure of a figure.
- For drawings edited by hand, [Excalidraw](https://github.com/excalidraw/excalidraw)
  is another option: retain the editable `.excalidraw` file and export SVG to Typst.
