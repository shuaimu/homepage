# CSE 532 Spanner SQL lecture

November 4, 2026. Follows `../notes/spanner-sql.md` section by section and Bacon, Bales,
Bruno, Cooper, Dickinson, Fikes, Fraser, Gubarev, Joshi, Kogan, Lloyd, Melnik, Rao, Shue,
Taylor, van der Holst, and Woodford, *Spanner: Becoming a SQL System* (SIGMOD 2017,
pages 331–343). It comes two days after the query-optimization lecture
(`README-QueryOpt.md`) and builds on it: Apply is last lecture's nested-loop join, the
range-extraction strawman is last lecture's matching index. The filter tree, with System
R's CNF and Table 1 as its foils, is in the lecture notes, not on slides.

## Present and share

- `DB26fa-SpannerSQL.pdf`: 50 logical slides, 102 PDF pages. Twenty slides build in steps,
  one click per step: slide 2 three (one bullet per click); slide 3 five (the System R
  column, then Spanner's side one row per click); slide 4 two (SQL beside the store, then
  inside it); slide 9 two (Q1, then what it does in words); slide 10 two (strawman 1 with
  the array, then without it); slide 11 four (the parallel-database plan, then one reason
  it fails per click); slide 13 three (the rewrite, then the compiled tree, then the
  run-time calls); slide 14 four (slide 13's compiled tree with a pull-up arrow, then one
  bullet per click); slide 16 six (the operators with the question, then one row's verdict
  per click); slide 17 four (the split rule with its three operators, then one row's local
  and final parts per click); slide 19 three (the interleaved tables, then the plan before,
  then after the two unions merge); slide 20 six (the start, then one per pull-up step of Q1);
  slide 22 three (the array, its points, the shards called); slide 24 three (Q2 and the
  index, then where each Denver customer lives, then Q2 as a join); slide 30 two (the one
  range, then the wanted seek per document); slide 31 six (Scan1, Scan2, the CrossApply
  that runs Scan2 per project, Scan3, the CrossApply that runs Scan3 per path, then a
  summary); slide 33 four (a long query and its stream, then one failure per click); slide
  34 four (the three strawmen, then each one's cost per click); slide 36 two (a row
  returned twice, then a row never returned); and slide 38 four (server A stops, the
  token, the merged shard on server B, the resume). Each
  slide's speaker note starts with its timing and, where it has any, its states. Present
  this version and advance one PDF page per click.
- `DB26fa-SpannerSQL-handout.pdf`: 50 pages with each slide's final state, for students.
- `DB26fa-SpannerSQL.pdfpc`: presenter notes for all 102 pages and overlay metadata for
  pdfpc. Keep it next to the presentation PDF.
- `DB26fa-SpannerSQL.html`: the same slides as one self-contained page (about 4.8 MB,
  works offline) that counts 50 slides, not 102 pages; the keys are those of the
  query-optimization player (→ next step, ↓ / ↑ next or previous slide, S speaker
  window, O overview, F full screen, ? for the list). Build it with
  `make -C teaching/db/26fa/slides spannersql-export` (Python 3 and typst only; poppler's
  pdftotext and pdfinfo add slide titles if present); it is generated from the
  presentation PDF and the pdfpc file, so rebuild it after any slide change. Like the
  query-optimization player it is a local build product and is not committed.
- `DB26fa-SpannerSQL.pptx`: a PowerPoint copy, built on request with
  `make -C teaching/db/26fa/slides DB26fa-SpannerSQL.pptx`: one slide per logical slide,
  each reveal step a full-slide picture that appears on click, and no speaker notes.
  Also a local build product, not committed.

## Route and timing

The deck has two parts: a main route sized for about 44 slides, and five backup slides.

Slides 1–44 are the main route, ending on the recap, slide 44. They keep the four
mechanisms the paper is about and the setup they need: the machine and interleaving
(6–7), Q1 and the two strawmen (9–11), distribution as an operator with
partitionability, joins written as Apply (18) and the walk that distributes Q1, then shard
pruning (13–22), batched
distributed joins (24–27), range extraction from the start/stop-key strawman to one scan
per key column (29–31), and restarts up to resharding
(33–38), then, after a "Spanner Lessons" divider (39), four lessons from production, a
figure each: users wanted SQL, plans must not regress, scale first, then go relational, and
SQL vs. NoSQL with one size fits all (40–43). The speaker-note timings total 61 minutes; they assume a brisk pace, so a slower one, with
questions, fills an 80-minute
slot.

Slide 45 opens the backup: five self-contained slides, about a minute each, for when the
main route finishes early, usable in any order: one call per Paxos group and shard
affinity (46), Q2's two-level plan (47), location hints (48), parallel consumers (49),
and locking rows that are not there yet, a preview of Nov 11 (50).

