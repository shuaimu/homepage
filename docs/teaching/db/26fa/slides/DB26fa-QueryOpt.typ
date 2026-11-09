// CSE 532, Fall 2026. November 2, 2026.
// typst compile DB26fa-QueryOpt.typ
// typst compile --input handout=true DB26fa-QueryOpt.typ DB26fa-QueryOpt-handout.pdf
// Statistics, page counts and all costs are illustrative for this lecture; the paper gives none.
#import "@preview/touying:0.7.4": *
#import "queryopt-theme.typ": *
#import "queryopt-diagrams.typ": *
#show: lecture-theme

// 1
#lecture-slide(source: [§1], notes: [1 minute. The paper that invented cost-based query optimization, by the five authors named, led by Pat Selinger. This lecture re-derives the optimizer rather than describing it: every mechanism arrives as the answer to a failure we have just watched. The whole hour runs on the paper's own query, its Figure 1, over one set of table sizes that are ours, so the arithmetic is reproducible with a calculator. Continuity from the storage lectures: Get, Put, scans and indexes, in Postgres, LSM trees and B-trees, were the menu, and today is about how the system orders from it. SQL says what rows you want, not how to get them; today we reinvent the System R optimizer piece by piece to choose the how. The companion reading is Leis et al., How Good Are Query Optimizers, Really?, VLDB 2015, which checks what held up after 36 years; it is the retrospective at the front of the appendix.])[Query Optimization][
  #v(32pt)
  CSE 532 · Database Systems\
  November 2, 2026
  #v(35pt)
  #text(size: 19pt, fill: muted)[Selinger, Astrahan, Chamberlin, Lorie, and Price\ _Access Path Selection in a Relational Database Management System_ · SIGMOD 1979]
]
// The paper's Figure 1 query, its WHERE columns prefixed by their tables, beside the three
// tables' columns. EMP has no local predicate, which the deck uses
// later (rule 2 breaks on it); the one-table query `SAL > 20000` is a separate example.
// 2
#lecture-slide(source: [§5, Figure 1], notes: [2 minutes. This is the paper's own running example, Figure 1, and the whole hour stays on it. One change from the paper: each column in the WHERE clause carries its table's name, JOB.TITLE where the paper writes TITLE, so every predicate shows which table it touches. The boxes on the right are the three tables' columns, as Figure 1 lists them; only the join columns DNO and JOB appear in two tables. Read it aloud as English, the way the paper captions it: retrieve the name, salary, job title and department name of employees who are clerks and work for departments in Denver. Three tables. Two local predicates, each on one table: TITLE = 'CLERK' on JOB and LOC = 'DENVER' on DEPT. Two join predicates, each tying two tables together: EMP.DNO = DEPT.DNO and EMP.JOB = JOB.JOB. Point out what is missing, because it matters later: nothing in the WHERE clause filters EMP, the biggest table. Stress that the query is declarative: it fixes the answer and says nothing about the method, not which table to read first, not which index, not which join algorithm. Choosing the how is the optimizer's job, and today we reinvent the System R optimizer piece by piece. The paper's Figure 1 shows a few rows of each table and no sizes; ours follow on slides 4 and 5.])[The Denver clerks query][
  // In a grid the sql block's own above/below spacing is dropped, so it is restored here.
  #v(14pt)
  #grid(columns: (auto, 1fr), column-gutter: 56pt, align: horizon,
    sql(size: 27pt)[```
SELECT NAME, TITLE, SAL, DNAME
FROM   EMP, DEPT, JOB
WHERE  JOB.TITLE = 'CLERK'
  AND  DEPT.LOC = 'DENVER'
  AND  EMP.DNO = DEPT.DNO
  AND  EMP.JOB = JOB.JOB
```],
    schema-a(),
  )
  #v(24pt)
  #small[Name, salary, job title and department of every clerk in a Denver department.]
  #takeaway[SQL says what rows you want. It never says how to get them.]
  #caption[Figure 1’s query, with each WHERE column’s table named. Two local predicates, two join predicates.]
]
// 3
#lecture-slide(source: [§1, §7], notes: [1 minute. The job, as four questions, and nothing answered yet. The user did not say which table to read first or in what order to join the three; whether to use an index, and which one; which join algorithm; and, a choice that comes with the join algorithm, whether to sort. Do not answer them now: the hour answers each in turn, with its arithmetic. Say only that every one of them can change the running time by orders of magnitude on this very query, more than a hundredfold for the join order alone, and that none of them changes the answer. Then the last line, the goal: not the best plan, because the paper is explicit that its estimates are rough, but a plan close to the best, found cheaply enough to run at compile time and amortize over many runs of a compiled program. For anyone who wants the numbers now, the appendix cards from slide 68 price each question.])[Four choices nobody made][
  #small[The query fixes which rows come back. It says nothing about how to get them.]
  #v(30pt)
  // Four short questions get more air between them than the recap's six statements.
  #block[
    #set enum(spacing: 1.2em)
    + *Order:* which table do we read first, and in what order do we join the rest?
    + *Access:* do we scan a whole table, or go through an index? Which one?
    + *Join:* how do we join two tables?
    + *Sorting:* do we sort rows along the way, or never?
  ]
  #v(26pt)
  #takeaway[Same rows every way. Which way is cheapest, and can we find it fast?]
]
// The two new slides of the notes' "The tables": the sizes everything is computed from,
// then what "stored in DNO order" and clustered / non-clustered mean.
// 4
#lecture-slide(source: [§5, Figure 1, extended], notes: [2 minutes. The three tables, with sizes. The paper's Figure 1 shows three or four rows of each and no sizes at all; these sizes are ours, picked so the trade-offs show, and every number in the hour is computed from this slide, so tell the class to photograph it. Walk it top to bottom. EMP: 10,000 employees at 20 rows to a page, so 500 pages, stored in DNO order, which the next slide explains. Three indexes on EMP. DNO: clustered, 100 department numbers with 100 employees each, 50 pages. JOB: non-clustered, 50 job codes with 200 employees each, 50 pages. SAL: non-clustered, salaries from 5,000 to 25,000, 40 pages. DEPT: 100 departments on 5 pages, also in DNO order; its DNO index is clustered and unique, one row per department number, 2 pages; its LOC index is non-clustered, 10 cities with 10 departments each, 2 pages. JOB: 50 job codes on 2 pages, in JOB order; the JOB index is clustered and unique, 1 page; the TITLE index is non-clustered and unique, one job code per title, 1 page. The index sizes are assumptions, not the paper's: SAL at 40 pages, DNO and JOB at 50. Then the answer, for scale: one job title in 50 is CLERK, so 10,000 × 1/50 = 200 clerks; one city in 10 is Denver, so about one clerk in 10 works in a Denver department, about 20 rows. Slide 21 restates this table in the catalog's terms.])[The three tables][
  #tables-a()
]
// 5
#lecture-slide(source: [§3: clustered indexes], notes: [2 minutes. Two clicks: the stored order with the clustered DNO index, then the non-clustered JOB index and the takeaway. What stored in DNO order means, because the rest of the hour leans on it. EMP's rows were inserted sorted by DNO and kept that way, so one department's 100 employees sit together on 5 pages, 20 to a page; the strip shows department 50's five pages side by side. Nothing forces this. It is a choice made when the table was set up, a sensible one if employees are usually fetched by department. Then the two kinds of index. Every index lists rows in its own column's order. If the table is stored in that same order, the index is clustered and the rows it finds sit together: EMP's DNO index, top of the figure, finds department 50's 100 rows on 5 adjacent pages. If the table is stored in some other order, the index is non-clustered and the rows it finds are scattered: EMP's JOB index, bottom, finds job code 5's 200 employees spread across the table, about one page each. EMP's SAL index is the same story. A table is stored in one order, so at most one of its indexes is clustered: that is the takeaway. Last, size: an index is small next to its table, EMP's are 40 to 50 pages against 500. And the answer to our query, for scale: 200 clerks, 1 in 10 of them in a Denver department, about 20 rows. The two lookups in the figure, DNO = 50 and JOB = 5, are where rule 1 starts on slide 13.])[Stored in DNO order][
  #small[EMP's rows were inserted sorted by DNO and kept that way: a choice made at setup.]
  #v(12pt)
  #alternatives[#stored-order-a(step: 0)][#stored-order-a()]
  #uncover("2-")[
    #takeaway[A table is stored in one order, so at most one index is clustered.]
    #caption[An index lists rows in its own column's order, and is small: 40 to 50 pages against EMP's 500.\
    The answer to our query: 200 clerks, 1 in 10 of them in a Denver department, about 20 rows.]
  ]
]

// Section divider before the parse-to-tree slides and the first strawman.
// 6
#lecture-slide(section: true, notes: [0 minutes. Follow the query from text to a stored plan, then run the tree exactly as written and price it.])[From text to a tree][]
// 7
#lecture-slide(source: [§2, §3], notes: [1 minute. Name the stages and what each needs. Parse: a query block is a SELECT list, a FROM list and a WHERE tree, and a predicate may contain another block, which is the nested-query case at the front of the appendix. Catalog lookup does double duty: it checks that the tables and columns exist and what their types are, and it fetches the four statistics about the tables and their indexes that the optimizer spends the rest of the lecture using. The algebra tree is what the optimizer works on, and the loop under it is rewrite. System R does a little: conjunctive normal form, and each boolean factor pushed down to the tables it names, applied as early as possible. Later systems do a lot: view expansion, subquery flattening and unnesting. System R keeps each subquery as its own block. Choosing the physical plan gives each node an operator with an algorithm: segment scan, index scan, nested loop, merge. Code generation: System R compiled the plan to machine code; Postgres interprets; Spanner, next class, does its own thing. The stored-and-rerun loop is the economic argument for spending real CPU here: a program's plan is optimized once and run many times, and that is the paper's own framing. This is System R's pipeline, not a description of any current release.])[Where the optimizer sits][
  #small[Parse into *query blocks* (one SELECT, FROM and WHERE each), check them against the *catalog*, rewrite the tree, choose a plan, generate code, store it.]
  #v(18pt)
  #pipeline-stages()
  #caption[System R compiled plans to machine code. Postgres interprets. Either way: optimize once, run many times.]
]
// 8
#lecture-slide(source: [Codd, CACM 13(6), 1970; §4: the WHERE tree], notes: [1 minute. Four clicks, one sign each: σ, π, ×, ⋈. The notation card, because the next slides are trees and these four signs carry all of them. Read any tree bottom-up: the leaves are stored tables, each node consumes the rows below it, and the root is the answer the user asked for. Say each sign aloud once, because students who have not seen the algebra will otherwise guess: sigma for select, which keeps rows; pi for project, which keeps columns; times for the cross product, every row paired with every row; bowtie for the join, which is a cross product with a selection on the join column, and that definition is the one worth repeating, because slide 10 is nothing but that equivalence read right to left. The predicate is written beside the sign, so sigma LOC = 'DENVER' is one node and not two. Then the sentence this lecture exists for, which is no longer printed on the slide, so say it: the four signs fix what the answer is and not one of them says how to compute it, which is why the same tree still leaves the join order, the access paths and the join methods open. The algebra is Codd 1970; Selinger's paper itself works in SQL query blocks and never draws an algebra tree (its Figures 3 to 6 are search trees of plans), so the trees on the next two slides are this lecture's, not the paper's.])[Four signs, read bottom-up][
  // One sign per click. Each state is the same table with one more row; the columns are fr
  // widths, so rows already shown keep their place, and nothing sits below the table to move.
  #let signs = (
    ([#text(size: 28pt)[σ]], [keep the rows where], [σ LOC = \'DENVER\' on DEPT: 10 rows of 100]),
    ([#text(size: 28pt)[π]], [keep only these columns], [π NAME, TITLE, SAL, DNAME, at the root]),
    ([#text(size: 28pt)[×]], [every row with every row], [EMP × DEPT: 10,000 × 100 = 1,000,000 rows]),
    ([#text(size: 28pt)[⋈]], [a × with a σ on the join column], [EMP #text(size: 1.3em, top-edge: 16.8pt, bottom-edge: -4.2pt)[⋈] DEPT on DNO: 10,000 of those]),
  )
  #alternatives(..range(1, 5).map(k => comparison(columns: (.35fr, 1.3fr, 1.9fr),
    [*Sign*], [*Reads as*], [*In our query*],
    ..signs.slice(0, k).flatten(),
  )))
]
// 9
#lecture-slide(source: [§4: the WHERE tree], notes: [2 minutes. Two clicks: the tree as parsed, then its price. This is the literal reading of FROM, WHERE and SELECT: cross product, then filter, then project. Read the tree bottom-up. The cross-product node is the literal meaning of a three-table FROM list, the selection carries all four boolean factors at once, and the projection drops the columns nobody asked for. Then the arithmetic out loud: 10,000 × 100 × 50 = 50,000,000 rows; at 20 rows per page that is 2,500,000 pages, written once and read back, so about 5,000,000 page fetches to return 20 rows from three tables that occupy 507 pages in total, 500 + 5 + 2. Say clearly that this tree is correct, which is exactly why correctness is never the optimizer's problem. For scale, the plan the optimizer will pick costs 163 page fetches, slide 53: about 31,000 times less. These are illustrative counts, not a measured result; the paper prices no such plan.])[Strawman 1: run the tree as parsed][
  #alternatives[#algebra-tree(stage: 1, counts: false)][#algebra-tree(stage: 1)]
  #uncover("2-")[
    #takeaway[50,000,000 rows built and thrown away to return 20.]
    #caption[50,000,000 rows at 20 per page is 2,500,000 pages, written once and read back:\ about 5,000,000 disk page reads and writes, by our arithmetic.]
  ]
]
// 10
#lecture-slide(source: [§4: boolean factors; §2], notes: [2 minutes. Compare with the previous slide: same leaves at the same coordinates, one structural change. The two local selections have moved down onto the tables whose columns they mention, TITLE = 'CLERK' onto JOB and LOC = 'DENVER' onto DEPT, and the two equality factors have been consumed by join nodes, which turns the cross product into joins. EMP gets no selection, because nothing in the query filters it: all 10,000 rows go up, and the dashed box marks the slot. The licence for all of it is the paper's own sentence, said aloud because it is not on the slide: every tuple returned to the user must satisfy every boolean factor, so each factor can be applied as early as you like. A boolean factor is one conjunct of the WHERE clause in conjunctive normal form, and it may itself be a tree headed by OR, so a factor is not the same thing as a simple comparison. Row counts on the edges: 10,000 EMP rows, 10 Denver departments, 1 clerk job code; the DNO join keeps 10,000 × 10 × 1/100 = 1,000 pairs; the JOB join keeps 1,000 × 1 × 1/50 = 20, the answer. Those fractions are selectivity factors, slide 24. System R's rewriting is small: conjunctive normal form, and each boolean factor applied as early as possible. View expansion, subquery flattening and much more came with later systems; System R keeps each subquery as its own block. Then the sting: rewriting removes the obviously stupid plans and does not tell you which of the remaining ones is good. This tree still leaves four legal join orders, four ways to read EMP and two join methods. Strawman 2 tries to choose among them with fixed rules, starting on slide 12.])[Pushdown turns × into ⋈][
  #small[*Pushdown* moves each filter onto the table it names; the AND-ed parts are *boolean factors*.]
  #v(12pt)
  #algebra-tree(stage: 2)
]

// Section divider before the rule book and the three inventions it motivates.
// 11
#lecture-slide(section: true, notes: [0 minutes. Try the obvious rule book: two rules, each right on plenty of queries. Watch each one win on a simple query and break on the next, with rough counts of reads, then derive the three things the optimizer has to invent.])[Strawman 2: fixed rules][]
// 12
#lecture-slide(source: [§4, §5], notes: [2 minutes. Strawman 1 died of a rewrite; this one replaces the search with a rule book, and it deserves a fair hearing, because each rule is right on plenty of queries, which is why rule books were the serious alternative in 1979. Read the two rules as a careful programmer would write them, and give each its excuse. An index exists precisely so that a query need not read the whole table. The FROM list is right there, it costs nothing to follow, and the person who wrote it presumably knows the data. Then the counting convention, said aloud because the slide does not print it, and the four rule cards that follow, slides 13 to 16, lean on it and none of them uses a formula. Rough counts, as in strawman 1, on the tables of slide 4. A disk read brings in a whole page, so a scan reads EMP's 10,000 rows in 500 reads, twenty rows each. Rows found through a clustered index sit together, so they arrive twenty to a read; rows found through a non-clustered index are scattered, so each costs about a read of its own. The index's own pages are left out, because they are a sliver next to the data, and exact page-fetch formulas wait for the access paths, slide 30. Each rule gets the same two cards: the rule on a query where it is right, then on one where it breaks. Rough counts on this lecture's illustrative sizes, not measurements.])[Two rules that sound right][
  #small[Replace the search with a rule book. Each rule is right on plenty of queries.]
  #v(14pt)
  #comparison(columns: (.2fr, 2.6fr, 1.6fr),
    [], [*Rule*], [*Why it sounds right*],
    [1], [Always use an index if one exists], [an index skips pages],
    [2], [Always join in FROM order], [it needs no search],
  )
]
// Each rule gets two cards: a simple query where it is right, then one where it breaks.
// None is the running query, and every count is a rough count of reads, not a formula.
// 13
#lecture-slide(source: [§3: clustered index; §4, Table 2], notes: [1 minute. Two clicks: the query, then the table. The good case for rule 1, and on purpose not our query, which never filters EMP: one-table queries on EMP of the kind an application issues all day. DNO = 50 keeps one department. EMP is stored in DNO order, so its DNO index is the clustered one, and that department's 100 employees sit together on 5 pages at twenty to a page: about 5 reads, against 500 for the scan, a hundred times fewer. JOB = 5 keeps one job code, 200 rows, one in fifty. EMP is not stored in JOB order, so those 200 rows are scattered across the table and each costs about a read of its own: about 200 reads. That still beats the scan's 500, and it is the point of the second row: scattered rows win too, if they are few. This is the average case the rule was written for, and on it the rule is right. The index's own pages, a page or so per query here, are left out; the access-path section adds them back, slides 31 and 32. Rough counts, not measurements.])[Rule 1: where the index wins][
  #sql(size: 24pt)[```
