#!/usr/bin/env python3
"""
Frostify Local MPV Audio Controller & IPC Bridge
Controls playback losslessly via MPV socket and status polling
"""
import os
import sys
import json
import time
import socket
import subprocess

MPV_SOCKET = "/tmp/frostify_mpv.sock"
STATUS_FILE = "/tmp/frostify_status.json"
COMMAND_FILE = "/tmp/frostify_cmd.pipe"

def ensure_mpv():
    """Ensure background MPV process is running with IPC socket"""
    try:
        # Check if socket is active
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(MPV_SOCKET)
        s.close()
        return True
    except Exception:
        pass

    # Start mpv
    if os.path.exists(MPV_SOCKET):
        try:
            os.remove(MPV_SOCKET)
        except Exception:
            pass

    cmd = [
        "mpv",
        "--idle=yes",
        "--no-video",
        f"--input-ipc-server={MPV_SOCKET}",
        "--audio-buffer=0.2",
        "--title=frostify-audio"
    ]
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Wait for socket to appear
    for _ in range(20):
        time.sleep(0.1)
        if os.path.exists(MPV_SOCKET):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(MPV_SOCKET)
                s.close()
                return True
            except Exception:
                pass
    return False

def send_mpv_cmd(command_args):
    """Send JSON IPC command to MPV"""
    ensure_mpv()
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(MPV_SOCKET)
        payload = json.dumps({"command": command_args}) + "\n"
        s.sendall(payload.encode("utf-8"))
        data = s.recv(4096)
        s.close()
        return json.loads(data.decode("utf-8"))
    except Exception as e:
        return {"error": str(e)}

def get_mpv_property(prop):
    res = send_mpv_cmd(["get_property", prop])
    return res.get("data")

def main():
    if len(sys.argv) < 2:
        print("Usage: player_daemon.py [play <path> | pause | resume | toggle | seek <sec> | stop | status]")
        sys.exit(1)

    action = sys.argv[1].lower()

    if action == "play" and len(sys.argv) > 2:
        file_path = sys.argv[2]
        send_mpv_cmd(["loadfile", file_path, "replace"])
        send_mpv_cmd(["set_property", "pause", False])
        print("Playing:", file_path)

    elif action == "toggle":
        is_paused = get_mpv_property("pause")
        send_mpv_cmd(["set_property", "pause", not is_paused])
        print("Toggled pause to:", not is_paused)

    elif action == "pause":
        send_mpv_cmd(["set_property", "pause", True])

    elif action == "resume":
        send_mpv_cmd(["set_property", "pause", False])

    elif action == "stop":
        send_mpv_cmd(["stop"])

    elif action == "seek" and len(sys.argv) > 2:
        sec = float(sys.argv[2])
        send_mpv_cmd(["seek", sec, "absolute"])

    elif action == "volume" and len(sys.argv) > 2:
        vol = float(sys.argv[2])
        send_mpv_cmd(["set_property", "volume", vol])

    elif action == "status":
        ensure_mpv()
        pause = get_mpv_property("pause")
        time_pos = get_mpv_property("time-pos") or 0.0
        duration = get_mpv_property("duration") or 0.0
        filename = get_mpv_property("filename") or ""
        vol = get_mpv_property("volume") or 100

        status = {
            "is_playing": (pause is False),
            "is_paused": (pause is True),
            "time_pos": round(time_pos, 1),
            "duration": round(duration, 1),
            "filename": filename,
            "volume": vol
        }
        print(json.dumps(status))

if __name__ == "__main__":
    main()
