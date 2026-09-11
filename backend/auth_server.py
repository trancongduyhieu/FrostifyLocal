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