SELECT NAME FROM EMP WHERE DNO = 50
SELECT NAME FROM EMP WHERE JOB = 5
```]
  #pause
  #v(4pt)
  #comparison(columns: (1.3fr, 2.1fr, 1.25fr, .8fr),
    [*WHERE*], [*Rows the index finds*], [*Index*], [*Scan*],
    [DNO = 50], [100, together: clustered], [*about 5*], [500],
    [JOB = 5], [200, scattered: non-clustered], [*about 200*], [500],
  )
  #takeaway[Few rows, or rows that sit together: the index wins.]
  #caption[One department's 100 employees sit on 5 pages, 20 to a read. One job's 200 employees are scattered, about a read each, and 200 reads still beat 500.]
]
// 14
#lecture-slide(source: [§4, Table 2], notes: [1 minute. Two clicks: the query, then the table. The same rule on one more one-table query, and it breaks. SAL runs from 5,000 to 25,000, and SAL > 20000 is the top quarter of that range, so with salaries spread evenly it keeps a quarter of EMP, 2,500 rows; the selectivity section turns that into Table 1’s range formula, slide 23. EMP is stored in DNO order, so the SAL index is non-clustered, and the 2,500 rows it finds are scattered across the whole table: about 2,500 reads. The scan reads every page once and tests SAL on the way past: 500 reads. The index loses five to one. The reason is a unit mismatch, and it is the sentence to leave on the board: the index pays per row it finds, the scan pays per page. A non-clustered index wins only while the rows it finds are fewer than the table's pages, here about 500 rows, one in twenty of EMP; past that, scan. Slide 34 derives that crossing exactly. The rule would be right here too if EMP were stored in SAL order, but a table is stored in one order, and EMP's is DNO. Rough counts, not measurements.])[Rule 1: where it breaks][
  #sql(size: 24pt)[```
SELECT NAME FROM EMP WHERE SAL > 20000
```]
  #pause
  #v(4pt)
  #comparison(columns: (1.15fr, 3fr, 1.05fr),
    [*Path*], [*What it reads*], [*Reads*],
    [SAL index], [a quarter of EMP, 2,500 rows scattered across the table: a read each], [about 2,500],
    [Scan], [every page once, testing SAL on the way past], [*500*],
  )
  #takeaway[The index pays per row it finds, the scan per page.]
  #caption[The scan wins 5×. Past about 500 scattered rows, as many as EMP has pages, scan.]
]
// 15
#lecture-slide(source: [§5: computing join order], notes: [1 minute. Two clicks: the query, then the table. The second rule, and the one with the best excuse: the FROM list is right there, it costs nothing to follow, and people tend to name first the table they are filtering. This query is written that way: DEPT first, filtered to Denver. A join done this way is a chain of lookups: read one table, and for each of its rows that survives its filter, find the matching rows in the other. DEPT first: LOC = 'DENVER' keeps 10 of its 100 rows, so 10 lookups into EMP, each finding one department's employees. EMP first: this query does not filter EMP, so all 10,000 rows survive and each needs a lookup into DEPT to find its department, 10,000 lookups. The LOC test can only happen once the DEPT row is in hand, so all 10,000 are paid and only 1,000 of them find a Denver department. Ten against ten thousand. The order the user wrote is the best one, and it took no search to find; that is the case rule 2 was written for. These are counts of lookups, not page fetches: what one lookup costs arrives with nested loops, slide 37.])[Rule 2: where FROM order is right][
  #small[People tend to name first the table they are filtering. This query does.]
  #sql(size: 24pt)[```
SELECT DNAME, NAME
FROM   DEPT, EMP
WHERE  DEPT.LOC = 'DENVER' AND EMP.DNO = DEPT.DNO
```]
  #pause
  #comparison(columns: (1.35fr, 1.25fr, 1.9fr),
    [*Start from*], [*It keeps*], [*Then*],
    [DEPT, as written], [10 Denver rows], [*10 lookups* into EMP],
    [EMP], [all 10,000], [10,000 lookups into DEPT],
  )
  #takeaway[The order the user wrote is the best one, found with no search.]
  #caption[A *lookup* takes one row of the first table and finds its matches in the second.]
]
// 16
#lecture-slide(source: [§5: computing join order], notes: [1 minute. Two clicks: the query, then the table. The same rule, broken by a query written the same way. EMP is named first and EMP is filtered, so the user did exactly what the rule expects. But SAL > 20000 keeps a quarter of EMP, 2,500 rows, the same quarter as slide 14, and 2,500 surviving rows means 2,500 lookups into DEPT. Start from DEPT instead: this query does not filter DEPT, so all 100 rows survive, and 100 lookups into EMP find each department's employees, testing SAL on the way. A hundred against 2,500, and the order the user wrote is the dearer one. Being filtered is not the point; keeping the fewest rows is, and the FROM list cannot know which table that is, because it depends on the predicates and on the data, not on the sentence. Then point at our own query: FROM EMP, DEPT, JOB starts with EMP, the one table its WHERE clause does not filter at all, so rule 2 sends all 10,000 EMP rows into the first join. Two honest caveats for the note. Lookups are not all equally dear: a lookup into EMP fetches a whole department, a lookup into DEPT one row. And fewest rows first is itself only a rule: on our query it would start from JOB, which keeps a single row, and that is not the best order either, slide 52. The cost model weighs both, slide 41. Counts of lookups, not page fetches.])[Rule 2: where it breaks][
  #sql(size: 24pt)[```
