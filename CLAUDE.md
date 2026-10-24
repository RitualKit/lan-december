# LAN December

A 2–8 player party game in **Godot 4.7** (GDScript). It's 5, 10 or 15 rounds of minigames on floating blossom islands, in an HD-2D style: low-poly 3D tiles with pixel textures and pixel-sprite or blocky 3D characters. Players share one screen locally, or play online across screens in the browser build on claude.ai. The README covers gameplay, controls and the project layout.

## Workflow: feature branch + PR (required for every agent)

`main` is protected by convention: **never commit or push to `main` directly.** Every change, however small, goes through a pull request.

1. **Branch from the latest `main`:**
   ```bash
   git fetch origin main && git checkout -b <type>/<short-name> origin/main
   ```
   Pick `<type>` from `feat`, `fix`, `docs`, `chore`, `test` (e.g. `feat/music`, `fix/river-run-logs`). If the session already gave you a branch name, use that one as the feature branch, but still base it on `origin/main`.
2. **Commit** in small, focused commits as the repo owner, keeping the `Co-Authored-By: Claude ...` trailer (see Rules below).
3. **Verify before the PR:**
   - `tools/run_tests.sh` must pass.
   - Gameplay code also needs `ONLY=lockstep`.
   - Netcode or the `LDNet` bridge also needs the `online-test` skill.
   - Visual changes need screenshots.
   - Update the README and skills when behaviour or workflow changes.
4. **Push and open a PR against `main`:**
   - Push with `git push -u origin <branch>`.
   - Open the PR with the GitHub tools, base `main`.
   - Fill in `.github/pull_request_template.md`: what changed, why, and how it was tested, with real results.
5. **Don't merge your own PR** unless the user asks you to. Report the PR link to the user.
6. **After a merge,** start the next piece of work on a new branch from the updated `origin/main`. Never stack new work on a merged branch.

Publishing the playable artifact from a feature branch is fine when the user wants to try something before merging; tell them it isn't merged yet.

## Commands

```bash
tools/setup_cloud.sh                    # fresh container: Godot 4.7, web template, xvfb + lavapipe
tools/run_tests.sh                      # headless suite; must end "N checks, 0 failures"
ONLY=lockstep tools/run_tests.sh        # also: unit | powerups | minigames | match
ONLY=minigames GAME=river_run tools/run_tests.sh
tools/build_web.sh                      # browser build -> build/web/lan-december.html
```

Skills in `.claude/skills/` hold the longer recipes:

| Skill | Use it for |
|---|---|
| `run-tests` | the test suite |
| `screenshots` | looking at the game without a monitor |
| `web-build-publish` | rebuilding and publishing the claude.ai artifact |
| `online-test` | two browsers playing online |
| `new-minigame` | adding a game |
| `lockstep-determinism` | keeping online play in sync |

## Architecture

- **Autoloads**, in this order: `Art` (textures, sprites, meshes), `Touch` (on-screen controls), `Sfx` (chiptune synth), `Controls` (per-device input), `Game` (players, scores, round plan, themes), `Net` (online play).
- `main/main.gd` switches screens: lobby → `match_host` (intro card → countdown → minigame → results, for each round) → podium.
- `core/minigame.gd` is the base class. Its lifecycle is `setup()` → `build()` → intro → `begin()` → `tick(delta)` → `finish()` → `finished(ranking)`. A ranking is an Array of Arrays of `PlayerSlot`, best group first.
- `core/player_character.gd` is a `CharacterBody3D`. It collides only with tiles (layer 1), not with other characters. Its input comes from `Minigame._input_for`, which handles local devices, bots (`bot_input`) and online play (`Net.input_for`).
- **Online play** (`autoload/net.gd`, plus the `window.LDNet` bridge in `web/lan-december.html`) uses only artifact-room *presence*:
  - Each page simulates in lockstep and sends only inputs, with a 10-tick input delay.
  - The host shares a fixed-point character snapshot every 6 ticks.
  - The host's round result is the one everyone scores.
  - It works only on claude.ai for signed-in people the artifact is shared with; public links can't connect.

## Rules that bite

- **Determinism.** Anything that affects gameplay must be identical on every page. Follow the `lockstep-determinism` skill:
  - Use `rng` (the minigame's seeded `RandomNumberGenerator`), never `randf()` / `randi()` / `shuffle()`.
  - Make gameplay timers `create_timer(t, false, true)`: pausable and counted in physics frames.
  - Make gameplay tweens `TWEEN_PROCESS_PHYSICS`.
  - Read logical positions, never ones a tween is animating.
- **Typing.** A warning about a type inferred from a Variant is an error here: `var x := dict.value` fails to load the script. Write an explicit type (`var x: int = ...`).
- **Members of `Minigame`.** Don't name a member after a base-class signal or method (`finished`, `running`, `ended`, `players`, `chars`, `rng`, ...).
- **Web build.** The web build uses the Compatibility renderer. `GroundMark` uses flat quads instead of decals there, and the water shader branches on `CURRENT_RENDERER`. Check visual changes in both renderers.
- **Assets.** The network policy blocks kenney.nl, itch.io and opengameart. Use GitHub mirrors; `assets/ninja_adventure/` came from `sparklinlabs/superpowers-asset-packs`. Textures and most sounds are generated in code, and PNG/OGG files in `assets/textures/` and `assets/sfx/` override them.
- **Commits.** Commit as the repo owner (`git config user.name "Adam Deblen"`, `user.email "Adam.deblen@intery.se"`). Keep the `Co-Authored-By: Claude ...` trailer. `main` is the default branch, and changes reach it only through PRs (see Workflow).

## Keep the README screenshots current

`docs/screenshots/<game>.jpg` feeds the README's minigame gallery. Recapture the affected images in the same PR whenever you change:
- character sprites or 3D models
- textures, props or themes
- the HUD
- how a minigame looks or plays
- the set of minigames (adding, removing or renaming one)

When art or a theme changes for every game, recapture all 13. The `screenshots` skill has the exact recipe. The PR template's screenshot checkbox covers this.

## Style

GDScript uses tabs and static types. Each script starts with a `##` doc comment. Comments are short and say *why*. Match the surrounding code. Every gameplay change gets a test run: `tools/run_tests.sh`, plus `ONLY=lockstep` if it touches gameplay code.
