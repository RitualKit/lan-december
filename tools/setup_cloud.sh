#!/usr/bin/env bash
# Installs what this project needs in a fresh Linux container (e.g. Claude Code on the web):
#   - Godot 4.7 at /opt/godot, linked as `godot`
#   - the single-threaded web export template (only that file is kept from the 1.3 GB bundle)
#   - xvfb + lavapipe (software Vulkan) for headless screenshots
# Safe to re-run: each step is skipped when already done.
set -euo pipefail
V=4.7
REL=https://github.com/godotengine/godot/releases/download/$V-stable

if ! command -v godot >/dev/null; then
	mkdir -p /opt/godot
	curl -sSL -o /opt/godot/g.zip "$REL/Godot_v$V-stable_linux.x86_64.zip"
	unzip -oq /opt/godot/g.zip -d /opt/godot && rm /opt/godot/g.zip
	ln -sf "/opt/godot/Godot_v$V-stable_linux.x86_64" /usr/local/bin/godot
fi

T="$HOME/.local/share/godot/export_templates/$V.stable"
if [ ! -f "$T/web_nothreads_release.zip" ]; then
	# The host doesn't support range requests, so the whole bundle has to come down once.
	tmp=$(mktemp -d)
	curl -sSL -o "$tmp/t.tpz" "$REL/Godot_v$V-stable_export_templates.tpz"
	unzip -oq "$tmp/t.tpz" templates/web_nothreads_release.zip templates/version.txt -d "$tmp"
	mkdir -p "$T" && cp "$tmp"/templates/* "$T/" && rm -rf "$tmp"
fi

if ! dpkg -s xvfb mesa-vulkan-drivers libvulkan1 >/dev/null 2>&1; then
	apt-get install -y -qq xvfb mesa-vulkan-drivers libvulkan1 >/dev/null 2>&1 \
		|| { apt-get update -qq && apt-get install -y -qq xvfb mesa-vulkan-drivers libvulkan1 >/dev/null; }
fi

godot --version
echo "Ready: godot, web template, xvfb + lavapipe"
