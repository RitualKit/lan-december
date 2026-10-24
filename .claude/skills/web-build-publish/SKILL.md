---
name: web-build-publish
description: Build LAN December for the browser and publish or update the playable claude.ai artifact (with the room capability for online play). Use when the user wants to play the latest version, after changes to web/lan-december.html, or to share the game.
---

# Build and publish the browser version

## Build

```bash
tools/build_web.sh        # needs ~/.local/share/godot/export_templates/4.7.stable/web_nothreads_release.zip
```

- If the template is missing, run `tools/setup_cloud.sh`.
- The page source is `web/lan-december.html`. The `index.html` that Godot exports is not used.
- The artifact host serves only standard web types, up to 15 MB per file. So the build gzips and base64-encodes the 40 MB wasm into `index.wasm.gz.b64.txt` and the pck into `index.pck.b64.txt`.
- A `fetch` shim in the page decodes them when Godot asks for `index.wasm` / `index.pck`.
- The script copies the page into `build/web/` and patches the real file sizes into it for the progress bar.
- The export is single-threaded (`web_nothreads`), so it needs no cross-origin isolation headers.

## Publish (Artifact tool)

The game lives at https://claude.ai/artifact/94yD5uM5jpeaz4wW8EFLD4. Update it in place:

- `file_path`: `/home/user/lan-december/build/web/lan-december.html`
- `url`: the link above. Needed from a new conversation, after reading it once with `action: "read"`.
- `files`:
  ```json
  {"index.js": "build/web/index.js",
   "index.wasm.gz.b64.txt": "build/web/index.wasm.gz.b64.txt",
   "index.pck.b64.txt": "build/web/index.pck.b64.txt",
   "index.audio.worklet.js": "build/web/index.audio.worklet.js",
   "index.audio.position.worklet.js": "build/web/index.audio.position.worklet.js"}
  ```
- `capabilities`: `{"room": {}}`. The room is stored on the artifact and carries forward when omitted. Never pass `{}`: that turns online play off.
- `label`: a few words on what changed.

## Online play needs

- Players must be signed in to claude.ai, and the artifact must be shared with their account from the page's **Share** menu.
- Viewers who open it from a public ("anyone with the link") share can't use the room. For them the in-game ONLINE menu says why.
- Only room *presence* is used, never event topics, so nobody needs edit rights.

## Before publishing

1. Run `tools/run_tests.sh`.
2. Take a phone screenshot if the touch UI or page changed (`screenshots` skill).
3. Run `online-test` if the netcode or the `LDNet` bridge changed.
