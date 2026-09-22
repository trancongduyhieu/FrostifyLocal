#!/usr/bin/env python3
"""
Nutsty 1-Click Auth Webhook Server
Listens strictly on 127.0.0.1:17890 for cookie sync from browser extension
"""
import os
import sys
import json
import time
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import ytmusic_helper
from datetime import datetime
import sqlite3
import uuid
import random
import urllib.request
import urllib.error

try:
    from . import platform_compat as pc
except (ImportError, ValueError):
    import platform_compat as pc

pc.configure_windows_ssl()

def get_nutsty_config_dir():
    return pc.get_config_dir()

def get_cloud_relay_db_path():
    d = get_nutsty_config_dir()
    return os.path.join(d, "nutsty_cloud_relay.db")

class CloudRelayEngine:
    """Local SQLite engine mirroring Cloudflare D1 schema for Nutsty Global Relay."""
    def __init__(self, db_path=None):
        self.db_path = db_path or get_cloud_relay_db_path()
        self._init_db()

    def _get_conn(self):
        conn = sqlite3.connect(self.db_path, timeout=10.0)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        with self._get_conn() as conn:
            conn.executescript("""
            CREATE TABLE IF NOT EXISTS nutsty_users (
                id TEXT PRIMARY KEY,
                secret_key TEXT NOT NULL,
                username TEXT NOT NULL,
                discriminator TEXT NOT NULL,
                tag TEXT NOT NULL UNIQUE,
                avatar_url TEXT DEFAULT '',
                now_playing TEXT DEFAULT '',
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                last_active_at INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_users_tag ON nutsty_users(tag);
            CREATE INDEX IF NOT EXISTS idx_users_username ON nutsty_users(username);
            CREATE INDEX IF NOT EXISTS idx_users_discriminator ON nutsty_users(discriminator);

            CREATE TABLE IF NOT EXISTS nutsty_friendships (
                id TEXT PRIMARY KEY,
                user_id_1 TEXT NOT NULL,
                user_id_2 TEXT NOT NULL,
                status TEXT NOT NULL,
                initiated_by TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                FOREIGN KEY(user_id_1) REFERENCES nutsty_users(id),
                FOREIGN KEY(user_id_2) REFERENCES nutsty_users(id),
                UNIQUE(user_id_1, user_id_2)
            );

            CREATE INDEX IF NOT EXISTS idx_friendships_u1 ON nutsty_friendships(user_id_1);
            CREATE INDEX IF NOT EXISTS idx_friendships_u2 ON nutsty_friendships(user_id_2);

            CREATE TABLE IF NOT EXISTS nutsty_events (
                id TEXT PRIMARY KEY,
                to_user_id TEXT NOT NULL,
                from_user_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                payload TEXT NOT NULL,
                consumed INTEGER DEFAULT 0,
                created_at INTEGER NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_events_to_user ON nutsty_events(to_user_id, consumed);
            """)

    def find_available_discriminator(self, username, preferred=None):
        clean_user = username.strip()
        with self._get_conn() as conn:
            if preferred and len(str(preferred)) == 4 and str(preferred).isdigit():
                cand = f"{clean_user}#{str(preferred).zfill(4)}"
                row = conn.execute("SELECT id FROM nutsty_users WHERE tag = ?", (cand,)).fetchone()
                if not row:
                    return str(preferred).zfill(4)
            for _ in range(30):
                rnd = str(random.randint(1000, 9999))
                cand = f"{clean_user}#{rnd}"
                row = conn.execute("SELECT id FROM nutsty_users WHERE tag = ?", (cand,)).fetchone()
                if not row:
                    return rnd
            for i in range(1, 10000):
                pad = str(i).zfill(4)
                cand = f"{clean_user}#{pad}"
                row = conn.execute("SELECT id FROM nutsty_users WHERE tag = ?", (cand,)).fetchone()
                if not row:
                    return pad
        return "0001"

    def register(self, username, avatar_url="", client_secret=None, user_id=None, preferred_discriminator=None):
        clean_user = (username or "User").strip()[:32]
        now = int(time.time() * 1000)
        with self._get_conn() as conn:
            if user_id and client_secret:
                row = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, client_secret)).fetchone()
                if row:
                    if avatar_url or clean_user != row["username"]:
                        new_avatar = avatar_url if avatar_url else row["avatar_url"]
                        conn.execute("UPDATE nutsty_users SET avatar_url = ?, last_active_at = ? WHERE id = ?", (new_avatar, now, user_id))
                    else:
                        conn.execute("UPDATE nutsty_users SET last_active_at = ? WHERE id = ?", (now, user_id))
                    refreshed = conn.execute("SELECT id, username, discriminator, tag, avatar_url, now_playing FROM nutsty_users WHERE id = ?", (user_id,)).fetchone()
                    return {"success": True, "user": dict(refreshed), "secret_key": client_secret, "restored": True}

            new_user_id = f"usr_{uuid.uuid4().hex[:16]}"
            new_secret = uuid.uuid4().hex + uuid.uuid4().hex
            disc = self.find_available_discriminator(clean_user, preferred_discriminator)
            tag = f"{clean_user}#{disc}"
            conn.execute(
                "INSERT INTO nutsty_users (id, secret_key, username, discriminator, tag, avatar_url, now_playing, created_at, updated_at, last_active_at) VALUES (?, ?, ?, ?, ?, ?, '', ?, ?, ?)",
                (new_user_id, new_secret, clean_user, disc, tag, avatar_url or "", now, now, now)
            )
            return {
                "success": True,
                "user": {
                    "id": new_user_id,
                    "username": clean_user,
                    "discriminator": disc,
                    "tag": tag,
                    "avatar_url": avatar_url or "",
                    "now_playing": ""
                },
                "secret_key": new_secret,
                "restored": False
            }

    def update_profile(self, user_id, secret_key, new_username=None, new_discriminator=None, avatar_url=None):
        now = int(time.time() * 1000)
        with self._get_conn() as conn:
            user = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
            if not user:
                return {"success": False, "error": "Unauthorized"}
            target_username = (new_username.strip()[:32] if new_username is not None and new_username.strip() else user["username"])
            target_disc = user["discriminator"]
            if new_discriminator is not None:
                d_str = str(new_discriminator).strip().zfill(4)
                if not (len(d_str) == 4 and d_str.isdigit() and d_str != "0000"):
                    return {"success": False, "error": "Discriminator must be 4 digits (0001-9999)"}
                target_disc = d_str
            target_tag = f"{target_username}#{target_disc}"
            if target_tag != user["tag"]:
                collision = conn.execute("SELECT id FROM nutsty_users WHERE tag = ? AND id != ?", (target_tag, user_id)).fetchone()
                if collision:
                    sugg = self.find_available_discriminator(target_username)
                    return {
                        "success": False,
                        "error": "Tag already taken",
                        "suggested_discriminator": sugg,
                        "suggested_tag": f"{target_username}#{sugg}" if sugg else None
                    }
            target_avatar = avatar_url if avatar_url is not None else user["avatar_url"]
            conn.execute(
                "UPDATE nutsty_users SET username = ?, discriminator = ?, tag = ?, avatar_url = ?, updated_at = ?, last_active_at = ? WHERE id = ?",
                (target_username, target_disc, target_tag, target_avatar, now, now, user_id)
            )
            updated = conn.execute("SELECT id, username, discriminator, tag, avatar_url, now_playing FROM nutsty_users WHERE id = ?", (user_id,)).fetchone()
            return {"success": True, "user": dict(updated)}

    def search(self, q, caller_user_id=None):
        clean_q = (q or "").strip()
        if not clean_q:
            return {"results": []}
        with self._get_conn() as conn:
            if "#" in clean_q:
                parts = clean_q.split("#", 1)
                u = parts[0].strip()
                d = parts[1].strip()
                if d:
                    rows = conn.execute(
                        "SELECT id, username, discriminator, tag, avatar_url, now_playing, last_active_at FROM nutsty_users WHERE tag LIKE ? LIMIT 20",
                        (f"{u}#{d}%",)
                    ).fetchall()
                else:
                    rows = conn.execute(
                        "SELECT id, username, discriminator, tag, avatar_url, now_playing, last_active_at FROM nutsty_users WHERE username LIKE ? LIMIT 20",
                        (f"%{u}%",)
                    ).fetchall()
            elif clean_q.isdigit() and len(clean_q) <= 4:
                pad = clean_q.zfill(4)
                rows = conn.execute(
                    "SELECT id, username, discriminator, tag, avatar_url, now_playing, last_active_at FROM nutsty_users WHERE discriminator = ? OR username LIKE ? LIMIT 20",
                    (pad, f"%{clean_q}%")
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT id, username, discriminator, tag, avatar_url, now_playing, last_active_at FROM nutsty_users WHERE username LIKE ? LIMIT 20",
                    (f"%{clean_q}%",)
                ).fetchall()

            processed = []
            for r in rows:
                item = dict(r)
                if caller_user_id and item["id"] == caller_user_id:
                    continue
                status = "none"
                initiated_by = ""
                if caller_user_id:
                    u1 = min(caller_user_id, item["id"])
                    u2 = max(caller_user_id, item["id"])
                    f = conn.execute("SELECT status, initiated_by FROM nutsty_friendships WHERE user_id_1 = ? AND user_id_2 = ?", (u1, u2)).fetchone()
                    if f:
                        status = f["status"]
                        initiated_by = f["initiated_by"]
                item["friendship_status"] = status
                item["is_friend"] = (status == "accepted")
                item["has_outgoing_request"] = (status == "pending" and initiated_by == caller_user_id)
                item["has_incoming_request"] = (status == "pending" and initiated_by != caller_user_id)
                processed.append(item)
            return {"results": processed}

    def friend_request(self, from_user_id, secret_key, target_user_id):
        now = int(time.time() * 1000)
        with self._get_conn() as conn:
            caller = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (from_user_id, secret_key)).fetchone()
            if not caller:
                return {"success": False, "error": "Unauthorized"}
            if not target_user_id or target_user_id == from_user_id:
                return {"success": False, "error": "Invalid target user"}
            target = conn.execute("SELECT * FROM nutsty_users WHERE id = ?", (target_user_id,)).fetchone()
            if not target:
                return {"success": False, "error": "Target user not found"}
            u1 = min(from_user_id, target_user_id)
            u2 = max(from_user_id, target_user_id)
            existing = conn.execute("SELECT * FROM nutsty_friendships WHERE user_id_1 = ? AND user_id_2 = ?", (u1, u2)).fetchone()
            if existing:
                if existing["status"] == "accepted":
                    return {"success": True, "message": "Already friends", "status": "accepted"}
                if existing["status"] == "pending":
                    if existing["initiated_by"] == from_user_id:
                        return {"success": True, "message": "Request already sent", "status": "pending"}
                    else:
                        conn.execute("UPDATE nutsty_friendships SET status = 'accepted', updated_at = ? WHERE id = ?", (now, existing["id"]))
                        evt_id = f"evt_{uuid.uuid4().hex[:16]}"
                        conn.execute(
                            "INSERT INTO nutsty_events (id, to_user_id, from_user_id, event_type, payload, consumed, created_at) VALUES (?, ?, ?, 'friend_accepted', ?, 0, ?)",
                            (evt_id, target_user_id, from_user_id, json.dumps({"id": caller["id"], "username": caller["username"], "tag": caller["tag"], "avatar_url": caller["avatar_url"]}), now)
                        )
                        return {"success": True, "message": "Mutual request auto-accepted", "status": "accepted"}
            rel_id = f"rel_{uuid.uuid4().hex[:16]}"
            conn.execute(
                "INSERT OR REPLACE INTO nutsty_friendships (id, user_id_1, user_id_2, status, initiated_by, created_at, updated_at) VALUES (?, ?, ?, 'pending', ?, ?, ?)",
                (rel_id, u1, u2, from_user_id, now, now)
            )
            evt_id = f"evt_{uuid.uuid4().hex[:16]}"
            conn.execute(
                "INSERT INTO nutsty_events (id, to_user_id, from_user_id, event_type, payload, consumed, created_at) VALUES (?, ?, ?, 'friend_request', ?, 0, ?)",
                (evt_id, target_user_id, from_user_id, json.dumps({"id": caller["id"], "username": caller["username"], "tag": caller["tag"], "avatar_url": caller["avatar_url"]}), now)
            )
            return {"success": True, "message": "Friend request sent", "status": "pending"}

    def friend_respond(self, user_id, secret_key, from_user_id, action):
        now = int(time.time() * 1000)
        with self._get_conn() as conn:
            caller = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
            if not caller:
                return {"success": False, "error": "Unauthorized"}
            u1 = min(user_id, from_user_id)
            u2 = max(user_id, from_user_id)
            rel = conn.execute("SELECT * FROM nutsty_friendships WHERE user_id_1 = ? AND user_id_2 = ?", (u1, u2)).fetchone()
            if not rel:
                return {"success": False, "error": "No friendship relation found"}
            if action == "accept":
                conn.execute("UPDATE nutsty_friendships SET status = 'accepted', updated_at = ? WHERE id = ?", (now, rel["id"]))
                evt_id = f"evt_{uuid.uuid4().hex[:16]}"
                conn.execute(
                    "INSERT INTO nutsty_events (id, to_user_id, from_user_id, event_type, payload, consumed, created_at) VALUES (?, ?, ?, 'friend_accepted', ?, 0, ?)",
                    (evt_id, from_user_id, user_id, json.dumps({"id": caller["id"], "username": caller["username"], "tag": caller["tag"], "avatar_url": caller["avatar_url"]}), now)
                )
                return {"success": True, "status": "accepted"}
            else:
                conn.execute("DELETE FROM nutsty_friendships WHERE id = ?", (rel["id"],))
                return {"success": True, "status": "rejected"}

    def friend_remove(self, user_id, secret_key, target_user_id):
        now = int(time.time() * 1000)
        with self._get_conn() as conn:
            caller = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
            if not caller:
                return {"success": False, "error": "Unauthorized"}
            u1 = min(user_id, target_user_id)
            u2 = max(user_id, target_user_id)
            conn.execute("DELETE FROM nutsty_friendships WHERE user_id_1 = ? AND user_id_2 = ?", (u1, u2))
            evt_id = f"evt_{uuid.uuid4().hex[:16]}"
            conn.execute(
                "INSERT INTO nutsty_events (id, to_user_id, from_user_id, event_type, payload, consumed, created_at) VALUES (?, ?, ?, 'friend_removed', ?, 0, ?)",
                (evt_id, target_user_id, user_id, json.dumps({"user_id": user_id}), now)
            )
            return {"success": True, "message": "Friend removed"}

    def get_friends(self, user_id, secret_key):
        with self._get_conn() as conn:
            caller = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
            if not caller:
                return {"success": False, "error": "Unauthorized"}
            friends_rows = conn.execute("""
                SELECT u.id, u.username, u.discriminator, u.tag, u.avatar_url, u.now_playing, u.last_active_at, f.created_at as friendship_created_at
                FROM nutsty_friendships f
                JOIN nutsty_users u ON u.id = CASE WHEN f.user_id_1 = ? THEN f.user_id_2 ELSE f.user_id_1 END
                WHERE (f.user_id_1 = ? OR f.user_id_2 = ?) AND f.status = 'accepted'
                ORDER BY u.last_active_at DESC
            """, (user_id, user_id, user_id)).fetchall()

            reqs_rows = conn.execute("""
                SELECT u.id, u.username, u.discriminator, u.tag, u.avatar_url, f.created_at as requested_at
                FROM nutsty_friendships f
                JOIN nutsty_users u ON u.id = f.initiated_by
                WHERE (f.user_id_1 = ? OR f.user_id_2 = ?) AND f.status = 'pending' AND f.initiated_by != ?
                ORDER BY f.created_at DESC
            """, (user_id, user_id, user_id)).fetchall()

            now_ms = int(time.time() * 1000)
            friends_list = []
            for r in friends_rows:
                d = dict(r)
                is_online = (now_ms - (d.get("last_active_at") or 0)) < 25000
                d["is_online"] = is_online
                if not is_online:
                    d["now_playing"] = ""
                friends_list.append(d)

            return {
                "success": True,
                "friends": friends_list,
                "incoming_requests": [dict(r) for r in reqs_rows]
            }

    def get_events(self, user_id, secret_key):
        with self._get_conn() as conn:
            caller = conn.execute("SELECT * FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
            if not caller:
                return {"success": False, "error": "Unauthorized"}
            rows = conn.execute(
                "SELECT id, to_user_id, from_user_id, event_type, payload, created_at FROM nutsty_events WHERE to_user_id = ? AND consumed = 0 ORDER BY created_at ASC",
                (user_id,)
            ).fetchall()
            if rows:
                conn.execute("UPDATE nutsty_events SET consumed = 1 WHERE to_user_id = ? AND consumed = 0", (user_id,))
            events = []
            for r in rows:
                d = dict(r)
                try:
                    d["payload"] = json.loads(d["payload"])
                except Exception:
                    pass
                events.append(d)
            return {"success": True, "events": events}

    def update_presence(self, user_id, secret_key, now_playing):
        now = int(time.time() * 1000)
        np_str = json.dumps(now_playing) if isinstance(now_playing, (dict, list)) else str(now_playing or "")
        with self._get_conn() as conn:
            caller = conn.execute("SELECT id FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
            if not caller:
                return {"success": False, "error": "Unauthorized"}
            conn.execute("UPDATE nutsty_users SET now_playing = ?, last_active_at = ? WHERE id = ?", (np_str, now, user_id))
            return {"success": True}

    def set_offline(self, user_id, secret_key=None):
        with self._get_conn() as conn:
            if secret_key:
                caller = conn.execute("SELECT id FROM nutsty_users WHERE id = ? AND secret_key = ?", (user_id, secret_key)).fetchone()
                if not caller:
                    return {"success": False, "error": "Unauthorized"}
            conn.execute("UPDATE nutsty_users SET now_playing = '', last_active_at = 0 WHERE id = ?", (user_id,))
            return {"success": True}

def invalidate_cloud_identity_by_user_id(user_id):
    if not user_id:
        return
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    import glob
    for p in glob.glob(os.path.join(d, "nutsty_cloud_identity*.json")):
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
            if data.get("user_id") == user_id:
                os.remove(p)
                sys.stderr.write(f"[CloudRelayClient] Removed invalid/unauthorized cloud identity: {p}\n")
        except Exception:
            pass

class CloudRelayClient:
    """Client bridge: forwards to Cloudflare Worker if configured, else uses CloudRelayEngine."""
    def __init__(self, relay_url=None):
        self.relay_url = relay_url or os.getenv("NUTSTY_CLOUD_RELAY_URL", "").strip()
        if not self.relay_url:
            try:
                xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
                settings_p = os.path.join(xdg, "noctalia", "nutsty_settings.json")
                if os.path.exists(settings_p):
                    with open(settings_p, "r", encoding="utf-8") as sf:
                        sdata = json.load(sf)
                        self.relay_url = (sdata.get("cloud_relay_url") or sdata.get("relay_url") or "").strip()
            except Exception:
                pass
        if not self.relay_url:
            self.relay_url = "https://nutsty-global-relay.nutsty-global-relay.workers.dev"
        self.local_engine = CloudRelayEngine()

    def is_external(self):
        return self.relay_url.startswith("http://") or self.relay_url.startswith("https://")

    def _http_request(self, method, endpoint, data=None, params=None):
        if not self.is_external():
            return None
        import urllib.parse
        url = self.relay_url.rstrip("/") + endpoint
        if params:
            url += "?" + urllib.parse.urlencode(params)

        # Priority 1: Use requests library with auto-retry and SSL tolerance
        try:
            import requests
            headers = {
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 NutstyClient/1.0"
            }
            try:
                r = requests.request(method, url, json=data, params=params, headers=headers, timeout=5.0)
                if r.status_code == 401:
                    uid = (data or {}).get("user_id") or (params or {}).get("user_id") or (data or {}).get("from_user_id")
                    if uid:
                        invalidate_cloud_identity_by_user_id(uid)
                    return {"success": False, "error": "Unauthorized", "unauthorized": True}
                if r.status_code < 500:
                    return r.json()
            except Exception as req_err:
                if "CERTIFICATE_VERIFY_FAILED" in str(req_err) or "SSLError" in type(req_err).__name__:
                    try:
                        import urllib3
                        urllib3.disable_warnings()
                        r = requests.request(method, url, json=data, params=params, headers=headers, timeout=5.0, verify=False)
                        if r.status_code == 401:
                            uid = (data or {}).get("user_id") or (params or {}).get("user_id") or (data or {}).get("from_user_id")
                            if uid:
                                invalidate_cloud_identity_by_user_id(uid)
                            return {"success": False, "error": "Unauthorized", "unauthorized": True}
                        if r.status_code < 500:
                            return r.json()
                    except Exception:
                        pass
        except Exception:
            pass

        # Priority 2: urllib.request with unverified SSL fallback
        req = urllib.request.Request(url, method=method)
        req.add_header("Content-Type", "application/json")
        req.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 NutstyClient/1.0")
        body = json.dumps(data).encode("utf-8") if data is not None else None
        import ssl
        ctx = None
        try:
            import certifi
            ctx = ssl.create_default_context(cafile=certifi.where())
        except Exception:
            try:
                ctx = ssl.create_default_context()
            except Exception:
                ctx = None

        try:
            with urllib.request.urlopen(req, data=body, timeout=5.0, context=ctx) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as he:
            if he.code == 401:
                uid = (data or {}).get("user_id") or (params or {}).get("user_id") or (data or {}).get("from_user_id")
                if uid:
                    invalidate_cloud_identity_by_user_id(uid)
                return {"success": False, "error": "Unauthorized", "unauthorized": True}
            sys.stderr.write(f"[CloudRelayClient request failed]: {he}\n")
            return None
        except Exception as e:
            if "CERTIFICATE_VERIFY_FAILED" in str(e) or "SSL" in type(e).__name__:
                try:
                    unverified_ctx = ssl._create_unverified_context()
                    req_retry = urllib.request.Request(url, method=method)
                    req_retry.add_header("Content-Type", "application/json")
                    req_retry.add_header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) NutstyClient/1.0")
                    with urllib.request.urlopen(req_retry, data=body, timeout=5.0, context=unverified_ctx) as resp:
                        return json.loads(resp.read().decode("utf-8"))
                except urllib.error.HTTPError as he2:
                    if he2.code == 401:
                        uid = (data or {}).get("user_id") or (params or {}).get("user_id") or (data or {}).get("from_user_id")
                        if uid:
                            invalidate_cloud_identity_by_user_id(uid)
                        return {"success": False, "error": "Unauthorized", "unauthorized": True}
                    sys.stderr.write(f"[CloudRelayClient request failed]: {he2}\n")
                    return None
                except Exception as e2:
                    sys.stderr.write(f"[CloudRelayClient request failed]: {e2}\n")
                    return None
            if "401" in str(e):
                uid = (data or {}).get("user_id") or (params or {}).get("user_id") or (data or {}).get("from_user_id")
                if uid:
                    invalidate_cloud_identity_by_user_id(uid)
                return {"success": False, "error": "Unauthorized", "unauthorized": True}
            sys.stderr.write(f"[CloudRelayClient request failed]: {e}\n")
            return None

    def register(self, username, avatar_url="", client_secret=None, user_id=None, preferred_discriminator=None):
        if self.is_external():
            res = self._http_request("POST", "/api/users/register", data={
                "username": username,
                "avatar_url": avatar_url,
                "client_secret": client_secret,
                "user_id": user_id,
                "preferred_discriminator": preferred_discriminator
            })
            if res and res.get("success"):
                return res
        return self.local_engine.register(username, avatar_url, client_secret, user_id, preferred_discriminator)

    def update_profile(self, user_id, secret_key, new_username=None, new_discriminator=None, avatar_url=None):
        if self.is_external():
            res = self._http_request("POST", "/api/users/update_profile", data={
                "user_id": user_id,
                "secret_key": secret_key,
                "new_username": new_username,
                "new_discriminator": new_discriminator,
                "avatar_url": avatar_url
            })
            if res:
                return res
        return self.local_engine.update_profile(user_id, secret_key, new_username, new_discriminator, avatar_url)

    def search(self, q, caller_user_id=None):
        if self.is_external():
            res = self._http_request("GET", "/api/users/search", params={"q": q, "user_id": caller_user_id or ""})
            if res and "results" in res:
                return res
        return self.local_engine.search(q, caller_user_id)

    def friend_request(self, from_user_id, secret_key, target_user_id):
        if self.is_external():
            res = self._http_request("POST", "/api/friends/request", data={
                "from_user_id": from_user_id,
                "secret_key": secret_key,
                "target_user_id": target_user_id
            })
            if res and res.get("success"):
                return res
        return self.local_engine.friend_request(from_user_id, secret_key, target_user_id)

    def friend_respond(self, user_id, secret_key, from_user_id, action):
        if self.is_external():
            res = self._http_request("POST", "/api/friends/respond", data={
                "user_id": user_id,
                "secret_key": secret_key,
                "from_user_id": from_user_id,
                "action": action
            })
            if res and res.get("success"):
                return res
        return self.local_engine.friend_respond(user_id, secret_key, from_user_id, action)

    def friend_remove(self, user_id, secret_key, target_user_id):
        if self.is_external():
            res = self._http_request("POST", "/api/friends/remove", data={
                "user_id": user_id,
                "secret_key": secret_key,
                "target_user_id": target_user_id
            })
            if res and res.get("success"):
                return res
        return self.local_engine.friend_remove(user_id, secret_key, target_user_id)

    def get_friends(self, user_id, secret_key):
        if self.is_external():
            res = self._http_request("GET", "/api/friends", params={"user_id": user_id, "secret_key": secret_key})
            if res and res.get("success"):
                return res
        return self.local_engine.get_friends(user_id, secret_key)

    def get_events(self, user_id, secret_key):
        if self.is_external():
            res = self._http_request("GET", "/api/events", params={"user_id": user_id, "secret_key": secret_key})
            if res and res.get("success"):
                return res
        return self.local_engine.get_events(user_id, secret_key)

    def update_presence(self, user_id, secret_key, now_playing):
        if self.is_external():
            res = self._http_request("POST", "/api/users/presence", data={
                "user_id": user_id,
                "secret_key": secret_key,
                "now_playing": now_playing
            })
            if res and res.get("success"):
                return res
        return self.local_engine.update_presence(user_id, secret_key, now_playing)

    def set_offline(self, user_id, secret_key):
        if self.is_external():
            res = self._http_request("POST", "/api/users/offline", data={
                "user_id": user_id,
                "secret_key": secret_key
            })
            if res and res.get("success"):
                return res
        return self.local_engine.set_offline(user_id, secret_key)

    def publish_note(self, user_id, secret_key, note_text, track=None, now_playing=None):
        if self.is_external():
            res = self._http_request("POST", "/api/notes", data={
                "user_id": user_id,
                "secret_key": secret_key,
                "note_text": note_text,
                "track": track,
                "now_playing": now_playing
            })
            if res and res.get("success"):
                return res
        return None

    def get_notes(self, user_id, secret_key):
        if self.is_external():
            res = self._http_request("GET", "/api/notes", params={
                "user_id": user_id,
                "secret_key": secret_key
            })
            if res and res.get("success"):
                return res
        return None

    def delete_note(self, user_id, secret_key):
        if self.is_external():
            res = self._http_request("POST", "/api/notes/delete", data={
                "user_id": user_id,
                "secret_key": secret_key
            })
            if res and res.get("success"):
                return res
        return None

    def send_note_event(self, user_id, secret_key, to_user_id=None, to_tag=None, event="chat_bubble", data=None):
        if self.is_external():
            res = self._http_request("POST", "/api/notes/events", data={
                "user_id": user_id,
                "secret_key": secret_key,
                "to_user_id": to_user_id,
                "to_tag": to_tag,
                "event": event,
                "data": data
            })
            if res and res.get("success"):
                return res
        return None

GLOBAL_RELAY_CLIENT = CloudRelayClient()

def resolve_profile_suffix(profile=None, user_email=None):
    if profile:
        p = str(profile).strip().lower()
        if p in ("user1",):
            return "_user1"
        elif p in ("default", "main"):
            return ""
        elif p in ("user2", "friend"):
            return f"_{p}"
        elif p.startswith("_"):
            return p
        elif p:
            return f"_{p}"
    if user_email:
        em = str(user_email).strip().lower()
        if "user1" in em:
            return "_user1"
        elif "user2" in em:
            return "_user2"
        elif "friend" in em:
            return "_friend"
        xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
        d = os.path.join(xdg, "noctalia")
        import glob
        for cache_file in glob.glob(os.path.join(d, "nutsty_user_cache*.json")):
            try:
                with open(cache_file, "r", encoding="utf-8") as f:
                    cdata = json.load(f)
                    if (cdata.get("email") or "").strip().lower() == em or (cdata.get("handle") or "").strip().lower() == em:
                        base = os.path.basename(cache_file)
                        s = base.replace("nutsty_user_cache", "").replace(".json", "")
                        return s
            except Exception:
                pass
    env_p = os.getenv("NUTSTY_PROFILE", "").strip().lower()
    if env_p == "user1":
        return "_user1"
    if env_p in ("default", "main"):
        return ""
    return f"_{env_p}" if env_p else ""

def get_cloud_identity_path(profile_suffix=""):
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    os.makedirs(d, exist_ok=True)
    if profile_suffix in ("_user1", "user1"):
        suffix = "_user1"
    elif profile_suffix:
        suffix = profile_suffix
    else:
        suffix = ""
    return os.path.join(d, f"nutsty_cloud_identity{suffix}.json")

def load_cloud_identity(profile_suffix=""):
    p = get_cloud_identity_path(profile_suffix)
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict) and data.get("user_id") and data.get("secret_key"):
                    return data
        except Exception:
            pass
    return None

