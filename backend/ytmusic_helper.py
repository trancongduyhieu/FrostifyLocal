#!/usr/bin/env python3
"""
Frostify Local YouTube Music Helper
Provides search, stream URL resolution, hybrid personalized home feed,
mood categories, radio generation, and Google Account cookie integration.
"""
import sys
import os
import json
import time
import re
import hashlib

AUTH_FILE = os.path.expanduser("~/.config/noctalia/ytmusic_auth.json")
STREAM_CACHE_FILE = os.path.expanduser("~/.cache/frostify/stream_cache.json")
HOME_CACHE_FILE = os.path.expanduser("~/.cache/frostify/home_feed.json")
ONLINE_TRACKS_FILE = os.path.expanduser("~/.cache/frostify/online_tracks.json")

def load_json(filepath, default=None):
    if os.path.exists(filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return default if default is not None else {}
    return default if default is not None else {}

def save_json(filepath, data):
    try:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

def cache_online_tracks(tracks):
    try:
        data = load_json(ONLINE_TRACKS_FILE, {})
        for t in tracks:
            vid = t.get("videoId")
            if vid:
                data[vid] = t
                data[t.get("path")] = t
        save_json(ONLINE_TRACKS_FILE, data)
    except Exception:
        pass

def get_ytmusic_client():
    from ytmusicapi import YTMusic
    if os.path.exists(AUTH_FILE):
        try:
            return YTMusic(AUTH_FILE)
        except Exception as e:
            sys.stderr.write(f"[ytmusic auth load error]: {e}\n")
    return YTMusic()

def get_auth_status():
    if not os.path.exists(AUTH_FILE):
        return {"logged_in": False, "name": "", "thumb": ""}
    try:
        from ytmusicapi import YTMusic
        yt = YTMusic(AUTH_FILE)
        user = yt.get_account_info()
        name = user.get("accountName") or user.get("name") or "Google User"
        thumbs = user.get("thumbnails", [])
        thumb = thumbs[-1].get("url") if thumbs else ""
        return {"logged_in": True, "name": name, "thumb": thumb}
    except Exception:
        try:
            yt = YTMusic(AUTH_FILE)
            yt.get_home(limit=1)
            return {"logged_in": True, "name": "YouTube Music Account", "thumb": ""}
        except Exception as e:
            return {"logged_in": False, "error": str(e)}

def save_auth(raw_text):
    raw_text = raw_text.strip()
    if not raw_text:
        return {"success": False, "error": "Empty input"}

    try:
        import ytmusicapi
        from ytmusicapi.auth.browser import initialize_headers

        headers = dict(initialize_headers())
        headers["user-agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
        headers["x-goog-authuser"] = "0"

        if "\n" in raw_text and (": " in raw_text or "cookie:" in raw_text.lower()):
            for line in raw_text.splitlines():
                if ": " in line:
                    k, v = line.split(": ", 1)
                    k_lower = k.strip().lower()
                    if k_lower in ("cookie", "authorization", "x-goog-authuser", "user-agent"):
                        headers[k_lower] = v.strip()
        else:
            cookie_str = raw_text
            if cookie_str.lower().startswith("cookie:"):
                cookie_str = cookie_str[7:].strip()
            headers["cookie"] = cookie_str

        if "authorization" not in headers and "cookie" in headers:
            cookie_str = headers["cookie"]
            sapisid = None
            for part in cookie_str.split(";"):
                part = part.strip()
                if "=" in part:
                    k, v = part.split("=", 1)
                    if k.strip() in ("SAPISID", "__Secure-3PAPISID"):
                        sapisid = v.strip().strip('"')
                        break
            if sapisid:
                now_ts = int(time.time())
                hash_input = f"{now_ts} {sapisid} https://music.youtube.com"
                sha1_hash = hashlib.sha1(hash_input.encode("utf-8")).hexdigest()
                headers["authorization"] = f"SAPISIDHASH {now_ts}_{sha1_hash}"

        temp_file = AUTH_FILE + ".tmp"
        save_json(temp_file, headers)

        test_client = ytmusicapi.YTMusic(temp_file)
        test_client.get_home(limit=1)

        os.replace(temp_file, AUTH_FILE)
        return {"success": True, "message": "Connected successfully to YouTube Music"}
    except Exception as e:
        if os.path.exists(AUTH_FILE + ".tmp"):
            try: os.remove(AUTH_FILE + ".tmp")
            except: pass
        return {"success": False, "error": str(e)}

def logout():
    if os.path.exists(AUTH_FILE):
        try:
            os.remove(AUTH_FILE)
            return {"success": True}
        except Exception as e:
            return {"success": False, "error": str(e)}
    return {"success": True}

def normalize_track(item):
    vid = item.get("videoId")
    if not vid:
        return None
    title = item.get("title", "Unknown")
    artists = item.get("artists", [])
    artist_name = ", ".join(a.get("name", "") for a in artists if a.get("name")) or "YouTube Music"
    dur_str = item.get("duration", "--:--")
    dur_sec = item.get("duration_seconds") or 0
    thumbs = item.get("thumbnails", [])
    thumb_url = thumbs[-1].get("url", "") if thumbs else f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"

    if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
        thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

    return {
        "id": f"yt_{vid}",
        "title": title,
        "name": title,
        "artist": artist_name,
        "source": "YouTube Music",
        "path": f"ytdl://{vid}",
        "videoId": vid,
        "duration": dur_str,
        "durationMs": dur_sec * 1000,
        "image": thumb_url
    }

def get_recent_seed_track():
    sess_file = os.path.expanduser("~/.config/noctalia/frostify_session.json")
    if os.path.exists(sess_file):
        try:
            data = load_json(sess_file)
            p = data.get("path", "")
            if p.startswith("ytdl://"):
                return p.replace("ytdl://", "")
        except Exception:
            pass
    return "J7p4bzqLvCw"

def get_personalized_home():
    yt = get_ytmusic_client()
    seed_vid = get_recent_seed_track()

    mood_pills = [
        {"title": "All", "params": ""},
        {"title": "Relax", "params": "ggMPOg1uX1JOQWZFeDByc2Jm"},
        {"title": "Sleep", "params": "ggMPOg1uX0h4T0xYVlR1VHRl"},
        {"title": "Energize", "params": "ggMPOg1uX2lRZUZiMnNrQnJW"},
        {"title": "Sad", "params": "ggMPOg1uX3VRaFdQWFFZRFZB"},
        {"title": "Romance", "params": "ggMPOg1uX0tEZk5zT2pTUTVF"},
        {"title": "Feel Good", "params": "ggMPOg1uXzZQbDB5eThLRTQ3"},
        {"title": "Workout", "params": "ggMPOg1uX096TGJvTjVHTVRX"},
        {"title": "Party", "params": "ggMPOg1uX2pnU0VjTE5kUVVR"},
        {"title": "Commute", "params": "ggMPOg1uX044Z2o5WERLckpU"},
        {"title": "Focus", "params": "ggMPOg1uX0NvNGNhWThMYWRh"}
    ]

    quick_picks = []
    try:
        radio = yt.get_watch_playlist(seed_vid, limit=16)
        raw_tracks = radio.get("tracks", [])
        for t in raw_tracks[:12]:
            norm = normalize_track(t)
            if norm:
                quick_picks.append(norm)
    except Exception as e:
        sys.stderr.write(f"[quick picks error]: {e}\n")

    if not quick_picks:
        quick_picks = search_ytmusic("Trending Vietnam Pop", limit=12)

    cache_online_tracks(quick_picks)

    featured_playlists = []
    try:
        home_sections = yt.get_home(limit=4)
        for sec in home_sections:
            title = sec.get("title", "")
            if "short" in title.lower() or "video" in title.lower():
                continue
            contents = sec.get("contents", [])
            for item in contents[:8]:
                pl_id = item.get("playlistId") or item.get("browseId")
                item_title = item.get("title", "")
                desc = item.get("description") or title
                thumbs = item.get("thumbnails", [])
                thumb_url = thumbs[-1].get("url", "") if thumbs else ""
                if "w120" in thumb_url or "w226" in thumb_url:
                    thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

                if item_title and thumb_url:
                    featured_playlists.append({
                        "id": pl_id or f"pl_{len(featured_playlists)}",
                        "playlistId": pl_id,
                        "title": item_title,
                        "subtitle": desc,
                        "image": thumb_url
                    })
    except Exception as e:
        sys.stderr.write(f"[featured playlists error]: {e}\n")

    res = {
        "moods": mood_pills,
        "quick_picks": quick_picks,
        "featured_playlists": featured_playlists[:14]
    }
    save_json(HOME_CACHE_FILE, res)
    return res

def get_radio(video_id, limit=30):
    if video_id.startswith("ytdl://"):
        video_id = video_id.replace("ytdl://", "")

    yt = get_ytmusic_client()
    try:
        radio = yt.get_watch_playlist(video_id, limit=limit)
        raw_tracks = radio.get("tracks", [])
        tracks = []
        for t in raw_tracks:
            norm = normalize_track(t)
            if norm:
                tracks.append(norm)
        cache_online_tracks(tracks)
        return tracks
    except Exception as e:
        sys.stderr.write(f"[get_radio error for {video_id}]: {e}\n")
        return []

def get_mood_feed(params):
    yt = get_ytmusic_client()
    try:
        raw_playlists = yt.get_mood_playlists(params)
        playlists = []
        for item in raw_playlists[:16]:
            pl_id = item.get("playlistId")
            title = item.get("title", "")
            thumbs = item.get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else ""
            if "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
            if pl_id and title:
                playlists.append({
                    "id": pl_id,
                    "playlistId": pl_id,
                    "title": title,
                    "subtitle": item.get("description") or "Playlist",
                    "image": thumb_url
                })
        return playlists
    except Exception as e:
        sys.stderr.write(f"[get_mood_feed error]: {e}\n")
        return []

def get_playlist_tracks(playlist_id, limit=50):
    yt = get_ytmusic_client()
    try:
        pl = yt.get_playlist(playlist_id, limit=limit)
        raw_tracks = pl.get("tracks", [])
        tracks = []
        for t in raw_tracks:
            norm = normalize_track(t)
            if norm:
                tracks.append(norm)
        cache_online_tracks(tracks)
        return tracks
    except Exception as e:
        sys.stderr.write(f"[get_playlist_tracks error]: {e}\n")
        return []

def search_ytmusic(query, limit=20):
    if not query or not query.strip():
        query = "Trending Music"

    try:
        ytm = get_ytmusic_client()
        raw = ytm.search(query.strip(), filter="songs")
        tracks = []
        for item in raw[:limit]:
            norm = normalize_track(item)
            if norm:
                tracks.append(norm)
        cache_online_tracks(tracks)
        return tracks
    except Exception as e:
        sys.stderr.write(f"[ytmusic search error]: {e}\n")
        return []

def resolve_stream_url(video_id):
    if not video_id:
        return None

    if video_id.startswith("ytdl://"):
        video_id = video_id.replace("ytdl://", "")
    elif "watch?v=" in video_id:
        video_id = video_id.split("watch?v=")[1].split("&")[0]

    cache = load_json(STREAM_CACHE_FILE, {})
    cached = cache.get(video_id)
    now = time.time()

    if cached and (now - cached.get("timestamp", 0)) < 10800:
        return cached

    try:
        from yt_dlp.networking.impersonate import ImpersonateTarget
        import yt_dlp

        target = ImpersonateTarget.from_str("chrome")
        ydl_opts = {
            "format": "ba",
            "impersonate": target,
            "quiet": True,
            "no_warnings": True
        }
        url = f"https://www.youtube.com/watch?v={video_id}"
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            stream_url = info.get("url")
            duration = info.get("duration") or 0
            if stream_url:
                res = {
                    "stream_url": stream_url,
                    "duration": duration,
                    "timestamp": now
                }
                cache[video_id] = res
                save_json(STREAM_CACHE_FILE, cache)
                return res
    except Exception as e:
        sys.stderr.write(f"[resolve_stream_url error for {video_id}]: {e}\n")

    return None

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ytmusic_helper.py [home | radio <id> | mood <params> | playlist <id> | search <q> | get_url <id> | auth_status | save_auth <text> | logout]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "home":
        res = get_personalized_home()
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "radio" and len(sys.argv) > 2:
        vid = sys.argv[2]
        res = get_radio(vid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "mood" and len(sys.argv) > 2:
        params = sys.argv[2]
        res = get_mood_feed(params)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "playlist" and len(sys.argv) > 2:
        pl_id = sys.argv[2]
        res = get_playlist_tracks(pl_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "search":
        q = sys.argv[2] if len(sys.argv) > 2 else "Trending"
        res = search_ytmusic(q)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "get_url":
        vid = sys.argv[2] if len(sys.argv) > 2 else ""
        res = resolve_stream_url(vid)
        print(json.dumps(res or {}, ensure_ascii=False))

    elif cmd == "auth_status":
        res = get_auth_status()
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "save_auth" and len(sys.argv) > 2:
        text = sys.argv[2]
        res = save_auth(text)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "logout":
        res = logout()
        print(json.dumps(res, ensure_ascii=False))
