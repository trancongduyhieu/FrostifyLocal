#!/usr/bin/env python3
"""
Nutsty Download Manager (Multi-Thread Architecture)
- Real-time download queue & worker daemon
- Audio extraction (192k AAC/M4A / Opus) via yt-dlp + FFmpeg
- Embedded album art & ID3 metadata
- Automatic synced lyrics (.lrc) fetching
- Desktop notifications & batch summary
- Unix domain socket IPC (/tmp/nutsty_download.sock) & stdout JSON stream
"""

import os
import sys
import json
import time
import socket
import select
import threading
import subprocess

SOCKET_PATH = "/tmp/nutsty_download.sock"
STATUS_FILE = "/tmp/nutsty_download_status.json"

STATE_NOT_DOWNLOADED = 0
STATE_PREPARING = 1
STATE_DOWNLOADING = 2
STATE_DOWNLOADED = 3
STATE_FAILED = 4

def get_download_dir():
    music_dir = os.environ.get("XDG_MUSIC_DIR") or os.path.expanduser("~/Music")
    target = os.path.join(music_dir, "Downloads_Phone")
    os.makedirs(target, exist_ok=True)
    return target

def send_desktop_notification(title, message):
    try:
        icon_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets/icons/download-symbolic.svg")
        cmd = ["notify-send", title, message, "-a", "Nutsty"]
        if os.path.exists(icon_path):
            cmd.extend(["-i", icon_path])
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