def save_cloud_identity(data, profile_suffix=""):
    p = get_cloud_identity_path(profile_suffix)
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        os.chmod(p, 0o600)
    except Exception:
        pass

def ensure_cloud_identity(profile_suffix="", fallback_name=None, fallback_avatar=None, force_recreate=False):
    if force_recreate:
        p = get_cloud_identity_path(profile_suffix)
        if os.path.exists(p):
            try:
                os.remove(p)
            except Exception:
                pass
        ident = None
    else:
        ident = load_cloud_identity(profile_suffix)

    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    cache_path = os.path.join(d, f"nutsty_user_cache{profile_suffix}.json")
    user_name = fallback_name
    avatar_url = fallback_avatar or ""

    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                cdata = json.load(f)
                if not user_name:
                    user_name = cdata.get("name") or (cdata.get("email", "").split("@")[0] if "@" in cdata.get("email", "") else "")
                if not avatar_url:
                    avatar_url = cdata.get("avatar", "")
        except Exception:
            pass

    # If identity exists, verify if username needs synchronization with Google account
    if ident and ident.get("user_id") and ident.get("secret_key"):
        # Auto-update if user logged in with a real name (e.g. "Hieu Tran") and identity still has a placeholder or old name
        if user_name and user_name not in ("Nutsty User", "Shiraori", "Khách", "Guest") and ident.get("username") != user_name:
            try:
                up_res = GLOBAL_RELAY_CLIENT.update_profile(
                    user_id=ident["user_id"],
                    secret_key=ident["secret_key"],
                    new_username=user_name,
                    avatar_url=avatar_url or ident.get("avatar_url")
                )
                if up_res and up_res.get("success") and up_res.get("user"):
                    u = up_res["user"]
                    ident["username"] = u["username"]
                    ident["tag"] = u["tag"]
                    ident["discriminator"] = u["discriminator"]
                    if u.get("avatar_url"):
                        ident["avatar_url"] = u["avatar_url"]
                    save_cloud_identity(ident, profile_suffix)
                elif up_res and up_res.get("unauthorized"):
                    # Credentials rejected by Cloudflare D1 (401)! Purge invalid identity and re-register afresh!
                    sys.stderr.write(f"[CloudRelay] Cloud identity unauthorized for {ident.get('user_id')}. Re-registering as {user_name}...\n")
                    return ensure_cloud_identity(profile_suffix, fallback_name=user_name, fallback_avatar=avatar_url, force_recreate=True)
                else:
                    ident["username"] = user_name
                    ident["tag"] = f"{user_name}#{ident.get('discriminator', '0001')}"
                    if avatar_url:
                        ident["avatar_url"] = avatar_url
                    save_cloud_identity(ident, profile_suffix)
            except Exception:
                ident["username"] = user_name
                ident["tag"] = f"{user_name}#{ident.get('discriminator', '0001')}"
                if avatar_url:
                    ident["avatar_url"] = avatar_url
                save_cloud_identity(ident, profile_suffix)
        return ident

    if not user_name:
        if profile_suffix == "_user2":
            user_name = "Hiếu Trần"
        else:
            user_name = "Nutsty User"

    reg_res = GLOBAL_RELAY_CLIENT.register(
        username=user_name,
        avatar_url=avatar_url
    )
    if reg_res and reg_res.get("success") and reg_res.get("user"):
        u = reg_res["user"]
        ident = {
            "user_id": u["id"],
            "secret_key": reg_res["secret_key"],
            "username": u["username"],
            "discriminator": u["discriminator"],
            "tag": u["tag"],
            "avatar_url": u.get("avatar_url", "")
        }
        save_cloud_identity(ident, profile_suffix)
        return ident

    return {
        "user_id": f"usr_local{profile_suffix}",
        "secret_key": "local_secret",
        "username": user_name,
        "discriminator": "0001",
        "tag": f"{user_name}#0001",
        "avatar_url": avatar_url
    }

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

