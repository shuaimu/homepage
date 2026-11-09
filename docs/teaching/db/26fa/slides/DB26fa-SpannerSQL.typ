// CSE 532, Fall 2026. November 4, 2026.
// typst compile DB26fa-SpannerSQL.typ
// typst compile --input handout=true DB26fa-SpannerSQL.typ DB26fa-SpannerSQL-handout.pdf
// Follows ../notes/spanner-sql.md section by section. The shard map, the arrays, the
// batch, the Documents version counts and the restart traces are illustrative; the paper gives none.
#import "@preview/touying:0.7.4": *
#import "spannersql-theme.typ": *
#import "spannersql-diagrams.typ": *
#show: lecture-theme

// 1
#lecture-slide(source: [§1], notes: [1 minute. Seventeen authors from Google, SIGMOD 2017. This is the database half of Spanner's story, five years after the OSDI 2012 paper we read on Oct 19, which was the systems half: sharding, replication and transactions across datacenters. Continuity from last time: System R chose a plan for one machine and counted page fetches. Today the same SQL runs on tables cut into key ranges spread over datacenters, the ranges move while queries read them, and what a plan must avoid is calls between machines. As before, we re-derive the design rather than describe it: every mechanism arrives as the answer to a failure we have just watched. One running query, the paper's Figure 1, carries the first half; a second query, through a secondary index, carries the joins; the paper's Documents example carries range extraction, working out which keys a predicate can touch; and one long scan carries restarts, resuming a query after a failure. Each example's data is ours unless a later note says it is the paper's.])[Spanner SQL][
  #v(32pt)
  CSE 532 · Database Systems\
  November 4, 2026
  #v(35pt)
  #text(size: 19pt, fill: muted)[Bacon, Bales, Bruno, Cooper, Dickinson, Fikes, Fraser, Gubarev, Joshi, Kogan,\ Lloyd, Melnik, Rao, Shue, Taylor, van der Holst, and Woodford (Google)\ _Spanner: Becoming a SQL System_ · SIGMOD 2017]
]
// 2
#lecture-slide(source: [§1], notes: [1 minute. Three states, one bullet per click; the takeaway arrives with the last. Why the paper exists. Spanner started as a key-value store: in the paper's words NoSQL methods for point lookups and range scans, plus multi-row transactions and reads at a timestamp. By the 2012 paper it already had schematized tables, interleaving, which stores a child table's rows inside its parent's, and a SQL-based query language, so SQL is not new here; what is new is how deep it goes. Google developers on Bigtable lacked a schema, cross-row transactions, consistent replication and a real query language. Megastore put transactions on top of Bigtable but still had no robust query language, so application code did its own joins and aggregations. The workload is both kinds at once: OLTP, point lookups and small joins in milliseconds, and analytics, long scans and aggregations taking seconds to hours. Say aloud, since the slide no longer shows it: the first query engine was bolted on, using high-level APIs like an external application. That is the paper's own confession about its first version, and it sets up the choice on slide 4: SQL bolted on beside the store, or built into it. First, the next slide lines this lecture up against last time's.])[Why Spanner became a SQL system][
  - Spanner began as a key-value store: point lookups, range scans, multi-row transactions, reads at a timestamp.
  #pause
  - On Bigtable, Google's earlier key-value store, developers lacked a schema, cross-row transactions and a query language, so their code did its own joins and aggregations.
  #pause
  - Wanted: one system for transactions (OLTP), in milliseconds,\ and analytics, in seconds to hours.
  #takeaway[Turn a scalable key-value store into a full SQL database.]
]
// 3
#lecture-slide(source: [§1, §2], notes: [2 minutes. Five states: the System R column alone, then Spanner's side one row per click. The bridge from last time, one row at a time. Data: System R's tables sat on one machine's disk; Spanner's are cut into key ranges, shards, each replicated across datacenters. Cost: last time we counted page fetches; today the expensive thing is a call to another machine and the rows it ships back. Last lecture's recap promised that the cost measure would grow a network term and a shard fan-out term; slide 14 says honestly what the paper does with that, which is less than you might expect. When the plan is fixed: System R fixed everything at compile time; Spanner fixes what to run on each piece of a table at compile time and decides which pieces, and on which servers, at run time. That split is the first half of the lecture. A failure: in System R a crash mid-query simply fails it; Spanner's queries at one timestamp resume where they stopped, which is the last part of the lecture. The storage, replication and transactions underneath are the Oct 19 lecture; we recall only what we need, on slide 6.])[From one machine to many][
  #v(6pt)
  #let rows = (
    ([Data], [one machine's disk], [key ranges (*shards*) across datacenters]),
    ([Cost], [page fetches], [calls between machines, rows shipped]),
    ([Plan], [fixed at compile time], [which shards, and where: at run time]),
    ([Failure], [the query fails], [a query at one timestamp resumes]),
  )
  #alternatives(..range(5).map(k => comparison(columns: (.8fr, 1.4fr, 2.2fr),
    [], [*System R, last time*], [*Spanner SQL, today*],
    ..rows.enumerate().map(((i, r)) => (r.at(0), r.at(1), if i < k { r.at(2) } else { [] })).flatten())))
]
// 4
#lecture-slide(source: [§1; §9], notes: [2 minutes. Two states: SQL beside the store, then SQL inside it, with the takeaway and the TiDB caption. Two ways to add SQL to a store like this. Loosely coupled, left: SQL is a separate service on its own servers, talking to storage through its API, which here means key-range reads, and the rows come up to the SQL tier. F1, the AdWords database from 2012, did exactly that over Spanner. Tightly coupled, right: the compiler and executor live inside the Spanner servers, so the SQL layer knows where the shards are, how they are replicated, and how they move; a server that receives a query ships subplans to the servers holding the data. That is this paper. TiDB, Aug 31, sits in between: its SQL layer runs in its own processes, but it ships single-table plan pieces, filters, aggregates and top-N, into TiKV, its key-value storage layer, and the rest runs in the SQL layer; that pushdown is in the TiDB paper, not in our notes on it. Then the point of the paper in one sentence: making it tight changed both sides. How Spanner stores data changed how queries run, which is distribution, range extraction and restarts, today's core; and what queries need changed how Spanner stores data, which is Ressi, its new storage format, in the lecture notes. Do not oversell tight coupling: the paper's own verdict, in its conclusions, is that both designs work.])[Two ways to add SQL][
  #alternatives[#coupling(step: 1)][#coupling(step: 2)]
  #uncover("2-")[
    #takeaway[Spanner SQL is the tight design: SQL that knows where the shards are.]
    #caption[TiDB (Aug 31) sits in between: its SQL processes ship single-table plan pieces into its store, TiKV.]
  ]
]

