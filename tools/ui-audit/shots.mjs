/**
 * Renders each admin page at a device matrix and reports layout faults.
 * Static-only: the pages are served straight off disk, so the shell, CSS
 * cascade and responsive tiers are exercised for real. Data-driven sections
 * stay in their loading state, which is also worth seeing.
 *
 *   PLAYWRIGHT_DIR=/tmp/pwrunner/node_modules node tools/ui-audit/shots.mjs [outDir]
 *
 * UI_PAGES / UI_DEVICES narrow the matrix while iterating, e.g.
 *   UI_PAGES=orders UI_DEVICES=390x844,1440x900 node tools/ui-audit/shots.mjs
 *
 * Playwright is a dev-only dependency and is deliberately not vendored here.
 * Pages are requested at their real production paths (/admin/dashboard, ...)
 * so that active-link resolution is tested, not just the file on disk.
 */
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require(
  process.env.PLAYWRIGHT_DIR ? join(process.env.PLAYWRIGHT_DIR, 'playwright') : 'playwright'
);

const ROOT = fileURLToPath(new URL('../../go-backend/static/', import.meta.url));
const OUT = process.argv[2] || fileURLToPath(new URL('./shots/', import.meta.url));

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
};

/** Production route -> file on disk. */
const ROUTES = {
  '/admin/dashboard': 'admin/dashboard.html',
  '/admin/orders': 'admin/orders.html',
  '/admin/revenue': 'admin/stores.html',
  '/admin/inventory': 'admin/inventory.html',
  '/admin': 'admin/login.html',
  '/admin/login': 'admin/login.html',
  '/privacy-policy': 'privacy-policy.html',
  '/static/admin/test_monthly_summary_fix.html': 'admin/test_monthly_summary_fix.html',
  '/static/admin/test_orders_api.html': 'admin/test_orders_api.html',
  '/static/admin/test_search.html': 'admin/test_search.html',
  '/static/test_images.html': 'test_images.html',
};

const PAGES = [
  { name: 'dashboard', route: '/admin/dashboard' },
  { name: 'orders', route: '/admin/orders' },
  { name: 'stores', route: '/admin/revenue' },
  { name: 'inventory', route: '/admin/inventory' },
  { name: 'login', route: '/admin' },
  { name: 'privacy', route: '/privacy-policy' },
];

const DEVICES = [
  { name: '360x640', w: 360, h: 640, touch: true },
  { name: '390x844', w: 390, h: 844, touch: true },
  { name: '768x1024', w: 768, h: 1024, touch: true },
  { name: '1024x768', w: 1024, h: 768, touch: false },
  { name: '1440x900', w: 1440, h: 900, touch: false },
];

const only = (env, all) => {
  const want = process.env[env];
  if (!want) return all;
  const set = new Set(want.split(',').map((s) => s.trim()).filter(Boolean));
  const picked = all.filter((x) => set.has(x.name));
  if (!picked.length) {
    console.error(`${env}=${want} matched nothing. Known: ${all.map((x) => x.name).join(', ')}`);
    process.exit(2);
  }
  return picked;
};

const MATRIX_PAGES = only('UI_PAGES', PAGES);
const MATRIX_DEVICES = only('UI_DEVICES', DEVICES);