def get_friends_vault_path():
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "nutsty_friends_vault.json")

def load_friends_vault():
    p = get_friends_vault_path()
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
        except Exception:
            pass
    return {}

def save_friends_vault(data):
    p = get_friends_vault_path()
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

def get_friend_requests_vault_path():
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "nutsty_friend_requests_vault.json")

def load_friend_requests_vault():
    p = get_friend_requests_vault_path()
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for r in data:
                        if isinstance(r, dict):
                            if "to_email" in r:
                                r["to_email"] = resolve_canonical_user_email(r["to_email"])
                            if "from_email" in r:
                                r["from_email"] = resolve_canonical_user_email(r["from_email"])
                    return data
        except Exception:
            pass
    return []

def save_friend_requests_vault(data):
    p = get_friend_requests_vault_path()
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

def normalize_user_email(email):
    return (email or "").strip().lower()

def resolve_canonical_user_email(ident):
    if not ident:
        return ""
    s = str(ident).strip().lower()
    try:
        vault = load_profiles_vault()
        for em_key, prof in vault.items():
            em = prof.get("email", em_key).lower()
            tag = (prof.get("nutsty_tag") or "").lower()
            pin = str(prof.get("pin_code") or "")
            if s == em or (tag and s == tag) or (pin and s == pin):
                return em
    except Exception:
        pass
    try:
        known = get_all_known_users()
        for k, u in known.items():
            u_em = (u.get("email") or k).lower()
            u_tag = (u.get("nutsty_tag") or "").lower()
            u_pin = str(u.get("pin_code") or "")
            u_handle = (u.get("handle") or "").lower()
            if s == k.lower() or s == u_em or (u_tag and s == u_tag) or (u_pin and s == u_pin) or (u_handle and s == u_handle):
                return u_em
    except Exception:
        pass
    return normalize_user_email(s)

