#!/usr/bin/env bash
# Frostify Local Entry Script
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Scan library if missing or requested
if [ ! -f "$DIR/library.json" ] || [ "$1" == "--rescan" ]; then
    echo "Scanning music library..."
    python3 "$DIR/backend/library.py"
fi

# Launch Frostify Local with Quickshell
echo "Launching Frostify Local..."
exec /usr/bin/quickshell -p "$DIR/shell.qml"