class DownloadManager:
    def __init__(self):
        self.lock = threading.Lock()
        self.queue = []  # list of dict: {videoId, title, artist, thumbnail}
        self.tasks = {}  # videoId -> dict of info & state
        self.active_downloads = set()
        self.current_task = None
        self.batch_total = 0
        self.batch_completed = 0
        self.batch_failed = 0
        self.last_song_title = ""
        self.running = True
        self.clients = set()

        self.worker_thread = threading.Thread(target=self._worker_loop, daemon=True)
        self.worker_thread.start()

    def emit_event(self, data):
        """Emit JSON event to stdout and all connected clients"""
        msg = json.dumps(data, ensure_ascii=False) + "\n"
        try:
            sys.stdout.write(msg)
            sys.stdout.flush()
        except Exception:
            pass

        dead_clients = set()
        with self.lock:
            clients_copy = list(self.clients)
        for client in clients_copy:
            try:
                client.sendall(msg.encode("utf-8"))
            except Exception:
                dead_clients.add(client)

        if dead_clients:
            with self.lock:
                self.clients.difference_update(dead_clients)

        self._save_status()

    def _save_status(self):
        try:
            with self.lock:
                payload = {
                    "active_count": len(self.active_downloads) + len(self.queue),
                    "queue_len": len(self.queue),
                    "batch_total": self.batch_total,
                    "batch_completed": self.batch_completed,
                    "batch_failed": self.batch_failed,
                    "tasks": self.tasks,
                    "queue": self.queue
                }
            tmp = STATUS_FILE + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            os.replace(tmp, STATUS_FILE)
        except Exception:
            pass

    def enqueue(self, video_id, title="Track", artist="Artist", thumbnail=""):
        if not video_id:
            return False

        with self.lock:
            # If already downloaded or in queue/downloading, skip or re-queue
            if video_id in self.tasks and self.tasks[video_id]["state"] == STATE_DOWNLOADING:
                return False

            task = {
                "videoId": video_id,
                "title": title or "Track",
                "artist": artist or "Artist",
                "thumbnail": thumbnail or "",
                "state": STATE_PREPARING,
                "progress": 0.0,
                "speed": "--",
                "eta": "--",
                "path": "",
                "error": ""
            }
            self.tasks[video_id] = task

            was_idle = len(self.active_downloads) == 0 and len(self.queue) == 0
            self.queue.append(task)
            self.batch_total += 1
            self.last_song_title = title or "Track"

            if was_idle:
                self.batch_completed = 0
                self.batch_failed = 0
                send_desktop_notification("Downloading", self.last_song_title)

        self.emit_event({
            "event": "task_enqueued",
            "videoId": video_id,
            "title": title,
            "artist": artist,
            "thumbnail": thumbnail,
            "queue_len": len(self.queue),
            "batch_total": self.batch_total,
            "active_count": len(self.active_downloads) + len(self.queue)
        })
        return True

    def cancel(self, video_id):
        with self.lock:
            self.queue = [t for t in self.queue if t["videoId"] != video_id]
            if video_id in self.tasks:
                self.tasks[video_id]["state"] = STATE_NOT_DOWNLOADED
        self.emit_event({
            "event": "task_cancelled",
            "videoId": video_id,
            "queue_len": len(self.queue),
            "active_count": len(self.active_downloads) + len(self.queue)
        })

    def clear_completed(self):
        with self.lock:
            self.tasks = {
                vid: t for vid, t in self.tasks.items()
                if t.get("state") in (STATE_PREPARING, STATE_DOWNLOADING)
            }
        self.emit_event({
            "event": "completed_cleared",
            "tasks": self.tasks,
            "queue_len": len(self.queue),
            "active_count": len(self.active_downloads) + len(self.queue)
        })

    def _worker_loop(self):
        while self.running:
            task = None
            with self.lock:
                if self.queue:
                    task = self.queue.pop(0)
                    self.active_downloads.add(task["videoId"])
                    self.current_task = task
                    task["state"] = STATE_DOWNLOADING

            if not task:
                time.sleep(0.2)
                continue

            video_id = task["videoId"]
            self.emit_event({
                "event": "task_started",
                "videoId": video_id,
                "title": task["title"],
                "artist": task["artist"],
                "active_count": len(self.active_downloads) + len(self.queue)
            })

            success = self._execute_download(task)

            with self.lock:
                self.active_downloads.discard(video_id)
                self.current_task = None
                if success:
                    self.batch_completed += 1
                else:
                    self.batch_failed += 1

                is_now_idle = len(self.active_downloads) == 0 and len(self.queue) == 0
                remaining = len(self.active_downloads) + len(self.queue)

            self.emit_event({
                "event": "task_completed" if success else "task_failed",
                "videoId": video_id,
                "title": task["title"],
                "artist": task.get("artist", ""),
                "path": task.get("path", ""),
                "error": task.get("error", ""),
                "active_count": remaining,
                "batch_completed": self.batch_completed,
                "batch_failed": self.batch_failed
            })

            if is_now_idle:
                if self.batch_total == 1:
                    summary = self.last_song_title
                elif self.batch_failed == 0:
                    summary = f"{self.batch_completed} songs downloaded"
                else:
                    summary = f"{self.batch_completed} downloaded, {self.batch_failed} failed"

                title = "Download complete" if self.batch_completed > 0 else "Download failed"
                send_desktop_notification(title, summary)

                with self.lock:
                    self.batch_total = 0
                    self.batch_completed = 0
                    self.batch_failed = 0

    def _execute_download(self, task):
        import yt_dlp

        video_id = task["videoId"]
        dl_dir = get_download_dir()
        target_url = f"https://www.youtube.com/watch?v={video_id}"

        last_progress_time = [0.0]

        def progress_hook(d):
            status = d.get("status")
            if status == "downloading":
                total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
                downloaded = d.get("downloaded_bytes") or 0
                pct = (downloaded / total * 100.0) if total > 0 else 0.0

                speed_bytes = d.get("speed") or 0
                speed_str = f"{speed_bytes / (1024*1024):.1f} MB/s" if speed_bytes else "--"
                eta_sec = d.get("eta") or 0
                eta_str = f"{eta_sec // 60:02d}:{eta_sec % 60:02d}" if eta_sec else "--"

                # Throttle progress events to max 5 per second
                now = time.time()
                if now - last_progress_time[0] >= 0.2:
                    last_progress_time[0] = now
                    with self.lock:
                        task["progress"] = round(pct, 1)
                        task["speed"] = speed_str
                        task["eta"] = eta_str

                    self.emit_event({
                        "event": "task_progress",
                        "videoId": video_id,
                        "progress": round(pct, 1),
                        "speed": speed_str,
                        "eta": eta_str
                    })

        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": os.path.join(dl_dir, "%(title)s.%(ext)s"),
            "extractor_args": {"youtube": {"player_client": ["android", "ios", "mweb"]}},
            "writethumbnail": True,
            "embedthumbnail": True,
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "m4a",
                    "preferredquality": "192",
                },
                {"key": "FFmpegMetadata"},
                {"key": "EmbedThumbnail"},
            ],
            "quiet": True,
            "no_warnings": True,
            "progress_hooks": [progress_hook],
        }

        downloaded_file = None
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(target_url, download=True)
                title = info.get("title", task["title"])
                task["title"] = title
                # Find output filename
                expected_fn = ydl.prepare_filename(info)
                base, _ = os.path.splitext(expected_fn)
                m4a_path = base + ".m4a"
                if os.path.exists(m4a_path):
                    downloaded_file = m4a_path
                elif os.path.exists(expected_fn):
                    downloaded_file = expected_fn

            with self.lock:
                task["state"] = STATE_DOWNLOADED
                task["progress"] = 100.0
                task["path"] = downloaded_file or ""

            # Fetch synced lyrics alongside the downloaded audio
            if downloaded_file:
                self._fetch_lyrics_for_file(downloaded_file, task["title"], task["artist"], video_id)

            # Trigger library re-index so the new track appears in Nutsty 0ms
            self._trigger_library_rescan()
            return True

        except Exception as e:
            err_msg = str(e)
            with self.lock:
                task["state"] = STATE_FAILED
                task["error"] = err_msg
            return False

    def _fetch_lyrics_for_file(self, audio_path, title, artist, video_id):
        try:
            base, _ = os.path.splitext(audio_path)
            target_lrc = base + ".lrc"
            if os.path.exists(target_lrc):
                return

            lyrics_helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), "lyrics_helper.py")
            if os.path.exists(lyrics_helper):
                # Search lyrics and parse
                cmd = ["python3", lyrics_helper, title, artist or "", video_id or ""]
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                if res.returncode == 0 and res.stdout.strip():
                    lines = json.loads(res.stdout)
                    if lines and isinstance(lines, list):
                        # Convert back to LRC format
                        lrc_lines = []
                        for item in lines:
                            t = float(item.get("time", 0.0))
                            txt = item.get("text", "")
                            mins = int(t // 60)
                            secs = t % 60
                            lrc_lines.append(f"[{mins:02d}:{secs:05.2f}]{txt}")
                        with open(target_lrc, "w", encoding="utf-8") as f:
                            f.write("\n".join(lrc_lines))
        except Exception:
            pass

    def _trigger_library_rescan(self):
        try:
            lib_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "library.py")
            if os.path.exists(lib_script):
                subprocess.run(["python3", lib_script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        except Exception:
            pass

def run_daemon():
    """Run resident download daemon listening on Unix domain socket & printing stdout events"""
    if os.path.exists(SOCKET_PATH):
        try:
            os.remove(SOCKET_PATH)
        except Exception:
            pass

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(10)
    server.setblocking(False)

    manager = DownloadManager()
    manager.emit_event({"event": "daemon_ready", "socket": SOCKET_PATH})

    read_sockets = [server]

    try:
        while True:
            readable, _, _ = select.select(read_sockets, [], [], 0.5)
            for s in readable:
                if s is server:
                    client_socket, _ = server.accept()
                    client_socket.setblocking(False)
                    read_sockets.append(client_socket)
                    with manager.lock:
                        manager.clients.add(client_socket)
                    # Send immediate status dump to new client
                    with manager.lock:
                        status_dump = {
                            "event": "status_dump",
                            "tasks": manager.tasks,
                            "queue_len": len(manager.queue),
                            "active_count": len(manager.active_downloads) + len(manager.queue),
                            "batch_total": manager.batch_total,
                            "batch_completed": manager.batch_completed
                        }
                    try:
                        client_socket.sendall((json.dumps(status_dump) + "\n").encode("utf-8"))
                    except Exception:
                        pass
                else:
                    try:
                        data = s.recv(4096)
                        if data:
                            lines = data.decode("utf-8").splitlines()
                            for line in lines:
                                if not line.strip():
                                    continue
                                try:
                                    cmd = json.loads(line)
                                    action = cmd.get("action")
                                    if action == "enqueue":
                                        manager.enqueue(
                                            cmd.get("videoId"),
                                            cmd.get("title", "Track"),
                                            cmd.get("artist", "Artist"),
                                            cmd.get("thumbnail", "")
                                        )
                                    elif action == "cancel":
                                        manager.cancel(cmd.get("videoId"))
                                    elif action == "clear_completed":
                                        manager.clear_completed()
                                    elif action == "status":
                                        with manager.lock:
                                            resp = {
                                                "event": "status_dump",
                                                "tasks": manager.tasks,
                                                "queue_len": len(manager.queue),
                                                "active_count": len(manager.active_downloads) + len(manager.queue)
                                            }
                                        s.sendall((json.dumps(resp) + "\n").encode("utf-8"))
                                except Exception:
                                    pass
                        else:
                            # Client disconnected
                            read_sockets.remove(s)
                            with manager.lock:
                                manager.clients.discard(s)
                            s.close()
                    except Exception:
                        if s in read_sockets:
                            read_sockets.remove(s)
                        with manager.lock:
                            manager.clients.discard(s)
                        s.close()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
        if os.path.exists(SOCKET_PATH):
            try:
                os.remove(SOCKET_PATH)
            except Exception:
                pass

def client_enqueue(video_id, title="Track", artist="Artist", thumbnail=""):
    """CLI client helper to enqueue a download"""
    def is_socket_alive():
        if not os.path.exists(SOCKET_PATH):
            return False
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(SOCKET_PATH)
            s.close()
            return True
        except Exception:
            return False

    if not is_socket_alive():
        script = os.path.abspath(__file__)
        subprocess.Popen(
            ["python3", script, "daemon"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True
        )
        for _ in range(30):
            time.sleep(0.1)
            if is_socket_alive():
                break

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        payload = {
            "action": "enqueue",
            "videoId": video_id,
            "title": title,
            "artist": artist,
            "thumbnail": thumbnail
        }
        s.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        s.close()
        print(json.dumps({"success": True, "videoId": video_id, "title": title}))
        return True
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        return False

def client_clear_completed():
    """CLI client helper to clear completed downloads"""
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            if "tasks" in data:
                data["tasks"] = {vid: t for vid, t in data["tasks"].items() if t.get("state") in (STATE_PREPARING, STATE_DOWNLOADING)}
            with open(STATUS_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    if os.path.exists(SOCKET_PATH):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(SOCKET_PATH)
            payload = {"action": "clear_completed"}
            s.sendall((json.dumps(payload) + "\n").encode("utf-8"))
            s.close()
            print(json.dumps({"success": True, "action": "clear_completed"}))
            return True
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
            return False
    return True

def get_status():
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, "r", encoding="utf-8") as f:
                print(f.read())
                return
        except Exception:
            pass
    print(json.dumps({"active_count": 0, "queue_len": 0, "tasks": {}}))

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "daemon":
            run_daemon()
        elif cmd in ("add", "enqueue"):
            vid = sys.argv[2] if len(sys.argv) > 2 else ""
            t = sys.argv[3] if len(sys.argv) > 3 else "Track"
            a = sys.argv[4] if len(sys.argv) > 4 else "Artist"
            thumb = sys.argv[5] if len(sys.argv) > 5 else ""
            client_enqueue(vid, t, a, thumb)
        elif cmd in ("clear", "clear_completed"):
            client_clear_completed()
        elif cmd == "status":
            get_status()
        elif cmd == "test_download":
            vid = sys.argv[2] if len(sys.argv) > 2 else "dQw4w9WgXcQ"
            mgr = DownloadManager()
            mgr.enqueue(vid, "Test Track", "Test Artist")
            time.sleep(5)
        else:
            print("Usage: download_manager.py [daemon | add <videoId> [title] [artist] [thumb] | status]")
    else:
        run_daemon()