def get_user_all_identifiers(ident):
    if not ident:
        return []
    s = str(ident).strip().lower()
    canonical = resolve_canonical_user_email(s)
    ids = set()
    if s:
        ids.add(s)
    if canonical:
        ids.add(canonical)
    try:
        vault = load_profiles_vault()
        for em_key, prof in vault.items():
            if prof.get("email", em_key).lower() == canonical:
                ids.add(em_key.lower())
                if prof.get("nutsty_tag"):
                    ids.add(prof["nutsty_tag"].lower())
                if prof.get("pin_code"):
                    ids.add(str(prof["pin_code"]))
    except Exception:
        pass
    try:
        known = get_all_known_users()
        for k, u in known.items():
            if (u.get("email") or k).lower() == canonical:
                ids.add(k.lower())
                if u.get("handle"):
                    ids.add(u["handle"].lower())
                if u.get("nutsty_tag"):
                    ids.add(u["nutsty_tag"].lower())
                if u.get("pin_code"):
                    ids.add(str(u["pin_code"]))
    except Exception:
        pass
    return list(ids)

def get_profiles_vault_path():
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "nutsty_profiles_vault.json")

def load_profiles_vault():
    p = get_profiles_vault_path()
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    return data
        except Exception:
            pass
    return {}

def save_profiles_vault(data):
    p = get_profiles_vault_path()
    try:
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception:
        pass

