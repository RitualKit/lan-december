# LAN December

A local multiplayer party game for 2–8 players, built in **Godot 4.7**. Each match is 5, 10 or 15 rounds of quick minigames on floating cherry-blossom islands, in a 2.5D pixel-art style: low-poly 3D tiles with pixel textures and pixel-sprite characters.

Everyone plays on one screen. Players use keyboards and gamepads, and CPU players can fill empty seats. Treasure chests with bombs, shurikens and spells let players blast each other off the islands.

## Run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open `project.godot` in Godot and press **F5**, or run `godot --path .` from this folder.

## Controls

| Device | Move | Action (join / dash / hop / strike) | Use item | Back (leave) |
|---|---|---|---|---|
| Keyboard left | WASD | Space | E or Q | E |
| Keyboard right | Arrow keys | Enter | Right Shift or / | Backspace |
| Gamepad (each one) | Left stick / D-pad | A | X or B | B |

**Esc** or **Start** pauses. While paused, **Back** quits to the lobby.

### Lobby

- Press the action button on any device to join. Your character drops onto the island.
- Walk onto **+ CPU** or **- CPU** to add or remove computer players. On keyboard, **+** and **-** also work; on a gamepad, use the shoulder buttons.
- Walk onto **ROUNDS** to switch between 5, 10 and 15 rounds.
- Walk onto **NEW LOOK** to switch to another character. Every player always has a different one.
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

## Power-ups

In Petal Push, Petal Rush, Hot Lantern, Blossom King and Paint the Isle, treasure chests drop onto the island every few seconds. Walk into one to grab a random item; its icon floats over your head. Press the item button to use it. You can only hold one item at a time.

| Item | Effect |
|---|---|
| **Bomb** | Thrown about 4.5 tiles ahead. Explodes after a short fuse and blasts away everyone nearby, including you. |
| **Shurikens** | Three stars in a spread ahead of you. Each hit knocks the target back and stuns them. |
| **Fire Blast** | A burst of fire around you that throws back everyone close. |
| **Freeze** | Freezes everyone near you in an ice block for about 2 seconds. |
| **Thunder** | Marks every opponent's spot. Lightning strikes there a moment later, so keep moving to dodge it. |
| **Giant** | 7 seconds of being huge: you hit much harder and barely get pushed. |
| **Speed** | 6 seconds of running faster, and your dash recharges immediately. |
| **Shield** | 6 seconds of a bubble that blocks all knockback and freezing. |

Hits from items count like dash hits: in Petal Rush they make the victim drop blossoms. Hot Lantern only drops Freeze, Thunder, Speed and Shield, so the lantern stays the main threat. CPUs pick up chests and use their items too.

## Art, sound and fonts

- **Characters, effects, item icons and some sounds** come from the [Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack) pack by Pixel-boy (CC0, credit appreciated). The files used are in `assets/ninja_adventure/`, which also holds the license and the source link.

- **Island textures are generated in code** (`autoload/art.gd`): grass, cliffs, paths, blossoms and bark. To replace a texture, drop a PNG with the same name into `assets/textures/` (for example `grass.png`, 16×16) and it is used instead of the generated one.
- **Most sound effects are generated in code** by a small chiptune synth (`autoload/sfx.gd`); pickup, spell, throw and knockout sounds come from the pack. To replace a sound, drop `assets/sfx/<name>.ogg` or `.wav` into place, using a name such as `coin`, `boom`, `splash` or `win`.
- **Fonts:** Tiny5 and Silkscreen, both under the SIL Open Font License (see `assets/fonts/OFL.txt`).
- **No music yet.** The same pack has 19 CC0 music tracks that could be added.

## Project layout

```
autoload/   Art (procedural art), Sfx (synth), Controls (per-device input), Game (match state & scoring)
core/       Minigame base class, PlayerCharacter, Powerups, Arena/ArenaTile (island builder), water shader, Fx, Props, Ui
main/       main.tscn (screen switcher + pause), lobby, match_host (rounds/intro/results), podium
minigames/  One script per minigame
tests/      Headless test suite
tools/      run_tests.sh, capture.sh (screenshots)
```

## Adding a minigame

1. Create `minigames/my_game.gd` with `extends Minigame`.
2. In `_init()`, set `title`, `tagline`, `rules`, `action_name`, `time_limit` and, if needed, `last_standing`. Set `powerups_enabled = true` for item chests, and optionally `powerup_items` to limit which items drop.
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
ONLY=unit tools/run_tests.sh            # assets, characters, scoring, round planning
ONLY=powerups tools/run_tests.sh        # fires every item at a target
ONLY=minigames tools/run_tests.sh       # every minigame with 2/4/8 CPUs
ONLY=match tools/run_tests.sh           # a full 10-round match through to the podium
```

To take screenshots without a monitor (needs `xvfb-run`):

```bash
GAME=res://minigames/paint_the_isle.gd N=6 TIMES=5,10 OUT=/tmp/shot tools/capture.sh
GAME=match N=4 HUMAN=1 TIMES=2,20 OUT=/tmp/match tools/capture.sh
GAME=res://minigames/blossom_king.gd N=6 ITEMS=1 TIMES=3,4 OUT=/tmp/items tools/capture.sh   # CPUs keep getting items
```
