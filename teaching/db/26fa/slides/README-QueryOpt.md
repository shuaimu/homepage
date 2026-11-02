# CSE 532 Query Optimization lecture

November 2, 2026. Follows `../notes/selinger.md` section by section and Selinger,
Astrahan, Chamberlin, Lorie, and Price, *Access Path Selection in a Relational Database
Management System* (SIGMOD 1979, pages 23–34). The appendix's retrospective uses Leis,
Gubichev, Mirchev, Boncz, Kemper, and Neumann, *How Good Are Query Optimizers, Really?*
(PVLDB 9(3), 2015) and its 2018 VLDB Journal version.

## Present and share

- `DB26fa-QueryOpt.pdf`: 85 logical slides, 121 PDF pages. Nineteen slides build in
  steps, one click per step: slide 8's notation table adds one sign per click, four
  states; the four rule cards, slides 13–16, show the query first and the table on the
  click; slide 29 has three (EMP's pages, then the segment scan under them, then the
  index scan over them); slide 37's nested loop has three (the loop, what its inner line
  really is, then the formula); slide 40's merge trace has five; slide 44 three (the
  question, the continuation priced once, then the order caveat); slide 46 three (two of
  EMP's four paths, then the scan's route through a sort, then the ordered path); slide
  47's dynamic program four, one per level of its loop and then everything under it; the
  search lattice seven on slide 51 (the singles, then DEPT, EMP, JOB, {EMP, DEPT} and
  {EMP, JOB}, each explained in a panel, then the question) and three on slide 52 (the
  pairs, the triple and its panel, then the winning path); and slides 5, 9, 26, 49, 64
  and 75 two each, most of them a question or a picture first and its answer on the
  click. Each slide's speaker note starts with its clicks. Present this version and
  advance one PDF page per click.
- `DB26fa-QueryOpt-handout.pdf`: 85 pages with each slide's final state, for students.
- `DB26fa-QueryOpt.pdfpc`: presenter notes for all 121 pages and overlay metadata for
  pdfpc. Keep it next to the presentation PDF. Other PDF viewers can display the slides
  normally.
- `DB26fa-QueryOpt.html`: the same slides as one self-contained page (5.9 MB, works
  offline in any browser) that counts 85 slides, not 121 pages. A slide's steps advance
  one click at a time under one slide number, and the address names both:
  `#40.3` is the third step of slide 40. Keys: → or Page Down for the next step,
  ↓ / ↑ to skip to the next or previous slide, a number then Enter to jump, S for a
  speaker window with the notes, the next step, and a timer that follows the main
  window, O for an overview, F for full screen, B to black the screen, ? for the list.

Build the HTML file with `make -C teaching/db/26fa/slides queryopt-export` (Python 3
and typst only); it is generated from the presentation PDF's pages and the pdfpc file,
so rebuild it after any slide change. A PowerPoint copy is not kept while the slides are
changing. When one is needed, `make -C teaching/db/26fa/slides DB26fa-QueryOpt.pptx`
builds it: 85 slides with the speaker notes, each step a picture of the rendered page
that appears on a click, so it is for presenting rather than editing.

Slides 1–55 form the core lecture, which ends on a recap, slide 55. The suggested
timings in the speaker notes total 75 minutes, inside an 80-minute slot with five minutes
to spare. Slide 56
opens the appendix, 36 optional minutes, all of it in the student handout. It starts
with the two parts the core route stops before, in their old order, so that time left
at slide 55 runs straight on: nested queries, slides 57–59
(3 minutes), and what held up when the paper was re-tested in 2015, slides 60–66
(8 minutes), ending with the notes' "The design, assembled". The reference cards follow,
slides 67–85 (25 minutes). For a shorter slot, cut in this order, and skip slides while
presenting rather than deleting them from the source: the slide numbers in the speaker
notes are literal, so a deletion would shift every later reference. The slides
themselves cite no other slide by number, so a skipped slide leaves no dangling pointer
on screen.

