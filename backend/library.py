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

    # Build videoId mapping from SimpMusic Database
    db_path = os.path.join(HOME, "Music", "SimpMusic", "extracted", "Music Database")
    video_map = {}
    if os.path.exists(db_path):
        try:
            conn = sqlite3.connect(db_path)
            c = conn.cursor()
            rows = c.execute("SELECT title, videoId FROM song WHERE videoId IS NOT NULL").fetchall()
            for t_title, v_id in rows:
                if t_title and v_id:
                    video_map[t_title.strip().lower()] = v_id
            conn.close()
        except Exception as e:
            print("DB read error:", e)

    def find_thumbnail(title_str, artist_str):
        lower_t = title_str.strip().lower()
        if lower_t in video_map:
            return f"https://i.ytimg.com/vi/{video_map[lower_t]}/hqdefault.jpg"
        # Fuzzy search
        for db_t, db_v in video_map.items():
            if lower_t in db_t or db_t in lower_t:
                return f"https://i.ytimg.com/vi/{db_v}/hqdefault.jpg"
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
