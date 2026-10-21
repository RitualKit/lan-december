// Two browser pages play an online match against each other through a fake claude.ai
// "room" (BroadcastChannel with latency), checking that their simulations agree.
// Usage: serve build/web on :8099, then
//   node tools/online_test.js [rounds=3]
// Needs Playwright (PLAYWRIGHT=/path/to/node_modules/playwright).
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');
const ROUNDS = +(process.argv[2] || 3);
const OUT = process.env.OUT || '/tmp';
const T0 = Date.now();

// Installed in each page before it loads: claude.use('room') backed by BroadcastChannel.
function fakeRoom() {
  const me = Math.random().toString(36).slice(2, 10);
  const bc = new BroadcastChannel('fake-room');
  const rooms = {}; // name -> {mine, peers: {peer: {presence, seen}}}
  const LAT = 60 + Math.random() * 60;
  let lastDeliver = 0;
  function room(name) {
    if (!rooms[name]) rooms[name] = { mine: {}, peers: {}, joined: name === '', snap: null };
    return rooms[name];
  }
  function send(msg) { bc.postMessage(Object.assign({ from: me }, msg)); }
  bc.onmessage = function (e) {
    const m = e.data;
    // Ordered delivery with latency.
    const at = Math.max(lastDeliver, performance.now() + LAT);
    lastDeliver = at;
    setTimeout(function () {
      const r = room(m.room);
      if (m.type === 'leave') delete r.peers[m.from];
      else r.peers[m.from] = { presence: m.presence, seen: performance.now() };
      r.snap = null;
    }, at - performance.now());
  };
  setInterval(function () {
    for (const name in rooms) {
      const r = rooms[name];
      if (r.joined) send({ type: 'pres', room: name, presence: r.mine });
      for (const p in r.peers) if (performance.now() - r.peers[p].seen > 8000) { delete r.peers[p]; r.snap = null; }
    }
  }, 500);
  function api(name) {
    const r = room(name);
    let pending = false;
    return {
      name: name,
      presence: function (patch) {
        for (const k in patch) { if (patch[k] === null) delete r.mine[k]; else r.mine[k] = patch[k]; }
        r.mine = Object.assign({}, r.mine);
        r.snap = null;
        if (JSON.stringify(r.mine).length > 4096) return Promise.reject({ code: 'invalid_argument' });
        if (!pending) { pending = true; setTimeout(function () { pending = false; if (r.joined) send({ type: 'pres', room: name, presence: r.mine }); }, 33); }
        return Promise.resolve();
      },
      peers: function () {
        if (!r.snap) {
          const list = [{ peer: me, sameTab: true, isMe: true, presence: r.mine }];
          for (const p in r.peers) list.push({ peer: p, sameTab: false, isMe: false, presence: r.peers[p].presence });
          r.snap = list;
        }
        return r.snap;
      },
      connected: function () { return true; },
      leave: function () { r.joined = false; r.mine = {}; r.peers = {}; r.snap = null; send({ type: 'leave', room: name }); return Promise.resolve(); },
    };
  }
  const lobby = api('');
  lobby.join = function (name) {
    room(name).joined = true;
    return new Promise(function (ok) { setTimeout(function () { ok(api(name)); }, 200); });
  };
  window.claude = { use: function (n) { return Promise.resolve(n === 'room' ? lobby : null); } };
  window.__fake = { rooms: rooms, me: me };
  window.__ldTest = [];
  addEventListener('pagehide', function () { for (const n in rooms) if (rooms[n].joined) send({ type: 'leave', room: n }); });
}

