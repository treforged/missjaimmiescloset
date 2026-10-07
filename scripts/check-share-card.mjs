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
 * a domain that is still on Weebly. It does not fetch og:image over the network;
 * it checks the tags and that the committed og-image.jpg the URL names really
 * is a 1200x630 JPEG (added 2026-10-07 with the image).
 */
import { pathToFileURL } from 'node:url';
import { readFileSync } from 'node:fs';
import { dirname, join, basename } from 'node:path';
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
      ogImage: g('meta[property="og:image"]','content'),
      ogImgW: g('meta[property="og:image:width"]','content'),
      ogImgH: g('meta[property="og:image:height"]','content'),
      ogImgAlt: g('meta[property="og:image:alt"]','content'),
      twImage: g('meta[name="twitter:image"]','content'),
      canonical: g('link[rel="canonical"]','href'),
    };
  });
  const req = ['ogTitle','ogDesc','ogUrl','ogType','ogSite','twCard','canonical','ogImage','ogImgW','ogImgH','ogImgAlt','twImage'];
  for (const k of req) console.log(`  ${k.padEnd(10)} ${d[k] ? 'OK ' : 'MISSING'}  ${String(d[k]).slice(0,58)}`);
  const missing = req.filter(k => !d[k]);
  console.log(`  title == og:title        : ${d.title === d.ogTitle}`);
  console.log(`  description == og:desc   : ${d.desc === d.ogDesc}`);
  // The image the tag names must be the committed file, and must really be 1200x630 JPEG.
  let imgOk = false, imgWhy = 'no og:image';
  if (d.ogImage) {
    try {
      const buf = readFileSync(join(dirname(process.argv[2]), basename(new URL(d.ogImage).pathname)));
      let i = 2, w = 0, h = 0;
      if (buf[0] !== 0xFF || buf[1] !== 0xD8) throw new Error('not a JPEG');
      while (i < buf.length) {
        const m = buf[i + 1], len = buf.readUInt16BE(i + 2);
        if (m >= 0xC0 && m <= 0xC3) { h = buf.readUInt16BE(i + 5); w = buf.readUInt16BE(i + 7); break; }
        i += 2 + len;
      }
      imgOk = w === 1200 && h === 630 && d.ogImgW === '1200' && d.ogImgH === '630' && d.twImage === d.ogImage;
      imgWhy = `file ${w}x${h}, tags ${d.ogImgW}x${d.ogImgH}, twitter:image ${d.twImage === d.ogImage ? 'matches' : 'DIFFERS'}`;
    } catch (e) { imgWhy = 'file unreadable: ' + e.message; }
  }
  console.log(`  og:image 1200x630 jpeg   : ${imgOk}  (${imgWhy})`);
  console.log(`  twitter:card large image : ${d.twCard === 'summary_large_image'}`);
  if (missing.length) { console.log('MISSING: ' + missing.join(', ')); process.exitCode = 1; }
  else if (!imgOk || d.twCard !== 'summary_large_image') { console.log('IMAGE: share image is wrong or absent'); process.exitCode = 1; }
  else if (d.title !== d.ogTitle || d.desc !== d.ogDesc) { console.log('DRIFT: share copy differs from page copy'); process.exitCode = 1; }
  else console.log('  ALL PRESENT AND CONSISTENT');
} finally { await b.close(); }
