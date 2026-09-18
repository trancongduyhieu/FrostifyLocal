#!/usr/bin/env python3
"""
Nutsty MPV Audio Controller & IPC Bridge
Controls playback losslessly via MPV socket and status polling
"""
import os
import sys
import json
import time
import math
import socket
import subprocess

MPV_SOCKET = "/tmp/nutsty_mpv.sock"
STATUS_FILE = "/tmp/nutsty_status.json"
COMMAND_FILE = "/tmp/nutsty_cmd.pipe"

YTDL_FORMAT_MAP = {
    "high_opus": "774/141/251/140/bestaudio/best",
    "high_aac": "141/774/140/251/bestaudio/best",
    "medium": "251/140/bestaudio/best",
    "low": "250/ba[abr<=70]/bestaudio/best"
}

def get_current_streaming_quality():
    settings_path = os.path.expanduser("~/.config/noctalia/nutsty_settings.json")
    if os.path.exists(settings_path):
        try:
            with open(settings_path, "r", encoding="utf-8") as f:
                return json.load(f).get("streamingQuality", "high_opus")
        except Exception:
            pass
    return "high_opus"

def ensure_mpv():
    """Ensure background MPV process is running with IPC socket"""
    try:
        # Check if socket is active
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.6)
        s.connect(MPV_SOCKET)
        s.close()
        return True
    except Exception:
        pass

    # If socket connection failed, clean up any zombie/stuck mpv with nutsty-audio
    try:
        subprocess.run(["pkill", "-f", "title=nutsty-audio"], capture_output=True)
        time.sleep(0.1)
    except Exception:
        pass

    # Start mpv
    if os.path.exists(MPV_SOCKET):
        try:
            os.remove(MPV_SOCKET)
        except Exception:
            pass

    streaming_quality = get_current_streaming_quality()
    ytdl_fmt = YTDL_FORMAT_MAP.get(streaming_quality, "774/141/251/140/bestaudio/best")

    cookie_file = "/tmp/nutsty_yt_cookies.txt"
    if not os.path.exists(cookie_file):
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import ytmusic_helper
            cookie_file = ytmusic_helper.get_exported_cookie_file()
        except Exception:
            pass

    cmd = [
        "mpv",
        "--idle=yes",
        "--no-video",
        f"--input-ipc-server={MPV_SOCKET}",
        "--audio-buffer=0.2",
        "--demuxer-max-bytes=16M",
        "--demuxer-max-back-bytes=4M",
        "--title=nutsty-audio",
        "--loop-playlist=inf",
        "--gapless-audio=yes",
        f"--ytdl-format={ytdl_fmt}"
    ]
    if cookie_file and os.path.exists(cookie_file):
        cmd.append(f"--ytdl-raw-options=cookies={cookie_file}")
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Wait for socket to appear
    for _ in range(25):
        time.sleep(0.1)
        if os.path.exists(MPV_SOCKET):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.settimeout(0.6)
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
        s.settimeout(1.5)
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

LAST_PATH_FILE = "/tmp/nutsty_last_path"

def resolve_media_path(file_path):
    if not file_path:
        return file_path
    if file_path.startswith("ytdl://") or "youtube.com/watch" in file_path or "youtu.be/" in file_path:
        try:
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import ytmusic_helper
            vid = file_path.replace("ytdl://", "")
            if "watch?v=" in vid:
                vid = vid.split("watch?v=")[1].split("&")[0]

            streaming_quality = get_current_streaming_quality()

            # Instant cache lookup with quality fallback
            cache = ytmusic_helper.load_json(ytmusic_helper.STREAM_CACHE_FILE, {})
            cached = cache.get(f"{vid}_{streaming_quality}") or cache.get(vid)
            if not cached:
                for k, v in cache.items():
                    if k.startswith(f"{vid}_") and isinstance(v, dict) and v.get("stream_url"):
                        cached = v
                        break
            if cached and (time.time() - cached.get("timestamp", 0)) < 10800:
                return cached.get("stream_url")

            # Resolve direct stream URL using authenticated format picker
            res = ytmusic_helper.resolve_stream_url(vid, streaming_quality)
            if res and res.get("stream_url"):
                return res.get("stream_url")

            return f"https://www.youtube.com/watch?v={vid}"
        except Exception as e:
            sys.stderr.write(f"[player_daemon resolve error]: {e}\n")
    return file_path

