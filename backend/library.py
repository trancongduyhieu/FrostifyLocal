#!/usr/bin/env python3
"""
Frostify Local Library Scanner
Scans tracks from SimpMusic and phone downloads into library.json
"""
import os
import sys
import json
import subprocess
import glob

HOME = os.path.expanduser("~")
SIMP_DIR = os.path.join(HOME, "Music", "SimpMusic", "Tracks")
DOWNLOADS_DIR = os.path.join(HOME, "Music", "Downloads_Phone")
OUT_JSON = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "library.json")

def get_duration(file_path):
    try:
        cmd = [
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", file_path
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
        val = float(res.stdout.strip())
        m = int(val // 60)
        s = int(val % 60)
        return f"{m}:{s:02d}", val
    except Exception:
        return "--:--", 0.0

import sqlite3
import hashlib

THUMB_DIR = os.path.join(HOME, ".cache", "frostify", "thumbnails")
os.makedirs(THUMB_DIR, exist_ok=True)

def extract_embedded_cover(file_path):
    """Extract embedded album art from audio file using ffmpeg and cache it."""
    if not file_path or not os.path.exists(file_path):
        return ""
    
    # Check if a sibling image exists (e.g. song.jpg, song.png, cover.jpg)
    base_no_ext = os.path.splitext(file_path)[0]
    for ext in (".jpg", ".jpeg", ".png", ".webp"):
        sibling = base_no_ext + ext
        if os.path.exists(sibling) and os.path.getsize(sibling) > 1000:
            return sibling

    # Create deterministic hash path in ~/.cache/frostify/thumbnails/
    f_hash = hashlib.md5(file_path.encode("utf-8")).hexdigest()
    out_thumb = os.path.join(THUMB_DIR, f"{f_hash}.jpg")

    if os.path.exists(out_thumb) and os.path.getsize(out_thumb) > 1000:
        return out_thumb

    try:
        cmd = ["ffmpeg", "-y", "-i", file_path, "-an", "-frames:v", "1", "-update", "1", out_thumb]
        res = subprocess.run(cmd, capture_output=True, timeout=3)
        if res.returncode == 0 and os.path.exists(out_thumb) and os.path.getsize(out_thumb) > 1000:
            return out_thumb
    except Exception:
        pass

    return ""

def scan_library():
    tracks = []

    # Build mapping from SimpMusic Database
    db_path = os.path.join(HOME, "Music", "SimpMusic", "extracted", "Music Database")
    title_artist_map = {}
    title_map = {}
    import re
    if os.path.exists(db_path):
        try:
            conn = sqlite3.connect(db_path)
            c = conn.cursor()
            rows = c.execute("SELECT title, artistName, videoId, thumbnails FROM song WHERE videoId IS NOT NULL").fetchall()
            for t_title, a_name, v_id, thumb_json in rows:
                if not t_title or not v_id:
                    continue
                t_clean = t_title.strip().lower()
                thumb_url = f"https://i.ytimg.com/vi/{v_id}/hqdefault.jpg"
                artists = []
                if a_name:
                    try:
                        parsed_a = json.loads(a_name)
                        if isinstance(parsed_a, list):
                            artists = [str(x).strip().lower() for x in parsed_a]
                        else:
                            artists = [str(parsed_a).strip().lower()]
                    except Exception:
                        artists = [a_name.strip().lower()]
                for art in artists:
                    title_artist_map[(t_clean, art)] = thumb_url
                title_map[t_clean] = thumb_url
            conn.close()
        except Exception as e:
            print("DB read error:", e)

    def find_thumbnail(title_str, artist_str):
        lower_t = title_str.strip().lower()
        lower_a = artist_str.strip().lower()

        # 1. Exact title + artist match
        if (lower_t, lower_a) in title_artist_map:
            return title_artist_map[(lower_t, lower_a)]

        for sub_a in [x.strip() for x in re.split(r'[,&/]', lower_a)]:
            if (lower_t, sub_a) in title_artist_map:
                return title_artist_map[(lower_t, sub_a)]

        # 2. Exact title match
        if lower_t in title_map:
            return title_map[lower_t]

        # 3. Cleaned title match (without brackets/extra notes)
        c_title = re.sub(r'[\(\[\{].*?[\)\]\}]', '', lower_t).strip()
        if c_title in title_map:
            return title_map[c_title]

        # 4. Strict fuzzy match (only for long titles >= 5 chars)
        if len(c_title) >= 5:
            for db_t, url in title_map.items():
                if len(db_t) >= 5 and (c_title == db_t or c_title.startswith(db_t) or db_t.startswith(c_title)):
                    return url
        return ""
    
    # 1. Scan SimpMusic
    if os.path.exists(SIMP_DIR):
        for f in sorted(os.listdir(SIMP_DIR)):
            if f.endswith((".opus", ".m4a", ".mp3", ".webm", ".flac")):
                full_path = os.path.join(SIMP_DIR, f)
                base = os.path.splitext(f)[0]
                if " - " in base:
                    artist, title = base.split(" - ", 1)
                else:
                    artist = "SimpMusic"
                    title = base
                
                thumb = find_thumbnail(title, artist)
                if not thumb:
                    thumb = extract_embedded_cover(full_path)

                try:
                    mtime = int(os.path.getmtime(full_path))
                except Exception:
                    mtime = 0

                tracks.append({
                    "id": len(tracks) + 1,
                    "title": title.strip(),
                    "name": title.strip(),
                    "artist": artist.strip(),
                    "source": "SimpMusic",
                    "path": full_path,
                    "filename": f,
                    "duration": "--:--",
                    "image": thumb,
                    "mtime": mtime
                })

    # 2. Scan Downloads_Phone
    if os.path.exists(DOWNLOADS_DIR):
        for f in sorted(os.listdir(DOWNLOADS_DIR)):
            if f.endswith((".mp3", ".m4a", ".opus", ".flac")):
                full_path = os.path.join(DOWNLOADS_DIR, f)
                base = os.path.splitext(f)[0]
                if " - " in base:
                    artist, title = base.split(" - ", 1)
                else:
                    artist = "Downloaded"
                    title = base
                
                thumb = find_thumbnail(title, artist)
                if not thumb:
                    thumb = extract_embedded_cover(full_path)

                try:
                    mtime = int(os.path.getmtime(full_path))
                except Exception:
                    mtime = 0

                tracks.append({
                    "id": len(tracks) + 1,
                    "title": title.strip(),
                    "name": title.strip(),
                    "artist": artist.strip(),
                    "source": "Downloads",
                    "path": full_path,
                    "filename": f,
                    "duration": "--:--",
                    "image": thumb,
                    "mtime": mtime
                })

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(tracks, f, ensure_ascii=False, indent=2)

    print(f"Scanned {len(tracks)} tracks into {OUT_JSON}")
    return tracks

def delete_track(path="", filename="", title=""):
    deleted_files = []

    # 1. Determine candidate file paths
    candidate_paths = []
    if path and not path.startswith("ytdl://"):
        candidate_paths.append(path)
    if filename:
        candidate_paths.append(os.path.join(SIMP_DIR, filename))
        candidate_paths.append(os.path.join(DOWNLOADS_DIR, filename))

    for cp in candidate_paths:
        if os.path.exists(cp):
            try:
                os.remove(cp)
                deleted_files.append(cp)
            except Exception as e:
                print(f"Error removing file {cp}: {e}", file=sys.stderr)

            # Also check and remove associated .lrc
            lrc_path = os.path.splitext(cp)[0] + ".lrc"
            if os.path.exists(lrc_path):
                try:
                    os.remove(lrc_path)
                    deleted_files.append(lrc_path)
                except Exception:
                    pass

    # 2. Update library.json atomically
    if os.path.exists(OUT_JSON):
        try:
            with open(OUT_JSON, "r", encoding="utf-8") as f:
                tracks = json.load(f)

            def should_remove(t):
                t_path = t.get("path", "")
                t_fn = t.get("filename", "")
                t_title = t.get("title", "") or t.get("name", "")
                if path and t_path == path:
                    return True
                if filename and (t_fn == filename or t_path.endswith(filename)):
                    return True
                if title and t_title and t_title.lower() == title.lower():
                    return True
                return False

            new_tracks = [t for t in tracks if not should_remove(t)]
            for i, t in enumerate(new_tracks):
                t["id"] = i + 1

            tmp_json = OUT_JSON + ".tmp"
            with open(tmp_json, "w", encoding="utf-8") as f:
                json.dump(new_tracks, f, ensure_ascii=False, indent=2)
            os.replace(tmp_json, OUT_JSON)

            print(json.dumps({
                "success": True,
                "deleted_files": deleted_files,
                "remaining_tracks": len(new_tracks)
            }))
            return True
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
            return False
    else:
        print(json.dumps({"success": True, "deleted_files": deleted_files, "remaining_tracks": 0}))
        return True

def batch_delete_tracks(paths):
    deleted_files = []
    if not isinstance(paths, list):
        try:
            paths = json.loads(paths)
        except Exception:
            paths = [paths]

    paths_set = set(p for p in paths if p and not p.startswith("ytdl://"))
    for p in paths_set:
        if os.path.exists(p):
            try:
                os.remove(p)
                deleted_files.append(p)
            except Exception as e:
                print(f"Error removing {p}: {e}", file=sys.stderr)
        lrc_path = os.path.splitext(p)[0] + ".lrc"
        if os.path.exists(lrc_path):
            try:
                os.remove(lrc_path)
                deleted_files.append(lrc_path)
            except Exception:
                pass

    if os.path.exists(OUT_JSON):
        try:
            with open(OUT_JSON, "r", encoding="utf-8") as f:
                tracks = json.load(f)
            new_tracks = [t for t in tracks if t.get("path") not in paths_set]
            for i, t in enumerate(new_tracks):
                t["id"] = i + 1
            tmp_json = OUT_JSON + ".tmp"
            with open(tmp_json, "w", encoding="utf-8") as f:
                json.dump(new_tracks, f, ensure_ascii=False, indent=2)
            os.replace(tmp_json, OUT_JSON)
            print(json.dumps({
                "success": True,
                "deleted_count": len(deleted_files),
                "remaining_tracks": len(new_tracks)
            }))
            return True
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
            return False
    return True

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "delete":
        p = sys.argv[2] if len(sys.argv) > 2 else ""
        fn = sys.argv[3] if len(sys.argv) > 3 else ""
        t = sys.argv[4] if len(sys.argv) > 4 else ""
        delete_track(p, fn, t)
    elif len(sys.argv) > 1 and sys.argv[1] == "batch_delete" and len(sys.argv) > 2:
        batch_delete_tracks(sys.argv[2])
    else:
        scan_library()