SELECT DNAME, NAME
FROM   EMP, DEPT
WHERE  EMP.SAL > 20000 AND EMP.DNO = DEPT.DNO
```]
  #pause
  #comparison(columns: (1.35fr, 1.25fr, 1.9fr),
    [*Start from*], [*It keeps*], [*Then*],
    [EMP, as written], [2,500, a quarter], [2,500 lookups into DEPT],
    [DEPT], [all 100], [*100 lookups* into EMP],
  )
  #takeaway[Start from the table that keeps the fewest rows.]
  #caption[The FROM list does not know which. The running query says FROM EMP, DEPT, JOB: it starts with EMP,\
  the one table its WHERE clause does not filter at all.]
]
// 17
#lecture-slide(source: [§1, §7], notes: [1 minute. The hinge of the lecture. One rule survives both strawmen: apply filters as early as possible. That is strawman 1’s fix, pushdown, and the optimizer keeps it, because every answer row satisfies every boolean factor, so applying one early is never wrong. Strawman 2’s two rules were each right on one query and wrong on the next, and every time the deciding fact was in the data: how many rows a filter keeps, and whether the rows it keeps sit together. So stop writing rules and price the candidates: estimate the cost of each and pick the cheapest. That takes three inventions: the next part builds the first two, cost and statistics, and the search arrives once the join methods are priced, in the many-tables part. Note that cost-based optimization was not obvious in 1979; the live alternative was a better rule book. The paper's own contribution list names the expanded use of statistics, putting CPU into the cost formula (a term this lecture leaves out, slide 19), and the method of determining join order. For anyone who wants the rule book's bill on the running query, it is in the appendix, slide 75, priced once the cost model exists: the same twenty rows at 138 times the cost of the plan the optimizer picks.])[Measure, then choose][
  #small[Applying filters early is the rule that survives: strawman 1’s fix.\ Strawman 2’s rules each held on one query and broke on the next: only the data says which.]
  #v(22pt)
  + *A cost measure:* one number per plan, in units we can count.
  + *Statistics:* enough about the data to predict that number.
  + *A search:* through the candidates, without enumerating them all.
  #takeaway[Estimate the cost of each candidate. Pick the cheapest.]
]

// Section divider before the cost measure and the catalog statistics.
// 18
#lecture-slide(section: true, notes: [0 minutes. Cost and statistics. First the one number being minimized, page fetches, and why rows still matter to it. Then the four catalog numbers it is computed from, and our three tables in those terms.])[Cost and statistics][]
// The cost measure is page fetches alone, argued in general terms. The paper's CPU term is
// only the approximate sign here and a paragraph of the note; the full story is appendix slide 79.
// 19
#lecture-slide(source: [§4: the cost formula], notes: [2 minutes. One number per plan, so that plans can be compared, and the number is a count of page fetches. Say why in general terms before any formula. Disk is slow: reading one page from disk takes milliseconds, while the CPU work on the rows in it takes microseconds, so in 1979, and still today for data on disk, the disk dominates. And the disk moves whole pages: fetching one row costs as much as fetching the page it sits on. So count the pages a plan reads, and you have its cost closely enough to rank plans. A page fetch is one page read from disk, a data page or an index page: the same unit strawman 2 counted as reads, now made exact. Rows still matter, because they decide how many pages a plan touches; how many, for a scan and for each kind of index, is the access-path section, slides 29 to 32, with the exact formulas on slide 30. The approximate sign is honest: the paper's own formula has a second, CPU term, COST = PAGE FETCHES + W × RSI CALLS. RSI calls count the rows the storage layer passes up to the rest of the plan, and W is a machine-specific weight that turns them into page-equivalents. The paper gives W no value anywhere, and on one table the term is the same for every path anyway, because they all return the same rows. So we count pages only, and every cost for the rest of the hour is page fetches. The optional appendix slide 79 tells the rest. Then name what this objective ignores, since every later optimizer widens it: it is single-user total resource use, not latency; no parallelism, no memory pressure, no network. Spanner, next class, adds network and shard fan-out.])[What the optimizer minimizes][
  #formula[COST ≈ PAGE FETCHES]
  #small[A *page fetch* is one page read from disk, a data page or an index page.]
  #v(30pt)
  // Three short reasons, spaced like slide 3's questions.
  #block[
    #set list(spacing: 1.2em)
    - *Disk is slow:* a page read takes far longer than the CPU work on its rows.
    - *Disk moves whole pages:* one row costs as much as the page it sits on.
    - *So count pages:* the plan that reads the fewest pages is the cheapest.
  ]
]
// 20
#lecture-slide(source: [§4: the statistics kept], notes: [2 minutes. Point at the picture, not the words. Two numbers per table: rows(T) counts the lines on T's pages, the rows of T, and pages(T) counts the pages that hold them. A scan reads every one of those pages, so a scan of T costs pages(T). Two numbers per index: index_pages(I) counts the index's own pages, and distinct(I) counts the distinct keys at its leaf level. Stress that distinct is kept per index, not per column: for an index on one column we write distinct(col), and an un-indexed column has no distinct-value count at all, which is exactly where the magic constants of Table 1 come from, slide 23. There is no histogram and no sample anywhere in 1979. The paper's names are on no slide; give them only to anyone reading the paper: NCARD is rows, TCARD is pages, ICARD is distinct, NINDX is index_pages, and one that comes later, QCARD is result_rows. CARD is short for cardinality, "how many"; the letters before it are not consistent, the N in NCARD counts rows and the N in NINDX counts pages, which is why this deck uses plain names. The paper keeps one more number, P, which we drop: in System R several tables can be stored together in one disk segment, the area of disk a table lives in, and a scan then reads the whole segment, the other tables' pages included. Here every table has its own segment, so a scan reads exactly pages(T). Then the refresh. The numbers are set when a table is loaded or an index created, then refreshed by a manual UPDATE STATISTICS, not on every write. The paper's three reasons: the extra database operations, the locking bottleneck at the system catalogs, and the serialization of every access that modifies the relation; in one phrase, the catalog would become a hot lock. Postgres ANALYZE is the same decision for the same reasons. The consequence is that every cost in the next forty minutes is computed from numbers that may be stale, and the optimizer cannot tell.])[Four numbers in the catalog][
  #statistics-catalog()
  #v(22pt)
  #caption[Refreshed by a manual UPDATE STATISTICS, not on each write (a hot lock); Postgres ANALYZE likewise.]
]
// 21
#lecture-slide(source: [§4: statistics; Figure 1, extended], notes: [2 minutes. These are the tables from slide 4, now in the catalog's terms. Tell the class to photograph this slide: every cost for the next forty minutes comes off it, and with a calculator they can reproduce the whole deck. A scan reads pages(T): 500 pages for EMP, 5 for DEPT, 2 for JOB. Two structural facts to stress. First, EMP is stored in DNO order, so its DNO index is the clustered one, and the JOB and SAL indexes cannot also be clustered, because a table has one physical order; that constraint is what makes slides 31 to 34 inevitable rather than contrived. Second, two conventions are the lecture's, not the paper's: every cost is page fetches, slide 19; and the sort estimate in the small line is one pass out and one pass back at 20 rows per page, 2 × ceil(Q / 20), because the paper gives no formula for producing a sort at all, only the cost of a merge reading a sorted inner, which is read once in total. The index sizes are assumed too: SAL 40 pages, DNO and JOB 50. Illustrative statistics, not measurements: the paper's Figure 1 gives three toy tables with three or four rows each, and no row counts, page counts or costs.])[Our running statistics][
  #comparison(columns: (.7fr, .9fr, .9fr, 2.4fr),
    [*T*], [*rows*], [*pages*], [*Indexes (distinct, index_pages)*],
    [EMP], [10,000], [500], [*DNO clustered* (100, 50)\ JOB (50, 50) · SAL (2,000, 40)],
    [DEPT], [100], [5], [*DNO clustered unique* (100, 2)\ LOC (10, 2)],
    [JOB], [50], [2], [*JOB clustered unique* (50, 1)\ TITLE unique (50, 1)],
  )
  #v(18pt)
  #small[EMP: *20 rows per page* · SAL keys 5,000 to 25,000 · sorting Q rows: 2 × ceil(Q / 20)]
  #v(16pt)
  #small[*Clustered* = rows stored in that index's key order · *unique* = at most one row per key]
]

// Section divider before Table 1 and the assumptions inside it.
// 22
#lecture-slide(section: true, notes: [0 minutes. Turn each boolean factor into a number, multiply, and then read the assumptions hiding inside the multiplication.])[Selectivity][]
// 23
#lecture-slide(source: [§4, Table 1], notes: [2 minutes. F is "the expected fraction of tuples which will satisfy the predicate", the paper's words, and its own hedge is "very roughly". Read the table as a design under pressure, not a lookup table: every entry is either a statistic the catalog has or a constant. Two things the abridgements usually drop. First, distinct is counted per index, not per column: an un-indexed column has no distinct count at all, so column1 = column2 needs two fallbacks, one index gives 1 / distinct on that side and no index gives 1/10. Second, the condition on column > value has two halves, the column must be arithmetic and the value must be known at access-path selection time; the second half matters precisely in System R's main use case, because a host variable in a compiled program is not known when the plan is chosen, so the 1/3 guess is used instead of interpolation. Then the paper's own ordering argument for the constants: 1/10 for an un-indexed equality is the most selective guess, 1/4 for BETWEEN is between the default selectivity factors for an equal predicate and a range predicate, 1/3 for a range has no significance to this number beyond being less selective than 1/10, and all sit under 1/2 because few queries use predicates that are satisfied by more than half the tuples. Quote the candour; it is the lesson. The caption carries the AND row, F1 × F2, because the next slides lean on it: the factors of independent predicates multiply. OR, F1 + F2 − F1 × F2, and NOT, 1 − F, are one line each on appendix slide 77.])[Table 1: a factor per boolean factor][
  #comparison(columns: (1.15fr, 1.85fr),
    [*Predicate*], [*F, the fraction of rows that pass*],
    [`column = value`], [1 / distinct(column), else *1/10*],
    [`column1 = column2`], [1 / max(distinct1, distinct2), else *1/10*],
    [`column > value`], [(high − value) / (high − low), else *1/3*],
    [`column BETWEEN a AND b`], [(b − a) / (high − low), else *1/4*],
    [`column IN (list)`], [n × F(column = value), capped at 1/2],
  )
  #caption[Bold: System R’s guesses when there is no index, assuming a missing index means a small table.\ _high_, _low_: the index’s largest and smallest key. AND: F1 × F2.]
]
// 24
#lecture-slide(source: [§4, Table 1], notes: [2 minutes. Every row count of the running query on later slides is a partial product of these four factors. Two local factors and two join factors, and nothing on EMP: the paper's query never filters EMP, so all 10,000 of its rows reach the joins, and there is no EMP row in the table. The two equality rows read straight off the catalog's distinct counts on slide 21: TITLE has 50 distinct values and LOC has 10, so 1 job code of 50 and 10 departments of 100. The max rule for the two join predicates assumes each key value in the index with fewer distinct values has a matching value in the other index; here both sides have the same count, 100 departments and 50 job codes. Keep the survivor column in view; it is the input to every join cost in the second half. Then, aloud because the slide no longer prints it, one more factor, and say clearly that it is a different query: rule 1’s one-table example, SELECT NAME FROM EMP WHERE SAL > 20000 (slide 14), which the access-path section prices with formulas. Do its interpolation on the board, (25,000 − 20,000) / (25,000 − 5,000) = 1/4, and point out that this row and the BETWEEN row are the only rows of Table 1 that look at actual key values: two numbers, a high key and a low key, with a straight line between them, which is the closest thing in 1979 to a histogram. distinct(SAL) is 2,000 and plays no part in this factor at all. Illustrative statistics, not measurements.])[Our four selectivity factors][
  #comparison(columns: (1.35fr, 1.6fr, .45fr, .9fr),
    [*Boolean factor*], [*Table 1 row used*], [*F*], [*Survivors*],
    [`TITLE = 'CLERK'`], [`1 / distinct(TITLE) = 1/50`], [`1/50`], [1 of 50],
    [`LOC = 'DENVER'`], [`1 / distinct(LOC) = 1/10`], [`1/10`], [10 of 100],
    [`EMP.DNO = DEPT.DNO`], [`1 / max(100, 100)`], [`1/100`], [—],
    [`EMP.JOB = JOB.JOB`], [`1 / max(50, 50)`], [`1/50`], [—],
  )
]
// 25
#lecture-slide(source: [§4: query cardinality], notes: [1 minute. One bar at a time, using the factors just derived, local factors first: 50 × 10 × 100 × 50 = 2,500,000, and 50,000,000 / 2,500,000 = 20. Twenty rows is the answer size; remember it, because the plan on slide 53 has to produce exactly it. Give the concrete chain as well, because it makes the number real: 10,000 employees, 200 of them clerks, one job code in 50, and 1 in 10 of those in a Denver department: 20, the same 20 that slide 5 promised. Point out the order of the bars: the two local factors first, the filters that touch one table each, which a scan can test as it reads (search arguments, slide 29), then the two join factors. The composites the join section needs, 1,000 for EMP and DEPT and 200 for EMP and JOB, are the same kind of product over two tables rather than three: 10,000 × 10 × 1/100 = 1,000 and 10,000 × 1 × 1/50 = 200. Illustrative counts, not measurements.])[Fifty million rows become twenty][
  #small[result\_rows = the block's answer size: the three tables' row counts times every factor's F.]
  #v(14pt)
  #selectivity-funnel()
  #takeaway[result\_rows = 50,000,000 / 2,500,000 = 20 rows.]
  #caption[Local factors first, then the two join factors. Bars on a log scale.]
]
// 26
#lecture-slide(source: [§4, Table 1: column = value and p1 AND p2], notes: [2 minutes. Two clicks: the question over four DEPT rows, then the answer. Independence gives 1/100 where the truth is 1/10, a tenfold underestimate, and four rows of DEPT show why. Three assumptions, named aloud because the slide does not list them, in the paper's own words: an even distribution of tuples among the index key values; note that this assumes that column values are independent; and a lack of statistics implies that the relation is small. The table carries the second. Read the four rows: every Denver department has an 802 ZIP, and Boulder, next door, has 803, so the ZIP filter keeps every row the LOC filter kept. Multiplying the two factors divides by ten twice where reality divides once: 100 × 1/10 × 1/10 = 1 department predicted, 10 in the table. Positively correlated predicates, which is what real queries carry because they are written with domain knowledge, underestimate. For uniformity, say what 1 / distinct cannot know: distinct is a single count of keys with no shape attached, so the same count is consistent with a flat salary distribution and with a lumpy one, and nothing in the catalog distinguishes them. The magic constants are the third assumption: with no index to consult, 1/10, 1/3 and 1/4 are guesses. Histograms are the eventual answer and they are not in this paper. Tell the room to hold this slide: this is the piece that aged worst, and appendix slide 62 shows how little of it changed in thirty-six years. DNO 50 to 52 and their cities are the paper's Figure 1; DNO 57 and every ZIP are illustrative.])[Read the assumptions][
  #small[F(`LOC = 'DENVER'`) = 1/10 and F(`ZIP LIKE '802%'`) = 1/10. Multiply them?]
  #v(22pt)
  #columns(widths: (1.05fr, 1fr))[
    #comparison(columns: (.7fr, 1.3fr, 1.1fr),
      [*DNO*], [*LOC*], [*ZIP*],
      [50], [DENVER], [#text(fill: red)[802]02],
      [51], [BOULDER], [80301],
      [52], [DENVER], [#text(fill: red)[802]16],
      [57], [DENVER], [#text(fill: red)[802]37],
    )
  ][
    #small[Four of DEPT’s 100 rows.\ How many of the 100 pass both filters?]
    #v(22pt)
    #uncover("2-")[
      Independence: *1* \
      #text(size: 20pt, fill: muted)[100 × 1/10 × 1/10]
      #v(18pt)
      The data: *10* \
      #text(size: 20pt, fill: muted)[every Denver department]
    ]
  ]
]
// An outline before the three parts that build the optimizer, one table at a time.
// 27
#lecture-slide(notes: [1 minute. A map of what is left, before the first of the three parts. We can now price a plan: page fetches, from four catalog numbers and a selectivity factor per predicate. What remains is choosing, and the hour builds it up one table at a time. One table: the cheapest way to read it, a scan or one of its indexes. Two tables: the cheapest way to join a pair, by lookups or by walking both in order. Three tables, our query, and more: the cheapest order to join them in, without trying every order. Each part reuses the one before it: the join prices the ways to read each table, and the search prices joins. Do not answer any of the three now.])[One table, two tables, three][
  #small[We can price a plan. Now choose one, building up a table at a time.]
  #v(30pt)
  // Three short questions, spaced like slide 3's.
  #block[
    #set enum(spacing: 1.2em)
    + *One table:* what is the cheapest way to read it, a scan or an index?
    + *Two tables:* what is the cheapest way to join them?
    + *Three tables or more:* in what order should we join them?
  ]
]

// Section divider before the single-table access-path slides, the lecture's first hard turn.
// 28
#lecture-slide(section: true, notes: [0 minutes. Price one table on its own, now with Table 2’s formulas. This part contains the lecture's first hard turn, which strawman 2 showed in rough counts on slide 14: the case where the obvious index loses to a full scan. Until slide 34 the example is that one-table query, SELECT NAME FROM EMP WHERE SAL > 20000; the running query comes back with the joins, slide 36.])[One table: pick an access path][]
// 29
#lecture-slide(source: [§3: scans and search arguments; §4: matching index], notes: [2 minutes. Three clicks: the page strip alone, then the segment scan, then the index scan. Say first which query is on the screen: not the running query, whose EMP has no predicate at all, but rule 1’s one-table query, SELECT NAME FROM EMP WHERE SAL > 20000, which stays the example through slide 34. Two panels, one shared page strip. A segment scan, the paper's name for a full table scan, sweeps every page of the table once and produces no order. An index scan walks the leaf level in key order, optionally between a start key and a stop key, and produces rows in that order; remember that for slide 46. Then the term the rest of the lecture leans on, said aloud because it is not on the slide: a filter of the form column op value is sargable, a search argument. Both scans test it as they read, so a failing row is dropped on the spot at no extra page cost: the scan reads the same pages whether the row passes or not. The running query has one on each of DEPT and JOB: a scan of DEPT reads its 5 pages, tests LOC = 'DENVER' on all 100 rows, and keeps 10, for 5 page fetches. A comparison of two columns of the same table is not sargable; it is tested only after the row has been read. That is predicate pushdown, in 1979: reject rows where they are read, as early and as cheaply as possible. An index whose key starts with the column can do more than test the filter: it can use it to start and stop its range. Here SAL > 20000 becomes a start key of 20,000 and no stop key: the scan begins at the first entry above 20,000 and runs to the end of the index. A matching predicate narrows the index range and the number of rows fetched, which is why F multiplies the whole bracket in Table 2 rather than one term of it. Define a matching index here, in the paper's words: a set of predicates matches an index access path when the predicates are sargable and the columns they mention are an initial substring of the index key. The paper's own example is a NAME, LOCATION index matching NAME = SMITH AND LOCATION = SAN JOSE; LOCATION = SAN JOSE alone matches nothing, because it skips the first key column and the San Jose entries are scattered through the index. A non-matching predicate can still ride along as a search argument; it just does not narrow the scan.])[Two ways to read a table][
  #small[Not the running query: rule 1’s `SAL > 20000` on EMP, for this whole section.]
  #v(52pt)
  #alternatives(..range(3).map(s => access-paths(step: s)))
]
// 30
#lecture-slide(source: [§4, Table 2], notes: [2 minutes. Six situations and eight formulas: both non-clustered rows have a second, buffer-fit form, pages in place of rows, which the caption mentions and appendix slide 78 draws. Read row one as the degenerate case: a unique index on an equality returns at most one row, so one index page plus one data page, and no statistic is needed at all; JOB's unique TITLE index is that row, 1 + 1 = 2. Rows four and five are the full index scan, where no boolean factor matches, so the F multiplier disappears and the path reads the whole index and the whole table. Those two rows are usually dropped from abridgements and they are load-bearing here, because in the running query EMP has no predicate at all, so every one of EMP's index paths matches nothing: its DNO index reads 50 + 500 = 550 and its JOB index 50 + 10,000 = 10,050, appendix slide 80. The last row is the segment scan, every page of the table once: pages, 500 for EMP. Then set up the next three slides. Ask the room to stare at rows two and three, which are character-for-character identical except for pages against rows. For EMP that is 500 against 10,000, a factor of twenty hiding in one word. Strawman 2 said the same thing in rough counts, 20 rows to a read against about a read per row (slides 13 and 14); the next two slides draw it.])[Table 2: six situations, eight formulas][
  #comparison(columns: (1.25fr, 1.75fr),
    [*Situation*], [*Cost in pages*],
    [Unique index, equality], [`1 + 1`],
    [Clustered, matching], [`F × (index_pages + pages)`],
    [Non-clustered, matching], [`F × (index_pages + rows)`],
    [Clustered, matching nothing], [`index_pages + pages`],
    [Non-clustered, matching nothing], [`index_pages + rows`],
    [Segment scan], [`pages`],
  )
  #caption[*Clustered* = the table is stored in that index's key order, so a table has at most one.\ The non-clustered rows have a second form, _pages_ for _rows_, if the pages fit in the buffer.]
]
// Slides 31 and 32 are a matched pair: identical geometry,
// one changed arrow pattern. Memorise the geometry on the first; the contrast does the teaching.
// 31
#lecture-slide(source: [§3: clustered index; §4, Table 2], notes: [1 minute. The first of a matched pair: tell the class the next slide is this same picture with exactly one thing changed, so they should memorise the geometry now. Still the one-table query, SAL > 20000. The index leaves are in key order and the data pages are in the same order, so the qualifying range is a contiguous run of pages and each page is fetched once no matter how many qualifying rows sit on it. The paper's definition is worth quoting: for a clustered index, not only each index page but also each data page containing a tuple from that relation will be touched only once in a scan on that index. Table 2’s clustered-matching row is that sentence as arithmetic: F × (index_pages + pages) = one quarter of (40 + 500) = 135, which is 10 index pages and 125 data pages. Be explicit that this panel is a counterfactual, because EMP is stored in DNO order, not SAL order, and that is the next slide's point. Illustrative layout, not a measured trace.])[Clustered: one fetch per page][
  #clustered-scan()
  #takeaway[Were it clustered: 125 consecutive data pages + 10 index pages = 135.]
  #caption[EMP's rows sit in DNO order and only one index per table can be clustered,\ so this panel is a counterfactual. Layout: 20 rows per page, ten of 500 drawn.]
]
// 32
#lecture-slide(source: [§3; §4, Table 2 and the buffer-pool paragraph], notes: [2 minutes. The matched partner, and nothing has moved: the same leaf strip, the same page strip, the same 2,500 qualifying rows. The arrows changed. The index is ordered by SAL while the pages are ordered by DNO, so consecutive index entries point at unrelated pages, and the page highlighted in the figure is fetched five separate times. The paper states the assumption behind charging for every one of those: for non-clustered indexes it is assumed that for those relations not fitting in the buffer, the relation is sufficiently large with respect to the buffer size that a page fetch is required for every tuple retrieval. That assumption, not the B-tree, is what turns pages into rows in the formula: F × (index_pages + rows) = one quarter of (40 + 10,000) = 2,510. This is strawman 2’s about a read per row, slides 13 and 14, with a formula under it: the 2,500 reads it estimated, plus the index's own 10 pages. Then the structural point, which is the whole reason this example works: EMP is stored in DNO order, a table has at most one physical order, so the SAL index has to be the non-clustered one. This is forced, not unlucky. Illustrative page numbers, not a measured trace.])[Non-clustered: one fetch per row][
  #nonclustered-scatter()
  #takeaway[The same 2,500 rows, 2,500 scattered page visits: one fetch per row.]
  #caption[In the formula, _pages_ became _rows_: strawman 2’s "about a read per row".\ Table 2 assumes EMP is far bigger than the buffer, so each visit to page 4 is a fresh fetch.]
]
// 33
#lecture-slide(source: [§4, Table 2], notes: [2 minutes. The slide the lecture turns on, and the one to slow down for. Three bars, three Table 2 rows, one predicate of the one-table query, the same 2,500 rows returned by every path. The non-clustered index at 2,510 is what rule 1, always use an index if one exists, picks; the segment scan at 500 wins by 5.02 times; the same index, had it been clustered, would have cost 135 and won by 3.7 times. Strawman 2 reached the same verdict from rough counts, about 2,500 reads against 500 (slide 14); now Table 2 stands under it. Every path tests SAL > 20000 as a search argument, so every path returns the same 2,500 rows; what differs is how many pages each touches to find them, and pages are all the cost counts (slide 19). Say it in one line, since the slide no longer prints it: the obvious index loses to a plain scan by 5×, because the scan pays per page, the non-clustered index per row, the clustered one per page of matching rows. Answer the review question directly: the two statistics that tell you the index is wrong are pages and rows. EMP's other two paths for this query, the DNO and JOB indexes matching nothing at 550 and 10,050, are on appendix slide 72. The paper gives no worked single-table cost arithmetic anywhere; its Figures 2 to 4 are symbolic and prune paths by assumption.])[The same predicate, priced three ways][
  #small[Rule 1’s one-table query: SAL > 20000, F = 1/4, 2,500 rows out. Three Table 2 rows: the scan, EMP's real SAL index, and the clustered one it cannot have.]
  #v(28pt)
  #access-path-costs()
]
// 34
#lecture-slide(source: [§4, Table 2], notes: [2 minutes. Generalise the previous slide into something reusable, still on the one-table query. The index line passes through the origin with a slope of about one fetch per qualifying row, 1.004 to be exact; at 100 rows it costs 100.4. The scan line is flat at 500. They cross where F × (index_pages + rows) = pages, which is F = 500 / 10,040, about five per cent, roughly 498 rows, just under the 500-page count because the index's own 40 pages tip it. Give the class the sentence to write down: the index loses once the answer has more rows than the table has pages. That is where strawman 2’s past about 500 scattered rows, scan came from (slide 14): the 500 is pages(EMP). Then say what moves the crossing, because that is the deeper point: more rows per page moves it left, because the scan gets cheaper while the index still pays per row; a clustered index removes it almost entirely; and a buffer large enough to hold the fetched pages removes it too, which is appendix slide 78. All three are properties of the data and the physical design, which is why no rule book can encode the threshold, and why the optimizer can only notice clustering, never create it. Our arithmetic, not the paper's.])[Break-even: five percent of the table][
  #small[Vary F and the index cost scales with it: F × (40 + 10,000) against a flat 500.]
  #v(12pt)
  #crossover()
  #takeaway[The index loses once the qualifying rows outnumber the table's pages.]
  #caption[Break-even: F × (index\_pages + rows) = pages, so F = 500 / 10,040, about 5% of the rows.]
]

// Section divider before the two join methods.
// 35
#lecture-slide(section: true, notes: [0 minutes. Two algorithms and one cost shape, so the whole contest is over what one pass of the inner costs. One is an old acquaintance from strawman 2, rule 2’s lookups; the other, the merge join, is defined here, in words and then step by step, before it is priced.])[Two tables: join methods][]
// 36
#lecture-slide(source: [§5: the outer relation and the inner relation], notes: [2 minutes. Open on the loop, the plainest way to write a join: for every DEPT row, look at every EMP row, and emit the pairs that agree on DNO. That is what joining EMP and DEPT on DNO means, and every join method is a cheaper way to produce the same pairs. Then the two words the rest of the hour uses, one per box. The outer is the table of the outside loop: it is read once, row by row. The inner is the table of the inside loop: it is read again for every outer row, so whatever one pass of the inner costs is paid once per outer row; one lookup into the inner is called a probe, the thing strawman 2 called a lookup. Say explicitly that outer and inner are the outside and inside of a loop and have nothing to do with an outer join, which is a different thing and not in this paper. Written this way the loop is hopeless, 100 × 10,000 = a million pairs examined to keep 10,000, and only 1,000 of those are in Denver; the next slide makes it cheap twice over: the Denver filter runs on the outer before the inner loop starts, and the inner loop becomes a lookup through EMP's index.])[A join, as two loops][
  #v(50pt)
  #join-loops()
]
// 37
#lecture-slide(source: [§5: nested loop join], notes: [2 minutes. Three clicks: the loop, then what line two really is and one probe's price, then the formula. The first method, written out, because an audience that has not met it will not get it from a cost formula. These are rule 2’s lookups from slide 15, now with a price on each one. Read the three lines aloud as English: take one Denver department, find that department's employees, emit each pair, repeat. Then say what is not in the pseudocode and matters most: the inner line is not a scan of EMP, it is an access path chosen by exactly the Table 2 machinery of slide 30, with the outer row's DNO supplied as the constant. That is how a join predicate that is not sargable on its own becomes sargable once an outer row provides a value, and therefore how the inner index gets to match. Derive the probe on the board: EMP through its clustered DNO index, F = 1/distinct(DNO) = 1/100, costs 1/100 × (50 + 500) = 5.5 pages, half an index page and the 5 data pages that hold one department's 100 employees. Ten probes cost 55, and the whole plan 5 + 55 = 60. Then generalise to the formula, and point out the asymmetry it hides: the outer is paid once and the inner outer_rows times, so the two tables are not interchangeable even though the answer is. Every join cost from here on is page fetches, the measure of slide 19.])[Nested loops: rule 2’s lookups][
  #sql(size: 25pt)[```
for each d in DEPT with LOC = 'DENVER':
    for each e in EMP with e.DNO = d.DNO:
        emit (d, e)
