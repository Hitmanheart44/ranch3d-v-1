#!/bin/sh
# Terrain bake: heights from the game's own height(), then AO / colour / texture assets with numpy.
cd "$(dirname "$0")/../.." || exit 1
mkdir -p ~/.cache/ranch3d_tmp
godot --headless --path . res://tools/bake/export_heights.tscn 2>&1 | grep EXPORTED
godot --headless --path . res://tools/bake/bake_far.tscn 2>&1 | grep FAR
python3 tools/bake/bake_terrain.py
godot --headless --path . --import >/dev/null 2>&1
