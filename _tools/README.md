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

### Activation, once Tre says DNS is on Cloudflare and pointing at Pages

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

Re-check all of this if the repo is ever switched to a `workflow` build, which
does not use Jekyll and would publish this folder.
