# LAN December

A local multiplayer party game for 2–8 players, built in **Godot 4.7**. Each match is 5, 10 or 15 rounds of quick minigames on floating cherry-blossom islands, in a 2.5D pixel-art style: low-poly 3D tiles with pixel textures and pixel-sprite characters.

Everyone plays on one screen. Players use keyboards and gamepads, and CPU players can fill empty seats.

## Run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open `project.godot` in Godot and press **F5**, or run `godot --path .` from this folder.

## Controls

| Device | Move | Action (join / dash / hop / strike) | Back (leave) |
|---|---|---|---|
| Keyboard left | WASD | Space | E |
| Keyboard right | Arrow keys | Enter | Backspace |
| Gamepad (each one) | Left stick / D-pad | A | B |

**Esc** or **Start** pauses. While paused, **Back** quits to the lobby.

### Lobby

- Press the action button on any device to join. Your character drops onto the island.
- Walk onto **+ CPU** or **- CPU** to add or remove computer players. On keyboard, **+** and **-** also work; on a gamepad, use the shoulder buttons.
- Walk onto **ROUNDS** to switch between 5, 10 and 15 rounds.
- When every human stands on **START** for 3 seconds, the match begins.

## How a match works

- The minigames are shuffled. Every game plays once before any repeats, and no game plays twice in a row.
- Each round shows an intro card with the rules. Players press action when ready, then there's a 3‑2‑1 countdown.
- Points per round, by placement: **10 / 7 / 5 / 3 / 2 / 1**. Tied players share the better placement.
- **The last two rounds are worth double**, so nobody is out of it early.
- At the end there's a podium and the final standings.

## Minigames

| Game | Goal | Button |
|---|---|---|
| **Petal Push** | Sumo: shove everyone into the sea while the island crumbles from the edges. | Dash |
| **Petal Rush** | Collect blossoms (gold ones are worth 5). Dash into rivals to make them drop some. | Dash |
| **Hot Lantern** | Hot potato: touch someone to pass the lantern before it bursts. | Dash |
| **Crumble** | Tiles crack on your first step and fall on the second. Standing still breaks them too. Last one standing wins. | Hop |
| **Blossom King** | Hold the moving golden circle. If it's crowded, only whoever got there first scores, at half speed. | Dash |
| **Rockfall** | Dodge boulders that land on the red warning circles. | Dash |
| **Paint the Isle** | Cover the most tiles in your colour. Paint bombs splash a big area. | Dash |
| **Koi Catch** | Reaction duel: strike first when the koi bites. Pressing early locks you out for that cast. | Strike |

## Art, sound and fonts

- **Textures and characters are generated in code** (`autoload/art.gd`): grass, cliffs, paths, blossoms, bark, and a 3×3 sprite sheet per player colour. To replace a texture, drop a PNG with the same name into `assets/textures/` (for example `grass.png`, 16×16) and it is used instead of the generated one.
- **Sound effects are generated in code** by a small chiptune synth (`autoload/sfx.gd`). To replace a sound, drop `assets/sfx/<name>.ogg` or `.wav` into place, using a name such as `coin`, `boom`, `splash` or `win`.
- **Fonts:** Tiny5 and Silkscreen, both under the SIL Open Font License (see `assets/fonts/OFL.txt`).
- **No music yet.**

## Project layout

```
autoload/   Art (procedural art), Sfx (synth), Controls (per-device input), Game (match state & scoring)
core/       Minigame base class, PlayerCharacter, Arena/ArenaTile (island builder), water shader, Fx, Props, Ui
main/       main.tscn (screen switcher + pause), lobby, match_host (rounds/intro/results), podium
minigames/  One script per minigame
tests/      Headless test suite
tools/      run_tests.sh, capture.sh (screenshots)
```

## Adding a minigame

1. Create `minigames/my_game.gd` with `extends Minigame`.
2. In `_init()`, set `title`, `tagline`, `rules`, `action_name`, `time_limit` and, if needed, `last_standing`.
3. In `build()`, create the island and spawn players:

   ```gdscript
   arena.build(Arena.disc(5.0))
   arena.setup_view(Vector3.ZERO, 23.0)
   arena.decorate(rng.randi(), 5.0)
   spawn_characters(arena.spawn_ring(players.size(), 3.0))
   ```

4. Put the game rules in `tick(delta)`.
5. Override `rank()` to return groups of players, best first, for example `score_ranking(scores)`. The default ranks by who survived longest.
6. Override `bot_input(ch)` so CPUs can play. Helpers available: `bot_go`, `bot_steer`, `bot_wander`, `nearest`, `bot_lined_up` and `bot_roll`.
7. Add the path to `Game.MINIGAMES` in `autoload/game.gd`.
8. Run the tests. Every minigame is automatically played to the end by CPUs with 2, 4 and 8 players.

## Tests

```bash
tools/run_tests.sh                      # everything (~30 s)
ONLY=unit tools/run_tests.sh            # art templates, scoring, round planning
ONLY=minigames tools/run_tests.sh       # every minigame with 2/4/8 CPUs
ONLY=match tools/run_tests.sh           # a full 10-round match through to the podium
```

To take screenshots without a monitor (needs `xvfb-run`):

```bash
GAME=res://minigames/paint_the_isle.gd N=6 TIMES=5,10 OUT=/tmp/shot tools/capture.sh
GAME=match N=4 HUMAN=1 TIMES=2,20 OUT=/tmp/match tools/capture.sh
```
