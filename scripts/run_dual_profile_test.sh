#!/usr/bin/env bash
# Dual Profile Test Launcher for Nutsty Friends Pulse & 24h Notes
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure auth server is running
if ! pgrep -f "backend/auth_server.py" >/dev/null 2>&1; then
    echo "Starting backend auth server..."
    python3 "$DIR/backend/auth_server.py" >/dev/null 2>&1 &
    sleep 1
fi

PROFILE="${1:-friend}"
echo "Launching Nutsty with Profile: '$PROFILE'..."
export NUTSTY_PROFILE="$PROFILE"
exec /usr/bin/quickshell --allow-duplicate -p "$DIR/shell.qml"
