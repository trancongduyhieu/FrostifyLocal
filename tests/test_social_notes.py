#!/usr/bin/env python3
"""
Test Suite for Nutsty 24h Social Notes
Tests local mock server, TTL behavior, JSON format, and multi-user note exchange.
"""

import sys
import json
import time
import threading
import unittest
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from datetime import datetime, timedelta

# In-memory storage mimicking Cloudflare KV
MOCK_KV = {}

class MockCloudflareHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # Silence server logs during tests

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == "/api/notes":
            content_len = int(self.headers.get("Content-Length", 0))
            body_bytes = self.rfile.read(content_len)
            data = json.loads(body_bytes.decode("utf-8"))

            email = data.get("user_email", "").strip().lower()
            note_text = data.get("note_text", "").strip()

            if not email or not note_text:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error": "Missing fields"}')
                return

            ttl = 86400
            now = time.time()
            record = {
                "user_email": email,
                "user_name": data.get("user_name", "Anonymous"),
                "avatar_url": data.get("avatar_url", ""),
                "note_text": note_text[:80],
                "track": data.get("track"),
                "created_at": datetime.fromtimestamp(now).isoformat(),
                "expires_at": datetime.fromtimestamp(now + ttl).isoformat(),
                "_expires_ts": now + ttl
            }
            MOCK_KV[f"note:{email}"] = record

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": True, "note": record}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/api/notes":
            qs = parse_qs(url.query)
            friends_raw = qs.get("friends", [""])[0]
            friends = [f.strip().lower() for f in friends_raw.split(",") if f.strip()]

            now = time.time()
            notes = []
            for f in friends:
                item = MOCK_KV.get(f"note:{f}")
                if item:
                    # Check TTL
                    if item.get("_expires_ts", 0) > now:
                        notes.append(item)
                    else:
                        del MOCK_KV[f"note:{f}"]

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"count": len(notes), "notes": notes}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()


class SocialNotesTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 18991), MockCloudflareHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def setUp(self):
        MOCK_KV.clear()

    def test_post_and_retrieve_note(self):
        import urllib.request

        # 1. User A posts a note
        post_data = {
            "user_email": "apple@gmail.com",
            "user_name": "Duy Hieu",
            "avatar_url": "https://example.com/avatar_a.png",
            "note_text": "Hôm nay trời đẹp quá, đang nghe lofi chill...",
            "track": {
                "id": "trk_123",
                "title": "Ghé Qua",
                "artist": "Dick, PC, Tofu",
                "cover": "https://example.com/cover.jpg"
            }
        }
        req = urllib.request.Request(
            "http://127.0.0.1:18991/api/notes",
            data=json.dumps(post_data).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            res_json = json.loads(resp.read().decode("utf-8"))
            self.assertTrue(res_json["success"])
            self.assertEqual(res_json["note"]["note_text"], post_data["note_text"])

        # 2. Friend B queries notes of User A
        req_get = urllib.request.Request("http://127.0.0.1:18991/api/notes?friends=apple@gmail.com")
        with urllib.request.urlopen(req_get) as resp:
            self.assertEqual(resp.status, 200)
            res_json = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(res_json["count"], 1)
            friend_note = res_json["notes"][0]
            self.assertEqual(friend_note["user_email"], "apple@gmail.com")
            self.assertEqual(friend_note["track"]["title"], "Ghé Qua")

    def test_ttl_expiration_behavior(self):
        import urllib.request

        # Inject an expired note into KV
        expired_ts = time.time() - 100 # expired in the past
        MOCK_KV["note:expired_friend@gmail.com"] = {
            "user_email": "expired_friend@gmail.com",
            "note_text": "Old note from yesterday",
            "_expires_ts": expired_ts
        }

        # Query should not return expired note
        req = urllib.request.Request("http://127.0.0.1:18991/api/notes?friends=expired_friend@gmail.com")
        with urllib.request.urlopen(req) as resp:
            res_json = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(res_json["count"], 0)


if __name__ == "__main__":
    unittest.main()
