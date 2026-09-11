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
import urllib.request

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

DISLIKED_SONGS_FILE = os.path.expanduser("~/.config/noctalia/frostify_disliked_songs.json")

def load_disliked_songs():
    return load_json(DISLIKED_SONGS_FILE, {})

def save_disliked_songs(data):
    save_json(DISLIKED_SONGS_FILE, data)

def add_disliked_song(video_id, title="", artist=""):
    clean_vid = str(video_id).strip().replace("ytdl://", "").replace("yt_", "")
    if not clean_vid:
        return False
    data = load_disliked_songs()
    data[clean_vid] = {
        "videoId": clean_vid,
        "title": title,
        "artist": artist,
        "timestamp": int(time.time())
    }
    save_disliked_songs(data)
    return True

def remove_disliked_song(video_id):
    clean_vid = str(video_id).strip().replace("ytdl://", "").replace("yt_", "")
    if not clean_vid:
        return False
    data = load_disliked_songs()
    if clean_vid in data:
        del data[clean_vid]
        save_disliked_songs(data)
    return True

def is_song_disliked(video_id):
    if not video_id:
        return False
    clean_vid = str(video_id).strip().replace("ytdl://", "").replace("yt_", "")
    data = load_disliked_songs()
    return clean_vid in data

ARTIST_AVATARS_FILE = os.path.expanduser("~/.cache/frostify/artist_avatars.json")

def load_artist_avatars():
    return load_json(ARTIST_AVATARS_FILE, {})

def save_artist_avatars(data):
    save_json(ARTIST_AVATARS_FILE, data)

def cache_artist_avatar(artist_name, avatar_url):
    if not artist_name or not avatar_url:
        return
    norm = str(artist_name).strip().lower()
    data = load_artist_avatars()
    if data.get(norm) != avatar_url:
        data[norm] = avatar_url
        save_artist_avatars(data)

def get_cached_artist_avatar(artist_name):
    if not artist_name:
        return ""
    norm = str(artist_name).strip().lower()
    return load_artist_avatars().get(norm, "")


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
    if not vid or is_song_disliked(vid):
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

def _normalize_shelf_item(it, shelf_title=""):
    if not isinstance(it, dict):
        return None

    # 1. musicResponsiveListItemRenderer
    if "musicResponsiveListItemRenderer" in it:
        r = it["musicResponsiveListItemRenderer"]
        vid = r.get("playlistItemData", {}).get("videoId")
        if vid and is_song_disliked(vid):
            return None
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
        if vid and title:
            return {
                "id": f"yt_{vid}",
                "type": "track",
                "title": title,
                "name": title,
                "artist": artist or "YouTube Music",
                "subtitle": artist or "YouTube Music",
                "source": "YouTube Music",
                "path": f"ytdl://{vid}",
                "videoId": vid,
                "duration": "--:--",
                "durationMs": 0,
                "image": thumb_url
            }

    # 2. musicTwoRowItemRenderer
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
        if vid and is_song_disliked(vid):
            return None
        pl_id = watch_ep.get("playlistId") or browse_ep.get("browseId")

        if vid and (not pl_id or "listen" in shelf_title.lower() or "favorite" in shelf_title.lower()):
            return {
                "id": f"yt_{vid}",
                "type": "track",
                "title": title,
                "name": title,
                "artist": sub or "YouTube Music",
                "subtitle": sub or "YouTube Music",
                "source": "YouTube Music",
                "path": f"ytdl://{vid}",
                "videoId": vid,
                "duration": "--:--",
                "durationMs": 0,
                "image": thumb_url
            }
        elif pl_id and title:
            return {
                "id": pl_id,
                "type": "playlist",
                "playlistId": pl_id,
                "title": title,
                "subtitle": sub or shelf_title or "Playlist",
                "image": thumb_url
            }

    # 3. Parsed item (from parse_mixed_content)
    elif isinstance(it, dict):
        vid = it.get("videoId")
        pl_id = it.get("playlistId") or it.get("browseId") or it.get("audioPlaylistId")
        title = it.get("title", "")
        thumbs = it.get("thumbnails", [])
        thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
        if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
            thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

        artist = ""
        if it.get("artists"):
            artist = ", ".join(a.get("name", "") for a in it.get("artists", []) if isinstance(a, dict))
        elif it.get("description"):
            artist = it.get("description")

        if vid and (not pl_id or "song" in str(it.get("videoType", "")).lower() or "atv" in str(it.get("videoType", "")).lower() or "listen" in shelf_title.lower() or "quick" in shelf_title.lower() or "cover" in shelf_title.lower() or "video" in shelf_title.lower() or "trending" in shelf_title.lower() or "favorite" in shelf_title.lower() or "long" in shelf_title.lower()):
            return {
                "id": f"yt_{vid}",
                "type": "track",
                "title": title,
                "name": title,
                "artist": artist or "YouTube Music",
                "subtitle": artist or "YouTube Music",
                "source": "YouTube Music",
                "path": f"ytdl://{vid}",
                "videoId": vid,
                "duration": it.get("duration", "--:--"),
                "durationMs": (it.get("duration_seconds") or 0) * 1000,
                "image": thumb_url
            }
        elif pl_id and title:
            return {
                "id": pl_id,
                "type": "playlist",
                "playlistId": pl_id,
                "title": title,
                "subtitle": artist or shelf_title or "Playlist",
                "image": thumb_url
            }
    return None