```]
  #pause
  #small[Line two is not a scan of EMP. It is an access path, chosen by cost with d.DNO supplied as the constant, which is how EMP's index gets to match.\ One probe is Table 2’s clustered-matching row: 1/100 × (50 + 500) = 5.5 pages.]
  #pause
  #formula[C = C_outer + outer_rows × C_inner]
  #takeaway[Read the outer once. Look the inner up once per surviving outer row.]
  #caption[Here 5 + 10 × 5.5 = 60, with outer_rows = 10, not 100: DEPT’s filter has already run.]
]
// 38
#lecture-slide(source: [§5: nested loop join], notes: [1 minute. The same three lines as pages rather than rows, which is where the cost comes from. Walk one red outer row through the figure and then the repeat label on the arrow, and be explicit that the arrow is the whole argument of the next section: everything at its far end is paid outer_rows times. The inner's 5.5 pages are one probe of EMP's clustered DNO index, 1/100 × (50 + 500), and the index is matching because the outer row supplied a DNO value. Then the line under the figure: ask what happens if the inner has no index on the join column, and answer it. The inner pass becomes a scan of all 500 pages, and ten probes become 10 × 500 = 5,000 instead of 55. Then turn the loop around: with EMP outside, every one of its 10,000 rows looks DEPT up through DEPT's unique index at 2 pages, 500 + 10,000 × 2 = 20,500, which slide 41 prices next to 60. Illustrative layout, not a measured trace.])[Nested loops: outer and inner][
  #nested-loop()
  #v(16pt)
  #small[Without an index on EMP.DNO, each lookup scans all 500 pages: 10 × 500 = 5,000, not 55.]
  #takeaway[Read one outer row, find its matches in the inner; repeat outer_rows times.]
]
// The second join method, defined where it is first priced: in words, then step by step on
// the paper's own Figure 1 rows, then priced next to nested loops on slide 41.
// 39
#lecture-slide(source: [§5: merging scans], notes: [1 minute. The second join method, before it is priced. Nested loops are rule 2’s lookups: for each row of one table, find its matches in the other. A merge join is the other way to join two tables. Put both in join-column order, then walk them side by side, the way you merge two sorted lists in a first programming course: compare the two current rows, output on a match, step the side that is behind. Each table is read once, start to finish, and there are no lookups at all. The price is the first step: both tables must be in that order before the walk starts, and a table that is not has to be sorted, or read through an index in that order. So when is it worth it? When the lookups would be many. Rule 2’s query with EMP first needed 10,000 lookups into DEPT, and one walk instead of ten thousand lookups is a bargain. DEPT first needed 10, and ten lookups are cheaper than putting anything in order. System R had exactly these two join methods; slides 37 and 41 price both. Then answer why only two: Blasgen and Eswaran, 1976, found one of the two near-optimal except for very small relations, so System R implemented two and stopped. Quote the paper's own sentence, the cleanest in Section 5: the two cost formulas are essentially the same, and the reason that merging scans is sometimes better than nested loops is that the cost of the inner scan may be much less. Hash join is a 1980s addition, GRACE 1983 and hybrid hash, DeWitt et al. 1984, and today's engines have all three; appendix slide 84 has the dates.])[What a merge join is][
  #small[Nested loops pay a lookup per outer row. The other join method looks nothing up:]
  #v(14pt)
  #comparison(columns: (1fr, 3.2fr),
    [*Merge join*], [walk both tables side by side in join-column order, the way you merge two sorted lists],
    [*It reads*], [each table once, start to finish, with no lookups],
    [*The price*], [both in join-column order first: sorted, or already stored that way],
  )
  #takeaway[Worth it when the lookups would be many: 10,000, not 10.]
  #caption[Rule 2’s first query: EMP first needs 10,000 lookups into DEPT; DEPT first needs 10.]
]
// 40
#lecture-slide(source: [§5: merging scans; Figure 1], notes: [2 minutes. Five clicks: both cursors at the top, then one per step of the trace. One merge, step by step, on the paper's own Figure 1 rows and on the pair the nested loop of slide 38 and the comparison of slide 41 both use: DEPT with EMP on DNO. LOC = 'DENVER' has already run on DEPT, which leaves 50 MFG and 52 SHIPPING; 51 BILLING is in Boulder. Neither side needs sorting: DEPT is stored in DNO order, and so is EMP, SMITH 50, JONES 50, DOE 51. Both cursors start at the top; click once per step. One: 50 MFG against SMITH 50, equal, output the pair, and step EMP only. Two: the same 50 against JONES 50, equal again, output it. That is why a match steps only EMP: DNO is unique in DEPT, but the next EMP row may share it, as JONES shares SMITH's 50. Three: 50 against DOE 51. 50 is smaller, so DEPT steps: both lists are sorted, so nothing later in EMP can be a 50. Four: 52 SHIPPING against DOE 51. Now 51 is smaller, so EMP steps, and it has no rows left, so the merge is done: DOE, whose department is in Boulder, is passed over without a single lookup. The two stepping rules are said aloud, not printed: the smaller side steps forward, because nothing later on the other side can match it; and on a match only EMP moves on, because the next EMP row may share the key. Count what was read: each DEPT row once, each EMP row once, two pairs out; in the running query TITLE = 'CLERK' then keeps only JONES, the clerk. Then the two cost lines at the bottom, with this pair's numbers said aloud: a merge reads each input once, in join-column order. Here both arrive in DNO order through their clustered indexes, EMP for 50 index pages + 500 table pages and DEPT for 2 + 5, so the merge costs 557, the fourth row of slide 41. Had EMP been read by a scan, it would need a sort first, 500 + 2 × ceil(10,000 / 20) = 1,500, and the merge would cost 1,507, the route slide 46 draws. A non-clustered index in the right order costs about a page per row, EMP by JOB 50 + 10,000, so it rarely beats the sort; and a composite from an earlier join has no table pages to read, only what built it plus a sort if needed.])[A merge, step by step][
  #alternatives(..range(5).map(s => merge-trace-b(step: s)))
  #v(18pt)
  #small[*Merge join cost:* read each input once, in join order.\
  Clustered index: index + table pages. Otherwise: table pages + a sort.]
]
// 41
#lecture-slide(source: [§5: computing the cost of joins, Figure 3], notes: [2 minutes. Both methods are now on the table, so price them, and notice that rows one and three are rule 2’s two orders from slide 15, 10 lookups or 10,000, with real prices on them. Four candidates from slide 21 and slide 24 alone. The 342-fold gap between rows one and three, 20,500 against 60, comes from outer_rows, since the inner cost is paid once per outer row: 10 lookups at 5.5 against 10,000 lookups at 2. Same two tables, same two indexes, 60 or 20,500; say it aloud, since the slide shows only the table. EMP's lookup into DEPT is even the cheaper one, 2 pages against 5.5, and it does not come close to helping. Same join, same answer, same two indexes. Row two is two pages dearer and arrives in DNO order, so the search keeps both, a first sight of the keep rule slide 46 states. Row four is the merge, and it loses here for the reason slide 39 gave: it reads all of EMP in DNO order, 550 by itself, to save ten lookups that cost 55. Say that the merge's vindication is coming on slide 52, where the composite has 1,000 rows and a sort plus one pass of JOB, 100 + 3 = 103, replaces 1,000 lookups at 2 pages, 2,000. Three further candidates for this pair, 1,507, 20,550 and 30,050, are in appendix slide 81. Illustrative costs in page fetches, not measurements.])[Which table goes outside][
  #small[Joining EMP and DEPT; 1,000 rows out either way. DEPT.DNO is *unique*: one probe is Table 2’s row one, 1 + 1 = 2. All of DEPT in DNO order is its clustered index, 2 + 5 = 7.]
  #v(14pt)
  #comparison(columns: (1.9fr, 1.1fr, .6fr),
    [*Plan*], [*Arithmetic*], [*Cost*],
    [DEPT scan outer, probe EMP.DNO], [`5 + 10 × 5.5`], [*60*],
    [DEPT.DNO index outer, probe EMP.DNO], [`7 + 10 × 5.5`], [62],
    [EMP scan outer, probe DEPT.DNO], [`500 + 10,000 × 2`], [20,500],
    [Merge, both via clustered DNO indexes], [`50 + 500 + 7`], [557],
  )
]

// Section divider before the join-order search, the lecture's second hard turn.
// 42
#lecture-slide(section: true, notes: [0 minutes. The next slide states the problem and counts the candidates. This part contains the lecture's second hard turn: dynamic programming over subsets.])[Many tables: the order problem][]
// The opening of the many-tables part: what the order problem is, and why the obvious
// search, pricing every order, is factorial. Times assume a generous 1 µs per order.
// 43
#lecture-slide(source: [§5: computing join order], notes: [1 minute. The problem this part solves, stated before anything clever. A join's result does not depend on the order the tables are joined in; its cost depends on it hugely, 163 or 20,603 page fetches for our three tables, the first question on slide 3. The naive search is the obvious one: list every order, price each, keep the cheapest. With n tables that is n! orders, and each order also picks a join method for each of its n − 1 joins and an access path for each table, which multiplies the count again, so the table understates the work. Factorial means the n-th table multiplies the work by n. The right-hand column is search time, not the plan's page fetches; read it at a deliberately generous microsecond to price a whole order: nothing at three or eight tables, eight minutes at twelve, 77,000 years at twenty; fifteen tables, not on the slide, would take two weeks. Real queries get there: the benchmark Leis built averages eight joins, nine tables, and its largest query joins seventeen tables, about eleven years at this rate. The next four slides find the observation that replaces orders with subsets, and slide 48 counts what it saves.])[The order problem][
  #small[Every join order returns the same rows, at different cost: 163 or 20,603 page fetches on ours.\ The naive search: price every order, keep the cheapest.]
  #v(14pt)
  #comparison(columns: (.8fr, 1.5fr, 1.5fr),
    [*Tables (n)*], [*Orders (n!)*], [*Search time, 1 µs an order*],
    [3], [6], [6 µs],
    [8], [40,320], [0.04 seconds],
    [12], [479,001,600], [8 minutes],
    [20], [2.4 × 10#super(typographic: false, size: .7em)[18]], [77,000 years],
  )
]
// 44
#lecture-slide(source: [§5: computing join order], notes: [2 minutes. Three clicks: the question, then the continuation and the answer, then the order caveat. The paper's sentence in full: the method to join the composite to the k+1-st relation is independent of the order of joining the first k. Go slowly; this is the most important slide in the second half. DEPT joined to EMP at 60 and EMP joined to DEPT at 20,500 are different plans with wildly different costs, but they produce the same 1,000 rows, with the same columns, with the same two predicates already applied, LOC = 'DENVER' and EMP.DNO = DEPT.DNO. So the problem of adding JOB is the identical function of both, and the cost of adding JOB is the identical number: the same predicates apply, the same orders are useful, the same join methods. Therefore the history of a composite is irrelevant except through three facts: which tables are in it, how many rows it has, and what order they are in. Take a show of hands before revealing; the usual wrong answer is that the shape of the subtree must matter. The first click adds the continuation in red, priced once off the state box. The second click draws the caveat in the figure's lower branch, because it is where intuition breaks and the next two slides live: if the two sub-plans differ in order, the merge costs differ, 3 pages if the composite already arrives in JOB order and 100 + 3 if it must be sorted first, so they are not interchangeable. Nested loops into JOB cost 1,000 × 2 = 2,000 in any order.])[The observation that saves us][
  #alternatives(..range(1, 4).map(s => dp-prefix-irrelevance(stage: s)))
  Two ways to join EMP and DEPT. Does the next join care which one you used?
  #uncover("2-")[
    #takeaway[Only through two things: how many rows came out, and in what order.]
    #caption["independent of the order of joining the first k"]
  ]
]
// 45
#lecture-slide(source: [§5: computing join order], notes: [2 minutes. The correctness argument, in numbers rather than in the abstract. Set it up aloud, since the slide shows only the table: suppose the best three-table plan used the 20,500 plan for {EMP, DEPT}, and swap in the 60. The continuations' prices: JOB.JOB is unique, so one probe is 1 + 1 = 2; one pass of JOB in JOB order is its clustered index, 1 + 2 = 3; sorting the 1,000-row composite costs 2 × ceil(1,000 / 20) = 100. Row three is the argument and rows one and two are its instances: because the continuation only consumes 1,000 rows with the same columns, its cost X is the same number in both columns, so the difference between the two totals is always exactly 20,500 − 60 = 20,440, whatever sits above. An optimal plan containing the 20,500 subplan could therefore always be improved, which means no optimal plan contains it, so discarding it loses nothing. That is the exchange argument, and it is what licenses keeping one plan per subset instead of one per order. Two of the four totals are old friends: 22,500 in row one is exactly the rule book's plan, EMP scanned, DEPT probed, JOB probed, which appendix slide 75 prices, and 20,603 in row two is the FROM order run as written, EMP outside with DEPT found by lookups, then a sort and merge for JOB. The swap turns both into plans built on the 60. Then state the repair the next slide pays for: the swap is only legal while the cheaper plan delivers everything the parent needed, and order is the one thing it can fail to deliver. Sort cost is our own one-pass estimate, 2 × ceil(1,000 / 20) = 100 at 20 rows per page. Illustrative costs in page fetches, not measurements.])[Why throwing a plan away is safe][
  #comparison(columns: (2.2fr, 1fr, 1fr),
    [*Continuation*], [*With 20,500*], [*With 60*],
    [Nested loops into JOB.JOB: + 1,000 × 2], [22,500], [2,060],
    [Sort 1,000 rows, merge JOB: + 100 + 3], [20,603], [*163*],
    [Any continuation at all: + X], [20,500 + X], [60 + X],
  )
  #takeaway[Every total falls by the same 20,440: the 20,500 plan is in no optimal plan.]
  #caption[The swap is valid: both subplans deliver the same 1,000 rows, predicates applied.]
]
// Why a losing plan is kept: this is the exact point where the optimality argument needs
// "per interesting order". On this data the plan it saves still loses, which is the honest
// outcome and is said in the speaker note.
// 46
#lecture-slide(source: [§4: interesting orders; §5: one solution per order equivalence class], notes: [2 minutes. Three clicks: two of EMP's four paths, the 500 scan the cheaper on its own; then what keeping only the scan costs at the merge, a 1,000-page sort, 1,507; then the kept ordered path, 557, and the takeaway. The slide that says why the search keeps more than one plan per table, at the exact point where the optimality argument needs it. Say it in plain words first, as the top lines do: the scan is the cheapest way to read EMP, but the DNO index returns rows already in DNO order, and a later join may want that order, so the search keeps both. The paper's name for such an order is an interesting order, one that a join, ORDER BY or GROUP BY can use; the slides say useful order and do not define the term. Its pruning rule is to examine only the cheapest access path which produces tuples in each interesting order and the cheapest unordered access path. Our interesting orders are DNO and JOB, the two join columns, because the merge join of slide 39 walks both inputs in join-column order, so a plan that already delivers that order can save a sort later. For EMP that keeps three of its four paths: the 500 scan, the 550 DNO index and the 10,050 JOB index, twenty times the scan and kept only for its order; the SAL index, 10,040, is pruned, in an order nobody wants; appendix slide 80 has every path. In the paper's model a segment scan has no order, so EMP's DNO order always comes through its clustered index. If the state were just the cheapest plan for this subset, the 550 plan would have been discarded at the first level, and the merge option for EMP and DEPT would have had to start from the 500 scan and pay 1,000 to sort all 10,000 rows, 2 × ceil(10,000 / 20), 500 pages out and 500 back: 500 + 1,000 + 7 = 1,507 instead of 550 + 7 = 557. Fifty extra pages for the ordered path save 950 at the merge. The algorithm would still be correct for the plans it kept; it would simply have lost a good one from the space it searched. Hence the state is a pair, subset and order, and the table has seven entries at level one rather than three. Say the caveat out loud rather than hiding it: on this instance the merge loses to the 60 nested loop anyway, so nothing about the final plan changes. The point is the pruning rule, and a student who notices should be told they are right. One sentence on equivalence classes: EMP.DNO and DEPT.DNO are the same order once the two are joined, so one entry covers both, which is appendix slide 83. Sort cost is our own one-pass estimate at 20 rows per page; the paper gives no sort-production formula.])[Why the state carries the order][
  #small[For EMP, the scan is cheapest, but the DNO index returns rows already in DNO order.\ A later join may want that order, so keep both, not just the cheapest.]
  #v(12pt)
  #alternatives(..range(3).map(s => order-in-state(step: s)))
  #uncover("3-")[#takeaway[Spend 50 on the plan that lost, save 950 at the next merge.]]
]
// The algorithm itself, as the notes write it, before the counting and the worked lattice.
// 47
#lecture-slide(source: [§5: computing join order; the search tree], notes: [1 minute. The algorithm the last three slides licensed, written the way the notes write it. Four clicks: one per level of the loop, then everything under it at once. Read it level by level. Level one is slide 46's keep rule applied to every table: the cheapest path, plus the cheapest in each useful order, the paper's interesting orders. Level two extends each level-one survivor by one more table, which is always the inner, priced with both join methods, and keeps the cheapest for each pair and each order; level three does the same from the pairs, and so on up to all n tables. Nothing at level k + 1 looks at anything but level k's survivors, which is exactly what the observation and the exchange argument made safe, and the order tag is what slide 46 added. The paper builds the same table by iterating on the number of relations joined so far. On our query the levels hold 3 singles, 2 pairs and 1 triple, and the lattice on slide 51 is this loop run by hand.])[Dynamic programming over subsets][
  // One level of the loop per click: lines past the current level are hidden, not removed,
  // so the block keeps its size and nothing below it moves.
  #alternatives(..(2, 4, 7).map(shown => {
    show raw.line: it => if it.number > shown { hide(it) } else { it }
    sql(size: 24pt)[```
for each single table:
    keep the best plan, plus the best in each useful order
for each pair {A, B}:
    every kept plan for {A} ⋈ B and for {B} ⋈ A, both methods; best per order
for each triple:
    every kept plan for each pair in it ⋈ the remaining table; best per order
