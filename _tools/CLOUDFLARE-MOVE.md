# Off GitHub, onto Cloudflare (ask ae2b69b0, Tre 2026-10-16)

Cloudflare has no git hosting, so "off GitHub" splits in two:

1. **Serving (moves).** Cloudflare Pages direct upload: `_tools/deploy-cloudflare.sh`. The site is two files
   (`index.html`, `og-image.jpg`), no build. Replaces GitHub Pages and the A/CNAME targets in CUTOVER.md
   (apex and www become a Pages custom domain, proxied, once the domain is on Cloudflare DNS).
2. **Source (stays, for now).** The repo remains on GitHub as a private/backup remote. Nothing is archived,
   deleted or made private until Sam confirms. Undo for everything here: revert this commit; GitHub Pages is untouched.

Blocked on Tre's hands: Cloudflare login (`npx wrangler login`) or an API token, and the domain reaching Cloudflare DNS (db52da5f).
Until then the first deploy can go to `missjaimmiescloset.pages.dev` as soon as auth exists.
After cutover: retire `.github/workflows/activate-custom-domain.yml` and the `_tools/CNAME.ready` flow (they serve GitHub Pages only).
