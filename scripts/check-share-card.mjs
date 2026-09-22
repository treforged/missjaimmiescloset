/*
 * Does this page produce a readable card when somebody SHARES the link?
 *
 *   PLAYWRIGHT_PKG=file:///.../playwright/index.mjs  *     node scripts/check-share-card.mjs index.html
 *
 * WHY. This site's whole job is sending people to the Poshmark and eBay
 * closets, and that traffic arrives because somebody shared the link - an
 * Instagram bio, a Facebook post, an iMessage. Until 2026-09-22 the page
 * carried NO Open Graph or Twitter tags at all, so every share rendered as a
 * bare grey URL. Nothing in the repo showed it and no gate could see it.
 *
 * IT READS THE PARSED DOM, not the file as text, so a tag inside a comment or
 * broken markup cannot count as present.
 *
 * IT ALSO ASSERTS THE COPY MATCHES the <title> and meta description. The share
 * text is deliberately the same wording as the page, so there is one copy to
 * keep true; this is what catches the two drifting apart later.
 *
 * Exit 0 all present and consistent, 1 missing or drifted.
 *
 * PROVEN RED 2026-09-22 by deleting og:title (exit 1, names it) and by
 * rewording og:description (exit 1, DRIFT), index.html restored byte-exact by
 * sha256 both times.
 *
 * WHAT IT DOES NOT CHECK: whether Facebook or iMessage actually like the card -
 * only their own scrapers settle that, and they cannot reach a file:// path or
 * a domain that is still on Weebly. It also does not require og:image, because
 * the repo has no image asset; if one is ever added, add the assertion too.
 */
import { pathToFileURL } from 'node:url';
const pw = await import(process.env.PLAYWRIGHT_PKG);
const b = await pw.chromium.launch();
try {
  const p = await b.newPage();
  await p.goto(pathToFileURL(process.argv[2]).href, {waitUntil:'load'});
  const d = await p.evaluate(() => {
    const g = (sel,a) => { const e=document.querySelector(sel); return e ? e.getAttribute(a) : null; };
    return {
      title: document.title,
      desc: g('meta[name="description"]','content'),
      ogTitle: g('meta[property="og:title"]','content'),
      ogDesc: g('meta[property="og:description"]','content'),
      ogUrl: g('meta[property="og:url"]','content'),
      ogType: g('meta[property="og:type"]','content'),
      ogSite: g('meta[property="og:site_name"]','content'),
      twCard: g('meta[name="twitter:card"]','content'),
      canonical: g('link[rel="canonical"]','href'),
    };
  });
  const req = ['ogTitle','ogDesc','ogUrl','ogType','ogSite','twCard','canonical'];
  for (const k of req) console.log(`  ${k.padEnd(10)} ${d[k] ? 'OK ' : 'MISSING'}  ${String(d[k]).slice(0,58)}`);
  const missing = req.filter(k => !d[k]);
  console.log(`  title == og:title        : ${d.title === d.ogTitle}`);
  console.log(`  description == og:desc   : ${d.desc === d.ogDesc}`);
  console.log(`  twitter:card == summary  : ${d.twCard === 'summary'}`);
  if (missing.length) { console.log('MISSING: ' + missing.join(', ')); process.exitCode = 1; }
  else if (d.title !== d.ogTitle || d.desc !== d.ogDesc) { console.log('DRIFT: share copy differs from page copy'); process.exitCode = 1; }
  else console.log('  ALL PRESENT AND CONSISTENT');
} finally { await b.close(); }
