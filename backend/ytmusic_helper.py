#!/usr/bin/env python3
"""
Nutsty YouTube Music Helper
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
STREAM_CACHE_FILE = os.path.expanduser("~/.cache/nutsty/stream_cache.json")
HOME_CACHE_FILE = os.path.expanduser("~/.cache/nutsty/home_feed.json")
ONLINE_TRACKS_FILE = os.path.expanduser("~/.cache/nutsty/online_tracks.json")
MOOD_CACHE_DIR = os.path.expanduser("~/.cache/nutsty/moods")
MOOD_CATS_FILE = os.path.expanduser("~/.cache/nutsty/mood_categories.json")
SQUARE_COVERS_CACHE_FILE = os.path.expanduser("~/.cache/nutsty/square_covers.json")

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

DISLIKED_SONGS_FILE = os.path.expanduser("~/.config/noctalia/nutsty_disliked_songs.json")

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

ARTIST_AVATARS_FILE = os.path.expanduser("~/.cache/nutsty/artist_avatars.json")

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
        return {"logged_in": False, "name": "", "thumb": "", "email": ""}
    try:
        from ytmusicapi import YTMusic
        yt = YTMusic(AUTH_FILE)
        user = yt.get_account_info()
        name = user.get("accountName") or user.get("name") or "Google User"
        thumb = user.get("accountPhotoUrl") or ""
        if not thumb:
            thumbs = user.get("thumbnails", [])
            thumb = thumbs[-1].get("url") if thumbs else ""
        email = user.get("email") or user.get("channelHandle") or ""
        return {"logged_in": True, "name": name, "thumb": thumb, "email": email}
    except Exception:
        try:
            yt = YTMusic(AUTH_FILE)
            yt.get_home(limit=1)
            return {"logged_in": True, "name": "YouTube Music Account", "thumb": "", "email": ""}
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
            with open("/tmp/nutsty_auth_changed", "w") as f:
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
        with open("/tmp/nutsty_auth_changed", "w") as f:
            f.write(str(time.time()))
    except Exception:
        pass
    return {"success": True}

def clean_artist_name(raw_name):
    if not raw_name:
        return "YouTube Music"
    s = str(raw_name).strip()
    # Split by bullet point separator ' • '
    parts = re.split(r'\s*•\s*', s)
    for p in parts:
        p_clean = p.strip()
        if not p_clean:
            continue
        if re.search(r'\d+([.,]\d+)?\s*[KMBkmb]?\s*(views|plays|lượt xem|lượt nghe)', p_clean, re.I):
            continue
        if p_clean.lower() in ("single", "album", "ep", "video", "bài hát", "nghệ sĩ", "artist"):
            continue
        return p_clean
    return parts[0].strip() or "YouTube Music"

def normalize_track(item):
    vid = item.get("videoId")
    if not vid or is_song_disliked(vid):
        return None
    title = item.get("title", "Unknown")
    artists = item.get("artists", [])
    channel_id = ""
    for a in artists:
        if isinstance(a, dict) and a.get("id"):
            channel_id = a.get("id")
            break
    artist_name = ", ".join(a.get("name", "") for a in artists if a.get("name")) or ""
    if not artist_name:
        artist_name = item.get("artist", "")
    artist_name = clean_artist_name(artist_name)
    dur_str = item.get("duration", "--:--")
    dur_sec = item.get("duration_seconds") or 0
    thumbs = item.get("thumbnails", [])
    thumb_url = thumbs[-1].get("url", "") if thumbs else f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"

    if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
        thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

    res = {
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
    alb = item.get("album")
    if isinstance(alb, dict):
        res["album"] = alb.get("name", "")
        res["albumId"] = alb.get("id", "")
    elif isinstance(alb, str):
        res["album"] = alb
    views = item.get("views", "")
    if views:
        res["views"] = views if ("lượt" in str(views).lower() or "play" in str(views).lower()) else f"{views} lượt phát"
    if channel_id:
        res["channelId"] = channel_id
    return res

def get_recent_seed_track():
    sess_file = os.path.expanduser("~/.config/noctalia/nutsty_session.json")
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

PALETTE_CREATORS = [
    "#00bcd4",  # cyan
    "#ff7043",  # orange
    "#ab47bc",  # purple
    "#26a69a",  # teal
    "#42a5f5",  # blue
    "#ff5722",  # deep orange
    "#ffa726",  # amber
    "#ec407a",  # pink
    "#7e57c2",  # deep purple
    "#66bb6a",  # light green
]

def get_creator_color(name):
    if not name:
        return "#00bcd4"
    h = 0
    for ch in str(name):
        h = (h * 31 + ord(ch)) & 0xFFFFFFFF
    return PALETTE_CREATORS[h % len(PALETTE_CREATORS)]

def classify_section(title, norm_items):
    lower_t = str(title).lower()
    track_count = sum(1 for x in norm_items if x.get("type") in ["track", "video"])
    pl_count = sum(1 for x in norm_items if x.get("type") in ["playlist", "album"])
    has_16_9 = any(x.get("aspectRatio") == "16:9" or x.get("isVideo") for x in norm_items)

    # 1. Multi-row Track Grid (4 rows per column)
    if any(k in lower_t for k in ["quick", "lựa chọn nhanh", "cover", "remix", "trending song", "bài hát thịnh hành", "long", "thư giãn", "shorts"]):
        return "track_grid"

    # 2. Video Carousel (16:9 Widescreen)
    if any(k in lower_t for k in ["video", "listen again", "nghe lại", "forgotten", "giai điệu", "cùng nghe", "together"]):
        return "video_carousel"

    # 3. Large Square Album & Playlist Carousel
    if pl_count >= len(norm_items) * 0.5 or any(k in lower_t for k in ["album", "playlist", "community", "cộng đồng", "release", "mới phát hành", "mix", "kết hợp", "bảng xếp hạng", "chart", "station", "danh sách"]):
        return "album_carousel"

    # 4. Aspect Ratio Heuristic
    if has_16_9:
        return "video_carousel"

    # 5. Default fallback heuristics
    if track_count > len(norm_items) * 0.7:
        return "track_grid"
    return "album_carousel"

def _normalize_shelf_item(it, shelf_title):
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
        channel_id = ""
        views = ""
        if len(cols) > 1:
            artist_runs = cols[1].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])
            for x in artist_runs:
                txt = x.get("text", "").strip()
                if not txt or txt == "•":
                    continue
                if any(w in txt.lower() for w in ["views", "plays", "lượt xem", "lượt phát"]):
                    views = txt
                    continue
                if not artist:
                    artist = txt
                    ep = x.get("navigationEndpoint", {}).get("browseEndpoint", {})
                    if ep and ep.get("browseId"):
                        channel_id = ep.get("browseId")
            if not artist:
                artist = "".join(x.get("text", "") for x in artist_runs if "views" not in x.get("text", "").lower() and "plays" not in x.get("text", "").lower() and "lượt" not in x.get("text", "").lower()).strip(" • ")
        artist = clean_artist_name(artist)
        thumbs = r.get("thumbnail", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
        thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
        if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
            thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
        if vid and title:
            item_res = {
                "id": f"yt_{vid}",
                "type": "track",
                "title": title,
                "name": title,
                "artist": artist or "YouTube Music",
                "subtitle": f"{artist} • {views}" if (artist and views) else (artist or "YouTube Music"),
                "views": views,
                "source": "YouTube Music",
                "path": f"ytdl://{vid}",
                "videoId": vid,
                "duration": "--:--",
                "durationMs": 0,
                "image": thumb_url,
                "aspectRatio": "1:1",
                "isVideo": False
            }
            if channel_id:
                item_res["channelId"] = channel_id
            return item_res

    # 2. musicTwoRowItemRenderer
    elif "musicTwoRowItemRenderer" in it:
        r = it["musicTwoRowItemRenderer"]
        title = "".join(x.get("text", "") for x in r.get("title", {}).get("runs", []))
        sub = "".join(x.get("text", "") for x in r.get("subtitle", {}).get("runs", []))
        sub_runs = r.get("subtitle", {}).get("runs", [])
        artist_name = ""
        channel_id = ""
        views = ""
        for x in sub_runs:
            txt = x.get("text", "").strip()
            if not txt or txt == "•":
                continue
            if any(w in txt.lower() for w in ["views", "plays", "lượt xem", "lượt phát"]):
                views = txt
            elif not artist_name and not any(w in txt.lower() for w in ["playlist", "danh sách phát", "album", "ep", "single"]):
                artist_name = txt
                ep = x.get("navigationEndpoint", {}).get("browseEndpoint", {})
                if ep and ep.get("browseId"):
                    channel_id = ep.get("browseId")
        if not artist_name:
            artist_name = clean_artist_name(sub)

        r_aspect = str(r.get("aspectRatio", ""))
        is_16_9 = ("16_9" in r_aspect) or ("RECTANGLE" in r_aspect)
        if not is_16_9 and any(k in shelf_title.lower() for k in ["video", "listen again", "nghe lại", "forgotten", "giai điệu", "cùng nghe"]):
            is_16_9 = True

        thumbs = r.get("thumbnailRenderer", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
        thumb_url = thumbs[-1].get("url", "") if thumbs else ""
        if is_16_9:
            if "=w" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w640-h360-l90-rj', thumb_url)
        else:
            if "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

        nav_ep = r.get("navigationEndpoint", {})
        watch_ep = nav_ep.get("watchEndpoint", {})
        browse_ep = nav_ep.get("browseEndpoint", {})

        vid = watch_ep.get("videoId")
        if vid and is_song_disliked(vid):
            return None
        pl_id = watch_ep.get("playlistId") or browse_ep.get("browseId")

        if vid and (not pl_id or is_16_9 or "listen" in shelf_title.lower() or "favorite" in shelf_title.lower() or "video" in shelf_title.lower()):
            item_res = {
                "id": f"yt_{vid}",
                "type": "video" if is_16_9 else "track",
                "title": title,
                "name": title,
                "artist": artist_name or "YouTube Music",
                "subtitle": f"{artist_name} • {views}" if (artist_name and views) else (artist_name or "YouTube Music"),
                "views": views,
                "source": "YouTube Music",
                "path": f"ytdl://{vid}",
                "videoId": vid,
                "duration": "--:--",
                "durationMs": 0,
                "image": thumb_url,
                "aspectRatio": "16:9" if is_16_9 else "1:1",
                "isVideo": is_16_9
            }
            if channel_id:
                item_res["channelId"] = channel_id
            return item_res
        elif pl_id and title:
            is_album = str(pl_id).startswith("MPREb_") or any(w in sub.lower() for w in ["album", "ep", "single"]) or "album" in shelf_title.lower()
            creator = artist_name or ""
            not_community_shelf = any(w in shelf_title.lower() for w in ["mixed for you", "dành riêng", "nghe lại", "listen again", "quick", "album", "mới phát hành", "release", "radio", "for you", "cho bạn"])
            is_community = not not_community_shelf and (("community" in shelf_title.lower()) or ("cộng đồng" in shelf_title.lower()) or (bool(views) and not is_album))
            if is_community and creator and not any(w in creator.lower() for w in ["youtube music", "supermix"]):
                creator_initial = creator.strip()[:1].upper()
                creator_color = get_creator_color(creator)
            else:
                creator_initial = ""
                creator_color = ""
            return {
                "id": pl_id,
                "type": "album" if is_album else "playlist",
                "playlistId": pl_id,
                "title": title,
                "subtitle": (f"Album • {artist_name}" if artist_name else "Album") if is_album else (f"Playlist • {creator}" + (f" • {views}" if views else "") if creator else "Playlist"),
                "creator": creator,
                "creatorInitial": creator_initial,
                "creatorColor": creator_color,
                "views": views,
                "image": thumb_url,
                "aspectRatio": "1:1",
                "isVideo": False
            }

    # 3. Parsed item (from parse_mixed_content)
    elif isinstance(it, dict):
        vid = it.get("videoId")
        pl_id = it.get("playlistId") or it.get("browseId") or it.get("audioPlaylistId")
        title = it.get("title", "")
        r_aspect = str(it.get("aspectRatio", ""))
        is_16_9 = ("16_9" in r_aspect) or ("RECTANGLE" in r_aspect)
        if not is_16_9 and any(k in shelf_title.lower() for k in ["video", "listen again", "nghe lại", "forgotten", "giai điệu", "cùng nghe", "together"]):
            is_16_9 = True

        thumbs = it.get("thumbnails", [])
        thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
        if is_16_9:
            if "=w" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w640-h360-l90-rj', thumb_url)
        else:
            if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)

        artist = ""
        channel_id = ""
        views = ""
        desc = it.get("description") or ""
        if desc:
            parts = [p.strip() for p in desc.split("•")]
            for p in parts:
                if any(w in p.lower() for w in ["views", "plays", "lượt xem", "lượt phát"]):
                    views = p
                elif not artist and not any(w in p.lower() for w in ["playlist", "album", "ep", "single"]):
                    artist = p

        if it.get("artists"):
            artist = ", ".join(a.get("name", "") for a in it.get("artists", []) if isinstance(a, dict))
            for a in it.get("artists", []):
                if isinstance(a, dict) and a.get("id"):
                    channel_id = a.get("id")
                    break
        elif not artist and desc:
            artist = desc
        artist = clean_artist_name(artist)

        if vid and (not pl_id or is_16_9 or "song" in str(it.get("videoType", "")).lower() or "atv" in str(it.get("videoType", "")).lower() or "listen" in shelf_title.lower() or "quick" in shelf_title.lower() or "cover" in shelf_title.lower() or "video" in shelf_title.lower() or "trending" in shelf_title.lower() or "favorite" in shelf_title.lower() or "long" in shelf_title.lower()):
            item_res = {
                "id": f"yt_{vid}",
                "type": "video" if is_16_9 else "track",
                "title": title,
                "name": title,
                "artist": artist or "YouTube Music",
                "subtitle": f"{artist} • {views}" if (artist and views) else (artist or "YouTube Music"),
                "views": views,
                "source": "YouTube Music",
                "path": f"ytdl://{vid}",
                "videoId": vid,
                "duration": it.get("duration", "--:--"),
                "durationMs": (it.get("duration_seconds") or 0) * 1000,
                "image": thumb_url,
                "aspectRatio": "16:9" if is_16_9 else "1:1",
                "isVideo": is_16_9
            }
            if channel_id:
                item_res["channelId"] = channel_id
            return item_res
        elif pl_id and title:
            is_album = str(it.get("type", "")).lower() == "album" or str(pl_id).startswith("MPREb_") or "album" in desc.lower() or "album" in shelf_title.lower()
            creator = artist or ""
            not_community_shelf = any(w in shelf_title.lower() for w in ["mixed for you", "dành riêng", "nghe lại", "listen again", "quick", "album", "mới phát hành", "release", "radio", "for you", "cho bạn"])
            is_community = not not_community_shelf and (("community" in shelf_title.lower()) or ("cộng đồng" in shelf_title.lower()) or (bool(views) and not is_album))
            if is_community and creator and not any(w in creator.lower() for w in ["youtube music", "supermix"]):
                creator_initial = creator.strip()[:1].upper()
                creator_color = get_creator_color(creator)
            else:
                creator_initial = ""
                creator_color = ""
            return {
                "id": pl_id,
                "type": "album" if is_album else "playlist",
                "playlistId": pl_id,
                "title": title,
                "subtitle": (f"Album • {artist}" if artist else "Album") if is_album else (f"Playlist • {creator}" + (f" • {views}" if views else "") if creator else "Playlist"),
                "creator": creator,
                "creatorInitial": creator_initial,
                "creatorColor": creator_color,
                "views": views,
                "image": thumb_url,
                "aspectRatio": "1:1",
                "isVideo": False
            }
    return None

def get_personalized_home():
    cached = load_json(HOME_CACHE_FILE, None)
    if cached and (time.time() - cached.get("timestamp", 0)) < 1800:
        sections = cached.get("sections", [])
        has_legacy = any(s.get("type") == "card_carousel" for s in sections)
        if not has_legacy and sections and (cached.get("quick_picks") or cached.get("featured_playlists")):
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

            final_sections.append({
                "title": title,
                "subtitle": subtitle,
                "type": classify_section(title, norm_items),
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

    # Load all existing cached moods from ~/.cache/nutsty/moods/ into preloaded_moods for 0ms QML startup
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

def _parse_duration_seconds(dur_str):
    if not dur_str or dur_str == "--:--":
        return 0
    parts = dur_str.split(":")
    try:
        if len(parts) == 2:
            return int(parts[0]) * 60 + int(parts[1])
        elif len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
    except Exception:
        return 0
    return 0

def get_watch_playlist_chips(video_id):
    if video_id.startswith("ytdl://"):
        video_id = video_id.replace("ytdl://", "")

    yt = get_ytmusic_client()
    try:
        res = yt._send_request('next', {'videoId': video_id, 'playlistId': f'RDAMVM{video_id}'})
        tabs = res.get('contents', {}).get('singleColumnMusicWatchNextResultsRenderer', {}).get('tabbedRenderer', {}).get('watchNextTabbedResultsRenderer', {}).get('tabs', [])
        if not tabs:
            return []
        queue = tabs[0].get('tabRenderer', {}).get('content', {}).get('musicQueueRenderer', {})
        chips_raw = queue.get('subHeaderChipCloud', {}).get('chipCloudRenderer', {}).get('chips', [])

        chips = []
        for c in chips_raw:
            cr = c.get('chipCloudChipRenderer', {})
            title = ''.join(r.get('text', '') for r in cr.get('text', {}).get('runs', [])).strip()
            ep = cr.get('navigationEndpoint', {}).get('queueUpdateCommand', {}).get('fetchContentsCommand', {}).get('watchEndpoint', {})
            playlist_id = ep.get('playlistId', '')
            params = ep.get('params', '')
            is_selected = cr.get('isSelected', False)
            if title:
                chips.append({
                    "title": title,
                    "playlistId": playlist_id,
                    "params": params,
                    "selected": is_selected
                })
        return chips
    except Exception as e:
        sys.stderr.write(f"[get_watch_playlist_chips error for {video_id}]: {e}\n")
        return []

def get_filtered_radio_queue(video_id, playlist_id, params=None):
    if video_id.startswith("ytdl://"):
        video_id = video_id.replace("ytdl://", "")

    yt = get_ytmusic_client()
    try:
        from ytmusicapi.parsers.watch import parse_watch_playlist
        body = {'videoId': video_id, 'playlistId': playlist_id}
        if params:
            body['params'] = params
        res = yt._send_request('next', body)
        tabs = res.get('contents', {}).get('singleColumnMusicWatchNextResultsRenderer', {}).get('tabbedRenderer', {}).get('watchNextTabbedResultsRenderer', {}).get('tabs', [])
        if not tabs:
            return []
        queue = tabs[0].get('tabRenderer', {}).get('content', {}).get('musicQueueRenderer', {})
        contents = queue.get('content', {}).get('playlistPanelRenderer', {}).get('contents', [])
        parsed = parse_watch_playlist(contents)

        tracks = []
        for p in parsed:
            if "length" in p and "duration" not in p:
                p["duration"] = p["length"]
            if "thumbnail" in p and "thumbnails" not in p:
                p["thumbnails"] = p["thumbnail"]
            norm = normalize_track(p)
            if norm:
                if (not norm.get("durationMs") or norm.get("durationMs") == 0) and norm.get("duration") and norm.get("duration") != "--:--":
                    norm["durationMs"] = _parse_duration_seconds(norm["duration"]) * 1000
                tracks.append(norm)
        cache_online_tracks(tracks)
        return tracks
    except Exception as e:
        sys.stderr.write(f"[get_filtered_radio_queue error for {video_id}, {playlist_id}]: {e}\n")
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
            channel_id = ""
            if len(cols) > 1:
                artist_runs = cols[1].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])
                for x in artist_runs:
                    txt = x.get("text", "").strip()
                    if not txt or txt == "•" or "views" in txt.lower() or "plays" in txt.lower() or "lượt xem" in txt.lower():
                        continue
                    if not artist:
                        artist = txt
                        ep = x.get("navigationEndpoint", {}).get("browseEndpoint", {})
                        if ep and ep.get("browseId"):
                            channel_id = ep.get("browseId")
                if not artist:
                    artist = "".join(x.get("text", "") for x in artist_runs if "views" not in x.get("text", "").lower() and "plays" not in x.get("text", "").lower()).strip(" • ")
            artist = clean_artist_name(artist)
            thumbs = r.get("thumbnail", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
            thumb_url = thumbs[-1].get("url", "") if thumbs else (f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg" if vid else "")
            if "w60" in thumb_url or "w120" in thumb_url or "w226" in thumb_url:
                thumb_url = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', thumb_url)
            if vid and title_text and len(quick_picks) < max_qp:
                if not any(q.get("videoId") == vid for q in quick_picks):
                    qp_item = {
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
                    }
                    if channel_id:
                        qp_item["channelId"] = channel_id
                    quick_picks.append(qp_item)
        elif "musicTwoRowItemRenderer" in it:
            r = it["musicTwoRowItemRenderer"]
            t_text = "".join(x.get("text", "") for x in r.get("title", {}).get("runs", []))
            sub = "".join(x.get("text", "") for x in r.get("subtitle", {}).get("runs", []))
            sub_runs = r.get("subtitle", {}).get("runs", [])
            artist_name = ""
            channel_id = ""
            for x in sub_runs:
                txt = x.get("text", "").strip()
                if not txt or txt == "•" or "views" in txt.lower() or "plays" in txt.lower() or "lượt xem" in txt.lower():
                    continue
                if not artist_name:
                    artist_name = txt
                    ep = x.get("navigationEndpoint", {}).get("browseEndpoint", {})
                    if ep and ep.get("browseId"):
                        channel_id = ep.get("browseId")
            if not artist_name:
                artist_name = clean_artist_name(sub)

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
                    qp_item = {
                        "id": f"yt_{vid}",
                        "title": t_text,
                        "name": t_text,
                        "artist": artist_name or "YouTube Music",
                        "source": "YouTube Music",
                        "path": f"ytdl://{vid}",
                        "videoId": vid,
                        "duration": "--:--",
                        "durationMs": 0,
                        "image": thumb_url
                    }
                    if channel_id:
                        qp_item["channelId"] = channel_id
                    quick_picks.append(qp_item)
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

        # 2. Process continuation sections (Continuation scraper for 50+ playlists)
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

            final_sections.append({
                "title": s_title,
                "subtitle": s_sub,
                "type": classify_section(s_title, norm_items),
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
        search_query = clean_artist_name(clean_id)
        try:
            search_res = yt.search(search_query, filter="artists")
            if search_res and len(search_res) > 0:
                browse_id = search_res[0].get("browseId", "")
            else:
                # Fallback: search without filter and locate first artist browseId
                gen_res = yt.search(search_query)
                for it in gen_res:
                    if it.get("resultType") == "artist" and it.get("browseId"):
                        browse_id = it.get("browseId")
                        break
                    for a in it.get("artists", []):
                        if isinstance(a, dict) and a.get("id"):
                            browse_id = a.get("id")
                            break
                    if browse_id:
                        break
        except Exception as e:
            sys.stderr.write(f"[get_artist search error for {clean_id}]: {e}\n")
            
    if not browse_id:
        return {"metadata": {"name": clean_artist_name(clean_id), "title": clean_artist_name(clean_id)}, "popular": [], "singles": [], "albums": [], "videos": [], "related": []}

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

def search_categorized(query):
    if not query or not query.strip():
        query = "Trending"

    q = query.strip()
    try:
        ytm = get_ytmusic_client()
        raw = ytm.search(q)
        top_result = None
        songs = []
        albums = []
        artists = []
        playlists = []

        for i, r in enumerate(raw):
            rtype = r.get("resultType")
            cat = r.get("category")
            is_top = (cat == "Top result" or (i == 0 and rtype in ("artist", "album", "song")))

            if is_top and not top_result:
                if rtype == "artist":
                    arts = r.get("artists", [])
                    a_name = r.get("artist") or (arts[0].get("name") if arts else q)
                    a_id = (arts[0].get("id") if arts else "") or r.get("browseId", "")
                    thumbs = r.get("thumbnails", [])
                    turl = thumbs[-1].get("url", "") if thumbs else ""
                    turl = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', turl)
                    top_result = {
                        "type": "artist",
                        "browseId": a_id,
                        "name": a_name,
                        "artist": a_name,
                        "subscribers": r.get("subscribers", ""),
                        "image": turl
                    }
                elif rtype in ("song", "video"):
                    norm = normalize_track(r)
                    if norm:
                        norm["type"] = "song"
                        top_result = norm
                elif rtype == "album":
                    thumbs = r.get("thumbnails", [])
                    turl = thumbs[-1].get("url", "") if thumbs else ""
                    turl = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', turl)
                    arts = r.get("artists", [])
                    aname = ", ".join(a.get("name", "") for a in arts if isinstance(a, dict)) if arts else ""
                    bid = r.get("browseId", "")
                    top_result = {
                        "type": "album",
                        "browseId": bid,
                        "playlistId": r.get("playlistId", "") or bid,
                        "title": r.get("title", ""),
                        "name": r.get("title", ""),
                        "artist": aname,
                        "year": str(r.get("year", "") or ""),
                        "image": turl
                    }

            if rtype in ("song", "video"):
                norm = normalize_track(r)
                if norm and not is_song_disliked(norm.get("videoId")):
                    songs.append(norm)
            elif rtype == "album":
                thumbs = r.get("thumbnails", [])
                turl = thumbs[-1].get("url", "") if thumbs else ""
                turl = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', turl)
                arts = r.get("artists", [])
                aname = ", ".join(a.get("name", "") for a in arts if isinstance(a, dict)) if arts else ""
                bid = r.get("browseId", "")
                albums.append({
                    "type": "album",
                    "browseId": bid,
                    "playlistId": r.get("playlistId", "") or bid,
                    "title": r.get("title", ""),
                    "name": r.get("title", ""),
                    "artist": aname,
                    "year": str(r.get("year", "") or ""),
                    "image": turl
                })
            elif rtype == "artist":
                arts = r.get("artists", [])
                a_name = r.get("artist") or (arts[0].get("name") if arts else "")
                a_id = (arts[0].get("id") if arts else "") or r.get("browseId", "")
                thumbs = r.get("thumbnails", [])
                turl = thumbs[-1].get("url", "") if thumbs else ""
                turl = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', turl)
                artists.append({
                    "type": "artist",
                    "browseId": a_id,
                    "name": a_name,
                    "artist": a_name,
                    "subscribers": r.get("subscribers", ""),
                    "image": turl
                })
            elif rtype == "playlist":
                thumbs = r.get("thumbnails", [])
                turl = thumbs[-1].get("url", "") if thumbs else ""
                turl = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', turl)
                bid = r.get("browseId", "")
                author = r.get("author", "") or (r.get("artists", [{}])[0].get("name") if r.get("artists") else "")
                playlists.append({
                    "type": "playlist",
                    "id": bid,
                    "browseId": bid,
                    "title": r.get("title", ""),
                    "name": r.get("title", ""),
                    "author": author,
                    "artist": author,
                    "itemCount": r.get("itemCount", ""),
                    "image": turl
                })

        cache_online_tracks(songs)

        # Distinguish community playlists vs featured playlists
        community_playlists = []
        featured_playlists = []
        for pl in playlists:
            author_low = (pl.get("author") or "").lower()
            if "youtube music" in author_low or "youtube" in author_low or "tuyển tập" in author_low:
                featured_playlists.append(pl)
            else:
                community_playlists.append(pl)

        # If top_result is not artist but artists list has an exact or strong match for query, promote artist to top_result (YouTube Music Desktop pattern)
        clean_q_low = q.lower().strip()
        if artists and (not top_result or top_result.get("type") != "artist"):
            for a in artists:
                a_name_low = (a.get("name") or "").lower().strip()
                if a_name_low == clean_q_low or clean_q_low in a_name_low or a_name_low in clean_q_low:
                    top_result = a
                    break

        # Attach top 3 tracks to top_result for 2-column desktop hero card
        if top_result:
            if top_result.get("type") == "artist":
                a_name = top_result.get("name", "")
                for s in songs:
                    if not s.get("artist") or s.get("artist") == "YouTube Music":
                        s["artist"] = a_name
            top_result["top_tracks"] = songs[:3]

        return {
            "query": q,
            "top_result": top_result,
            "songs": songs,
            "albums": albums,
            "artists": artists,
            "community_playlists": community_playlists,
            "featured_playlists": featured_playlists,
            "playlists": playlists
        }
    except Exception as e:
        sys.stderr.write(f"[search_categorized error]: {e}\n")
        return {"query": q, "top_result": None, "songs": [], "albums": [], "artists": [], "community_playlists": [], "featured_playlists": [], "playlists": []}

def filter_search(query, category="songs"):
    q = str(query or "").strip()
    if not q:
        return []
    try:
        ytm = get_ytmusic_client()
        cat_map = {
            "songs": "songs",
            "albums": "albums",
            "artists": "artists",
            "community_playlists": "community_playlists",
            "playlists": "community_playlists",
            "featured_playlists": "featured_playlists"
        }
        flt = cat_map.get(category, "songs")
        raw = ytm.search(q, filter=flt, limit=60)
        items = []
        for r in raw:
            rtype = r.get("resultType")
            thumbs = r.get("thumbnails", [])
            turl = thumbs[-1].get("url", "") if thumbs else ""
            turl = re.sub(r'=w\d+-h\d+.*', '=w544-h544-l90-rj', turl)

            if flt == "songs" or rtype in ("song", "video"):
                norm = normalize_track(r)
                if norm and not is_song_disliked(norm.get("videoId")):
                    norm["type"] = "song"
                    items.append(norm)
            elif flt == "albums" or rtype == "album":
                arts = r.get("artists", [])
                aname = ", ".join(a.get("name", "") for a in arts if isinstance(a, dict)) if arts else (r.get("artist") or "")
                bid = r.get("browseId", "")
                year_str = str(r.get("year", "") or "")
                album_type = "EP" if "ep" in (r.get("title", "")).lower() else ("Single" if "single" in (r.get("title", "")).lower() else "Album")
                items.append({
                    "type": "album",
                    "browseId": bid,
                    "playlistId": r.get("playlistId", "") or bid,
                    "title": r.get("title", ""),
                    "name": r.get("title", ""),
                    "artist": aname,
                    "albumType": album_type,
                    "year": year_str,
                    "image": turl
                })
            elif flt == "artists" or rtype == "artist":
                arts = r.get("artists", [])
                a_name = r.get("artist") or (arts[0].get("name") if arts else "")
                a_id = (arts[0].get("id") if arts else "") or r.get("browseId", "")
                items.append({
                    "type": "artist",
                    "browseId": a_id,
                    "name": a_name,
                    "artist": a_name,
                    "subscribers": r.get("subscribers", ""),
                    "image": turl
                })
            elif flt in ("community_playlists", "featured_playlists") or rtype == "playlist":
                bid = r.get("browseId", "")
                author = r.get("author", "") or (r.get("artists", [{}])[0].get("name") if r.get("artists") else "")
                items.append({
                    "type": "playlist",
                    "id": bid,
                    "browseId": bid,
                    "title": r.get("title", ""),
                    "name": r.get("title", ""),
                    "author": author,
                    "artist": author,
                    "itemCount": r.get("itemCount", ""),
                    "image": turl
                })
        return items
    except Exception as e:
        sys.stderr.write(f"[filter_search error]: {e}\n")
        return []


def get_artist_shuffle(name, browse_id=None):
    """
    Fetches the full official YouTube Music artist shuffle queue (up to 50 tracks)
    using the artist's shuffleId (e.g. 'RDAO...'), with fallback to filter_search songs.
    """
    yt = get_ytmusic_client()
    tracks = []
    artist_name = (name or "").strip()
    clean_id = (browse_id or "").strip()

    # Strategy 1: Use official shuffleId from artist details
    if clean_id:
        try:
            art = get_artist(clean_id)
            if art and isinstance(art, dict):
                meta = art.get("metadata", {})
                if not artist_name:
                    artist_name = meta.get("name", "")
                shuf_id = meta.get("shuffleId")
                if shuf_id:
                    wp = yt.get_watch_playlist(playlistId=shuf_id)
                    raw_tracks = wp.get("tracks", [])
                    for t in raw_tracks:
                        norm = normalize_track(t)
                        if norm and not is_song_disliked(norm.get("videoId")):
                            tracks.append(norm)
                    if tracks:
                        cache_online_tracks(tracks)
                        return {"artist": artist_name, "playlistId": shuf_id, "tracks": tracks}
        except Exception as e:
            sys.stderr.write(f"[get_artist_shuffle strategy 1 error]: {e}\n")

    # Strategy 2: If no browse_id, search artist first to get browseId & shuffleId
    if not tracks and artist_name:
        try:
            sr = yt.search(artist_name, filter="artists")
            if sr and len(sr) > 0:
                first_aid = sr[0].get("browseId")
                if first_aid:
                    art = get_artist(first_aid)
                    if art and isinstance(art, dict):
                        shuf_id = art.get("metadata", {}).get("shuffleId")
                        if shuf_id:
                            wp = yt.get_watch_playlist(playlistId=shuf_id)
                            raw_tracks = wp.get("tracks", [])
                            for t in raw_tracks:
                                norm = normalize_track(t)
                                if norm and not is_song_disliked(norm.get("videoId")):
                                    tracks.append(norm)
                            if tracks:
                                cache_online_tracks(tracks)
                                return {"artist": artist_name, "playlistId": shuf_id, "tracks": tracks}
        except Exception as e:
            sys.stderr.write(f"[get_artist_shuffle strategy 2 error]: {e}\n")

    # Strategy 3: Fallback search songs by artist
    if not tracks and artist_name:
        try:
            songs = filter_search(artist_name, "songs")
            if songs:
                tracks = songs
        except Exception as e:
            sys.stderr.write(f"[get_artist_shuffle strategy 3 error]: {e}\n")

    return {"artist": artist_name, "playlistId": "songs", "tracks": tracks}




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
    if not query or not str(query).strip():
        return {"queries": [], "recommended": []}
    q = str(query).strip()

    # Method 1: Direct YouTube Music Innertube API (< 0.2s, music-specific + rich recommended songs with avatar)
    try:
        import urllib.request
        req_data = json.dumps({
            "context": {
                "client": {
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00",
                    "hl": "vi",
                    "gl": "VN"
                }
            },
            "input": q
        }).encode("utf-8")
        req = urllib.request.Request(
            "https://music.youtube.com/youtubei/v1/music/get_search_suggestions",
            data=req_data,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0",
                "Origin": "https://music.youtube.com"
            }
        )
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            queries = []
            recommended = []
            for content in data.get("contents", []):
                sec = content.get("searchSuggestionsSectionRenderer", {})
                for it in sec.get("contents", []):
                    # Query suggestion
                    if "searchSuggestionRenderer" in it:
                        runs = it["searchSuggestionRenderer"].get("suggestion", {}).get("runs", [])
                        text = "".join(r.get("text", "") for r in runs).strip()
                        if text and text not in queries:
                            queries.append(text)
                    # Recommended song item with thumbnail/avatar
                    elif "musicResponsiveListItemRenderer" in it:
                        r = it["musicResponsiveListItemRenderer"]
                        flex = r.get("flexColumns", [])
                        title = ""
                        subtitle = ""
                        if flex:
                            title_runs = flex[0].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])
                            title = "".join(x.get("text", "") for x in title_runs).strip()
                        if len(flex) > 1:
                            sub_runs = flex[1].get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}).get("runs", [])
                            subtitle = "".join(x.get("text", "") for x in sub_runs).strip()
                        thumbs = r.get("thumbnail", {}).get("musicThumbnailRenderer", {}).get("thumbnail", {}).get("thumbnails", [])
                        thumb = thumbs[-1].get("url", "") if thumbs else ""
                        thumb = re.sub(r'=w\d+-h\d+.*', '=w120-h120-l90-rj', thumb)
                        nav = r.get("navigationEndpoint", {})

                        # 1. Check Watch Endpoint (Song)
                        vid = nav.get("watchEndpoint", {}).get("videoId", "")
                        if not vid:
                            overlay = r.get("overlay", {}).get("musicItemThumbnailOverlayRenderer", {})
                            vid = overlay.get("content", {}).get("musicPlayButtonRenderer", {}).get("playNavigationEndpoint", {}).get("watchEndpoint", {}).get("videoId", "")

                        # 2. Check Browse Endpoint (Artist / Album)
                        browse_ep = nav.get("browseEndpoint", {})
                        browse_id = browse_ep.get("browseId", "")
                        page_type = browse_ep.get("browseEndpointContextSupportedConfigs", {}).get("browseEndpointContextMusicConfig", {}).get("pageType", "")
                        crop_circle = r.get("thumbnail", {}).get("musicThumbnailRenderer", {}).get("thumbnailCrop", "") == "MUSIC_THUMBNAIL_CROP_CIRCLE"

                        if title and (crop_circle or page_type == "MUSIC_PAGE_TYPE_ARTIST" or (browse_id and (browse_id.startswith("UC") or browse_id.startswith("FEmusic_library")))):
                            recommended.append({
                                "type": "artist",
                                "id": browse_id,
                                "browseId": browse_id,
                                "name": title,
                                "title": title,
                                "artist": title,
                                "subtitle": subtitle or "Nghệ sĩ",
                                "image": thumb
                            })
                        elif title and (page_type == "MUSIC_PAGE_TYPE_ALBUM" or (browse_id and browse_id.startswith("MPREb_"))):
                            recommended.append({
                                "type": "album",
                                "id": browse_id,
                                "browseId": browse_id,
                                "playlistId": browse_id,
                                "name": title,
                                "title": title,
                                "artist": subtitle,
                                "subtitle": subtitle or "Album",
                                "image": thumb
                            })
                        elif title and vid:
                            # Clean artist name (SimpMusic pattern)
                            parts = subtitle.split(" • ")
                            artist_name = parts[1].strip() if len(parts) > 1 else subtitle
                            recommended.append({
                                "type": "song",
                                "id": vid,
                                "videoId": vid,
                                "title": title,
                                "name": title,
                                "artist": artist_name,
                                "subtitle": subtitle,
                                "image": thumb,
                                "path": "ytdl://" + vid
                            })
            if queries or recommended:
                return {"queries": queries, "recommended": recommended}
    except Exception as e:
        sys.stderr.write(f"[innertube suggestions fallback]: {e}\n")

    # Method 2: Google Suggest Queries API (Instant < 0.1s fallback)
    try:
        import urllib.request
        import urllib.parse
        encoded_q = urllib.parse.quote(q)
        url = f"https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q={encoded_q}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=1.2) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if isinstance(data, list) and len(data) > 1 and isinstance(data[1], list):
                return {"queries": data[1], "recommended": []}
    except Exception as e:
        sys.stderr.write(f"[google suggest fallback]: {e}\n")

    # Method 3: ytmusicapi fallback
    try:
        yt = get_ytmusic_client()
        raw_sug = yt.get_search_suggestions(q)
        return {"queries": raw_sug if isinstance(raw_sug, list) else [], "recommended": []}
    except Exception as e:
        sys.stderr.write(f"[get_search_suggestions error]: {e}\n")
        return {"queries": [], "recommended": []}

QUALITY_ITAG_PRIORITIES = {
    "high_opus": [774, 141, 251, 140, 250],
    "high_aac": [141, 774, 140, 251, 250],
    "medium": [251, 140, 250, 141, 774],
    "low": [250, 249, 139, 251, 140, 141, 774]
}

def get_exported_cookie_file():
    if not os.path.exists(AUTH_FILE):
        return None
    try:
        data = load_json(AUTH_FILE, {})
        raw_cookie = data.get("cookie", "")
        if not raw_cookie:
            return None
        out_path = "/tmp/nutsty_yt_cookies.txt"
        now = int(time.time()) + 365 * 86400
        lines = ["# Netscape HTTP Cookie File\n"]
        for item in raw_cookie.split(";"):
            item = item.strip()
            if not item or "=" not in item:
                continue
            k, v = item.split("=", 1)
            lines.append(f".youtube.com\tTRUE\t/\tTRUE\t{now}\t{k.strip()}\t{v.strip()}\n")
        with open(out_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
        return out_path
    except Exception:
        return None

def resolve_stream_url(video_id, quality=None):
    if not video_id:
        return None

    if video_id.startswith("ytdl://"):
        video_id = video_id.replace("ytdl://", "")
    elif "watch?v=" in video_id:
        video_id = video_id.split("watch?v=")[1].split("&")[0]

    if not quality:
        settings_path = os.path.expanduser("~/.config/noctalia/nutsty_settings.json")
        if os.path.exists(settings_path):
            try:
                with open(settings_path, "r", encoding="utf-8") as f:
                    s_obj = json.load(f)
                    quality = s_obj.get("streamingQuality", "high_opus")
            except Exception:
                quality = "high_opus"
        else:
            quality = "high_opus"

    quality = quality if quality in QUALITY_ITAG_PRIORITIES else "high_opus"
    cache_key = f"{video_id}_{quality}"

    cache = load_json(STREAM_CACHE_FILE, {})
    cached = cache.get(cache_key)
    if not cached:
        legacy = cache.get(video_id)
        if legacy and legacy.get("quality") == quality:
            cached = legacy
    now = time.time()

    if cached and (now - cached.get("timestamp", 0)) < 10800:
        return cached

    try:
        import yt_dlp

        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "check_formats": False,
            "noplaylist": True,
            "extractor_args": {"youtube": {"player_client": ["android_music"]}}
        }
        url = f"https://www.youtube.com/watch?v={video_id}"
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            formats = [f for f in info.get("formats", []) if f.get("acodec") != "none"]

            # Select format matching priority list (SimpMusic Twin Fallback)
            priority = QUALITY_ITAG_PRIORITIES.get(quality, QUALITY_ITAG_PRIORITIES["high_opus"])
            selected_format = None
            for itag in priority:
                for f in formats:
                    fid = str(f.get("format_id") or "")
                    if fid == str(itag) and f.get("url"):
                        selected_format = f
                        break
                if selected_format:
                    break

            if not selected_format and formats:
                selected_format = formats[-1]

            stream_url = selected_format.get("url") if selected_format else info.get("url")
            duration = info.get("duration") or 0
            if stream_url:
                res = {
                    "stream_url": stream_url,
                    "duration": duration,
                    "quality": quality,
                    "itag": selected_format.get("format_id") if selected_format else None,
                    "bitrate": selected_format.get("abr") if selected_format else None,
                    "codec": selected_format.get("acodec") if selected_format else None,
                    "timestamp": now
                }
                cache[cache_key] = res
                save_json(STREAM_CACHE_FILE, cache)
                return res
    except Exception as e:
        sys.stderr.write(f"[resolve_stream_url error for {video_id} ({quality})]: {e}\n")

    return None

PENDING_HISTORY_FILE = os.path.expanduser("~/.cache/nutsty/pending_history.json")
LOCAL_YT_MAPPINGS_FILE = os.path.expanduser("~/.cache/nutsty/local_yt_mappings.json")

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
    Sends playback tracking and watchtime to Google account
    so that account records it in Watch History and updates personalized shelves.
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
    if not details["album"] or details["album"].lower() in ("single / simpmusic", "single / nutsty"):
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
RELATED_CACHE_DIR = os.path.expanduser("~/.cache/nutsty/related")

def get_song_related_content(video_id, title="", artist=""):
    clean_vid = resolve_video_id_for_track(video_id, title, artist)
    if not clean_vid:
        return {"you_might_also_like": [], "recommended_playlists": [], "similar_artists": []}

    os.makedirs(RELATED_CACHE_DIR, exist_ok=True)
    cache_path = os.path.join(RELATED_CACHE_DIR, f"{clean_vid}.json")
    if os.path.exists(cache_path):
        cached = load_json(cache_path)
        if cached and (time.time() - cached.get("timestamp", 0) < 86400):
            return cached

    yt = get_ytmusic_client()
    try:
        wp = yt.get_watch_playlist(clean_vid, limit=1)
        rel_id = wp.get("related")
        if not rel_id:
            return {"you_might_also_like": [], "recommended_playlists": [], "similar_artists": []}

        rel_sections = yt.get_song_related(rel_id)
        you_might_like = []
        rec_playlists = []
        similar_artists = []

        for sec in rel_sections:
            sec_title = sec.get("title", "")
            contents = sec.get("contents", [])
            if "You might also like" in sec_title or "bạn có thể thích" in sec_title.lower():
                for item in contents:
                    norm = normalize_track(item)
                    if norm:
                        you_might_like.append(norm)
            elif "Recommended playlists" in sec_title or "danh sách phát" in sec_title.lower():
                for item in contents:
                    p_id = item.get("playlistId", "")
                    p_title = item.get("title", "")
                    thumbs = item.get("thumbnails", [])
                    img = thumbs[-1].get("url", "") if thumbs else ""
                    desc = item.get("description", "")
                    if p_id and p_title:
                        rec_playlists.append({
                            "playlistId": p_id,
                            "id": p_id,
                            "title": p_title,
                            "image": img,
                            "description": desc,
                            "isOnline": True
                        })
            elif "Similar artists" in sec_title or "nghệ sĩ tương tự" in sec_title.lower():
                for item in contents:
                    a_name = item.get("title", "")
                    a_id = item.get("browseId", "")
                    thumbs = item.get("thumbnails", [])
                    img = thumbs[-1].get("url", "") if thumbs else ""
                    subs = item.get("subscribers", "")
                    if a_name:
                        similar_artists.append({
                            "name": a_name,
                            "channelId": a_id,
                            "image": img,
                            "subscribers": subs
                        })

        res = {
            "timestamp": time.time(),
            "videoId": clean_vid,
            "you_might_also_like": you_might_like[:16],
            "recommended_playlists": rec_playlists[:12],
            "similar_artists": similar_artists[:12]
        }
        save_json(cache_path, res)
        return res
    except Exception as e:
        sys.stderr.write(f"[get_song_related error for {clean_vid}]: {e}\n")
# ==============================================================================
# APPLE MUSIC ANIMATED ALBUM ARTWORK EXTRACTION (Item 25)
# ==============================================================================
AM_TOKEN_CACHE_FILE = os.path.expanduser("~/.cache/nutsty/am_token.json")
ANIMATED_ARTWORK_CACHE_FILE = os.path.expanduser("~/.cache/nutsty/animated_artworks.json")

def get_am_token():
    """Scrapes the public web-player bearer token (JWT) from music.apple.com."""
    import base64
    if os.path.exists(AM_TOKEN_CACHE_FILE):
        try:
            with open(AM_TOKEN_CACHE_FILE, "r", encoding="utf-8") as f:
                d = json.load(f)
                if time.time() - d.get("time", 0) < 43200:  # 12 hours
                    return d.get("token")
        except Exception:
            pass

    try:
        req = urllib.request.Request("https://music.apple.com", headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
        html = urllib.request.urlopen(req, timeout=8).read().decode("utf-8", errors="ignore")
        m = re.search(r"/assets/index~[^/\"]+\.js", html)
        if not m:
            return None
        js_url = "https://music.apple.com" + m.group(0)
        js_req = urllib.request.Request(js_url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
        js = urllib.request.urlopen(js_req, timeout=12).read().decode("utf-8", errors="ignore")
        jwts = re.findall(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", js)
        token = None
        for j in jwts:
            try:
                p = j.split(".")[1]
                pad = len(p) % 4
                pay = base64.urlsafe_b64decode(p + "=" * (4 - pad if pad else 0)).decode("utf-8", errors="ignore")
                if "AMPWebPlay" in pay:
                    token = j
                    break
            except Exception:
                pass
        if not token and jwts:
            token = jwts[0]

        if token:
            os.makedirs(os.path.dirname(AM_TOKEN_CACHE_FILE), exist_ok=True)
            with open(AM_TOKEN_CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump({"token": token, "time": time.time()}, f)
        return token
    except Exception as e:
        sys.stderr.write(f"[Apple Music Token Scrape Error]: {e}\n")
        return None

def select_am_rendition(master_url):
    """
    Parses HLS master playlist from Apple Music and selects optimal avc1 video rendition:
    codec is decided before quality (avc1 over 10-bit HEVC), picking ~768x768 or resolution >= 720px.
    """
    if not master_url:
        return ""
    try:
        import urllib.parse
        req = urllib.request.Request(master_url, headers={"User-Agent": "Mozilla/5.0"})
        content = urllib.request.urlopen(req, timeout=6).read().decode("utf-8", errors="ignore")
        lines = content.splitlines()

        variants = []
        cur_inf = None
        for line in lines:
            line = line.strip()
            if line.startswith("#EXT-X-STREAM-INF:"):
                cur_inf = line
            elif line and not line.startswith("#") and cur_inf:
                codec_m = re.search(r'CODECS="([^"]+)"', cur_inf)
                res_m = re.search(r'RESOLUTION=(\d+)x(\d+)', cur_inf)
                bw_m = re.search(r'BANDWIDTH=(\d+)', cur_inf)
                codec = codec_m.group(1) if codec_m else ""
                w = int(res_m.group(1)) if res_m else 0
                h = int(res_m.group(2)) if res_m else 0
                bw = int(bw_m.group(1)) if bw_m else 0

                v_url = line if line.startswith("http") else urllib.parse.urljoin(master_url, line)
                variants.append({
                    "url": v_url,
                    "codec": codec,
                    "width": w,
                    "height": h,
                    "bandwidth": bw
                })
                cur_inf = None

        avc1_variants = [v for v in variants if "avc1" in v["codec"].lower()]
        if not avc1_variants:
            avc1_variants = variants

        suitable = [v for v in avc1_variants if v["width"] >= 720]
        if suitable:
            suitable.sort(key=lambda x: (x["width"], x["bandwidth"]))
            return suitable[0]["url"]
        elif avc1_variants:
            avc1_variants.sort(key=lambda x: -x["width"])
            return avc1_variants[0]["url"]

        return master_url
    except Exception as e:
        sys.stderr.write(f"[select_am_rendition error]: {e}\n")
        return master_url

def clean_for_search(text):
    if not text:
        return ""
    s = re.sub(r"\((feat\.|ft\.|cùng với|con|mukana|com|avec|official|mv|lyrics|audio).*?\)", "", text, flags=re.IGNORECASE)
    s = re.sub(r"\[.*?\]", "", s)
    s = re.sub(r"\((.*?)\)", r"\1", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def normalize_for_match(text):
    if not text:
        return ""
    cleaned = "".join(c if c.isalnum() else " " for c in text.lower())
    tokens = [w for w in cleaned.split() if w]
    return " ".join(tokens)

def match_key(text):
    norm = normalize_for_match(text)
    return norm if norm else text.strip().lower()

def matches_loosely(a, b):
    ka = match_key(a)
    kb = match_key(b)
    if not ka or not kb:
        return False
    if ka == kb or ka in kb or kb in ka:
        return True
    sa = set(ka.split())
    sb = set(kb.split())
    if sa and sb:
        overlap = sa & sb
        if len(overlap) / min(len(sa), len(sb)) >= 0.5:
            return True
    return False

def artist_agrees(cand_artist, query_artist):
    if not query_artist:
        return True
    if not cand_artist:
        return False
    return matches_loosely(cand_artist, query_artist)

def match_score(candidate, subject):
    c = match_key(candidate)
    s = match_key(subject)
    if not c or not s:
        return None
    if c == s:
        return (0, 0)
    if c.startswith(s):
        return (1, len(c) - len(s))
    if s in c:
        return (2, len(c) - len(s))
    if c in s:
        # If candidate is a substring of subject, ensure it is substantial (at least 60% of length or >= 12 chars)
        if len(c) >= 12 or (len(c) / max(1, len(s))) >= 0.60:
            return (3, len(s) - len(c))
        return None
    return None

def get_apple_music_animated_artwork(title, artist, duration_seconds=0, album_hint=""):
    """
    Searches Apple Music catalog for an album's editorialVideo animated artwork.
    Strictly follows SimpMusic's pickSongMatch architecture:
    1. Artist MUST agree (matches_loosely).
    2. Song title MUST match closely (tiers 0-3: exact, prefix, substring, superstring).
    3. EditorialVideo is ONLY inspected on albums directly associated with the MATCHED song candidate.
    4. Arbitrary album fallback is strictly forbidden to prevent unrelated animated covers.
    """
    if not title:
        return {"found": False}
    import urllib.parse
    clean_title = clean_for_search(title)
    clean_artist = clean_for_search(artist)
    cache_key = f"{match_key(clean_title)}_{match_key(clean_artist)}"

    cached_data = load_json(ANIMATED_ARTWORK_CACHE_FILE, {})
    if cache_key in cached_data:
        entry = cached_data[cache_key]
        if time.time() - entry.get("timestamp", 0) < 86400 * 7:  # 7 days cache
            return entry

    token = get_am_token()
    if not token:
        return {"found": False, "error": "token_unavailable"}

    try:
        query = f"{clean_title} {clean_artist}".strip()
        # Query storefront "vn" first (covers Vietnamese catalog and international releases), then "us"
        for sf in ["vn", "us"]:
            encoded_query = urllib.parse.quote(query)
            search_url = (
                f"https://amp-api-edge.music.apple.com/v1/catalog/{sf}/search?"
                f"term={encoded_query}&types=songs&include[songs]=albums&format[resources]=map&extend=editorialVideo&limit=5&platform=web"
            )
            req = urllib.request.Request(
                search_url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Origin": "https://music.apple.com",
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"
                }
            )
            try:
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode("utf-8", errors="ignore"))
            except Exception:
                continue

            albums = data.get("resources", {}).get("albums", {})
            songs = data.get("resources", {}).get("songs", {})

            candidates = []
            for rank, (sid, s) in enumerate(songs.items()):
                attrs = s.get("attributes", {})
                cand_name = attrs.get("name", "")
                cand_artist = attrs.get("artistName", "")

                # 1. Artist MUST agree
                if not artist_agrees(cand_artist, clean_artist):
                    continue

                # 2. Title MUST match
                score = match_score(cand_name, clean_title)
                if score is None:
                    continue

                cand_dur = (attrs.get("durationInMillis") or 0) / 1000.0
                dur_misses = False
                if duration_seconds > 0 and cand_dur > 0:
                    if abs(cand_dur - duration_seconds) > 5.5:
                        dur_misses = True

                # 3. Check if any associated album of THIS SPECIFIC song has editorialVideo
                rel_albums = s.get("relationships", {}).get("albums", {}).get("data", [])
                has_artwork = False
                matched_album_name = ""
                found_video = None
                album_hint_misses = False

                for a_ref in rel_albums:
                    aid = a_ref.get("id")
                    if aid in albums:
                        a_data = albums[aid]
                        a_name = a_data.get("attributes", {}).get("name", "")
                        if album_hint and a_name:
                            alb_sc = match_score(a_name, album_hint)
                            if not alb_sc or alb_sc[0] != 0:
                                album_hint_misses = True

                        ev = a_data.get("attributes", {}).get("editorialVideo", {})
                        if ev:
                            for k in ["motionSquareVideo1x1", "motionDetailSquare", "motionDetailTall", "motionTallVideo3x4"]:
                                if k in ev and "video" in ev[k]:
                                    found_video = ev[k]["video"]
                                    break
                            if not found_video:
                                for k, v in ev.items():
                                    if isinstance(v, dict) and "video" in v:
                                        found_video = v["video"]
                                        break
                            if found_video:
                                has_artwork = True
                                matched_album_name = a_name
                                break

                # Penalty / Demote (SimpMusic formula: durationMisses=4, hintMisses=2, hasNoArtwork=1)
                demote = (4 if dur_misses else 0) + (2 if album_hint_misses else 0) + (0 if has_artwork else 1)
                tier, extra_len = score
                candidates.append({
                    "tier": tier,
                    "extra_len": extra_len,
                    "demote": demote,
                    "rank": rank,
                    "has_artwork": has_artwork,
                    "album_name": matched_album_name,
                    "video_url": found_video,
                    "cand_name": cand_name,
                    "cand_artist": cand_artist
                })

            if candidates:
                # Rank candidates: tier -> extra_len -> demote -> rank
                candidates.sort(key=lambda x: (x["tier"], x["extra_len"], x["demote"], x["rank"]))
                best = candidates[0]
                if best["has_artwork"] and best["video_url"]:
                    rendition_url = select_am_rendition(best["video_url"])
                    res = {
                        "found": True,
                        "video_url": rendition_url,
                        "master_url": best["video_url"],
                        "album_name": best["album_name"],
                        "storefront": sf,
                        "timestamp": time.time()
                    }
                    cached_data[cache_key] = res
                    save_json(ANIMATED_ARTWORK_CACHE_FILE, cached_data)
                    return res
                else:
                    # The genuine matched song's album has no animated artwork.
                    # Do NOT fallback to random albums!
                    res = {
                        "found": False,
                        "reason": "no_animated_artwork_on_album",
                        "storefront": sf,
                        "timestamp": time.time()
                    }
                    cached_data[cache_key] = res
                    save_json(ANIMATED_ARTWORK_CACHE_FILE, cached_data)
                    return res

        # No candidate song matched across storefronts
        res = {"found": False, "reason": "no_song_candidate_matched", "timestamp": time.time()}
        cached_data[cache_key] = res
        save_json(ANIMATED_ARTWORK_CACHE_FILE, cached_data)
        return res

    except Exception as e:
        sys.stderr.write(f"[Apple Music Animated Artwork Error for {title}]: {e}\n")
        return {"found": False, "error": str(e)}

_square_cover_cache = None

def _get_square_covers_cache():
    global _square_cover_cache
    if _square_cover_cache is None:
        _square_cover_cache = load_json(SQUARE_COVERS_CACHE_FILE, {})
    return _square_cover_cache

def _save_square_covers_cache():
    global _square_cover_cache
    if _square_cover_cache is not None:
        save_json(SQUARE_COVERS_CACHE_FILE, _square_cover_cache)

def resolve_square_cover(title, artist="", video_id=None, current_image=None):
    """
    2-Tier Resolver for 1:1 Square Album Artwork:
    Tier 0: If current_image is already a Google CDN square artwork, upscale to 1200px and return immediately.
    Tier 1: Search official song release on YouTube Music (filter='songs', limit=5).
            If a matching song candidate exists, extract native square 1:1 artwork.
    Tier 2 (Fallback): Return current_image or maxresdefault.jpg.
    """
    clean_title = str(title or "").strip()
    clean_artist = str(artist or "").strip()
    clean_vid = str(video_id or "").strip().replace("ytdl://", "").replace("yt_", "")
    curr_img = str(current_image or "").strip()

    # Tier 0: Already native square Google CDN or Apple Music image
    if curr_img and ("googleusercontent.com" in curr_img or "ggpht.com" in curr_img):
        upgraded = re.sub(r'=w\d+-h\d+.*', '=w1200-h1200-l90-rj', curr_img)
        if "=w1200-h1200-l90-rj" not in upgraded:
            if "=" in upgraded:
                upgraded = upgraded.split("=")[0] + "=w1200-h1200-l90-rj"
            else:
                upgraded = upgraded + "=w1200-h1200-l90-rj"
        return {"url": upgraded, "is_square": True, "cached": True}

    if curr_img and "mzstatic.com" in curr_img:
        upgraded = re.sub(r'\d+x\d+bb', '1200x1200bb', curr_img)
        return {"url": upgraded, "is_square": True, "cached": True}

    cache_key = clean_vid if clean_vid else f"{clean_title}_{clean_artist}".lower()
    if cache_key:
        cached_data = _get_square_covers_cache().get(cache_key)
        if cached_data and cached_data.get("is_square"):
            return cached_data

    # Tier 1: Search official song release on YouTube Music (1:1 Google CDN)
    ytm = get_ytmusic_client()
    query = f"{clean_title} {clean_artist}".strip()
    if not query and clean_title:
        query = clean_title

    if query and ytm:
        try:
            results = ytm.search(query, filter="songs", limit=5)
            for r in results:
                t = r.get("title", "")
                r_artists = [a.get("name", "") for a in r.get("artists", []) if isinstance(a, dict)]
                cand_artist_str = ", ".join(r_artists)

                sc = match_score(t, clean_title)
                agree = artist_agrees(cand_artist_str, clean_artist) if clean_artist else True
                if (sc is not None) and agree:
                    thumbs = r.get("thumbnails", [])
                    if thumbs:
                        thumb_url = thumbs[-1].get("url", "")
                        if "googleusercontent.com" in thumb_url or "ggpht.com" in thumb_url:
                            upgraded = re.sub(r'=w\d+-h\d+.*', '=w1200-h1200-l90-rj', thumb_url)
                            if "=w1200-h1200-l90-rj" not in upgraded:
                                if "=" in upgraded:
                                    upgraded = upgraded.split("=")[0] + "=w1200-h1200-l90-rj"
                                else:
                                    upgraded = upgraded + "=w1200-h1200-l90-rj"
                            res = {
                                "url": upgraded,
                                "is_square": True,
                                "title": t,
                                "videoId": r.get("videoId", ""),
                                "match": "official_ytm_song"
                            }
                            if cache_key:
                                _get_square_covers_cache()[cache_key] = res
                                _save_square_covers_cache()
                            return res
        except Exception as e:
            sys.stderr.write(f"[resolve_square_cover YTM error]: {e}\n")

    # Tier 1.5: Search official song release on iTunes / Apple Music (1200x1200bb 1:1)
    if query:
        try:
            import urllib.request, urllib.parse
            itunes_url = f"https://itunes.apple.com/search?term={urllib.parse.quote(query)}&entity=song&limit=5"
            it_req = urllib.request.Request(itunes_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(it_req, timeout=3.5) as resp:
                it_data = json.loads(resp.read().decode("utf-8", errors="ignore"))
                for r in it_data.get("results", []):
                    t = r.get("trackName", "")
                    cand_artist = r.get("artistName", "")
                    sc = match_score(t, clean_title)
                    agree = artist_agrees(cand_artist, clean_artist) if clean_artist else True
                    if (sc is not None) and agree:
                        art = r.get("artworkUrl100", "")
                        if art:
                            art1200 = re.sub(r'\d+x\d+bb', '1200x1200bb', art)
                            res = {
                                "url": art1200,
                                "is_square": True,
                                "title": t,
                                "artist": cand_artist,
                                "match": "official_itunes_song"
                            }
                            if cache_key:
                                _get_square_covers_cache()[cache_key] = res
                                _save_square_covers_cache()
                            return res
        except Exception as e:
            sys.stderr.write(f"[resolve_square_cover iTunes error]: {e}\n")

    # Tier 2 Fallback: YouTube HD Thumbnail (maxresdefault.jpg 1280x720)
    fallback_url = curr_img
    if not fallback_url and clean_vid:
        fallback_url = f"https://i.ytimg.com/vi/{clean_vid}/maxresdefault.jpg"
    elif fallback_url and "i.ytimg.com" in fallback_url:
        clean_yt = fallback_url.split("?")[0]
        if "maxresdefault.jpg" not in clean_yt:
            fallback_url = re.sub(r'/(hqdefault|mqdefault|sddefault|default|hq720)\.jpg', '/maxresdefault.jpg', clean_yt)
        else:
            fallback_url = clean_yt

    # Do not permanently cache fallback covers so future attempts or corrected metadata can resolve the official square art
    return {"url": fallback_url, "is_square": False, "match": "fallback"}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: ytmusic_helper.py [home | radio <id> | mood <params> | playlist <id> | search <q> | get_url <id> | auth_status | save_auth <text> | logout | track_playback <id> | song_details <id> | rate_song <id> <rating> | song_related <id>]")
        sys.exit(1)

    cmd = sys.argv[1].lower()
    if cmd == "song_related" and len(sys.argv) > 2:
        vid = sys.argv[2]
        title = sys.argv[3] if len(sys.argv) > 3 else ""
        artist = sys.argv[4] if len(sys.argv) > 4 else ""
        res = get_song_related_content(vid, title, artist)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "song_details" and len(sys.argv) > 2:
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

    elif cmd == "next_chips" and len(sys.argv) > 2:
        vid = sys.argv[2]
        res = get_watch_playlist_chips(vid)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "filter_queue" and len(sys.argv) > 3:
        vid = sys.argv[2]
        pl_id = sys.argv[3]
        params = sys.argv[4] if len(sys.argv) > 4 else None
        res = get_filtered_radio_queue(vid, pl_id, params)
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

    elif cmd == "categorized_search":
        q = sys.argv[2] if len(sys.argv) > 2 else "Trending"
        res = search_categorized(q)
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

    elif cmd == "filter_search" and len(sys.argv) > 2:
        q = sys.argv[2]
        flt = sys.argv[3] if len(sys.argv) > 3 else "songs"
        res = filter_search(q, flt)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "artist_shuffle" and len(sys.argv) > 2:
        name = sys.argv[2]
        browse_id = sys.argv[3] if len(sys.argv) > 3 else None
        res = get_artist_shuffle(name, browse_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "animated_artwork" and len(sys.argv) > 2:
        title = sys.argv[2]
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        dur = float(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else 0.0
        album_hint = sys.argv[5] if len(sys.argv) > 5 else ""
        res = get_apple_music_animated_artwork(title, artist, dur, album_hint)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "resolve_stream" and len(sys.argv) > 2:
        vid = sys.argv[2]
        qual = sys.argv[3] if len(sys.argv) > 3 else None
        res = resolve_stream_url(vid, qual)
        print(json.dumps(res, ensure_ascii=False) if res else "{}")

    elif cmd == "resolve_cover" and len(sys.argv) > 2:
        title = sys.argv[2]
        artist = sys.argv[3] if len(sys.argv) > 3 else ""
        vid = sys.argv[4] if len(sys.argv) > 4 else None
        curr = sys.argv[5] if len(sys.argv) > 5 else None
        res = resolve_square_cover(title, artist, vid, curr)
        print(json.dumps(res, ensure_ascii=False))




