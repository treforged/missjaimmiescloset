# `_tools/` — not part of the website

Jekyll (this repo is a `build_type: legacy` Pages site) excludes directories
whose name starts with `_`, so nothing in here should be published. That is
checked against the live site rather than assumed — see "Is it really not
served?" below.

Nothing in this folder runs automatically and nothing here is a dependency of
the page. `index.html` is still the whole site.

---

## `CNAME.ready` — the custom domain, prepared but DELIBERATELY NOT ACTIVE

**Do not rename this to `/CNAME` until DNS for `missjaimmiescloset.com` actually
points at GitHub Pages.** Committing it early does real damage, and it is not
obvious why, so it is written down here rather than left to be rediscovered.

Measured 2026-09-15 from `gh api repos/treforged/missjaimmiescloset/pages`:

```
"cname": null,  "build_type": "legacy",  "https_enforced": true
```

Two things follow:

1. A `CNAME` file **sets the custom domain**. Once set, Pages 301-redirects
   `treforged.github.io/missjaimmiescloset/` to the custom domain — so the one
   URL that currently works would start redirecting to one that does not.
2. **`https_enforced` is `true`.** The redirect target would be an `https://`
   URL on a domain with no valid certificate for that name. Today that domain
   refuses the TLS handshake on all three stacks tested.

So activating early does not "get ahead of the work". It takes the site down.

### Activation is AUTOMATIC. Nobody does this by hand any more.

`.github/workflows/activate-custom-domain.yml` runs on a schedule, resolves the
apex, and performs the `git mv` itself the moment `missjaimmiescloset.com`
resolves to the four GitHub Pages addresses. **Tre's registrar edit is the whole
cutover** — there is no second step to coordinate and no message to relay.

The records he changes are in [`CUTOVER.md`](./CUTOVER.md).

**HOW LONG IT ACTUALLY TAKES, measured rather than assumed.** The cron asks for
every 10 minutes. GitHub does not honour it. Over 38 scheduled runs from
2026-09-16 to 2026-09-22 the gap between fires was **min 118 / median 194 / max
423 minutes** - 6.7 runs a day against the 144 the expression asks for, and
**every one of the 37 gaps exceeded 30 minutes**.

So after the registrar edit, left alone, the site comes up somewhere between
**two and seven hours** later - not in half an hour. Nobody should sit watching.

**Do not wait for the schedule. Force it:**

```sh
gh workflow run activate-custom-domain.yml
```

That fires in seconds and runs exactly the same checks, including the positive
control. It is safe to run at any time: if DNS has not moved the job measures
that and does nothing, and if `CNAME` is already in place it exits early. There
is no state to corrupt by running it too often.

**It needs a working `gh` login, and on 2026-09-22 this machine did not have
one.** `gh auth status` reads *the token in default is invalid*, and the
dispatch fails `HTTP 401`.

**Do not read a successful `gh run list` as proof the login works.** This repo
is **public**, so gh falls through to an unauthenticated request and the reads
answer normally with no credential involved. That is why the breakage is
invisible from the command anyone would naturally try. The discriminating
checks, both run here:

```sh
gh api user                      # Requires authentication  -> not logged in
gh api repos/treforged/dot-claude  # 404 on a PRIVATE repo  -> not logged in
```

`git push` is unaffected - it goes over SSH, which authenticates fine
(`ssh -T git@github.com` greets `treforged`). Two transports, two answers; a
claim about one is not a claim about the other.

**Reading the workflow's runs, and the one reading that is a trap:**

```sh
gh run list --workflow=activate-custom-domain.yml --limit 1
```

- **green** — the check ran and said *not yet*. This is the normal state.
- **red** — the *resolver* failed, so the run proves **nothing about the
  domain**. Fix the instrument. Do not read a red as "not yet".

That distinction is the reason the job carries a positive control: a resolver
that cannot answer returns an empty list, which is indistinguishable from a
domain that has not moved. Without the control this job would sit green for
ever while being structurally incapable of ever firing. It resolves
`treforged.github.io` first — whose addresses are known — and exits non-zero if
that does not come back.

Proven before it was committed, six outcomes, each able to fail:

| Case | Result |
| --- | --- |
| resolver blind | **exit 1, RED** — "this run proves NOTHING" |
| domain still at Weebly (the real value that day) | not ready |
| domain returns no A records | not ready |
| all four Pages addresses | **READY** — the only case that activates |
| `/CNAME` already present | nothing to do |
| mixed Pages + foreign addresses | not ready |

