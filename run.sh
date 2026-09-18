#!/usr/bin/env bash
# Nutsty Entry Script
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If an instance of Nutsty is already running, bring window to front via IPC
if /usr/bin/quickshell ipc -p "$DIR/shell.qml" call nutsty openWindow 2>/dev/null || /usr/bin/quickshell ipc -p "$DIR/shell.qml" call frostify openWindow 2>/dev/null; then
    echo "Nutsty is already running, brought window to front."
    if ! pgrep -f "backend/tray_indicator.py" >/dev/null 2>&1; then
        python3 "$DIR/backend/tray_indicator.py" >/dev/null 2>&1 &
    fi
    exit 0
fi

# Ensure background tray indicator and auth server are running
if ! pgrep -f "backend/tray_indicator.py" >/dev/null 2>&1; then
    python3 "$DIR/backend/tray_indicator.py" >/dev/null 2>&1 &
fi
if ! pgrep -f "backend/auth_server.py" >/dev/null 2>&1; then
    python3 "$DIR/backend/auth_server.py" >/dev/null 2>&1 &
fi

# Ensure required Python dependencies (mutagen)
if ! python3 -c "import mutagen" >/dev/null 2>&1; then
    echo "Installing missing dependency: mutagen..."
    python3 -m pip install mutagen --quiet || true
fi

# Scan library if missing or requested
if [ ! -f "$DIR/library.json" ] || [ "$1" == "--rescan" ]; then
    echo "Scanning music library..."
    python3 "$DIR/backend/library.py"
fi

# Memory allocator tuning: prevent jemalloc from using 2MB Transparent Huge Pages
# and aggressively return unused dirty memory to the OS (vital for CachyOS/Arch Linux)
export MALLOC_CONF="background_thread:true,dirty_decay_ms:1000,muzzy_decay_ms:1000,thp:never,metadata_thp:disabled"

# Launch Nutsty with Quickshell (with kernel THP disabled to prevent memory inflation)
echo "Launching Nutsty..."
exec python3 -c '
import ctypes, os, sys
try:
    # PR_SET_THP_DISABLE = 41
    ctypes.CDLL(None).prctl(41, 1, 0, 0, 0)
except Exception:
    pass
os.execvp("/usr/bin/quickshell", ["/usr/bin/quickshell", "-p", sys.argv[1]])
' "$DIR/shell.qml"
