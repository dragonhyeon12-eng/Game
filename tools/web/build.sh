#!/bin/bash
# Build the browser version of DREAM PROTOCOL into a folder, ready to publish next to tools/web/play.html.
#   tools/web/build.sh /path/to/godot-4.7.1 /path/to/output
# Needs Godot 4.7.1's export templates installed (web_nothreads_release.zip) and an export preset named
# "Web" (variant/thread_support=false; exclude tests/* and tools/*). export_presets.cfg is git-ignored.
set -e
GODOT=$1; OUT=$2
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$OUT/raw"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/raw/index.html"
cp "$ROOT/tools/web/play.html" "$OUT/"
cp "$OUT/raw/index.js" "$OUT/raw/index.audio.worklet.js" "$OUT/raw/index.audio.position.worklet.js" "$OUT/"
gzip -9 -c "$OUT/raw/index.wasm" > "$OUT/engine.wasm"     # gzip bytes; play.html decompresses them
# the host only serves known file types, with a size limit per file: the game data goes up in 3 parts
split -n 3 -d -a 1 "$OUT/raw/index.pck" "$OUT/data"
for f in "$OUT"/data[0-9]; do mv "$f" "$f.wasm"; done
echo "fileSizes for play.html (index.pck; DATA_PARTS must match):"; grep -o '"fileSizes":{[^}]*}' "$OUT/raw/index.html"
