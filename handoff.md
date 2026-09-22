# Handoff — missjaimmiescloset.com

Snapshot of what is true right now. Read in full at session start; keep it a
snapshot, not a log — edit it in place rather than appending a section per
session.

## ⚠️ THE DOMAIN DOES NOT SERVE THIS REPO, AND https IS BROKEN

Measured 2026-09-15 by Iris. **Three premises previously recorded in this file
and in CLAUDE.md are false.** They were stated confidently and nobody had
re-tested them, so every session here has been working on a page the public
cannot reach.

| Claim that was recorded | What is actually true (measured) |
| --- | --- |
| "Served by GitHub Pages from `main`" | The **domain** is not. Pages *does* serve the repo, but only at `treforged.github.io/missjaimmiescloset/`. |
| "Domain on Cloudflare DNS" | Nameservers are **register.com** (`dns019.a.register.com` +3). The `server: cloudflare` header comes from Weebly's own CDN, not Tre's account. |
| "Every commit is live" | **No commit here has ever reached the domain.** |

**What the domain actually does today:**

- `missjaimmiescloset.com` A record -> `199.34.228.66`, rDNS
  **`pages-custom-18.weebly.com`**. (GitHub Pages apex is 185.199.108-111.153.)
- **`https://` is hard-broken:** `ERR_SSL_VERSION_OR_CIPHER_MISMATCH` in Chrome,
  `SEC_E_ILLEGAL_MESSAGE` from schannel — two independent TLS stacks, same
  refusal. No valid certificate for this name.
- `http://` -> 301 to `www` -> **200, a 583-byte Square/Weebly placeholder**:
  *"Thanks for purchasing — This temporary landing page will be replaced when
  you publish your site."*
- There is **no `CNAME` file** in this repo, so Pages was never told the custom
  domain.

**Positive control, so this is not a blind instrument:** `treforged.com` loaded
fine in the same browser, same network, same minute (200, 30 links), and
`https://treforged.github.io/missjaimmiescloset/` returns 200 / 39,012 bytes.

**The repo itself is healthy.** The deployed Pages copy is **byte-identical** to
`HEAD:index.html` — sha256 `1d39cf67…d806ab3b` on both sides.

### The fork is closed; only the DNS move is outstanding

Tre, 2026-09-15: *"I haven't fixed it to where I can put it into my Cloudflare
yet. I will let you know when I do update that."* So the intent is settled —
the domain is going to Cloudflare and will point at this Pages site. **Do not
touch DNS, and do not chase him for it.**

Prepared and waiting in `_tools/`:

- **`CNAME.ready`** — the CNAME file, **deliberately not active**. Committing it
  as `/CNAME` today would take the site down: a CNAME file sets the custom
  domain, Pages then 301-redirects `treforged.github.io/missjaimmiescloset/` to
  it, and `https_enforced` is `true` against a domain that currently refuses the
  TLS handshake. Activation and undo are one command each; see
  `_tools/README.md`.
- **`verify-domain.ps1`** — checks from OUTSIDE when he reports the move.
  Three TLS stacks, a positive control, and a body comparison so a 200 from the
  Square placeholder cannot read as success. Proven `exit 1` / `exit 0` /
  `exit 2` before it was committed.

A third independent confirmation of the outage came out of building it:
python/OpenSSL returns `SSLV3_ALERT_HANDSHAKE_FAILURE`, alongside schannel's
`SEC_E_ILLEGAL_MESSAGE` and Chrome's `ERR_SSL_VERSION_OR_CIPHER_MISMATCH`.

## State

- One page, `index.html`, no build step, no dependencies, no CI. Keep it that way.
- Repo: `treforged/missjaimmiescloset`. History before 2026-09 is bulk uploads,
  so the commit log is not a record of what changed or why.
- Live (reachable) URL: `https://treforged.github.io/missjaimmiescloset/`.

## How to work here

Read `CLAUDE.md` first — but note its "GitHub Pages + Cloudflare" line is the
false premise corrected above. It is a real client's live site, every commit is
live **at the Pages URL only**, and nothing gets a framework or a tracker added
to it without Tre.

