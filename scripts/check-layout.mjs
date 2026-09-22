/*
 * A RENDERED guard for the narrow-viewport layout of index.html.
 *
 *   PLAYWRIGHT_PKG=file:///.../playwright/index.mjs node scripts/check-layout.mjs --repo .
 *
 * WHY IT MEASURES PIXELS. index.html once shipped `.categories-grid` as
 * `repeat(3, 1fr)`. A `1fr` track is `minmax(auto, 1fr)` and its auto minimum is
 * MIN-CONTENT, so the track row could not shrink below the widest card and grew
 * past its container instead: at 320px the third column ran off-screen and BAGS,
 * MEN'S, ACCESSORIES and & MORE were cut mid-word. No string or source check can
 * see that. Only a rendered box can.
 *
 * EXIT 0 clean, 1 a real layout defect, 2 could not check.
 *
 * PROVEN IN FOUR ARMS, and the red one used the REAL historical defect rather
 * than a contrived mutation:
 *   current page                     exit 0
 *   true pre-fix state restored      exit 1 - 320px doc overflow 27.00px,
 *                                    spread 23.28px, and 414px+ unaffected
 *   `.categories-grid` renamed       exit 2 CONTROL FAILED, never a pass
 *   playwright absent                exit 2
 *
 * Those red numbers independently reproduce what a previous session measured
 * with a different instrument (recorded in handoff.md as 27px of sideways
 * scroll and a 23.3px spread), which is the reason to believe the green.
 *
 * ⚠ THE FIX IT GUARDS IS REDUNDANT, AND THAT MATTERS FOR ANY FUTURE MUTATION.
 * Three changes made it: `minmax(0, 1fr)` on the tracks, `min-width: 0` on
 * `.cat-card`, and `overflow-wrap: anywhere` on `.cat-name`. The first two
 * remove the min-content floor by different routes, so REVERTING ONLY ONE LEAVES
 * THIS GATE GREEN - measured, and it is how the exit-code defect below was
 * nearly missed. A mutation here must revert all three, or it proves nothing.
 *
 * WHAT IT DOES NOT COVER, said plainly rather than implied:
 *   - Colour, contrast, copy, and anything above or below the categories grid
 *     except whole-document sideways overflow.
 *   - The DEPLOYED page. It reads the local file, and GitHub Pages can serve
 *     something else.
 *   - It is NOT wired into CI. The page pulls Cormorant Garamond and DM Sans
 *     from Google Fonts and the defect is driven by TEXT WIDTH, so a runner
 *     without those fonts measures different numbers. That could cry wolf on
 *     every push, and a gate that cries wolf is one somebody switches off on the
 *     day it matters. It prints which fonts actually resolved (via
 *     `document.fonts.check`, not `fonts.status`, which reads 'loaded' even when
 *     the download failed); wiring it to CI is safe only once somebody has read
 *     that line on a real runner.
 *
 * Node >=14, ESM, top-level await.
 */

import { resolve, join } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';
import { existsSync } from 'fs';

// Resolve Playwright, respecting PLAYWRIGHT_PKG env var.
let playwright;
try {
  const pkg = process.env.PLAYWRIGHT_PKG || 'playwright';
  playwright = await import(pkg);
} catch (e) {
  console.error('Playwright could not be loaded; check could NOT run.');
  process.exit(2);
}

// ---------- CLI ----------
const args = process.argv.slice(2);
let repoPath = process.cwd();
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--repo' && i + 1 < args.length) {
    repoPath = resolve(args[i + 1]);
    i++;
  }
}
const indexPath = join(repoPath, 'index.html');
if (!existsSync(indexPath)) {
  console.error(`index.html not found at ${indexPath}`);
  process.exit(2);
}
const indexUrl = pathToFileURL(indexPath).href;

// ---------- Helper ----------
function fmt(num) {
  return Number.isFinite(num) ? num.toFixed(2) : 'NaN';
}

