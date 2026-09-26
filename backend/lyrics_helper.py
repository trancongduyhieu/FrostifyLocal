#!/usr/bin/env python3
"""
Nutsty Synced Lyrics Helper — 7-Tier Pipeline
Priority (highest → lowest):
  0. Local SQLite DB (SimpMusic exported — has rich syllable timestamps)
  1. Local .lrc file next to audio file
  2. Persistent .lrc cache (~/.cache/nutsty/lyrics/)
  3. BetterLyrics TTML (lyrics-api.boidu.dev) — Apple Music WORD-LEVEL, best quality
  4. Spotify spclient (sp_dc cookie) — word-level, requires user cookie
  5. LRCLIB /api/get with duration-matched query — precise line sync, no drift
  6. NetEase / syncedlyrics fallback (may have rich-sync tags)
  7. YouTube Music InnerTube plain lyrics (last resort, unsynced)

isSynthetic flag: lines from plain LRC (no <mm:ss.xx> word tags) are marked
isSynthetic=True so QML renders Full-Line Solid Highlight instead of WordFlow.
"""
import sys
import json
import os
import re
import sqlite3
import urllib.request
import urllib.parse
import urllib.error

# Ensure backend directory is in sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

import platform_compat as pc
pc.configure_windows_ssl()

CACHE_DIR = os.path.join(pc.get_cache_dir(), "lyrics")
SETTINGS_PATH = os.path.join(
    os.path.expanduser("~"), ".config", "noctalia", "nutsty_settings.json"
)

# ──────────────────────────────────────────────────────────────────────────────
# Settings helpers
# ──────────────────────────────────────────────────────────────────────────────

def _load_settings():
    try:
        with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def get_spotify_spdc():
    """Return sp_dc cookie string from nutsty_settings.json, or empty string."""
    return _load_settings().get("spotifySpdc", "").strip()

# ──────────────────────────────────────────────────────────────────────────────
# Filename / cache utilities
# ──────────────────────────────────────────────────────────────────────────────

def sanitize_filename(name):
    if not name:
        return ""
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def get_cache_path(title, artist=None):
    os.makedirs(CACHE_DIR, exist_ok=True)
    clean_t = sanitize_filename(title)
    clean_a = sanitize_filename(artist) if artist else ""
    filename = f"{clean_a} - {clean_t}.lrc" if clean_a else f"{clean_t}.lrc"
    return os.path.join(CACHE_DIR, filename)

def clean_search_title(title):
    if not title:
        return ""
    t = re.sub(r'\[.*?\]|\(.*?\)|\|.*?$', '', title)
    t = re.sub(r'\b(official\s+video|official\s+audio|lyric\s+video|mv|vietsub)\b', '', t, flags=re.IGNORECASE)
    t = re.sub(r'\s+', ' ', t).strip()
    return t or title

# ──────────────────────────────────────────────────────────────────────────────
# LRC / Rich-sync parsers
# ──────────────────────────────────────────────────────────────────────────────

def strip_rich_sync_tags(text):
    if not text:
        return ""
    t = re.sub(r'<[0-9:.]+>', ' ', text)
    return re.sub(r'\s+', ' ', t).strip()

def parse_rich_sync_words(line_str, default_start=0.0):
    """Parse <mm:ss.xx> word timestamps embedded in a LRC line."""
    if not line_str or "<" not in line_str or ">" not in line_str:
        return []
    pattern = re.compile(r'<(\d{1,2}):(\d{1,2}(?:\.\d+)?)>\s*([^<]*)')
    matches = list(pattern.finditer(line_str))
    if not matches:
        return []
    words = []
    for i, m in enumerate(matches):
        mins, secs = int(m.group(1)), float(m.group(2))
        start_t = round(mins * 60.0 + secs, 3)
        txt = m.group(3).strip()
        if not txt:
            continue
        if i + 1 < len(matches):
            nm = matches[i + 1]
            end_t = round(int(nm.group(1)) * 60.0 + float(nm.group(2)), 3)
        else:
            end_t = round(start_t + 0.5, 3)
        dur = max(0.08, round(end_t - start_t, 3))
        words.append({
            "text": txt,
            "start": start_t,
            "end": end_t,
            "duration": dur,
            "isHeld": dur >= 0.85,
        })
    return words

