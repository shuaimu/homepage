# CSE 532 RocksDB lecture

September 21, 2026. Follows `../notes/rocksdb.md` and Dong et al.,
*Evolution of Development Priorities in Key-value Stores Serving Large-scale
Applications: The RocksDB Experience* (FAST 2021).

## Present and share

- `DB26fa-RocksDB.pdf`: 70 logical slides, 73 PDF pages, including three incremental
  reveals. Present this version and advance one PDF page per click.
- `DB26fa-RocksDB-handout.pdf`: 70 pages with each slide's final state, for students.
- `DB26fa-RocksDB.pdfpc`: presenter notes and overlay metadata for pdfpc. Keep it
  next to the presentation PDF. Other PDF viewers can display the slides normally.

Slides 1–62 form the core lecture. The suggested timings in the speaker notes
total 92 minutes, including discussion and the separate compaction-policy examples.
For an 80-minute route, omit the prior-lecture review on slides 5–11 (7 minutes)
and the discussion activities on slides 21 and 60–61 (7 minutes), leaving two minutes
for transitions. Slide 63 opens the appendix; slides 64–70 are optional material on hardware,
key/value separation, read costs, project history, the original utilization
chart, and the talk's amplification estimates. Presenting all appendices adds
approximately 12 minutes; they are also included in the student handout.

