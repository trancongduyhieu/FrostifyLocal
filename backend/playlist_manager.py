#!/usr/bin/env python3
"""
Nutsty Custom Playlist Manager
Manages user custom playlists saved in ~/.config/noctalia/custom_playlists.json
"""
import os
import sys
import json
import time

CONFIG_DIR = os.path.expanduser("~/.config/noctalia")
PLAYLISTS_FILE = os.path.join(CONFIG_DIR, "custom_playlists.json")

def load_playlists():
    if not os.path.exists(PLAYLISTS_FILE):
        return []
    try:
        with open(PLAYLISTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []

def save_playlists(playlists):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    tmp = PLAYLISTS_FILE + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(playlists, f, ensure_ascii=False, indent=2)
        os.replace(tmp, PLAYLISTS_FILE)
        return True
    except Exception as e:
        sys.stderr.write(f"Error saving custom playlists: {e}\n")
        return False

def create_playlist(title, initial_tracks=None):
    if not title or not title.strip():
        title = "New Playlist"
    playlists = load_playlists()
    pl_id = f"custom_pl_{int(time.time() * 1000)}"
    tracks = []
    if initial_tracks:
        if isinstance(initial_tracks, str):
            try:
                tracks = json.loads(initial_tracks)
            except Exception:
                tracks = []
        elif isinstance(initial_tracks, list):
            tracks = initial_tracks

    new_pl = {
        "id": pl_id,
        "playlistId": pl_id,
        "title": title.strip(),
        "name": title.strip(),
        "isLocal": True,
        "isCustom": True,
        "createdAt": int(time.time()),
        "tracks": tracks,
        "trackCount": len(tracks),
        "image": tracks[0].get("image", "") if tracks else ""
    }
    playlists.append(new_pl)
    save_playlists(playlists)
    return new_pl

def delete_playlist(pl_id):
    playlists = load_playlists()
    filtered = [p for p in playlists if p.get("id") != pl_id]
    save_playlists(filtered)
    return {"success": True, "remaining": len(filtered)}

def add_tracks_to_playlist(pl_id, new_tracks):
    playlists = load_playlists()
    target = None
    for p in playlists:
        if p.get("id") == pl_id:
            target = p
            break
    if not target:
        return {"success": False, "error": "Playlist not found"}

    if isinstance(new_tracks, str):
        try:
            new_tracks = json.loads(new_tracks)
        except Exception:
            new_tracks = []

    existing_paths = set(t.get("path") for t in target.get("tracks", []) if t.get("path"))
    added = 0
    for t in new_tracks:
        p = t.get("path")
        if p and p not in existing_paths:
            target["tracks"].append(t)
            existing_paths.add(p)
            added += 1

    target["trackCount"] = len(target["tracks"])
    if not target.get("image") and target["tracks"]:
        target["image"] = target["tracks"][0].get("image", "")

    save_playlists(playlists)
    return {"success": True, "added": added, "total": len(target["tracks"])}

def remove_track_from_playlist(pl_id, track_path):
    playlists = load_playlists()
    target = None
    for p in playlists:
        if p.get("id") == pl_id:
            target = p
            break
    if not target:
        return {"success": False, "error": "Playlist not found"}

    target["tracks"] = [t for t in target.get("tracks", []) if t.get("path") != track_path]
    target["trackCount"] = len(target["tracks"])
    target["image"] = target["tracks"][0].get("image", "") if target["tracks"] else ""
    save_playlists(playlists)
    return {"success": True, "total": len(target["tracks"])}

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        print(json.dumps(load_playlists(), ensure_ascii=False))
    elif cmd == "create" and len(sys.argv) > 2:
        title = sys.argv[2]
        trks = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(create_playlist(title, trks), ensure_ascii=False))
    elif cmd == "delete" and len(sys.argv) > 2:
        print(json.dumps(delete_playlist(sys.argv[2]), ensure_ascii=False))
    elif cmd == "add" and len(sys.argv) > 3:
        print(json.dumps(add_tracks_to_playlist(sys.argv[2], sys.argv[3]), ensure_ascii=False))
    elif cmd == "remove" and len(sys.argv) > 3:
        print(json.dumps(remove_track_from_playlist(sys.argv[2], sys.argv[3]), ensure_ascii=False))
    else:
        print(json.dumps(load_playlists(), ensure_ascii=False))