**There is no browser in the shell and shell https egress is blocked.** To check
a rendered result: serve locally (`python -m http.server 8731 --bind 127.0.0.1`)
and drive it with the Chrome tools. A 400px-wide same-origin `<iframe>` is the
honest way to get a true phone viewport — `resize_window` did not take on a
maximised window and silently rendered at 1325px, which read as a phone frame.

## Fixed this session (2026-09-15)

**The mobile drawer trapped its own first and last items.** `.mobile-menu` was
`position:fixed; inset:0` with `justify-content:center` and `overflow-y:visible`,
so on a short viewport the overflow was clipped at *both* ends and could not be
scrolled.

- At **667px tall (iPhone SE/8)**: `Shop` and `SHOP EBAY` unreachable.
- At **600px**: `What We Carry` too.
- At **800px**: `Shop` rendered *underneath* the opaque fixed nav bar
  (nav `z-index:200` vs menu `190`).

So on common phones the first nav link and one of the two store CTAs could not
be tapped at all.

Fix: `justify-content: safe center`, `overflow-y: auto`,
`overscroll-behavior: contain`, `padding: 4.5rem 1.25rem 1.5rem`.
Also gave the hamburger `type="button"`, `aria-expanded` (now toggled) and
`aria-controls`, and its label swaps to "Close menu" when open.

**Proven red then green** with one instrument in one run, unfixed copy vs fixed
copy served side by side:

| Viewport | Before | After |
| --- | --- | --- |
| 667px | unreachable: `Shop`, `SHOP EBAY`; `scrollable:false` | unreachable: none; first+last reachable |
| 600px | unreachable: `Shop`, `What We Carry`, `SHOP EBAY` | unreachable: none |
| 800px | 1 item under the nav bar | 0 items under the nav bar |

Undo: `git revert` the commit, or restore the four lines in the diff.

### Also fixed: the category grid was wider than its container (be4091d)

Pre-existing, **not** from the drawer work — measured identical before and after
73e36ef, so do not attribute it to that commit.

`.categories-grid` used `repeat(3, 1fr)`. A `1fr` track is `minmax(auto, 1fr)`
and its auto minimum is **min-content**, so tracks could not shrink below the
widest card (`ACCESSORIES` 82.7px + 18px padding = 100.7px) and grew past the
container instead.

| Viewport | Track row over its container, before | After |
| --- | --- | --- |
| 320px | **+61.9px** (27px of document sideways scroll) | 0.0px |
| 360px | +21.9px | 0.0px |
| 375px | +6.9px | 0.0px |
| 414px and up | 0 (unaffected) | 0.0px |

Tracks were also lopsided (85.5 / 108.7 / 108.7, spread 23.3px); now equal to
within 0.02px. **At 320px the whole third column ran off-screen** — BAGS, MEN'S,
ACCESSORIES and & MORE cut mid-word.

Fix: `minmax(0, 1fr)` on all three breakpoints, `.cat-card` padding-x 0.75rem ->
0.5rem plus `min-width: 0`, `.cat-name { overflow-wrap: anywhere }`.

**Cost, stated rather than hidden:** at <=375px `ACCESSORIES` and `ELECTRONICS`
wrap to two lines. Three one-line columns genuinely do not fit there (3 x 100.7
+ 24px gaps = 326px against 320px available), so the old layout avoided wrapping
only by overflowing. Shrinking the type and dropping to two columns were both
tried and measured worse. 414px and above is identical to before.

### Also fixed: contrast, landmark, meta description, reduced motion

