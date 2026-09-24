#!/usr/bin/env python3
"""
Nutsty Music & Authentication HTTP Route Handlers
Extracted from auth_server.py for clean modularity and CodeGraph AST function indexing.
"""
import sys
import json

try:
    from . import ytmusic_helper
except (ImportError, ValueError):
    import ytmusic_helper


def handle_get_auth_status(handler):
    st = ytmusic_helper.get_auth_status()
    handler._send_json(st, 200)


def handle_get_mood(handler, query):
    params = query.get("params", [""])[0]
    title = query.get("title", [""])[0]
    try:
        data = ytmusic_helper.get_mood_feed(params, title)
    except Exception:
        data = {"sections": [], "quick_picks": [], "featured_playlists": []}
    handler._send_json(data, 200)


def handle_get_home(handler):
    try:
        data = ytmusic_helper.get_personalized_home()
    except Exception:
        data = {"moods": [], "sections": [], "quick_picks": [], "featured_playlists": []}
    handler._send_json(data, 200)


def handle_get_suggestions(handler, query):
    q = query.get("q", [""])[0]
    data = ytmusic_helper.get_search_suggestions(q)
    handler._send_json(data, 200)


def handle_get_filter_search(handler, query):
    q = query.get("q", [""])[0]
    flt = query.get("filter", ["songs"])[0]
    data = ytmusic_helper.filter_search(q, flt)
    handler._send_json(data, 200)


def handle_get_playlist(handler, query):
    pl_id = query.get("id", [""])[0]
    data = ytmusic_helper.get_playlist_tracks(pl_id)
    handler._send_json(data, 200)


def handle_get_artist_shuffle(handler, query):
    name = query.get("name", [""])[0]
    browse_id = query.get("browseId", [""])[0]
    try:
        data = ytmusic_helper.get_artist_shuffle(name, browse_id)
    except Exception as e:
        print(f"[artist_shuffle error]: {e}", flush=True)
        data = {"artist": name, "tracks": []}
    handler._send_json(data, 200)


def handle_get_resolve_cover(handler, query):
    title = query.get("title", [""])[0]
    artist = query.get("artist", [""])[0]
    vid = query.get("videoId", [""])[0]
    curr = query.get("current", [""])[0]
    try:
        data = ytmusic_helper.resolve_square_cover(title, artist, vid, curr)
    except Exception as e:
        sys.stderr.write(f"[resolve_cover error]: {e}\n")
        data = {"url": curr, "is_square": False, "match": "error"}
    handler._send_json(data, 200)


def handle_post_auth_cookies(handler, post_body):
    raw_data = None
    try:
        parsed = json.loads(post_body)
        if isinstance(parsed, dict):
            raw_data = parsed.get("cookies") or parsed.get("youtubeMusic") or parsed.get("data") or parsed
        else:
            raw_data = parsed
    except Exception:
        raw_data = post_body

    res = ytmusic_helper.save_auth(raw_data)
    status_code = 200 if res.get("success") else 400
    handler._send_json(res, status_code)
