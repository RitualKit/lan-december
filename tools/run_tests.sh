#!/usr/bin/env bash
# Runs the headless test suite. Fails on any failed check or script error.
# Usage: tools/run_tests.sh            (all)
#        ONLY=unit|minigames|match tools/run_tests.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import >/dev/null 2>&1
log=$(mktemp)
"$GODOT" --headless --fixed-fps 60 --audio-driver Dummy res://tests/test_runner.tscn 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Failed to load script" "$log"; then
	echo "Script errors found in output."
	status=1
fi
rm -f "$log"
exit $status