def get_personalized_home():
    cached = load_json(HOME_CACHE_FILE, None)
    if cached and (time.time() - cached.get("timestamp", 0)) < 1800:
        if cached.get("sections") and (cached.get("quick_picks") or cached.get("featured_playlists")):
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

        # 2. Extract initial sections
        raw_sections = home_res.get("contents", {}).get("singleColumnBrowseResultsRenderer", {}).get("tabs", [{}])[0].get("tabRenderer", {}).get("content", {}).get("sectionListRenderer", {}).get("contents", [])

        shelves = []
        for s in raw_sections:
            shelf = s.get("musicCarouselShelfRenderer") or s.get("musicShelfRenderer")
            if shelf:
                header = shelf.get("header", {}).get("musicCarouselShelfBasicHeaderRenderer", {})
                t = "".join(r.get("text", "") for r in header.get("title", {}).get("runs", []))
                sub = "".join(r.get("text", "") for r in header.get("strapline", {}).get("runs", []))
                shelves.append((t, sub, shelf.get("contents", [])))

        # 3. Extract continuation sections (up to 12 continuation shelves)
        from ytmusicapi.navigation import nav, SINGLE_COLUMN_TAB
        from ytmusicapi.continuations import get_continuations
        from ytmusicapi.parsers.browsing import parse_mixed_content

        section_list = nav(home_res, [*SINGLE_COLUMN_TAB, "sectionListRenderer"], True)
        if section_list and "continuations" in section_list:
            try:
                request_func = lambda additionalParams: yt._send_request("browse", {"browseId": "FEmusic_home"}, additionalParams)
                conts = get_continuations(section_list, "sectionListContinuation", 12, request_func, parse_mixed_content)
                for c in conts:
                    shelves.append((c.get("title", ""), "", c.get("contents", [])))
            except Exception as e:
                sys.stderr.write(f"[home continuations error]: {e}\n")

        final_sections = []
        all_tracks_discovered = []
        for title, subtitle, items in shelves:
            if not title or not items or (len(items) <= 1 and "together" in title.lower()):
                continue
            norm_items = []
            track_count = 0
            for it in items:
                norm = _normalize_shelf_item(it, title)
                if norm:
                    norm_items.append(norm)
                    if norm.get("type") == "track":
                        track_count += 1
                        if not any(q.get("videoId") == norm.get("videoId") for q in quick_picks) and len(quick_picks) < 24:
                            quick_picks.append(norm)
                        if not any(q.get("videoId") == norm.get("videoId") for q in all_tracks_discovered):
                            all_tracks_discovered.append(norm)
                    elif norm.get("type") == "playlist":
                        if not any(p.get("id") == norm.get("id") or p.get("title") == norm.get("title") for p in featured_playlists):
                            featured_playlists.append(norm)

            if not norm_items:
                continue

            is_grid = False
            lower_t = title.lower()
            if "quick" in lower_t or "cover" in lower_t or "trending" in lower_t or "long" in lower_t:
                is_grid = True
            elif "listen again" in lower_t or "video" in lower_t or "favorite" in lower_t or "release" in lower_t or "playlist" in lower_t:
                is_grid = False
            elif track_count > len(norm_items) * 0.7:
                is_grid = True

            final_sections.append({
                "title": title,
                "subtitle": subtitle,
                "type": "track_grid" if is_grid else "card_carousel",
                "items": norm_items
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
    if 'all_tracks_discovered' in locals() and all_tracks_discovered:
        cache_online_tracks(all_tracks_discovered)

    # Load all existing cached moods from ~/.cache/frostify/moods/ into preloaded_moods for 0ms QML startup
    preloaded = {}
    if os.path.exists(MOOD_CACHE_DIR):
        for f in os.listdir(MOOD_CACHE_DIR):
            if f.endswith(".json"):
                m_data = load_json(os.path.join(MOOD_CACHE_DIR, f))
                if m_data and m_data.get("sections") and (m_data.get("quick_picks") or m_data.get("featured_playlists")):
                    m_title = f.split("_")[0]
                    preloaded[m_title] = m_data

    res = {
        "timestamp": time.time(),
        "moods": mood_pills,
        "sections": final_sections if 'final_sections' in locals() and final_sections else [],
        "quick_picks": quick_picks[:20],
        "featured_playlists": featured_playlists[:50],
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
        if cached.get("sections") and (cached.get("quick_picks") or cached.get("featured_playlists")):
            return cached

    yt = get_ytmusic_client()
    quick_picks = []
    featured_playlists = []
    final_sections = []

    try:
        # Native personalized mood browse via FEmusic_home with params
        endpoint = "browse"
        body = {"browseId": "FEmusic_home", "params": params}
        res = yt._send_request(endpoint, body)

        shelves = []
        raw_sections = res.get("contents", {}).get("singleColumnBrowseResultsRenderer", {}).get("tabs", [{}])[0].get("tabRenderer", {}).get("content", {}).get("sectionListRenderer", {}).get("contents", [])
        for s in raw_sections:
            shelf = s.get("musicCarouselShelfRenderer") or s.get("musicShelfRenderer")
            if not shelf:
                continue
            header = shelf.get("header", {}).get("musicCarouselShelfBasicHeaderRenderer", {})
            t = "".join(r.get("text", "") for r in header.get("title", {}).get("runs", []))
            sub = "".join(r.get("text", "") for r in header.get("strapline", {}).get("runs", []))
            shelves.append((t, sub, shelf.get("contents", [])))

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
                    shelves.append((c_sec.get("title", ""), "", c_sec.get("contents", [])))
            except Exception as e:
                sys.stderr.write(f"[continuations error for {title}]: {e}\n")

        all_tracks_discovered = []
        for s_title, s_sub, s_items in shelves:
            if not s_title or not s_items or (len(s_items) <= 1 and "together" in s_title.lower()):
                continue
            norm_items = []
            track_count = 0
            for it in s_items:
                norm = _normalize_shelf_item(it, s_title)
                if norm:
                    norm_items.append(norm)
                    if norm.get("type") == "track":
                        track_count += 1
                        if not any(q.get("videoId") == norm.get("videoId") for q in quick_picks) and len(quick_picks) < 30:
                            quick_picks.append(norm)
                        if not any(q.get("videoId") == norm.get("videoId") for q in all_tracks_discovered):
                            all_tracks_discovered.append(norm)
                    elif norm.get("type") == "playlist":
                        if not any(p.get("id") == norm.get("id") or p.get("title") == norm.get("title") for p in featured_playlists):
                            featured_playlists.append(norm)

            if not norm_items:
                continue

            is_grid = False
            lower_t = s_title.lower()
            if "quick" in lower_t or "cover" in lower_t or "trending" in lower_t or "long" in lower_t:
                is_grid = True
            elif "listen again" in lower_t or "video" in lower_t or "favorite" in lower_t or "release" in lower_t or "playlist" in lower_t or "mix" in lower_t:
                is_grid = False
            elif track_count > len(norm_items) * 0.7:
                is_grid = True

            final_sections.append({
                "title": s_title,
                "subtitle": s_sub,
                "type": "track_grid" if is_grid else "card_carousel",
                "items": norm_items
            })

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
    if 'all_tracks_discovered' in locals() and all_tracks_discovered:
        cache_online_tracks(all_tracks_discovered)

    result = {
        "timestamp": time.time(),
        "title": title,
        "sections": final_sections,
        "quick_picks": quick_picks[:30],
        "featured_playlists": featured_playlists[:60]
    }
    save_json(cache_path, result)
    return result

def get_album_details(browse_id):
    if not browse_id:
        return {"metadata": {}, "tracks": []}
    clean_id = browse_id
    if clean_id.startswith("VL"):
        clean_id = clean_id[2:]

    yt = get_ytmusic_client()
    try:
        alb = yt.get_album(clean_id)
        if not alb:
            return {"metadata": {}, "tracks": []}

        thumbs = alb.get("thumbnails", [])
        alb_thumb = thumbs[-1].get("url", "") if thumbs else ""
        if "w60" in alb_thumb or "w120" in alb_thumb or "w226" in alb_thumb:
            alb_thumb = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', alb_thumb)

        artists = alb.get("artists", [])
        artist_name = ", ".join(a.get("name", "") for a in artists if isinstance(a, dict)) if artists else "Unknown Artist"
        if not artist_name:
            artist_name = "Unknown Artist"

        tracks = []
        raw_tracks = alb.get("tracks", [])
        for t in raw_tracks:
            if not t.get("thumbnails") and alb_thumb:
                t["thumbnails"] = [{"url": alb_thumb}]
            norm = normalize_track(t)
            if norm:
                if not norm.get("album"):
                    norm["album"] = alb.get("title", "")
                tracks.append(norm)

        if tracks:
            cache_online_tracks(tracks)

        meta = {
            "id": clean_id,
            "browseId": clean_id,
            "title": alb.get("title", "Album"),
            "name": alb.get("title", "Album"),
            "artist": artist_name,
            "year": str(alb.get("year", "") or ""),
            "type": alb.get("type", "Album"),
            "trackCount": alb.get("trackCount", len(tracks)),
            "duration": alb.get("duration", ""),
            "image": alb_thumb,
            "description": alb.get("description", "")
        }
        return {
            "metadata": meta,
            "tracks": tracks
        }
    except Exception as e:
        sys.stderr.write(f"[get_album_details error for {clean_id}]: {e}\n")
        return {"metadata": {}, "tracks": []}

def get_artist(channel_id_or_name):
    if not channel_id_or_name:
        return {"metadata": {}, "popular": [], "singles": [], "albums": [], "videos": [], "related": []}
    
    clean_id = str(channel_id_or_name).strip()
    yt = get_ytmusic_client()
    
    browse_id = clean_id
    if not (clean_id.startswith("UC") or clean_id.startswith("FEmusic_library_privately_owned_artist_detail")):
        try:
            search_res = yt.search(clean_id, filter="artists")
            if search_res and len(search_res) > 0:
                browse_id = search_res[0].get("browseId", "")
        except Exception as e:
            sys.stderr.write(f"[get_artist search error for {clean_id}]: {e}\n")
            
    if not browse_id:
        return {"metadata": {"name": clean_id, "title": clean_id}, "popular": [], "singles": [], "albums": [], "videos": [], "related": []}

    try:
        art = yt.get_artist(browse_id)
        if not art:
            return {"metadata": {"name": clean_id, "title": clean_id}, "popular": [], "singles": [], "albums": [], "videos": [], "related": []}
            
        thumbs = art.get("thumbnails", [])
        art_thumb = thumbs[-1].get("url", "") if thumbs else ""
        if "w60" in art_thumb or "w120" in art_thumb or "w226" in art_thumb:
            art_thumb = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', art_thumb)
        elif "s60" in art_thumb or "s120" in art_thumb or "s226" in art_thumb:
            art_thumb = re.sub(r'=s\d+.*', '=s960-c-k-c0x00ffffff-no-rj', art_thumb)
            
        artist_name = art.get("name", clean_id)
        if artist_name and art_thumb:
            cache_artist_avatar(artist_name, art_thumb)
            
        popular_tracks = []
        raw_songs = art.get("songs", {}).get("results", [])
        for t in raw_songs:
            if not t.get("thumbnails") and art_thumb:
                t["thumbnails"] = [{"url": art_thumb}]
            norm = normalize_track(t)
            if norm:
                if not norm.get("artist"):
                    norm["artist"] = artist_name
                popular_tracks.append(norm)
                
        if popular_tracks:
            cache_online_tracks(popular_tracks)
            
        singles_list = []
        raw_singles = art.get("singles", {}).get("results", [])
        for s in raw_singles:
            s_thumbs = s.get("thumbnails", [])
            s_thumb = s_thumbs[-1].get("url", "") if s_thumbs else ""
            if "w60" in s_thumb or "w120" in s_thumb or "w226" in s_thumb:
                s_thumb = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', s_thumb)
            singles_list.append({
                "title": s.get("title", ""),
                "browseId": s.get("browseId", ""),
                "year": str(s.get("year", "") or ""),
                "image": s_thumb,
                "type": "Single"
            })
            
        albums_list = []
        raw_albums = art.get("albums", {}).get("results", [])
        for a in raw_albums:
            a_thumbs = a.get("thumbnails", [])
            a_thumb = a_thumbs[-1].get("url", "") if a_thumbs else ""
            if "w60" in a_thumb or "w120" in a_thumb or "w226" in a_thumb:
                a_thumb = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', a_thumb)
            albums_list.append({
                "title": a.get("title", ""),
                "browseId": a.get("browseId", ""),
                "year": str(a.get("year", "") or ""),
                "image": a_thumb,
                "type": "Album"
            })
            
        videos_list = []
        raw_videos = art.get("videos", {}).get("results", [])
        for v in raw_videos:
            v_thumbs = v.get("thumbnails", [])
            v_thumb = v_thumbs[-1].get("url", "") if v_thumbs else ""
            views_str = v.get("views", "") or ""
            videos_list.append({
                "title": v.get("title", ""),
                "videoId": v.get("videoId", ""),
                "views": views_str,
                "image": v_thumb
            })
            
        related_list = []
        raw_related = art.get("related", {}).get("results", [])
        for r in raw_related:
            r_thumbs = r.get("thumbnails", [])
            r_thumb = r_thumbs[-1].get("url", "") if r_thumbs else ""
            if "w60" in r_thumb or "w120" in r_thumb or "w226" in r_thumb:
                r_thumb = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', r_thumb)
            r_name = r.get("title", "")
            if r_name and r_thumb:
                cache_artist_avatar(r_name, r_thumb)
            related_list.append({
                "name": r_name,
                "title": r_name,
                "browseId": r.get("browseId", ""),
                "subscribers": r.get("subscribers", "") or "",
                "image": r_thumb
            })
            
        meta = {
            "channelId": browse_id,
            "browseId": browse_id,
            "name": artist_name,
            "title": artist_name,
            "subscribers": art.get("subscribers", "") or "",
            "views": art.get("views", "") or "",
            "radioId": art.get("radioId", "") or "",
            "shuffleId": art.get("shuffleId", "") or "",
            "subscribed": bool(art.get("subscribed", False)),
            "image": art_thumb,
            "description": art.get("description", "") or ""
        }
        
        return {
            "metadata": meta,
            "popular": popular_tracks,
            "singles": singles_list,
            "albums": albums_list,
            "videos": videos_list,
            "related": related_list
        }
    except Exception as e:
        sys.stderr.write(f"[get_artist error for {clean_id}]: {e}\n")
        return {"metadata": {"name": clean_id, "title": clean_id}, "popular": [], "singles": [], "albums": [], "videos": [], "related": []}

def subscribe_artist_action(channel_id, subscribe=True):
    clean_id = str(channel_id).strip()
    yt = get_ytmusic_client()
    res = {"channelId": clean_id, "subscribed": subscribe, "status": "ok"}
    try:
        if subscribe:
            if hasattr(yt, "subscribe_artist"):
                yt.subscribe_artist(clean_id)
            else:
                yt.subscribe_artists([clean_id])
        else:
            if hasattr(yt, "unsubscribe_artist"):
                yt.unsubscribe_artist(clean_id)
            else:
                yt.unsubscribe_artists([clean_id])
    except Exception as e:
        sys.stderr.write(f"[subscribe_artist error for {clean_id}]: {e}\n")
        res["error"] = str(e)
        res["status"] = "error"
    return res


def get_playlist_tracks(playlist_id, limit=50):
    if not playlist_id:
        return []
    yt = get_ytmusic_client()
    raw_tracks = []
    tracks = []

    clean_id = playlist_id
    if clean_id.startswith("VL"):
        clean_id = clean_id[2:]

    # Case 1: Album browseId (starts with MPREb_)
    if clean_id.startswith("MPREb_") or playlist_id.startswith("MPREb_"):
        res = get_album_details(clean_id)
        if res and res.get("tracks"):
            return res["tracks"]

    # Case 2: Radio and automix playlists (RD or VLRD)
    if playlist_id.startswith("RD") or playlist_id.startswith("VLRD") or clean_id.startswith("RD"):
        try:
            res = yt.get_watch_playlist(playlistId=playlist_id, limit=limit)
            raw_tracks = res.get("tracks", [])
        except Exception as e:
            try:
                res = yt.get_watch_playlist(playlistId=clean_id, limit=limit)
                raw_tracks = res.get("tracks", [])
            except Exception as e2:
                sys.stderr.write(f"[get_watch_playlist error for {playlist_id}]: {e} | {e2}\n")

    # Case 3: Standard playlist
    if not raw_tracks:
        try:
            pl = yt.get_playlist(playlist_id, limit=limit)
            raw_tracks = pl.get("tracks", [])
        except Exception as e:
            if playlist_id.startswith("VL"):
                try:
                    pl = yt.get_playlist(clean_id, limit=limit)
                    raw_tracks = pl.get("tracks", [])
                except Exception:
                    pass

            if not raw_tracks:
                try:
                    res = yt.get_watch_playlist(playlistId=playlist_id, limit=limit)
                    raw_tracks = res.get("tracks", [])
                except Exception:
                    try:
                        alb = yt.get_album(clean_id)
                        thumbs = alb.get("thumbnails", [])
                        alb_thumb = thumbs[-1].get("url", "") if thumbs else ""
                        for t in alb.get("tracks", []):
                            if not t.get("thumbnails") and alb_thumb:
                                t["thumbnails"] = [{"url": alb_thumb}]
                            norm = normalize_track(t)
                            if norm:
                                tracks.append(norm)
                        if tracks:
                            cache_online_tracks(tracks)
                            return tracks
                    except Exception as e_alb:
                        sys.stderr.write(f"[get_playlist_tracks all fallback error for {playlist_id}]: {e} | {e_alb}\n")

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

def search_albums(query, limit=10):
    if not query or not query.strip():
        return []
    try:
        ytm = get_ytmusic_client()
        raw = ytm.search(query.strip(), filter="albums")
        albums = []
        for item in raw[:limit]:
            thumbs = item.get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else ""
            if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
            artists = item.get("artists", [])
            art_name = ", ".join(a.get("name", "") for a in artists if isinstance(a, dict)) if artists else "Unknown Artist"
            bid = item.get("browseId", "")
            albums.append({
                "id": bid,
                "browseId": bid,
                "type": "album",
                "title": item.get("title", ""),
                "name": item.get("title", ""),
                "artist": art_name,
                "year": str(item.get("year", "") or ""),
                "image": thumb_url
            })
        return albums
    except Exception as e:
        sys.stderr.write(f"[search_albums error]: {e}\n")
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
        import yt_dlp

        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "extractor_args": {"youtube": {"player_client": ["android"]}}
        }
        url = f"https://www.youtube.com/watch?v={video_id}"
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            formats = [f for f in info.get("formats", []) if f.get("acodec") != "none"]
            stream_url = formats[-1]["url"] if formats else info.get("url")
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

PENDING_HISTORY_FILE = os.path.expanduser("~/.cache/frostify/pending_history.json")
LOCAL_YT_MAPPINGS_FILE = os.path.expanduser("~/.cache/frostify/local_yt_mappings.json")

def resolve_video_id_for_track(video_id, title="", artist=""):
    """If video_id is valid, return it. If local song, lookup via Title + Artist on YTMusic"""
    if video_id and not video_id.startswith("/") and not os.path.isabs(video_id) and not video_id.startswith("file://"):
        vid = video_id.replace("ytdl://", "")
        if "watch?v=" in vid:
            vid = vid.split("watch?v=")[1].split("&")[0]
        if len(vid) == 11:
            return vid

    clean_title = (title or "").strip()
    clean_artist = (artist or "").strip()
    if not clean_title:
        return None

    cache_key = f"{clean_title}|||{clean_artist}".lower()
    mappings = load_json(LOCAL_YT_MAPPINGS_FILE, {})
    if cache_key in mappings:
        return mappings[cache_key]

    try:
        yt = get_ytmusic_client()
        query = f"{clean_title} {clean_artist}".strip()
        results = yt.search(query, filter="songs", limit=1)
        if results and "videoId" in results[0]:
            found_id = results[0]["videoId"]
            mappings[cache_key] = found_id
            save_json(LOCAL_YT_MAPPINGS_FILE, mappings)
            return found_id
    except Exception as e:
        sys.stderr.write(f"[resolve_video_id_for_track error]: {e}\n")
    return None

def send_playback_tracking(video_id, title="", artist="", playlist_id=None):
    """
    SimpMusic adaptation: sends playback tracking and watchtime to YouTube Music
    so that Google Account records it in Watch History and updates personalized shelves.
    """
    vid = resolve_video_id_for_track(video_id, title, artist)
    if not vid:
        return {"success": False, "error": "Could not resolve videoId for tracking"}

    if not os.path.exists(AUTH_FILE):
        return {"success": False, "error": "Not logged in to Google Account"}

    def _execute_tracking(target_vid, p_id=None):
        import string
        import random
        try:
            yt = get_ytmusic_client()
            song = yt.get_song(target_vid)
            pt = song.get("playbackTracking")
            if not pt:
                return False

            playback_url = pt.get("videostatsPlaybackUrl", {}).get("baseUrl", "").replace("https://s.youtube.com", "https://music.youtube.com")
            watchtime_url = pt.get("videostatsWatchtimeUrl", {}).get("baseUrl", "").replace("https://s.youtube.com", "https://music.youtube.com")
            atr_url = pt.get("atrUrl", {}).get("baseUrl", "").replace("https://s.youtube.com", "https://music.youtube.com")
            if not playback_url or not watchtime_url:
                return False

            cpn = "".join(random.choices(string.ascii_letters + string.digits + "-_", k=16))
            now_ms = str(int(time.time() * 1000))
            
            # Use authenticated headers from yt.headers (includes fresh SAPISIDHASH, cookies, origin)
            auth_headers = dict(yt.headers)
            auth_headers["X-Goog-Event-Time"] = now_ms
            auth_headers["X-Goog-Request-Time"] = now_ms

            # 1. Playback ping
            p1 = {"ver": "2", "c": "WEB_REMIX", "cpn": cpn}
            if p_id:
                p1["list"] = p_id
                p1["referrer"] = f"https://music.youtube.com/playlist?list={p_id}"
            yt._session.get(playback_url, params=p1, headers=auth_headers, timeout=10)

            # 2. Watchtime initial ping (st=0, et=5.54)
            p2 = {"ver": "2", "c": "WEB_REMIX", "cpn": cpn, "st": "0", "et": "5.54"}
            if p_id:
                p2["list"] = p_id
                p2["referrer"] = f"https://music.youtube.com/playlist?list={p_id}"
            auth_headers["X-Goog-Event-Time"] = str(int(time.time() * 1000))
            auth_headers["X-Goog-Request-Time"] = auth_headers["X-Goog-Event-Time"]
            yt._session.get(watchtime_url, params=p2, headers=auth_headers, timeout=10)

            # 3. Background delay 5s -> atr -> delay 0.5s -> second watchtime (12.xx seconds)
            def _async_follow_up():
                try:
                    time.sleep(5.0)
                    follow_headers = dict(yt.headers)
                    if atr_url:
                        p_atr = {"cpn": cpn}
                        if p_id:
                            p_atr["list"] = p_id
                            p_atr["referrer"] = f"https://music.youtube.com/playlist?list={p_id}"
                        now_atr = str(int(time.time() * 1000))
                        follow_headers["X-Goog-Event-Time"] = now_atr
                        follow_headers["X-Goog-Request-Time"] = now_atr
                        yt._session.post(atr_url, params=p_atr, headers=follow_headers, timeout=10)

                    time.sleep(0.5)
                    sec_watch = round(random.uniform(12.0, 13.5), 2)
                    p3 = {
                        "ver": "2",
                        "c": "WEB_REMIX",
                        "cpn": cpn,
                        "st": "0,5.54",
                        "et": f"5.54,{sec_watch}"
                    }
                    if p_id:
                        p3["list"] = p_id
                        p3["referrer"] = f"https://music.youtube.com/playlist?list={p_id}"
                    now_final = str(int(time.time() * 1000))
                    follow_headers["X-Goog-Event-Time"] = now_final
                    follow_headers["X-Goog-Request-Time"] = now_final
                    yt._session.get(watchtime_url, params=p3, headers=follow_headers, timeout=10)
                except Exception as ex:
                    sys.stderr.write(f"[async tracking follow-up error]: {ex}\n")

            import threading
            threading.Thread(target=_async_follow_up, daemon=True).start()
            return True
        except Exception as e:
            sys.stderr.write(f"[execute_tracking error]: {e}\n")
            return False

    def _flush_pending():
        pending = load_json(PENDING_HISTORY_FILE, [])
        if pending and isinstance(pending, list):
            remaining = []
            for item in pending:
                t_vid = item.get("videoId")
                if t_vid:
                    ok = _execute_tracking(t_vid, item.get("playlistId"))
                    if not ok:
                        remaining.append(item)
            save_json(PENDING_HISTORY_FILE, remaining)

    import threading
    threading.Thread(target=_flush_pending, daemon=True).start()

    success = _execute_tracking(vid, playlist_id)
    if not success:
        pending = load_json(PENDING_HISTORY_FILE, [])
        if not isinstance(pending, list):
            pending = []
        pending.append({
            "videoId": vid,
            "title": title,
            "artist": artist,
            "playlistId": playlist_id,
            "timestamp": int(time.time())
        })
        save_json(PENDING_HISTORY_FILE, pending)
        return {"success": False, "queued": True, "videoId": vid}

    return {"success": True, "videoId": vid, "title": title, "artist": artist}

def get_song_details(video_id):
    """
    Fetch comprehensive song metadata and engagement statistics:
    - Title, Artist, Author, Subscribers, AuthorThumbnail
    - Album (real album name, or 'Single'), AlbumBrowseId
    - DateText, PublishDate, Description
    - View count, Like count, Dislike count, Like status
    """
    if not video_id:
        return {}

    clean_vid = str(video_id).strip().replace("ytdl://", "").replace("yt_", "")
    if len(clean_vid) != 11 or " " in clean_vid or "/" in clean_vid or "." in clean_vid:
        try:
            ytm = get_ytmusic_client()
            search_res = ytm.search(clean_vid, filter="songs", limit=1)
            if not search_res:
                search_res = ytm.search(clean_vid, filter="videos", limit=1)
            if search_res and search_res[0].get("videoId"):
                clean_vid = search_res[0]["videoId"]
            else:
                return {}
        except Exception as e:
            sys.stderr.write(f"[resolve videoId error for '{clean_vid}']: {e}\n")
            return {}

    details = {
        "videoId": clean_vid,
        "title": "",
        "artist": "",
        "author": "",
        "subscribers": "",
        "authorThumbnail": "",
        "dateText": "",
        "publishDate": "",
        "year": "",
        "description": "",
        "album": "Single",
        "albumBrowseId": "",
        "views": 0,
        "viewsStr": "--",
        "likes": 0,
        "likesStr": "--",
        "dislikes": 0,
        "dislikesStr": "--",
        "rating": 5.0,
        "likeRatio": 100.0,
        "likeStatus": "INDIFFERENT"
    }

    # 1. Fetch YouTube Innertube next endpoint for Author, Subscribers, Thumbnail, Date, and Description
    try:
        req = urllib.request.Request(
            "https://www.youtube.com/youtubei/v1/next?prettyPrint=false",
            data=json.dumps({
                "context": {"client": {"clientName": "WEB", "clientVersion": "2.20230515.01.00"}},
                "videoId": clean_vid
            }).encode(),
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req, timeout=3.0) as resp:
            next_data = json.loads(resp.read().decode())

        contents = next_data.get("contents", {}).get("twoColumnWatchNextResults", {}).get("results", {}).get("results", {}).get("contents", [])
        for c in contents:
            if "videoSecondaryInfoRenderer" in c:
                sec = c["videoSecondaryInfoRenderer"]
                owner = sec.get("owner", {}).get("videoOwnerRenderer", {})
                author = owner.get("title", {}).get("runs", [{}])[0].get("text", "")
                details["author"] = re.sub(r' - Topic| - Chủ đề', '', author).strip()
                details["artist"] = details["author"]
                details["subscribers"] = owner.get("subscriberCountText", {}).get("simpleText", "")
                thumbs = owner.get("thumbnail", {}).get("thumbnails", [])
                if thumbs:
                    details["authorThumbnail"] = thumbs[-1].get("url", "").replace("s48", "s960").replace("s88", "s960")
                    if details.get("artist"):
                        cache_artist_avatar(details["artist"], details["authorThumbnail"])
                details["description"] = sec.get("attributedDescription", {}).get("content", "")
            if "videoPrimaryInfoRenderer" in c:
                prim = c["videoPrimaryInfoRenderer"]
                details["dateText"] = prim.get("dateText", {}).get("simpleText", "")
                details["publishDate"] = details["dateText"]
                t_runs = prim.get("title", {}).get("runs", [])
                if t_runs:
                    details["title"] = t_runs[0].get("text", "")
    except Exception as e:
        sys.stderr.write(f"[Innertube next error for {clean_vid}]: {e}\n")

    # 2. Fetch watch playlist for Album info and Like status
    try:
        ytm = get_ytmusic_client()
        wp = ytm.get_watch_playlist(clean_vid, limit=1)
        if wp and "tracks" in wp and len(wp["tracks"]) > 0:
            tr0 = wp["tracks"][0]
            alb = tr0.get("album")
            if isinstance(alb, dict) and alb.get("name"):
                details["album"] = alb["name"]
                details["albumBrowseId"] = alb.get("id", "")
            elif isinstance(alb, str) and alb.strip():
                details["album"] = alb.strip()

            ls = tr0.get("likeStatus")
            if ls in ("LIKE", "DISLIKE", "INDIFFERENT"):
                details["likeStatus"] = ls

            if not details["title"]:
                details["title"] = tr0.get("title", "")
            if not details["artist"]:
                artists = tr0.get("artists", [])
                details["artist"] = ", ".join(a.get("name", "") for a in artists if a.get("name")) or details.get("author", "")
    except Exception as e:
        sys.stderr.write(f"[watch_playlist error for {clean_vid}]: {e}\n")

    # 3. Fetch YouTube Dislike & Engagement stats via Return YouTube Dislike API
    try:
        ryd_url = f"https://returnyoutubedislikeapi.com/votes?videoId={clean_vid}"
        req = urllib.request.Request(ryd_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            ryd_data = json.loads(resp.read().decode("utf-8"))
            likes = ryd_data.get("likes", 0)
            dislikes = ryd_data.get("dislikes", 0)
            rating = ryd_data.get("rating", 5.0)
            view_count = ryd_data.get("viewCount", 0)

            details["likes"] = likes
            details["dislikes"] = dislikes
            details["rating"] = round(rating, 2)
            if view_count:
                details["views"] = view_count
                if view_count >= 1000000:
                    details["viewsStr"] = f"{view_count / 1000000:.1f}M"
                elif view_count >= 1000:
                    details["viewsStr"] = f"{view_count / 1000:.1f}K"
                else:
                    details["viewsStr"] = f"{view_count:,}"

            if likes >= 1000000:
                details["likesStr"] = f"{likes / 1000000:.1f}M"
            elif likes >= 1000:
                details["likesStr"] = f"{likes / 1000:.1f}K"
            else:
                details["likesStr"] = str(likes)

            if dislikes >= 1000000:
                details["dislikesStr"] = f"{dislikes / 1000000:.1f}M"
            elif dislikes >= 1000:
                details["dislikesStr"] = f"{dislikes / 1000:.1f}K"
            else:
                details["dislikesStr"] = str(dislikes)

            total_votes = likes + dislikes
            if total_votes > 0:
                details["likeRatio"] = round((likes / total_votes) * 100.0, 1)
            else:
                details["likeRatio"] = 100.0
    except Exception as e:
        sys.stderr.write(f"[RYD API error for {clean_vid}]: {e}\n")

    # 4. Fallback check for empty fields via get_song
    if not details["description"] or not details["publishDate"]:
        try:
            ytm = get_ytmusic_client()
            song = ytm.get_song(clean_vid)
            v_details = song.get("videoDetails", {})
            if not details["title"]:
                details["title"] = v_details.get("title", "")
            if not details["artist"]:
                details["artist"] = v_details.get("author", "")
            if not details["author"]:
                details["author"] = v_details.get("author", "")

            mf = song.get("microformat", {}).get("microformatDataRenderer", {})
            pub_date = mf.get("publishDate", "") or mf.get("uploadDate", "")
            if pub_date and not details["publishDate"]:
                details["publishDate"] = pub_date[:10]
                details["dateText"] = pub_date[:10]
            if pub_date and not details["year"]:
                details["year"] = pub_date[:4]

            if not details["description"]:
                desc = ""
                if "description" in mf:
                    d_val = mf["description"]
                    desc = d_val.get("simpleText", "") if isinstance(d_val, dict) else str(d_val)
                if not desc and "shortDescription" in v_details:
                    desc = v_details["shortDescription"]
                if desc:
                    details["description"] = desc
        except Exception:
            pass

    # Ensure album is never empty or weird
    if not details["album"] or details["album"].lower() == "single / simpmusic":
        details["album"] = "Single"

    # Enforce blacklist check on likeStatus
    if is_song_disliked(clean_vid):
        details["likeStatus"] = "DISLIKE"

    return details

def rate_song_action(video_id, rating):
    clean_vid = str(video_id).strip().replace("ytdl://", "").replace("yt_", "")
    upper_rating = str(rating).upper().strip()
    if upper_rating not in ("LIKE", "DISLIKE", "INDIFFERENT"):
        upper_rating = "INDIFFERENT"

    if upper_rating == "DISLIKE":
        add_disliked_song(clean_vid)
    elif upper_rating in ("LIKE", "INDIFFERENT"):
        remove_disliked_song(clean_vid)

    res = {"success": True, "videoId": clean_vid, "rating": upper_rating}
    try:
        ytm = get_ytmusic_client()
        ytm.rate_song(clean_vid, upper_rating)
    except Exception as e:
        sys.stderr.write(f"[rate_song error for {clean_vid}]: {e}\n")
        res["ytm_error"] = str(e)
    return res

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ytmusic_helper.py [home | radio <id> | mood <params> | playlist <id> | search <q> | get_url <id> | auth_status | save_auth <text> | logout | track_playback <id> | song_details <id> | rate_song <id> <rating>]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "song_details" and len(sys.argv) > 2:
        vid = sys.argv[2]
        res = get_song_details(vid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "rate_song" and len(sys.argv) > 3:
        vid = sys.argv[2]
        rating = sys.argv[3]
        res = rate_song_action(vid, rating)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "disliked_list":
        print(json.dumps(load_disliked_songs(), ensure_ascii=False))

    elif cmd == "home":
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

    elif cmd == "album" and len(sys.argv) > 2:
        alb_id = sys.argv[2]
        res = get_album_details(alb_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "search_albums" and len(sys.argv) > 2:
        q = sys.argv[2]
        res = search_albums(q)
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

    elif cmd == "track_playback" and len(sys.argv) > 2:
        vid = sys.argv[2]
        title = sys.argv[3] if len(sys.argv) > 3 else ""
        artist = sys.argv[4] if len(sys.argv) > 4 else ""
        pl_id = sys.argv[5] if len(sys.argv) > 5 else None
        res = send_playback_tracking(vid, title, artist, pl_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "artist" and len(sys.argv) > 2:
        art_id = sys.argv[2]
        res = get_artist(art_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "subscribe" and len(sys.argv) > 2:
        channel_id = sys.argv[2]
        sub = True
        if len(sys.argv) > 3:
            sub = str(sys.argv[3]).lower() in ("true", "1", "yes")
        res = subscribe_artist_action(channel_id, sub)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "cached_avatar" and len(sys.argv) > 2:
        name = sys.argv[2]
        url = get_cached_artist_avatar(name)
        print(json.dumps({"artist": name, "avatar": url}, ensure_ascii=False))