// The pages reference assets as /static/... (Go serves them from ./static).
// The test server is rooted at that directory, so a leading /static is
// stripped before lookup.
const server = createServer(async (req, res) => {
  const raw = decodeURIComponent(req.url.split('?')[0]);
  let rel = ROUTES[raw];
  if (!rel) rel = raw.startsWith('/static/') ? raw.slice('/static'.length) : raw;
  const file = join(ROOT, normalize(rel === '/' ? '/index.html' : rel));
  if (!file.startsWith(ROOT)) {
    res.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, { 'Content-Type': MIME[extname(file)] || 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
});

await new Promise((r) => server.listen(0, r));
const base = `http://127.0.0.1:${server.address().port}`;
await mkdir(OUT, { recursive: true });

/** Console noise that only appears because there is no backend here. */
const EXPECTED_NOISE = [
  /Failed to load resource/i,
  /net::ERR_/i,
  /is not valid JSON/i,
  /Failed to fetch/i,
  /NetworkError/i,
  /HTTP 404/i,
  /Error loading/i,
  /ERROR in load/i,
  /^\s*at /i,
];

const browser = await chromium.launch();
const report = [];
let bad = 0;

/**
 * Interaction + geometry probe for the app shell. Screenshots are written for
 * a human, but these assertions are the real gate: they prove the bar sits on
 * top, the drawer opens and closes, tap targets are big enough, and nothing
 * overlaps the header.
 */
async function probeShell(page, device) {
  const r = { device: device.name, checks: [] };
  const ok = (name, pass, detail = '') => r.checks.push({ name, pass: !!pass, detail: String(detail) });

  const geo = await page.evaluate(() => {
    const de = document.documentElement;
    const q = (s) => document.querySelector(s);
    const box = (el) => {
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), bottom: Math.round(r.bottom) };
    };
    const header = q('.app-header');
    const navLinks = [...document.querySelectorAll('.app-nav-link')].map((el) => ({ href: el.getAttribute('href'), ...box(el) }));
    let firstContent = null;
    for (const el of document.body.children) {
      if (el.classList.contains('app-header') || el.classList.contains('app-drawer') || el.classList.contains('app-drawer-backdrop')) continue;
      const b = box(el);
      if (b && b.h > 0) { firstContent = b; break; }
    }
    return {
      vw: de.clientWidth,
      header: box(header),
      headerPos: header ? getComputedStyle(header).position : null,
      brand: box(q('.app-brand')),
      navLinks,
      toggle: box(q('.nav-toggle')),
      firstContent,
    };
  });

  ok('header present', geo.header);
  ok('header is sticky', geo.headerPos === 'sticky', geo.headerPos);
  ok('header above content', geo.firstContent && geo.header && geo.firstContent.y >= geo.header.bottom - 1,
     `header.bottom=${geo.header && geo.header.bottom} content.y=${geo.firstContent && geo.firstContent.y}`);
  ok('brand inside viewport', geo.brand && geo.brand.x >= 0 && geo.brand.x + geo.brand.w <= geo.vw + 1, JSON.stringify(geo.brand));
  ok('brand >= 36px tall', (geo.brand && geo.brand.h) >= 36, geo.brand && geo.brand.h);

  if (device.touch) {
    ok('hamburger visible on touch', geo.toggle && geo.toggle.w > 0, JSON.stringify(geo.toggle));
    ok('hamburger >= 44px', (geo.toggle && geo.toggle.h) >= 44, geo.toggle && geo.toggle.h);
    ok('hamburger inside viewport', geo.toggle && geo.toggle.x + geo.toggle.w <= geo.vw + 1);
  } else {
    ok('hamburger hidden on desktop', !geo.toggle || geo.toggle.w === 0, JSON.stringify(geo.toggle));
    ok('4 nav links present', geo.navLinks.length === 4, geo.navLinks.length);
    ok('nav links inside viewport', geo.navLinks.every((l) => l.x >= 0 && l.x + l.w <= geo.vw + 1), JSON.stringify(geo.navLinks));
    ok('nav links >= 36px tall', geo.navLinks.every((l) => l.h >= 36), JSON.stringify(geo.navLinks.map((l) => l.h)));
    const s = [...geo.navLinks].sort((a, b) => a.x - b.x);
    ok('nav links do not overlap', !s.some((l, i) => i > 0 && l.x < s[i - 1].x + s[i - 1].w), JSON.stringify(s.map((l) => [l.x, l.w])));
  }

  if (device.touch && geo.toggle && geo.toggle.w > 0) {
    await page.click('.nav-toggle');
    await page.waitForTimeout(350);
    const open = await page.evaluate(() => {
      const d = document.querySelector('.app-drawer');
      const b = document.querySelector('.app-drawer-backdrop');
      const t = document.querySelector('.nav-toggle');
      const r = d.getBoundingClientRect();
      const vw = document.documentElement.clientWidth;
      return {
        open: d.getAttribute('data-open'),
        aria: t.getAttribute('aria-expanded'),
        x: Math.round(r.x), w: Math.round(r.width), vw,
        backdropOpen: b ? b.getAttribute('data-open') : null,
        htmlOverflow: document.documentElement.style.overflow,
        links: [...document.querySelectorAll('.app-drawer__link, .app-drawer form button')].map((a) => {
          const lr = a.getBoundingClientRect();
          return { x: Math.round(lr.x), w: Math.round(lr.width), h: Math.round(lr.height) };
        }),
        inView: r.x < vw && r.x + r.width > 0,
      };
    });
    ok('drawer opens', open.open === 'true' && open.aria === 'true', `${open.open}/${open.aria}`);
    ok('drawer slides into view', open.inView, `x=${open.x} w=${open.w} vw=${open.vw}`);
    ok('backdrop shown', open.backdropOpen === 'true', open.backdropOpen);
    ok('background scroll locked', open.htmlOverflow === 'hidden', `"${open.htmlOverflow}"`);
    ok('drawer links >= 44px', open.links.every((l) => l.h >= 44), JSON.stringify(open.links.map((l) => l.h)));
    ok('drawer links inside viewport', open.links.every((l) => l.x >= 0 && l.x + l.w <= open.vw + 1), JSON.stringify(open.links));

    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);
    const closed = await page.evaluate(() => ({
      open: document.querySelector('.app-drawer').getAttribute('data-open'),
      aria: document.querySelector('.nav-toggle').getAttribute('aria-expanded'),
      overflow: document.documentElement.style.overflow,
    }));
    ok('Escape closes drawer', closed.open === 'false' && closed.aria === 'false', `${closed.open}/${closed.aria}`);
    ok('scroll lock released', closed.overflow === '', `"${closed.overflow}"`);
  }
  return r;
}