def ensure_user_profile(email):
    norm = normalize_user_email(email)
    vault = load_profiles_vault()
    known = get_all_known_users()
    u_info = known.get(norm, {})

    if norm not in vault:
        import random
        pin = str(random.randint(100000, 999999))
        base_name = u_info.get("name") or (norm.split("@")[0] if "@" in norm else norm)
        tag = f"{base_name}#{random.randint(1000, 9999)}"
        vault[norm] = {
            "email": norm,
            "name": u_info.get("name") or base_name,
            "avatar": u_info.get("avatar") or "",
            "pin_code": pin,
            "nutsty_tag": tag
        }
        save_profiles_vault(vault)

    prof = vault[norm]
    if not prof.get("pin_code"):
        import random
        prof["pin_code"] = str(random.randint(100000, 999999))
        save_profiles_vault(vault)
    if not prof.get("nutsty_tag"):
        import random
        base = prof.get("name") or norm.split("@")[0]
        prof["nutsty_tag"] = f"{base}#{random.randint(1000, 9999)}"
        save_profiles_vault(vault)
    return prof

def regenerate_user_pin(email):
    import random
    norm = normalize_user_email(email)
    vault = load_profiles_vault()
    ensure_user_profile(norm)
    vault = load_profiles_vault()
    new_pin = str(random.randint(100000, 999999))
    if norm in vault:
        vault[norm]["pin_code"] = new_pin
        save_profiles_vault(vault)
    return new_pin

def get_all_known_users():
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    users = {}
    import glob
    for p in glob.glob(os.path.join(d, "nutsty_user_cache*.json")):
        try:
            with open(p, "r", encoding="utf-8") as f:
                u = json.load(f)
                email = (u.get("email") or "").strip().lower()
                name = u.get("name") or email.split("@")[0]
                avatar = u.get("avatar", "")
                handle = (u.get("handle") or "").strip().lower()
                if email:
                    users[email] = {
                        "email": email,
                        "name": name,
                        "avatar": avatar,
                        "handle": handle
                    }
                if handle:
                    users[handle] = {
                        "email": email,
                        "name": name,
                        "avatar": avatar,
                        "handle": handle
                    }
        except Exception:
            pass

    vault = load_notes_vault()
    for k, item in vault.items():
        iem = (item.get("user_email") or "").strip().lower()
        if iem:
            existing = users.get(iem, {})
            users[iem] = {
                "email": item.get("user_email", ""),
                "name": item.get("user_name") or existing.get("name") or iem.split("@")[0],
                "avatar": item.get("avatar_url") or existing.get("avatar", ""),
                "handle": existing.get("handle", ""),
                "pin_code": existing.get("pin_code", ""),
                "nutsty_tag": existing.get("nutsty_tag", "")
            }

    prof_vault = load_profiles_vault()
    for pem, pinfo in prof_vault.items():
        if pem in users:
            users[pem].update(pinfo)
        else:
            users[pem] = pinfo
    return users

def sync_local_friends_files(user_email, friends_list):
    xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    d = os.path.join(xdg, "noctalia")
    import glob
    u_norm = user_email.strip().lower()
    for p in glob.glob(os.path.join(d, "nutsty_user_cache*.json")):
        try:
            with open(p, "r", encoding="utf-8") as f:
                uc = json.load(f)
                if (uc.get("email") or "").strip().lower() == u_norm:
                    base = os.path.basename(p)
                    suffix = base.replace("nutsty_user_cache", "").replace(".json", "")
                    target_file = os.path.join(d, f"nutsty_friends{suffix}.json")
                    with open(target_file, "w", encoding="utf-8") as tf:
                        json.dump(friends_list, tf, indent=2, ensure_ascii=False)
        except Exception:
            pass

PORT = 17890
HOST = "127.0.0.1"

