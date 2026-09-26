#!/usr/bin/env python3
"""
Nutsty Friends Pulse & 24h Music Capsule Backend Client (Forwarding Shim)
Delegates directly to SocialRelayCore (Deep Module) for unified caching,
identity resolution (SSOT #2), and event distribution.
"""

import os
import sys
import json
import time
from pathlib import Path
from typing import Dict, Any, List, Optional

try:
    from . import platform_compat as pc
    from .social_relay_core import SOCIAL_RELAY_CORE
except (ImportError, ValueError):
    import platform_compat as pc
    from social_relay_core import SOCIAL_RELAY_CORE

pc.configure_windows_ssl()


def get_profile_suffix() -> str:
    return pc.get_profile_suffix()


def get_config_dir() -> Path:
    return pc.get_config_path()


def get_friends_file() -> Path:
    return pc.get_friends_file(get_profile_suffix())


def get_cache_file() -> Path:
    return pc.get_notes_cache_file(get_profile_suffix())


def get_current_user() -> Dict[str, str]:
    """Returns caller identity from SocialRelayCore (SSOT #2)."""
    ident = SOCIAL_RELAY_CORE.get_caller_identity(os.getenv("NUTSTY_PROFILE", ""))
    return {
        "email": (ident.get("tag") or ident.get("email") or "me@gmail.com").strip().lower(),
        "tag": ident.get("tag", ""),
        "user_id": ident.get("user_id", ""),
        "name": ident.get("username", "Nutsty User"),
        "avatar": ident.get("avatar_url", ""),
    }


def load_friends() -> List[str]:
    res = SOCIAL_RELAY_CORE.get_friends(os.getenv("NUTSTY_PROFILE", ""))
    friends = res.get("friends", [])
    return [str(f.get("tag") or f.get("email") or f.get("user_id")).lower() for f in friends if f]


def save_friends(friends_list: List[str]) -> bool:
    fpath = get_friends_file()
    try:
        clean = sorted(list(set(e.strip().lower() for e in friends_list if e.strip())))
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(clean, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"Error saving friends: {e}", file=sys.stderr)
        return False


def add_friend(target_identifier: str) -> bool:
    res = SOCIAL_RELAY_CORE.add_friend(target_identifier, os.getenv("NUTSTY_PROFILE", ""))
    return bool(res.get("success", False))


def remove_friend(target_identifier: str) -> bool:
    res = SOCIAL_RELAY_CORE.remove_friend(target_identifier, os.getenv("NUTSTY_PROFILE", ""))
    return bool(res.get("success", False))


def publish_note(note_text: str, track: Optional[Dict[str, Any]] = None, worker_url: Optional[str] = None) -> Dict[str, Any]:
    return SOCIAL_RELAY_CORE.publish_note(note_text, track, os.getenv("NUTSTY_PROFILE", ""))


def delete_note(worker_url: Optional[str] = None) -> Dict[str, Any]:
    return SOCIAL_RELAY_CORE.delete_note(os.getenv("NUTSTY_PROFILE", ""))


def fetch_notes(worker_url: Optional[str] = None) -> Dict[str, Any]:
    res = SOCIAL_RELAY_CORE.get_feed(os.getenv("NUTSTY_PROFILE", ""))
    return {
        "notes": res.get("notes", []),
        "my_note": res.get("my_note"),
    }


def fetch_friends_notes(worker_url: Optional[str] = None) -> List[Dict[str, Any]]:
    return fetch_notes(worker_url).get("notes", [])


def send_social_event(event_type: str, to_identifier: str, extra_data: Optional[Dict[str, Any]] = None, worker_url: Optional[str] = None) -> Dict[str, Any]:
    return SOCIAL_RELAY_CORE.send_event(event_type, to_identifier, extra_data, os.getenv("NUTSTY_PROFILE", ""))


def fetch_social_events(worker_url: Optional[str] = None) -> List[Dict[str, Any]]:
    return SOCIAL_RELAY_CORE.get_events(os.getenv("NUTSTY_PROFILE", ""))


def update_now_playing(now_playing_data: Optional[Dict[str, Any]] = None, worker_url: Optional[str] = None) -> Dict[str, Any]:
    return SOCIAL_RELAY_CORE.update_presence(now_playing_data, os.getenv("NUTSTY_PROFILE", ""))


def set_offline(worker_url: Optional[str] = None) -> Dict[str, Any]:
    return SOCIAL_RELAY_CORE.set_offline(os.getenv("NUTSTY_PROFILE", ""))


def handle_cli(args):
    execute_command(list(args))


def main():
    execute_command(sys.argv[1:])


def execute_command(args):
    if len(args) < 1:
        print("Usage: social_notes.py [get | post <text> [track_json] | now_playing [track_json] | add_friend <email> | list_friends | send_event <type> <to_email> | get_events | offline]")
        return

    cmd = args[0].lower()
    if cmd == "get":
        notes_data = fetch_notes()
        print(json.dumps(notes_data, ensure_ascii=False))
    elif cmd == "post":
        text = args[1] if len(args) > 1 else "Chilling with Nutsty"
        track = None
        if len(args) > 2:
            try:
                track = json.loads(args[2])
            except Exception:
                pass
        res = publish_note(text, track)
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "now_playing":
        data = None
        if len(args) > 1 and args[1].strip():
            try:
                data = json.loads(args[1])
            except Exception:
                data = {"title": args[1], "is_playing": True}
        res = update_now_playing(data)
        print(json.dumps(res, ensure_ascii=False))
    elif cmd in ("offline", "leave"):
        res = set_offline()
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "add_friend":
        if len(args) > 1:
            ok = add_friend(args[1])
            print(json.dumps({"success": ok, "friends": load_friends()}, ensure_ascii=False))
    elif cmd == "list_friends":
        print(json.dumps(load_friends(), ensure_ascii=False))
    elif cmd == "send_event":
        ev_type = args[1] if len(args) > 1 else "leave"
        to_email = args[2] if len(args) > 2 else ""
        extra = None
        if len(args) > 3 and args[3].strip():
            try:
                extra = json.loads(args[3])
            except Exception:
                extra = {"text": args[3]}
        res = send_social_event(ev_type, to_email, extra)
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "delete":
        res = delete_note()
        print(json.dumps(res, ensure_ascii=False))
    elif cmd == "get_events":
        events = fetch_social_events()
        print(json.dumps(events, ensure_ascii=False))
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)


if __name__ == "__main__":
    main()
