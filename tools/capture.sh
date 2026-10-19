#!/usr/bin/env bash
# Screenshot helper: GAME=... N=... TIMES=... OUT=... tools/capture.sh
cd "$(dirname "$0")/.."
exec xvfb-run -a -s "-screen 0 1280x720x24" "${GODOT:-godot}" --audio-driver Dummy --fixed-fps 30 --resolution 1280x720 res://tools/capture.tscn
