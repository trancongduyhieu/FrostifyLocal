#!/usr/bin/env python3
"""
Nutsty Synced Lyrics Helper
Hierarchy:
1. Local .lrc file / Persistent cache (~/.cache/nutsty/lyrics/<key>.lrc)
2. Online Synced Lyrics via `syncedlyrics` (LRCLIB -> NetEase -> Musixmatch) -> save cache
3. Last Resort Fallback: Local SQLite Database
"""
import sys
import json
import os
import re
import sqlite3

# Ensure backend directory is in sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

import platform_compat as pc
pc.configure_windows_ssl()

CACHE_DIR = os.path.join(pc.get_cache_dir(), "lyrics")

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

def strip_rich_sync_tags(text):
    if not text:
        return ""
    t = re.sub(r'<[0-9:.]+>', ' ', text)
    return re.sub(r'\s+', ' ', t).strip()

def parse_rich_sync_words(line_str, default_start=0.0):
    if not line_str or "<" not in line_str or ">" not in line_str:
        return []
    
    # Matches <mm:ss.xx> or <mm:ss.xxx> followed by word text until next < or end
    pattern = re.compile(r'<(\d{1,2}):(\d{1,2}(?:\.\d+)?)>\s*([^<]*)')
    matches = list(pattern.finditer(line_str))
    if not matches:
        return []
    
    words = []
    for i, m in enumerate(matches):
        mins = int(m.group(1))
        secs = float(m.group(2))
        start_t = round(mins * 60.0 + secs, 2)
        txt = m.group(3).strip()
        if not txt:
            continue
        
        if i + 1 < len(matches):
            next_mins = int(matches[i+1].group(1))
            next_secs = float(matches[i+1].group(2))
            end_t = round(next_mins * 60.0 + next_secs, 2)
        else:
            end_t = round(start_t + 0.5, 2)
            
        dur = max(0.08, round(end_t - start_t, 2))
        is_held = (dur >= 0.85) # Held note threshold: 850ms+
        
        words.append({
            "text": txt,
            "start": start_t,
            "end": end_t,
            "duration": dur,
            "isHeld": is_held
        })
    return words

def synthesize_line_words(text, start_time, end_time):
    if not text:
        return []
    raw_words = text.strip().split()
    if not raw_words:
        return []
    dur = max(0.6, end_time - start_time)
    # Natural phrasing: vocal delivery occupies ~75-80% of line interval, reserving remainder for breath/rest
    rest = min(1.6, max(0.35, dur * 0.24)) if dur >= 1.6 else 0.15
    vocal_dur = max(0.5, dur - rest)
    char_counts = [max(1, len(w)) for w in raw_words]
    total_chars = sum(char_counts)
    
    words = []
    cur_t = start_time
    for i, w in enumerate(raw_words):
        fraction = char_counts[i] / total_chars
        w_dur = round(max(0.10, vocal_dur * fraction), 2)
        w_start = round(cur_t, 2)
        w_end = round(cur_t + w_dur, 2)
        words.append({
            "text": w,
            "start": w_start,
            "end": w_end,
            "duration": w_dur,
            "isHeld": (w_dur >= 0.75)
        })
        cur_t = w_end
    return words

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
        raw_text = line[last_match.end():].strip()
        clean_text = strip_rich_sync_tags(raw_text)

        if not clean_text:
            continue

        syllable_words = parse_rich_sync_words(raw_text)

        for m in matches:
            mins = int(m.group(1))
            secs = float(m.group(2))
            total_sec = round(mins * 60.0 + secs, 2)
            end_sec = max((w["end"] for w in syllable_words), default=None)
            item = {
                "time": total_sec,
                "endTime": end_sec if end_sec is not None else round(total_sec + 4.5, 2),
                "text": clean_text,
                "hasWords": bool(syllable_words),
                "words": syllable_words
            }
            results.append(item)

    results.sort(key=lambda x: x["time"])

    # Fallback endTime calculation for lines without syllable timestamps.
    # IMPORTANT: We do NOT synthesize fake word timing here anymore.
    # Lines without real <mm:ss.xx> tags stay as isSynthetic=True with hasWords=False
    # so the QML layer correctly shows Apple Music Full-Line Solid Highlight instead
    # of AppleMusicWordFlow with guessed timing that drifts vs the singer.
    for i, it in enumerate(results):
        if not it.get("hasWords"):
            if i + 1 < len(results):
                it["endTime"] = results[i + 1]["time"]
            else:
                it["endTime"] = round(it["time"] + 5.0, 2)
            # Keep hasWords=False and words=[] — no fake synthesis
            it["words"] = []
            it["isSynthetic"] = True  # Signal to QML: use Full-Line Solid Highlight

    return results

def clean_search_title(title):
    if not title:
        return ""
    t = re.sub(r'\[.*?\]|\(.*?\)|\|.*?$', '', title)
    t = re.sub(r'\b(official\s+video|official\s+audio|lyric\s+video|mv|vietsub)\b', '', t, flags=re.IGNORECASE)
    t = re.sub(r'\s+', ' ', t).strip()
    return t or title