for (const page of MATRIX_PAGES) {
  for (const d of MATRIX_DEVICES) {
    const ctx = await browser.newContext({
      viewport: { width: d.w, height: d.h },
      hasTouch: d.touch,
      isMobile: d.touch,
      deviceScaleFactor: 1,
    });
    const p = await ctx.newPage();
    if (process.env.UI_VERBOSE) console.log(`.... ${page.name} ${d.name}`);
    const errors = [];
    const missing = [];

    p.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
    p.on('console', (m) => {
      if (m.type() !== 'error') return;
      const t = m.text();
      if (!EXPECTED_NOISE.some((r) => r.test(t))) errors.push('console: ' + t);
    });
    // A missing CDN or /api asset is an artefact of running without a
    // backend or egress, not a layout fault. A missing LOCAL asset is real.
    const ignorable = (u) => !u.startsWith(base) || /\/(api|admin\/api)\//.test(u);
    p.on('requestfailed', (r) => {
      const u = r.url();
      if (u.startsWith('data:') || ignorable(u)) return;
      missing.push(u.replace(base, '') + (r.failure()?.errorText || ''));
    });
    p.on('response', (r) => {
      if (r.status() >= 400 && !ignorable(r.url())) missing.push(r.status() + ' ' + r.url().replace(base, ''));
    });

    // No egress in the sandbox: keep CDN fonts/icons and /api calls from
    // hanging, but never the document or the local stylesheets under test.
    await p.route('**/*', (route) => {
      const u = route.request().url();
      if (u.startsWith(base) || u.startsWith('data:')) return route.continue();
      return route.abort();
    });

    try {
      await p.goto(`${base}${page.route}`, { waitUntil: 'commit', timeout: 15000 });
      await p.waitForFunction(() => document.body && document.body.children.length > 0, null, { timeout: 10000 });
    } catch (e) {
      console.log(`FAIL ${page.name.padEnd(10)} ${d.name.padEnd(9)} navigation: ${e.message.split('\n')[0]}`);
      console.log(`       missing: ${[...new Set(missing)].slice(0, 4).join(', ') || '(none logged)'}`);
      bad += 1;
      await ctx.close();
      continue;
    }
    await p.waitForTimeout(500);

    const m = await p.evaluate((TOUCH) => {
      const de = document.documentElement;
      const vw = de.clientWidth;

      // TRUE horizontal scroll: can the user actually pan sideways?
      const before = window.scrollX;
      window.scrollTo(9999, 0);
      const canPan = window.scrollX > 0;
      window.scrollTo(before, 0);

      // Deepest element sticking out past the viewport, ignoring anything
      // that sits inside a clipping ancestor (that is not a page-level bug).
      const clipped = (el) => {
        for (let n = el.parentElement; n && n !== de; n = n.parentElement) {
          const o = getComputedStyle(n);
          if (o.overflowX !== 'visible' || o.overflow !== 'visible') return true;
        }
        return false;
      };
      let worst = null;
      for (const el of document.querySelectorAll('body *')) {
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) continue;
        const over = Math.round(r.right - vw);
        if (over > 1 && !clipped(el) && (!worst || over > worst.over)) {
          worst = {
            over,
            sel:
              el.tagName.toLowerCase() +
              (el.id ? '#' + el.id : '') +
              (typeof el.className === 'string' && el.className.trim()
                ? '.' + el.className.trim().split(/\s+/).join('.')
                : ''),
          };
        }
      }

      const header = document.querySelector('.app-header');
      const toggle = document.querySelector('.nav-toggle');
      const nav = document.querySelector('.app-nav');
      const vis = (n) => (n ? getComputedStyle(n).display !== 'none' : null);
      const hero = document.querySelector('.orders-header, .stores-header');

      return {
        canPan,
        scrollW: de.scrollWidth,
        clientW: vw,
        worst,
        hasHeader: !!header,
        headerPos: header ? getComputedStyle(header).position : null,
        headerH: header ? Math.round(header.getBoundingClientRect().height) : 0,
        enhanced: header ? header.getAttribute('data-enhanced') : null,
        toggleVisible: vis(toggle),
        navVisible: vis(nav),
        current: [...document.querySelectorAll('[aria-current="page"]')].map((a) =>
          a.getAttribute('href')
        ),
        heroTop: hero ? getComputedStyle(hero).top : null,
        // iOS zooms any focused control under 16px, and a tap target under
        // ~36px is hard to hit. Both only matter on touch hardware.
        smallTargets: TOUCH
          ? [...document.querySelectorAll('button, a.btn, input, select')]
              .filter((el) => {
                const r = el.getBoundingClientRect();
                return r.width > 0 && r.height > 0 && r.height < 36;
              })
              .slice(0, 4)
              .map((el) => (el.id ? '#' + el.id : el.className || el.TagName || el.tagName) + '@' + Math.round(el.getBoundingClientRect().height))
          : [],
        tinyFont: TOUCH
          ? [...document.querySelectorAll('input, select, textarea')]
              .filter((el) => {
                const r = el.getBoundingClientRect();
                return r.width > 0 && parseFloat(getComputedStyle(el).fontSize) < 16;
              })
              .slice(0, 4)
              .map((el) => (el.id ? '#' + el.id : el.className) + '@' + getComputedStyle(el).fontSize)
          : [],
      };
    }, d.touch);

    await p.screenshot({ path: join(OUT, `${page.name}-${d.name}.png`) });

    // The shell probe clicks the hamburger, so it runs after the screenshot.
    // Pages without the shell are skipped rather than failed.
    let shell = null;
    if (await p.$('.app-header')) {
      shell = await probeShell(p, d);
      const failed = shell.checks.filter((c) => !c.pass);
      if (failed.length) {
        for (const c of failed) console.log(`FAIL ${page.name.padEnd(10)} ${d.name.padEnd(9)} ${c.name} ${c.detail}`);
        bad += failed.length;
      }
    }

    report.push({ page: page.name, device: d.name, touch: d.touch, ...m, errors, missing: [...new Set(missing)], shell });
    await ctx.close();
  }
}