class AuthWebhookHandler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def handle_one_request(self):
        try:
            super().handle_one_request()
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError, OSError):
            self.close_connection = True

    def _send_json(self, data, status_code=200):
        try:
            payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(status_code)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, OSError):
            pass
        except Exception:
            pass

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
            self._send_json(st, 200)
        elif path == "/api/mood":
            params = query.get("params", [""])[0]
            title = query.get("title", [""])[0]
            try:
                data = ytmusic_helper.get_mood_feed(params, title)
            except Exception as e:
                data = {"sections": [], "quick_picks": [], "featured_playlists": []}
            self._send_json(data, 200)
        elif path == "/api/home":
            try:
                data = ytmusic_helper.get_personalized_home()
            except Exception as e:
                data = {"moods": [], "sections": [], "quick_picks": [], "featured_playlists": []}
            self._send_json(data, 200)
        elif path == "/api/suggestions":
            q = query.get("q", [""])[0]
            data = ytmusic_helper.get_search_suggestions(q)
            self._send_json(data, 200)
        elif path == "/api/filter_search":
            q = query.get("q", [""])[0]
            flt = query.get("filter", ["songs"])[0]
            data = ytmusic_helper.filter_search(q, flt)
            self._send_json(data, 200)
        elif path == "/api/playlist":
            pl_id = query.get("id", [""])[0]
            data = ytmusic_helper.get_playlist_tracks(pl_id)
            self._send_json(data, 200)
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
            profile = query.get("profile", [""])[0].strip()
            user_email = query.get("user_email", [""])[0].strip()
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix)

            if GLOBAL_RELAY_CLIENT.is_external():
                res = GLOBAL_RELAY_CLIENT.get_notes(caller_ident["user_id"], caller_ident["secret_key"])
                if res and res.get("success"):
                    self._send_json(res, 200)
                    return

            relay_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
            cloud_friends = relay_res.get("friends", [])

            vault = load_notes_vault()
            now = time.time()
            valid_notes = []
            my_note = None
            cleaned_vault = {}

            caller_tag = (caller_ident.get("tag") or "").strip().lower()
            caller_uid = (caller_ident.get("user_id") or "").strip().lower()
            caller_uname = (caller_ident.get("username") or "").strip().lower()
            caller_email = user_email.strip().lower() if user_email else ""

            for k, item in vault.items():
                if item.get("_expires_ts", 0) > now:
                    cleaned_vault[k] = item
                    iem = item.get("user_email", "").strip().lower()
                    itag = (item.get("tag") or "").strip().lower()
                    iuid = (item.get("user_id") or "").strip().lower()
                    iname = (item.get("user_name") or "").strip().lower()

                    is_me = False
                    if caller_tag and (itag == caller_tag or iem == caller_tag):
                        is_me = True
                    elif caller_uid and (iuid == caller_uid or iem == caller_uid):
                        is_me = True
                    elif caller_email and (iem == caller_email or itag == caller_email):
                        is_me = True
                    elif caller_uname and (iname == caller_uname or iem == caller_uname):
                        is_me = True

                    if is_me:
                        if my_note is None or item.get("last_active_ts", 0) >= my_note.get("last_active_ts", 0):
                            my_note = item.copy()

            if len(cleaned_vault) != len(vault):
                save_notes_vault(cleaned_vault)

            # Build list of friend notes from Cloud Relay friends
            for f in cloud_friends:
                f_tag = (f.get("tag") or "").strip().lower()
                f_id = (f.get("id") or "").strip().lower()
                f_name = (f.get("username") or "").strip().lower()

                matched_note = (
                    cleaned_vault.get(f"note:{f_tag}") or
                    cleaned_vault.get(f"note:{f_id}") or
                    cleaned_vault.get(f"note:{f_name}")
                )
                if not matched_note:
                    for k, item in cleaned_vault.items():
                        iem = item.get("user_email", "").strip().lower()
                        itag = (item.get("tag") or "").strip().lower()
                        iuid = (item.get("user_id") or "").strip().lower()
                        iname = (item.get("user_name") or "").strip().lower()
                        if (f_tag and (itag == f_tag or iem == f_tag)) or \
                           (f_id and (iuid == f_id or iem == f_id)) or \
                           (f_name and (iname == f_name or iem == f_name)):
                            matched_note = item.copy()
                            break

                ONLINE_TIMEOUT_SEC = 25.0
                if matched_note:
                    fn = matched_note.copy()
                    fn["avatar_url"] = f.get("avatar_url") or fn.get("avatar_url", "")
                    fn["user_name"] = f.get("username") or fn.get("user_name", "")
                    fn["tag"] = f.get("tag") or fn.get("tag", "")
                    
                    last_active = fn.get("last_active_ts") or 0
                    if not last_active and f.get("last_active_at"):
                        last_active = f.get("last_active_at") / 1000.0 if f.get("last_active_at") > 1e11 else f.get("last_active_at")
                    is_online = (now - last_active) < ONLINE_TIMEOUT_SEC if last_active else False
                    fn["is_online"] = is_online
                    fn["last_active_ts"] = last_active
                    fn["now_playing"] = (f.get("now_playing") or fn.get("now_playing", "")) if is_online else ""
                    valid_notes.append(fn)
                else:
                    last_active = f.get("last_active_at", 0)
                    if last_active > 1e11:
                        last_active = last_active / 1000.0
                    is_online = (now - last_active) < ONLINE_TIMEOUT_SEC if last_active else False
                    valid_notes.append({
                        "user_id": f.get("id", ""),
                        "user_email": f.get("tag", ""),
                        "user_name": f.get("username", ""),
                        "avatar_url": f.get("avatar_url", ""),
                        "tag": f.get("tag", ""),
                        "note_text": "",
                        "track": None,
                        "created_at": 0,
                        "is_friend": True,
                        "is_online": is_online,
                        "last_active_ts": last_active,
                        "now_playing": f.get("now_playing", "") if is_online else ""
                    })

            data = {"count": len(valid_notes), "notes": valid_notes, "my_note": my_note}
            self._send_json(data, 200)
        elif path == "/api/friends":
            profile = query.get("profile", [""])[0].strip()
            user_email = query.get("user_email", [""])[0].strip()
            preferred_name = query.get("name", [""])[0].strip()
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix, fallback_name=preferred_name or None)

            relay_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
            if relay_res and relay_res.get("unauthorized"):
                caller_ident = ensure_cloud_identity(suffix, fallback_name=preferred_name or None, force_recreate=True)
                relay_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
            friends_data = []
            notes_vault = load_notes_vault()

            for f in (relay_res or {}).get("friends", []):
                f_tag = f["tag"]
                note_item = notes_vault.get(f"note:{f_tag}") or notes_vault.get(f"note:{f['id']}") or notes_vault.get(f"note:{f['username'].lower()}")
                friends_data.append({
                    "id": f["id"],
                    "user_id": f["id"],
                    "email": f["tag"],
                    "name": f["username"],
                    "avatar": f.get("avatar_url", ""),
                    "nutsty_tag": f["tag"],
                    "tag": f["tag"],
                    "discriminator": f["discriminator"],
                    "now_playing": f.get("now_playing", ""),
                    "note": note_item
                })

            incoming = []
            for r in (relay_res or {}).get("incoming_requests", []):
                incoming.append({
                    "id": f"req_{r['id']}",
                    "from_id": r["id"],
                    "from_email": r["tag"],
                    "from_name": r["username"],
                    "from_avatar": r.get("avatar_url", ""),
                    "from_tag": r["tag"],
                    "created_at": r.get("requested_at", 0),
                    "status": "pending"
                })

            data = {
                "friends": friends_data,
                "incoming_requests": incoming,
                "outgoing_requests": [],
                "unread_count": len(incoming)
            }
            self._send_json(data, 200)
        elif path == "/api/users/me":
            profile = query.get("profile", [""])[0].strip()
            user_email = query.get("user_email", [""])[0].strip()
            preferred_name = query.get("name", [""])[0].strip()
            suffix = resolve_profile_suffix(profile, user_email)
            ident = ensure_cloud_identity(suffix, fallback_name=preferred_name or None)
            display_name = preferred_name if (preferred_name and preferred_name not in ("Nutsty User", "Shiraori", "Khách", "Guest")) else ident["username"]
            display_tag = f"{display_name}#{ident.get('discriminator', '0001')}" if display_name != ident["username"] else ident["tag"]
            self._send_json({
                "success": True,
                "profile": {
                    "id": ident["user_id"],
                    "user_id": ident["user_id"],
                    "name": display_name,
                    "username": display_name,
                    "discriminator": ident["discriminator"],
                    "pin_code": ident["discriminator"],
                    "tag": display_tag,
                    "nutsty_tag": display_tag,
                    "avatar": ident.get("avatar_url", ""),
                    "avatar_url": ident.get("avatar_url", "")
                }
            }, 200)
        elif path == "/api/users/search":
            raw_q = query.get("q", [""])[0].strip()
            profile = query.get("profile", [""])[0].strip()
            user_email = query.get("user_email", [""])[0].strip()
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix)

            res = GLOBAL_RELAY_CLIENT.search(raw_q, caller_user_id=caller_ident.get("user_id"))
            results = []
            for r in res.get("results", []):
                results.append({
                    "id": r["id"],
                    "user_id": r["id"],
                    "email": r["tag"],
                    "name": r["username"],
                    "nutsty_tag": r["tag"],
                    "tag": r["tag"],
                    "pin_code": r["discriminator"],
                    "discriminator": r["discriminator"],
                    "avatar": r.get("avatar_url", ""),
                    "avatar_url": r.get("avatar_url", ""),
                    "now_playing": r.get("now_playing", ""),
                    "is_self": False,
                    "is_friend": r.get("is_friend", False),
                    "has_outgoing_request": r.get("has_outgoing_request", False),
                    "has_incoming_request": r.get("has_incoming_request", False)
                })
            self._send_json({"results": results}, 200)
        elif path == "/api/notes/events":
            profile = query.get("profile", [""])[0].strip()
            user_email = query.get("user_email", [""])[0].strip()
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix)

            relay_evts = GLOBAL_RELAY_CLIENT.get_events(caller_ident["user_id"], caller_ident["secret_key"])
            events = []
            for revt in relay_evts.get("events", []):
                events.append({
                    "id": revt["id"],
                    "event": revt["event_type"],
                    "from_email": revt.get("payload", {}).get("tag", revt["from_user_id"]),
                    "from_name": revt.get("payload", {}).get("username", "User"),
                    "from_avatar": revt.get("payload", {}).get("avatar_url", ""),
                    "timestamp": revt.get("created_at", time.time() * 1000) / 1000.0,
                    "data": revt.get("payload", {})
                })

            user_aliases = get_user_all_identifiers(user_email)
            local_evts = load_events_vault()
            my_local = [e for e in local_evts if e.get("to_email", "").strip().lower() in user_aliases]
            rem_local = [e for e in local_evts if e.get("to_email", "").strip().lower() not in user_aliases]
            if my_local:
                save_events_vault(rem_local)
                events.extend(my_local)

            self._send_json({"count": len(events), "events": events}, 200)
        else:
            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/users/update_profile":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            profile = req_data.get("profile", "")
            user_email = req_data.get("user_email", "")
            suffix = resolve_profile_suffix(profile, user_email)
            ident = ensure_cloud_identity(suffix)

            new_username = req_data.get("new_username")
            new_discriminator = req_data.get("new_discriminator")
            avatar_url = req_data.get("avatar_url")

            res = GLOBAL_RELAY_CLIENT.update_profile(
                user_id=ident["user_id"],
                secret_key=ident["secret_key"],
                new_username=new_username,
                new_discriminator=new_discriminator,
                avatar_url=avatar_url
            )

            if res.get("success") and res.get("user"):
                u = res["user"]
                ident["username"] = u["username"]
                ident["discriminator"] = u["discriminator"]
                ident["tag"] = u["tag"]
                if "avatar_url" in u:
                    ident["avatar_url"] = u["avatar_url"]
                save_cloud_identity(ident, suffix)

                xdg = os.getenv("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
                d = os.path.join(xdg, "noctalia")
                uc_path = os.path.join(d, f"nutsty_user_cache{suffix}.json")
                if os.path.exists(uc_path):
                    try:
                        with open(uc_path, "r", encoding="utf-8") as f:
                            uc_data = json.load(f)
                        uc_data["name"] = u["username"]
                        with open(uc_path, "w", encoding="utf-8") as f:
                            json.dump(uc_data, f, indent=2, ensure_ascii=False)
                    except Exception:
                        pass

                self._send_json({"success": True, "user": u, "profile": ident}, 200)
            else:
                self._send_json(res, 409 if res.get("suggested_discriminator") else 400)
        elif self.path == "/api/users/regenerate_pin":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            profile = req_data.get("profile", "")
            user_email = req_data.get("user_email", "")
            suffix = resolve_profile_suffix(profile, user_email)
            ident = ensure_cloud_identity(suffix)

            new_disc = GLOBAL_RELAY_CLIENT.local_engine.find_available_discriminator(ident["username"])
            res = GLOBAL_RELAY_CLIENT.update_profile(
                user_id=ident["user_id"],
                secret_key=ident["secret_key"],
                new_username=ident["username"],
                new_discriminator=new_disc
            )
            if res.get("success") and res.get("user"):
                u = res["user"]
                ident["discriminator"] = u["discriminator"]
                ident["tag"] = u["tag"]
                save_cloud_identity(ident, suffix)
                self._send_json({"success": True, "pin_code": u["discriminator"], "nutsty_tag": u["tag"], "tag": u["tag"]}, 200)
            else:
                self._send_json({"success": False, "error": "Failed to generate new tag"}, 500)
        elif self.path == "/api/users/offline":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            profile = req_data.get("profile", "")
            user_email = req_data.get("user_email", "")
            suffix = resolve_profile_suffix(profile, user_email)
            ident = ensure_cloud_identity(suffix)

            email = user_email.lower() if user_email else ident.get("tag", "").lower()
            try:
                GLOBAL_RELAY_CLIENT.set_offline(ident["user_id"], ident["secret_key"])
            except Exception as e:
                print(f"[auth_server offline error] {e}")

            vault = load_notes_vault()
            key = f"note:{email}" if email else f"note:{ident['user_id']}"
            if key in vault:
                vault[key]["last_active_ts"] = 0
                vault[key]["now_playing"] = ""
                save_notes_vault(vault)

            self._send_json({"success": True, "message": "User is offline"}, 200)
        elif self.path in ("/api/auth/cookies", "/api/auth/sync"):
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

            profile = req_data.get("profile", "").strip().lower()
            email = req_data.get("user_email", "").strip().lower()
            note_text = req_data.get("note_text", "").strip()
            track = req_data.get("track")
            if isinstance(track, dict) and not track.get("title") and not track.get("name") and not track.get("id"):
                track = None

            # Resolve caller cloud identity to bind cloud tag & id properly
            suffix = resolve_profile_suffix(profile, email)
            caller_ident = ensure_cloud_identity(suffix)

            cloud_tag = caller_ident.get("tag") or req_data.get("user_tag") or email
            user_name = caller_ident.get("username") or req_data.get("user_name", "Anonymous")
            avatar_url = caller_ident.get("avatar_url") or req_data.get("avatar_url", "")
            user_id = caller_ident.get("user_id", "")

            if not email and cloud_tag:
                email = cloud_tag.lower()

            if not email or (not note_text and not track):
                res = {"success": False, "error": "Missing required fields (either text or track required)"}
                status_code = 400
            elif GLOBAL_RELAY_CLIENT.is_external():
                cloud_res = GLOBAL_RELAY_CLIENT.publish_note(
                    caller_ident["user_id"],
                    caller_ident["secret_key"],
                    note_text,
                    track,
                    req_data.get("now_playing")
                )
                if cloud_res and cloud_res.get("success"):
                    self._send_json(cloud_res, 200)
                    return
                else:
                    self._send_json(cloud_res or {"success": False, "error": "Cloud relay failed"}, 400)
                    return
            else:
                ttl = 86400
                now = time.time()
                record = {
                    "user_email": email,
                    "tag": cloud_tag,
                    "user_id": user_id,
                    "user_name": user_name,
                    "avatar_url": avatar_url,
                    "note_text": note_text[:80],
                    "track": track,
                    "now_playing": req_data.get("now_playing"),
                    "created_at": datetime.fromtimestamp(now).isoformat(),
                    "expires_at": datetime.fromtimestamp(now + ttl).isoformat(),
                    "_expires_ts": now + ttl,
                    "last_active_ts": now
                }
                vault = load_notes_vault()
                # Save under email
                if email:
                    vault[f"note:{email}"] = record
                # Save under cloud tag
                if cloud_tag:
                    vault[f"note:{cloud_tag.lower()}"] = record
                # Save under cloud user_id
                if user_id:
                    vault[f"note:{user_id}"] = record
                # Save under cloud username
                if user_name:
                    vault[f"note:{user_name.lower()}"] = record

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
            profile = req_data.get("profile", "").strip().lower()
            email = req_data.get("user_email", "").strip().lower()
            suffix = resolve_profile_suffix(profile, email)
            caller_ident = ensure_cloud_identity(suffix)

            if GLOBAL_RELAY_CLIENT.is_external():
                cloud_res = GLOBAL_RELAY_CLIENT.delete_note(caller_ident["user_id"], caller_ident["secret_key"])
                if cloud_res and cloud_res.get("success"):
                    self._send_json(cloud_res, 200)
                    return
                else:
                    self._send_json(cloud_res or {"success": False, "error": "Cloud relay failed"}, 400)
                    return

            vault = load_notes_vault()
            if email:
                vault.pop(f"note:{email}", None)
            if caller_ident.get("tag"):
                vault.pop(f"note:{caller_ident['tag'].lower()}", None)
            if caller_ident.get("user_id"):
                vault.pop(f"note:{caller_ident['user_id']}", None)
            if caller_ident.get("username"):
                vault.pop(f"note:{caller_ident['username'].lower()}", None)
            save_notes_vault(vault)
            self._send_json({"success": True}, 200)
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
            from_avatar = req_data.get("from_avatar", "").strip()
            to_email = req_data.get("to_email", "").strip()
            profile = req_data.get("profile", "").strip().lower()
            suffix = resolve_profile_suffix(profile, from_email)
            caller_ident = ensure_cloud_identity(suffix)

            if not to_email:
                self._send_json({"success": False, "error": "Missing to_email"}, 400)
                return

            if GLOBAL_RELAY_CLIENT.is_external():
                cloud_res = GLOBAL_RELAY_CLIENT.send_note_event(
                    caller_ident["user_id"],
                    caller_ident["secret_key"],
                    to_tag=to_email if "#" in to_email else None,
                    to_user_id=to_email if "#" not in to_email else None,
                    event=ev_type,
                    data=req_data.get("data")
                )
                if cloud_res and cloud_res.get("success"):
                    self._send_json(cloud_res, 200)
                    return
                else:
                    self._send_json(cloud_res or {"success": False, "error": "Cloud relay failed"}, 400)
                    return

            events = load_events_vault()
            ev = {
                "id": f"ev_{int(time.time()*1000)}",
                "event": ev_type,
                "from_email": from_email,
                "from_name": from_name,
                "from_avatar": from_avatar,
                "to_email": to_email,
                "data": req_data.get("data"),
                "timestamp": time.time(),
                "created_at": datetime.now().isoformat()
            }
            events.append(ev)
            save_events_vault(events)
            self._send_json({"success": True, "event": ev}, 200)
        elif self.path == "/api/now_playing":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}

            profile = req_data.get("profile", "")
            user_email = req_data.get("user_email", "").strip()
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix)

            email = user_email.lower() if user_email else caller_ident.get("tag", "").lower()
            now_playing = req_data.get("now_playing")
            track_meta = req_data.get("track")
            np_payload = None

            if isinstance(now_playing, dict):
                np_payload = now_playing
            elif isinstance(track_meta, dict):
                np_payload = {
                    "title": track_meta.get("title", ""),
                    "artist": track_meta.get("artist", ""),
                    "cover": track_meta.get("cover", track_meta.get("image", "")),
                    "videoId": track_meta.get("videoId", track_meta.get("id", "")),
                    "accent_color": track_meta.get("accent_color", "")
                }
            elif isinstance(now_playing, str) and now_playing.strip().startswith("{"):
                try:
                    np_payload = json.loads(now_playing)
                except Exception:
                    pass

            if np_payload is None and req_data.get("title"):
                np_payload = {
                    "title": req_data.get("title", ""),
                    "artist": req_data.get("artist", ""),
                    "cover": req_data.get("image", req_data.get("cover", "")),
                    "videoId": req_data.get("videoId", req_data.get("id", "")),
                    "accent_color": req_data.get("accent_color", "")
                }

            presence_val = np_payload if np_payload else (now_playing if now_playing is not None else "")
            np_text = ""
            if isinstance(np_payload, dict):
                np_text = f"{np_payload.get('title', '')} - {np_payload.get('artist', '')}".strip(" -")
            elif isinstance(now_playing, str):
                np_text = now_playing

            try:
                GLOBAL_RELAY_CLIENT.update_presence(caller_ident["user_id"], caller_ident["secret_key"], presence_val)
            except Exception as pe:
                print(f"[auth_server presence error] {pe}")

            vault = load_notes_vault()
            key = f"note:{email}" if email else f"note:{caller_ident['user_id']}"
            now = time.time()
            store_np = np_payload if np_payload else np_text
            if key in vault:
                vault[key]["now_playing"] = store_np
                vault[key]["last_active_ts"] = now
                if np_payload and not vault[key].get("track"):
                    vault[key]["track"] = np_payload
                record = vault[key]
            else:
                ttl = 86400
                record = {
                    "user_email": email or caller_ident.get("tag", ""),
                    "user_name": req_data.get("user_name") or caller_ident.get("username", "User"),
                    "avatar_url": req_data.get("avatar_url") or caller_ident.get("avatar_url", ""),
                    "note_text": "",
                    "track": np_payload,
                    "now_playing": store_np,
                    "created_at": datetime.fromtimestamp(now).isoformat(),
                    "expires_at": datetime.fromtimestamp(now + ttl).isoformat(),
                    "_expires_ts": now + ttl,
                    "last_active_ts": now
                }
                vault[key] = record
            save_notes_vault(vault)
            self._send_json({"success": True, "note": record}, 200)
        elif self.path == "/api/friends/request":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            profile = req_data.get("profile", "")
            from_email = req_data.get("from_email", "")
            suffix = resolve_profile_suffix(profile, from_email)
            caller_ident = ensure_cloud_identity(suffix)

            target_user_id = (req_data.get("target_user_id") or req_data.get("target_id") or "").strip()
            to_email = (req_data.get("to_email") or req_data.get("target_email") or "").strip()

            if not target_user_id and to_email:
                search_res = GLOBAL_RELAY_CLIENT.search(to_email, caller_user_id=caller_ident["user_id"])
                for cand in search_res.get("results", []):
                    if cand["tag"].lower() == to_email.lower() or cand["id"] == to_email or cand["username"].lower() == to_email.lower():
                        target_user_id = cand["id"]
                        break
                if not target_user_id and search_res.get("results"):
                    target_user_id = search_res["results"][0]["id"]

            if not target_user_id:
                self._send_json({"success": False, "error": "Target user not found"}, 404)
                return

            res = GLOBAL_RELAY_CLIENT.friend_request(caller_ident["user_id"], caller_ident["secret_key"], target_user_id)
            self._send_json(res, 200 if res.get("success") else 400)
        elif self.path == "/api/friends/respond":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            profile = req_data.get("profile", "")
            user_email = req_data.get("user_email", "")
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix)

            from_user_id = (req_data.get("from_user_id") or req_data.get("from_id") or req_data.get("target_id") or "").strip()
            from_email = req_data.get("from_email", "").strip()
            request_id = req_data.get("request_id", "").strip()
            action = req_data.get("action", "").strip().lower()

            if not from_user_id:
                if request_id:
                    from_user_id = request_id.replace("req_", "")
                elif from_email:
                    search_res = GLOBAL_RELAY_CLIENT.search(from_email, caller_user_id=caller_ident["user_id"])
                    if search_res.get("results"):
                        from_user_id = search_res["results"][0]["id"]

            if not from_user_id:
                self._send_json({"success": False, "error": "Requester not found"}, 404)
                return

            res = GLOBAL_RELAY_CLIENT.friend_respond(caller_ident["user_id"], caller_ident["secret_key"], from_user_id, action)
            self._send_json(res, 200 if res.get("success") else 400)
        elif self.path == "/api/friends/remove":
            content_len = int(self.headers.get("Content-Length", 0))
            post_body = self.rfile.read(content_len).decode("utf-8") if content_len > 0 else ""
            try:
                req_data = json.loads(post_body)
            except Exception:
                req_data = {}
            profile = req_data.get("profile", "")
            user_email = req_data.get("user_email", "")
            suffix = resolve_profile_suffix(profile, user_email)
            caller_ident = ensure_cloud_identity(suffix)

            target_user_id = (req_data.get("target_user_id") or req_data.get("target_id") or "").strip()
            target_email = req_data.get("target_email", "").strip()
            if not target_user_id and target_email:
                search_res = GLOBAL_RELAY_CLIENT.search(target_email, caller_user_id=caller_ident["user_id"])
                for cand in search_res.get("results", []):
                    if cand["tag"].lower() == target_email.lower() or cand["id"] == target_email:
                        target_user_id = cand["id"]
                        break

            if not target_user_id:
                self._send_json({"success": False, "error": "Target user not found"}, 404)
                return

            res = GLOBAL_RELAY_CLIENT.friend_remove(caller_ident["user_id"], caller_ident["secret_key"], target_user_id)
            self._send_json(res, 200 if res.get("success") else 400)
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
        httpd = ThreadingHTTPServer(server_address, AuthWebhookHandler)
        print(f"Nutsty Auth Server listening on http://{HOST}:{PORT}")
        httpd.serve_forever()
    except OSError as e:
        if "Address already in use" in str(e):
            print(f"Nutsty Auth Server port {PORT} already active.")
        else:
            sys.stderr.write(f"Auth server error: {e}\n")

main = run_server

if __name__ == "__main__":
    run_server()