...
```]
  }))
  #uncover("4-")[
    #small[Each level reads only the level below: how a subset was built no longer matters.\ The added table is always the inner, and always a base table.]
    #takeaway[Keep the best plan per (subset, order), not per join order.]
    #caption[Our query has 3 singles, 2 pairs and 1 triple.]
  ]
]
// 48
#lecture-slide(source: [§5: at most 2#super[n] solutions], notes: [1 minute. The orders column is slide 43's; the new column is subsets. Make the room read the n = 3 row and notice that the clever algorithm is worse on our own running example; say the one-line summary aloud, exponential instead of factorial, and at three tables a loss. The column counts subsets, not plans priced: our query enters 6 of its 7 non-empty subsets. Honesty buys trust, and it tells them where the technique is for: we are doing this to learn it, not because a three-table query needs it. The crossover is the real content, pointless on toy queries and decisive on real ones, and Leis's queries average eight joins. Then the paper's own bound: the number of solutions stored is at most 2 to the n times the number of interesting result orders, with the time to build the tree roughly proportional to the same number. Left-deep enumeration prices about n × 2 to the n−1 joins, so 1,024 for eight tables. Our 30 costs break down as 10 single-table paths, 14 pair plans and 6 triple plans; appendix slides 80 and 81 list all of them.])[Subsets instead of orders][
  #comparison(columns: (.5fr, 1.1fr, .8fr, .8fr),
    [*n*], [*Orders (n!)*], [*Subsets (2#super(typographic: false, size: .7em)[n])*], [*Ratio*],
    [3], [6], [8], [0.75× — a loss],
    [5], [120], [32], [3.8×],
    [8], [40,320], [256], [*158×*],
    [10], [3,628,800], [1,024], [3,544×],
    [12], [479,001,600], [4,096], [117,000×],
  )
]
// 49
#lecture-slide(source: [§5: Cartesian products postponed], notes: [1 minute. Two clicks: the six orders, then the two that open with a cross product struck. The first of two heuristics on top of the subset search, and a property of the query, readable off the join graph before any cost is computed. EMP to DEPT and EMP to JOB are edges; DEPT to JOB is not. So two of the six orders on the right die, DEPT then JOB then EMP and JOB then DEPT then EMP, because each would open by pairing every DEPT row with every JOB row, a cross product, and one lattice node, {DEPT, JOB}, is never priced. The four survivors are the four legal orders, priced in full on appendix slide 68. A cross product is unavoidable only when the join graph is disconnected, and then the job is to take it as late as possible.])[No cross products][
  #alternatives(..range(2).map(s => no-cross-products(step: s)))
  #v(16pt)
  #small[Add a table only if it shares a join predicate with the tables joined so far.]
  #uncover("2-")[
    #takeaway[{DEPT, JOB} has no join predicate, so that subset is never entered.]
    #caption[Cross products are needed only for a disconnected join graph, and then as late as possible.]
  ]
]
// The second heuristic on its own slide, drawn so it reads without the speaker: the
// outer/inner words of slide 36 on a left-deep tree, against the bushy shape it rules out.
// 50
#lecture-slide(source: [§5: the relation being added to the join], notes: [1 minute. The second heuristic, on its own slide because it is the one 1979 restriction later systems dropped. Use slide 36's words: every join has an outer, read once, and an inner, consulted again for each outer row. Left-deep means the inner is always one base table, so each join adds one table to the composite built so far, and a plan's tree is fully described by its order, A, B, C, D on the left. The bushy tree on the right joins two composites, A ⋈ B and C ⋈ D, so its top join has a composite as its inner; System R never prices that shape. A bushy tree needs at least four tables, so our three-table query cannot have one; what the rule rules out here is the {DEPT, EMP} pair on the inside, JOB ⋈ (DEPT ⋈ EMP), the same rows at a different cost, which is the caption. Why accept the restriction: a base-table inner can be reached by an index probe, which is what made slide 37's 5.5-page probe available at every step; a composite is only ever the outer, so it can pipeline into the next join and is stored only if that join must sort it, as the winning plan's 1,000-row composite is on slide 53, while a composite inner, re-read once per outer row, would have to be stored; and the space shrinks to orders of tables, which the subset search then prices at about n × 2 to the n−1 joins, 1,024 at eight tables, slide 48. Flag that this is the one 1979 decision the modern evidence overturns: with rich indexes the best bushy plan can be far cheaper, appendix slide 64.])[Left-deep only][
  #small[Each join adds one base table, the *inner*, to the composite built so far, the *outer*.]
  #v(14pt)
  #left-deep()
  #v(14pt)
  #small[Why: a base-table inner can be probed through its index, as nested loops do;\ a composite is only ever an outer, read once, so it streams on unless a merge must sort it.]
  #takeaway[The inner is never a composite, so a plan’s shape is just an order of tables.]
  #caption[With three tables there is no bushy tree; the rule still excludes JOB ⋈ (DEPT ⋈ EMP).]
]
// 51
#lecture-slide(source: [§5, Figures 2 to 5], notes: [3 minutes. Seven clicks, bottom-up: the singles with the keep rule; then DEPT, EMP and JOB, one per click, each box outlined in red while the panel under the lattice prices its paths; then {EMP, DEPT} and {EMP, JOB}, priced the same way; then the panel clears for the question, with the two entries it asks about red in their boxes. It is slide 47's loop run by hand. Read each panel top to bottom: the kept entries first, each with its arithmetic and in grey why it survives, then the struck ones and why they lost. Level one is slide 46's keep rule applied to all three tables, and it contains a small repeat of slide 33: DEPT's index on its own filter column costs 10.2 and loses to a five-page scan. JOB's segment scan reads its 2 pages, exactly the unique TITLE index's 1 + 1 = 2, and both are unordered; only one unordered entry is kept, so the lattice keeps the index and strikes the scan as a tie. Nothing downstream moves: a JOB-first pair through the scan would cost the same 2 + 201 = 203. EMP's SAL index, which matches nothing in this query, is a 10,040-page pass in an order nobody wants. Level two is built by extending each level-one entry with one more table, both methods, keeping the best per order. The per-lookup prices in its panels are Table 2's: 5.5 for one probe of EMP's clustered DNO index, slide 37, 201 for one probe of its non-clustered JOB index, 1/50 × (50 + 10,000), one job code's 200 scattered rows at a page each plus a fiftieth of the index, which is printed only on appendix slide 70, so say it aloud; and 2 for one lookup through a unique index. Two entries deserve a finger: EMP and DEPT in JOB order at 30,050, and EMP and JOB in DNO order at 20,550, produce the same rows as the 60 and the 203 in their own subsets, and each is kept only because it delivers an order the triple might want. Ask the room whether they will ever be used, then answer it on the next slide: no, both lose to the cheap plan plus a sort. That is the honest outcome of the interesting-order rule on this data, and it is why the rule is cheap insurance rather than a guarantee. For students who check the paper: its own example prunes EMP's segment scan and keeps JOB's, because its sizes are not ours; here EMP's scan is the cheapest path and JOB's falls only on a tie. The mechanism is the same. Illustrative costs in page fetches, not measurements.])[The search: singles and pairs][
  #alternatives(..range(7).map(s => dp-lattice(stage: 2, step: s)))
]
// 52
#lecture-slide(source: [§5, Figure 6], notes: [2 minutes. Three clicks: the pairs from the last slide, its question gone, then the triple on top outlined in red, with the panel pricing it and the five plans it beats, then the winning path in red. The panel's last row answers the last slide's question: the two ordered entries skip a sort, but the sort they save costs only 20 or 100 pages, and they pay about 20,000 and 30,000 for it. The payoff for the whole middle of the lecture, in three beats. First, the winner uses both join methods and a sort, a nested-loop probe to build EMP and DEPT and then a merge to add JOB, and no rule book reaches it. Second, the merge wins here for exactly the reason slide 39 gave: the composite is only 1,000 rows, so sorting it costs 2 × ceil(1,000 / 20) = 100 pages and the merge's inner is one 3-page pass of JOB through its clustered index, 1 + 2, against 1,000 × 2 = 2,000 pages of probing. On the pair alone the merge lost by 557 − 60 = 497; once JOB is added, sorting wins by 2,000 − 103 = 1,897. Third, price the order the user actually wrote, run as written with lookups for the first pair: EMP outside probes DEPT for the pair at 500 + 10,000 × 2 = 20,500, then a sort and merge add JOB, 20,500 + 100 + 3 = 20,603, which is 126 times the winner. The four legal orders, with lookups for the first pair and a sort and merge for the third, are 163, 230, 20,527 and 20,603; the other two orders are cross products and were never enumerated. With a merge for the first pair, EMP first does far better, 557 + 100 + 3 = 660, which is why the search prices both methods. The best plan built on the other pair, 230, starts from JOB: 203 for the pair, a 20-page sort of its 200 rows on DNO, and one 7-page pass of DEPT. A sharp student may extend the kept 62 and 204 entries too: they only add 2 or 1 to plans already shown, 165, 2,062, 231 and 604, and their orders are no use to the last join; probing from the two ordered entries costs 32,050 and 20,950. The slide leaves these dominated plans out. The top level keeps only its cheapest plan, because the query has no ORDER BY or GROUP BY, which is why 230, in DNO order, is struck. Appendix slides 80 and 81 have every one of the 30 costs. Sort cost is our own one-pass estimate at 20 rows per page.])[The search: the triple and the winner][
  #alternatives(..range(3).map(s => dp-lattice(stage: 3, step: s)))
]
// 53
#lecture-slide(source: [§5, Figure 6], notes: [1 minute. The whole lecture on one slide. Trace it bottom-up and name where each number came from: scan DEPT's five pages with LOC = DENVER as a search argument, 10 rows out, from slides 20 and 24; probe EMP's clustered DNO index once per Denver department, 10 × 5.5 = 55, running total 60, 1,000 rows out, from slide 37; sort those 1,000 rows on JOB, 2 × ceil(1,000 / 20) = 100 pages, running total 160, from slide 21; merge with JOB through its clustered index with TITLE = CLERK as a search argument, 1 + 2 = 3 pages, total 163, 20 rows out, from slides 39 and 40; project. EMP carries no predicate in this query, so its probe is driven only by the DNO each Denver row supplies. Then close the loop opened on slide 3 and priced on slide 9 and appendix slide 75: 163 for the plan, 22,500 for the rule book at 138 times, 20,603 for the user's own FROM order run as written, EMP outside with lookups into DEPT, at 126 times, and about 5,000,000 for the tree as parsed at roughly 31,000 times. Both strawmen are our arithmetic, not costs the paper computes.])[The plan it picks][
  #v(48pt)
  #winning-plan()
]
// 54
#lecture-slide(source: [§5; §7: conclusion], notes: [1 minute. The engineering answer to the question isn't this expensive. Say one more figure aloud, which is no longer on the slide: the paper puts the search for a two-way join at 5 to 20 database retrievals, a database retrieval being one row fetched through the storage layer rather than one page, which is less than the query itself costs on its first execution, while the gap between plans here is 138 times against the rule book and 126 times against the FROM order run as written, with lookups for the first pair. These are the only performance numbers in the entire paper; there is no measured plan-quality result in it, only the claim appendix slide 61 checks. Then say where this search lives now: Postgres runs the same bottom-up subset DP, bushy joins included, for fewer than geqo_threshold = 12 FROM items, then switches to a genetic search, GEQO; Cascades-style optimizers, SQL Server, Calcite, CockroachDB and Spanner among them, memoize the same subsets top-down with rules instead of bottom-up; and most engines now consider bushy plans, which 1979 did not. These are 1979 figures for an IBM 370/158, not a prediction for any current system.])[What the search itself cost][
  #comparison(columns: (1.5fr, 1.5fr),
    [*Search cost*], [*System R, 1979*],
    [Storage for a typical optimization], [A few thousand bytes],
    [CPU on an IBM 370/158], [A few tenths of a second],
    [An eight-relation join], [Optimized in a few seconds],
  )
  #takeaway[A plan is compiled once and run many times, so the search amortizes.]
]
// The recap that ends the core route: what each part of the hour built, in the order it
// was built, closing on the plan of slide 53. Nested queries and the 2015 re-run follow
// the appendix divider.
// 55
#lecture-slide(source: [§4 and §5, assembled], notes: [1 minute. The end of the core route, and no new content: one line per part of the hour, in the order it was built. Rules: each of strawman 2’s two held on one query and broke on the next, because the deciding fact was in the data, slides 12 to 16; the one rule that survives, applying filters early, is strawman 1’s pushdown, slide 10. Cost: page fetches, slide 19, the one number every plan is ranked by. Estimates: the four catalog numbers of slide 20 and Table 1’s factors, multiplied, slide 23, under the assumptions slide 26 read out, uniform values and independent columns, which is where estimates go wrong. One table: the cheapest access path, priced by Table 2, slides 30 to 33, plus the cheapest per useful order, which the search keeps, slide 46. Two tables: nested loops or merge scan, whichever costs less, slide 41. Many tables: the subset search, argued on slides 44 to 47 and run by hand on slides 51 and 52, which found the plan of slide 53. Then the result once more: 163 page fetches for the 20 rows, against 22,500 for the rule book. The three slides to re-read: 26, the assumptions; 33, where the obvious index loses to a scan by 5×; and 46, why the state carries the order. The appendix opens with the two parts this route leaves out, nested queries from slide 57 and what held up when the paper's claim was re-tested, from slide 60; the review questions are slide 85. Forward to next class: Spanner, where the cost measure grows a network term and a shard fan-out term.])[Recap][
  + *Rules:* each held on one query and broke on the next.
  + *Cost:* page fetches, the one number every plan is ranked by.
  + *Estimates:* four catalog numbers and a factor per predicate, multiplied.
  + *One table:* the cheapest access path, plus the cheapest per useful order.
  + *Two tables:* nested loops or merge scan, whichever costs less.
  + *Many tables:* DP over subsets, one plan per (subset, order).
  #takeaway[163 page fetches for the 20 rows, against 22,500 for the rule book.]
  #caption[Next class, Spanner: the cost measure grows a network term and a shard fan-out term.]
]

// Appendix divider.
// 56
#lecture-slide(section: true, notes: [Optional, 0 minutes. First the two parts the core route stops before: nested queries, slides 57 to 59, and what held up when the paper was re-tested in 2015, slides 60 to 66, ending with the whole design in eight steps. Then the cards the core route moved here because they quote costs it derives only later: the glossary and the four choice cards behind slide 3, each with its arithmetic, and the rule book's bill. Then the two tables in full, the paper's CPU term, every plan the search priced, and the follow-up evidence.])[Appendix][]

// Section divider before the two nested-query cases.
// 57
#lecture-slide(section: true, notes: [Optional, 0 minutes. A predicate can contain a whole query block. Evaluate it once, or once per outer row.])[Nested queries][]
// 58
#lecture-slide(source: [§6: nested queries; Table 1], notes: [Optional, 1 minute. The paper's own example, on our EMP. The inner block references nothing from the outer block, so it is evaluated once, before the outer block runs, and its result is substituted as a constant, which means the outer predicate becomes sargable and gets a real selectivity factor, so everything from the access-path section on applies unchanged. A subquery that returns a list is handled the same way: evaluated once, and the list plugged in. When the values are not yet known at optimization time, Table 1 supplies the factor for column IN subquery: the subquery's expected result_rows over the product of rows(T) across its FROM list, which is appendix slide 77. The value 15000 is illustrative, the midpoint of the SAL keys from 5,000 to 25,000, not a computed average.])[Uncorrelated: evaluate once][
  #sql(size: 25pt)[```
SELECT NAME FROM EMP
WHERE  SAL = (SELECT AVG(SAL) FROM EMP)
```]
  #small[*Uncorrelated*: the subquery names no outer column — one answer for the whole query.]
  #v(8pt)
  #subquery(mode: "uncorrelated")
  #takeaway[AVG(SAL) returns 15000, so the outer block optimizes SAL = 15000.]
]
// The paper's correlated example compares each employee with their manager, a column our
// EMP does not have; the department average keeps the example inside the lecture's schema
// and gives the reuse rule something to reuse (DNO repeats, and EMP is stored in DNO order).
// 59
#lecture-slide(source: [§6: correlation subqueries], notes: [Optional, 2 minutes. The same layout as slide 58, query on top and the same two boxes in the same positions, with one change: an arrow now carries a value from the outer row into the inner block, X.DNO, so the inner block is re-evaluated per outer row and the badge reads outer_rows times instead of once. The query asks for the employees who earn more than their own department's average; the paper's own example asks for those who earn more than their manager, a column our EMP does not have, and the shape is identical. This is rule 2’s lookups again, slide 37, with the subquery as the inner: a nested-loop join wearing a different syntax. Name the one optimization the paper does offer, which is not on the slide, so say it: if the referenced column repeats across outer rows, reuse the previous result, and sort the outer on that column if the saving pays; the paper's cue for whether it pays is rows(T) greater than distinct(I) on an index over the referenced column. Here rows(EMP) is 10,000 against distinct(DNO) of 100, and EMP is already stored in DNO order, so reading it through its clustered DNO index delivers each department's 100 employees together with no sort, and the average is computed 100 times instead of 10,000. Then the honest limitation, which is the real lesson: because System R keeps each subquery as its own block and treats it as a procedure rather than a join, the dynamic programming of the many-tables part never sees across the boundary, so no join order is considered there at all. System R stops there; rewriting correlated subqueries into joins, unnesting, came with later systems and closes that gap, and the gap is why a correlated subquery could be catastrophically slow in early systems.])[Correlated: a nested loop in disguise][
  #sql(size: 25pt)[```
