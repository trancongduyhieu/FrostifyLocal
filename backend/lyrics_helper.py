#!/usr/bin/env python3
"""
Frostify Local Synced Lyrics Helper
Hierarchy:
1. Local .lrc file / Persistent cache (~/.cache/frostify/lyrics/<key>.lrc)
2. Online Synced Lyrics via `syncedlyrics` (LRCLIB -> NetEase -> Musixmatch) -> save cache
3. Last Resort Fallback: SimpMusic SQLite Database (YouTube extracted auto-subtitles)
"""
import sys
import json
import os
import re
import sqlite3

CACHE_DIR = os.path.expanduser("~/.cache/frostify/lyrics")

def sanitize_filename(name):
    if not name:
        return ""
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def get_cache_path(title, artist=None):
    os.makedirs(CACHE_DIR, exist_ok=True)
    clean_t = sanitize_filename(title)
    clean_a = sanitize_filename(artist) if artist else ""
    if clean_a:
        filename = f"{clean_a} - {clean_t}.lrc"
    else:
        filename = f"{clean_t}.lrc"
    return os.path.join(CACHE_DIR, filename)

def parse_lrc(lrc_text):
    if not lrc_text:
        return []

    results = []
    # Pattern: [mm:ss.xx] or [mm:ss.xxx]
    time_regex = re.compile(r'\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]')

    for line in lrc_text.splitlines():
        line = line.strip()
        if not line:
            continue
        # Skip header metadata lines like [ar:artist], [ti:title], etc.
        if re.match(r'^\[[a-zA-Z]+:', line):
            continue

        matches = list(time_regex.finditer(line))
        if not matches:
            continue

        last_match = matches[-1]
        text = line[last_match.end():].strip()
        text = re.sub(r'<[0-9:.]+>', '', text).strip()

        if not text:
            continue

        for m in matches:
            mins = int(m.group(1))
            secs = float(m.group(2))
            total_sec = round(mins * 60.0 + secs, 2)
            results.append({"time": total_sec, "text": text})

    results.sort(key=lambda x: x["time"])
    return results

def get_lyrics_from_simpmusic(title, video_id=None):
    db_path = os.path.expanduser('~/Music/SimpMusic/extracted/Music Database')
    if not os.path.exists(db_path):
        return []

    try:
        conn = sqlite3.connect(db_path)
        c = conn.cursor()

        raw_lines = None
        if video_id:
            r = c.execute('SELECT lines FROM lyrics WHERE videoId = ?', (video_id,)).fetchone()
            if r and r[0]:
                raw_lines = r[0]

        if not raw_lines and title:
            r = c.execute('''
                SELECT l.lines FROM lyrics l
                JOIN song s ON s.videoId = l.videoId
                WHERE s.title = ? AND l.lines IS NOT NULL AND l.lines != ""
                LIMIT 1
            ''', (title,)).fetchone()
            if r and r[0]:
                raw_lines = r[0]

        if not raw_lines and title:
            # Fuzzy match
            r = c.execute('''
                SELECT l.lines FROM lyrics l
                JOIN song s ON s.videoId = l.videoId
                WHERE s.title LIKE ? AND l.lines IS NOT NULL AND l.lines != ""
                LIMIT 1
            ''', (f"%{title}%",)).fetchone()
            if r and r[0]:
                raw_lines = r[0]

        if not raw_lines:
            return []

        parsed = json.loads(raw_lines)
        results = []
        for line in parsed:
            w = line.get('words', '').strip()
            clean_w = re.sub(r'<[0-9:.]+>', '', w).strip()
            st = int(line.get('startTimeMs', 0))
            if clean_w:
                results.append({'time': round(st / 1000.0, 2), 'text': clean_w})
        return results
    except Exception:
        return []

def clean_search_title(title):
    t = re.sub(r'\[.*?\]|\(.*?\)|\|.*?$', '', title)
    t = re.sub(r'\b(official\s+video|official\s+audio|lyric\s+video|mv|vietsub)\b', '', t, flags=re.IGNORECASE)
    t = re.sub(r'\s+', ' ', t).strip()
    return t or title

def get_lyrics(title, artist=None, video_id=None, file_path=None):
    if not title:
        return []

    # -------------------------------------------------------------------------
    # TẦNG 1: Local .lrc file & Persistent Cache
    # -------------------------------------------------------------------------
    if file_path:
        base, _ = os.path.splitext(file_path)
        local_lrc = base + ".lrc"
        if os.path.exists(local_lrc):
            try:
                with open(local_lrc, "r", encoding="utf-8", errors="ignore") as f:
                    res = parse_lrc(f.read())
                    if res:
                        return res
            except Exception:
                pass

    cache_paths = [
        get_cache_path(title, artist),
        get_cache_path(title, None)
    ]
    for cp in cache_paths:
        if os.path.exists(cp):
            try:
                with open(cp, "r", encoding="utf-8", errors="ignore") as f:
                    res = parse_lrc(f.read())
                    if res:
                        return res
            except Exception:
                pass

    # -------------------------------------------------------------------------
    # TẦNG 2: Online Synced Lyrics qua syncedlyrics (LRCLIB -> NetEase -> Musixmatch)
    # -------------------------------------------------------------------------
    try:
        import syncedlyrics
        cleaned_title = clean_search_title(title)

        queries = []
        if artist and artist.strip() and artist.lower() not in title.lower():
            queries.append(f"{cleaned_title} {artist}".strip())
        queries.append(cleaned_title)
        if cleaned_title != title:
            if artist and artist.strip():
                queries.append(f"{title} {artist}".strip())
            queries.append(title.strip())

        for q in queries:
            try:
                lrc = syncedlyrics.search(q, providers=["lrclib", "netease", "musixmatch"])
                if lrc:
                    parsed = parse_lrc(lrc)
                    if parsed:
                        save_path = get_cache_path(title, artist)
                        try:
                            with open(save_path, "w", encoding="utf-8") as f:
                                f.write(lrc)
                        except Exception:
                            pass
                        return parsed
            except Exception as e:
                sys.stderr.write(f"[syncedlyrics error for '{q}']: {e}\n")
    except ImportError:
        sys.stderr.write("[syncedlyrics not available, skipping online search]\n")

    # -------------------------------------------------------------------------
    # TẦNG 3: Dự phòng cuối cùng (SimpMusic SQLite Database)
    # -------------------------------------------------------------------------
    return get_lyrics_from_simpmusic(title, video_id)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("[]")
        sys.exit(0)

    title_arg = sys.argv[1] if len(sys.argv) > 1 else ""
    artist_arg = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].strip() != "" else None
    vid_arg = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].strip() != "" else None
    path_arg = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4].strip() != "" else None

    res = get_lyrics(title_arg, artist_arg, vid_arg, path_arg)
    print(json.dumps(res, ensure_ascii=False))
