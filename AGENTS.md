# AGENTS.md

## Slide visual review

- After creating or editing slides, render the entire final deck and visually inspect
  every slide at a readable size, including all incremental reveal states and appendices.
- Check spacing between text groups, especially conclusions below lists or tables,
  captions below diagrams, and question/answer reveals. Also check text wrapping,
  alignment, label collisions, clipping, and clearance from headers and footers.
- Use at least 1.5× baseline spacing for slide body text and lists: a half-font-size
  gap beyond a one-em line box (e.g. 36pt baseline spacing for 24pt text). Allow
  extra space between separate bullets. Reflow or split dense slides instead of
  shrinking their type or tightening the spacing to fit.
- Fix visual glitches and re-render the affected slides before delivery. Compilation,
  text extraction, and automated bounds checks supplement visual inspection; they do
  not replace it. Verify both presentation and handout exports when both are provided.

## Cursor Cloud specific instructions

This repository is a **Jekyll static site** (an academic homepage) served via the `github-pages`
gem and hosted on GitHub Pages. There is no backend, database, or API — the whole product is one
static-site build served by a single dev server.

### Services

| Service | Command | Notes |
| --- | --- | --- |
| Jekyll dev server | `bundle exec jekyll serve` | Builds the site and serves it (WebRick) on `http://localhost:4000`. This is the entire product. |

There are no automated tests or lint tooling configured. "Build" == `bundle exec jekyll build`.

### Non-obvious gotchas

- **`jekyll serve` clobbers the committed `docs/` folder.** `_config.yml` sets `destination: docs`,
  and `docs/` is the checked-in GitHub Pages output. Running `serve`/`build` regenerates `docs/`
  (including *deleting* `docs/CNAME`, which is not part of the source), producing a large, unwanted
  diff. To preview locally without touching the tracked output, serve to a throwaway destination:
  `bundle exec jekyll serve --destination /tmp/_site`. Do **not** commit regenerated `docs/` changes
  unless you are intentionally re-publishing the site.
- Ruby is 3.2 (Ubuntu system Ruby). `_plugins/ruby4_compat.rb` is a shim that restores
  `tainted?`/`untaint` for Ruby 3.4+, so builds also work on newer Ruby.
- Gems are installed to a bundler path **outside** the repo (`~/.bundle-jekyll`, set via a global
  `bundle config`). This is deliberate: installing into `vendor/bundle` inside the repo makes Jekyll
  scan gem files and fail the build on a template file. Keep gems out of the working tree.
- `Gemfile.lock` is gitignored, so `bundle install` resolves fresh each time.
- `_config.yml` is **not** hot-reloaded by `jekyll serve`; restart the server after editing it.
- Node/npm is only needed for the optional `update_bootstrap.sh` asset-refresh helper, not for
  normal builds.
