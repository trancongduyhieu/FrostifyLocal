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
                tracks.append({
                    "id": len(tracks) + 1,
                    "title": title.strip(),
                    "name": title.strip(),
                    "artist": artist.strip(),
                    "source": "SimpMusic",
                    "path": full_path,
                    "filename": f,
                    "duration": "--:--",
                    "image": thumb
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
                tracks.append({
                    "id": len(tracks) + 1,
                    "title": title.strip(),
                    "name": title.strip(),
                    "artist": artist.strip(),
                    "source": "Downloads",
                    "path": full_path,
                    "filename": f,
                    "duration": "--:--",
                    "image": thumb
                })

    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(tracks, f, ensure_ascii=False, indent=2)

    print(f"Scanned {len(tracks)} tracks into {OUT_JSON}")
    return tracks

if __name__ == "__main__":
    scan_library()
