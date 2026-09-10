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
MOOD_CACHE_DIR = os.path.expanduser("~/.cache/frostify/moods")
MOOD_CATS_FILE = os.path.expanduser("~/.cache/frostify/mood_categories.json")

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
    if isinstance(raw_text, dict):
        raw_text = "; ".join(f"{k}={v}" for k, v in raw_text.items())
    raw_text = str(raw_text).strip()
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
        try:
            with open("/tmp/frostify_auth_changed", "w") as f:
                f.write(str(time.time()))
        except Exception:
            pass
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
        except Exception:
            pass
    try:
        with open("/tmp/frostify_auth_changed", "w") as f:
            f.write(str(time.time()))
    except Exception:
        pass
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

DEFAULT_MOOD_PILLS = [
    {"title": "All", "params": ""},
    {"title": "Relax", "params": "ggM8SgQIBxADSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Sleep", "params": "ggM8SgQIBxABSgQIBRADSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Energize", "params": "ggM8SgQIBxABSgQIBRABSgQICRADSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Sad", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChADSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Romance", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRADSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Party", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhADSgQIAxABSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Commute", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxADSgQICBABSgQIBhABSgQIBBAB"},
    {"title": "Feel good", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBADSgQIBhABSgQIBBAB"},
    {"title": "Focus", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhADSgQIBBAB"},
    {"title": "Workout", "params": "ggM8SgQIBxABSgQIBRABSgQICRABSgQIChABSgQIDRABSgQIDhABSgQIAxABSgQICBABSgQIBhABSgQIBBAD"}
]

def get_mood_categories_live():
    cached = load_json(MOOD_CATS_FILE, None)
    if cached and (time.time() - cached.get("timestamp", 0)) < 86400:
        return cached.get("categories", DEFAULT_MOOD_PILLS)
    return DEFAULT_MOOD_PILLS

def get_personalized_home():
    cached = load_json(HOME_CACHE_FILE, None)
    if cached and (time.time() - cached.get("timestamp", 0)) < 1800:
        if cached.get("quick_picks") or cached.get("featured_playlists"):
            return cached

    yt = get_ytmusic_client()
    quick_picks = []
    featured_playlists = []
    dynamic_moods = []

    try:
        home_res = yt._send_request("browse", {"browseId": "FEmusic_home"})

        # 1. Extract dynamic mood chips directly from user's account home
        try:
            from ytmusicapi.navigation import nav, SINGLE_COLUMN_TAB
            chip_cloud = nav(home_res, [*SINGLE_COLUMN_TAB, "sectionListRenderer", "header", "chipCloudRenderer", "chips"], True)
            if chip_cloud:
                for c in chip_cloud:
                    chip = c.get("chipCloudChipRenderer", {})
                    chip_title = "".join(r.get("text", "") for r in chip.get("text", {}).get("runs", []))
                    chip_params = chip.get("navigationEndpoint", {}).get("browseEndpoint", {}).get("params", "")
                    if chip_title and chip_params:
                        dynamic_moods.append({"title": chip_title, "params": chip_params})
        except Exception as e:
            sys.stderr.write(f"[chip extract error]: {e}\n")

        # 2. Extract sections
        sections = home_res.get("contents", {}).get("singleColumnBrowseResultsRenderer", {}).get("tabs", [{}])[0].get("tabRenderer", {}).get("content", {}).get("sectionListRenderer", {}).get("contents", [])

        for s in sections:
            shelf = s.get("musicCarouselShelfRenderer") or s.get("musicShelfRenderer")
            if not shelf:
                continue
            header = shelf.get("header", {}).get("musicCarouselShelfBasicHeaderRenderer", {})
            shelf_title = "".join(r.get("text", "") for r in header.get("title", {}).get("runs", []))
            items = shelf.get("contents", [])

            for it in items:
                # musicResponsiveListItemRenderer (Quick picks)
                if "musicResponsiveListItemRenderer" in it:
                    r = it["musicResponsiveListItemRenderer"]
                    vid = r.get("playlistItemData", {}).get("videoId")
                    cols = r.get("flexColumns", [])
                    title = "".join(x.get("text", "") for x in cols[0].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])) if cols else ""
                    artist = ""
                    if len(cols) > 1:
                        artist_runs = cols[1].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])
                        artist = "".join(x.get("text", "") for x in artist_runs if "views" not in x.get("text", "").lower() and "plays" not in x.get("text", "").lower()).strip(" • ")
                    thumbs = r.get("thumbnail", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
                    thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
                    if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
                        thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
                    if vid and title and len(quick_picks) < 20:
                        if not any(q.get("videoId") == vid for q in quick_picks):
                            quick_picks.append({
                                "id": f"yt_{vid}",
                                "title": title,
                                "name": title,
                                "artist": artist or "YouTube Music",
                                "source": "YouTube Music",
                                "path": f"ytdl://{vid}",
                                "videoId": vid,
                                "duration": "--:--",
                                "durationMs": 0,
                                "image": thumb_url
                            })

                # musicTwoRowItemRenderer (Listen again, Mixes, Playlists)
                elif "musicTwoRowItemRenderer" in it:
                    r = it["musicTwoRowItemRenderer"]
                    title = "".join(x.get("text", "") for x in r.get("title", {}).get("runs", []))
                    sub = "".join(x.get("text", "") for x in r.get("subtitle", {}).get("runs", []))
                    thumbs = r.get("thumbnailRenderer", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
                    thumb_url = thumbs[-1].get("url", "") if thumbs else ""
                    if "w120" in thumb_url or "w226" in thumb_url:
                        thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

                    nav_ep = r.get("navigationEndpoint", {})
                    watch_ep = nav_ep.get("watchEndpoint", {})
                    browse_ep = nav_ep.get("browseEndpoint", {})

                    vid = watch_ep.get("videoId")
                    pl_id = watch_ep.get("playlistId") or browse_ep.get("browseId")

                    # If it has videoId and is in "Listen again", treat as track
                    if vid and (not pl_id or "listen again" in shelf_title.lower()):
                        if len(quick_picks) < 20 and not any(q.get("videoId") == vid for q in quick_picks):
                            quick_picks.append({
                                "id": f"yt_{vid}",
                                "title": title,
                                "name": title,
                                "artist": sub or "YouTube Music",
                                "source": "YouTube Music",
                                "path": f"ytdl://{vid}",
                                "videoId": vid,
                                "duration": "--:--",
                                "durationMs": 0,
                                "image": thumb_url
                            })
                    elif pl_id and title and thumb_url:
                        if len(featured_playlists) < 18 and not any(p.get("title") == title for p in featured_playlists):
                            featured_playlists.append({
                                "id": pl_id,
                                "playlistId": pl_id,
                                "title": title,
                                "subtitle": sub or shelf_title or "Playlist",
                                "image": thumb_url
                            })
    except Exception as e:
        sys.stderr.write(f"[personalized home error]: {e}\n")

    mood_pills = [{"title": "All", "params": ""}] + (dynamic_moods if dynamic_moods else DEFAULT_MOOD_PILLS[1:])
    save_json(MOOD_CATS_FILE, {"timestamp": time.time(), "categories": mood_pills})

    # Fallback for quick picks if empty
    if not quick_picks:
        seed_vid = get_recent_seed_track()
        try:
            radio = yt.get_watch_playlist(seed_vid, limit=16)
            for t in radio.get("tracks", [])[:12]:
                norm = normalize_track(t)
                if norm:
                    quick_picks.append(norm)
        except Exception:
            pass

    if not quick_picks:
        quick_picks = search_ytmusic("Trending Music", limit=12)

    cache_online_tracks(quick_picks)

    # Load all existing cached moods from ~/.cache/frostify/moods/ into preloaded_moods for 0ms QML startup
    preloaded = {}
    if os.path.exists(MOOD_CACHE_DIR):
        for f in os.listdir(MOOD_CACHE_DIR):
            if f.endswith(".json"):
                m_data = load_json(os.path.join(MOOD_CACHE_DIR, f))
                if m_data and (m_data.get("quick_picks") or m_data.get("featured_playlists")):
                    m_title = f.split("_")[0]
                    preloaded[m_title] = m_data

    res = {
        "timestamp": time.time(),
        "moods": mood_pills,
        "quick_picks": quick_picks[:16],
        "featured_playlists": featured_playlists[:40],
        "preloaded_moods": preloaded
    }
    save_json(HOME_CACHE_FILE, res)

    # Pre-warm top moods in background thread for 0ms disk cache hits
    def _prewarm():
        for pill in mood_pills[1:6]:
            p = pill.get("params")
            t = pill.get("title")
            if p and t != "All":
                try:
                    get_mood_feed(p, t)
                except Exception:
                    pass

    import threading
    threading.Thread(target=_prewarm, daemon=True).start()

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

def _process_mood_items(items, shelf_title, quick_picks, featured_playlists, max_qp=30, max_fp=60):
    for it in items:
        if not isinstance(it, dict):
            continue
        if "musicResponsiveListItemRenderer" in it:
            r = it["musicResponsiveListItemRenderer"]
            vid = r.get("playlistItemData", {}).get("videoId")
            cols = r.get("flexColumns", [])
            title_text = "".join(x.get("text", "") for x in cols[0].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])) if cols else ""
            artist = ""
            if len(cols) > 1:
                artist_runs = cols[1].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])
                artist = "".join(x.get("text", "") for x in artist_runs if "views" not in x.get("text", "").lower() and "plays" not in x.get("text", "").lower()).strip(" • ")
            thumbs = r.get("thumbnail", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
            if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
            if vid and title_text and len(quick_picks) < max_qp:
                if not any(q.get("videoId") == vid for q in quick_picks):
                    quick_picks.append({
                        "id": f"yt_{vid}",
                        "title": title_text,
                        "name": title_text,
                        "artist": artist or "YouTube Music",
                        "source": "YouTube Music",
                        "path": f"ytdl://{vid}",
                        "videoId": vid,
                        "duration": "--:--",
                        "durationMs": 0,
                        "image": thumb_url
                    })
        elif "musicTwoRowItemRenderer" in it:
            r = it["musicTwoRowItemRenderer"]
            t_text = "".join(x.get("text", "") for x in r.get("title", {}).get("runs", []))
            sub = "".join(x.get("text", "") for x in r.get("subtitle", {}).get("runs", []))
            thumbs = r.get("thumbnailRenderer", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else ""
            if "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

            nav_ep = r.get("navigationEndpoint", {})
            watch_ep = nav_ep.get("watchEndpoint", {})
            browse_ep = nav_ep.get("browseEndpoint", {})

            vid = watch_ep.get("videoId")
            pl_id = watch_ep.get("playlistId") or browse_ep.get("browseId")

            if vid and (not pl_id or "listen again" in shelf_title.lower()):
                if len(quick_picks) < max_qp and not any(q.get("videoId") == vid for q in quick_picks):
                    quick_picks.append({
                        "id": f"yt_{vid}",
                        "title": t_text,
                        "name": t_text,
                        "artist": sub or "YouTube Music",
                        "source": "YouTube Music",
                        "path": f"ytdl://{vid}",
                        "videoId": vid,
                        "duration": "--:--",
                        "durationMs": 0,
                        "image": thumb_url
                    })
            elif pl_id and t_text and thumb_url:
                if len(featured_playlists) < max_fp and not any(p.get("title") == t_text for p in featured_playlists):
                    featured_playlists.append({
                        "id": pl_id,
                        "playlistId": pl_id,
                        "title": t_text,
                        "subtitle": sub or shelf_title or "Playlist",
                        "image": thumb_url
                    })
        elif isinstance(it, dict) and (it.get("playlistId") or it.get("browseId")):
            pl_id = it.get("playlistId") or it.get("browseId")
            t_text = it.get("title", "")
            thumbs = it.get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else ""
            if "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
            if pl_id and t_text and thumb_url:
                if len(featured_playlists) < max_fp and not any(p.get("title") == t_text for p in featured_playlists):
                    featured_playlists.append({
                        "id": pl_id,
                        "playlistId": pl_id,
                        "title": t_text,
                        "subtitle": it.get("description") or shelf_title or "Playlist",
                        "image": thumb_url
                    })
        elif isinstance(it, dict) and it.get("videoId"):
            vid = it.get("videoId")
            t_text = it.get("title", "")
            artist = ", ".join(a.get("name", "") for a in it.get("artists", [])) if it.get("artists") else ""
            thumbs = it.get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
            if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
            if vid and t_text and len(quick_picks) < max_qp:
                if not any(q.get("videoId") == vid for q in quick_picks):
                    quick_picks.append({
                        "id": f"yt_{vid}",
                        "title": t_text,
                        "name": t_text,
                        "artist": artist or shelf_title or "YouTube Music",
                        "source": "YouTube Music",
                        "path": f"ytdl://{vid}",
                        "videoId": vid,
                        "duration": "--:--",
                        "durationMs": 0,
                        "image": thumb_url
                    })

def get_mood_feed(params, title=""):
    if (not params or params == "") and title and title != "All":
        cats = get_mood_categories_live()
        for c in cats:
            if c.get("title", "").lower() == title.lower():
                params = c.get("params", "")
                break

    if not params or title == "All":
        return get_personalized_home()

    os.makedirs(MOOD_CACHE_DIR, exist_ok=True)
    slug = re.sub(r'[^a-zA-Z0-9_-]', '_', f"{title}_{params[:16]}" if params else title)
    cache_path = os.path.join(MOOD_CACHE_DIR, f"{slug}.json")

    # Instant cache return (valid for 3 hours)
    cached = load_json(cache_path, None)
    if cached and (time.time() - cached.get("timestamp", 0)) < 10800:
        if cached.get("quick_picks") or cached.get("featured_playlists"):
            return cached

    yt = get_ytmusic_client()
    quick_picks = []
    featured_playlists = []

    try:
        # Native personalized mood browse via FEmusic_home with params
        endpoint = "browse"
        body = {"browseId": "FEmusic_home", "params": params}
        res = yt._send_request(endpoint, body)

        # 1. Process initial sections
        raw_sections = res.get("contents", {}).get("singleColumnBrowseResultsRenderer", {}).get("tabs", [{}])[0].get("tabRenderer", {}).get("content", {}).get("sectionListRenderer", {}).get("contents", [])
        for s in raw_sections:
            shelf = s.get("musicCarouselShelfRenderer") or s.get("musicShelfRenderer")
            if not shelf:
                continue
            header = shelf.get("header", {}).get("musicCarouselShelfBasicHeaderRenderer", {})
            shelf_title = "".join(r.get("text", "") for r in header.get("title", {}).get("runs", []))
            _process_mood_items(shelf.get("contents", []), shelf_title, quick_picks, featured_playlists)

        # 2. Process continuation sections (SimpMusic continuation scraper for 50+ playlists)
        from ytmusicapi.navigation import nav, SINGLE_COLUMN_TAB
        from ytmusicapi.parsers.browsing import parse_mixed_content
        from ytmusicapi.continuations import get_continuations

        section_list = nav(res, [*SINGLE_COLUMN_TAB, "sectionListRenderer"], True)
        if section_list and "continuations" in section_list:
            try:
                request_func = lambda additionalParams: yt._send_request(endpoint, body, additionalParams)
                conts = get_continuations(section_list, "sectionListContinuation", 10, request_func, parse_mixed_content)
                for c_sec in conts:
                    c_title = c_sec.get("title", "")
                    _process_mood_items(c_sec.get("contents", []), c_title, quick_picks, featured_playlists)
            except Exception as e:
                sys.stderr.write(f"[continuations error for {title}]: {e}\n")
    except Exception as e:
        sys.stderr.write(f"[personalized mood browse error for {title}]: {e}\n")

    # If featured_playlists has fewer than 6, supplement from official mood playlists
    if len(featured_playlists) < 6 and params:
        try:
            raw_playlists = yt.get_mood_playlists(params)
            for item in raw_playlists[:12]:
                pl_id = item.get("playlistId")
                pl_title = item.get("title", "")
                thumbs = item.get("thumbnails", [])
                thumb_url = thumbs[-1].get("url", "") if thumbs else ""
                if "w120" in thumb_url or "w226" in thumb_url:
                    thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
                if pl_id and pl_title and not any(p.get("title") == pl_title for p in featured_playlists):
                    featured_playlists.append({
                        "id": pl_id,
                        "playlistId": pl_id,
                        "title": pl_title,
                        "subtitle": item.get("description") or "Playlist",
                        "image": thumb_url
                    })
        except Exception as e:
            sys.stderr.write(f"[mood playlist fallback error for {title}]: {e}\n")

    # If quick_picks is empty, extract from top playlist
    if not quick_picks and featured_playlists:
        for pl in featured_playlists[:2]:
            try:
                top_tracks = get_playlist_tracks(pl["playlistId"], limit=12)
                if top_tracks:
                    quick_picks = top_tracks
                    break
            except Exception:
                pass

    cache_online_tracks(quick_picks)

    result = {
        "timestamp": time.time(),
        "quick_picks": quick_picks[:30],
        "featured_playlists": featured_playlists[:60]
    }
    save_json(cache_path, result)
    return result

def get_playlist_tracks(playlist_id, limit=50):
    if not playlist_id:
        return []
    yt = get_ytmusic_client()
    raw_tracks = []

    # Radio and automix playlists have IDs starting with RD or VLRD
    if playlist_id.startswith("RD") or playlist_id.startswith("VLRD"):
        try:
            res = yt.get_watch_playlist(playlistId=playlist_id, limit=limit)
            raw_tracks = res.get("tracks", [])
        except Exception as e:
            sys.stderr.write(f"[get_watch_playlist for {playlist_id} error]: {e}\n")

    if not raw_tracks:
        try:
            pl = yt.get_playlist(playlist_id, limit=limit)
            raw_tracks = pl.get("tracks", [])
        except Exception as e:
            # Fallback to watch playlist if standard get_playlist throws
            try:
                res = yt.get_watch_playlist(playlistId=playlist_id, limit=limit)
                raw_tracks = res.get("tracks", [])
            except Exception as e2:
                sys.stderr.write(f"[get_playlist_tracks error for {playlist_id}]: {e} | {e2}\n")

    tracks = []
    for t in raw_tracks:
        norm = normalize_track(t)
        if norm:
            tracks.append(norm)
    cache_online_tracks(tracks)
    return tracks

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

def get_search_suggestions(query):
    if not query or not query.strip():
        return []
    try:
        yt = get_ytmusic_client()
        return yt.get_search_suggestions(query.strip())
    except Exception as e:
        sys.stderr.write(f"[get_search_suggestions error]: {e}\n")
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
        title = sys.argv[3] if len(sys.argv) > 3 else ""
        res = get_mood_feed(params, title)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "playlist" and len(sys.argv) > 2:
        pl_id = sys.argv[2]
        res = get_playlist_tracks(pl_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "search":
        q = sys.argv[2] if len(sys.argv) > 2 else "Trending"
        res = search_ytmusic(q)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "suggestions" and len(sys.argv) > 2:
        q = sys.argv[2]
        res = get_search_suggestions(q)
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
