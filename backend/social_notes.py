#!/usr/bin/env python3
"""
Nutsty Friends Pulse & 24h Music Capsule Backend Client
Manages friends list, posts 24h ephemeral notes, and fetches friends' notes.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Dict, Any, List, Optional

# Default Cloudflare Worker URL (Defaults to local daemon 127.0.0.1:17890, or Cloudflare Worker via NUTSTY_WORKER_URL)
DEFAULT_WORKER_URL = os.getenv("NUTSTY_WORKER_URL", "http://127.0.0.1:17890")

def get_profile_suffix() -> str:
    """Hỗ trợ đa profile (NUTSTY_PROFILE) để kiểm thử song song nhiều cửa sổ trên 1 máy."""
    profile = os.getenv("NUTSTY_PROFILE", "").strip().lower()
    return f"_{profile}" if profile else ""

def get_config_dir() -> Path:
    """Xác định thư mục cấu hình chuẩn theo HĐH."""
    if sys.platform == "win32":
        app_data = os.getenv("APPDATA") or str(Path.home() / "AppData" / "Roaming")
        cfg_dir = Path(app_data) / "Nutsty"
    else:
        xdg_config = os.getenv("XDG_CONFIG_HOME") or str(Path.home() / ".config")
        cfg_dir = Path(xdg_config) / "noctalia"
    cfg_dir.mkdir(parents=True, exist_ok=True)
    return cfg_dir

def get_friends_file() -> Path:
    suffix = get_profile_suffix()
    return get_config_dir() / f"nutsty_friends{suffix}.json"

def get_cache_file() -> Path:
    suffix = get_profile_suffix()
    return get_config_dir() / f"nutsty_notes_cache{suffix}.json"

def get_current_user() -> Dict[str, str]:
    """Lấy thông tin tài khoản hiện tại từ settings hoặc profile môi trường."""
    profile = os.getenv("NUTSTY_PROFILE", "").strip().lower()
    suffix = get_profile_suffix()

    # 1. Đọc từ ytmusic_auth{suffix}.json nếu có để lấy info chính chủ
    auth_file = get_config_dir() / f"ytmusic_auth{suffix}.json"
    if auth_file.exists():
        try:
            from ytmusicapi import YTMusic
            yt = YTMusic(str(auth_file))
            user = yt.get_account_info()
            name = user.get("accountName") or user.get("name") or ""
            thumbs = user.get("thumbnails", [])
            thumb = user.get("accountPhotoUrl") or (thumbs[-1].get("url") if thumbs else "")
            email = user.get("email") or user.get("channelHandle") or ""
            if not email and name:
                import re
                safe_name = re.sub(r'[^a-zA-Z0-9]', '', name).lower()
                email = f"{safe_name or (profile or 'user')}@gmail.com"
            if email or name:
                return {"email": (email or f"{profile or 'user'}@gmail.com").strip().lower(), "name": name or "Me", "avatar": thumb}
        except Exception:
            pass

    # 2. Đọc từ nutsty_settings{suffix}.json
    settings_file = get_config_dir() / f"nutsty_settings{suffix}.json"
    if not settings_file.exists() and not suffix:
        settings_file = get_config_dir() / "nutsty_settings.json"
    if settings_file.exists():
        try:
            with open(settings_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                email = data.get("google_email") or data.get("auth_account_email", "")
                name = data.get("google_name") or data.get("auth_account_name", "")
                avatar = data.get("google_avatar") or data.get("auth_account_thumb", "")
                if email:
                    return {"email": email.strip().lower(), "name": name or "Me", "avatar": avatar}
        except Exception:
            pass

    if profile == "friend":
        return {
            "email": "friend@gmail.com",
            "name": "Bạn Thân",
            "avatar": ""
        }
    elif profile == "beta":
        return {
            "email": "beta@gmail.com",
            "name": "Minh Anh",
            "avatar": ""
        }
    elif profile:
        return {
            "email": f"{profile}@gmail.com",
            "name": profile.capitalize(),
            "avatar": ""
        }

    return {
        "email": "me@gmail.com",
        "name": "Tôi",
        "avatar": ""
    }

def load_friends() -> List[str]:
    fpath = get_friends_file()
    if fpath.exists():
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return [str(e).strip().lower() for e in data if str(e).strip()]
        except Exception:
            pass

    # Danh sách mặc định để test nếu chưa có
    profile = os.getenv("NUTSTY_PROFILE", "").strip().lower()
    if profile == "friend":
        return ["me@gmail.com", "apple@gmail.com"]
    return ["friend@gmail.com", "beta@gmail.com"]

def save_friends(friends_list: List[str]) -> bool:
    clean = sorted(list(set(e.strip().lower() for e in friends_list if e.strip())))
    fpath = get_friends_file()
    try:
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(clean, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving friends: {e}", file=sys.stderr)
        return False

def add_friend(email: str) -> bool:
    friends = load_friends()
    clean_email = email.strip().lower()
    if clean_email and clean_email not in friends:
        friends.append(clean_email)
        return save_friends(friends)
    return True

def remove_friend(email: str) -> bool:
    friends = load_friends()
    clean_email = email.strip().lower()
    if clean_email in friends:
        friends.remove(clean_email)
        return save_friends(friends)
    return True

def publish_note(note_text: str, track: Optional[Dict[str, Any]] = None, worker_url: Optional[str] = None) -> Dict[str, Any]:
    """Đăng ghi chú 24h kèm bài hát lên server."""
    user = get_current_user()
    url = (worker_url or DEFAULT_WORKER_URL).rstrip("/") + "/api/notes"

    # Đính kèm now_playing nếu bài hát đang phát trong MPV
    now_playing = None
    suffix = get_profile_suffix()
    cur_track_file = Path(f"/tmp/nutsty_current_track{suffix}.json")
    if cur_track_file.exists():
        try:
            with open(cur_track_file, "r", encoding="utf-8") as f:
                cur_meta = json.load(f)
                if cur_meta.get("title"):
                    now_playing = {
                        "title": cur_meta.get("title", ""),
                        "artist": cur_meta.get("artist", ""),
                        "cover": cur_meta.get("artUrl", ""),
                        "path": cur_meta.get("path", "")
                    }
        except Exception:
            pass

    payload = {
        "user_email": user["email"],
        "user_name": user["name"],
        "avatar_url": user["avatar"],
        "note_text": note_text[:80],
        "track": track,
        "now_playing": now_playing
    }

    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "User-Agent": "Nutsty-Desktop/1.0"}
        )
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            # Cập nhật cache local
            cache_file = get_cache_file()
            cache_data = {}
            if cache_file.exists():
                try:
                    with open(cache_file, "r", encoding="utf-8") as cf:
                        cache_data = json.load(cf)
                except Exception:
                    pass
            cache_data["my_latest_note"] = data.get("note", payload)
            with open(cache_file, "w", encoding="utf-8") as cf:
                json.dump(cache_data, cf, indent=2, ensure_ascii=False)
            return data
    except Exception as e:
        # Fallback offline cache
        cache_file = get_cache_file()
        offline_note = {
            "user_email": user["email"],
            "user_name": user["name"],
            "avatar_url": user["avatar"],
            "note_text": note_text[:80],
            "track": track,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "expires_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 86400)),
            "offline_pending": True
        }
        try:
            cache_data = {}
            if cache_file.exists():
                with open(cache_file, "r", encoding="utf-8") as cf:
                    cache_data = json.load(cf)
            cache_data["my_latest_note"] = offline_note
            with open(cache_file, "w", encoding="utf-8") as cf:
                json.dump(cache_data, cf, indent=2, ensure_ascii=False)
        except Exception:
            pass
        return {"success": False, "error": str(e), "note": offline_note}

def delete_note(worker_url: Optional[str] = None) -> Dict[str, Any]:
    """Xóa ghi chú 24h của bản thân khỏi cache local và server."""
    user = get_current_user()
    cache_file = get_cache_file()
    if cache_file.exists():
        try:
            with open(cache_file, "r", encoding="utf-8") as cf:
                cache_data = json.load(cf)
            cache_data["my_latest_note"] = None
            with open(cache_file, "w", encoding="utf-8") as cf:
                json.dump(cache_data, cf, indent=2, ensure_ascii=False)
        except Exception:
            pass

    url = (worker_url or DEFAULT_WORKER_URL).rstrip("/") + "/api/notes/delete"
    try:
        payload = {"user_email": user["email"]}
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json", "User-Agent": "Nutsty-Desktop/1.0"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return {"success": True, "offline": True, "error": str(e)}

def fetch_notes(worker_url: Optional[str] = None) -> Dict[str, Any]:
    """Lấy danh sách ghi chú 24h của bạn bè và ghi chú mới nhất của bản thân."""
    friends = load_friends()
    user = get_current_user()
    user_email = user.get("email", "").strip().lower()

    url = (worker_url or DEFAULT_WORKER_URL).rstrip("/") + "/api/notes?friends=" + urllib.parse.quote(",".join(friends))
    if user_email:
        url += "&user_email=" + urllib.parse.quote(user_email)

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Nutsty-Desktop/1.0"})
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            notes = data.get("notes", [])
            my_note = data.get("my_note", None)
            # Lưu cache
            cache_file = get_cache_file()
            cache_data = {}
            if cache_file.exists():
                try:
                    with open(cache_file, "r", encoding="utf-8") as cf:
                        cache_data = json.load(cf)
                except Exception:
                    pass
            cache_data["friends_notes"] = notes
            cache_data["my_latest_note"] = my_note
            cache_data["last_sync"] = time.time()
            with open(cache_file, "w", encoding="utf-8") as cf:
                json.dump(cache_data, cf, indent=2, ensure_ascii=False)
            return {"notes": notes, "my_note": my_note}
    except Exception:
        # Đọc từ cache
        cache_file = get_cache_file()
        if cache_file.exists():
            try:
                with open(cache_file, "r", encoding="utf-8") as cf:
                    cache_data = json.load(cf)
                    return {
                        "notes": cache_data.get("friends_notes", []),
                        "my_note": cache_data.get("my_latest_note")
                    }
            except Exception:
                pass
        return {"notes": [], "my_note": None}

def fetch_friends_notes(worker_url: Optional[str] = None) -> List[Dict[str, Any]]:
    """Lấy danh sách ghi chú 24h của tất cả bạn bè (backward compatibility)."""
    return fetch_notes(worker_url).get("notes", [])

def send_social_event(event_type: str, to_email: str, worker_url: Optional[str] = None) -> Dict[str, Any]:
    url = (worker_url or DEFAULT_WORKER_URL).rstrip("/") + "/api/notes/events"
    user = get_current_user()
    my_email = user.get("email", "")
    my_name = user.get("name", "")
    payload = {
        "event": event_type,
        "from_email": my_email,
        "from_name": my_name,
        "to_email": to_email
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "User-Agent": "Nutsty-Desktop/1.0"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return {"success": False, "error": str(e)}

def fetch_social_events(worker_url: Optional[str] = None) -> List[Dict[str, Any]]:
    user = get_current_user()
    my_email = user.get("email", "")
    url = (worker_url or DEFAULT_WORKER_URL).rstrip("/") + "/api/notes/events?user_email=" + urllib.parse.quote(my_email)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Nutsty-Desktop/1.0"})
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("events", [])
    except Exception:
        return []

def main():
    if len(sys.argv) < 2:
        print("Usage: social_notes.py [get | post <text> [track_json] | add_friend <email> | list_friends | send_event <type> <to_email> | get_events]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "get":
        notes_data = fetch_notes()
        print(json.dumps(notes_data, ensure_ascii=False))
    elif cmd == "post":
        text = sys.argv[2] if len(sys.argv) > 2 else "Chilling with Nutsty"
        track = None
        if len(sys.argv) > 3:
            try:
                track = json.loads(sys.argv[3])
            except Exception:
                pass
        res = publish_note(text, track)
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "add_friend":
        if len(sys.argv) > 2:
            ok = add_friend(sys.argv[2])
            print(json.dumps({"success": ok, "friends": load_friends()}, ensure_ascii=False))
    elif cmd == "list_friends":
        print(json.dumps(load_friends(), ensure_ascii=False))
    elif cmd == "send_event":
        ev_type = sys.argv[2] if len(sys.argv) > 2 else "leave"
        to_email = sys.argv[3] if len(sys.argv) > 3 else ""
        res = send_social_event(ev_type, to_email)
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "delete":
        res = delete_note()
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "get_events":
        events = fetch_social_events()
        print(json.dumps(events, ensure_ascii=False))
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