await browser.close();
server.close();


for (const r of report) {
  const flags = [];
  if (r.canPan) flags.push(`H-SCROLL pannable to ${r.scrollX}px (worst ${r.worst ? r.worst.over + 'px ' + r.worst.sel : '?'})`);
  if (r.errors.length) flags.push('JS: ' + r.errors.slice(0, 2).join(' | '));
  if (r.missing.length) flags.push('missing: ' + r.missing.slice(0, 3).join(', '));
  if (r.hasHeader && r.current.length === 0) flags.push('no active nav link');
  if (r.hasHeader && r.current.length > 2) flags.push('active link duplicated x' + r.current.length);
  if (r.tinyFont.length) flags.push('font<16px: ' + r.tinyFont.join(', '));
  if (r.smallTargets.length) flags.push('target<36px: ' + r.smallTargets.join(', '));
  if (flags.length) bad++;
  console.log(
    `${flags.length ? 'FAIL' : ' ok '} ${r.page.padEnd(10)} ${r.device.padEnd(9)}` +
      ` hdr=${r.hasHeader ? r.headerPos + '/' + r.headerH + ' enh=' + r.enhanced : '-'}` +
      ` tgl=${r.toggleVisible} nav=${r.navVisible} cur=[${r.current}]` +
      (flags.length ? '\n       ' + flags.join('\n       ') : '')
  );
}
console.log(`\n${report.length - bad}/${report.length} clean -> ${OUT}`);
process.exit(bad ? 1 : 0);