Exercised live on 2026-09-16 (run `35126787324`): the control returned the four
real Pages addresses, the target returned `199.34.228.66`, and it reported NOT
READY on a **green** run.

**Still unexercised:** the `git push` itself, which cannot run until DNS
actually moves — so it runs for the first time on the day it matters.

### Doing it by hand, if the workflow is ever disabled

GitHub disables scheduled workflows on a repository with no activity for 60
days. If that has happened, the manual sequence still works — and the warning
at the top of this section still applies, so **only once DNS already points at
Pages**:

```sh
git mv _tools/CNAME.ready CNAME
git commit -m "chore: point the custom domain at this Pages site"
git push origin main
```

Then **verify from outside** — do not trust the settings screen:

```powershell
_tools/verify-domain.ps1
```

### Undo, if it goes wrong

```sh
git rm CNAME && git commit -m "revert: unset the custom domain" && git push
```

Pages drops the custom domain and `treforged.github.io/missjaimmiescloset/`
serves directly again. Allow a few minutes for the build.

---

## `verify-domain.ps1` — does the domain serve THIS repo?

Answers one question and refuses to guess. Exit `0` serving, `1` not serving,
`2` cannot tell.

**Three TLS stacks** (.NET/schannel, curl, python/OpenSSL) because one stack
failing can be a local quirk; three agreeing is a fact about the server. On
2026-09-15 all three refused — `SEC_E_ILLEGAL_MESSAGE`, `status=000`, and
`SSLV3_ALERT_HANDSHAKE_FAILURE` — alongside Chrome's
`ERR_SSL_VERSION_OR_CIPHER_MISMATCH`.

**A positive control** (`treforged.com`) is fetched in the same run. If the
control fails, the script exits `2` and says the instrument is blind, rather
than blaming the domain. It does this **even when the subject looks green** —
proven below.

**It compares the body**, because the domain previously answered http 200 with
a 583-byte Square placeholder reading *"Thanks for purchasing"*. A 200 is a
fact about the HTTP layer, not about whose page came back.

**No-follow on the status check**, because a followed 200 is a fact about
wherever you landed.

### Proven in all three directions, 2026-09-15

| Case | Result |
| --- | --- |
| real domain (broken) | `exit 1` — NOT SERVING, 0/3 stacks, control green |
| `-Domain` the Pages URL (works) | `exit 0` — SERVING, 3/3 stacks, marker found |
| Pages URL but `-Control` unreachable | `exit 2` — CANNOT TELL, **despite the subject being 3/3 green** |

The `-Domain` / `-Control` parameters exist **only** so those paths can be
proven. Left at the defaults it asks the real question about the real domain.

### What it does not check

Whether the page *looks* right. It says so on success: open it and look at it.

---

## Is it really not served?

`_`-prefixed directories being excluded is a property of Jekyll, not a promise,
so it is checked rather than assumed:

```powershell
foreach ($p in '_tools/verify-domain.ps1','_tools/CNAME.ready','_tools/README.md') {
  try { (Invoke-WebRequest "https://treforged.github.io/missjaimmiescloset/$p" -UseBasicParsing).StatusCode }
  catch { "404 (expected) - $p" }
}
```

**Result, 2026-09-15:** all three paths return 404, and `index.html` returns
200 in the same run. That positive control matters — without it a 404 could
just mean the build had not landed yet, which is exactly what happened on the
first attempt: the check was run while
`gh api .../pages/builds/latest` still said `"status": "building"`, so the
404s proved nothing. Confirm the build reports `built` for the commit you care
about *before* trusting a 404.

**Re-confirmed 2026-09-16**, after `.github/` and `_tools/CUTOVER.md` were
added, and only once `pages/builds/latest` reported `"status": "built"` for the
commit that added them:

```
.github/workflows/activate-custom-domain.yml   404
_tools/CUTOVER.md                              404
index.html                                     200   <- positive control
```

The 200 in the same run is what makes the 404s mean "excluded" rather than
"the build has not landed". `.github` is dot-prefixed, which Jekyll also
excludes, so the workflow is not published either.

Re-check all of this if the repo is ever switched to a `workflow` build, which
does not use Jekyll and would publish this folder.
