#!/usr/bin/env bash
# Frostify Local Entry Script
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If an instance of Frostify is already running, bring window to front via IPC
if /usr/bin/quickshell ipc -p "$DIR/shell.qml" call frostify openWindow 2>/dev/null; then
    echo "Frostify Local is already running, brought window to front."
    if ! pgrep -f "backend/tray_indicator.py" >/dev/null 2>&1; then
        /usr/bin/python3 "$DIR/backend/tray_indicator.py" >/dev/null 2>&1 &
    fi
    exit 0
fi

# Ensure background tray indicator is running
if ! pgrep -f "backend/tray_indicator.py" >/dev/null 2>&1; then
    /usr/bin/python3 "$DIR/backend/tray_indicator.py" >/dev/null 2>&1 &
fi

# Scan library if missing or requested
if [ ! -f "$DIR/library.json" ] || [ "$1" == "--rescan" ]; then
    echo "Scanning music library..."
    python3 "$DIR/backend/library.py"
fi

# Launch Frostify Local with Quickshell
echo "Launching Frostify Local..."
exec /usr/bin/quickshell -p "$DIR/shell.qml"
