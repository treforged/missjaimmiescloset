# The cutover — what Tre changes, on one screen, in about two minutes

Everything below was **measured on 2026-09-16**, not assumed. Commands that
produced each figure are named so any of it can be re-run.

---

## The one action

At **register.com** → sign in → **My Domains** → `missjaimmiescloset.com` →
**Manage DNS** (also labelled *Advanced DNS* or *Edit DNS Zone*).

### Delete these two rows

| Type | Name | Value |
| --- | --- | --- |
| A | `@` (may show as blank, or as `missjaimmiescloset.com`) | `199.34.228.66` |
| A | `www` | `199.34.228.66` |

### Add these five rows

| Type | Name | Value |
| --- | --- | --- |
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| CNAME | `www` | `treforged.github.io` |

Optional, only if the form offers IPv6 — the site works without them:

| Type | Name | Value |
| --- | --- | --- |
| AAAA | `@` | `2606:50c0:8000::153` |
| AAAA | `@` | `2606:50c0:8001::153` |
| AAAA | `@` | `2606:50c0:8002::153` |
| AAAA | `@` | `2606:50c0:8003::153` |

### Do not touch

- **The five MX rows.** They are live Google Workspace mail. See *Email* below.
- **The nameservers.** They stay at register.com.

**Then nothing else.** A scheduled job in this repo
(`.github/workflows/activate-custom-domain.yml`) watches the DNS and commits the
`CNAME` file by itself the moment the change lands. There is no second step to
remember and no message to send.

---

## Why these addresses, and why not Cloudflare today

The four `185.199.*` addresses were confirmed **two independent ways** in the
same session: they are what `treforged.github.io` resolves to live, and they are
what GitHub's current documentation publishes. Neither was taken from memory.

Moving the nameservers to Cloudflare is a **different and larger job** — every
existing record, including the five MX rows, has to be recreated at Cloudflare
*before* the nameservers change, or mail stops. Editing two A records at the
registrar fixes the site in two minutes and cannot touch mail at all. Cloudflare
can still happen afterwards, on its own, with the site already working.

---

## After you press save, nothing else is yours to do

A workflow in this repo watches the domain and switches the site on by itself.
You do not have to tell anyone, and there is no second step.

**But do not sit and watch for it.** The schedule asks GitHub to check every 10
minutes and GitHub does not honour that on a quiet repo. Measured over 38 runs
between 2026-09-16 and 2026-09-22, the real gap between checks was **two to
seven hours**, and it never once checked within half an hour.

So: make the edit, close the tab, and expect the site later the same day.
**Tell whoever is at this desk that you have moved the DNS** and they will try
to force it; if they cannot, the schedule still does it by itself.

Forcing it is one command, and it takes seconds:

```sh
gh workflow run activate-custom-domain.yml
```

> **Measured 2026-09-22: that command does NOT work on this machine right now.**
> `gh`'s stored token is invalid, so every write is refused. The reads still
> succeed and that is a trap rather than a reassurance - this repo is **public**,
> so `gh run list` answers with no credential at all and looks healthy. Proven by
> asking for something that needs auth: `gh api user` returns *Requires
> authentication*, and a private repo returns 404.
>
> Until someone runs `gh auth login`, the schedule is the only route and the
> wait is the two-to-seven hours above. Nothing is lost by waiting - the
> workflow is doing the right thing, just slowly.

---

## What breaks during propagation, and for how long

- **The apex A record's TTL is 14,400 seconds — four hours.** Resolvers that
  have already cached the Weebly address may keep serving it for up to that
  long. Most will pick the change up within minutes.
- During that window some visitors reach the new site and some reach the old
  placeholder. **Nobody is worse off than they are now**, because right now
  every `https://` visitor gets a hard TLS failure.
- **The certificate is issued after DNS moves, not before.** GitHub requests a
  Let's Encrypt certificate only once the domain resolves to Pages; that takes
  minutes to about an hour. Until it lands, `https://` on the domain may still
  fail — again, no worse than today.

---

## Email: unaffected, and here is why

`missjaimmiescloset.com` runs **Google Workspace mail**, live today:

```
MX  1  aspmx.l.google.com
MX  5  alt1.aspmx.l.google.com      MX  5  alt2.aspmx.l.google.com
MX 10  alt3.aspmx.l.google.com      MX 10  alt4.aspmx.l.google.com
```

A and CNAME records address web traffic. MX records address mail. Changing the
first does not touch the second, **provided the MX rows are left alone** — which
is why they are called out above rather than left to be noticed.

### A separate finding, not caused by this change

The domain has **no TXT records at all** — so **no SPF record** — and no DMARC
record at `_dmarc`, and no DKIM key at `google._domainkey`. Mail from this
domain is therefore more likely to be filtered as spam than it needs to be.

That is a deliverability change on a live business mailbox, so it is **recorded,
not acted on**. It is worth fixing separately and deliberately.

---

## What was measured, and how

| Fact | Evidence |
| --- | --- |
| Domain does not serve this repo | `http://www` returns **200** with a 583-byte Weebly placeholder titled *"Thanks for purchasing — This temporary landing page will be replaced when you publish your site."* |
| `https` fails on both names | `curl` exit **35**, status **000**, apex and `www`, no-follow |
| `http` apex redirects to `www` | **301** to `http://www.missjaimmiescloset.com/`, served by Cloudflare in front of Weebly (`X-Host: blu40.sf2p.intern.weebly.net`) |
| The Pages site is healthy and current | `https://treforged.github.io/missjaimmiescloset/` → **200 no-follow**, 40,542 bytes, `sha256` **byte-identical** to the working copy's `index.html`, valid TLS |
| Pages is built from the current commit | `pages/builds/latest` → `"status":"built"`, commit `536b9b7` |

Every fetch was cache-busted and read **no-follow**. A 200 is a fact about the
HTTP layer, never about which site answered — so the body was checked in each
case, which is exactly how the Weebly placeholder was caught behind a 200.

---

## What could NOT be verified without Tre's access

These are open, and none of them is guessed at above:

1. **The exact wording on register.com's DNS screen.** There is no account
   access here. The field names used above are the standard ones; the labels
   may read differently.
2. **Whether the `www` row will accept a CNAME.** Some registrars refuse a CNAME
   on a name that carries other records. If it is refused, delete the `www` A
   row first, then add the CNAME.
3. **Whether Weebly or Square is still being paid for**, and whether anything
   else — a shop, a booking page, a checkout link — depends on `199.34.228.66`.
   The page found there is an *unpublished-site placeholder*, which suggests
   nothing is live on it, but that is an inference and not a measurement.
4. **Whether any mail alias or subdomain** beyond the apex is in use.
5. **The push step of the activation workflow is unexercised.** Its decision
   logic is proven in all six directions; the `git push` itself cannot run until
   DNS actually moves, so it will be exercised for the first time on the day it
   matters. The undo if it misfires is `git rm CNAME` and a push.

---

## Undo

If anything goes wrong, put the two original rows back:

| Type | Name | Value |
| --- | --- | --- |
| A | `@` | `199.34.228.66` |
| A | `www` | `199.34.228.66` |

and in this repo `git rm CNAME && git commit && git push`, which drops the
custom domain and restores `treforged.github.io/missjaimmiescloset/`.