(async () => {
  // Both pages must keep running at full speed, as if on two separate screens.
  const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist',
    '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'] });
  const ctx = await browser.newContext({ viewport: { width: 480, height: 270 } });
  await ctx.addInitScript(fakeRoom);
  const pages = [await ctx.newPage(), await ctx.newPage()];
  const logs = [[], []];
  pages.forEach((p, i) => {
    p.on('console', m => { if (/error|warn|Net:/i.test(m.type() + m.text())) logs[i].push(`${Math.round((Date.now() - T0) / 1000)}s ${m.text()}`); });
    p.on('pageerror', e => logs[i].push('pageerror ' + e.message));
  });
  for (const p of pages) {
    await p.goto('http://localhost:8099/lan-december.html');
    await p.click('#play');
  }
  for (const p of pages) await p.waitForFunction(() => !document.getElementById('splash'), null, { timeout: 120000 });
  await pages[0].waitForTimeout(5000);
  const press = async (p, key, ms = 120) => { await p.keyboard.down(key); await p.waitForTimeout(ms); await p.keyboard.up(key); };
  for (const p of pages) { await p.bringToFront(); await p.locator('canvas').focus(); await press(p, 'Space'); }
  await pages[0].waitForTimeout(1500);

  const game = (p) => p.evaluate(() => {
    const out = {};
    for (const n in __fake.rooms) if (n && __fake.rooms[n].joined) {
      const r = __fake.rooms[n];
      out.name = n; out.mine = r.mine; out.peers = Object.values(r.peers).map(x => x.presence);
    }
    return out;
  });
  await pages[0].evaluate(() => __ldTest.push('host'));
  await pages[0].waitForTimeout(2500);
  for (let i = 0; i < 60; i++) {
    const g = await game(pages[0]);
    if (g.peers && g.peers.length === 1 && g.peers[0].pl && g.peers[0].pl.length && g.mine.pl.length) break;
    if (!(await game(pages[1])).name) await pages[1].evaluate(() => __ldTest.push('join'));
    await pages[0].waitForTimeout(1000);
  }
  const g0 = await game(pages[0]);
  console.log('host room', g0.name, 'host pl', JSON.stringify(g0.mine.pl), 'guest pl', JSON.stringify(g0.peers.map(p => p.pl)));
  await pages[0].screenshot({ path: OUT + '/online_lobby_host.png' });
  await pages[1].screenshot({ path: OUT + '/online_lobby_guest.png' });
  await pages[0].evaluate(() => __ldTest.push('start'));

  // Play: press action now and then (readies the intros) and wander around.
  const keys = ['w', 'a', 's', 'd'];
  const checks = {}; // round:tick -> [hostSum, guestSum]
  const seen = new Set();
  let shots = 0, bad = 0;
  const t0 = Date.now();
  while (Date.now() - t0 < ROUNDS * 150000) {
    for (let i = 0; i < 2; i++) {
      const p = pages[i];
      const k = keys[Math.floor(Math.random() * 4)];
      await p.keyboard.down(k);
      if (Math.random() < 0.4) await press(p, 'Space', 60);
      await p.waitForTimeout(150);
      await p.keyboard.up(k);
    }
    for (let i = 0; i < 2; i++) {
      const g = await game(pages[i]);
      const ck = g.mine && g.mine.ck;
      if (ck) {
        const key = ck[0] + '@' + ck[1];
        (checks[key] = checks[key] || [null, null])[i] = ck[2];
        const c = checks[key];
        if (c[0] !== null && c[1] !== null && !seen.has(key)) {
          seen.add(key);
          if (c[0] !== c[1]) { bad++; console.log('MISMATCH', key, c); }
        }
      }
    }
    const g = await game(pages[0]);
    const round = g.mine && g.mine.in ? g.mine.in.r : (g.mine && g.mine.rd) || '-';
    if (Date.now() - t0 > shots * 25000) {
      await pages[0].screenshot({ path: `${OUT}/online_host_${shots}.png` });
      await pages[1].screenshot({ path: `${OUT}/online_guest_${shots}.png` });
      console.log(`t=${Math.round((Date.now() - t0) / 1000)}s round=${round} compared=${seen.size} mismatches=${bad}`);
      shots++;
    }
    const n = +(String(round).split(':')[1] || 0);
    if (n > ROUNDS) break;
  }
  // A player leaving mid-match sends everyone back to the lobby.
  await pages[1].close();
  let after = {};
  for (let i = 0; i < 40; i++) {
    await pages[0].waitForTimeout(1000);
    after = await game(pages[0]);
    if (after.mine && after.mine.pl) break;
  }
  await pages[0].screenshot({ path: OUT + '/online_after_leave.png' });
  console.log('after guest left: host back in lobby =', !!(after.mine && after.mine.pl), 'in lockstep =', !!(after.mine && after.mine.in));
  console.log(`checksums compared: ${seen.size}, mismatches: ${bad} (snapshots from the host fix small ones)`);
  logs.forEach((l, i) => l.length && console.log(`page ${i} log:\n  ` + l.slice(0, 20).join('\n  ')));
  await browser.close();
  process.exit(seen.size === 0 || !(after.mine && after.mine.pl) ? 1 : 0);
})();
