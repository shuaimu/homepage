// CSE 416-03 Fall 2026 — Lecture 3: Working with coding agents
// Compile: typst compile SE26fa-03-Agents.typ
#import "@preview/touying:0.5.3": *

#let orange = rgb("#E67E22")
#let teal = rgb("#48C9B0")
#let tan = rgb("#C9B48A")
#let ink = rgb("#4A4A4A")
#let box-bg = rgb("#F7F4EE")

#set page(
  paper: "presentation-16-9",
  margin: (x: 1.15cm, top: 0.85cm, bottom: 1.05cm),
  background: place(bottom, rect(width: 100%, height: 8pt, fill: teal)),
)
#set text(font: "Helvetica Neue", size: 20pt, fill: ink)
#set par(leading: 1.15em)
#set list(indent: 0.15em, marker: ([●], [○]), spacing: 1.15em)
#show heading: set text(fill: orange, weight: "bold")
#show link: set text(fill: rgb("#1A73E8"))

#let triple-line = align(center, stack(
  dir: ttb,
  spacing: 4pt,
  line(length: 86%, stroke: 0.8pt + teal),
  line(length: 86%, stroke: 2.6pt + teal),
  line(length: 86%, stroke: 0.8pt + teal),
))

#let title-slide(title, subtitle) = page(
  margin: 0cm,
  background: none,
  {
    set align(center)
    v(0.7cm)
    triple-line
    v(2.15cm)
    text(size: 38pt, weight: "bold", fill: orange, title)
    v(0.65cm)
    grid(
      columns: (1fr, auto, 1fr),
      align: horizon,
      align(right, rect(width: 1.6cm, height: 7pt, fill: tan, radius: 1pt)),
      pad(x: 0.5cm, text(size: 20pt, fill: ink, subtitle)),
      align(left, rect(width: 1.6cm, height: 7pt, fill: tan, radius: 1pt)),
    )
    v(2.15cm)
    triple-line
  },
)

#let section-slide(body) = page(
  margin: 0cm,
  background: place(bottom, rect(width: 100%, height: 50%, fill: teal)),
  block(
    width: 100%,
    height: 50%,
    align(center + horizon, text(size: 32pt, weight: "bold", fill: orange, body)),
  ),
)

#let slide(title, body) = page[
  #text(size: 28pt, weight: "bold", fill: orange, title)
  #v(0.45cm)
  #body
]

#let card(title, body, fill: box-bg) = block(
  width: 100%,
  fill: fill,
  radius: 6pt,
  inset: 12pt,
  stroke: 0.6pt + luma(200),
  {
    text(size: 15pt, weight: "bold", fill: orange, title)
    v(6pt)
    text(size: 14pt, body)
  },
)

#let dcard(title, body) = block(
  width: 100%,
  height: 3.55cm,
  fill: box-bg,
  radius: 6pt,
  inset: 11pt,
  stroke: 0.6pt + luma(200),
  {
    text(size: 15pt, weight: "bold", fill: orange, title)
    v(5pt)
    text(size: 13.5pt, body)
  },
)

#let arrow = text(size: 22pt, fill: teal, weight: "bold")[→]

#let pipe-box(label, sub) = block(
  width: 100%,
  height: 2.35cm,
  fill: box-bg,
  radius: 5pt,
  inset: (x: 5pt, y: 7pt),
  stroke: 0.7pt + teal,
  align(center + horizon)[
    #text(size: 13pt, weight: "bold", fill: orange, label)
    #v(2pt)
    #text(size: 11pt, fill: ink, sub)
  ],
)

#let source(label, url) = {
  v(6pt)
  align(right, link(url, text(size: 9.5pt, fill: luma(110), label)))
}

// ---------------------------------------------------------------------------
#title-slide[Working with coding agents][CSE-416-03  ·  Sep 9, 2026]

#slide[Recap][
  - M1 is next week. You need a written proposal in the repo. Put the repo/doc link into the team spreadsheet.
  - Received many questions.
]

#slide[Q&A][
  - Q: We brainstormed these features, can you see if they are good? 
  #pause
  - A: I’m not your user, but I don’t need to be! You would want to find some evidence to support your features, and show that your brainstorming have real users. That’s the idea. You don’t need my approval to do idea. What I will “Judge” is whether you have spend reasonable amount of efforts to evaluate your idea if they have real users potentially.
]

#slide[How do we expect from your proposal?][
  #pause
  - Is there a proposal? 
  #pause
  - Is this proposal carefully generated? 
  #pause
  - Are there efforts spent on studying users' needs? 
  #pause
  - Are the team working together?
]

