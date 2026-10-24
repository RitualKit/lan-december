---
name: screenshots
description: Take screenshots of LAN December without a monitor, whether desktop renders of minigames, lobby, match flow or podium via xvfb, or phone renders of the browser build via Playwright. Use to check visual changes, art, layouts and mobile controls.
---

# Screenshots

## Desktop (Forward+ renderer)

`tools/capture.sh` runs `tools/capture.tscn` under `xvfb-run`. It renders with lavapipe, which `tools/setup_cloud.sh` installs. It's configured with environment variables (full list at the top of `tools/capture.gd`):

```bash
GAME=res://minigames/paint_the_isle.gd N=6 TIMES=5,10 OUT=/tmp/shot tools/capture.sh
GAME=match N=4 HUMAN=1 TIMES=2,20 OUT=/tmp/match tools/capture.sh     # intro card, then gameplay
GAME=lobby N=4 TIMES=3 OUT=/tmp/lobby tools/capture.sh
GAME=res://minigames/blossom_king.gd N=6 ITEMS=1 TIMES=3,4 OUT=/tmp/items tools/capture.sh
LOOK=3d THEME=winter GAME=res://minigames/crumble.gd N=4 TIMES=4 OUT=/tmp/c tools/capture.sh
```

- `TIMES` are seconds of game time. Each one writes `<OUT>_00.png`, `<OUT>_01.png` and so on, numbered in order.
- `HUMAN=1` adds an idle human, so cards wait for their timeouts.
- Look at the PNGs with the Read tool. To compare several, paste them into one grid with PIL first.
- The README gallery images in `docs/screenshots/` were made this way, with `N=4 TIMES=3,7,12`. The best frame of each game was saved as a 960×540 JPEG.

## Browser build (Compatibility renderer, phones)

The web build looks different: no depth-of-field blur, and flat ground markers instead of decals. Check web-specific changes there:

```bash
tools/build_web.sh
(cd build/web && setsid nohup python3 -m http.server 8099 >/dev/null 2>&1 < /dev/null &)
PLAYWRIGHT=/opt/node-tools/node_modules/playwright OUT=/tmp node tools/phone_shot.js portrait
PLAYWRIGHT=/opt/node-tools/node_modules/playwright OUT=/tmp node tools/phone_shot.js landscape
```

- `phone_shot.js` emulates a Pixel 7, taps the on-screen **A** to join, and drags the stick.
- Chromium runs with SwiftShader (`--use-angle=swiftshader`), so WebGL 2 works without a GPU.
- Allow about 30 s for the engine to boot.
- The local server dies with the session; restart it with the line above.