- **Contrast (bd/see log): 24 failing styles -> 0**, worst ratio 1.88 -> 4.57,
  same 160 elements examined both sides. Cause was palette colours used as TEXT
  (`--rose` 2.54-3.31, `--gold` 1.72-2.24, greys, white at 30-40% on #111).
  Fixed with **text-only variants** — `--rose-text #A8442F`, `--gold-text
  #7E6128`, `--muted-text #6B6B6B` — leaving the brand colours untouched for
  borders and fills (7 decorative `var(--rose)` uses remain).
  **Visible change:** the primary button and rose accents are a deeper
  terracotta. One `git revert` undoes it if Jaimmie prefers the lighter rose.
- **`<main>`** wraps all 9 sections (nav/footer outside). Zero layout change —
  document height and every section offset identical at 375px and 1280px.
- **Meta description** added, 150 chars. There was none.
- **`prefers-reduced-motion`** disables smooth scroll, collapses transitions to
  0.01ms and forces `.reveal` to its final state. Proven by rewriting the media
  condition and reading the cascade: opacity 0->1, transform ->none, scroll
  smooth->auto, transition 0.6s->1e-05s. **Not proven: that the OS setting
  reaches the page** — the media feature is supported here but the system
  preference cannot be flipped from this harness.

**Verified on the LIVE deployed Pages build**, not just locally: at 375x667,
320x600 and 1280x900 — 0 contrast failures, no horizontal overflow, 1 `<main>`,
reduced-motion rule present, drawer scrollable with first and last item
reachable and 0 items under the nav bar. Positive controls green in the same run
(black-on-white 21, white-on-white 1).

## Still open

- **No Lighthouse run** — there is no headless browser wired up here, and this
  repo must stay dependency-free, so a Playwright/Lighthouse install would need
  Tre's say-so. The checks above were driven through the Chrome tools instead.
- **Two emoji nodes score below AA** (`✉️` 1.45, and the tag emoji). Emoji
  ignore CSS `color`, so these are instrument artefacts, **not defects** — do
  not "fix" them and do not count them.
- **Focus styles are the browser default.** Nothing removes outlines
  (`outline: none` appears 0 times), so keyboard focus is visible but unstyled.
  A designed `:focus-visible` ring would be an improvement, not a fix.
- **Tap targets**: 15 controls are under 44px (AAA 2.5.5); all clear the 24px
  AA floor of 2.5.8. Not a failure.

## Resume queue

**FIRST UP NEXT TIME, one thing:** nothing, unless Tre says the DNS is moved.
The activation is now **automatic** - `.github/workflows/activate-custom-domain.yml`
watches the apex and commits `/CNAME` itself the moment
`missjaimmiescloset.com` resolves to the four GitHub Pages addresses. There is
no longer a second action for anyone here to remember.

If you want to know the state right now, read the last run:
`gh run list --workflow=activate-custom-domain.yml --limit 1`. A **green** run
means the check ran and said not-yet. A **red** run means the *resolver* failed
and the run proved nothing - fix the instrument, do not read it as "not yet".

**RE-MEASURED 2026-09-22 and unchanged** - confirmed today rather than
repeated from the reading below. `https://` apex and `www` both fail the TLS
handshake (curl exit 35, status 000, no-follow), `http://www` still serves the
583-byte Weebly placeholder, the apex still resolves to `199.34.228.66`, the
five MX rows are still live, and the Pages target still returns 200 / 40,542
bytes / sha256 byte-identical to `index.html`. So the item below says "still"
on the strength of a measurement taken today.

**TWO THINGS LANDED 2026-09-22 that change what a cold session should expect:**

1. **The cron's "every ~10-30 minutes" was never measured and is FALSE.**
   Across 38 scheduled runs 2026-09-16 to 2026-09-22 the gap between fires ran
   **min 118 / median 194 / max 423 minutes** - 6.7 runs a day against the 144
   that `*/10` asks for, and **all 37 gaps exceeded 30 minutes**. So after Tre's
   registrar edit the site comes up in **two to seven hours** unforced, not half
   an hour. Corrected in the workflow header, `_tools/README.md`,
   `_tools/CUTOVER.md` and this file (commit `deca6ff`). The cron was
   deliberately NOT shortened - GitHub drops short crons on quiet repos whatever
   the expression says.

2. **`gh workflow run` - the way to force it - DOES NOT WORK on this machine.**
   `gh auth status` reads *the token in default is invalid*; the dispatch
   returns HTTP 401. **Do not test this with `gh run list`:** this repo is
   PUBLIC, so gh falls through to an unauthenticated request and the reads look
   perfectly healthy. `gh api user` returns *Requires authentication* and a
   private repo returns 404 - those discriminate, the read does not. `git push`
   is unaffected (SSH; `ssh -T git@github.com` greets treforged, and three
   pushes went out today). Commit `63a2ebd`. Reported to Sam, who was already
   working the machine-wide sign-out question.

**A RENDERED layout gate now exists**: `scripts/check-layout.mjs` (commit
`5dc88ac`), measuring document and grid overflow plus track spread at 320 / 360
/ 375 / 414 / 768 / 1280px. Run it as:

```sh
PLAYWRIGHT_PKG=file:///C:/Users/tvonh/Desktop/TRE-Forged/getforgenta/node_modules/playwright/index.mjs   node scripts/check-layout.mjs --repo .
```

Proven in four arms; the red one restores the REAL pre-fix state and reproduces
the 27px / 23.3px figures recorded above from a different instrument.
**It is NOT in CI** - the page's fonts come from Google and the defect is driven
by text width, so a runner without them measures different numbers and could cry
wolf on every push. It prints which fonts actually resolved; wire it up only
after reading that line on a real runner.

⚠ **If you ever mutate to re-prove it, REVERT ALL THREE halves of the fix**
(`minmax(0, 1fr)`, `.cat-card min-width: 0`, `.cat-name overflow-wrap: anywhere`).
The first two remove the min-content floor by different routes, so reverting one
leaves the gate GREEN - measured, not assumed.

**A pre-commit secret guard now runs in this repo** (commit `59870a9`), copied
byte-identical from tre-forged-conductor. The pre-push hook that lived in
`.git/hooks/` was MOVED into `.githooks/` first, so setting
`core.hooksPath --local` did not shadow it - git resolves pre-push to
`.githooks/pre-push`, proven both ways. Undo:
`git config --local --unset core.hooksPath`.

Measured 2026-09-16, and this is the state the whole desk turns on:

- The public site is **broken, not merely stale**. `https://` fails the TLS
  handshake on the apex and on `www` (curl exit 35, status 000, no-follow), and
  `http://www` returns **200** with a 583-byte Weebly placeholder reading
  *"Thanks for purchasing - This temporary landing page will be replaced when
  you publish your site."* There is no old site to preserve.
- Apex `A` = `199.34.228.66` (Weebly/Square behind Cloudflare), **TTL 14400**.
  `www` is an **A record, not a CNAME**. NS are register.com's four.
- **Google Workspace mail is LIVE** on the domain - five MX at `aspmx.l.google.com`
  and `alt1-4`. A DNS move that does not carry those kills her email. This is the
  single most important fact in this file.
- **No TXT records at all**, so **no SPF**; no DMARC, no `google._domainkey`
  DKIM. Recorded, deliberately NOT acted on - deliverability on a live business
  mailbox is its own decision.
- The Pages target is healthy: `treforged.github.io/missjaimmiescloset/` returns
  **200 no-follow**, 40,542 bytes, `sha256` byte-identical to `index.html`,
  valid TLS, built at the current commit.

- [x] **The cutover is now ONE action Tre takes at the registrar.** Written up
  in **`_tools/CUTOVER.md`** - exact rows to delete and add, the register.com
  screen, propagation, email impact, and what could not be verified without his
  access. Recommended path is editing A/CNAME rows at register.com rather than
  a nameserver move to Cloudflare: two minutes, zero email risk, and Cloudflare
  can still follow later on its own.
- [ ] **Waiting on Tre only: the DNS edit.** Do not touch DNS and do not chase
  him. Everything on this side is done and proven.
- [ ] **Unexercised, and it will first run on the day it matters:** the
  workflow's `git push` step. Its decision logic is proven in all six
  directions, but the push cannot be exercised until DNS actually moves. Undo
  if it misfires is `git rm CNAME` and a push.
- [ ] **Nothing else queued.** The accessibility backlog is cleared.

<!-- AUTO-SNAPSHOT:BEGIN - machine-written, replaced each compaction -->
## Auto-snapshot

_Written 2026-09-16 13:16 by handoff_hook. Everything below this heading is
machine-generated and replaced each time; put durable notes above it._

- **Branch:** `main`
- **vs upstream:** 0 ahead, 0 behind

- **Working tree:** clean

- **Recent commits:**

```
46ad459 docs: record the measured state of the live domain and the automatic cutover
b59ed1d feat: make the domain cutover one action Tre takes at the registrar
536b9b7 docs: name the one thing that is first up next session
9de1298 docs: refresh handoff auto-snapshot
34c38b7 docs: record that _tools is excluded from the published site, measured
b0bc47b chore: prepare the custom domain and an outside verifier, without activating
3c237e8 docs: record the contrast, landmark, meta and reduced-motion work
db5f3a1 feat: main landmark, meta description, and prefers-reduced-motion
```

<!-- AUTO-SNAPSHOT:END -->