#slide[Heads-up on the presentation][
  - Come 10 minutes before class to test you laptop.
  - Try not to switch computers during your presentation.
  - You don't have to all speak. 
]

#slide[Today][
  - Today is how to use a coding agent on that work — and for the rest of the semester.
  - Some of this is from Stanford CS146S (*The Modern Software Developer*). 
  - Three parts: *prompt engineering*, *context engineering*, and *specification engineering*.
]

#section-slide[Autocomplete vs an agent]

#slide[Autocomplete, chat, agent][
  #v(0.15cm)
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 0.45cm,
    dcard([Autocomplete], [Completes the line. Useful. You are still writing the program.]),
    dcard([Chat], [You ask a question, copy an answer, run it yourself.]),
    dcard([Agent], [It edits files, runs commands, reads the error, tries again. You stop it.]),
  )
  #v(0.5cm)
]

#slide[Three ways to optimize][
  #v(0.15cm)
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 0.4cm,
    dcard([Prompt], [Unclear request. Rewrite what you ask for this turn.]),
    dcard([Context], [Missing evidence. Add the right files, output, or tools.]),
    dcard([Specification], [Work spans turns or people. Write the agreement down.]),
  )
  #v(0.4cm)
  - These overlap in real work. None of the three is “the most important” for every task.
]

#section-slide[Prompt engineering]

#slide[Prompt engineering][
  - You are choosing the words in the box so this turn does the right thing.
  - Still worth doing. “Add tests” and “add tests for a \$0 bill and a roommate who already paid” are not the same request.
  - It cannot fix missing files or a messy repository. Those are different problems.
]

#slide[Say the cases][
  #v(0.1cm)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 0.55cm,
    card([Weak], [
      “Add unit tests.”
      #v(8pt)
      For what? It will test the happy path, or invent cases you do not care about.
    ]),
    card([Better], [
      “Add tests for: amount 0, a negative amount, and a roommate who already paid. Do not add a chat feature.”
      #v(8pt)
      Same idea if the work spans DB + API + UI: one piece per prompt, then look at it.
    ]),
  )
]

#slide[Show the shape you want][
  #v(0.1cm)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 0.55cm,
    card([Weak], [
      “Write a good commit message for this diff.”
      #v(8pt)
      “Good” is not a format. You get a paragraph, or something you will rewrite.
    ]),
    card([Better], [
      “Same style as these:”
      #v(6pt)
      `Fix split so a $0 bill does not crash`
      #v(4pt)
      `Mark a bill paid from the list, not the detail page`
      #v(6pt)
      Then: “One line. What changed, not how you felt about it.”
    ]),
  )
  #v(0.35cm)
  - One or two examples in the prompt beat a long speech about quality.
]

#slide[Simon Willison (Django creator): one short prompt][
  - Simon has a `blog-to-newsletter` tool. In 2026 he wanted it to include a new kind of post called a “beat.”
  - The repository had more than 200 little HTML tools. His prompt named the one file to change.
  - It also named an existing implementation to copy and told the agent exactly how to check the result.
  - He reports that the resulting pull request made the right change in one pass.
  #source(
    [Source: Simon Willison, “Adding a new content type to my blog-to-newsletter tool,” Apr 18, 2026],
    "https://simonwillison.net/guides/agentic-engineering-patterns/adding-a-new-content-type/",
  )
]

#slide[The prompt][
  #set text(size: 16.5pt)
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 0.35cm,
    card([Reference], [
      “Clone `simonw/simonwillisonblog` to `/tmp` for reference.”
    ]),
    card([Change], [
      “Update `blog-to-newsletter.html` to include beats that have descriptions — similar to how the Atom everything feed works.”
    ]),
    card([Check], [
      “Run it with `python -m http.server`; use Rodney to test it; compare it with the live homepage.”
    ]),
  )
  #v(0.45cm)
  - It says *where to look*, *what to change*, and *how to tell if it worked*.
  - Willison’s point: an existing working example often explains the desired behavior better than another paragraph.
]

#slide[Ask for a plan, then stop][
  - “Read `spec.md` and `app/bills.py`. Tell me how mark-paid would work. Do not edit files.”
  - Then you fix the plan (wrong table, extra feature, it wanted a new auth).
  - Then: “Do step 2 only.”
  - If you skip this, it often adds a second copy of something you already have.
]

