---
name: lockstep-determinism
description: Keep LAN December's minigames deterministic so online lockstep play stays in sync across browsers, and debug a desync. Use when writing or changing gameplay code, or when the lockstep test reports DIFFERENT.
---

# Determinism for online lockstep

In online play, every page simulates the whole match and only inputs travel (`autoload/net.gd`). Gameplay state must therefore depend only on:
- the round seed,
- the players' inputs per tick,
- the tick count.

It must never depend on wall-clock time, frame rate, rendering or the visual look. Each page may use a different look (pixel or 3D) and may stall for a different number of frames while it waits for input.

## Rules

| Do | Don't |
|---|---|
| `rng.randf()`, `rng.randi()`: the minigame's seeded RNG | `randf()`, `randi()`, `Array.shuffle()`, `pick_random()` |
| `get_tree().create_timer(t, false, true)`: pausable, physics-timed | `create_timer(t)`, which counts idle frames and keeps running while paused |
| Gameplay tweens on `.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)` | idle-process tweens that move anything gameplay reads |
| Store the logical position (`pickup.pos`, `zone_pos`) and test against that | reading `node.global_position` while a tween animates it |
| Read input from `_input_for(ch)` | reading `Controls` or `Input` directly in a minigame |
| Iterate arrays in insertion order | relying on the order of `Dictionary` keys built from node references |
| Visual-only effects (`Fx`, `Sfx`, popups) anywhere | letting a visual node's state feed back into scoring |

`begin()` puts characters back on their spawn points when online, so the intro's length doesn't matter. Don't run gameplay before `begin()`.

## Safety nets already in place

- `PlayerCharacter` rounds its position, velocity and knockback to 1/1024 each tick during lockstep.
- Every 6 ticks the host publishes a fixed-point snapshot. Other pages compare it with their own history for that tick and shift characters by the difference (`Net._apply_snap`).
- The host's ranking is the one everyone scores (`Net.share_result` / `result_for`). A page whose round is still running stops when the host's result arrives.

These cover last-bit differences in the physics engine: collision results can depend on each page's physics history. They don't cover scores, tiles or other minigame state. Those must be deterministic.

## Debugging a DIFFERENT game

```bash
TRACE=1 NO_SNAPS=1 ONLY=lockstep GAME=<name> tools/run_tests.sh 2>&1 | grep -A6 "trace diverges"
```

- The trace prints each character's `[position, velocity, facing, alive, stun, invulnerable]` and the status texts, at the first differing tick and the tick before it.
- A difference of 1e-6 at a tile seam is physics noise; the snapshots fix it.
- A whole-step difference in a score or `alive` flag is a real bug. Look for the rule broken in the table above.
- Use `SAME_LOOK=1` or `NO_STALL=1` to isolate whether the look or the stalls cause it.