// ---------- Main ----------
let browser;
let exitCode = null;
try {
  browser = await playwright.chromium.launch();
  const context = await browser.newContext();
  const page = await context.newPage();

  // Load the file URL.
  await page.goto(indexUrl, { waitUntil: 'load' });

  // FONTS. The 320px defect this guard exists for is driven by TEXT WIDTH, so
  // which font actually rendered changes every number below.
  //
  // TWO OBVIOUS SIGNALS ARE NON-DISCRIMINATING AND ARE DELIBERATELY NOT USED:
  //   - `document.fonts.status` becomes 'loaded' once loading SETTLES, which
  //     includes the case where the webfont failed to download. Offline it
  //     still reads 'loaded'.
  //   - `getComputedStyle(el).fontFamily` returns the SPECIFIED family string,
  //     i.e. whatever the stylesheet asked for, arrived or not.
  // Either would print "webfonts loaded" on a machine with no network - a claim
  // the evidence cannot support.
  //
  // `document.fonts.check()` reports whether a face is actually AVAILABLE, and
  // the width probe is a second independent read: the real face and a generic
  // fallback render the same string at visibly different widths.
  await page.evaluate(() => document.fonts.ready.then(() => true));
  const fontInfo = await page.evaluate(() => {
    const measure = (family) => {
      const el = document.createElement('span');
      el.textContent = 'ACCESSORIES';
      el.style.cssText =
        'position:absolute;visibility:hidden;white-space:nowrap;font-size:32px;font-family:' + family;
      document.body.appendChild(el);
      const w = el.getBoundingClientRect().width;
      el.remove();
      return w;
    };
    return {
      status: document.fonts.status,
      available: {
        cormorant: document.fonts.check('32px "Cormorant Garamond"'),
        dmsans: document.fonts.check('32px "DM Sans"'),
      },
      widthWebfont: measure('"DM Sans", sans-serif'),
      widthFallback: measure('monospace'),
    };
  });

  const webfontsReal = fontInfo.available.cormorant || fontInfo.available.dmsans;
  console.log(
    `Fonts: status=${fontInfo.status} available=${JSON.stringify(fontInfo.available)} ` +
      `probe 'ACCESSORIES' @32px: DM Sans ${fontInfo.widthWebfont.toFixed(1)}px vs monospace ${fontInfo.widthFallback.toFixed(1)}px`
  );
  console.log(
    webfontsReal
      ? 'Fonts: webfonts ARE available - these are production text metrics.'
      : 'Fonts: webfonts NOT available (offline?) - THE NUMBERS BELOW USE FALLBACK METRICS and are not the production measurement.'
  );

  const viewports = [
    { w: 320, h: 800 },
    { w: 360, h: 800 },
    { w: 375, h: 800 },
    { w: 414, h: 800 },
    { w: 768, h: 800 },
    { w: 1280, h: 800 },
  ];

  const results = [];

  for (const vp of viewports) {
    await page.setViewportSize({ width: vp.w, height: vp.h });

    const data = await page.evaluate(() => {
      const docEl = document.documentElement;
      const docOverflow = docEl.scrollWidth - docEl.clientWidth;

      const grid = docEl.querySelector('.categories-grid');
      if (!grid) {
        return { error: 'grid-missing' };
      }
      const children = Array.from(grid.children);
      if (children.length === 0) {
        return { error: 'grid-empty' };
      }

      const gridRect = grid.getBoundingClientRect();

      let unionLeft = Infinity;
      let unionRight = -Infinity;
      const childWidths = [];

      for (const child of children) {
        const r = child.getBoundingClientRect();
        unionLeft = Math.min(unionLeft, r.left);
        unionRight = Math.max(unionRight, r.right);
        childWidths.push(r.width);
      }

      const leftOverflow = Math.max(0, gridRect.left - unionLeft);
      const rightOverflow = Math.max(0, unionRight - gridRect.right);
      const widthSpread = Math.max(...childWidths) - Math.min(...childWidths);

      return {
        docOverflow,
        leftOverflow,
        rightOverflow,
        widthSpread,
        childCount: children.length,
      };
    });

    if (data.error) {
      // NOT process.exit() here: it skips the `await browser.close()` in the
      // finally block and leaks a chromium process - on exactly the runs that
      // are already going wrong.
      console.error(
        `CONTROL FAILED at ${vp.w}px: ` +
          (data.error === 'grid-missing'
            ? '.categories-grid not found'
            : '.categories-grid has no direct children')
      );
      console.error('A selector that matches nothing and a clean page are the same silence.');
      exitCode = 2;
      break;
    }

    const pass = data.docOverflow <= 0.5 &&
                 data.leftOverflow <= 0.5 &&
                 data.rightOverflow <= 0.5 &&
                 data.widthSpread <= 1;

    results.push({
      width: vp.w,
      docOverflow: data.docOverflow,
      leftOverflow: data.leftOverflow,
      rightOverflow: data.rightOverflow,
      widthSpread: data.widthSpread,
      childCount: data.childCount,
      pass,
    });
  }

  if (exitCode === null && results.length === 0) {
    console.error('CONTROL FAILED: no viewports were measured, so nothing was proved.');
    exitCode = 2;
  }

  // ---------- Reporting ----------
  if (exitCode === null) {
  console.log('\nViewport | DocOv(px) | LeftOv(px) | RightOv(px) | WidthSpread(px) | Children | Pass');
  console.log('--------------------------------------------------------------------------');
  for (const r of results) {
    console.log(
      `${r.width.toString().padEnd(8)} | ${fmt(r.docOverflow).padStart(9)} | ${fmt(r.leftOverflow).padStart(10)} | ${fmt(r.rightOverflow).padStart(11)} | ${fmt(r.widthSpread).padStart(15)} | ${r.childCount
        .toString()
        .padStart(8)} | ${r.pass ? 'YES' : 'NO'}`
    );
  }

  const failing = results.filter(r => !r.pass);
  if (failing.length > 0) {
    console.log('\nFAILURES:');
    for (const f of failing) {
      const msgs = [];
      if (f.docOverflow > 0.5) msgs.push(`doc overflow ${fmt(f.docOverflow)} px > 0.5 px`);
      if (f.leftOverflow > 0.5) msgs.push(`left overflow ${fmt(f.leftOverflow)} px > 0.5 px`);
      if (f.rightOverflow > 0.5) msgs.push(`right overflow ${fmt(f.rightOverflow)} px > 0.5 px`);
      if (f.widthSpread > 1) msgs.push(`width spread ${fmt(f.widthSpread)} px > 1 px`);
      console.log(`- ${f.width}px: ${msgs.join('; ')}`);
    }
    exitCode = 1;
  } else {
    // ONLY in the else. An earlier version set exitCode = 1 here and then fell
    // through to an UNCONDITIONAL exitCode = 0, so the script printed its
    // FAILURES section and exited 0 anyway - a failure with no route to the
    // exit code, which is the one thing CI actually reads. It was caught by
    // running the red arm, not by reading the code.
    console.log(
      `\nAll ${results.length} measured viewport(s) pass. ` +
        `Children per viewport: ${results.map((r) => r.childCount).join(', ')}.`
    );
    exitCode = 0;
  }
  } // end: if (exitCode === null) - skip reporting when a control already failed
} catch (e) {
  console.error('An unexpected error occurred, so the check could NOT run:', e);
  exitCode = 2;
} finally {
  if (browser) await browser.close();
}

// A null exitCode means no branch set a verdict - that is "could not check",
// never a pass.
process.exit(exitCode === null ? 2 : exitCode);
