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

### Fixing it needs Tre (registrar credentials + a decision)

The repo half is one file (`CNAME`). The other half is DNS at register.com or
the Square/Weebly domain settings, both his accounts. CLAUDE.md also forbids DNS
changes without him. **Deliberately not started** — see "Actions for Tre" in the
session report.

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

## Still open

- **27 text styles below WCAG AA contrast** on the Pages copy. Worst real ones:
  `.review-author` 2.32, `.shipping-tag` 2.54, the footer DBA line 2.67, the
  contact email link 2.84 (all need 4.5). **Caveat: some of the 27 are emoji**
  (`✉️ 1.45`, `🚚`, `📍`) which ignore CSS `color`, so they are false positives —
  do not quote 27 as a defect count without re-checking which are real.
  ⚠️ The first version of this probe reported **every** hit as exactly `1.00`
  because it treated a semi-transparent same-hue tint as an opaque background
  and compared text to itself. Composite alpha down to white, and give the probe
  positive controls (black/white must be 21, white/white must be 1) before
  believing any number it prints.
- No `<main>` landmark, no meta description, no `prefers-reduced-motion`
  handling (the page has reveal animations + `scroll-behavior:smooth`).
- No Lighthouse run — there is no headless browser wired up here.

## Resume queue

- [ ] **Blocked on Tre: point the domain at the Pages site** (or decide the
  Weebly/Square site is the intended one instead). Needs registrar credentials
  and a genuine fork-in-intent call. Everything else here is unblocked.
- [ ] Contrast pass on the genuine sub-AA styles, emoji excluded. **Report the
  number actually fixed — the ~27 figure is not a defect count.**
- [ ] Add `<main>`, a meta description, and a `prefers-reduced-motion` block.

<!-- AUTO-SNAPSHOT:BEGIN - machine-written, replaced each compaction -->
## Auto-snapshot

_Written 2026-09-15 10:17 by handoff_hook. Everything below this heading is
machine-generated and replaced each time; put durable notes above it._

- **Branch:** `main`
- **vs upstream:** 0 ahead, 0 behind

- **Working tree:** clean

- **Recent commits:**

```
73e36ef fix: mobile drawer trapped its own first and last items on short phones
5afd7dd docs: this repo gets a charter and a named executive (Iris)
733526e Add files via upload
7fea0cf Add files via upload
78a7fcf Add files via upload
af0452e Add files via upload
9fbfd84 Add files via upload
e35e07f Add files via upload
```

<!-- AUTO-SNAPSHOT:END -->