def update_current_track_metadata(file_path, title="", artist="", art_url=""):
    if not file_path:
        return
    try:
        if not title:
            app_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            lib_json = os.path.join(app_dir, "library.json")
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

        # Fallback to online tracks cache if not in local library
        if not title:
            online_json = os.path.expanduser("~/.cache/nutsty/online_tracks.json")
            if os.path.exists(online_json):
                try:
                    with open(online_json, "r", encoding="utf-8") as f:
                        on_data = json.load(f)
                        vid = file_path.replace("ytdl://", "")
                        t = on_data.get(file_path) or on_data.get(vid)
                        if t:
                            art_url = t.get("image", "")
                            title = t.get("title", "") or t.get("name", "")
                            artist = t.get("artist", "")
                except Exception:
                    pass

        # If still no title and artist, do not overwrite existing valid metadata
        if not title and not artist:
            return

        meta = {
            "title": title,
            "artist": artist,
            "artUrl": art_url,
            "path": file_path
        }
        for track_file in ["/tmp/nutsty_current_track.json", "/tmp/frostify_current_track.json"]:
            try:
                with open(track_file, "w", encoding="utf-8") as f:
                    json.dump(meta, f, ensure_ascii=False)
            except Exception:
                pass

        session_file = os.path.expanduser("~/.config/noctalia/nutsty_session.json")
        os.makedirs(os.path.dirname(session_file), exist_ok=True)
        with open(session_file, "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False)
        return meta
    except Exception:
        pass
def fade_out_and_pause(duration=5.0):
    """Gradually lowers volume using a smooth Cosine fade curve, then pauses and restores volume."""
    abort_file = "/tmp/nutsty_abort_fade"
    if os.path.exists(abort_file):
        try:
            os.remove(abort_file)
        except Exception:
            pass

    current_vol = get_mpv_property("volume")
    if current_vol is None:
        current_vol = 100.0
    else:
        try:
            current_vol = float(current_vol)
        except Exception:
            current_vol = 100.0

    if current_vol <= 0:
        send_mpv_cmd(["set_property", "pause", True])
        return

    steps = max(10, int(duration * 20))  # 20 steps per second (50ms interval)
    interval = duration / steps

    for i in range(1, steps + 1):
        if os.path.exists(abort_file):
            try:
                os.remove(abort_file)
            except Exception:
                pass
            send_mpv_cmd(["set_property", "volume", current_vol])
            return

        t = i / steps  # 0.0 -> 1.0
        # Cosine S-curve: factor = (1 + cos(pi * t)) / 2 (starts at 1.0, ends at 0.0)
        factor = (1.0 + math.cos(math.pi * t)) / 2.0
        v = round(current_vol * factor, 1)
        send_mpv_cmd(["set_property", "volume", v])
        time.sleep(interval)

    # Pause playback once volume touches 0
    send_mpv_cmd(["set_property", "pause", True])
    # Restore original volume safely so next session starts normal
    send_mpv_cmd(["set_property", "volume", current_vol])

def main():
    if len(sys.argv) < 2:
        print("Usage: player_daemon.py [play <path> [title] [artist] [art_url] | pause | resume | toggle | seek <sec> | stop | status]")
        sys.exit(1)

    action = sys.argv[1].lower()

    if action == "play" and len(sys.argv) > 2:
        file_path = sys.argv[2]
        title_arg = sys.argv[3] if len(sys.argv) > 3 else ""
        artist_arg = sys.argv[4] if len(sys.argv) > 4 else ""
        art_arg = sys.argv[5] if len(sys.argv) > 5 else ""

        # Immediately stop previous track so old audio and progress cease instantly
        send_mpv_cmd(["stop"])

        state_file = "/tmp/nutsty_playback_state.json"
        try:
            with open(state_file, "w", encoding="utf-8") as f:
                json.dump({"state": "loading", "path": file_path, "timestamp": time.time()}, f)
        except Exception:
            pass

        meta = update_current_track_metadata(file_path, title_arg, artist_arg, art_arg)
        stream_target = resolve_media_path(file_path)
        send_mpv_cmd(["set_property", "pause", False])
        send_mpv_cmd(["loadfile", stream_target, "replace"])
        send_mpv_cmd(["set_property", "loop-playlist", "inf"])
        send_mpv_cmd(["set_property", "pause", False])
        if meta and meta.get("title"):
            disp_title = f"{meta['title']} - {meta.get('artist', '')}".strip(" -")
            send_mpv_cmd(["set_property", "force-media-title", disp_title])
        else:
            send_mpv_cmd(["set_property", "force-media-title", ""])

        try:
            with open(state_file, "w", encoding="utf-8") as f:
                json.dump({"state": "playing", "path": file_path, "timestamp": time.time()}, f)
        except Exception:
            pass
        print("Playing:", file_path)

    elif action == "next":
        send_mpv_cmd(["playlist-next"])
        print("Next track")

    elif action == "prev":
        send_mpv_cmd(["playlist-prev"])
        print("Previous track")

    elif action == "set_playlist" and len(sys.argv) > 2:
        idx = int(sys.argv[2])
        m3u_file = "/tmp/nutsty_playlist.m3u"
        tracks = []
        meta = None
        if len(sys.argv) > 3:
            try:
                tracks = json.loads(sys.argv[3])
                if len(tracks) > idx:
                    meta = update_current_track_metadata(tracks[idx])
            except Exception as e:
                pass

        if len(tracks) > idx and (tracks[idx].startswith("ytdl://") or "youtube.com" in tracks[idx]):
            send_mpv_cmd(["stop"])
            state_file = "/tmp/nutsty_playback_state.json"
            try:
                with open(state_file, "w", encoding="utf-8") as f:
                    json.dump({"state": "loading", "path": tracks[idx], "timestamp": time.time()}, f)
            except Exception:
                pass

            stream_target = resolve_media_path(tracks[idx])
            send_mpv_cmd(["loadfile", stream_target, "replace"])
            send_mpv_cmd(["set_property", "pause", False])
            if meta and meta.get("title"):
                disp_title = f"{meta['title']} - {meta.get('artist', '')}".strip(" -")
                send_mpv_cmd(["set_property", "force-media-title", disp_title])

            try:
                with open(state_file, "w", encoding="utf-8") as f:
                    json.dump({"state": "playing", "path": tracks[idx], "timestamp": time.time()}, f)
            except Exception:
                pass
            print("Playing online track:", tracks[idx])
        elif tracks:
            send_mpv_cmd(["set_property", "force-media-title", ""])
            with open(m3u_file, "w", encoding="utf-8") as f:
                for t in tracks:
                    f.write(t + "\n")
            if os.path.exists(m3u_file):
                send_mpv_cmd(["loadlist", m3u_file, "replace"])
                send_mpv_cmd(["set_property", "loop-playlist", "inf"])
                send_mpv_cmd(["playlist-play-index", idx])
                send_mpv_cmd(["set_property", "pause", False])
                print("Set playlist and playing index:", idx)

    elif action == "toggle":
        ensure_mpv()
        path = get_mpv_property("path")
        idle = get_mpv_property("idle-active")
        target_file = sys.argv[2] if len(sys.argv) > 2 else ""

        if not path or idle:
            if target_file:
                stream_target = resolve_media_path(target_file)
                send_mpv_cmd(["loadfile", stream_target, "replace"])
                send_mpv_cmd(["set_property", "pause", False])
                update_current_track_metadata(target_file)
                print("Loaded and playing:", target_file)
            else:
                print("MPV is idle and no track specified")
        else:
            is_paused = get_mpv_property("pause")
            new_paused = not is_paused
            send_mpv_cmd(["set_property", "pause", new_paused])
            state_file = "/tmp/nutsty_playback_state.json"
            try:
                with open(state_file, "w", encoding="utf-8") as f:
                    json.dump({"state": "paused" if new_paused else "playing", "timestamp": time.time()}, f)
            except Exception:
                pass
            print("Toggled pause to:", new_paused)

    elif action == "pause":
        send_mpv_cmd(["set_property", "pause", True])
        state_file = "/tmp/nutsty_playback_state.json"
        try:
            with open(state_file, "w", encoding="utf-8") as f:
                json.dump({"state": "paused", "timestamp": time.time()}, f)
        except Exception:
            pass

    elif action == "resume":
        send_mpv_cmd(["set_property", "pause", False])
        state_file = "/tmp/nutsty_playback_state.json"
        try:
            with open(state_file, "w", encoding="utf-8") as f:
                json.dump({"state": "playing", "timestamp": time.time()}, f)
        except Exception:
            pass

    elif action == "stop":
        send_mpv_cmd(["stop"])
        state_file = "/tmp/nutsty_playback_state.json"
        try:
            with open(state_file, "w", encoding="utf-8") as f:
                json.dump({"state": "stopped", "timestamp": time.time()}, f)
        except Exception:
            pass

    elif action == "seek" and len(sys.argv) > 2:
        sec = float(sys.argv[2])
        send_mpv_cmd(["seek", sec, "absolute"])

    elif action == "volume" and len(sys.argv) > 2:
        vol = float(sys.argv[2])
        send_mpv_cmd(["set_property", "volume", vol])

    elif action == "fade_out_and_pause":
        dur = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
        fade_out_and_pause(dur)

    elif action == "cancel_fade":
        try:
            with open("/tmp/nutsty_abort_fade", "w") as f:
                f.write("1")
        except Exception:
            pass

    elif action == "prewarm" and len(sys.argv) > 2:
        vid = sys.argv[2]
        if vid:
            ytmusic_helper.resolve_stream_url(vid)

    elif action == "status":
        ensure_mpv()

        is_loading = False
        state_file = "/tmp/nutsty_playback_state.json"
        st = {}
        if os.path.exists(state_file):
            try:
                with open(state_file, "r", encoding="utf-8") as f:
                    st = json.load(f)
                    if st.get("state") == "loading" and (time.time() - st.get("timestamp", 0)) < 35.0:
                        is_loading = True
            except Exception:
                pass

        pause = get_mpv_property("pause")
        time_pos = get_mpv_property("time-pos") or 0.0
        duration = get_mpv_property("duration") or 0.0
        filename = get_mpv_property("filename") or ""
        path = get_mpv_property("path") or ""
        vol = get_mpv_property("volume") or 100
        idle = get_mpv_property("idle-active")
        if time_pos and time_pos > 0:
            is_loading = False

        has_file = bool(path and not idle) and not is_loading

        # Self-healing unpause: if state was recently marked 'playing' (<25s), but MPV is paused during stream load
        if st.get("state") == "playing" and (time.time() - st.get("timestamp", 0)) < 25.0:
            if pause is True and (path and not idle):
                send_mpv_cmd(["set_property", "pause", False])
                pause = False

        status = {
            "is_playing": (pause is False) and has_file,
            "is_paused": (pause is True) and has_file,
            "time_pos": round(time_pos, 1) if has_file else 0.0,
            "duration": round(duration, 1) if has_file else 0.0,
            "filename": filename if has_file else "",
            "volume": vol,
            "is_loading": is_loading
        }
        print(json.dumps(status))

    elif action == "audio_specs":
        ensure_mpv()
        codec = get_mpv_property("audio-codec-name") or ""
        bitrate = get_mpv_property("audio-bitrate") or 0
        params = get_mpv_property("audio-params") or {}

        sample_rate = params.get("samplerate", 0)
        channels = params.get("channel-count", 2)
        channel_str = "Stereo (2ch)" if channels == 2 else (f"{channels}ch" if channels else "Stereo")

        bitrate_kbps = round(bitrate / 1000) if bitrate > 1000 else int(bitrate)
        if bitrate_kbps == 0:
            bitrate_kbps = 192 if codec in ["opus", "aac"] else (320 if codec == "mp3" else 192)

        samplerate_str = f"{sample_rate / 1000:.1f} kHz" if sample_rate > 0 else "48.0 kHz"

        specs = {
            "codec": (codec or "aac").upper(),
            "bitrate": bitrate_kbps,
            "bitrate_str": f"{bitrate_kbps} kbps" if bitrate_kbps > 0 else "192 kbps",
            "sample_rate": sample_rate or 48000,
            "sample_rate_str": samplerate_str,
            "channels": channel_str
        }
    elif action == "set_streaming_quality" and len(sys.argv) > 2:
        ensure_mpv()
        qual = sys.argv[2]
        ytdl_fmt = YTDL_FORMAT_MAP.get(qual, "774/141/251/140/bestaudio/best")
        send_mpv_cmd(["set_property", "ytdl-format", ytdl_fmt])
        print(json.dumps({"success": True, "quality": qual, "ytdl_format": ytdl_fmt}))

if __name__ == "__main__":
    main()