// Section divider: what Spanner gives the query processor.
// 5
#lecture-slide(section: true, notes: [0 minutes. What Spanner already does, from Oct 19, and two things new today: shards move, and a child table can be stored inside its parent.])[Revisit Spanner][]
// 6
#lecture-slide(source: [§2; Oct 19 notes], notes: [2 minutes. The shard map every example today uses; tell the class to photograph it. From Oct 19: rows are sorted by primary key and cut into contiguous key ranges, shards, which are TiDB's Regions, Aug 31, under another name. Each shard belongs to one Paxos group, and the group's replicas sit in different datacenters. In Spanner a group holds many shards: here G1 holds S1 and S3, which backup slide 46 uses. In TiDB a Region is its own Raft group, and a Mako shard, Oct 21, its own Paxos group. So keep the two words apart: a shard is a unit of key range, a Paxos group is a unit of replication. Two more things from Oct 19 that come back later, said aloud because the slide does not print them. Read-write transactions use two-phase locking and two-phase commit, and a wound-wait abort, Oct 19's deadlock-avoidance rule, in which an older transaction aborts a younger one holding a lock it wants, already makes the client retry. Reads at a timestamp take no locks: a strong read at the current time, TT.now().latest, the top of TrueTime's uncertainty interval, or a stale read at an older timestamp the client picks, served by any replica whose t_safe, the time up to which it is known to be up to date, has passed that timestamp; the paper calls both snapshot reads. Restarts, at the end of the hour, lean on exactly this. Then the first thing new today, said aloud because no slide shows it: Spanner splits, merges and moves shards between Paxos groups to balance load, at any time, even while a query is reading them, and nothing tells the query; calls are addressed to key ranges, and the coprocessor framework finds whoever owns the range now. Strawman 2, slide 11, fails because of it. Our map, not the paper's: four shards at 250, 500 and 750, three groups.])[Shards and Paxos groups][
  #small[Rows sorted by key are cut into key ranges, *shards*; each lives in one *Paxos group*.]
  #v(10pt)
  #shard-groups()
  #caption[A shard is a unit of key range; a Paxos group, a unit of replication. Every example uses this map.]
]
// 7
#lecture-slide(source: [§2; §3.1: interleaving], notes: [2 minutes. The second new thing, interleaving, already in the 2012 paper as INTERLEAVE IN PARENT. A child table can be stored inside its parent. Sales' primary key starts with its parent's key, ckey, so in key order each customer is followed by its own sales, as the figure shows. Shard boundaries fall between parent keys, so a customer and all of its sales sit in one shard: the paper says boundaries preserve row co-location, and the rules for which operators can run shard by shard, slides 15 to 19, rely on it. The key prefix that boundaries are cut on is the sharding key, here ckey; it can be several columns, and an interleaved child uses its parent's. Then the link to last time: this is a physical design choice exactly like last lecture's EMP table stored in department-number (DNO) order. The schema author decides what sits together, and some plans become cheap because of it; on slide 19 the Customer–Sales join becomes free of network calls for exactly this reason. The boundary at 249 and 250 is our map's S1 and S2.])[Interleaving: a child inside its parent][
  #grid(columns: (1fr, 400pt), column-gutter: 30pt,
    [
      #sql(size: 22pt)[```
CREATE TABLE Customer (
  ckey INT64, name STRING, city STRING
) PRIMARY KEY (ckey)
CREATE TABLE Sales (
  ckey INT64, skey INT64,
  type STRING, amount INT64
) PRIMARY KEY (ckey, skey),
  INTERLEAVE IN PARENT Customer
```]
      #small[A child's key starts with its parent's, so they sort together. `ckey` is the *sharding key*: shard boundaries are cut on it.]
    ],
    interleaved-rows(),
  )
  #takeaway[A customer and all its sales sit in one shard.]
]

// Section divider: the running query, then two ways that do not work.
// 8
#lecture-slide(section: true, notes: [0 minutes. The paper's running query and two obvious ways to run it on many machines, each of which fails for a reason worth remembering.])[Example Query][]
// 9
#lecture-slide(source: [§3.1, Figure 1], notes: [2 minutes. Two states: the query, then what it does in words. The paper's Figure 1 query; we call it Q1, and the whole first half runs on it. Read it as English: the five customers, out of a list passed in, with the most global sales. Three details. The array, customer_key_arr, written \@arr from now on, is a query parameter: the plan is compiled once, cached, and run many times with different arrays, so the compiler never sees the array; hold on to that, because it kills strawman 2. UNNEST turns the array into rows, so c.ckey IN UNNEST(\@arr) means ckey is one of the array's elements. ANY_VALUE(c.name): all rows with one ckey are one customer and share a name, so take any of them. The join is on the whole sharding key, which matters on slide 19. Customer is sharded on ckey and Sales is interleaved in it, so Sales shares the sharding key.])[Q1: the running query][
  #sql(size: 28pt)[```
SELECT ANY_VALUE(c.name) AS name, SUM(s.amount) AS total
FROM   Customer c JOIN Sales s ON c.ckey = s.ckey
WHERE  s.type = 'global' AND c.ckey IN UNNEST(@customer_key_arr)
GROUP  BY c.ckey
ORDER  BY total DESC
LIMIT  5
```]
  #pause
  #small[The 5 customers, out of a list passed in (`@arr` for short), with the most `'global'` sales.]
]
// 10
#lecture-slide(source: [§1; discussion based on §3], notes: [2 minutes. Two states: with the array, then without it, with the takeaway. Strawman 1 is the loosely coupled design in its simplest form: run all of Q1 on one SQL server, its filters, join, aggregation and Top, and read each table through key-range reads against Spanner. With the array it is tolerable: point reads for its few customers and their sales, three shards touched, S3 not at all. Now drop the array and ask for the top five customers overall. The SQL server must pull every Customer row and every Sales row across the network, global or not, because a key-range read cannot test type: type is not a key column, so storage has no way to filter on it. Then it keeps five rows. The filters, the join and the aggregation could all have run next to the data, on each shard, in parallel. That is the takeaway, and it raises the question for the rest of the part: which operators can be shipped, and to where?])[Strawman 1: SQL beside the store][
  #small[Run all of Q1 on one SQL server; it reads each table through key-range reads against Spanner.]
  #alternatives[#beside(step: 1)][#beside(step: 2)]
  #uncover("2-")[#takeaway[Ship the operators to the data, not the data to the operators.]]
]
// 11
#lecture-slide(source: [§2; §3.1], notes: [2 minutes. Four states: the parallel-database plan, then one reason it fails per click, the takeaway with the last. Strawman 2 is what a classic parallel database does. Partitioning is fixed, so the optimizer can write the plan against it: run this subplan on servers A, B and C, combine at the root. In Spanner the map does not hold still, for three reasons, one per row. Plans are cached and reused, and by the next run S2 may have split into 250 to 400 and 400 to 500 with one half moved to another group. A shard can move during the query itself. And which shards Q1 needs depends on the array, which the compiler has not seen. The last reason has a precedent from last time: System R hit the same wall, a host variable in a stored plan has no value when the plan is chosen, so System R fell back to fixed selectivity guesses from its Table 1, a third for a range. Spanner does not guess; it decides at run time. The paper's sentence: we do not rely on static partitioning during query planning. So the plan says what to run on each piece of a table; which pieces, and where they live, is decided at run time, by key range.])[Strawman 2: split the plan at compile time][
  #small[A parallel database partitions once, so its optimizer can write: run this subplan on servers A, B and C; combine their results on one server.]
  #v(12pt)
  // One row per click; the rows above never move.
  #let rows = (
    ([S2 is `[250, 500)`, on G2], [S2 split into `[250, 400)` and `[400, 500)`;\ one half moved]),
    ([a shard stays put while read], [it can move mid-query]),
    ([Q1 reads a known set of shards], [which ones depends on `@arr`,\ unseen at compile time]),
  )
  #let table(k) = comparison(columns: (1.25fr, 1.75fr),
    [*The compiled plan assumes*], [*By the time it runs*], ..rows.slice(0, k).flatten())
  #only("2")[#table(1)]
  #only("3")[#table(2)]
  #only("4-")[#table(3)]
  #uncover("4-")[#takeaway[Plan *what* runs on each piece; decide *which* pieces, and *where*, at run time.]]
]

// Section divider: the distribution operator and how far it can be pulled.
// 12
#lecture-slide(section: true, notes: [0 minutes. Put distribution into the plan as one operator, then ask how far up the tree it may move. This part contains the lecture's hard turn: partitionability, whether an operator gives the same answer run shard by shard and concatenated, and the five-step walk that distributes Q1. Just before the first join, a slide on how Spanner writes joins, as Apply.])[Distribution as an operator][]
// 13
#lecture-slide(source: [§3.1], notes: [2 minutes. Three states: the rewrite, then the compiled tree with the caption, then the run-time calls. The fix for strawman 2: make distribution an explicit operator in the algebra. At the start of compilation, put a DistributedUnion directly above every table scan, so a global scan of T becomes a union, over T's shards, of local scans. Its meaning, left half of the figure: for each shard of T, run the subtree on a server hosting that shard, and concatenate the results, in key order when the plan needs it. The plan stays one tree, compiled once. At run time, right half, the thick edge under the union becomes a one-to-N cross-machine call: the subtree goes to the N shards it needs, chosen then, by key range, through the coprocessor framework. The subtree can itself contain a union: multi-level distribution, which the secondary-index query later in the hour uses, backup slide 47. The root server is the server the query was sent to; it runs everything above the outermost union, and any Spanner server can be root. One detail for Q1: an interleaved child has no shards of its own, so Scan(Sales) gets DistributedUnion(Customer), the union over its parent's shards.])[DistributedUnion][
  #formula(size: 24pt)[Scan(T) ⇒ DistributedUnion\[shard ⊆ T\](Scan(shard))]
  #only("2")[#du-fanout(step: 1)]
  #only("3-")[#du-fanout(step: 2)]
  #uncover("2-")[#caption[The *root server*, the one the query was sent to, runs everything above the outermost union.]]
]
// 14
#lecture-slide(source: [§3.1; §8], notes: [1 minute. Four states: slide 13's compiled tree with a pull-up arrow, then one bullet per click. Optimization now has a direction: pull the union up. Everything below it runs next to the data, on every shard in parallel; everything above it runs on the root, over what came back. Then be honest about last lecture's promise. The recap said the cost measure would grow a network term and a shard fan-out term. The paper writes no cost formula at all. It pulls the union up where possible, its words, as far as partitionability, the next slide, allows; and it cuts calls and rows shipped with rules: pull-up, shard pruning and batching, all coming today, and affinity, running a subtree in-process when its shard is local, a backup slide. Whether anything is ever priced, it does not say. The compiler is described as rewrites via transformation rules: push predicates down, pick indexes, remove subqueries. Join order and statistics are not described at all, and the paper says so in section 8: we have barely touched on query optimization. So today's optimizer is System R's rewrite step plus distribution rules, and System R's search is absent from the paper, not shown to be absent from Spanner.])[Pull the union up][
  #v(8pt)
  #grid(columns: (auto, 1fr), column-gutter: 20pt, align: horizon,
    pull-up(),
    {
      set text(size: 20pt)
      uncover("2-")[- Last lecture promised cost terms for network traffic and for shards called.]
      v(14pt)
      uncover("3-")[- Here, rules instead: pull the union up wherever it may go, and cut calls.]
      v(14pt)
      uncover("4-")[- Join order, statistics: out of scope today.]
    },
  )
]
// 15
#lecture-slide(source: [§3.1: partitionability], notes: [2 minutes. When is pulling the union above an operator F correct? When running F on each shard and concatenating the results gives the same answer as running F on the whole table. That is the formula, the paper's partitionability, and the figure: left, F over the whole table; right, F on each shard, concatenated with the shards in key order. OrderedUnionAll is the paper's name for what the union does once its calls return: concatenate, shards in key order. Make the class say it in words: per shard then concatenate equals on the whole table. Filters pass trivially: a row survives a filter or not regardless of which shard it is in. The next slide asks the class to classify the rest before showing the answer.])[Partitionability][
  #formula(size: 22pt)[F(Scan(T)) = OrderedUnionAll\[shard ⊆ T\](F(Scan(shard)))]
  #partition-equiv()
  #caption[Pulling the union above F is correct only if this holds.\ *OrderedUnionAll*: concatenate the shards' results in key order.]
]
// 16
#lecture-slide(source: [§3.1], notes: [3 minutes. Six states: the operators with the question, then one row's verdict per click, the takeaway with the last. Let the room vote on each row before its click. Filter and Project: per row, always. GroupBy on ckey: shard boundaries never fall inside one ckey value, so every group lives in one shard and per-shard groups are final; that needs only co-location, so hash sharding on ckey would do as well, which is our reading, since the paper credits range sharding for both this and sorting. GroupBy on type: one type's rows are spread over every shard, so each shard produces a partial group. Sort by ckey, in the key's direction: sort each shard and concatenate in key order, which needs range sharding, since hash sharding scatters neighbouring keys; last lecture's interesting order, a sort order a later operator can use, shows up here, because a key-ordered union delivers ckey order for free, like a clustered index scan. Top(5): in any order it fails, because N shards each keep five and the union returns up to 5N rows. Ordered by the key, Top is Limit after Sort; the Sort passes and only keep the first five stays above. Ordered by anything else, such as total, it needs a real Top over the N per-shard lists. What happens to the ones that fail is the next slide.])[Which operators pass?][
  #small[Customer and Sales, sharded on `ckey`. Per shard, then concatenate: the same answer?]
  #let rows = (
    ([Filter, Project], [passes], [one row at a time]),
    ([`GroupBy(ckey)`], [passes], [a ckey's rows never span a boundary]),
    ([`GroupBy(type)`], [#text(fill: red)[fails]], [one type's rows span the shards]),
    ([Sort by `ckey`, ascending], [passes], [sort each shard, concatenate in key order]),
    ([`Top(5)`, by any sort key], [#text(fill: red)[fails]], [N shards keep 5 each: up to 5N rows]),
  )
  #v(12pt)
  // All questions first, then one row's verdict per click.
  #alternatives(..range(6).map(k => comparison(columns: (1.35fr, .7fr, 2fr),
    [*Operator*], [*Passes?*], [*Why*],
    ..rows.enumerate().map(((i, r)) => if i < k { r } else { (r.at(0), [?], []) }).flatten())))
  #uncover("6-")[#takeaway[Groups and orders that follow the sharding key pass; Top never does.]]
  #caption[`Top(5)` is `ORDER BY … LIMIT 5` as one operator.]
]
// 17
#lecture-slide(source: [§3.1: multi-stage processing], notes: [1 minute. Four states: the rule and the three operators, then one row's local and final parts per click; the caption comes with Top, the takeaway with the last. What to do with an operator that fails: split it, the well-known multi-stage processing. Write Op as OpFinal after OpLocal; run OpLocal on each shard below the union and OpFinal above it, on the machine running the union: the root, for Q1. The equation says the split plan equals the original. Top(5) is the top five of the per-shard top fives: each of the table's top five rows is in its own shard's top five, because nothing in another shard can push it out. SUM is the sum of the per-shard sums, COUNT the sum of the counts, AVG the sum of the sums over the sum of the counts; never average the averages. A GroupBy whose columns lack the sharding key splits the same way: group locally, then merge the partial groups. One review question to plant: COUNT DISTINCT type cannot ship one number per shard, because the same type appears on several shards; its OpLocal must ship the distinct values themselves, which can be large.])[Split what does not pass][
  #sql(size: 26pt)[```
Op( DistributedUnion[shard ⊆ T]( F(Scan(shard)) ) )
  = OpFinal( DistributedUnion[shard ⊆ T]( OpLocal( F(Scan(shard)) ) ) )
```]
  // The operators first, then one row's local and final parts per click.
  #let rows = (
    ([`Top(5)`], [its own top 5], [top 5 of the shards' top 5s]),
    ([`SUM`], [`SUM`], [`SUM` of the sums]),
    ([`AVG`], [`SUM` and `COUNT`], [`SUM` of sums ÷ `SUM` of counts]),
  )
  #alternatives(..range(4).map(k => comparison(columns: (.7fr, 1.3fr, 2.1fr), inset: 10pt,
    [*Op*], [*OpLocal, on each shard*], [*OpFinal, above the union*],
    ..rows.enumerate().map(((i, r)) => if i < k { r } else { (r.at(0), hide(r.at(1)), hide(r.at(2))) }).flatten())))
  #uncover("4-")[#takeaway[Ship a small summary per shard; finish above the union.]]
  #uncover("2-")[#caption[Top is right: each of the table's top 5 rows is in its own shard's top 5.]]
]
// 18
#lecture-slide(source: [§2: CrossApply and OuterApply], notes: [2 minutes. Before the union meets its first join, how Spanner writes joins, because every plan from here on uses it. CrossApply of input and map: for each row of the input, run the map with that row’s columns bound, and concatenate the results. OuterApply is the left-outer version: it emits the input row with NULLs when the map returns nothing. The paper notes they are common in lambda calculus, and some SQL dialects expose them directly. The link to last time: it runs like the nested-loop join, outer and inner, with the same cost formula. The line under the code is last lecture’s point too: inside the map, the outer row’s columns are constants, so s.ckey = c.ckey becomes s.ckey = 7, column op value, the sargable form, so the map seeks into Sales rather than scanning it. What differs is what the inner can be. Last lecture’s join inner was always one base table, reached by one access path, a scan or one index, and a correlated subquery stayed a separate query block, optimized on its own. Here the map is any plan over the outer row’s columns: a filter, a union over shards, an aggregate, another Apply. The compiler uses these correlated joins throughout, both for algebraic rewrites and as physical operators, and the distribution operators coming up are, algebraically, variants of them. Because the map needs nothing from the input but those column values, it can even be shipped, with a batch of input rows, to each shard the batch touches: DistributedApply, slide 26.])[Joins as Apply][
  #small[`CrossApply(input, map)`: for each row of input, run map with that row's columns bound; concatenate the results.]
  #sql(size: 28pt)[```
CrossApply(input, map):
  for each row c of input:
    for each row s of map(c):    -- c's columns are constants here
      emit (c, s)
```]
  #small[In the map, `s.ckey = c.ckey` becomes `s.ckey = 7`: a seek to key 7 in Sales, not a scan.]
  #caption[`OuterApply` is the left-outer version: NULLs when the map returns nothing.]
]
// 19
#lecture-slide(source: [§3.1: interleaved tables], notes: [2 minutes. Three states: the interleaved tables, each customer with its sales in one shard; then the plan with a union under each input; then the merged plan, one union over the join, with the takeaway. Joins have two inputs, so the rule needs two unions. Two unions on the same table, pulled up through an inner or a semi join, merge into one when the equi-join names every sharding-key column. A semi join keeps an input row if a match exists: EXISTS, or IN with a subquery. The figure's before and after: a CrossApply of two unions over Customer becomes one union over Customer of the per-shard CrossApply. It holds when every Sales row that matches a Customer row of shard i is itself in shard i, so no match is ever lost by joining shard by shard. Interleaving guarantees exactly that for Customer and Sales: a customer's sales sit in the customer's shard. The paper says these are usually ancestor-descendant joins in the table hierarchy, executed as local joins on table shards. This is where interleaving pays off: a join with no network calls. If Sales were its own table sharded on ckey, not interleaved, the rule would still need co-location, which interleaving guarantees and separate sharding does not; that case is a review question.])[Parent-child joins: two unions merge][
  #v(4pt)
  #alternatives(..range(1, 4).map(s => parent-child-merge(step: s)))
  #uncover("3-")[#takeaway[The parent-child join runs inside each shard.]]
]
// 20
#lecture-slide(source: [§3.1, Figure 1], notes: [4 minutes. Six states: the start, then one click per step, each step red in the panel while the union moves. This is the paper's Figure 1, whose dotted lines are the path of the union; here the union itself moves, bottom to top. Start: a union over each scan; Sales has no shards of its own, so both unions are over Customer. Step 1: through the filter on Customer, which is partitionable; because the filter is on the sharding key, the union also keeps a copy of it, its sharding-key filter, for picking shards at run time. Step 2: through the filter on Sales, also partitionable; the union notes s.ckey = c.ckey, meaning the shard it needs is the one holding the input row's ckey. Step 3: at the CrossApply, both unions are over Customer and s.ckey = c.ckey names the whole sharding key, so customer c in shard i has its sales only in shard i: merge, by the rule of slide 19. Step 4: through GroupBy(c.ckey), which groups on the full sharding key: partitionable. Step 5: at Top(5) ordered by total descending, not partitionable; split it, a local Top(5) below the union and the final Top(5) above, and stop. Point out that the per-shard totals are already final, because of step 4, so the local Top ranks true totals, not partial sums.])[Q1: pull the union up][
  #alternatives(..range(6).map(s => q1-tree(stage: s)))
]
// 21
#lecture-slide(source: [§3.1, Figure 1], notes: [1 minute. The final plan, as the paper draws it. Everything below the union runs on the shards, all of them in parallel, and at most five rows per shard cross the network. The root server runs the union, which makes the calls, and the final Top(5) over those short lists. The sharding-key filter, ckey IN UNNEST(\@arr), rides on the union and is what the next slide uses to choose shards. Then the sentence to leave on the board: what made this cheap is the interleaving the schema chose. Without it, Sales has shards of its own, step 3 fails, and the CrossApply becomes a distributed join, which is the next part.])[Q1, distributed][
  #q1-tree(stage: "final")
]
// 22
#lecture-slide(source: [§3.2], notes: [2 minutes. Three states: the array, then its points, then the shards they fall in, with the takeaway and caption. The union holds its sharding-key filter, ckey IN UNNEST(\@arr). Before calling anyone, it evaluates that filter with this run's parameters into key ranges, using range extraction, from slide 29. Here the array is 7, 412, 7, 950: remove duplicates, the paper does, and you have three points, 7, 412 and 950. Intersect them with the shard map: S1, S2 and S4. S3 is never contacted. That is shard pruning, and it is done per run, which is exactly what strawman 2 could not do at compile time. Why it is safe, which is the caption: the sharding-key filter is implied by the filters of the scans below the union, so every row the subtree could return satisfies it, and therefore lies in one of the extracted ranges. An extra shard would only cost a call that returns nothing; a missing one would lose rows. Range extraction is built on that asymmetry: its ranges may be too big, never too small; why is in the lecture notes, for anyone who asks.])[Which shards: pruning][
  #small[The union evaluates its filter with this run's `@arr`, before calling anyone.]
  #v(12pt)
  #alternatives(..range(3).map(s => pruning(step: s)))
  #uncover("3-")[
    #takeaway[S3 is never contacted: *shard pruning*.]
    #caption[Safe: every row the subtree could return passes the filter, so it lies in a range we call.]
  ]
]

// Section divider: joins the shard map does not make local.
// 23
#lecture-slide(section: true, notes: [0 minutes. Interleaving makes parent-child joins local. A secondary index stored as its own table, sharded on its own key, is the join it cannot cover.])[Joins across shards][]
// 24
#lecture-slide(source: [§3.3], notes: [1 minute. Three states: Q2 with the index and Customer's shards, then where each Denver entry's customer lives, then Q2 written as a join. What interleaving does not cover: a global secondary index, which is its own table, sharded on the indexed column. CustomerByCity is stored as a table with key (city, ckey), sharded on city, so one index shard, I2 in the figure, holds all of Denver. Q2 asks for Denver's customers. On one machine Q2 is not even a join: it is last lecture's access path through a non-clustered index, about a page fetch per row found. Here the index is a table of its own, so the access path becomes a join between the index and the base table, with a union over each scan. The SQL at the bottom is Q2 written that way: read CustomerByCity like any table, keep Denver's entries, and join each one to its customer on ckey. Nobody has to write it; the compiler builds this join from Q2 itself, but seeing it as SQL makes the next slides' join plans unsurprising. And the rows the index points at are wherever their ckeys put them: in the figure, five Denver customers live in three of Customer's four shards. Our index shard boundaries, Chicago and Miami, are illustrative.])[A secondary index is its own table][
  #small[Q2: `SELECT c.* FROM Customer c WHERE c.city = 'Denver'`]
  #v(14pt)
  #only("1")[#index-calls(mode: "index")]
  #only("2-")[#index-calls(mode: "scatter")]
  #uncover("3-")[#sql(size: 24pt)[```
SELECT c.* FROM CustomerByCity i JOIN Customer c ON c.ckey = i.ckey
WHERE  i.city = 'Denver'      -- Q2 with the index as a table: a join
```]]
]
// 25
#lecture-slide(source: [§3.3], notes: [1 minute. The join as written: a CrossApply whose input is the index scan, city = 'Denver', and whose map looks up the customer with the input row's ckey. The map's union cannot be pulled up: the two tables are sharded differently, so no partitionability rule applies, and it fires once per input row. That is last lecture's nested-loop cost, C equals C outer plus outer rows times C inner, except that C inner is now a call to another machine, not a page fetch. With 1,000 Denver customers that is 1,000 calls, one after another, which the paper calls prohibitively expensive in latency and resources. The other plan, scan all of Customer and filter on city, reads the whole table, which is what the index was for. The figure shows five of the rows, five calls.])[One call per row][
  #small[As written: a `CrossApply`, input the index scan, map the Customer lookup, a union over each.]
  #v(14pt)
  #index-calls(mode: "row")
  #caption[Nested-loop cost: `C = C_outer + outer_rows × C_inner`, outer the index scan, inner one map lookup.\
  The map's union cannot be pulled up: the tables are sharded differently. So `C_inner` is a call.]
]
// 26
#lecture-slide(source: [§3.3, Figure 2], notes: [2 minutes. The fix: send the input rows in batches. This is the paper's Figure 2. Left, the row-at-a-time plan: an Apply, cross or outer, whose map sits under a DistributedUnion, one remote call per input row. Right: one join becomes two. DistributedApply is the apply and the union fused into one operator. On the caller, Batch cuts the input rows into arrays, each named \$batch in turn. The subtree rooted at CrossApply is shipped to each shard the batch touches; there, Unnest turns \$batch back into rows and the original map runs per row, locally, seeking to its keys rather than scanning. So the distributed join ships batches, and a local join applies each row of a batch on the shard. The paper extends this from equi-joins to inner, left outer and semi joins whose predicates constrain the remote table's sharding keys.])[Batch the input: DistributedApply][
  #small[One join becomes two: a distributed one ships batches; a local one applies each row.]
  #v(12pt)
  #batched-apply()
]
// 27
#lecture-slide(source: [§3.3: the four steps], notes: [2 minutes. How a batch is routed, the paper's four steps, done before any call. One: evaluate the map's sharding-key filter, ckey equals the row's ckey, on each row of the batch, which gives each row its key ranges. Two: merge them into one set. Three: intersect with the shard boundaries, which gives the shards to call. Four: per shard, keep only the batch rows whose ranges overlap it; a row whose range spans two shards goes to both. The trace: a batch of five ckeys from the index, 7, 300, 310, 820 and 990. S1 gets 7, S2 gets 300 and 310, S3 is not called, S4 gets 820 and 990: three calls, in parallel, instead of five in a row. Calls per batch is the number of shards touched, not rows, and the paper notes that often the whole input fits in one batch: one round of calls. Then the link to last lecture's Table 2: a non-clustered index paid per row, a clustered one per page; batching makes the index pay per shard touched. On each shard, the per-row map seeks to its keys instead of scanning.])[Routing one batch][
  #small[Each row's ckey picks its shard; each shard gets only its rows, in one call.]
  #v(14pt)
  #index-calls(mode: "batch")
  #takeaway[The index now pays per shard touched, not per row.]
]

// Section divider: the predicate analysis every part so far relied on.
// 28
#lecture-slide(section: true, notes: [0 minutes. Every step so far needed to know which keys a predicate can touch. This part builds that analysis: the strawman of one key range, then one scan per key column. How Scan2 skips, one predicate's three uses, predicates with OR and NOT, the filter tree and why extraction is safe are in the lecture notes, not on slides.])[Range extraction][]
// 29
#lecture-slide(source: [§4.1], notes: [1 minute. Every step so far needed it: the union's shard list, the per-row ranges of a DistributedApply, and the seek in place of a scan on each shard. Locking needs it too: which keys a read-write transaction must lock. And it is done at run time, because parameters, and the values earlier scans read, are known only then. The paper's example is a Documents table with key ProjectId, DocumentPath, Version, sharded on ProjectId, and a query for one project's documents under /proposals at one version. The paper's values: the parameters are P001 and 2017-01-01, and ten documents sit under /proposals. Ours: 1,000 versions each. For students who read the paper: its text calls the third key column Timestamp once, and Figure 3 calls the second key column DocumentId; both are slips, and the deck uses Version and DocumentPath throughout.])[Which keys can a predicate touch?][
  #sql(size: 26pt)[```
Documents  PRIMARY KEY (ProjectId, DocumentPath, Version)
           sharded on ProjectId
SELECT d.* FROM Documents d
WHERE  d.ProjectId = @param1
  AND  STARTS_WITH(d.DocumentPath, '/proposals')
  AND  d.Version = @param2
```]
  #takeaway[Which shards to call, what to read, what to lock.]
  #caption[`@param1` = P001, `@param2` = 2017-01-01; ten documents under /proposals, 1,000 versions each.]
]
// 30
#lecture-slide(source: [§4.1; Selinger §4: matching index], notes: [2 minutes. Two states: the one range, then what we want instead. The strawman is last lecture's index scan: one key range, from a start key to a stop key. By last lecture's definition all three factors, the ANDed conditions, match: they are sargable, and their columns form a prefix of the key. But only equalities on the leading columns, then one range, narrow the scan, and that fine print is new today. Here ProjectId = P001 is an equality, then DocumentPath in the range from /proposals to /proposalt, the next string after the prefix, is a range. Version = \@param2 comes after the range, so it is tested on every version read and narrows nothing. With 1,000 versions per document and ten documents, that is 10,000 rows read to return 10: a thousand times the rows needed. What we want instead: for each distinct DocumentPath in the range, one seek to its 2017-01-01 version.])[Strawman: one start key, one stop key][
  #small[All three conditions test key columns, but only equalities, then one range, narrow a scan.]
  #v(10pt)
  #doc-keys(mode: "range")
  #pause
  #takeaway[Wanted: one seek per document, to its 2017-01-01 version.]
]
// 31
#lecture-slide(source: [§4.2, Figure 3], notes: [2 minutes. Six states, building the tree bottom up, each new box red: Scan1; Scan2, which needs a project it does not have; the lower CrossApply, which runs Scan2 once per project Scan1 emits; Scan3, which needs a path; the upper CrossApply, which runs Scan3 once per path; then the whole tree with a summary. Pin one key column, then constrain the next given its value: a nested loop over key columns. The compiler rewrites the filtered scan into a chain of CrossApplys over the same table, one scan per key column, the paper's Figure 3. Read the boxes as each scan's own attributes: its filter and what it emits, not children. Scan1 handles ProjectId; the filter pins it to \@param1, so it reads nothing and emits \@project_id. Scan2, correlated on \@project_id, handles DocumentPath under the prefix and emits one \@document_path per distinct path. Scan3, correlated on both, seeks the full key, path and version, and emits the rows. It is Apply again, slide 18, with the outer row's values as constants inside the map, which is what lets each inner scan seek.])[Key columns one at a time][
  #small[Pin one key column, then constrain the next given its value: one scan per key column.]
  #v(14pt)
  #alternatives(..range(6).map(s => self-join-tree(step: s)))
]
// Section divider: long queries that outlive a failure.
// 32
#lecture-slide(section: true, notes: [0 minutes. What happens when something breaks in the middle of a long query, three strawmen, and the restart token that replaced them.])[Restarts][]
// 33
#lecture-slide(source: [§5.1], notes: [1 minute. Four states: the query and its stream, then one failure per click, the takeaway with the last. The scenario: a long query reads 50 shards at one snapshot timestamp and streams a million rows to the client over half a minute; the client has consumed 400,000. Then one of three things happens, and at Spanner's scale one of them always does. A server it reads from restarts: Spanner is always upgrading somewhere, and the paper reports very few moments when no zone, one deployment of Spanner servers, was being upgraded. A shard it reads splits, and half moves to another Paxos group: data movement. Or a later or retried call lands on a replica that is overloaded, or not yet caught up to the query's timestamp, t_safe below the read timestamp; rather than block, the call gives up and retries at another replica, which the paper calls distributed wait. The question for the next slide: what should the system do with 400,000 rows already delivered?])[Failures in the middle of a query][
  #alternatives(..range(4).map(s => long-query(step: s)))
  #uncover("4-")[#takeaway[Something is always upgrading, moving or overloaded.]]
]
// 34
#lecture-slide(source: [§5.1], notes: [2 minutes. Four states: the three strawmen, then each one's cost, one per click. Return an error, and let the client retry from the start: every application writes a retry loop with backoff, and those loops are a known source of bugs; a snapshot transaction whose reads are spread across modules of an application cannot be retried cleanly; a query that runs about as long as the time between failures may never finish before its snapshot is garbage-collected, retry loop or not; and one bad shard sets the latency of a query that touched fifty. Make results durable: buffer the results, or each operator's intermediate output, in storage as reliable as the database, and resume from there; every query pays latency to protect the few that fail. Rewrite the query so it can resume: tag every intermediate row with an identity column, or page by key, WHERE col > \@last ORDER BY col LIMIT n. The paper says identity columns looked impossible in the general case; our guess at why is that aggregates and joins make rows with no identity of their own. Paging adds a sort the query did not otherwise need. The insight: the query processor itself knows how far it got. Have it say so, cheaply, with every batch of results.])[Three strawmen][
  #let rows = (
    ([Return an error; the client reruns the query], [retry loops in every application; a long query may never finish; one bad shard sets the latency of fifty]),
    ([Make the results durable], [every query pays latency to protect the few that fail]),
    ([Rewrite the query to resume: row numbers (identity columns), or pages (key > last)], [identity columns for every intermediate row: no general method found; paging adds a sort]),
  )
  // The strawmen first, then one cost per click; hidden cells keep their space.
  #alternatives(..range(4).map(k => comparison(columns: (1.6fr, 2.4fr), [*Strawman*], [*What it costs*],
    ..rows.enumerate().map(((i, r)) => (r.at(0), if i < k { r.at(1) } else { hide(r.at(1)) })).flatten())))
]
// 35
#lecture-slide(source: [§5.2], notes: [2 minutes. Every batch of results carries an opaque restart token. To resume, the client library resends the original request plus the last token it received; the application never sees it. The calls between Spanner servers, a union's calls to its shards, are restartable the same way. The contract is weaker than you might expect, and that is deliberate: the rows before and after a restart together are a correct answer, none returned twice, but there is no promise that it is the answer an uninterrupted run would have given. The caption's example: SELECT \* FROM T LIMIT 100, restarted after 30 rows, returns 70 more rows, none repeated, not necessarily the 70 the first attempt would have sent. Restarts stream: nothing is written to persistent storage for their sake. The simplest case, a range scan with filters and projections: the token is the last primary key returned plus the snapshot timestamp, and resuming is a seek just past that key, at that timestamp. Why the timestamp is the next slide.])[Restart tokens][
  - Every batch of results carries an opaque *restart token*. To resume, the client library resends the request with the last token it got.
  - Contract: the rows before and after a restart form a correct answer, none twice; not necessarily the one an unbroken run would give.
  - A range scan's token: the last key returned and the *snapshot timestamp*, the one time all the query's reads use. Resume: seek just past that key, at that timestamp.
  #takeaway[Nothing is written to storage for the sake of restarts.]
  #caption[`SELECT * FROM T LIMIT 100`, restarted after 30 rows: 70 more, none repeated, maybe not the first run's 70.]
]
// 36
#lecture-slide(source: [§5.2; Oct 19 notes], notes: [1 minute. Two states: a row returned twice, then a row never returned, with the takeaway and caption. The part after the restart must read the same state as the part before. Suppose a scan stopped at key 50 at timestamp 100, and resumes, without the timestamp, at a newer one, 120. A transaction at 110 that deleted the row at key 10, already returned, and reinserted its data at key 90, not yet reached, makes it show up twice. One that moved a row from 90 to 10 makes it vanish: at 100 it was at 90, not yet reached, and at 120 it is at 10, already passed. Keep the timestamp in the token and both halves read the same snapshot. Every replica whose t_safe has passed that timestamp returns the same data, Oct 19, so the resume may run on any of them, even in another datacenter. Strong reads are covered too: their timestamp is picked once, at the start, and travels in the token. The limit: old versions are garbage-collected. Snapshot data has been garbage collected is an error the client still sees, as is deadline exceeded.])[Why the token carries the timestamp][
  #alternatives[#resume-ts(mode: "dup")][#resume-ts(mode: "both")]
  #uncover("2-")[
    #takeaway[Resume at the token's timestamp: both halves read one snapshot.]
    #caption[Any replica whose `t_safe`, the time up to which it has applied every write, has passed that timestamp\
    returns the same data, even in another datacenter.\
    The limit: old versions are garbage-collected, and that error still reaches the client.]
  ]
]
// 37
#lecture-slide(source: [§5.2], notes: [1 minute. Who gets restarts. Snapshot queries, strong ones included, are most of Spanner's queries, and they all do, because a snapshot timestamp pins what they read. Read-write transactions do not. Their reads have no snapshot timestamp: they read the latest data, which stays valid only while their locks are held. Those locks, taken as the transaction runs, live only in the leader's memory; what goes through Paxos is the prepare record. A failure often loses the locks, and another transaction may then change rows already read, so there is no state to resume into. The transaction aborts and the client retries, as it already must after a wound-wait abort, Oct 19.])[Not for read-write transactions][
  - Snapshot queries, strong ones (read at the current time) included, are most of Spanner's queries; their timestamp is fixed once.
  - A read-write transaction reads the latest data,\ valid only while its locks are held.
  - Those locks live only in the leader replica's memory. A failure often loses them, and another transaction may change rows already read.
  #takeaway[No snapshot to resume into: the transaction aborts, and the client retries.]
  #caption[As it already must after a wound-wait abort, Oct 19’s deadlock-avoidance rule.]
]
// 38
#lecture-slide(source: [§5.1: dynamic resharding; §5.2], notes: [1 minute. Four states: server A stops after key 24, then the token it leaves, then the merged shard on server B, then the resume with the takeaway. The paper names what makes tokens hard and defers the mechanisms to another paper; here is what a token has to capture. First, resharding, on the paper's own ranges; the timestamp and keys are ours: server A serves the range 20 to 30 at timestamp 105 and has returned keys 20 through 24 when it restarts. The token records timestamp 105 and that the range 20 to 30 is done up to key 24. Meanwhile 10 to 40 has become one shard, on server B. The resume, still addressed to 20 to 30, reaches B, which seeks just past 24, stops at 30, and reads at 105. A token that said shard 3, 400 rows done would mean nothing on B, which has a different shard with different rows in it: progress must be recorded in key space.])[What a token must survive: resharding][
  #small[The server that resumes may own a different key range from the one that stopped.]
  #alternatives(..range(1, 5).map(s => reshard-trace(step: s)))
  #uncover("4-")[#takeaway[“Shard 3, 400 rows done” means nothing on B: record progress in key space.]]
]
// Section divider: lessons from running Spanner in production.
// 39
#lecture-slide(section: true, notes: [0 minutes. Four lessons from running Spanner in production, one figure each, before the recap: users wanted SQL, plans must not regress, scale first, then go relational, and SQL versus NoSQL with one size fits all. The lecture notes have the full list.])[Spanner Lessons][]
// 40
#lecture-slide(source: [§8], notes: [1 minute. Four lessons from running Spanner in production, before the recap; the lecture notes have the full list. First, users wanted SQL. The key-value API, point lookups and range scans, was the quick way to launch and still serves simple retrieval, but SQL expressed the complex access patterns and pushed computation to the data, which is this whole lecture. Adoption jumped once Google had one dialect: SQL query volume doubled in the year before the common dialect and grew five times in the year after, so the bars are 1, 2 and 10. In that year the internal distribution calls in queries grew fourfold, which the paper reads as queries getting more complex. Prospective Cloud customers were overwhelmingly interested in SQL. How one dialect was built and kept the same across engines is in the lecture notes.])[Users wanted SQL][
  #small[Key-value lookups and scans got Spanner launched; anything more complex was easier in SQL.]
  #v(12pt)
  #sql-growth()
  #takeaway[With one dialect across Google, SQL use grew fivefold in a year.]
  #caption[Prospective Cloud customers asked for SQL too.]
]
// 41
#lecture-slide(source: [§8], notes: [1 minute. Second, the optimizer must not make things worse. Spanner ships a new version roughly every two weeks, and it backs mission-critical systems, so any performance regression is unwelcome; regressions caused by the optimizer are among the most sensitive, with possible swings of an order of magnitude. Tie it to last lecture: a cost-based optimizer picks the cheapest estimated plan, so improve a rule or an estimate and the winner changes, faster for most queries and much slower for a few. The curves are illustrative, not measured. The paper calls innovating in optimization while keeping workloads stable a big challenge and says little more; Cloud Spanner today lets an application pin the optimizer version its queries use.])[Plans must not regress][
  #small[A new release about every two weeks, under systems that must never get slower.]
  #v(10pt)
  #plan-regression()
  #takeaway[Improving the optimizer makes some plans worse.]
  #caption[A changed plan can swing latency by an order of magnitude. The curves are illustrative.]
]
// 42
#lecture-slide(source: [§8; §9], notes: [1 minute. Third, the path and the advice. Spanner reached SQL one milestone at a time: scalability; manageability, which for Spanner meant transparent failover across clusters and easy resharding as the system grows; ACID transactions across rows; the relational model, schema DDL with indexes on nested data, and finally SQL. Scale came first: horizontal scaling got Spanner deployed without heavy investment in single-machine speed, which came later, with Ressi. The advice to anyone on the same path is the red arrow, which leaves after manageability: once a scalable, available storage core exists, adopt the relational model early, because well-known relational abstractions speed up development and make the migrations you will eventually face cheaper. That closes the loop with slide 2: a key-value store first, then a full SQL database.])[Scale first, then go relational][
  #sql-path()
  #takeaway[Once storage scales and stays up, adopt the relational model early.]
  #caption[Relational abstractions speed development and make later migrations cheaper.]
]
// 43
#lecture-slide(source: [§8; §9], notes: [2 minutes. Fourth, two debates the paper takes a side on. Left, SQL versus NoSQL. NoSQL was born of the need for highly available systems at scale and low cost; scalability is never compromised at a web company, and a scalable system must address manageability early, which for Spanner meant transparent failover and easy resharding. Those properties can come from a key-value store with no SQL at all, Bigtable for instance. Cross-row ACID transactions are the next-hardest barrier, and a scalable, manageable, transactional key-value store is, in the paper's words, perhaps the lowest common denominator for building enterprise-strength global storage systems. F1 showed that SQL can be built on such a core, loosely; this paper builds it in, tightly. So the paper's conclusion: from where many Google engineers sit, the SQL versus NoSQL dichotomy may no longer be relevant. It is a stack. Right, one size fits all. Stonebraker and Cetintemel argued in 2005 that one engine for every workload is an idea whose time has come and gone: specialised engines win. The paper's answer from customers: combining OLTP, OLAP and full-text search in one system remains at the top of their priorities, because deploying and monitoring several systems, each with its own availability guarantees, transaction semantics, rollout cycle and API quirks, is a major burden. Spanner's stated goal is to perform well across that range over time, a goal, not a claim that it already does. Counterpoint for discussion: TiDB, Aug 31, answers the OLTP-plus-analytics part of that demand with two copies of the data, rows and columns.])[SQL vs. NoSQL, and one size fits all][
  #v(6pt)
  #nosql-stack()
]
// 44
#lecture-slide(source: [§3–§5, §8–§9, assembled], notes: [1 minute. The end of the main route, and no new content: one topic per part of the hour, each with a few reminder words; say the line behind each. Distribution: a DistributedUnion over every scan, pulled up while partitionability holds, slides 13 to 16, with Top and aggregates split into local and final parts, slide 17. Locality: interleaving makes the parent-child join local, slide 19, and DistributedApply batches the joins it cannot cover, slides 24 to 27. Run time: shard pruning, slide 22; one call per Paxos group and affinity, running a subtree in-process when its shard is local, are backup slide 46. Range extraction: one scan per key column, slides 29 to 31, and one predicate's ranges for routing, seeks and locks, said on slide 29; how Scan2 skips, the three uses, and why the ranges may be too big but never too small are in the lecture notes, for anyone who asks. Restarts: a token per batch, a snapshot timestamp and progress in key space, slides 35 to 38. Lessons: users wanted SQL, plans must not regress, scale first, then go relational, and SQL versus NoSQL as a stack while customers still want one system, slides 40 to 43. Then the result for Q1: everything below the union runs next to the data, slide 21. The three slides to re-read: 16, which operators pass; 27, why batching makes an index pay per shard; and 31, how one scan per key column turns a predicate into seeks. Forward: Nov 11 is isolation levels weaker than Spanner's serializability, phantoms included; Nov 16 is CockroachDB, range-sharded key-value storage with SQL in the same process. Five backup slides follow, slides 46 to 50, for spare time; the review questions are at the end of the lecture notes.])[Recap][
  #let hint(body) = text(fill: muted)[#h(10pt)#body]
  + *Distribution* #hint[DistributedUnion · pull up · partitionability · split Top]
  + *Locality* #hint[interleaving · DistributedApply · batches]
  + *Run time* #hint[shard pruning]
  + *Ranges* #hint[one scan per key column · seeks]
  + *Restarts* #hint[restart token · timestamp · key space]
  + *Lessons* #hint[SQL · stable plans · scale first · one system]
]

// Backup divider: slides to use if the main route finishes early.
// 45
#lecture-slide(section: true, notes: [Backup, 0 minutes. Five slides for spare time, each self-contained: one call per Paxos group and shard affinity; Q2's two-level plan; location hints, which send a query straight to the server holding its data; parallel consumers, several workers splitting one query's results; and locking rows that are not there yet, a preview of Nov 11. Use any of them in any order.])[Backup][]
// 46
#lecture-slide(source: [§3.2], notes: [Backup, 1 minute. Fewer calls, two ways. Left: when the extracted ranges cover the whole table, for example Q1 with no array, asking for the top five customers overall, the union sends one call per Paxos group rather than one per shard, since a group hosts several shards of the same table. In our map G1 hosts S1 and S3, so four shards cost three calls. Calls go out in parallel, up to a cap that keeps one query from swamping the servers, and a big shard can be split further into sub-shards, using split points the storage layer keeps, to parallelize within it. Right: shard affinity. If a target shard is hosted on the server running the union, the subtree runs in-process, with no call at all. The paper says this is common and important: many queries read one object, a user and its interleaved rows, under one sharding key, and most such row sets fit in one shard.])[Which servers: fewer calls][
  #small[When the ranges cover the whole table, call each Paxos group once, in parallel.]
  #v(12pt)
  #group-calls()
  #takeaway[Count calls, not shards.]
  #caption[Affinity is common: many queries read one object, a user and its interleaved rows, under one key.]
]
// 47
#lecture-slide(source: [§3.3; §3.4], notes: [Backup, 1 minute. Q2's final plan: two levels of distribution. The index's own union, DistributedUnion(CustomerByCity), is pulled above the DistributedApply, because the apply's map runs once per input row, which behaves like a Filter for partitionability; that rule is our reading, and the lecture notes' table of rules lists it. Its sharding-key filter, city = 'Denver', picks the index shard or shards holding Denver, and the DistributedApply runs on each of them, batching the index entries and calling the Customer shards each batch touches. Where batching fits: the input is small, and the join condition constrains the map table's sharding key, by equality or range: index to base table, foreign key to parent; inner, left outer and semi joins. Where it does not: two big tables joined on a non-key column; there is nothing to route on, so every batch goes to every shard. The paper calls distributed joins too large to cover exhaustively and shows only this one.])[Q2, distributed][
  #q2-plan()
  #caption[Fits a small input joined on the other table's sharding key: index to base table, foreign key to parent.\
  Does not fit two big tables joined on a non-key column: every batch goes to every shard.]
]
// 48
#lecture-slide(source: [§3.4: single-consumer API], notes: [Backup, 1 minute. Single consumer: one client reads all the results. The query goes first to a root server, which orchestrates the rest. If that root holds none of the data, it costs an extra hop: a point lookup that needs one cross-machine call makes two. So Spanner routes the query to the data, by location hint. On the first execution, the compiled plan is analyzed for the outermost distribution operator with a sharding-key expression; that expression, written in terms of the query's parameters, is turned into a pattern and cached on the client. On later runs the client plugs in the parameters, gets a key, and addresses the query to that key; the coprocessor framework finds the server. Two examples. A customer and its sales by ckey: the hint is Customer key = \@k, so the query goes to the server holding customer \@k, and since Sales is interleaved the whole query runs there, in-process. Customers by city: the hint is the index's key, so the query goes to the server holding that index shard. The paper's examples use tables named Parent, Child and Index; the shapes are the same.])[Send the query to its data][
  #small[A root server that holds none of the data costs an extra hop:\ two cross-machine calls where one would do.]
  #sql(size: 23pt)[```
SELECT c.*, s.* FROM Customer c JOIN Sales s ON c.ckey = s.ckey WHERE c.ckey = @k
  hint: Customer key = @k          → the server with customer @k; Sales is
                                     interleaved, so the whole query runs there
SELECT c.* FROM Customer c WHERE c.city = @city
  hint: CustomerByCity key = @city → the server with that index shard
```]
  #takeaway[After the first run, the client knows where to send the query.]
  #caption[A *location hint*: the outermost union's sharding-key filter, in terms of the parameters, cached on the client.]
]
// 49
#lecture-slide(source: [§3.4: parallel-consumer API], notes: [Backup, 1 minute. Parallel consumer: results too big for one machine, for example a MapReduce-style pipeline that joins Spanner data with data from other systems, but still wants filtering done next to the data. Two stages. First, send the query and the parallelism wanted, here two, and get back opaque partition descriptors. Second, workers each run one descriptor, calling the shards directly; together they return the single-consumer result, up to order, all at one snapshot timestamp. With Customer's four shards and two partitions, each descriptor covers two shards. This works only for root-partitionable queries: the compiled plan's root is a DistributedUnion, so a descriptor is just a subset of its shards. Q1 is not root-partitionable: its final Top(5) sits above the union, and no single worker can compute it. Cloud Spanner exposes this today as PartitionQuery.])[Too big for one client][
  #parallel-consumer()
  #takeaway[Only for *root-partitionable* queries: the plan's root is a DistributedUnion.]
  #caption[The workers are *parallel consumers*. Q1 does not qualify: its final Top(5) sits above the union.]
]
// 50
#lecture-slide(source: [§4.1; Oct 19 notes; Nov 11 preview], notes: [Backup, 1 minute. Spanner locks per column, and a key column and a non-key column stand for different things. The key columns of a range stand for which rows exist there, so an insert or delete in the range conflicts. A non-key column of a row stands for its value, so an update of that row conflicts. Why the key-column lock covers the whole range, which is our reading: the answer also depends on which documents are absent. Oct 19's two-phase locking locks the items read, but /proposals/doc11 is not an item yet, so lock the range its insert would land in. A row that appears in a range you already read is a phantom, Nov 11. Snapshot reads lock nothing; for them the ranges say which prepared, uncommitted writes to wait out, rather than every one in the Paxos group, Oct 19's t_safe, a refinement already in the 2012 paper. The paper leaves a trade-off open: fine ranges read and lock less, but cost more to compute and to hold.])[Locking rows that are not there yet][
  - Spanner locks per column. Key columns of a range stand for which rows exist there: an insert or delete in the range conflicts.
  - A non-key column of a row stands for its value:\ an update of that row conflicts.
  - The answer depends on which documents are *absent*. `/proposals/doc11` is not a row yet, so lock the range its insert would land in.
  #takeaway[A row appearing in a range already read is a *phantom*: Nov 11.]
  #caption[*Snapshot reads*, lock-free reads at one timestamp, lock nothing; for them the ranges say which prepared but uncommitted writes to wait out.]
]
