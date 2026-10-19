#!/usr/bin/env bash
# Builds the browser version into build/web/ (needs the Godot 4.7 web export templates).
# The page web/lan-december.html loads the engine from base64 text files so every file
# stays a standard web type under 15 MB (for hosting as a Claude artifact).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/web
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release "Web" build/web/index.html
cd build/web
gzip -9 -c index.wasm | base64 -w0 > index.wasm.gz.b64.txt
base64 -w0 index.pck > index.pck.b64.txt
cp ../../web/lan-december.html .
# The page needs the real sizes of the text files for its progress bar.
sed -i -E "s/(file: 'index.wasm.gz.b64.txt', size: )[0-9]+/\1$(stat -c %s index.wasm.gz.b64.txt)/; s/(file: 'index.pck.b64.txt', size: )[0-9]+/\1$(stat -c %s index.pck.b64.txt)/; s/(\"index.pck\":)[0-9]+/\1$(stat -c %s index.pck)/; s/(\"index.wasm\":)[0-9]+/\1$(stat -c %s index.wasm)/" lan-december.html
echo "Built build/web/lan-december.html"
