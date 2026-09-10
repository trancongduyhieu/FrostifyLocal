#!/usr/bin/env python3
"""
Frostify Local YouTube Music Helper
Searches tracks and resolves direct Opus stream URLs via ytmusicapi + yt-dlp (curl_cffi impersonate)
"""
import sys
import os
import json
import time
import re

CACHE_FILE = os.path.expanduser("~/.cache/frostify/stream_cache.json")

def load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_cache(cache):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(cache, f)
    except Exception:
        pass

ONLINE_TRACKS_FILE = os.path.expanduser("~/.cache/frostify/online_tracks.json")

def cache_online_tracks(tracks):
    try:
        data = {}
        if os.path.exists(ONLINE_TRACKS_FILE):
            try:
                with open(ONLINE_TRACKS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except Exception:
                data = {}
        for t in tracks:
            vid = t.get("videoId")
            if vid:
                data[vid] = t
                data[t.get("path")] = t
        with open(ONLINE_TRACKS_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
    except Exception:
        pass

def search_ytmusic(query, limit=20):
    if not query or not query.strip():
        query = "Trending Music"

    try:
        from ytmusicapi import YTMusic
        ytm = YTMusic()
        raw = ytm.search(query.strip(), filter="songs")
        tracks = []
        for item in raw[:limit]:
            vid = item.get("videoId")
            if not vid:
                continue
            title = item.get("title", "Unknown")
            artists = item.get("artists", [])
            artist_name = ", ".join(a.get("name", "") for a in artists if a.get("name")) or "YouTube Music"
            dur_str = item.get("duration", "--:--")
            dur_sec = item.get("duration_seconds") or 0
            thumbs = item.get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"

            # Use high-res thumbnail if possible
            if "w60" in thumb_url or "w120" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

            tracks.append({
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
            })
        cache_online_tracks(tracks)
        return tracks
    except Exception as e:
        sys.stderr.write(f"[ytmusic search error]: {e}\n")
        return []

def resolve_stream_url(video_id):
    if not video_id:
        return None

    # Strip prefix if present
    if video_id.startswith("ytdl://"):
        video_id = video_id.replace("ytdl://", "")
    elif "watch?v=" in video_id:
        video_id = video_id.split("watch?v=")[1].split("&")[0]

    cache = load_cache()
    cached = cache.get(video_id)
    now = time.time()

    # Cache valid for 3 hours (10800s)
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
                save_cache(cache)
                return res
    except Exception as e:
        sys.stderr.write(f"[resolve_stream_url error for {video_id}]: {e}\n")

    return None

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ytmusic_helper.py search <query> | get_url <video_id>")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "search":
        q = sys.argv[2] if len(sys.argv) > 2 else "Trending"
        res = search_ytmusic(q)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "get_url":
        vid = sys.argv[2] if len(sys.argv) > 2 else ""
        res = resolve_stream_url(vid)
        print(json.dumps(res or {}, ensure_ascii=False))