def parse_lrc(lrc_text):
    """Parse LRC text → list of lyric line dicts.
    Lines with <mm:ss.xx> tags get hasWords=True (real syllable data).
    Plain lines get hasWords=False + isSynthetic=True → Full-Line Highlight in QML.
    """
    if not lrc_text:
        return []
    results = []
    time_regex = re.compile(r'\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]')

    for line in lrc_text.splitlines():
        line = line.strip()
        if not line:
            continue
        if re.match(r'^\[[a-zA-Z]+:', line):
            continue
        matches = list(time_regex.finditer(line))
        if not matches:
            continue
        last_match = matches[-1]
        raw_text = line[last_match.end():].strip()
        # Filter music note placeholders
        clean_text = strip_rich_sync_tags(raw_text)
        if not clean_text or clean_text in ("♪", "♫", "🎵"):
            continue
        syllable_words = parse_rich_sync_words(raw_text)
        for m in matches:
            mins, secs = int(m.group(1)), float(m.group(2))
            total_sec = round(mins * 60.0 + secs, 3)
            end_sec = max((w["end"] for w in syllable_words), default=None)
            results.append({
                "time": total_sec,
                "endTime": end_sec if end_sec is not None else round(total_sec + 4.5, 3),
                "text": clean_text,
                "hasWords": bool(syllable_words),
                "isSynthetic": not bool(syllable_words),
                "words": syllable_words,
            })
    results.sort(key=lambda x: x["time"])

    # Fill in endTime for lines without syllable timestamps
    for i, it in enumerate(results):
        if not it.get("hasWords"):
            if i + 1 < len(results):
                it["endTime"] = results[i + 1]["time"]
            else:
                it["endTime"] = round(it["time"] + 5.0, 3)
    return results

# ──────────────────────────────────────────────────────────────────────────────
# TTML parser (Apple Music word-level via BetterLyrics)
# ──────────────────────────────────────────────────────────────────────────────

def _parse_ttml_time(t):
    """Parse TTML time '1:23.456' or '83.456' → float seconds."""
    t = t.strip()
    parts = t.split(":")
    if len(parts) == 3:
        h, m, s = parts
        return int(h) * 3600 + int(m) * 60 + float(s)
    elif len(parts) == 2:
        m, s = parts
        return int(m) * 60 + float(s)
    else:
        return float(t)

def parse_ttml(ttml_str):
    """Convert Apple Music TTML → Nutsty lyric line list with real word timestamps."""
    if not ttml_str:
        return []

    p_re = re.compile(
        r'<p\s[^>]*begin="([^"]+)"[^>]*end="([^"]+)"[^>]*>([\s\S]*?)</p>'
    )
    span_re = re.compile(
        r'<span\s[^>]*begin="([^"]+)"[^>]*end="([^"]+)"[^>]*>(.*?)</span>'
    )

    results = []
    for pm in p_re.finditer(ttml_str):
        line_start = round(_parse_ttml_time(pm.group(1)), 3)
        line_end   = round(_parse_ttml_time(pm.group(2)), 3)
        inner      = pm.group(3)

        spans = span_re.findall(inner)
        if spans:
            words = []
            for sp_begin, sp_end, sp_text in spans:
                sp_text = sp_text.strip()
                if not sp_text:
                    continue
                start = round(_parse_ttml_time(sp_begin), 3)
                end   = round(_parse_ttml_time(sp_end), 3)
                dur   = max(0.08, round(end - start, 3))
                words.append({
                    "text": sp_text,
                    "start": start,
                    "end": end,
                    "duration": dur,
                    "isHeld": dur >= 0.85,
                })
            if words:
                plain = " ".join(w["text"] for w in words)
                results.append({
                    "time": line_start,
                    "endTime": line_end,
                    "text": plain,
                    "hasWords": True,
                    "isSynthetic": False,
                    "words": words,
                })
        else:
            plain = re.sub(r'<[^>]+>', '', inner).strip()
            if plain:
                results.append({
                    "time": line_start,
                    "endTime": line_end,
                    "text": plain,
                    "hasWords": False,
                    "isSynthetic": True,
                    "words": [],
                })

    results.sort(key=lambda x: x["time"])
    return results

# ──────────────────────────────────────────────────────────────────────────────
# Spotify word-level parser (color-lyrics JSON)
# ──────────────────────────────────────────────────────────────────────────────