For 69 minutes, omit slides 13, 34, 38, 48 and 54. Three of them are second views of
something a neighbouring slide already shows, and slide 54 is a coda to the search.
Slide 14 already states the break-even in rough counts, past about 500 scattered rows,
and slide 33 shows the scan winning, so dropping slide 34 costs the exact crossing, `F =
500 / 10,040`, about five per cent, and its list of what moves it. The page-level
nested-loop figure, slide 38, repeats the pseudocode of slide 37, so what is lost is the
no-index aside (10 × 500 = 5,000 pages). Slide 47 already
states the one-plan-per-(subset, order) rule, so dropping slide 48 costs only the 2ⁿ
column beside slide 43's n! and its admission that at three tables subsets are a loss, 8
against 6; the last sentence of slide 43's note, which points ahead to slide 48, then
points to the handout. Slide 54 holds the paper's own search-cost figures, and its note
says where the subset search lives today; slide 3 still asks whether the cheapest plan
can be found fast. Slide 13 is the card where rule 1 is right: slide 12 still says each
rule is right on plenty of queries and slide 5 already draws rule 1's two lookups, `DNO
= 50` and `JOB = 5`, but the room no longer watches the rule win before it breaks. Rule
2's good case, slide 15, stays because it defines the lookup.

For 66 minutes, also omit slides 7, 25 and 31: the pipeline, whose one-line definitions
of *query block* and *catalog* then belong to the speaker on slide 20, and whose
optimize-once, run-many argument is then left to the speaker on slide 3; the funnel,
since slides 9 and 10 already say 20 rows and slide 36's note states the 1,000 pairs,
though the name `result_rows` goes with it, and the 200
rows of {EMP, JOB}, behind the 20-page sort and the 200 × 2 lookups in slide 52's 230 ·
603 row, must then be said aloud there; the clustered counterfactual, whose 135 survives
as a bar on slide 33, so slide 32's scatter stands alone against Table 2. If more must
go, slide 40's merge trace is next, two minutes and five PDF pages. It sits in the join
section, between slide 39's definition of the merge join and slide 41's comparison of
the four plans.

Never omit slide 33 or slides 44–47: those are the lecture's two hard turns, the one
predicate priced three ways, where the obvious index loses to a scan, and the subset
dynamic program. Keep slide 19 at every length as well, because it sets the
page-fetches-only convention every later cost relies on, and its note is the one core
place that says what the paper's CPU term is, and keep strawman 1 (slides 9–10) and each
rule's breaking card (slides 14 and 16) with slides 12, 15 and 17, slide 39, where the
merge join is defined, and the recap, slide 55, which is the lecture's ending. If the
room is talkative in the many-tables part, take the cuts above rather than cutting into
the search.

**Statistics, page counts and all costs are illustrative for this lecture; the paper
gives none.** The paper's Figure 1 shows three toy tables with three or four rows, no
cardinalities, no page counts and no worked costs; its Figures 2 to 6 are symbolic, and
its text prunes paths by assumption ("For this example we assume that the index on JOB
is the cheapest path"). Everything numeric in this deck is derived from the table sizes
on slide 4, restated in the catalog's terms on slide 21, and can be reproduced with a
calculator.

The deck follows the lecture notes in their order, with their content and vocabulary;
where the two once disagreed, the notes won. There are three departures. The notes
define interesting orders under "One table"; the deck explains the idea on slide 46,
where the subset search first needs it, and says *useful order* on screen. The merge
trace on slide 40 walks DEPT with EMP on DNO, the pair the join section prices; the
notes walk EMP with JOB. The third is the ending: the core route stops after the notes'
"Many tables" with a recap of its own, and the three parts that follow it in the notes,
nested queries, what held up and the design assembled, open the appendix. Slides 1–5 are
the notes' "The job" and "The tables". Slide 2 prints the paper's Figure 1 query
verbatim, six lines, and the whole hour runs on it. Nothing in its WHERE clause filters
EMP, the biggest table, and the deck uses that rather than hiding it: rule 2 breaks on
it (slide 16's caption), and every EMP index path matches nothing, which is why Table
2's two matching-nothing rows, the ones abridgements drop, carry weight on slide 30. An
earlier version of the deck added a seventh line, `AND EMP.SAL > 20000`, so that an
index on EMP could match; that line is gone and every plan cost changed with it. `SAL >
20000` survives as a separate one-table query, `SELECT NAME FROM EMP WHERE SAL > 20000`,
wherever the lecture needs an index that matches: rule 1's breaking card (slide 14) and,
joined to DEPT, rule 2's (slide 16); slide 24's speaker note; the access-path section up
to slide 34; and appendix slides 72 and 79. Each of those slides prints its own SQL or
says which query it is on. Slide 3 asks the four choices as plain questions, with no
numbers, because nothing has been explained yet: the join order, scan or index, how to
join two tables, and whether to sort. It closes on the goal as a question, the same rows
every way, so which way is cheapest and can it be found fast; its speaker note points at
the appendix cards from slide 68, which price each question. Slide 4 gives the three
tables' sizes, with each index's kind, values and pages; slide 5 explains "stored in DNO
order" and draws the two kinds of index, a department's 100 rows on 5 adjacent pages
through the clustered DNO index against a job code's 200 rows scattered through the
non-clustered JOB index, then gives the answer for scale: 200 clerks, 1 in 10 of them in
a Denver department, about 20 rows.

Slide 8 is the notation card: σ, π, × and ⋈, each read aloud, with ⋈ defined as a × with
a σ on the join column, since slide 10 is that equivalence read right to left. The
algebra is Codd 1970; Selinger's paper works in SQL query blocks and draws no algebra
trees, so the trees are this lecture's. Slides 7–10 follow the query from text to a
stored plan and price the tree as parsed: 50,000,000 intermediate rows, about 5,000,000
page fetches, to return 20 rows from three tables occupying 507 pages, about 31,000
times the plan the optimizer eventually picks. Slide 10 pushes the two local filters
down and leaves EMP's slot empty, with 10,000 · 10 · 1 rows going up, 1,000 pairs and 20
rows out. System R's rewriting is kept as small as it was: conjunctive normal form and
pushdown, with view expansion and unnesting credited to later systems.

Slides 12–17 try the obvious rule book in the notes' words — always use an index if one
exists; always join in FROM order — and derive the three inventions the rest of the
paper is made of: a cost measure, statistics, and a search. Slide 12 shows only the two
rules; the speaker states the counting convention aloud. Every card in this part uses
the notes' rough counts, not page-fetch formulas: a disk read brings a whole page, a
scan reads EMP in 500 reads, a clustered index finds rows 20 to a read and a
non-clustered one about a read per row, and the index's own pages are left out. Exact
formulas first appear with Table 2 on slide 30. Each rule gets two cards, a query where
it is right and one where it breaks. Rule 1 uses one-table queries on EMP: `DNO = 50` at
about 5 reads and `JOB = 5` at about 200 both beat the 500-read scan, and `SAL > 20000`
at about 2,500 loses five to one, because the index pays per row it finds and the scan
per page. Rule 2 uses two-table queries, each naming first the table it filters, which
is the bet the rule makes: `DEPT, EMP` filtered to Denver needs 10 lookups into EMP
against 10,000 reversed, but `EMP, DEPT` filtered on SAL needs 2,500 lookups into DEPT
against 100, and the paper's own `FROM EMP, DEPT, JOB` starts with the one table its
WHERE clause does not filter at all. The pattern matters more than the four cards: a
rule is not wrong because it is simple, it is wrong because it cannot see the data. The
rule book's bill on the running query, which can only be priced once the cost model
exists, is appendix slide 75; slide 17's note points there. The merge join is defined in
the join section, slides 39 and 40, just before slide 41 prices it.

Slides 19–21 define the objective and the catalog, three slides where an earlier version
had seven. Slide 19 is `COST ≈ PAGE FETCHES`, a page fetch being one data or index page
read from disk, the unit strawman 2 already counted as reads, argued in three general
lines and nothing else: disk is slow next to the CPU work on a page's rows, disk moves
whole pages so a row costs its page, so the plan that reads the fewest pages is the
cheapest. Rows matter only through the pages they make a plan touch: once per page for a
scan, about once per row found for a non-clustered index, once per page of matching rows
for a clustered one, which slides 29 to 32 draw. Counted in rows, rule 1 would always
look right, 2,500 rows found by the SAL index against 10,000 read by the scan; counted
in pages it loses 2,510 to 500, the review question slide 85's note answers. The paper's
CPU term, `W × RSI CALLS`, is only the approximate sign on slide 19, named in its note
and set aside, deliberately: the paper gives `W` no value anywhere, on one table every
path passes up the same rows so the term cannot change the winner, and every cost in the
deck was the page-fetch term alone anyway, so carrying the RSI, `W` and the call counts
through the core cost three slides and changed no decision. Between join plans the call
counts do differ; slide 79's note says the term is dropped there for want of a `W`, not
because it cancels. Optional appendix slide 79 has the rest: the two-layer picture (the
compiled plan above the RSI, the RSS below it, one NEXT call per row passed up, a row a
search argument rejects costing pages but no call), `W` as an exchange rate with made-up
timings (`W` = 0.01, the one-table SAL scan at 500 + 2,500 × 0.01 = 525), two made-up
plans that swap places when `W` falls from 0.01 to 0.001 (B wins 160 to 200, then A wins
110 to 151), and PostgreSQL's `cpu_tuple_cost` as the same knob. Slide 63, in the
appendix's retrospective, is the re-run's evidence that the cost model matters less than
the cardinalities fed into it, a main-memory result the journal version qualifies on
disk.

Slide 20 is the four catalog numbers on one figure, `rows` and `pages` per table and
`distinct` and `index_pages` per index, with `distinct` kept per index, which is where
Table 1's constants come from, and the manual UPDATE STATISTICS refresh. There is no
`share`: the paper's P exists because System R can store several tables in one disk
segment, which a scan then reads whole; here every table has its own, so a scan of T
reads exactly `pages(T)`, which slide 20's note says in one line. The visible
consequence is JOB, whose scan now costs 2 and ties its unique TITLE index (see the
locked numbers below). Slide 21 restates slide 4 in the catalog's terms, with 20 rows
per page, the SAL key range and the sort convention in small type.

The paper's statistic names are replaced throughout by plain ones: `rows`, `pages`,
`distinct`, `index_pages`, `result_rows` and `outer_rows`. The paper's letters are not
consistent (the N in NCARD counts rows, the N in NINDX counts pages), and Table 2 reads
directly once they are gone: clustered matching is `F × (index_pages + pages)`,
non-clustered matching `F × (index_pages + rows)`. No slide prints the paper's
names; slide 20's speaker note gives the mapping for reading the paper: NCARD = rows,
TCARD = pages, ICARD = distinct, NINDX = index_pages, and later QCARD = result_rows, and
names P only to say why it is dropped. The join formula's N becomes `outer_rows` on
slide 37, whose caption explains it in place. The paper's merge-inner formula, built on its
temporary-page count and the CPU term, is replaced by one sentence, a sorted inner is
read once in total (slides 39 and 40). One speaker note, on slide 77, names ICARD, QCARD
and NCARD for a reader checking Table 1 against the paper.

Slides 23–26 turn each boolean factor into a number and then read the assumptions inside
the multiplication, which the appendix's retrospective judges. Slide 23 is Table 1
abridged, with the AND row in its caption; OR, NOT and the fine print are on appendix
slide 77. The running query has four factors, 1/50 for `TITLE = 'CLERK'`, 1/10 for
`LOC = 'DENVER'`, 1/100 and 1/50 for the two joins, and nothing on EMP (slide 24); slide
24's speaker note interpolates the one-table query's `SAL > 20000` to 1/4 and says it is a
different query. Slide 25's funnel takes 50,000,000 rows to 20, local factors first
(1,000,000, 100,000, 1,000, 20), and names the product `result_rows`. Nothing in the
part counts calls any more, so the funnel has no calls bar. Slide 26 shows the correlation
with four of DEPT's rows rather than a picture: every Denver department has an 802 ZIP,
so independence predicts 1 department of 100 and the data has 10; the three assumptions
behind Table 1 are left to the speaker. DNO 50–52 and their
cities are Figure 1's; DNO 57 and the `ZIP` column are illustrative.

Slide 27 is a three-line outline of what remains, asked as questions in slide 3's style:
the cheapest way to read one table, the cheapest way to join two, and the order in which
to join three or more; the three parts that follow answer them in that order.

Slides 29–34 price one relation on its own. This is the first hard spot, and up to slide
34 it runs on the one-table SAL query, which slide 29 says on the slide. Slide 29 draws
the two ways to read a table, one click each, and nothing else. Its speaker note defines
search arguments aloud, which once had a slide of their own: a filter of the form
`column op value` is sargable, a scan tests it as it reads so failing rows cost no extra
page, an index whose key starts with that column can use it to start and stop its range,
and `column = column` inside one table is not sargable. The same note defines *matches*.
Slide 30 is Table 2 without the paper's `W` terms: six situations and eight formulas,
since both non-clustered rows have a buffer-fit second form, drawn on appendix slide 78.
Slides 31 and 32 are a matched pair, identical geometry with one changed arrow pattern,
so the audience sees clustering turn `rows` into `pages` in the formula: 135 as a
counterfactual clustered SAL index, 2,510 for the real non-clustered one. Slide 33 is
the punchline, where the same predicate priced three ways makes the obvious index lose
to a plain segment scan by 5.02×; slide 34 generalizes it into a reusable crossing rule
at about five per cent of the rows, the index losing once the qualifying rows outnumber
the table's pages, which is strawman 2's "past about 500 scattered rows" made exact.
Every path on slide 33 tests `SAL > 20000` as it reads and returns the same 2,500 rows,
so pages are the whole comparison; the clustered bar is a counterfactual. The running
query's own EMP paths wait for the search: slide 46 says in plain words, without the
paper's term *interesting order*, why the search keeps a dearer plan that arrives in a
useful order, and appendix slide 80 lists every path, the scan at 500, the
DNO and JOB indexes at 550 and 10,050 kept for their orders, and the SAL index at 10,040
pruned.

Slides 36–41 are the two join methods, and they assume no prior exposure beyond strawman
2. Slide 36 opens on a join written as two loops, for each DEPT row and for each EMP
row, with two boxes that name the loops' tables: the outer, read once, row by row, and
the inner, read again for every outer row, one lookup into it being a probe; its note
distinguishes outer and inner from an outer join. `outer_rows` is explained in place on
slide 37 and *composite* on slide 50, so neither gets a line of its own. Slides 37 and
38 are nested loops: three lines of pseudocode, titled "Nested loops: rule 2's lookups"
to link the method to strawman 2's name for it, then the same loop drawn as pages. Slide
37 derives the 5.5-page probe of EMP's clustered DNO index before using it in 5 + 10 ×
5.5 = 60. Slides 39 and 40 define the merge join before it is priced: slide 39 in words,
as the other way to join two tables, worth it when the lookups would be many, 10,000
rather than 10; slide 40 as a four-step trace on the paper's own Figure 1 rows and on
the pair slides 38 and 41 use, DEPT with EMP on DNO: DEPT after LOC = 'DENVER' (50 MFG,
52 SHIPPING) walked against EMP in its stored DNO order (SMITH 50, JONES 50, DOE 51),
neither side sorted, one step per click, with the merge's cost beneath it in two short
lines: each input read once, in join order, through a clustered index for its index and
table pages, or else its table pages plus a sort. The numbers (EMP 50 + 500 and DEPT 2 +
5, slide 41's 557, or EMP scanned, 500 + 1,000) and the two stepping rules are left to
the speaker. Slide 41 sets the four candidates for {EMP, DEPT} side by side, 60, 62,
20,500 and 557, a 342-fold gap from which table goes outside; the merge row reads both
inputs through their clustered DNO indexes, EMP for 50 + 500 and DEPT for 2 + 5 = 7,
which its top line gives. In the paper's model a segment scan has no order, so the
stored order comes through the clustered index, never through a plain scan, a point
slide 46's note makes again.

Slides 43–54 are the join-order search. Slide 43 opens it with the order problem: every
order returns the same rows at very different cost, and the naive search prices all n!
of them, eight minutes at twelve tables and 77,000 years at twenty at a microsecond an
order. Slides 44–47 are the second hard spot: slide 44 asks, with a reveal, whether the
next join cares how {EMP, DEPT} was built; slide 45 makes the exchange argument numeric,
since every continuation of {EMP, DEPT} falls by the identical 20,440 when the 60
subplan replaces the 20,500 one, and two of its totals are old friends, 22,500 for the
rule book and 20,603 for the FROM order; slide 46 shows what that argument cannot
absorb, which is order, at 1,507 against 557, and leaves to the speaker that 557 still
loses to 60; and slide 47 is the dynamic program as the notes write it, one level per
subset size, the best plan per (subset, order). Slide 48 is honest about the saving: at
three tables, subsets are a loss, 8 against 6, and the technique pays from five tables
on. Slides 49 and 50 add the two heuristics, one slide each. Slide 49 is no cross
products: the join graph beside the six orders, with the two that would open with DEPT ×
JOB struck out. Slide 50 is left-deep only, drawn to read without the speaker: slide
36's outer and inner label a left-deep tree whose every inner is a base table, beside
the bushy tree it rules out, whose top inner is a composite, with the two reasons
underneath, an index probe into a base-table inner, and a composite that is only ever an
outer, read once, so it streams on unless a merge must sort it. Slides 51 and 52 run the
lattice, drawn bottom-up like the plan tree on slide 53 and revealed a step per click:
the singles with the keep rule, each single, each pair, the question, then the triple
and the winning path. The box under discussion is outlined in red, and a panel under the
lattice prices it: one row per kept entry, and one per group of struck entries that lose
the same way, each with its arithmetic and, in grey, why it is kept or struck. On the
question the panel clears and the two entries it asks about turn red in their boxes. The
bottom of both slides carries no other text. They arrive at 163 page fetches for 20
rows: a DEPT segment scan, ten probes of EMP's clustered DNO index, a sort of the 1,000
pairs on JOB and a merge with JOB through its clustered index, 5 + 55 + 100 + 3. At
level one JOB's scan is struck as a tie with its TITLE index. The two dear kept pair
entries, 30,050 and 20,550, produce the same rows as the 60 and the 203 in their own
subsets and are kept only for their orders; both lose at the triple, at 30,053 and
20,557, because the sort they save costs only 20 or 100. Slide 53's ledger prices the
same 20 rows three other ways: the rule book at 22,500 (138×), the FROM order as written
at 20,603 (126×), and the tree as parsed at about 5,000,000 (about 31,000×). The 20,603
is the FROM order run with lookups for the first pair, the convention appendix slide 68
uses for all four orders; with a merge for that pair EMP first costs 557 + 100 + 3 =
660, so neither the slides nor their notes call 20,603 the FROM order at its best. Slide
54 gives the paper's own search-cost figures.

Slide 55 ends the core route with a recap, one line per part in the order the hour built
them: the rules that broke, the cost measure, the estimates, then one, two and many
tables. Its takeaway is the result, 163 page fetches for the 20 rows against 22,500 for
the rule book, and its caption is the forward reference to Spanner. Its speaker note
points each line back at the slides that built it.

The appendix opens with the two parts the core route stops before. Slides 58–59 are the
paper's two nested-query cases on our EMP; the correlated one compares each salary with
the department average rather than the paper's manager, a column our EMP does not have.
Slides 61–65 check the paper against the 2015 re-run, one invention at a time — the
paper's own claim on slide 61, the statistics on 62, the cost measure on 63, the search
space on 64 — and slide 66 ends that part with the notes' "The design, assembled",
eight steps, nested queries included, with a speaker note that points each one back at
the slide that built it. Their speaker notes are marked optional, like the rest of the
appendix, and keep their timings. The enumeration survived;
the left-deep search space did not; the statistics were replaced; the assumptions are
still with us. Background reading used for that part: [the 2015 conference
paper](https://www.vldb.org/pvldb/vol9/p204-leis.pdf), [the 2018 VLDB Journal
version](https://ir.cwi.nl/pub/27562/27562.pdf), [the authors' 2025
retrospective](https://ir.cwi.nl/pub/35880/35880.pdf), [Ioannidis and Christodoulakis
1991](https://www.csd.uoc.gr/~hy460/pdf/p268-ioannidis.pdf), and [Lohman's 2014 SIGMOD
blog post](http://wp.sigmod.org/?p=1075). Every plan-enumeration and tree-shape figure
comes from the 2018 journal version, not from the 2015 conference version, whose
plan-enumeration results the authors' own retrospective reports as incorrect due to a
data-handling issue and corrected in the journal. The withdrawn conference figures
(1.06× median, 4.50× max for the left-deep restriction) appear only in slide 64's
speaker note, labelled as withdrawn. No per-system number anywhere in the deck names a
commercial product.

After those two parts the appendix holds the cards the core route moved out. Slides
67–74 are the glossary and the four choice cards that used to open the lecture,
recomputed for the six-line query, with the three cards that explain them: which table
first (163, 230, 20,527, 20,603), where 163 comes from, what one lookup costs (5.5, 201,
2), why the last two terms differ, index or scan on the one-table query (500, 550,
2,510, 10,050), which join method (60, 20,500, 557), and sort or never sort (saving
1,897, saving 373, losing 950). They left the core because they quoted costs before the
cost model existed; the core route now derives their numbers where it uses them, between
slides 19 and 53, and slide 3's speaker note points at the cards for a reader who wants
each question priced at once. Slides 75–76 are the rule book's bill, 22,500 against 163,
with the figure's numbers held back for a reveal and then unfolded term by term. Slides
77–85 are Table 1 in full, the buffer-fit alternative, the paper's CPU term (slide 79,
placed after the buffer-fit slide as reference material rather than a choice card),
every single-table path (ten priced, seven kept), every join plan (fourteen pair plans
and six triple plans), the journal's comparison of dynamic programming with three
heuristics, order equivalence classes, what 1979 did not have, and five of the notes'
thirteen review questions with all thirteen answered in the speaker note.

Title-only dividers mark the parts:

| Divider slide | Part | Content slides |
| --- | --- | --- |
| — | The job | 1–5 |
| 6 | From text to a tree | 7–10 |
| 11 | Strawman 2: fixed rules | 12–17 |
| 18 | Cost and statistics | 19–21 |
| 22 | Selectivity | 23–26 |
| — | Outline: one, two, three tables | 27 |
| 28 | One table: pick an access path | 29–34 |
| 35 | Two tables: join methods | 36–41 |
| 42 | Many tables: the order problem | 43–54 |
| — | Recap | 55 |
| 56 | Appendix | — |
| 57 | Nested queries | 58–59 |
| 60 | What held up, what did not | 61–66 |
| — | Appendix cards | 67–85 |

The locked number set is slides 2, 4 and 24: the query; the three tables (EMP 10,000
rows on 500 pages, stored in DNO order; DEPT 100 on 5, also in DNO order; JOB 50 on 2,
in JOB order; each in its own segment, so a scan of T costs `pages(T)`, 500, 5 and 2)
and their seven indexes with `distinct` and `index_pages` values, restated on slide 21;
and the four selectivity factors 1/50, 1/10, 1/100 and 1/50, plus 1/4 for the one-table
query. One tie belongs to the set: JOB's 2-page scan and its unique TITLE index both
cost 2 and both are unordered, so the search keeps the index and strikes the scan
(slides 51 and 80), and a JOB-first pair through the scan would cost the same 2 + 201 =
203, so no plan cost depends on which one is kept. Several conventions on top of them
are the lecture's own, not the paper's: all costs are page fetches, with the paper's CPU
term named in slide 19's note and explained only on appendix slide 79, because the paper
gives `W` no value; sorting Q rows costs `2 × ceil(Q / 20)` page fetches, because the
paper gives no sort-production formula at all, only a merge's inner over a sorted
temporary; strawman 2's rough counts leave out the index's own pages; and the FROM
order's 20,603 is run with lookups for the first pair. Any change to one statistic
cascades through dozens of slides, their speaker notes and most of the figures, so
change the statistics only deliberately and re-derive the appendix enumerations on
slides 80 and 81 afterwards; a change to JOB that breaks the tie also changes slide 51's
lattice and the notes of slides 51, 68 and 80. The `index_pages` values are assumptions
picked so no quoted cost needs rounding — 40 makes `1/4 × (40 + 10,000)` exactly 2,510,
50 makes `(50 + 500) / 100` exactly 5.5 and `(50 + 10,000) / 50` exactly 201 — and
slides 4 and 21 say on the slide that the sizes are ours, with their notes naming the
index sizes as assumptions. EMP is stored in DNO order, which forces the JOB and SAL
indexes to be non-clustered; slide 5 shows that before any cost appears, and it is what
makes slides 31–34 structural rather than contrived.

Every slide is meant to stand alone in the printed handout, with no lecturer present: a
reader must be able to see from the slide itself why its claim is true, and must never
meet a technical word the deck has not defined. No slide cites another slide by number
on screen; every cross-reference lives in the speaker notes and in this README. In the
core route that means each number
arrives with its arithmetic where it is first used: strawman 2's rough counts are
checkable on the card (100 rows at 20 to a read is 5 reads), slide 37 derives the
5.5-page probe on the same slide that uses it in 5 + 10 × 5.5 = 60, and slides 45 and
52 print their key totals as sums of terms the room has already seen. Slide 51 prints
its sums only in the panels of its click states, not on its handout page, which is the
question, and the 201 inside its 203 and 204 is first derived on appendix slide 70. In the
appendix it is why the sums are printed unfolded — slide 68 shows `5 + 10 × 5.5 + 100 +
3` rather than 163, so the 126-fold spread between join orders reads off the survivor
counts 10 and 10,000 — and why every lookup cost (5.5, 201, 2), every sort (100, 20,
1,000) and every saving is derivable from numbers printed on the slide or on an earlier
one. An unfolded sum is still only half an explanation, so slides 69 to 71 take the
winning one apart: what each term pays for and how many rows it leaves behind, what a
single lookup buys for its 5.5 pages, and why the last two terms depend on which pair
was built rather than on which table was read first. Slide 76 does the same for the
losing plan, because the figure on slide 75 labels its nodes with running totals, and a
reader can take the 20,500 inside 22,500 for a new cost: the three terms of 22,500, the
rows each leaves behind, and the fact that all 10,000 DEPT lookups are paid for while
only 1,000 of them find a Denver department. Its caption splits the gap between the two
plans into what each rule adds — 20,440 for the FROM order's first pair (20,500 − 60)
and 1,897 for looking JOB up instead of sorting and merging, together exactly 22,500 −
163 — and the notes add that rule 1 costs nothing extra here, because EMP has no
predicate for it to misuse.

The vocabulary half of the standard is: define a term where it is first used, in one
line, and name it only after the idea it names has been shown. *Page fetch* is defined
on slide 19, where it becomes the unit; slide 9, the first cost, counts disk page reads
and writes; clustered and non-clustered indexes are drawn on slide 5 before slide 21
defines *clustered* in a line; *query block* and *catalog* get a line on slide 7,
*pushdown* and *boolean factor* on slide 10, *lookup* on slide 15, *result_rows* on
slide 25, *segment scan* on slide 29, with *sargable* and *matching* defined aloud
there, *outer*, *inner* and *probe* on slide 36, *outer_rows* on slide 37, *merge join*
on slide 39, the idea of a *useful order* in plain words on slide 46, named in slide
47's pseudocode (the paper's *interesting order* stays in the notes), *composite*,
*left-deep* and *bushy* on slide 50, and *database retrieval* said aloud on slide 54.
Slide 19 leaves RSI calls and `W` to its note, which glosses them as rows passed up from
storage times a machine weight, sets them aside, and points at appendix slide 79, which
explains them on its figure. Strawman 2 says lookups, as the notes do; the join section
says nested loops and merge scan, links nested loops to the lookups in slide 37's title,
and introduces the merge scan on slide 39 by the notes' other name for it, merge join.
The deck says rows rather than tuples; the word survives only in speaker notes that
quote the paper. On the slides, *legal order* appears only in the appendix, where slide
67 defines it; the core route leaves the word to the speaker notes. The exchange
argument on slide 45 is "valid" rather than "legal". One collision is worth keeping in
mind when editing: the Leis benchmark is commonly called JOB, but JOB is also one of the
three tables in the running query, so the deck never uses that name; slide 61 says "113
queries on the real IMDB database" and slide 62 "the 113 IMDB queries".

The deck uses the same textbook style as the RocksDB lecture: serif titles, white pages,
thin grey rules, and red for the one choice or surprise under discussion. Body text uses
1.5× baseline spacing (36pt for 24pt type); separate bullets use 1.65× spacing (39.6pt).
Explicit Typst text edges make this independent of font metrics. Dense slides were
reflowed rather than set in smaller type. The full lecture, every reveal state included,
and the handout were rendered and reviewed page by page, the arithmetic was audited
slide by slide, and each slide a fix touched was re-rendered and checked again.
`queryopt-diagrams.typ` holds 27 editable figures and no imported images, 26 of them
CeTZ canvases and `tables-a` a plain Typst table. All of them appear in the deck; the
three that lost their slides, the RSI boundary, the old LOC/ZIP grid and
`interesting-order`, EMP's four paths with their verdicts, were removed, and
the two-panel heuristics figure was split into `no-cross-products` and `left-deep`. Ten
take a `stage:`, `mode:` or `step:` parameter. Three are called on consecutive slides
with identical coordinates, so the picture stays still while the annotation moves:
`algebra-tree` on slides 9–10, `dp-lattice` on 51–52 and
`subquery` on 58–59. `dp-prefix-irrelevance` and `rule-vs-cost` change stage inside one
slide's reveal, on slides 44 and 75, `dp-lattice` takes a `step:` inside each stage,
seven on slide 51 and three on slide 52, `stored-order-a`, `access-paths`,
`order-in-state` and `no-cross-products` take a `step:` for the reveals on slides 5, 29,
46 and 49,
`algebra-tree`'s `counts:` holds back the answer
for the first click on slide 9, and `merge-trace-b` is drawn once per state of
slide 40. Every reveal only adds to the picture except on slides 40 and 51: slide 40's
red pair moves down the two lists, greying the rows it has passed, and slide 51's red
outline and panel move from box to box and clear for the question. The last state of
each slide is the handout page, so slide 51's handout page shows the question, and
appendix slides 80 and 81 carry every price its panels explain. `clustered-scan`,
`nonclustered-scatter` and `buffer-rescue-g` share one private strip helper so their
geometry cannot drift apart. The suffixes on the five newest figure names (`tables-a`,
`stored-order-a`, `merge-trace-b`, `rss-rsi-c`, `buffer-rescue-g`) are left over from
the section-by-section rewrite and carry no meaning; `rss-rsi-c` now draws appendix
slide 79.

## Build

Requires Typst 0.15 or later (checked with 0.15.1). Imports pin Touying 0.7.4 and CeTZ
0.5.2. Typst downloads packages on the first build and caches them outside this
repository.

```sh
make -C teaching/db/26fa/slides queryopt
```

Or, from this directory:

```sh
typst compile DB26fa-QueryOpt.typ
typst compile --input handout=true DB26fa-QueryOpt.typ DB26fa-QueryOpt-handout.pdf
typst eval --in DB26fa-QueryOpt.typ --pretty 'query(<pdfpc-file>).first().value' > DB26fa-QueryOpt.pdfpc
```

For an explicit external package cache:

```sh
make -C teaching/db/26fa/slides queryopt TYPST_FLAGS='--package-cache-path /tmp/typst-packages'
```

`queryopt-theme.typ` defines the typography and layout, and adds two display helpers to
the shared set: `sql` for a SQL, pseudocode or relational-algebra block set off by a
left rule, and `formula` for one centred cost formula. Titles use STIX Two Text / Times
New Roman; body text uses Helvetica Neue, falling back to Arial and STIX Two Math for
the bowtie join glyph; code and costs use Menlo with the same two fallbacks. Typst
reports a font substitution for the bowtie glyph on machines without Arial or STIX Two
Math; on Linux, install STIX Two Text and STIX Two Math and set `sans-font` to an
installed font such as Liberation Sans. Changing fonts can change wrapping, so inspect
the regenerated PDF on another platform. Slide text, source references and speaker notes
are in `DB26fa-QueryOpt.typ`.

To preview the homepage, run from the repository root with a throwaway Jekyll
destination, loading the compatibility shim for newer Ruby:

```sh
bundle exec ruby -r ./_plugins/ruby4_compat.rb -S jekyll serve --destination /tmp/queryopt-site
```

Building these slides does not require Jekyll. Avoid regenerating the tracked `docs/`
tree unless publishing intentionally.