#slide[What usually does not help][
  - “You are a world-class senior engineer…” — it does not become one.
  - “Make it production ready / perfect / secure.” No check, so it will claim it did.
  - Restating the whole product in every message. That just fills the window.
  - A useful extra line is a *constraint*: “Do not touch auth.” “No new dependencies.”
]

#section-slide[Context engineering]

#slide[Context engineering][
  - You are choosing what the model is allowed to see this turn — not just how you phrase the ask.
  - That includes: files you \@-mention, `AGENTS.md`, the conversation so far, `npm test` output, a screenshot of the broken page.
  - Two teammates can type the same sentence and get different code, because one attached `bills.py` and the other attached the whole `src/`.
  - Most “the model is dumb today” problems are the wrong files, a stale thread, or two docs that disagree.
]

#slide[Same prompt, different files][
  #v(0.1cm)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 0.55cm,
    card([Prompt only], [
      “Add mark-paid.”
      #v(8pt)
      Empty chat, no files.
      #v(8pt)
      It invents a new table, a new route, maybe a points system — because it cannot see yours.
    ]),
    card([Prompt + the right files], [
      Same sentence, plus `spec.md` and `app/bills.py`, plus “do not change auth.”
      #v(8pt)
      It has a chance of editing the function you already have.
    ]),
  )
]

#slide[Armin Ronacher changed the environment][
  - Armin Ronacher (creator of Flask) uses coding agents heavily. He found that the agent would sometimes start a second development server.
  - He changed `make dev` to detect that the server was already running and print a clear error.
  - He also logs the server output to a file and provides `make tail-log`.
  - Now the agent can see the state of the program and recover without Armin copying errors into chat.
  #source(
    [Source: Armin Ronacher, “Agentic Coding Recommendations,” Jun 12, 2025],
    "https://lucumr.pocoo.org/2025/6/12/agentic-coding/",
  )
]

#slide[What one run looked like][
  #v(0.1cm)
  #align(center, grid(
    columns: (1fr, auto, 1fr, auto, 1fr),
    align: horizon,
    column-gutter: 0.25cm,
    dcard([Agent], [`make dev`]),
    arrow,
    dcard([Tool], [`services are already running`]),
    arrow,
    dcard([Agent], [`make tail-log` → finds the URL → opens the browser]),
  ))
  #v(0.55cm)
  - For login tests, the debug server prints the email link in the log. `CLAUDE.md` tells the agent where it is.
  - Context engineering here is not “attach more prose.” It is making the running system observable.
]

#slide[A screenshot during an outage][
  - Anthropic’s Data Infrastructure team had Kubernetes clusters that stopped scheduling pods.
  - They gave Claude Code screenshots of their dashboards.
  - It walked them through the Google Cloud UI, identified exhausted pod IP addresses, and gave commands to add an IP pool.
  - Anthropic says this saved about 20 minutes. Treat the number as a vendor’s own case study, not an independent measurement.
  #source(
    [Source: Anthropic, “How Anthropic teams use Claude Code,” Jul 24, 2025],
    "https://www.anthropic.com/news/how-anthropic-teams-use-claude-code",
  )
]

#slide[The error is the useful context][
  - Run it. Paste the traceback (or a screenshot). You do not need to rephrase the product.
  - “It doesn’t work” gives it nothing. The exception, the failing test name, the URL — those do.
  - For UI, a picture of the page beats another paragraph of “the button is on the left.”
]

#section-slide[Specification engineering]

#slide[Specification engineering][
  - A prompt is a request for this turn. Context is what the agent can inspect.
  - A specification is a durable description of behavior, constraints, and how you will check the result.
  - It could be an issue, `SPEC.md`, an API example, a diagram, or a set of acceptance tests.
]

#slide[When writing a spec helps][
  #v(0.15cm)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 0.6cm,
    card([A small experiment], [
      “Can this library read the file?” Try it and throw it away.
      #v(8pt)
      A detailed spec would slow you down without helping.
    ]),
    card([A feature the team will keep], [
      Several screens, stored data, error cases, two people editing it.
      #v(8pt)
      Write enough that the next person does not have to recover the decisions from chat.
    ]),
  )
]

#slide[Armin Ronacher: the tests were the spec][
  - In January 2026, Armin Ronacher ported MiniJinja from Rust to Go with an agent doing almost all of the coding.
  - MiniJinja already had snapshot tests: inputs plus the exact outputs expected from the Rust implementation.
  - He and the agent agreed to reuse those snapshots and port in stages: lexer → parser → runtime.
  - The run lasted 10 hours; Ronacher reports about 45 minutes of active human time, 34 prompts, and \$60 in API cost.
  #source(
    [Source: Armin Ronacher, “Porting MiniJinja to Go With an Agent,” Jan 14, 2026],
    "https://lucumr.pocoo.org/2026/1/14/minijinja-go-port/",
  )
]