def parse_spotify_lyrics(data):
    """Convert Spotify color-lyrics v2 JSON → Nutsty line list."""
    try:
        lines_raw = data["lyrics"]["lines"]
    except (KeyError, TypeError):
        return []

    sync_type = data.get("lyrics", {}).get("syncType", "")
    is_line_synced = sync_type == "LINE_SYNCED"

    results = []
    for i, line in enumerate(lines_raw):
        start_ms = int(line.get("startTimeMs", 0))
        start_sec = round(start_ms / 1000.0, 3)
        raw_words = line.get("words", "")

        # endTime: use next line start or +5s
        if i + 1 < len(lines_raw):
            next_ms = int(lines_raw[i + 1].get("startTimeMs", 0))
            end_sec = round(next_ms / 1000.0, 3)
        else:
            end_sec = round(start_sec + 5.0, 3)

        # Spotify LINE_SYNCED → no word timing
        if is_line_synced or not raw_words or "<" not in raw_words:
            clean = raw_words.strip() if raw_words else ""
            if not clean:
                continue
            results.append({
                "time": start_sec,
                "endTime": end_sec,
                "text": clean,
                "hasWords": False,
                "isSynthetic": True,
                "words": [],
            })
        else:
            # RICH_SYNCED: Spotify embeds <mm:ss.xx>word format
            syllable_words = parse_rich_sync_words(raw_words, default_start=start_sec)
            clean = strip_rich_sync_tags(raw_words)
            if not clean:
                continue
            results.append({
                "time": start_sec,
                "endTime": end_sec,
                "text": clean,
                "hasWords": bool(syllable_words),
                "isSynthetic": not bool(syllable_words),
                "words": syllable_words,
            })

    return results

# ──────────────────────────────────────────────────────────────────────────────
# HTTP helper (no external deps beyond stdlib)
# ──────────────────────────────────────────────────────────────────────────────

def _http_get(url, headers=None, timeout=8):
    """Simple HTTP GET, returns response body as str or None on error."""
    req = urllib.request.Request(url, headers=headers or {})
    req.add_header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) Nutsty/1.0")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode("utf-8", errors="replace")
    except Exception as e:
        sys.stderr.write(f"[http_get {url[:60]}]: {e}\n")
        return None

# ──────────────────────────────────────────────────────────────────────────────
# TẦNG 3: BetterLyrics TTML (Apple Music word-level)
# ──────────────────────────────────────────────────────────────────────────────

def fetch_betterlyrics_ttml(title, artist, duration_sec=None):
    """
    Fetch TTML from lyrics-api.boidu.dev — Apple Music internal TTML with
    per-span word timestamps. Best quality source after local DB.
    """
    params = {"s": title, "a": artist or ""}
    if duration_sec and duration_sec > 0:
        params["d"] = int(duration_sec)
    url = "https://lyrics-api.boidu.dev/getLyrics?" + urllib.parse.urlencode(params)
    body = _http_get(url, timeout=10)
    if not body:
        return []
    try:
        data = json.loads(body)
        ttml = data.get("ttml", "")
        if not ttml:
            return []
        parsed = parse_ttml(ttml)
        return parsed if parsed else []
    except Exception as e:
        sys.stderr.write(f"[BetterLyrics parse error]: {e}\n")
        return []

# ──────────────────────────────────────────────────────────────────────────────
# TẦNG 4: Spotify spclient (sp_dc cookie) — word-level
# ──────────────────────────────────────────────────────────────────────────────