SELECT NAME FROM EMP X
WHERE  SAL > (SELECT AVG(SAL) FROM EMP WHERE EMP.DNO = X.DNO)
```]
  #small[*Correlated*: the subquery names X.DNO, the current outer row’s value.]
  #v(8pt)
  #subquery(mode: "correlated")
  #takeaway[One inner evaluation per outer row. That is a nested-loop join.]
]

// Section divider before the 2015 re-run of the paper's own claim.
// 60
#lecture-slide(section: true, notes: [Optional, 0 minutes. Thirty-six years later, someone ran the experiment the paper promised. Check each of the three things we had to invent on slide 17, the cost measure, the statistics and the search, against the result.])[What held up, what did not][]
// 61
#lecture-slide(source: [§7: conclusion], notes: [Optional, 1 minute. The paper's own check, in one line: absolute costs often wrong, the ranking of plans usually right. The re-run is Leis et al., VLDB 2015, and its 2018 journal version. This is the fair standard to judge the paper by, and it is narrower than it is usually quoted: three distinct claims, that the absolute numbers are often wrong, that the best plan is chosen in a large majority of cases, and that only in many cases is the whole ordering identical to the measured ordering. The paper also describes these as preliminary results from evaluation work still in progress, and the promised validation arrived thirty-six years later from someone else. Say why Leis built a new benchmark rather than using TPC-H, in their words: the synthetic generators use the very same simplifying assumptions, uniformity, independence and the principle of inclusion, that query optimizers make, which trivializes cardinality estimation. The specifics: 629 base-table selections, over 100,000 intermediate estimates, measured on PostgreSQL, HyPer and three anonymised commercial engines, with cardinalities extracted from each and injected into one engine so a single executor runs every plan. A ranking tool, not a predictor. Reference: https://www.vldb.org/pvldb/vol9/p204-leis.pdf and https://ir.cwi.nl/pub/27562/27562.pdf])[The 1979 claim, and a test of it][
  #comparison(columns: (1fr, 2fr),
    [*What they checked*], [*What they found*],
    [Absolute costs], ["often not accurate in absolute value"],
    [Which plan wins], ["the true optimal path is selected\ in a large majority of cases"],
    [The full ordering], ["in many cases, the ordering ... is precisely the same as that among the actual measured costs"],
  )
  #v(26pt)
  #small[The test: Leis et al., 2015 and 2018 — 113 queries on the real IMDB database,\ 3.6 GB, 21 tables, 3 to 16 joins, average 8.]
  #v(10pt)
  #caption[The 1979 findings in the table were stated as preliminary, from work "in progress".]
]
// 62
#lecture-slide(source: [Leis 2015, §3, Table 1 and Figure 3], notes: [Optional, 2 minutes. The slide that judges 1979’s statistics, and the vindication of slide 26. Single-table selectivity is essentially solved, with median q-error 1.00 for PostgreSQL, 1.02 for HyPer and 1.06 at worst across the systems tested, which is Table 1 doing fine, and the two best estimators get there with a table sample rather than a histogram. Joins are where it collapses, and the authors name the mechanism: systematic underestimation due to applying the independence assumption, with the conclusion that no system tested was able to detect join-crossing correlations. That is the LOC and ZIP picture of slide 26, paid once per join: each join multiplies another factor in, and the errors compound. Then two honest caveats, because the slogan is not the result. First, the direction is workload-dependent: the authors' own 2025 retrospective reports overestimation on a different benchmark, so this is underestimation on workloads like the 113 IMDB queries, not a law. Second, independence is the principal mechanism but not the sole cause: when they replaced PostgreSQL's underestimated distinct counts with exact ones, underestimation got worse, because two wrong assumptions had been partly cancelling. For the exponential framing, Ioannidis and Christodoulakis proved in 1991 that estimation error grows exponentially with the number of joins in the worst case under their model's assumptions, and their own paper exhibits a regime where it decreases, so that is a worst-case model result, not a claim about every query. DBMS A, B and C are anonymised commercial systems; no per-system number here names a product. Reference: https://www.csd.uoc.gr/~hy460/pdf/p268-ioannidis.pdf])[Base tables are fine; joins are not][
  #small[q-error: the factor by which an estimate differs from the truth.]
  #v(12pt)
  #qerror-by-joins()
  #v(8pt)
  #small[Each join multiplies two estimates as if the columns were independent, once per join.]
  #takeaway[The failure is not in the statistics. It is in combining them.]
  #caption[Fraction of estimates wrong by 10× or more, on the 113 IMDB queries; here mostly underestimates.]
]
// 63
#lecture-slide(source: [Leis 2015, §5; journal version §8], notes: [Optional, 1 minute. The cost measure of slide 19 gets a surprisingly good grade: crude is fine, and tuning the model's constants, such as how much CPU work counts against a page read, was never the main problem. Give Lohman's 2014 line, which is the memorable form of the whole finding: the cost model may introduce errors of at most 30% for a given cardinality, but the cardinality model can quite easily introduce errors of many orders of magnitude. Then walk it back honestly, which is what the journal version does: on disk, with a realistic random-to-sequential ratio, even perfect estimates leave a join-order optimizer picking plans about an order of magnitude off, so a good cost model matters more there. The ranking survives, because plan quality will generally still be dominated by the errors in cardinality estimation, but the gap narrows. Then the line under the table, and be exact about what it measures, because it is a different number from the table: with true cardinalities, the plans each model picks were run, and in geometric mean over all queries the tuned model's plans ran 41% faster than the default's, and the plans of a model that does nothing but count the rows passing through each operator, no I/O at all, ran 34% faster. So the trivial model recovers most of what tuning buys, and the whole gain is dwarfed by what true cardinalities buy. A main-memory result, not a universal one. Reference: http://wp.sigmod.org/?p=1075])[The cost model matters less][
  #small[True cardinalities for every model, so only the cost model varies.]
  #v(12pt)
  #comparison(columns: (1.9fr, 1fr),
    [*Cost model*], [*Median error vs. run time*],
    [PostgreSQL's default, about 4,000 lines of C], [38%],
    [The same model, tuned for main memory], [30%],
  )
  #v(22pt)
  #small[Plans picked by a model that just counts rows through operators run 34% faster\
    than the default's; plans picked by the tuned model, 41% faster.]
  #takeaway[Thirty per cent from the cost model. Orders of magnitude from cardinalities.]
  #caption[A main-memory result. On disk, the journal version finds it matters more.]
]
// The journal figures, not the conference ones: the 2015 conference version's
// plan-enumeration results were withdrawn, and they are the figures that would have made
// "the 1979 search survived" look true.
// 64
#lecture-slide(source: [Leis, VLDB Journal 27(5), 2018, Table 3], notes: [Optional, 2 minutes. Two clicks: the three trees and the question, then the answer. The one place the 1979 design loses outright, and the slide exists so the lecture does not overclaim. The restriction under test is the left-deep heuristic of slide 50: the inner is always a base table, so two composites are never joined. Be careful here, because the literature contains a withdrawn number: the authors' 2025 retrospective states that the conference version's plan-enumeration results were incorrect due to a data-handling issue and were corrected in the journal version. The conference table priced the left-deep restriction at 1.06 times median and 4.50 times max, harmless, and exactly the figure that would have made "the 1979 search survived" look true. The corrected journal figure is a median of 1.94 times and up to 1,252 times once foreign-key indexes exist. Use the journal's numbers and say why. Then the deeper finding behind the condition in the subtitle, PK+FK indexes: good plans get rarer as the physical design gets richer, since the fraction of random plans within 1.5 times of optimal falls from 44% with no indexes to 39% with primary keys to 4% with foreign-key indexes, and the worst-to-best ratio rises from 101 times to 48,120 times. That is the point of slide 34 from the other end: the physical design moves the answer, and the richer it is, the harder optimization becomes. The other half of the verdict, that exhaustive enumeration still beats the heuristics in the tail, is appendix slide 82. Reference: https://ir.cwi.nl/pub/27562/27562.pdf and https://ir.cwi.nl/pub/35880/35880.pdf])[The search space had to widen][
  #small[Each tree's cost against the best *bushy* plan — median above, *95th / max* below. Bushy joins two composites, {A, B} ⋈ {C, D}; left-deep forbids that. True cardinalities, PK+FK indexes.]
  #v(12pt)
  #tree-shape-penalty()
  So did the 1979 search survive?
  #pause
  #takeaway[The enumeration did. The search space did not.]
]
// 65
#lecture-slide(source: [§4, §7; Leis 2015 §3; journal 2018 Tables 3 and 4], notes: [Optional, 1 minute. Earn each clause from the slides behind it. The subset search and interesting orders are intact and vindicated: appendix slide 82 prices them against three heuristics, and the authors' lesson is that in rich schemas with foreign-key indexes, exhaustive plan enumeration provides tangible benefits. Left-deep-only is the one restriction that had to go, which slide 64 priced. The four catalog statistics and the 1/10 and 1/3 constants were replaced by histograms and samples, which slide 62 showed working. And uniformity and independence, which Selinger wrote down in one line each, were still in force in every system Leis measured. The short form you will hear, the 1979 search survived and the 1979 statistics did not, is right about the enumeration; the corrected journal table adds that the space it enumerated, left-deep only, had to widen, which is why bushy plans are on the notes' list of what 1979 did not have, appendix slide 84. Selinger's candour is the model to copy, because both assumptions are printed in Table 1, in plain sight. The 2015 conference version's plan-enumeration tables were withdrawn; these are the 2018 journal figures.])[The line to remember][
  The 1979 enumeration survived.
  #v(18pt)
  The 1979 search space had to be widened.
  #v(18pt)
  The 1979 statistics were replaced.
  #v(24pt)
  #takeaway[And the 1979 assumptions, which were the real problem, are still with us.]
]
// The notes' eight steps replace the old five-bullet "What to remember".
// 66
#lecture-slide(source: [§3–§6, assembled; discussion based on §7], notes: [Optional, 1 minute. No new content: the whole optimizer in the order a query meets it, eight steps, each one built in the core route or the two parts just before this slide. Walk it top to bottom once and point at where each step came from. One, rewrite and pushdown: strawman 1’s fix, slide 10. System R's rewriting is that small, conjunctive normal form and each boolean factor applied as early as possible; expanding views and flattening or unnesting subqueries came with later systems, and System R keeps each subquery as its own block. Two, the cost measure: page fetches, slide 19. The paper adds a CPU term we leave out; it is appendix slide 79, for anyone who asks. Three, the four catalog numbers, refreshed by a manual UPDATE STATISTICS: slide 20. Four, one selectivity factor per boolean factor from Table 1, multiplied: slide 23, and the multiplying is what slide 62 just indicted. Five, per table the cheapest access path overall and the cheapest per useful order: slide 46. Six, nested loops or merge scan, whichever costs less, never a rule: slide 41. Seven, the subset search: slides 51 and 52, which found 163 page fetches for the 20 rows. Eight, nested queries: slides 58 and 59. Steps two to four are the cost measure and the statistics, and five to seven the search, so this is slide 17’s three inventions, built. Then the three slides to re-read: 33, where the obvious index loses by 5×; 46, why the state carries the order; and 64, what the 1979 space left out. The review questions are appendix slide 85.])[The design, assembled][
  + *Rewrite:* parse into blocks, convert to CNF, push each filter to its table.
  + *Cost:* page fetches (System R adds a CPU term we leave out).
  + *Statistics:* kept in the catalog, refreshed by hand.
  + *Selectivity:* one factor per predicate from Table 1; multiply.
  + *Access paths:* per table, the cheapest overall and per useful order.
  + *Join methods:* nested loops or merge scan, decided by cost.
  + *Join order:* DP over subsets, one plan per (subset, order);\
    left-deep, no cross products.
  + *Nested queries:* once if uncorrelated, per outer row if correlated.
]
// A one-card glossary for the four choice cards that follow: every word they use that a
// reader arriving from slide 3 may not have met yet. Each word returns, with the
// arithmetic behind it, in the core route.
// 67
#lecture-slide(source: [§3, §4, §5], notes: [Optional, 1 minute. The glossary the next four cards need, for anyone who jumps here from slide 3 before the core route has earned the words. Read each line once and move on; every term has arithmetic under it in the core route. Page fetch is the unit for the whole hour; slide 19's note names the paper's second, CPU term and drops it, and slide 79 has the rest. Access path, segment scan, clustered and matching are the single-table vocabulary of slides 29 to 34; segment scan is only the paper's name for a full scan, every page of the table once. Legal order is the no-cross-product heuristic of slide 49, stated here because the very next card prices four orders and calls them legal; say the reason out loud, that two of the six orders would have to start by pairing every DEPT row with every JOB row, because those two tables share no column. Nested loops and merge scan are the two join methods of slides 36 to 41: nested loops are rule 2's lookups, merge scan is the merge join of slides 39 and 40. If the room already has the words, skip the card: the four after it are the ones carrying numbers.])[Appendix: words for the choice cards][
  #columns(
    [#small[*Page fetch* — one data or index page read from disk. The unit of every cost.]
     #v(18pt)
     #small[*Access path* — one way to read one table: a scan, or one of its indexes.]
     #v(18pt)
     #small[*Segment scan* — System R’s name for a scan: every page of the table, once.]
     #v(18pt)
     #small[*Clustered* — table stored in that index's key order. Only one index can be.]],
    [#small[*Matching* — the predicate filters that index's own key, so a scan can narrow.]
     #v(18pt)
     #small[*Legal order* — each table after the first shares a join column with an earlier one.]
     #v(18pt)
     #small[*Nested loops* — read one table once; look each of its rows up in the other.]
     #v(18pt)
     #small[*Merge scan* — put both in join-column order, then walk them together once.]],
  )
  #takeaway[None of these words is in the SQL. Every one is the system's choice.]
  #caption[Each word is earned, with arithmetic under it, in the core lecture.]
]
// Four cards, one per question on slide 3, each naming the plans that answer it and their costs.
// 68
#lecture-slide(source: [§5: computing join order], notes: [Optional, 1 minute. The first of four cards, one per question on slide 3: the choice, the competing plans, and the arithmetic that prices them. All four legal orders are priced here so the spread is not taken on faith. Two of the six orders, DEPT then JOB and JOB then DEPT, are cross products, because those two tables share no column, and the optimizer never enumerates them. Read each sum left to right: read the first table, look the second up once per surviving row, sort, then merge the third. The first term is how each table is read: DEPT by a five-page scan, EMP by a 500-page scan, and JOB through its unique TITLE index, one index page and one data page, 1 + 1 = 2. That 2 is the TITLE index, not a scan, though a segment scan of JOB's two pages also costs 2: a tie, and the search keeps the index, slide 80; either way the JOB-first sum is 230. Almost all of the spread is the first table's surviving row count, 10 Denver departments against 1 clerk job against all 10,000 employees, since that count multiplies everything above it. EMP keeps all 10,000 because the paper's WHERE clause does not filter it at all, which is exactly where rule 2 breaks, slide 16. JOB first has the smallest count of all and still loses to DEPT first, 230 against 163, because the only way into EMP on JOB is a non-clustered index at 201 pages a lookup. The spread is 20,603 / 163 = 126.4, and the FROM list as written, EMP, DEPT, JOB, is the worst of the four, run the way this card runs every order: the first pair joined by lookups. Every number comes off the statistics on slide 21; 163 and 230 are priced on slide 52's panel and 20,603 on slide 53. If someone checks this against slide 81, the bottom two rows are not in it: the card fixes the method, lookups for the first pair, so that only the order varies, and both rows are built on the 20,500 pair plan that the search prunes before it ever reaches the triple. That is the point of slide 45, arriving early. If someone asks why EMP first could not merge with DEPT instead, it could, at 557, and that plan is on slide 73; with the sort and the merge for JOB on top it costs 557 + 100 + 3 = 660, still about four times 163. So 20,603 is the FROM order run with lookups, not EMP first at its own best. Illustrative costs in page fetches, not measurements.])[Appendix: which table first][
  #small[Read the first table, look the second up once per surviving row, then sort and merge the third.\
  DEPT: scan 5, 10 Denver rows. JOB: TITLE index 2, 1 clerk. EMP: scan 500, all 10,000 rows.]
  #v(14pt)
  #comparison(columns: (1fr, 2.1fr, .45fr),
    [*First, second, third*], [*Read + survivors × lookup + sort + merge*], [*Cost*],
    [DEPT, EMP, JOB], [`5 + 10 × 5.5 + 100 + 3`], [*163*],
    [JOB, EMP, DEPT], [`2 + 1 × 201 + 20 + 7`], [230],
    [EMP, JOB, DEPT], [`500 + 10,000 × 2 + 20 + 7`], [20,527],
    [EMP, DEPT, JOB], [`500 + 10,000 × 2 + 100 + 3`], [20,603],
  )
  #takeaway[Four legal orders, a 126-fold spread; the FROM list names the worst.]
  #caption[DEPT and JOB share no column: the two orders that pair them first are cross products.]
]
// Two cards that unfold the slide 68 sums: the winner term by term, then why the last
// two terms come in only two shapes. The same arithmetic is derived properly on slides
// 37, 41 and 52.
// 69
#lecture-slide(source: [§5: computing join order], notes: [Optional, 1 minute. The winning sum from the previous card, unfolded, because a four-term expression is not self-explanatory however carefully it is laid out. Read the terms aloud in order. Five is a segment scan of DEPT, all five of its pages, with LOC = 'DENVER' tested as a search argument, and ten of its hundred rows survive, from the 1/10 on slide 24. Then ten lookups into EMP, one per surviving Denver department, each costing one hundredth of EMP's DNO path: fifty index pages plus five hundred data pages is 550, and one DNO value in a hundred is 5.5. Say out loud that 5.5 is an expected cost and not half a page fetch, because the optimizer works in expectations throughout. Those first two terms are exactly the 60 on slide 73, and the 1,000 pairs they produce are the input to the last two: each Denver department brings all 100 of its employees, because nothing filters EMP. A hundred sorts those 1,000 rows into JOB order at twenty rows a page, out and back, 2 × ceil(1,000 / 20), which is this lecture's convention and not the paper's. Three is one pass of JOB through its clustered index, one index page and two data pages, with TITLE = 'CLERK' tested as a search argument, because a merge reads each side once; 20 rows come out. No new machinery: this is the two cost formulas of slides 37 and 41 applied once each, and slide 52 re-derives the whole plan inside the search. Illustrative costs in page fetches, not measurements.])[Appendix: where 163 comes from][
  #small[The winning order, DEPT then EMP then JOB, one term at a time.]
  #v(14pt)
  #comparison(columns: (.75fr, 2.75fr, .7fr),
    [*Term*], [*What it pays for*], [*Rows out*],
    [`5`], [read DEPT once: 5 pages, and the Denver rows are kept], [10],
    [`10 × 5.5`], [one EMP lookup per Denver row: `1/100 × (50 + 500)`], [1,000],
    [`100`], [sort those 1,000 pairs on JOB: `2 × ceil(1,000/20)`], [1,000],
    [`3`], [one pass of JOB in JOB order: 1 index + 2 data pages], [20],
  )
  #takeaway[5 + 55 + 100 + 3 = 163 page fetches, for twenty rows of answer.]
  #caption[The 1,000 pairs: 10,000 EMP × 10 Denver rows, one in a hundred agreeing on DNO.]
]
// The three lookup costs the whole deck leans on, decomposed once: a lookup is a fraction
// of the inner's whole access path, and clustering decides whether that fraction lands on
// pages or on rows.
// 70
#lecture-slide(source: [§4, Table 2; §5: computing the cost of joins], notes: [Optional, 1 minute. The card that stops 5.5 from being a magic number, and it pays for itself three times over, because these three lookup costs carry every join cost in the deck. A lookup is not a new formula: it is Table 2 again, on the inner table, with the outer row's value supplied as the constant, which is what makes the join predicate sargable and lets the inner index match. So the cost is a fraction of the inner's whole access path, and the fraction is the join predicate's selectivity factor, one over the column's distinct values. Walk row one: EMP has 10,000 rows and 100 departments, so one department is 100 rows; EMP is stored in DNO order, so those 100 rows sit together on five pages at twenty rows a page, and the index contributes one hundredth of its fifty pages, half a page. Five and a half. Walk row two and let the contrast land: one job code is 200 rows, the JOB index is not the order EMP is stored in, so those 200 rows sit on 200 different pages and the deck charges a fetch for each. That is pages against rows, the whole argument of slide 32. Row three is the degenerate case, a unique index: one key, one row, one index page and one data page. These are strawman 2's rough counts made exact: about 5 reads for one department and about 200 for one job code, slide 13. Say that 5.5 is an expected cost and not half a fetch: ten lookups cost 55. Illustrative costs in page fetches, not measurements.])[Appendix: what one lookup costs][
  #small[Every join cost in this deck is some number of lookups. Here is what one costs, and why.]
  #v(14pt)
  #comparison(columns: (2.8fr, 1.55fr, .5fr),
    [*What one lookup reads*], [*Table 2*], [*Pages*],
    [EMP by DNO, clustered: 100 rows on 5 pages], [`1/100 × (50 + 500)`], [*5.5*],
    [EMP by JOB, scattered: 200 rows on 200 pages], [`1/50 × (50 + 10,000)`], [201],
    [either unique index: 1 row on 1 page], [`1 + 1`], [2],
  )
  #takeaway[Clustered, rows share pages. Scattered, each row costs its own fetch.]
  #caption[Clustered F × (index_pages + pages), non-clustered F × (index_pages + rows), with F = 1/100\ for DNO and 1/50 for JOB. The outer row’s value lets the inner index match.]
]
// 71
#lecture-slide(source: [§5: computing join order; §5: n-way joins], notes: [Optional, 1 minute. Why the four sums on slide 68 come in only two shapes. The last two terms do not depend on the join order as such, only on which pair was built first: DEPT with EMP leaves JOB to add, and JOB with EMP leaves DEPT. Give the two composites, 1,000 rows for EMP and DEPT and 200 rows for EMP and JOB, both of them products of slide 24's factors, and note that the second is smaller because one job title is CLERK while ten departments are in Denver. Then the two tails, a sort plus one pass, with the sort cost from this lecture's own convention and the pass being the table's clustered index pages plus its data pages. Ask why the third table is not simply looked up once per composite row, and answer with slide 74: 1,000 lookups of a unique index cost 2,000 against 103 for a sort and a merge, and 200 lookups cost 400 against 27. Then flag what this slide quietly makes concrete, because it is the second half of the lecture in miniature: the tail is the same number whatever the pair below it cost, which is the exchange argument on slide 45 and the reason the search can keep one plan per subset. Illustrative costs in page fetches, not measurements.])[Appendix: why the last two terms differ][
  #small[Of the four legal orders, the two that join DEPT to EMP first end in `+ 100 + 3`, and the two that join JOB to EMP first end in `+ 20 + 7`. All four add the third table the same way: sort the pair you have, then walk it and the third table once each.]
  #v(14pt)
  #comparison(columns: (1.4fr, .5fr, 1.7fr, 1.1fr),
    [*First pair built*], [*Pairs*], [*Sort them*], [*Then one pass of*],
    [DEPT and EMP, JOB left], [1,000], [`2 × ceil(1,000/20) = 100`], [JOB: `1 + 2 = 3`],
    [JOB and EMP, DEPT left], [200], [`2 × ceil(200/20) = 20`], [DEPT: `2 + 5 = 7`],
  )
  #takeaway[The tail follows the pair you built, not the table you read first.]
  #caption[1,000 = 10,000 × 10 × 1/100 and 200 = 10,000 × 1 × 1/50. Looking the third table up instead would cost `1,000 × 2` or `200 × 2`, so the sort wins both times.]
]
// The one choice card that leaves the running query: the paper's WHERE clause never filters
// EMP, so the index-or-scan choice is shown on the one-table query of rule 1 and the
// access-path section.
// 72
#lecture-slide(source: [§4, Table 2], notes: [Optional, 1 minute. The second card, and the one place the cards leave the running query. The paper's WHERE clause never filters EMP, so on our query every EMP index path reads the whole index and the whole table, and nothing can match; slide 80 prices those four at 500, 550, 10,050 and 10,040. To see the index-or-scan choice at all, take the one-table query that rule 1 and the access-path section use, SAL > 20000 on EMP. One predicate, four paths, the same 2,500 rows found by every one of them, so the comparison is honest. The scan reads all 500 pages and tests SAL as a search argument on the way past, so the rows that fail cost no extra page; that is Table 2's segment-scan row, pages(EMP) = 500. The two non-matching index scans read a whole index and then the whole table, which is why they are dear; on the running query they are kept anyway, because they deliver DNO order and JOB order, free for the join above, slide 46. The matching index is the one rule 1 picks, and it is the one that loses: EMP is stored in DNO order, a table has only one stored order, so the SAL index is non-clustered and every one of the 2,500 qualifying rows costs its own page fetch. That substitution of rows for pages is the whole story, derived on slides 32 to 34. Illustrative costs in page fetches, not measurements.])[Appendix: index or scan][
  #small[The one-table query `... FROM EMP WHERE SAL > 20000`; the running query never filters EMP.\
  EMP: 10,000 rows on 500 pages, 2,500 of them match. Four paths, one answer.]
  #v(14pt)
  #comparison(columns: (1.6fr, 1.2fr, .55fr),
    [*Path on EMP*], [*Arithmetic*], [*Cost*],
    [Segment scan: read every page], [`500`], [*500*],
    [DNO clustered index, no match], [`50 + 500`], [550],
    [SAL index, matches the predicate], [`1/4 × (40 + 10,000)`], [2,510],
    [JOB index, no match], [`50 + 10,000`], [10,050],
  )
  #takeaway[The matching index costs 5× the scan: it pays per row, not per page.]
  #caption[On the running query nothing matches: the four cost 500, 550, 10,040, 10,050.]
]
// 73
#lecture-slide(source: [§5: computing the cost of joins], notes: [Optional, 1 minute. The third card, and the one that needs the reversal said out loud. Both methods cost the outer path plus one inner pass per surviving outer row, so the whole contest is what one inner pass costs. Nested loops are rule 2's lookups; merge scan is the merge join of slide 39. On this pair the merge loses, and not because merging is slow: its outer input, EMP in DNO order, costs 550 by itself before any merging starts, while a DEPT scan costs five. EMP outside with lookups is worse still, 20,500, because all 10,000 EMP rows look DEPT up; that is 342 times the 60. One level up the same comparison flips, because the composite is only 1,000 rows: sorting it costs 100 and the merge's inner is one 3-page pass of JOB, 1 index page and 2 data pages, against 1,000 lookups of two pages each, 2,000. So the merge loses by 557 − 60 = 497 on the pair and wins by 2,000 − 103 = 1,897 on the triple, and the answer to which join method is neither, until the data is known. Derived on slides 36 to 41, with the reversal on slide 52 and every pair plan on slide 81. Illustrative costs in page fetches, not measurements.])[Appendix: which join method][
  #small[Two join methods, three plans for the pair. Each returns the same 1,000 EMP-DEPT pairs.]
  #v(14pt)
  #comparison(columns: (1.7fr, 1.1fr, .55fr),
    [*Plan for the pair*], [*Arithmetic*], [*Cost*],
    [Nested loops: read DEPT, look up EMP], [`5 + 10 × 5.5`], [*60*],
    [Nested loops: read EMP, look up DEPT], [`500 + 10,000 × 2`], [20,500],
    [Merge scan: walk both in DNO order], [`550 + 7`], [557],
  )
  #takeaway[Merge loses by 497 on this pair, wins by 1,897 once JOB is added.]
  #caption[Merging is cheap. Getting EMP into DNO order costs 550 before it starts; one pass of DEPT, 7.\
  Once JOB is added, sorting the 1,000 pairs and merging costs 100 + 3, against 1,000 × 2 to look JOB up.]
]
// 74
#lecture-slide(source: [§4: interesting order; §5: merging scans], notes: [Optional, 1 minute. The fourth card. A sort is never free and is sometimes the cheapest thing on the slide, so the question is only ever what the resulting order is worth above it. Row one is the winning plan's sort and it is the best bargain in the lecture: 100 pages turn 2,000 pages of JOB lookups into a 3-page merge. Row two is the same trick on the pair of the other branch, 20 pages that save 373. Row three is the same trick refusing to pay: 10,000 rows cost 1,000 to sort on top of the 500-page scan, while reading EMP through its clustered DNO index arrives sorted for 50 more than the scan, so sorting loses by 950 and the ordered path is kept instead. That is slide 46's comparison: EMP comes in DNO order through its clustered DNO index for 550, the 500 data pages plus the index's own 50. A plain segment scan promises no order at all, so the ordered path is the index, never the scan. Nothing about the operation changed between row one and row three; only the row count did. Note the convention, because it is ours and not the paper's: sorting Q rows costs two passes at 20 rows per page, one out and one back, and the paper gives no sort-production formula at all. Derived on slides 46 and 52. Illustrative costs in page fetches, not measurements.])[Appendix: sort, or never sort][
  #small[Sorting Q rows costs 2 × ceil(Q / 20) page fetches, out and back at 20 rows per page.]
  #v(14pt)
  #comparison(columns: (1.6fr, .65fr, 1.2fr, .5fr),
    [*What is sorted*], [*With a sort*], [*Instead of*], [*Saves*],
    [1,000 EMP-DEPT rows, on JOB], [100 + 3], [1,000 × 2 to look up JOB], [*1,897*],
    [200 EMP-JOB rows, on DNO], [20 + 7], [200 × 2 to look up DEPT], [373],
    [10,000 EMP rows, on DNO], [500 + 1,000], [550 via the DNO index], [−950],
  )
  #takeaway[The same sort saves 1,897 on 1,000 rows and loses 950 on 10,000.]
  #caption[Each saving is the subtraction beside it: 2,000 − 103, 400 − 27, 550 − 1,500.\ Row three must scan EMP for 500 before it can sort.]
]
// The rule book of slide 12 priced on the paper's own query. The figure holds its
// numbers back until the reveal, so the room commits to a guess first.
// 75
#lecture-slide(source: [§4, §5], notes: [Optional, 2 minutes. Two clicks: the two plan shapes with every cost held back, then the costs and the verdict. The rule book from slide 12, priced on the paper's own query; it sits here because it quotes costs the core route derives only later. Show the two plan shapes and make the room commit to a guess before the reveal. The rules, as worded on slide 12: always use an index if one exists; always join in FROM order. FROM order puts EMP first, and the paper's WHERE clause gives EMP no predicate an index could match, so it is scanned: 500 pages, 10,000 rows. Rule 1 then fires on each join. Every EMP row looks DEPT up through its unique DNO index, 10,000 × 2 = 20,000, running total 20,500, and 1,000 pairs survive LOC. Each pair looks JOB up through its unique index, 1,000 × 2 = 2,000, total 22,500, and 20 rows survive TITLE. The winner is 163, so 22,500 / 163 = 138. The rule book is not stupid, every individual rule is defensible, and it still loses by two orders of magnitude. The winning plan on the right is derived on slides 51 to 53; do not explain it here. Our arithmetic for both plans, not a cost the paper computes.])[Appendix: the bill for the rule book][
  #alternatives[#rule-vs-cost(stage: 1)][#rule-vs-cost(stage: 2)]
  What does the rule book cost, against the best plan?
  #uncover("2-")[
    #takeaway[22,500 page fetches against 163. A factor of 138.]
  ]
]
// The right column of the previous figure was unfolded on slide 69; this is the
// left one, term by term and in the same shape, because the figure's node labels are
// running totals and a reader cannot tell 20,500 from a new cost.
// 76
#lecture-slide(source: [§4, §5], notes: [Optional, 1 minute. The left column of the previous figure, unfolded exactly as slide 69 unfolded the right one, and worth the minute because the figure's labels are running totals: the 20,500 inside 22,500 is not a new cost, it is the step below being carried up. Read the three terms. First, 500 reads EMP by a segment scan: rule 2 puts EMP first, and nothing in the paper's WHERE clause filters EMP, so rule 1 has no predicate for an index to match, and all 10,000 rows come out. Second, those 10,000 rows each drive one lookup of DEPT on DNO, a unique index at one index page plus one data page, so 20,000. Say the sting out loud: only 1,000 of those 10,000 lookups find a Denver department, and all 10,000 are paid for, because the lookup is driven by the outer row's DNO value and LOC can only be tested once the DEPT row is in hand. DEPT does have a LOC index, but it is on the wrong column for this lookup. Third, the 1,000 pairs each look JOB up on its unique index, another 2 apiece, 2,000 in all, and 20 rows come out. Then the decomposition, which is the real payoff: the FROM order adds 20,500 − 60 = 20,440 on the first pair, the same 20,440 slide 45 uses; looking JOB up instead of sorting the composite and merging adds 2,000 − 103 = 1,897, the saving slide 74 priced. Those two add to 22,337, which is exactly 22,500 − 163, so the gap is fully accounted for and nothing is hand-waved. Note what is missing: rule 1 costs nothing extra on this query, because EMP has no predicate for it to misuse; its breaking case is the one-table query of slide 14 and slide 72. Our arithmetic, not a cost the paper computes.])[Appendix: where 22,500 comes from][
  #small[The rule book's plan, one term at a time. Each node totals everything beneath it.]
  #v(14pt)
  #comparison(columns: (.75fr, 2.75fr, .7fr),
    [*Term*], [*What it pays for*], [*Rows out*],
    [`500`], [read EMP first, by a scan: no predicate for an index], [10,000],
    [`10,000 × 2`], [one DEPT lookup per EMP row, `1 + 1` on a unique index], [1,000],
    [`1,000 × 2`], [one JOB lookup per pair, `1 + 1` again, not a sort], [20],
  )
  #takeaway[500 + 20,000 + 2,000 = 22,500 page fetches, for the same 20 rows.]
  #caption[All 10,000 lookups are paid for, because they match on DNO, not LOC; only 1,000 find a Denver row.\
  The FROM order’s first pair adds 20,440 (20,500 − 60); looking JOB up instead of sorting adds 1,897.\
  Together 22,337 = 22,500 − 163.]
]
// 77
#lecture-slide(source: [§4, Table 1], notes: [Optional, 2 minutes. The four constants are 1/10 for an equality without an index, 1/4 for BETWEEN, 1/3 for an open-ended range, and 1/2 as both the IN cap and the ceiling the others sit under. These are the rows the core route abridged on slide 23, and the only place the paper shows a derivation. The range row has two conditions: the column must be arithmetic, and the value must be known when the plan is chosen; a host variable in a compiled program is not, so the 1/3 guess is used instead of interpolation. For column1 = column2 with an index on only one side, the paper uses one over that index's distinct values; with no index on either side, 1/10. For columnA IN subquery: assume the subquery column's values contain the outer column's values, so if the whole subquery table is selected the predicate is always true and F = 1; if the subquery is restricted, assume the matching values are restricted in proportion, so F is the subquery's own fraction, its result rows over the product of its tables' rows. The paper then extends this to subqueries that are joins and to arithmetic expressions with a little optimism, its words. That containment assumption is the principle of inclusion, which Leis names as one of the three assumptions still in force. The paper prints ICARD where this slide says distinct, and QCARD and NCARD in the subquery row; slide 20 has the mapping.])[Appendix: Table 1 in full][
  #comparison(columns: (.9fr, 2.3fr),
    [*Predicate*], [*Selectivity factor F*],
    [`col = v`], [1 / distinct(col) with an index on col, else *1/10*],
    [`col1 = col2`], [1 / the larger distinct; one index: 1 / its distinct; else *1/10*],
    [`col > v`], [(high − v) / (high − low) if numeric, v known; else *1/3*],
    [`col BETWEEN a AND b`], [(b − a) / (high − low) on the same condition, else *1/4*],
    [`col IN (list)`], [n × F(col = v), capped at 1/2],
    [`col IN subquery`], [the subquery’s result_rows / the product of its tables’ rows],
  )
  #v(18pt)
  #small[AND is F1 × F2 · OR is F1 + F2 − F1 × F2 · NOT is 1 − F]
]
// 78
#lecture-slide(source: [§4, Table 2 and its accompanying paragraph], notes: [Optional, 2 minutes. The third panel of the slide 31 and 32 pair, and the honest footnote to slide 33. The alternative charges pages instead of rows on the grounds that the fetched pages stay resident, which is literally the same substitution that makes a clustered index cheap, so the buffer-fit non-clustered index behaves like a clustered one: 1/4 × (40 + 500) = 135, which now beats the 500-page scan. Do not sharpen the condition: the paper prints if this number fits in the System R buffer, and the surrounding prose speaks of whether the set of tuples retrieved will fit entirely in the RSS buffer pool, or effective buffer pool per user; the RSS is System R's storage layer, pictured on slide 79. Note that Table 2 gives no buffer-fit alternative for clustered rows, because there is nothing to gain, and that the decision rests on a buffer size the optimizer knows only approximately. On our statistics it also flips a core-deck pruning: DEPT's LOC index costs 1/10 × (2 + 5) = 0.7 under the buffer-fit formula and would beat the five-page scan. The core deck uses the no-fit formulas everywhere so that there is one rule.])[Appendix: the buffer-fit alternative][
  #small[Pages that fit in the buffer are fetched once, so Table 2 charges pages, not rows: 135 beats 500.]
  #v(14pt)
  #buffer-rescue-g()
  #takeaway[The buffer-fit formula is the clustered formula: one rectangle changes it.]
]
// The paper's CPU term, for readers of the paper. Slide 19's note names it once and
// drops it; this card keeps the rest: the two-layer picture that defines an RSI call (C's
// rss-rsi-c figure), the weight W, and in the notes the made-up timings and the two plans
// that W can flip. Every other cost in the deck is page fetches only.
// 79
#lecture-slide(source: [§3: the RSS, the RSI and search arguments; §4: the cost formula and the weighting factor W; PostgreSQL documentation, cpu_tuple_cost], notes: [Optional, 2 minutes. The paper's full cost formula, for anyone who reads the paper: slide 19's approximate sign stands for the second term, which its note names and drops, and this card is the rest of the story. System R has two layers. Below the line, the RSS, the Research Storage System, keeps the tables and indexes on disk. Above it, the compiled plan runs the joins, the sorts, and any predicate the RSS cannot test itself. The plan never touches a page: it opens a scan through the RSS's interface, the RSI, and calls NEXT, and each call passes one row up; that crossing, in red, is one RSI call. Point at the RSS box: one call can do a lot of work below the line. The RSS reads pages as needed and tests each row against the search arguments of slide 29, skipping rows that fail until one passes, so a rejected row costs page reads but no call. Why count calls and not instructions: instructions are hard to predict before the plan runs, rows passed up are easy, because selectivity gives them; and the paper's argument that the count is a fair stand-in is that most of System R's CPU time is spent inside the RSS. W is the exchange rate that lets the two terms be added: one call costs W page fetches. Do it with made-up timings: a page fetch of 10 ms and a call of 0.1 ms make W = 0.1 / 10 = 0.01, so 100 calls cost one page. The one-table query SAL > 20000 then costs 500 + 2,500 × 0.01 = 500 + 25 = 525 by a scan, 2,500 calls for the 2,500 rows it passes up, and 500 of the 525 is I/O. W matters only when one plan saves I/O by spending CPU, so take two made-up plans: A reads 100 pages and makes 10,000 calls, B reads 150 pages and makes 1,000. At W = 0.01, A costs 100 + 100 = 200 and B costs 150 + 10 = 160, so B wins. Make the CPU ten times faster, W = 0.001: A costs 100 + 10 = 110 and B costs 150 + 1 = 151, so A wins. Same query, same data, same two plans; only the machine changed. So W belongs to the machine, not the query: a setting, not something the optimizer computes. PostgreSQL's cpu_tuple_cost is the same knob, default 0.01 of a sequential page fetch, whose own cost, seq_page_cost, is 1.0. Then why the deck counts pages only: the paper gives W no value, and on one table every path applies the same search arguments and passes up the same rows, so W × calls is the same on each and cannot change the winner. Between join plans the call counts do differ, and we drop the term anyway, for want of a W to put in it. The timings and both plans are made up to show the arithmetic.])[Appendix: the CPU term][
  #small[System R adds a CPU term: `COST = PAGE FETCHES + W × RSI CALLS`, W a machine weight.]
  #v(14pt)
  #rss-rsi-c()
  #caption[W prices a call in page fetches (say 10 ms a fetch, 0.1 ms a call: W = 0.01); no real value is published.\
  On one table every path passes up the same rows, so the term is the same for all. We count pages only.]
]
// 80
#lecture-slide(source: [§4, Table 2], notes: [Optional, 1 minute. For students who want to redo the deck with a calculator. Ten paths, three tables, every cost from slide 21. On the running query EMP has no predicate, so none of its indexes matches anything and each index path reads the whole index and then the whole table: the clustered DNO index 50 + 500, the non-clustered JOB and SAL indexes one fetch per row, 50 + 10,000 and 40 + 10,000. The DNO and JOB paths are kept for their orders, which the joins want; SAL order is wanted by nothing, so 10,040 is pruned. DEPT's scan tests LOC as a search argument and JOB's clustered index tests TITLE the same way. Note the small repeat of slide 33 here: DEPT's index on its own filter column costs 10.2 and loses to a five-page scan. JOB's segment scan reads its two pages for 2, the same as the TITLE index: a tie between two unordered paths, so the search keeps one, the TITLE index, and strikes the scan; a JOB-first plan through the scan would cost the same 2 + 201 = 203, so nothing above it changes. Reconstruct the crossing rule once more on the one-table query: a non-clustered index beats the scan exactly when `F × (index_pages + rows)` is less than `pages`, so for EMP's SAL index whenever fewer than about 498 of its 10,000 rows qualify, slide 34. All illustrative: the paper computes no costs anywhere.])[Appendix: every single-table path][
  #comparison(columns: (.45fr, 1.5fr, 1.15fr, 1fr),
    [*T*], [*Path*], [*Arithmetic*], [*Pages*],
    [EMP], [scan · DNO clustered ·\ JOB · SAL], [`500` · `50+500` ·\ `50+10,000` · `40+10,000`], [*500* · *550* ·\ *10,050* · 10,040],
    [DEPT], [scan · DNO clustered unique ·\ LOC matching], [`5` · `2+5` ·\ `1/10 × (2+100)`], [*5* · *7* ·\ 10.2],
    [JOB], [TITLE unique equality ·\ JOB clustered · scan], [`1+1` ·\ `1+2` · `2`], [*2* ·\ *3* · 2, a tie],
  )
  #v(18pt)
  #small[Bold costs are kept: the cheapest path, and the cheapest in each useful order.]
  #caption[Ten paths, seven kept. No EMP index matches: EMP has no predicate.\
  JOB's scan ties its TITLE index at 2, both unordered; the search keeps one, the index.]
]
// 81
#lecture-slide(source: [§5], notes: [Optional, 1 minute. The twenty costs behind slides 51 and 52. Each pair prices seven plans and keeps three: the cheapest unordered and the cheapest in each interesting order. Point at the candidates slide 51's panels priced two to a line: the EMP-JOB merge through EMP's JOB index, 10,050 + 3 = 10,053, and the EMP-JOB plan with EMP outside through its JOB index, 10,050 + 10,000 × 2 = 30,050; the EMP-DEPT merge that scans EMP and sorts it, 500 + 1,000 + 7 = 1,507, is the one slide 46 derives. The two dear kept entries, 30,050 and 20,550, exist only because of their order: they produce the same rows as the 60 and the 203 in their own subsets, and the triple discards both, at 30,053 and 20,557. Every nested-loop pair cost is the outer path's cost from slide 80 plus `outer_rows` times one inner lookup: 5.5 pages through EMP's clustered DNO index, 201 through its non-clustered JOB index, 2 through either unique index. The four merges instead cost an ordered EMP plus one pass of the inner, 7 for DEPT or 3 for JOB, where the ordered EMP is 550 through the DNO index, 10,050 through the JOB index, or the 500 scan plus 1,000 to sort it. {DEPT, JOB} is never entered: it has no join predicate. Sort cost is our own convention, 2 × ceil(Q / 20), out and back at 20 rows per page. All illustrative: the paper computes no costs anywhere.])[Appendix: every join plan priced][
  #comparison(columns: (.6fr, 1.7fr, 1.7fr),
    [*Set*], [*Kept, one per order*], [*Priced, then pruned*],
    [{E,D}], [*60* · *62* DNO · *30,050* JOB], [557 · 1,507 · 20,500 · 20,550],
    [{E,J}], [*203* · *204* JOB · *20,550* DNO], [1,503 · 10,053 · 20,500 · 30,050],
    [{E,D,J}], [*163* = 60 + 100 + 3], [230 · 603 · 2,060 · 20,557 · 30,053],
  )
  #v(18pt)
  #small[Fourteen pair plans and six triple plans, each `C = C_outer + outer_rows × C_inner` over the single-table paths or a sorted input; `outer_rows` is 10 for DEPT, 1 for JOB, 10,000 for EMP.]
  #v(18pt)
  #small[Lookups: EMP by DNO `1/100 × (50+500) = 5.5` · unique index `1 + 1 = 2` ·\ EMP by JOB `1/50 × (50+10,000) = 201`.]
  #v(6pt)
  #caption[A sort of Q rows adds 2 × ceil(Q / 20). Twenty costs, three subsets, one plan. All illustrative.]
]
// 82
#lecture-slide(source: [Leis, VLDB Journal 27(5), 2018, Table 4], notes: [Optional, 2 minutes. The honest version of "dynamic programming still beats heuristics". With primary-key indexes only, a greedy heuristic edges it at the median, 1.01 against 1.03, because with wrong estimates an exhaustive search optimizes the wrong objective more thoroughly; its advantage is in the tails and in rich physical designs. The authors' own register is moderate but not insignificant, and they immediately add that the performance potential from good cardinality estimates is certainly much larger. The real argument for keeping the exhaustive search is that it is cheap, since exhaustive algorithms solve dozens of tables quickly, so there is no reason to give up the tail protection. Note too that index-awareness matters as much as exhaustiveness: the two heuristics that consider indexes beat the one that ignores them. The 2015 conference version's plan-enumeration tables were withdrawn; these are the 2018 journal figures. DBMS A, B and C are anonymised commercial systems; no per-system number here names a product. Reference: https://ir.cwi.nl/pub/27562/27562.pdf])[Appendix: DP against the heuristics][
  #small[Every algorithm plans from PostgreSQL's estimates, then runs for real, so even exhaustive search lands at 1.42×: it optimizes the wrong objective more thoroughly. PK and FK indexes.]
  #v(14pt)
  #comparison(columns: (1.7fr, .9fr, .9fr, .9fr),
    [*Algorithm*], [*Median*], [*95th*], [*Max*],
    [*Dynamic programming*], [*1.42*], [*15.3*], [*35.3*],
    [Quickpick: best of 1,000 orders], [2.10], [77.6], [3,303],
    [Greedy, minimum cardinality], [1.84], [34.1], [766],
    [Greedy, minimum cost], [2.04], [20.3], [136],
  )
  #takeaway[Exhaustive search wins in the tail, which is where the timeouts live.]
  #caption[VLDB Journal 2018, Table 4. With primary keys only, a greedy median of 1.01 beats DP's 1.03.]
]
// 83
#lecture-slide(source: [§5: equivalence classes], notes: [Optional, 1 minute. The implementation detail that keeps the search table from blowing up on long join chains. Because the number of stored solutions is 2 to the n times the number of interesting orders, collapsing syntactically distinct join columns into one class shrinks the table directly, and one saved plan then covers the whole class. F here is a third, hypothetical table; the running query has two classes, EMP.DNO with DEPT.DNO and EMP.JOB with JOB.JOB.])[Appendix: order equivalence classes][
  #equivalence-class()
  #takeaway[E.DNO = D.DNO and D.DNO = F.DNO put all three columns in one class.]
  #caption[Exact, not a heuristic: equality is transitive. F is a third table; our query has two classes.]
]
// 84
#lecture-slide(source: [§5, §7; Leis 2015 §2; Ioannidis, VLDB 2003; PostgreSQL 8.3 release notes], notes: [Optional, 2 minutes. The lecture notes' list, with dates: hash join, histograms, bushy plans, parallel plans, re-optimizing when estimates turn out wrong, and plan caching that notices data changed. Sampling is the one addition worth naming aloud, since it is now the usual basis for statistics: Lipton, Naughton and Schneider, 1990. The gap between a good idea and a shipped feature is decades: bushy enumeration reached one major commercial optimizer about thirty-five years after Selinger. LEO's negative lesson is the best material here, because learning true cardinalities from execution feedback can make the plans you did not run look better than they are, since they are still estimated by an underestimating model; the retrospective calls it fleeing from knowledge to ignorance. What shipped widely is narrower and operator-level: switching a join algorithm or a distribution strategy at runtime. The last row is the notes' plan caching that notices data changed: System R did precompile and store access modules, described by Chamberlin et al. in 1981, but this deck claims nothing about how a stored plan was invalidated when the catalog changed, because that mechanism is not sourced here; the row gives only a shipped example, PostgreSQL 8.3, whose release notes list automatically re-planning cached queries when table definitions change or statistics are updated (https://www.postgresql.org/docs/release/8.3.0/). Research dates are first publication, not adoption. Postgres 8.3 and 9.6 are the releases that shipped the feature; 9.4 is different, only the release Leis 2015 tested, and Postgres's subset search considered bushy joins well before it, so read "by 9.4" as "at the latest". Hybrid hash is DeWitt and colleagues, SIGMOD 1984; Shapiro's 1986 TODS paper is the later analysis.])[Appendix: what 1979 did not have][
  #comparison(columns: (.9fr, 2.1fr),
    [*Missing in 1979*], [*When it arrived*],
    [Hash join], [GRACE hash join, 1983; hybrid hash, DeWitt et al. 1984],
    [Histograms], [Equi-width, Kooi 1980; equi-depth, Piatetsky-Shapiro 1984],
    [Bushy plans], [Postgres by 9.4; one major commercial engine only in 2014],
    [Parallel plans], [Volcano's exchange operator, 1990; Postgres 9.6, 2016],
    [Re-optimization], [Kabra and DeWitt 1998; LEO 2001; shipped only per operator],
    [Stale-plan checks], [Postgres 8.3, 2008: re-plans a cached query on new statistics],
  )
  #caption[Research dates are first publication. Postgres 8.3 and 9.6 are the releases that shipped the feature;\
  9.4 is only the release Leis tested, not the one that added bushy plans.]
]
// 85
#lecture-slide(source: [Discussion based on §4–§6], notes: [Optional, 1 minute. Five of the thirteen questions in the lecture notes; use them as an exit ticket or the first five minutes of the next class. Question 5 draws on the appendix's 2015 re-run, slides 61 to 65 and 82, so skip it if the class stopped at the recap. Answers. One: the one-table query SAL > 20000 on EMP; the two statistics are pages and rows, 500 against 10,000, because the scattered SAL index pays a fetch per qualifying row, 1/4 × (40 + 10,000) = 2,510, while the scan pays per page, 500; slides 14 and 33. Two: pages becomes rows; clustered rows share pages, so each page is fetched once, while a non-clustered index's neighbouring entries point at different pages, so each row costs a fetch and a page can come back many times; the buffer-fit exception is slide 78. Three: the exchange argument of slide 45, since adding JOB costs the same whatever built the {EMP, DEPT} composite, so every total falls by the same 20,440 when the 60 plan replaces the 20,500 one; it needs per interesting order because a dearer plan can deliver an order the next merge wants, 557 against 1,507 on slide 46. Four: an underestimate, tenfold on slide 26's table, because the ZIP factor rejects nobody the LOC factor kept, so multiplying divides by ten twice where reality divides once. Five: the enumeration survived, though its left-deep space had to widen, slide 64, and the statistics did not; with bad estimates DP still avoids the catastrophic plans that heuristics find, and it is cheap, slide 82. The other eight, briefly. Every output row satisfies every boolean factor, so a factor can run as early as you like, and pushdown killed strawman 1. Cost is counted in pages because a disk read brings a whole page, so rows matter only through the pages they touch. Counted in rows, rule 1 would always look right, 2,500 rows found by the SAL index against 10,000 read by the scan; counted in pages, the scattered index pays about a page per row, 2,510 against 500, slides 19 and 32. A sargable predicate has the form column op value: a scan tests it as it reads, so failing rows cost no extra page, and an index whose key starts with that column uses it to start and stop its range; column = column inside one table is not sargable, slide 29. An interesting order is one that ORDER BY, GROUP BY or a join column wants, kept because fifty pages can save 950, slide 46. Nested loops and merge scan share `C = C_outer + outer_rows × C_inner`, and merge wins when one pass is cheaper than many lookups, 100 + 3 against 2,000. Left-deep rules out joining two composites, and buys index lookups on a base-table inner, pipelining and a smaller search. A cross product is unavoidable only when the join graph is disconnected. A correlated subquery is secretly a nested-loop join with the outer block as the outer.])[Appendix: questions to review][
  #set enum(spacing: 1em)
  + Give a query where "use the index" is wrong. Which two statistics say so?
  + Clustered or not: which statistic switches from pages to rows, and why?
  + Why can the best plan for {EMP, DEPT, JOB} be built from the best plans for its 2-subsets? Where does that need "per useful order"?
  + Correlated LOC and ZIP, factors multiplied: over- or underestimate?
  + Leis 2015: if the cost model is crude and the estimates are bad, why does exhaustive DP still help?
  #v(14pt)
  #caption[Five of the thirteen review questions at the end of the lecture notes.]
]
