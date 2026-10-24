---
name: new-minigame
description: Add a new minigame to LAN December, including the build, rules, ranking, CPU bots and registration, with the determinism online play needs. Use when the user asks for new game modes or minigames.
---

# Add a minigame

1. Create `minigames/<name>.gd` with `extends Minigame`. Read a similar game first:
   - score-based: `petal_rush.gd`, `monster_bonk.gd`
   - last-one-standing: `crumble.gd`, `petal_push.gd`
   - race: `river_run.gd`
   - reaction: `koi_catch.gd`
2. In `_init()`, set `title`, `tagline`, `rules` (3 short lines), `action_name`, `accent`, `time_limit` and `bump_power`. Optionally set:
   - `last_standing`
   - `powerups_enabled` and `powerup_items`
   - `theme_name`, to force a theme
3. Write `build()`:
   ```gdscript
   radius = 5.0 + 0.15 * players.size()
   arena.build(Arena.disc(radius))           # a dict of Vector2i -> level; set level 1 for raised obstacles
   arena.setup_view(Vector3.ZERO, 18.0 + radius)
   arena.decorate(rng.randi(), radius)
   spawn_characters(arena.spawn_ring(players.size(), radius * 0.45))
   ```
4. Put the rules in `tick(delta)`. Call `finish()` to end early.
5. Implement `rank()`, for example `score_ranking(scores)`, and `status_text(slot)` for the HUD chip.
6. Implement `bot_input(ch) -> {move: Vector2, action: bool, hold: bool}`. The helpers are `bot_go`, `bot_steer`, `bot_wander`, `nearest`, `bot_lined_up` and `bot_roll`. Make bots beatable: use `ch.slot.skill`, plus some randomness from `rng`.
7. Register the path in `Game.MINIGAMES` (`autoload/game.gd`).
8. Support both looks. When `Game.look_3d` is true, use the 3D props from `core/props.gd`; otherwise use sprites from `Art`.

## Online-safe from the start

Follow the `lockstep-determinism` skill: use only `rng`, physics-timed pausable timers, and logical positions for gameplay.

## Verify

```bash
ONLY=minigames GAME=<name> tools/run_tests.sh   # 2/4/8 CPUs play to the end
ONLY=lockstep GAME=<name> tools/run_tests.sh    # must say "same"
GAME=res://minigames/<name>.gd N=4 TIMES=3,10 OUT=/tmp/<name> tools/capture.sh
```

Then add the game to the README's minigame gallery:
1. Pick a lively frame from the capture.
2. Save it as `docs/screenshots/<name>.jpg`: 960×540, JPEG quality ~86 (PIL `resize` + `save(quality=86, optimize=True)`).
3. Add a `<td>` cell with the image, the name, the button and a one-line goal, matching the other cells.

Check the balance too: rounds should last 20–45 s and the CPUs shouldn't always win.
