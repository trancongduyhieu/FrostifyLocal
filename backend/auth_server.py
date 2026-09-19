#!/usr/bin/env python3
"""
Nutsty 1-Click Auth Webhook Server
Listens strictly on 127.0.0.1:17890 for cookie sync from browser extension
"""
import os
import sys
import json
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import ytmusic_helper
from datetime import datetime

def get_notes_vault_path():
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "nutsty_notes_vault.json")

def load_notes_vault():
    p = get_notes_vault_path()
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_notes_vault(data):
    p = get_notes_vault_path()
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

def get_events_vault_path():
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "nutsty_notes_events.json")

def load_events_vault():
    p = get_events_vault_path()
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return []

def save_events_vault(data):
    p = get_events_vault_path()
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

PORT = 17890
HOST = "127.0.0.1"

class AuthWebhookHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        from urllib.parse import urlparse, parse_qs
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        query = parse_qs(parsed_url.query)

        if path == "/api/auth/status":
            st = ytmusic_helper.get_auth_status()
            payload = json.dumps(st, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/mood":
            params = query.get("params", [""])[0]
            title = query.get("title", [""])[0]
            data = ytmusic_helper.get_mood_feed(params, title)
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/home":
            data = ytmusic_helper.get_personalized_home()
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/suggestions":
            q = query.get("q", [""])[0]
            data = ytmusic_helper.get_search_suggestions(q)
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/filter_search":
            q = query.get("q", [""])[0]
            flt = query.get("filter", ["songs"])[0]
            data = ytmusic_helper.filter_search(q, flt)
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/playlist":
            pl_id = query.get("id", [""])[0]
            data = ytmusic_helper.get_playlist_tracks(pl_id)
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/artist_shuffle":
            name = query.get("name", [""])[0]
            browse_id = query.get("browseId", [""])[0]
            try:
                data = ytmusic_helper.get_artist_shuffle(name, browse_id)
            except Exception as e:
                print(f"[artist_shuffle error]: {e}", flush=True)
                data = {"artist": name, "tracks": []}
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/resolve_cover":
            title = query.get("title", [""])[0]
            artist = query.get("artist", [""])[0]
            vid = query.get("videoId", [""])[0]
            curr = query.get("current", [""])[0]
            try:
                data = ytmusic_helper.resolve_square_cover(title, artist, vid, curr)
            except Exception as e:
                sys.stderr.write(f"[resolve_cover error]: {e}\n")
                data = {"url": curr, "is_square": False, "match": "error"}
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/notes":
            friends_raw = query.get("friends", [""])[0]
            friends = [f.strip().lower() for f in friends_raw.split(",") if f.strip()]
            user_email = query.get("user_email", [""])[0].strip().lower()
            vault = load_notes_vault()
            now = time.time()
            valid_notes = []
            my_note = None
            cleaned_vault = {}
            for k, item in vault.items():
                if item.get("_expires_ts", 0) > now:
                    cleaned_vault[k] = item
                    iem = item.get("user_email", "").strip().lower()
                    if iem in friends:
                        valid_notes.append(item)
                    if user_email and iem == user_email:
                        my_note = item
            if len(cleaned_vault) != len(vault):
                save_notes_vault(cleaned_vault)
            data = {"count": len(valid_notes), "notes": valid_notes, "my_note": my_note}
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif path == "/api/notes/events":
            user_email = query.get("user_email", [""])[0].strip().lower()
            all_events = load_events_vault()
            my_events = []
            remaining_events = []
            now = time.time()
            for ev in all_events:
                # Keep events under 10 minutes old
                if ev.get("timestamp", 0) > now - 600:
                    if user_email and ev.get("to_email", "").strip().lower() == user_email:
                        my_events.append(ev)
                    else:
                        remaining_events.append(ev)
            if len(all_events) != len(remaining_events):
                save_events_vault(remaining_events)
            data = {"count": len(my_events), "events": my_events}
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()

    def do_POST(self):
        if self.path in ("/api/auth/cookies", "/api/auth/sync"):
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            
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
            payload = json.dumps(res, ensure_ascii=False).encode("utf-8")

            self.send_response(status_code)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif self.path == "/api/notes":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}

            email = req_data.get("user_email", "").strip().lower()
            note_text = req_data.get("note_text", "").strip()

            if not email or not note_text:
                res = {"success": False, "error": "Missing required fields"}
                status_code = 400
            else:
                ttl = 86400
                now = time.time()
                record = {
                    "user_email": email,
                    "user_name": req_data.get("user_name", "Anonymous"),
                    "avatar_url": req_data.get("avatar_url", ""),
                    "note_text": note_text[:80],
                    "track": req_data.get("track"),
                    "created_at": datetime.fromtimestamp(now).isoformat(),
                    "expires_at": datetime.fromtimestamp(now + ttl).isoformat(),
                    "_expires_ts": now + ttl
                }
                vault = load_notes_vault()
                vault[f"note:{email}"] = record
                save_notes_vault(vault)
                res = {"success": True, "note": record}
                status_code = 200

            payload = json.dumps(res, ensure_ascii=False).encode("utf-8")
            self.send_response(status_code)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif self.path == "/api/notes/delete":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            email = req_data.get("user_email", "").strip().lower()
            if email:
                vault = load_notes_vault()
                vault.pop(f"note:{email}", None)
                save_notes_vault(vault)
            res = {"success": True}
            payload = json.dumps(res, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        elif self.path == "/api/notes/events":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            ev_type = req_data.get("event", "leave")
            from_email = req_data.get("from_email", "").strip()
            from_name = req_data.get("from_name", "").strip()
            to_email = req_data.get("to_email", "").strip()
            if not to_email:
                res = {"success": False, "error": "Missing to_email"}
                status_code = 400
            else:
                events = load_events_vault()
                ev = {
                    "id": f"ev_{int(time.time()*1000)}",
                    "event": ev_type,
                    "from_email": from_email,
                    "from_name": from_name,
                    "to_email": to_email,
                    "timestamp": time.time(),
                    "created_at": datetime.now().isoformat()
                }
                events.append(ev)
                save_events_vault(events)
                res = {"success": True, "event": ev}
                status_code = 200
            payload = json.dumps(res, ensure_ascii=False).encode("utf-8")
            self.send_response(status_code)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()

    def log_message(self, format, *args):
        # Silence default stderr logging
        pass

def run_server():
    server_address = (HOST, PORT)
    try:
        httpd = HTTPServer(server_address, AuthWebhookHandler)
        print(f"Nutsty Auth Server listening on http://{HOST}:{PORT}")
        httpd.serve_forever()
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"Nutsty Auth Server port {PORT} already active.")
        else:
            sys.stderr.write(f"Auth server error: {e}\n")

if __name__ == "__main__":
    run_server()