def get_lyrics_from_local_db(title, artist=None, video_id=None):
    p1 = os.path.join(pc.get_music_dir(), "Nutsty", "extracted", "Music Database")
    p2 = os.path.join(pc.get_music_dir(), "SimpMusic", "extracted", "Music Database")
    db_path = p1 if os.path.exists(p1) else p2
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

        clean_artist = artist.strip().lower() if artist and artist.strip() else ""

        candidates = []
        if title:
            candidates.append(title.strip())
            cleaned = clean_search_title(title)
            if cleaned and cleaned.lower() != title.strip().lower():
                candidates.append(cleaned)

        if not raw_lines:
            for t_query in candidates:
                if raw_lines:
                    break
                # Exact title match
                rows = c.execute('''
                    SELECT l.lines, s.artistName, s.title FROM lyrics l
                    JOIN song s ON s.videoId = l.videoId
                    WHERE LOWER(s.title) = LOWER(?) AND l.lines IS NOT NULL AND l.lines != ""
                ''', (t_query,)).fetchall()

                for r_lines, r_art, r_title in rows:
                    if clean_artist:
                        r_art_str = (r_art or "").lower()
                        if clean_artist in r_art_str or r_art_str in clean_artist:
                            raw_lines = r_lines
                            break
                    else:
                        raw_lines = r_lines
                        break

        if not raw_lines:
            return []

        parsed = json.loads(raw_lines)
        results = []
        for line in parsed:
            w = line.get('words', '').strip()
            clean_w = strip_rich_sync_tags(w)
            st = int(line.get('startTimeMs', 0))
            if clean_w:
                start_sec = round(st / 1000.0, 2)
                syllable_words = parse_rich_sync_words(w, default_start=start_sec)
                end_sec = max((item["end"] for item in syllable_words), default=None)
                results.append({
                    'time': start_sec,
                    'endTime': end_sec if end_sec is not None else round(start_sec + 4.5, 2),
                    'text': clean_w,
                    'hasWords': bool(syllable_words),
                    'words': syllable_words
                })
        for i, it in enumerate(results):
            if not it.get("hasWords"):
                if i + 1 < len(results):
                    it["endTime"] = results[i + 1]["time"]
                else:
                    it["endTime"] = round(it["time"] + 5.0, 2)
                it["words"] = []
                it["isSynthetic"] = True
        return results
    except Exception:
        return []

def get_lyrics(title, artist=None, video_id=None, file_path=None):
    if not title:
        return []

    # -------------------------------------------------------------------------
    # TẦNG 0: Ưu tiên Local SQLite Database nếu có Rich Syllable Timestamps (phải khớp nghệ sĩ)!
    # -------------------------------------------------------------------------
    db_lyrics = get_lyrics_from_local_db(title, artist, video_id)
    if db_lyrics and any(item.get("hasWords") for item in db_lyrics):
        return db_lyrics

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

    cache_paths = []
    if artist and artist.strip():
        cache_paths.append(get_cache_path(title, artist))
    cache_paths.append(get_cache_path(title, None))

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
                lrc = syncedlyrics.search(q, providers=["netease", "lrclib"])
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
    # TẦNG 3: Dự phòng YouTube Music InnerTube Lyrics
    # -------------------------------------------------------------------------
    if video_id:
        try:
            import ytmusic_helper
            yt_lyrics = ytmusic_helper.get_youtube_lyrics(video_id)
            if yt_lyrics:
                lines = [l.strip() for l in yt_lyrics.split("\n") if l.strip()]
                if lines:
                    formatted = []
                    for idx, line in enumerate(lines):
                        formatted.append({
                            "time": idx * 3.5,
                            "text": line,
                            "hasWords": False,
                            "words": []
                        })
                    return formatted
        except Exception as ye:
            sys.stderr.write(f"[ytmusic lyrics fallback error]: {ye}\n")

    # -------------------------------------------------------------------------
    # TẦNG 4: Dự phòng cuối cùng (Local SQLite Database)
    # -------------------------------------------------------------------------
    return db_lyrics or get_lyrics_from_local_db(title, artist, video_id)

def handle_cli(args):
    """Entry point for thread-safe in-process execution without modifying sys.argv."""
    if len(args) < 1:
        print("[]")
        return
    title_arg = args[0] if len(args) > 0 else ""
    artist_arg = args[1] if len(args) > 1 and args[1].strip() != "" else None
    vid_arg = args[2] if len(args) > 2 and args[2].strip() != "" else None
    path_arg = args[3] if len(args) > 3 and args[3].strip() != "" else None

    res = get_lyrics(title_arg, artist_arg, vid_arg, path_arg)
    print(json.dumps(res, ensure_ascii=False))

def main():
    if len(sys.argv) < 2:
        print("[]")
        return

    title_arg = sys.argv[1] if len(sys.argv) > 1 else ""
    artist_arg = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].strip() != "" else None
    vid_arg = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].strip() != "" else None
    path_arg = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4].strip() != "" else None

    res = get_lyrics(title_arg, artist_arg, vid_arg, path_arg)
    print(json.dumps(res, ensure_ascii=False))

if __name__ == '__main__':
    main()
