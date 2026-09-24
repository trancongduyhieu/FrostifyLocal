#!/usr/bin/env python3
"""
Nutsty Custom Playlist Manager
Manages user custom playlists saved in ~/.config/noctalia/custom_playlists.json
"""
import os
import sys
import json
import time

try:
    from . import platform_compat as pc
except (ImportError, ValueError):
    import platform_compat as pc

PROFILE_NAME = os.getenv("NUTSTY_PROFILE", "").strip().lower()
PROFILE_SUFFIX = f"_{PROFILE_NAME}" if PROFILE_NAME else ""

CONFIG_DIR = pc.get_config_dir()
PLAYLISTS_FILE = os.path.join(CONFIG_DIR, f"custom_playlists{PROFILE_SUFFIX}.json")

def load_playlists():
    p = PLAYLISTS_FILE
    if not os.path.exists(p) and not PROFILE_SUFFIX:
        p = os.path.join(CONFIG_DIR, "custom_playlists.json")
    if not os.path.exists(p):
        return []
    try:
        with open(p, "r", encoding="utf-8") as f:
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

def get_track_unique_key(track):
    if not track:
        return ""
    if isinstance(track, str):
        if track.startswith("ytdl://"):
            return f"yt_{track.replace('ytdl://', '')}"
        return f"local_{track}"
    if isinstance(track, dict):
        if track.get("videoId"):
            return f"yt_{track['videoId']}"
        if track.get("path"):
            p = track["path"]
            if p.startswith("ytdl://"):
                return f"yt_{p.replace('ytdl://', '')}"
            return f"local_{p}"
        if track.get("id"):
            return f"id_{track['id']}"
        return track.get("title", "")
    return str(track)

def create_playlist(title, initial_tracks=None, description="", custom_cover=""):
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
        "description": description.strip() if description else "",
        "customCover": custom_cover.strip() if custom_cover else "",
        "isLocal": True,
        "isCustom": True,
        "createdAt": int(time.time()),
        "tracks": tracks,
        "trackCount": len(tracks),
        "image": custom_cover if custom_cover else (tracks[0].get("image", "") if tracks else "")
    }
    playlists.append(new_pl)
    save_playlists(playlists)
    return new_pl

def rename_playlist(pl_id, new_title, new_description=None):
    playlists = load_playlists()
    target = None
    for p in playlists:
        if p.get("id") == pl_id:
            target = p
            break
    if not target:
        return {"success": False, "error": "Playlist not found"}

    if new_title and new_title.strip():
        target["title"] = new_title.strip()
        target["name"] = new_title.strip()
    if new_description is not None:
        target["description"] = new_description.strip()
    save_playlists(playlists)
    return {"success": True, "playlist": target}

def set_playlist_cover(pl_id, image_path):
    playlists = load_playlists()
    target = None
    for p in playlists:
        if p.get("id") == pl_id:
            target = p
            break
    if not target:
        return {"success": False, "error": "Playlist not found"}

    target["customCover"] = image_path.strip() if image_path else ""
    target["image"] = target["customCover"] or (target["tracks"][0].get("image", "") if target.get("tracks") else "")
    save_playlists(playlists)
    return {"success": True, "playlist": target}

def reorder_tracks(pl_id, from_index, to_index):
    playlists = load_playlists()
    target = None
    for p in playlists:
        if p.get("id") == pl_id:
            target = p
            break
    if not target:
        return {"success": False, "error": "Playlist not found"}

    tracks = target.get("tracks", [])
    if 0 <= from_index < len(tracks) and 0 <= to_index < len(tracks):
        item = tracks.pop(from_index)
        tracks.insert(to_index, item)
        target["tracks"] = tracks
        if not target.get("customCover") and tracks:
            target["image"] = tracks[0].get("image", "")
        save_playlists(playlists)
        return {"success": True, "playlist": target}
    return {"success": False, "error": "Invalid indices"}

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

    existing_keys = set(get_track_unique_key(t) for t in target.get("tracks", []) if get_track_unique_key(t))
    added = 0
    for t in new_tracks:
        k = get_track_unique_key(t)
        if k and k not in existing_keys:
            target["tracks"].append(t)
            existing_keys.add(k)
            added += 1

    target["trackCount"] = len(target["tracks"])
    if not target.get("customCover") and not target.get("image") and target["tracks"]:
        target["image"] = target["tracks"][0].get("image", "")

    save_playlists(playlists)
    return {"success": True, "added": added, "total": len(target["tracks"])}

def remove_track_from_playlist(pl_id, track_identifier):
    playlists = load_playlists()
    target = None
    for p in playlists:
        if p.get("id") == pl_id:
            target = p
            break
    if not target:
        return {"success": False, "error": "Playlist not found"}

    target_key = get_track_unique_key(track_identifier)
    target_str = str(track_identifier) if not isinstance(track_identifier, dict) else ""

    target["tracks"] = [
        t for t in target.get("tracks", [])
        if get_track_unique_key(t) != target_key
        and (not target_str or (t.get("path") != target_str and t.get("videoId") != target_str))
    ]
    target["trackCount"] = len(target["tracks"])
    if not target.get("customCover"):
        target["image"] = target["tracks"][0].get("image", "") if target["tracks"] else ""
    save_playlists(playlists)
    return {"success": True, "total": len(target["tracks"])}

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        print(json.dumps(load_playlists(), ensure_ascii=False))
    elif cmd == "create" and len(sys.argv) > 2:
        title = sys.argv[2]
        trks = sys.argv[3] if len(sys.argv) > 3 else None
        desc = sys.argv[4] if len(sys.argv) > 4 else ""
        cover = sys.argv[5] if len(sys.argv) > 5 else ""
        print(json.dumps(create_playlist(title, trks, desc, cover), ensure_ascii=False))
    elif cmd == "rename" and len(sys.argv) > 3:
        pl_id = sys.argv[2]
        new_title = sys.argv[3]
        desc = sys.argv[4] if len(sys.argv) > 4 else None
        print(json.dumps(rename_playlist(pl_id, new_title, desc), ensure_ascii=False))
    elif cmd == "set_cover" and len(sys.argv) > 3:
        pl_id = sys.argv[2]
        cover_path = sys.argv[3]
        print(json.dumps(set_playlist_cover(pl_id, cover_path), ensure_ascii=False))
    elif cmd == "reorder" and len(sys.argv) > 4:
        pl_id = sys.argv[2]
        f_idx = int(sys.argv[3])
        t_idx = int(sys.argv[4])
        print(json.dumps(reorder_tracks(pl_id, f_idx, t_idx), ensure_ascii=False))
    elif cmd == "delete" and len(sys.argv) > 2:
        print(json.dumps(delete_playlist(sys.argv[2]), ensure_ascii=False))
    elif cmd == "add" and len(sys.argv) > 3:
        print(json.dumps(add_tracks_to_playlist(sys.argv[2], sys.argv[3]), ensure_ascii=False))
    elif cmd == "remove" and len(sys.argv) > 3:
        print(json.dumps(remove_track_from_playlist(sys.argv[2], sys.argv[3]), ensure_ascii=False))
    else:
        print(json.dumps(load_playlists(), ensure_ascii=False))

if __name__ == "__main__":
    main()
