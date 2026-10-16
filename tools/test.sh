#!/bin/sh
# CPU/headless regression gate. GODOT_BIN accepts one engine executable path/name.
set -eu
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
exec python3 "$script_dir/tests/test_runner.py" "$@"
