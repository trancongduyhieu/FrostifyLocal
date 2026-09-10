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
        "--title=frostify-audio",
        "--loop-playlist=inf",
        "--gapless-audio=yes"
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

LAST_PATH_FILE = "/tmp/frostify_last_path"

def update_current_track_metadata(file_path):
    if not file_path:
        return
    try:
        app_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        lib_json = os.path.join(app_dir, "library.json")
        art_url = ""
        title = ""
        artist = ""
        if os.path.exists(lib_json):
            with open(lib_json, "r", encoding="utf-8") as f:
                tracks = json.load(f)
                for t in tracks:
                    p = t.get("path", "")
                    fn = t.get("filename", "")
                    if p == file_path or (fn and file_path.endswith(fn)):
                        art_url = t.get("image", "")
                        title = t.get("title", "") or t.get("name", "")
                        artist = t.get("artist", "")
                        break

        meta = {
            "title": title,
            "artist": artist,
            "artUrl": art_url,
            "path": file_path
        }
        with open("/tmp/frostify_current_track.json", "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False)

        session_file = os.path.expanduser("~/.config/noctalia/frostify_session.json")
        os.makedirs(os.path.dirname(session_file), exist_ok=True)
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False)
    except Exception:
        pass

def main():
    if len(sys.argv) < 2:
        print("Usage: player_daemon.py [play <path> | pause | resume | toggle | seek <sec> | stop | status]")
        sys.exit(1)

    action = sys.argv[1].lower()

    if action == "play" and len(sys.argv) > 2:
        file_path = sys.argv[2]
        update_current_track_metadata(file_path)
        send_mpv_cmd(["loadfile", file_path, "replace"])
        send_mpv_cmd(["set_property", "loop-playlist", "inf"])
        send_mpv_cmd(["set_property", "pause", False])
        print("Playing:", file_path)

    elif action == "next":
        send_mpv_cmd(["playlist-next"])
        print("Next track")

    elif action == "prev":
        send_mpv_cmd(["playlist-prev"])
        print("Previous track")

    elif action == "set_playlist" and len(sys.argv) > 2:
        idx = int(sys.argv[2])
        m3u_file = "/tmp/frostify_playlist.m3u"
        if len(sys.argv) > 3:
            try:
                tracks = json.loads(sys.argv[3])
                if len(tracks) > idx:
                    update_current_track_metadata(tracks[idx])
                with open(m3u_file, "w", encoding="utf-8") as f:
                    for t in tracks:
                        f.write(t + "\n")
            except Exception as e:
                pass
        if os.path.exists(m3u_file):
            send_mpv_cmd(["loadlist", m3u_file, "replace"])
            send_mpv_cmd(["set_property", "loop-playlist", "inf"])
            send_mpv_cmd(["playlist-play-index", idx])
            send_mpv_cmd(["set_property", "pause", False])
            print("Set playlist and playing index:", idx)

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
        path = get_mpv_property("path") or ""
        vol = get_mpv_property("volume") or 100

        if path:
            update_current_track_metadata(path)
        elif filename:
            update_current_track_metadata(filename)

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
