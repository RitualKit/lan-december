// Screenshots the browser build on a phone (Pixel 7 emulation, touch input): joins with the
// on-screen A button, drags the stick, and saves the lobby. Serve build/web on :8099 first.
// Usage: node tools/phone_shot.js portrait|landscape [OUT=/tmp]
// Needs Playwright (PLAYWRIGHT=/path/to/node_modules/playwright).
const { chromium, devices } = require(process.env.PLAYWRIGHT || 'playwright');
const mode = process.argv[2] === 'portrait' ? 'portrait' : 'landscape';
const OUT = process.env.OUT || '/tmp';

(async () => {
  const portrait = mode === 'portrait';
  const dev = devices['Pixel 7'];
  const vw = portrait ? dev.viewport.width : dev.viewport.height;
  const vh = portrait ? dev.viewport.height : dev.viewport.width;
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await browser.newContext({ ...dev, viewport: { width: vw, height: vh } });
  const page = await ctx.newPage();
  const logs = [];
  page.on('pageerror', e => logs.push(`[pageerror] ${e.message}`));
  await page.goto('http://localhost:8099/lan-december.html');
  await page.waitForTimeout(1200);
  await page.screenshot({ path: `${OUT}/phone_${mode}_splash.png` });
  await page.tap('#play');
  await page.waitForFunction(() => !document.getElementById('splash'), null, { timeout: 120000 });
  await page.waitForTimeout(5000);
  const cdp = await ctx.newCDPSession(page);
  const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts.map((p, i) => ({ x: p[0], y: p[1], id: p[2] ?? i })) });
  // Where autoload/touch.gd puts the A button: logical layout 1280x720 or 760x1280, stretched.
  const base = portrait ? [760, 1280] : [1280, 720];
  const s = Math.min(vw / base[0], vh / base[1]);
  const L = [vw / s, vh / s];
  const unit = Math.min(1.6, Math.max(0.8, Math.min(L[0], L[1]) / 720));
  const A = [(L[0] - 150 * unit) * s, (L[1] - 160 * unit) * s];
  await touch('touchStart', [[A[0], A[1], 1]]); await page.waitForTimeout(100); await touch('touchEnd', []);
  await page.waitForTimeout(2500);
  const st = [vw * 0.2, vh * 0.7];
  await touch('touchStart', [[st[0], st[1], 2]]);
  for (let i = 1; i <= 12; i++) { await touch('touchMove', [[st[0] + i * 6, st[1] - i * 3, 2]]); await page.waitForTimeout(80); }
  await page.waitForTimeout(400);
  await page.screenshot({ path: `${OUT}/phone_${mode}_lobby.png` });
  await touch('touchEnd', []);
  if (logs.length) console.log(logs.join('\n'));
  console.log(`Saved ${OUT}/phone_${mode}_splash.png and ${OUT}/phone_${mode}_lobby.png`);
  await browser.close();
})();