#slide[Where the tests were not enough][
  - The agent gave up on “must fail” tests because Go could not reproduce the Rust error text exactly. Ronacher made it use fuzzy matching instead.
  - It also tried to change HTML escaping and iterator behavior to make the port easier. He rejected those changes.
  - Once the behavior was pinned down, the agent ran unattended for seven hours to finish the long tail.
  - The lesson: executable examples are a strong specification, but a human still decides which differences are acceptable.
]

#slide[Spec-driven development (SDD)][
  - Write and review the expected behavior, constraints, and acceptance criteria before asking an agent to implement.
  - Turn the specification into a plan and small tasks; implement and check each task against it.
  - Keep the specification in the repo and update it when the team changes a decision.
  - Most popular tools: Spec Kit, Kiro, OpenSpec
]

#slide[OrangeLoops: two hours to generate, four days to finish][
  - In early 2026, OrangeLoops used Spec Kit and Claude Code to build a NestJS backend and an Expo mobile frontend from project documents and base templates.
  - The tools produced 195 tasks and about two hours of recorded code generation.
  - Applying the visual design took about four hours. Testing, integration debugging, database seeding, review, and stabilization took four days.
  #source(
    [Source: OrangeLoops, “Spec Kit + Claude Code Case Study,” May 2026],
    "https://orangeloops.com/2026/05/spec-driven-development-with-ai-a-spec-kit-claude-code-case-study/",
  )
]


#let openspec-example(stage) = {
  let flow-card(title, body) = block(
    width: 100%,
    height: 2.85cm,
    fill: box-bg,
    radius: 6pt,
    inset: 11pt,
    stroke: 0.7pt + teal,
    align(left)[
      #text(size: 15pt, weight: "bold", fill: orange, title)
      #v(6pt)
      #text(size: 13pt, body)
    ],
  )
  let left-arrow = text(size: 22pt, fill: teal, weight: "bold")[←]
  let down-arrow = text(size: 22pt, fill: teal, weight: "bold")[↓]
  let up-arrow = text(size: 22pt, fill: teal, weight: "bold")[↑]
  let show-from(step, body) = if stage >= step { body } else { hide(body) }
  v(0.35cm)
  align(center, grid(
    columns: (1fr, auto, 1fr),
    align: horizon,
    column-gutter: 0.3cm,
    row-gutter: 0.12cm,
    flow-card([1. Propose], [
      Describe the change: let a roommate mark a bill paid. OpenSpec drafts the specification, design, and tasks.
    ]),
    show-from(2, arrow),
    show-from(2, flow-card([2. Review], [
      The team fixes the draft: whole payments only, participants only, and balances must update.
    ])),
    show-from(4, align(center, up-arrow)),
    [],
    show-from(3, align(center, down-arrow)),
    show-from(4, flow-card([4. Archive], [
      Move the shipped behavior into the current bill specification. Keep the completed change as history.
    ])),
    show-from(4, left-arrow),
    show-from(3, flow-card([3. Apply], [
      The agent adds the data field, route, button, and tests. The team checks the tests and the UI.
    ])),
  ))
}

#slide[OpenSpec example: a bill was paid][
  #openspec-example(1)
]

#slide[OpenSpec example: a bill was paid][
  #openspec-example(2)
]

#slide[OpenSpec example: a bill was paid][
  #openspec-example(3)
]

#slide[OpenSpec example: a bill was paid][
  #openspec-example(4)
]

#section-slide[Putting the three together]

#slide[If the result is bad, ask why][
  #v(0.15cm)
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: 0.4cm,
    dcard([Prompt problem], [Wrong task. Rewrite the request; add cases and constraints.]),
    dcard([Context problem], [Missing code or failure. Add files, logs, a screenshot, or a tool.]),
    dcard([Specification problem], [Team disagrees or repeats an old decision. Update the shared note.]),
  )
  #v(0.45cm)
  - Do not solve every failure by making the prompt longer.
]

#section-slide[Demo]

#section-slide[Tools]

#slide[Next][
  - Sep 14–16: *Milestone 1* in class.
  - About 10 minutes: what you finished, why, how the team (including AI) worked.
  - Have the files in the repo. Bring a walkthrough.
  - If you cannot name users, a core loop, and who owns what — you are late.
]