The backup's speaker-note timings total 5 minutes. The handout carries both parts. Earlier
versions also had an appendix: the slides cut from the main route (shards moving, Q1 on
one machine, how Scan2 skips, one predicate's three uses, the filter tree and the slides
that prepare it, why extraction is safe, tokens across reruns and releases, what restarts
bought, why inside, not beside), the pull-up rule cards, the notes' optional parts (one
SQL dialect, Ressi, the paper's full lessons), the design assembled, where the idea went
and the review questions. It was removed before publishing; the lecture notes cover all
of it.

The main route covers what the cut slides used to show in two ways. Slide 6's speaker
note says aloud that shards split, merge and move between groups at any time, which
strawman 2 (slide 11) needs. Q1's plan tree first appears as the start of the walk,
slide 20, and strawman 1 (slide 10) speaks of running "all of Q1" rather than its tree.
Otherwise it claims nothing that only the backup shows: the recap (44) shows six topics
with a few reminder words each, no sentences, and its note says the line behind each,
with Paxos-group calls and affinity left to backup slide 46. The notes of slides 22, 28
and 44 point to the lecture notes for one predicate's three uses, predicates with OR and
NOT, and why extracted ranges may be too big but never too small, and the recap's note
points to the review questions at the end of the lecture notes.

If time is shorter still, skip slides 2 (why Spanner became SQL), 14 (pull the
union up) and 38 (resharding) first. Never skip slides
15–16 and 20, partitionability and the walk that distributes Q1; slide 27, where
batching makes the index pay per shard touched; slide 31, one scan per key column; or
slides 35–36, the restart token and its timestamp.

Title-only dividers mark the parts:

| Divider slide | Part | Content slides |
| --- | --- | --- |
| — | The job | 1–4 |
| 5 | Revisit Spanner | 6–7 |
| 8 | Example Query | 9–11 |
| 12 | Distribution as an operator | 13–22 |
| 23 | Joins across shards | 24–27 |
| 28 | Range extraction | 29–31 |
| 32 | Restarts | 33–38 |
| 39 | Spanner Lessons | 40–43 |
| — | Recap | 44 |
| 45 | Backup | 46–50 |

## The locked scenario

