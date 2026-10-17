#!/bin/sh
# Refresh imported assets and Godot's local class registry after repository pulls.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
"$godot_bin" --headless --editor --import --path "$project_root"
exec "$godot_bin" --path "$project_root" "$@"
