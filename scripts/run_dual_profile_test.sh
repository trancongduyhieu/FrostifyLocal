#!/usr/bin/env bash
# Dual Profile Test Launcher for Nutsty Friends Pulse & 24h Notes
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure auth server is running
if ! pgrep -f "backend/auth_server.py" >/dev/null 2>&1; then
    echo "Starting backend auth server (127.0.0.1:17890)..."
    python3 "$DIR/backend/auth_server.py" >/dev/null 2>&1 &
    sleep 1
fi

ACTION="${1:-auto}"

if [ "$ACTION" = "both" ]; then
    echo "Restarting both Nutsty instances (user1 & user2)..."
    pkill -9 -f "quickshell.*FrostifyLocal/shell.qml" || true
    sleep 1

    echo "Launching Instance 1 (user1)..."
    NUTSTY_PROFILE="user1" quickshell --allow-duplicate -d -p "$DIR/shell.qml"
    sleep 2

    echo "Launching Instance 2 (user2)..."
    NUTSTY_PROFILE="user2" quickshell --allow-duplicate -d -p "$DIR/shell.qml"
    echo "Both Nutsty windows launched!"
    exit 0
elif [ "$ACTION" = "auto" ]; then
    # If a Nutsty instance is already open, launch user2 as the companion window
    if pgrep -f "quickshell.*FrostifyLocal/shell.qml" >/dev/null 2>&1; then
        echo "Detected existing Nutsty instance. Launching second window (user2)..."
        export NUTSTY_PROFILE="user2"
        exec /usr/bin/quickshell --allow-duplicate -p "$DIR/shell.qml"
    else
        echo "No instance running. Launching both user1 and user2..."
        "$0" both
    fi
else
    echo "Launching Nutsty with Profile: '$ACTION'..."
    export NUTSTY_PROFILE="$ACTION"
    exec /usr/bin/quickshell --allow-duplicate -p "$DIR/shell.qml"
fi