**The shard map, the arrays, the Denver batch, the version counts and the restart traces
are illustrative; the paper gives none.** The paper's own examples are its Figure 1 query
(Q1 here), the Documents table of section 4 with its parameters P001 and 2017-01-01 and
its ten documents under /proposals, the filter-tree predicate of Figure 4, and the
resharding example of section 5 ([20, 30) merged into [10, 40)); the deck uses all but the
filter tree, which is in the notes only,
says in slide 29's note which Documents values are the paper's, names the documents doc1 to
doc10 (so the path after doc1 is doc10, not the paper's doc2), and adds the following,
consistent with the notes:

- Customer is sharded on `ckey` into S1 `[−∞, 250)` in G1, S2 `[250, 500)` in G2, S3
  `[500, 750)` in G1 and S4 `[750, +∞)` in G3; Sales is interleaved in Customer. G1
  holding two shards is what slide 46's "four shards, three calls" relies on. Slide 6
  draws the map and its note asks the class to photograph it.
- Q1's array is `[7, 412, 7, 950]`: deduplicated to 7, 412 and 950, it calls S1, S2 and
  S4 and never S3 (slide 22).
- Q2 (`c.city = 'Denver'`) uses the global index CustomerByCity, key (city, ckey),
  sharded on city at Chicago and Miami, so index shard I2 holds all of Denver. Denver's
  entries are ckeys 7, 300, 310, 820 and 990: five rows in three Customer shards, five
  calls one after another without batching (slide 25), three calls in parallel with it
  (slide 27). Slide 25's note uses 1,000 Denver customers for the row-at-a-time cost.
- Each of the paper's ten documents gets 1,000 versions: one start/stop range reads
  10,000 rows to keep 10 (slide 30), and the correlated scans of slide 31 seek each
  document's one wanted version instead. Paths are strings, so in key order
  `/proposals/doc10` comes right after `/proposals/doc1`: slide 30's strip shows those two
  and draws doc2 to doc9 as one box.
- The restart scenario is one query over 50 shards streaming a million rows, 400,000
  consumed (slide 33). The timestamp figure moves one row between keys 10 and 90 at ts
  110, between halves read at ts 100 and ts 120 (slide 36). The resharding trace on slide
  38 uses the paper's ranges with our timestamp, keys and servers.

Statements the notes mark as "our reading" stay marked in the speaker notes; on screen
they are stated plainly, like everything else, since no slide refers to the paper: hash
sharding sufficing for `GroupBy(ckey)` (slide 16), the Apply pull-up rule, which slide
47's figure states beside Q2's two-level plan, and why the key-column lock covers a range
(slide 50).

The deck as a whole and the notes teach the same content in the same order, and nothing
on the slides goes beyond the notes except the lesson slides (40–43): their
Cloud-customer caption, the six-step path with its advice arrow, the regression
curves, and slide 43's burden of running several systems and its goal of doing well
across that range come from the paper's sections 8 and 9, beyond the notes' shorter
lessons list.
The main route presents a subset of the notes and the backup slides a little more; the
rest, including "The rules, collected" and "Questions to review", is in the notes only.
The paper's two slips (Timestamp once for Version, DocumentId in Figure 3) are mentioned
only in slide 29's note.

## Standards

The deck follows the query-optimization deck's standard. Every slide stands alone in the
handout: its claim is argued on the slide, and no technical word appears on screen
before a slide has defined it. No slide cites another slide by number on screen; the
cross-references live in the speaker notes and this README. Nor does any slide after the
title refer to the paper: no "the paper says", no quoted sentences, no "ours" against
"the paper's". Each slide states its content directly, and the speaker notes keep the
attributions and section numbers. On the main route, terms
are defined where first used: *shard* on slide 3 (as key ranges) and with the *Paxos
group* on slide 6, Bigtable and OLTP on slide 2, TiKV on slide 4, *sharding key* on
slide 7, the array `@arr` on slide 9 (slide 10 says "the array", not "IN list"),
`CrossApply` and `OuterApply` on slide 18, `Top(5)` on slide 16,
DistributedUnion and the *root server* on slide 13, *partitionability* and
`OrderedUnionAll` on slide 15, OpLocal and OpFinal on slide 17,
the *sharding-key filter* on slide 20, *shard pruning* on slide 22, DistributedApply,
with `Batch` and `Unnest`, drawn on slide 26 (its caption was dropped),
the *restart token* and the *snapshot timestamp* on slide 35, `t_safe` on slide 36, strong reads, the leader replica
and wound-wait on slide 37. Slide 3 says "a query at one timestamp" rather than "snapshot". The backup
slides define their own terms: shard affinity (46), the *location hint* (48),
*root-partitionable* and *parallel consumers* (49), and *phantom* (50).
Slide 30 says "test key columns" rather than last lecture's "factors match", slide 18
avoids "column op value", slide 24 writes Q2 as a join over the index table rather
than naming an access path, and slide 25 labels the nested-loop cost formula and names its
outer and inner, so no slide needs the previous lecture's vocabulary to be read. The
speaker notes follow the same rule for what the lecturer says aloud: a term from Oct 19
or last lecture gets a phrase of gloss where it first comes up (wound-wait, `t_safe`,
interesting order, Table 1's selectivity guesses, PD, a TiFlash learner).

The look is the query-optimization deck's: `spannersql-theme.typ` is a copy of
`queryopt-theme.typ` with this lecture's title, date and DOI, plus `size` and `inset`
options on the `comparison` table helper. Serif titles, white pages, thin grey rules, red
for the one operator, shard, call or range under discussion. Body text is 24pt with 1.5×
baseline spacing and tables 21pt; dense slides were reflowed or split rather than set
smaller. Code blocks use the `sql` helper, whose
size argument is about 1.47 times the rendered size because the theme's raw-text rules
compound; the sizes in the source were picked by rendering.

`spannersql-diagrams.typ` holds 27 editable CeTZ figures and no images; three of them,
`key-range-call`, `filter-tree` and `pax-block`, drew the removed appendix and are unused,
kept so those slides can be restored. It copies the
query-optimization deck's drawing primitives rather than importing them, so the two decks
can change independently. Every figure that draws Customer's shard strip uses the same
geometry (`shard-row`), so S1–S4 sit in the same place on slides 6, 10, 22, 24, 25 and 27;
slide 49 instead groups the four shards under its two workers. Slides 24, 25 and 27 also
open with the same one-line lead, so the index figure does not move between them.
The four lesson figures, `sql-growth`, `plan-regression`, `sql-path` and `nosql-stack`,
draw slides 40–43 in one state each; the second's curves are illustrative, as its caption says.
Twelve figures in the deck take a `stage:`, `step:` or `mode:` parameter, and several keep identical
coordinates across states so the picture stays still while one thing changes:
`q1-tree` draws the six states of slide 20 and slide 21
(`"final"`), with only the union, and from step 1 its sharding-key filter, moving; `index-calls` draws slides 24, 25 and 27
(`"index"` then `"scatter"`, `"row"`, `"batch"`); `doc-keys` draws slide 30
(`"range"`; its `"seek"` mode drew a removed slide); `coupling` draws slide 4, the loose design alone and then both;
`du-fanout` draws slide 13, the compiled tree alone and then the run-time calls too (slide 14's
`pull-up`, which takes no parameter, redraws that tree with a "pull up" arrow and the root and
shard brackets); `parent-child-merge` draws slide 19's three states, the interleaved shards, then the plan
before, then after the two unions merge;
`self-join-tree` draws the six states of slide 31, whose last
state, the handout page, is the tree with a one-line summary; `beside`,
`pruning`, `long-query`, `resume-ts` and `reshard-trace` draw the reveals of slides 10, 22, 33, 36
and 38. Every reveal only
adds to the picture except on slides 10, 20 and 31: on 10 the second state replaces the
with-array picture (S3 greyed, thin arrows) with the no-array one, its caption
keeping its baseline; on 20 the union moves up the tree and the panel reddens the current
step; on 31 the tree is built bottom up, Scan1, Scan2, their CrossApply, Scan3, the top
CrossApply, each red with its edges as it appears, with a line naming what it needs or feeds, and turns black on the next click.
Multi-line text inside figures, prose and the scan boxes' code alike, goes through the
`spaced` helper, which gives it the body text's 1.5× baseline spacing (CeTZ labels do not
inherit the theme's text edges); no figure text is smaller than 13pt. The last state of each slide is its handout page.

The whole deck, every reveal state included, and the handout were rendered and
inspected page by page at 960 × 540. An independent review then checked the slides and
notes against the paper and the notes, the teaching standard, the figures and every
rendered page; 70 findings survived a second reviewer's attempt to refute them and were
applied, the deck was rendered and inspected again, and a second, smaller review of the
fixes found 27 more, mostly line wraps and README details, which were applied the same
way. The deck was then cut to a 45-slide main route at the lecturer's request, with five
backup slides and the rest moved to the appendix; every speaker-note cross-reference was
renumbered, the transitions around the cut slides were rewritten, and every page was
inspected again. A term audit followed: four reviewers, three by slide range and one by
term, listed every word used on screen or in a note before the deck defined it, and three
skeptics tried to refute each; 80 survived (many duplicates). Thirty-eight on-screen
edits and thirty-two note glosses were applied, every changed slide was re-rendered in each
state, and seven that then wrapped badly or crowded the footer were reworded to fit.
Slide 18 was also reworded so that Apply differs from last lecture's nested loop in what
its inner side can be, not in whether the inner side sees the outer row. The lecturer
then moved the three slides that keep the AND/OR tree, build the filter tree and argue why
extraction is safe into the appendix, beside the two that prepare the leaves, which
shortened the main route to 42 slides and 58 minutes. A script renumbered every note
cross-reference and each was checked against its target's title, and the recap's ranges
line was rewritten so that the main route claims nothing it no longer shows. Three lesson slides
with figures were then added before the recap (40–42), which moved the recap after them and
the main route to 61 minutes; the appendix's text lists of lessons (70–71) stay as the full
version. Then slides 2 and 3 were swapped, so the reason Spanner became SQL comes before
the bridge from System R, and slides 2, 3 and 4 got reveals (62 minutes); the dividers on
slides 5 and 8 were retitled "Revisit Spanner" and "Example Query". Later, one predicate's
three uses moved to the appendix (55), ahead of the filter-tree slides, and why inside, not
beside followed it (63), after what restarts bought; the main route is now 43 slides, 60
minutes. A "Spanner Lessons" divider (39) then went in before the lessons. Joins as Apply
moved from right after Q1 to just before the first join the union meets (18), so the
strawmen follow Q1 directly. A fourth lesson, SQL vs. NoSQL and one size fits all (43),
went in before the recap, which now shows its six topics as reminder words. Scan2 skips
then moved to the appendix too, so the main route is 44 slides, the recap at 44. Before
publishing, the appendix was removed from the deck (50 slides); its notes references now
point to the lecture notes. Four of the first round's fixes also corrected the
lecture notes, which the deck follows: the point-lookup hop (one call becomes two, not
"most of the latency"), the doc10 key order, the NOT push-down example, and a
floating-point SUM's input order changing its value rather than the row order.

## Build

Requires Typst 0.15 or later (checked with 0.15.1). Imports pin Touying 0.7.4 and CeTZ
0.5.2.

```sh
make -C teaching/db/26fa/slides spannersql
make -C teaching/db/26fa/slides spannersql-export   # the HTML player
```

Or, from this directory:

```sh
typst compile DB26fa-SpannerSQL.typ
typst compile --input handout=true DB26fa-SpannerSQL.typ DB26fa-SpannerSQL-handout.pdf
typst eval --in DB26fa-SpannerSQL.typ --pretty 'query(<pdfpc-file>).first().value' > DB26fa-SpannerSQL.pdfpc
```

Fonts are the query-optimization deck's: STIX Two Text titles, Helvetica Neue body, Menlo
code, with Arial and STIX Two Math as per-glyph fallbacks for ⊆, ∘, ∪, ∩, ⇒ and ⋈.
Building the slides does not need Jekyll; avoid regenerating the tracked `docs/` tree
unless publishing.
