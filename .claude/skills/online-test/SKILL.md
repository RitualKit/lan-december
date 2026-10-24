---
name: online-test
description: Play LAN December online between two headless browser pages through a fake claude.ai room, checking that both simulations agree, rounds hand over and leaving returns to the lobby. Use after changes to autoload/net.gd, main/online_panel.gd, the LDNet bridge, match_host round flow or anything affecting determinism.
---

# Two-browser online test

`tools/online_test.js` opens two Chromium pages:
1. It injects a fake `claude.use('room')` built on BroadcastChannel, with 60–120 ms latency and ordered delivery.
2. Page A hosts and page B joins, through the `window.__ldTest` command hook (`host`, `join`, `start`; handled in `Net._test_command`).
3. Both pages press random keys for N rounds.
4. The script compares the pages' published checksums (`ck` in game presence) and closes page B, which should send A back to the lobby.

```bash
tools/build_web.sh
(cd build/web && setsid nohup python3 -m http.server 8099 >/dev/null 2>&1 < /dev/null &)
PLAYWRIGHT=/opt/node-tools/node_modules/playwright OUT=/tmp/online \
  node tools/online_test.js 2 > /tmp/online/log.txt 2>&1    # run in the background
```

## Expectations

- In a 4-core container with no GPU, both games render in software. One round takes about 1.5–2 minutes, so 2 rounds take about 4–5 minutes and 3 rounds about 8. Run it in the background and wait for the notification, rather than polling with sleep.
- A pass exits 0. Its log has `t=..s round=<id>:<n>` lines whose round number increases, `checksums compared: N, mismatches: 0`, and `host back in lobby = true`.
- Screenshots `online_host_<i>.png` and `online_guest_<i>.png` are saved every 25 s. Paste matching pairs into one image and check both pages show the same round.

## Gotchas seen before

- **Background throttling.** Without `--disable-background-timer-throttling` and its sibling flags, the second page's timers crawl and joins time out. The script already passes them.
- **The guest never joins.** The lobby advert can take seconds under load. The script retries `join` until the host sees the guest's players.
- **A false "player left".** Leave detection uses wall-clock time, gives 30 s for a page to load into a match (`START_GRACE`), and allows 6 s once someone was seen playing (`PEER_TIMEOUT`).
- **Random keys open menus.** Pages press random keys. In the ONLINE menu, CLOSE is listed first, so a stray press doesn't leave the game.
- A real claude.ai room can't be reached from the container. This test is the closest stand-in, so say so when reporting results.