Slides 2–3 introduce LevelDB's origins and Facebook's RocksDB fork, using
[Google's 2011 announcement](https://opensource.googleblog.com/2011/07/leveldb-fast-persistent-key-value-store.html)
and [Facebook's 2013 announcement](https://engineering.fb.com/2013/11/21/core-infra/under-the-hood-building-and-open-sourcing-rocksdb/).
These add about two minutes before the RocksDB architecture overview.

Slide 12 opens the section with "Why do we need LSM on SSD?"
Slides 13–15 introduce flash write costs with matched four-page diagrams: an HDD
overwrites one page in place; an SSD writes the updated page and copies the three
live pages to fresh space before erasing the old block, producing 4× write
amplification in this example. The SSD diagram combines an update with later
reclamation; it does not imply copying a block on every update. Slide 15 connects
these costs to LSM batching and compaction. Page sizes and counts are illustrative.
Background:
[OSTEP's SSD chapter](https://pages.cs.wisc.edu/~remzi/OSTEP/file-ssd.pdf).
Slide 16 introduces the compaction-policy section.
Slides 17–19 give leveled, universal/tiered, and FIFO one worked diagram each;
mechanics were checked against the [RocksDB compaction documentation](https://github.com/facebook/rocksdb/wiki/Compaction)
and [FIFO documentation](https://github.com/facebook/rocksdb/wiki/FIFO-compaction-style).
Slide 20 compares the measurements and defines write amplification and space
overhead beneath the table; slide 21 closes the section
with suggested policies and reasons beside each application. Source links and qualifications stay in
the speaker notes.

Slides 22–27 introduce Bloom filters from first principles: a title divider,
membership testing, construction with hashes, definite absence, false positives,
and RocksDB's use of filters to skip SST lookups. One eight-bit example carries
through construction and queries; its hash outputs are illustrative. The section
takes about nine minutes, seven more than the earlier single-slide introduction.
Background: [Bloom's original paper](https://www.cs.princeton.edu/courses/archive/spr05/cos598E/bib/p422-bloom.pdf)
and [RocksDB's filter documentation](https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter).

After the concept review, title-only dividers mark the remaining parts:

| Divider slide | Part | Content slides |
| --- | --- | --- |
| 28 | Resource optimization | 29–33 |
| 34 | Data integrity and recovery | 35–43 |
| 44 | Operating RocksDB at scale | 45–51 |
| 52 | Versions and timestamps | 53–58 |
| 59 | Discussion and takeaways | 60–62 |
| 63 | Appendix | 64–70 |

The dividers use the same style as the flash, compaction, and Bloomfilter title
pages. They add transitions without changing the suggested content timings.

The later slides define terms and explain the mechanisms directly on the page:
checksum boundaries, recovery, shared host budgets, WAL durability, file pinning,
and timestamped reads. Short additions explain checksum creation and verification
(35), WAL recovery (46), independent shard sequence numbers (55), and
one worked answer to the design discussion (61). Concrete examples supplement
the existing diagrams without reducing type size or line spacing. Suggested
timings are redistributed within those topics; the core now totals 92 minutes.

Slides 53–54 compare sequence numbers with user timestamps and show two versions
carrying both fields. The worked reads demonstrate that a snapshot's sequence limit
and the application's timestamp limit both apply. Local sequence numbers do not
provide a common clock across shards. These explanations use the
[RocksDB timestamp documentation](https://github.com/facebook/rocksdb/wiki/User-defined-Timestamp)
and [snapshot documentation](https://github.com/facebook/rocksdb/wiki/Snapshot)
to clarify the paper's concepts, without treating newer APIs as 2021 features.

The deck was checked against all 48 pages of the
[official FAST 2021 slides](https://www.usenix.org/sites/default/files/conference/protected-files/fast21_slides_dong.pdf).
See [FAST21-coverage.md](FAST21-coverage.md) for the original-page-to-lecture-slide
mapping, gaps found and filled, and the distinction between talk estimates and
paper measurements. Substantive talk content is covered in the core or appendix;
section dividers, repeated reveal frames, and closing branding are consolidated.

Speaker notes retain the paper and talk links with section, table, figure, and
page references. Citation footnotes are omitted from the projected slides.
Measurements and feature status describe the 2021 paper and talk, not current
RocksDB releases. The key/value examples and diagrams are teaching illustrations.

The full lecture uses the selected textbook style: serif titles, white pages,
thin black rules, and red highlights for the active record or operation.
Body text uses 1.5× baseline spacing (36pt for 24pt type); separate bullets use
1.65× spacing (39.6pt). Explicit Typst text edges make this independent of font
metrics. The full lecture, including reveal states, and the handout were rendered
and visually reviewed after the explanatory revisions.
The figures show records and sequence numbers, sorted key ranges, Bloom bits,
file layouts, and timelines. The original theme study and clean/sketch D2
comparison remain in [`style-study/`](style-study/README.md).

## Build

Requires Typst 0.15 or later (checked with 0.15.1). Imports pin Touying 0.7.4 and
CeTZ 0.5.2. Typst downloads packages on the first build and caches them outside
this repository.

```sh
make -C teaching/db/26fa/slides
```

Or, from this directory:

```sh
typst compile DB26fa-RocksDB.typ
typst compile --input handout=true DB26fa-RocksDB.typ DB26fa-RocksDB-handout.pdf
typst eval --in DB26fa-RocksDB.typ --pretty 'query(<pdfpc-file>).first().value' > DB26fa-RocksDB.pdfpc
```

For an explicit external package cache:

```sh
make -C teaching/db/26fa/slides TYPST_FLAGS='--package-cache-path /tmp/typst-packages'
```

`rocksdb-theme.typ` defines the typography and layout. Titles use STIX Two Text /
Times New Roman; body text uses Helvetica Neue / Arial; records use Menlo /
DejaVu Sans Mono. On Linux, install STIX Two Text and set `sans-font` to an
installed font such as Liberation Sans. Changing fonts can change wrapping,
so inspect the regenerated PDF on another platform.
`rocksdb-diagrams.typ` contains the editable CeTZ drawings. The original survey
chart is retained as a source image in `assets/`, with provenance in its README.
Slide text, source
references, and speaker notes are in `DB26fa-RocksDB.typ`.

To preview the homepage, run from the repository root with a throwaway Jekyll
destination. Explicitly loading the existing compatibility shim also works with
the Ruby 4 installation used to check this deck:

```sh
bundle exec ruby -r ./_plugins/ruby4_compat.rb -S jekyll serve --destination /tmp/rocksdb-site
```

Building these slides does not require Jekyll. Avoid regenerating the tracked
`docs/` tree unless publishing intentionally.