def _spotify_get_client_token():
    """Get anonymous Spotify client token (no sp_dc needed)."""
    import json as _json
    body = _json.dumps({
        "client_data": {
            "client_version": "1.2.61.20.g3b4cd5b2",
            "client_id": "d8a5ed958d274c2e8ee717e6a4b0971d",
            "js_sdk_data": {
                "device_brand": "Apple",
                "device_model": "MacBookPro",
                "os": "macos",
                "os_version": "14.4",
            }
        }
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://clienttoken.spotify.com/v1/clienttoken",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/135.0.0.0 Safari/537.36",
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=6) as r:
            d = json.loads(r.read().decode())
            return d.get("granted_token", {}).get("token", "")
    except Exception as e:
        sys.stderr.write(f"[Spotify client token error]: {e}\n")
        return ""

def _spotify_get_personal_token(spdc):
    """Exchange sp_dc cookie for a personal access token."""
    url = "https://open.spotify.com/get_access_token?reason=transport&productType=web_player"
    body = _http_get(url, headers={
        "Cookie": f"sp_dc={spdc}",
        "App-platform": "WebPlayer",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/135.0.0.0 Safari/537.36",
        "Accept": "application/json",
        "Origin": "https://open.spotify.com",
        "Referer": "https://open.spotify.com/",
    }, timeout=8)
    if not body:
        return ""
    try:
        return json.loads(body).get("accessToken", "")
    except Exception:
        return ""

def _spotify_search_track(query, access_token, client_token, duration_sec=None):
    """Search Spotify for a track, return trackId string or ''."""
    sha = "bc1ca2fcd0ba1013a0fc88e6cc4f190af501851e3dafd3e1ef85840297694428"
    variable = json.dumps({
        "searchTerm": query, "offset": 0, "limit": 5,
        "numberOfTopResults": 5, "includeAudiobooks": True, "includePreReleases": False
    })
    params = urllib.parse.urlencode({
        "operationName": "searchTracks",
        "variables": variable,
        "extensions": json.dumps({"persistedQuery": {"version": 1, "sha256Hash": sha}})
    })
    url = f"https://api-partner.spotify.com/pathfinder/v1/query?{params}"
    body = _http_get(url, headers={
        "Authorization": f"Bearer {access_token}",
        "Client-Token": client_token,
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/135.0.0.0 Safari/537.36",
    }, timeout=8)
    if not body:
        return ""
    try:
        data = json.loads(body)
        items = data["data"]["searchV2"]["tracksV2"]["items"]
        if not items:
            return ""
        # Try to find best duration match if duration_sec provided
        if duration_sec and duration_sec > 0:
            for item in items:
                dur_ms = item.get("item", {}).get("data", {}).get("duration", {}).get("totalMilliseconds", 0)
                if abs(dur_ms / 1000 - duration_sec) <= 12:
                    uri = item["item"]["data"]["uri"]
                    return uri.split(":")[-1]
        # Fall back to first result
        uri = items[0]["item"]["data"]["uri"]
        return uri.split(":")[-1]
    except Exception as e:
        sys.stderr.write(f"[Spotify search parse error]: {e}\n")
        return ""

def _spotify_get_lyrics(track_id, access_token, client_token):
    """Fetch lyrics from Spotify spclient."""
    url = f"https://spclient.wg.spotify.com/color-lyrics/v2/track/{track_id}?format=json&vocalRemoval=false&market=from_token"
    body = _http_get(url, headers={
        "Authorization": f"Bearer {access_token}",
        "Client-Token": client_token,
        "App-platform": "WebPlayer",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/74.0.3729.157 Safari/537.36",
    }, timeout=8)
    if not body:
        return []
    try:
        return parse_spotify_lyrics(json.loads(body))
    except Exception as e:
        sys.stderr.write(f"[Spotify lyrics parse error]: {e}\n")
        return []

def fetch_spotify_lyrics(title, artist, duration_sec=None):
    """Full Spotify lyrics fetch flow. Returns [] if sp_dc not configured."""
    spdc = get_spotify_spdc()
    if not spdc:
        return []

    access_token = _spotify_get_personal_token(spdc)
    if not access_token:
        sys.stderr.write("[Spotify] Could not get personal token from sp_dc\n")
        return []

    client_token = _spotify_get_client_token()
    if not client_token:
        sys.stderr.write("[Spotify] Could not get client token\n")
        return []

    cleaned = clean_search_title(title)
    query = f"{cleaned} {artist}".strip() if artist else cleaned
    # Sanitize query the same way SimpMusic does
    query = re.sub(r'\((feat\.|ft\.) ', ' ', query)
    query = re.sub(r'( và | & | и | e | und |, |和| dan)', ' ', query)
    query = re.sub(r'[()]', '', query).replace('.', ' ')
    query = re.sub(r'\s+', ' ', query).strip()

    track_id = _spotify_search_track(query, access_token, client_token, duration_sec)
    if not track_id:
        sys.stderr.write(f"[Spotify] Track not found for query: {query}\n")
        return []

    return _spotify_get_lyrics(track_id, access_token, client_token)

# ──────────────────────────────────────────────────────────────────────────────
# TẦNG 5: LRCLIB /api/get with duration matching (precision line sync)
# ──────────────────────────────────────────────────────────────────────────────

def fetch_lrclib(title, artist, duration_sec=None):
    """
    LRCLIB /api/get — duration-matched lookup prevents wrong-version matches.
    Returns parsed lyric list or [].
    """
    cleaned = clean_search_title(title)
    params = {"track_name": cleaned, "artist_name": artist or ""}
    if duration_sec and duration_sec > 0:
        params["duration"] = int(duration_sec)
    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
    body = _http_get(url, timeout=8)
    if not body:
        return []
    try:
        data = json.loads(body)
        synced = data.get("syncedLyrics", "")
        if synced:
            parsed = parse_lrc(synced)
            if parsed:
                return parsed
        plain = data.get("plainLyrics", "")
        if plain:
            lines = [l.strip() for l in plain.splitlines() if l.strip()]
            return [{
                "time": i * 3.5, "endTime": i * 3.5 + 3.5,
                "text": l, "hasWords": False, "isSynthetic": True, "words": []
            } for i, l in enumerate(lines)]
    except Exception as e:
        sys.stderr.write(f"[LRCLIB parse error]: {e}\n")
    return []

# ──────────────────────────────────────────────────────────────────────────────
# Local SQLite DB (SimpMusic exported)
# ──────────────────────────────────────────────────────────────────────────────

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
        candidates = [title.strip()]
        cleaned = clean_search_title(title)
        if cleaned and cleaned.lower() != title.strip().lower():
            candidates.append(cleaned)

        if not raw_lines:
            for t_query in candidates:
                if raw_lines:
                    break
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
                start_sec = round(st / 1000.0, 3)
                syllable_words = parse_rich_sync_words(w, default_start=start_sec)
                end_sec = max((item["end"] for item in syllable_words), default=None)
                results.append({
                    'time': start_sec,
                    'endTime': end_sec if end_sec is not None else round(start_sec + 4.5, 3),
                    'text': clean_w,
                    'hasWords': bool(syllable_words),
                    'isSynthetic': not bool(syllable_words),
                    'words': syllable_words,
                })
        for i, it in enumerate(results):
            if not it.get("hasWords"):
                if i + 1 < len(results):
                    it["endTime"] = results[i + 1]["time"]
                else:
                    it["endTime"] = round(it["time"] + 5.0, 3)
                it["words"] = []
                it["isSynthetic"] = True
        return results
    except Exception:
        return []

# ──────────────────────────────────────────────────────────────────────────────
# Main orchestrator
# ──────────────────────────────────────────────────────────────────────────────

def _has_real_syllables(lyric_list):
    """Returns True if any line has genuine word-level timestamps."""
    return lyric_list and any(
        item.get("hasWords") and not item.get("isSynthetic") and item.get("words")
        for item in lyric_list
    )

def _has_synced(lyric_list):
    """Returns True if any line has a real timestamp (not all synthetic/unsynced)."""
    return lyric_list and any(item.get("time", 0) > 0 for item in lyric_list)

def get_lyrics(title, artist=None, video_id=None, file_path=None, duration_sec=None):
    if not title:
        return []

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 0: Local SQLite (SimpMusic DB — rich syllable)
    # ──────────────────────────────────────────────────────────────────────
    db_lyrics = get_lyrics_from_local_db(title, artist, video_id)
    if _has_real_syllables(db_lyrics):
        return db_lyrics

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 1: Local .lrc file next to audio
    # ──────────────────────────────────────────────────────────────────────
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

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 2: Persistent .lrc cache
    # ──────────────────────────────────────────────────────────────────────
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
                        # Prefer cache only if it has syllable data; otherwise
                        # still try upstream sources for better quality
                        if _has_real_syllables(res):
                            return res
                        cached_plain = res  # save for fallback below
            except Exception:
                pass
    else:
        cached_plain = None

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 3: BetterLyrics TTML (Apple Music word-level) — best online source
    # ──────────────────────────────────────────────────────────────────────
    cleaned_title = clean_search_title(title)
    ttml_result = fetch_betterlyrics_ttml(cleaned_title, artist, duration_sec)
    if _has_real_syllables(ttml_result):
        # Save a plain LRC to cache so future local hits skip online fetch
        _save_ttml_as_lrc_cache(ttml_result, title, artist)
        return ttml_result

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 4: Spotify spclient (sp_dc cookie) — word-level
    # ──────────────────────────────────────────────────────────────────────
    spotify_result = fetch_spotify_lyrics(cleaned_title, artist, duration_sec)
    if _has_real_syllables(spotify_result):
        return spotify_result
    if _has_synced(spotify_result) and not cached_plain:
        # Spotify returned line-synced — keep it as fallback, still try LRCLIB
        spotify_line_synced = spotify_result
    else:
        spotify_line_synced = None

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 5: LRCLIB /api/get with duration matching
    # ──────────────────────────────────────────────────────────────────────
    lrclib_result = fetch_lrclib(cleaned_title, artist, duration_sec)
    if lrclib_result:
        # Save to cache
        _save_lrc_cache_from_lines(lrclib_result, title, artist)
        return lrclib_result

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 6: syncedlyrics (NetEase → LRCLIB → Musixmatch)
    # ──────────────────────────────────────────────────────────────────────
    try:
        import syncedlyrics

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
                        try:
                            with open(get_cache_path(title, artist), "w", encoding="utf-8") as f:
                                f.write(lrc)
                        except Exception:
                            pass
                        return parsed
            except Exception as e:
                sys.stderr.write(f"[syncedlyrics '{q}']: {e}\n")
    except ImportError:
        sys.stderr.write("[syncedlyrics not installed]\n")

    # Return Spotify line-synced if found earlier
    if spotify_line_synced:
        return spotify_line_synced

    # Return plain cache if we have it
    if cached_plain:
        return cached_plain

    # ──────────────────────────────────────────────────────────────────────
    # TẦNG 7: YouTube Music InnerTube plain lyrics (last resort)
    # ──────────────────────────────────────────────────────────────────────
    if video_id:
        try:
            import ytmusic_helper
            yt_lyrics = ytmusic_helper.get_youtube_lyrics(video_id)
            if yt_lyrics:
                lines = [l.strip() for l in yt_lyrics.split("\n") if l.strip()]
                if lines:
                    return [{
                        "time": idx * 3.5,
                        "endTime": idx * 3.5 + 3.5,
                        "text": line,
                        "hasWords": False,
                        "isSynthetic": True,
                        "words": [],
                    } for idx, line in enumerate(lines)]
        except Exception as ye:
            sys.stderr.write(f"[YouTube lyrics fallback]: {ye}\n")

    # Final fallback: plain DB lyrics
    return db_lyrics or get_lyrics_from_local_db(title, artist, video_id)

# ──────────────────────────────────────────────────────────────────────────────
# Cache write helpers
# ──────────────────────────────────────────────────────────────────────────────

def _save_ttml_as_lrc_cache(lines, title, artist):
    """Serialize TTML-parsed lines back to a basic LRC for local caching."""
    try:
        out = []
        for ln in lines:
            mm = int(ln["time"] // 60)
            ss = ln["time"] % 60
            if ln.get("words"):
                word_tags = "".join(
                    f"<{int(w['start']//60):02d}:{w['start']%60:05.2f}>{w['text']} "
                    for w in ln["words"]
                ).rstrip()
                out.append(f"[{mm:02d}:{ss:05.2f}]{word_tags}")
            else:
                out.append(f"[{mm:02d}:{ss:05.2f}]{ln['text']}")
        path = get_cache_path(title, artist)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(out))
    except Exception:
        pass

def _save_lrc_cache_from_lines(lines, title, artist):
    """Save simple timestamped LRC from parsed line list."""
    try:
        out = []
        for ln in lines:
            mm = int(ln["time"] // 60)
            ss = ln["time"] % 60
            out.append(f"[{mm:02d}:{ss:05.2f}]{ln['text']}")
        path = get_cache_path(title, artist)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(out))
    except Exception:
        pass

# ──────────────────────────────────────────────────────────────────────────────
# CLI entrypoints
# ──────────────────────────────────────────────────────────────────────────────

def handle_cli(args):
    """Entry point for thread-safe in-process execution without modifying sys.argv."""
    if len(args) < 1:
        print("[]")
        return
    title_arg  = args[0] if len(args) > 0 else ""
    artist_arg = args[1] if len(args) > 1 and args[1].strip() != "" else None
    vid_arg    = args[2] if len(args) > 2 and args[2].strip() != "" else None
    path_arg   = args[3] if len(args) > 3 and args[3].strip() != "" else None
    dur_arg    = float(args[4]) if len(args) > 4 and args[4].strip() != "" else None

    res = get_lyrics(title_arg, artist_arg, vid_arg, path_arg, dur_arg)
    print(json.dumps(res, ensure_ascii=False))

def main():
    if len(sys.argv) < 2:
        print("[]")
        return

    title_arg  = sys.argv[1] if len(sys.argv) > 1 else ""
    artist_arg = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].strip() != "" else None
    vid_arg    = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].strip() != "" else None
    path_arg   = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4].strip() != "" else None
    dur_arg    = float(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5].strip() != "" else None

    res = get_lyrics(title_arg, artist_arg, vid_arg, path_arg, dur_arg)
    print(json.dumps(res, ensure_ascii=False))

if __name__ == '__main__':
    main()
