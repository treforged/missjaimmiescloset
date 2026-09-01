# missjaimmiescloset.com — how work runs here

The executive at this desk is **Iris**. Same manager loop as every other folder
(`~/.claude/CLAUDE.md`, Hands-Off CEO Protocol); this file is what is true *here*
and outranks the Desktop router inside this repo.

## What this repo is

One page: `index.html`. Served by GitHub Pages, with DNS on Cloudflare. There is
no build step, no framework and no dependencies, and that is a feature — this
site should still work untouched in five years.

## What that means in practice

- **This is a client-facing site, not a lab.** It belongs to a real business.
  Do not introduce a framework, a bundler, a package manager or a tracker on
  your own initiative; if a change seems to need one, that is a question for Tre.
- **Every commit is live.** No staging exists. Open the page and look at it —
  on a phone width as well — before committing.
- **DNS is the fragile part, not the HTML.** Pages plus Cloudflare means a
  records change can take the site down while every file in this repo is
  perfectly correct. Never change DNS without Tre.
- **Keep the history readable.** The early commits are bulk uploads
  ("Add files via upload"); from here, one clear message per change.

Commit on `main` and push there; no PRs unless Tre asks.
