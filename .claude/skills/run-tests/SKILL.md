---
name: run-tests
description: Run LAN December's headless Godot test suite (unit, lockstep, powerups, minigames, full match) and read the results. Use after any gameplay, UI or netcode change, before committing.
---

# Run the tests

The suite is `tests/test_runner.gd` (scene `tests/test_runner.tscn`), run headless at a fixed 60 fps by `tools/run_tests.sh`. The wrapper also fails on any `SCRIPT ERROR`, `Parse Error`, `Invalid call` or `Failed to load script`, even when every check passed.

If `godot` is missing (fresh container), run `tools/setup_cloud.sh` first.

```bash
tools/run_tests.sh                                  # everything, a few minutes
ONLY=unit tools/run_tests.sh                        # assets, characters, scoring, round planning
ONLY=lockstep tools/run_tests.sh                    # every minigame replays identically (online sync)
ONLY=powerups tools/run_tests.sh                    # fires every item at a target
ONLY=minigames tools/run_tests.sh                   # every minigame with 2/4/8 CPUs
ONLY=minigames GAME=river_run tools/run_tests.sh    # GAME filters by path substring
ONLY=match tools/run_tests.sh                       # a full match through to the podium
```

## Reading the output

- Success is the last line `N checks, 0 failures`. N varies a little between runs; that's normal.
- Failures print `FAIL: <description>`. Grep for it: `tools/run_tests.sh 2>&1 | grep -E "FAIL|failures|ERROR"`.
- A script that fails to parse shows as `SCRIPT ERROR: Parse Error ...`, followed by `Nonexistent function 'new'` errors where it's used. Fix the parse error first. The usual cause is a type inferred from a Variant; add an explicit type.
- `ERROR: Lambda capture at index 0 was freed` means a timer or tween lambda captured a node that was freed first. Capture a `weakref()` instead (see `minigames/koi_catch.gd`).

## Lockstep section

Each minigame plays twice from the same seed with scripted inputs. Run 1 adds random 30% frame stalls, a different intro length, the 3D look, and run 0's snapshots fed in as if from a host. Both runs must end on the same tick with the same final checksum. The line per game reads `same (N ticks, X/Y checkpoints differed, Z snapshot fixes)`; checkpoints differing for a moment is fine.

Switches for debugging a `DIFFERENT` game:
- `SAME_LOOK=1`, `NO_STALL=1`, `NO_SNAPS=1` turn off one difference at a time.
- `TRACE=1` prints the first tick where the two runs' character states differ, and the tick before it.

```bash
TRACE=1 NO_SNAPS=1 ONLY=lockstep GAME=snowball tools/run_tests.sh 2>&1 | grep -A6 "trace diverges"
```

Then follow the `lockstep-determinism` skill.
