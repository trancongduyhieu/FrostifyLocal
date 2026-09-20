#!/usr/bin/env python3
"""
Comprehensive Cloud Relay & Friends Test Suite for Nutsty.
Tests:
1. Identity isolation & profile suffix handling
2. Profile update & discriminator collision detection
3. Search isolation (no ghost tags, search by tag, name, PIN)
4. Friend request lifecycle (request, pending list, accept, reject, unfriend)
5. Synchronized notes & FriendsPulseBar synthetic entries
6. Real-time presence & now_playing updates
"""

import sys
import time
import unittest
import urllib.request
import urllib.parse
import urllib.error
import json

BASE_URL = "http://127.0.0.1:17890"

def req(path, method="GET", data=None):
    url = f"{BASE_URL}{path}"
    headers = {"Content-Type": "application/json"}
    body = json.dumps(data).encode("utf-8") if data else None
    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        try:
            return json.loads(err.read().decode("utf-8"))
        except Exception:
            raise err

class TestCloudRelayFeatures(unittest.TestCase):

    def test_01_profile_me(self):
        """Verify user1 and user2 identity endpoints return correct immutable UUID and tags."""
        res1 = req("/api/users/me?profile=user1")
        self.assertTrue(res1.get("success"))
        p1 = res1.get("profile")
        self.assertEqual(p1.get("username"), "Shiraori")
        self.assertEqual(p1.get("discriminator"), "3333")
        self.assertEqual(p1.get("tag"), "Shiraori#3333")
        self.assertTrue(p1.get("user_id").startswith("usr_"))

        res2 = req("/api/users/me?profile=user2")
        self.assertTrue(res2.get("success"))
        p2 = res2.get("profile")
        self.assertEqual(p2.get("username"), "Hiếu Trần")
        self.assertEqual(p2.get("discriminator"), "8691")
        self.assertEqual(p2.get("tag"), "Hiếu Trần#8691")
        self.assertTrue(p2.get("user_id").startswith("usr_"))

    def test_02_search_isolation_and_no_ghost_tags(self):
        """Verify searching does NOT return old ghost tags (#7059) and correctly isolates tags."""
        # Search for 7059
        res_ghost = req("/api/users/search?q=7059&profile=user1")
        self.assertEqual(len(res_ghost.get("results", [])), 0, "Ghost tag #7059 must NOT appear in search")

        # Search for exact tag
        res_tag = req("/api/users/search?q=Hi%E1%BA%BFu%20Tr%E1%BA%A7n%238691&profile=user1")
        self.assertEqual(len(res_tag.get("results", [])), 1)
        self.assertEqual(res_tag["results"][0]["tag"], "Hiếu Trần#8691")

        # Search by discriminator
        res_pin = req("/api/users/search?q=8691&profile=user1")
        self.assertEqual(len(res_pin.get("results", [])), 1)
        self.assertEqual(res_pin["results"][0]["tag"], "Hiếu Trần#8691")

        # Search by name substring
        res_name = req("/api/users/search?q=Hi%E1%BA%BFu&profile=user1")
        self.assertEqual(len(res_name.get("results", [])), 1)
        self.assertEqual(res_name["results"][0]["name"], "Hiếu Trần")

        # Self search should not return self
        res_self = req("/api/users/search?q=Shiraori&profile=user1")
        for r in res_self.get("results", []):
            self.assertNotEqual(r["tag"], "Shiraori#3333", "User should not see themselves in search results")

    def test_03_profile_rename_and_collision_detection(self):
        """Verify discriminator collision detection and suggested discriminator fallback."""
        # Attempt to rename user2 to Shiraori#3333 (collision with user1)
        col_res = req("/api/users/update_profile", method="POST", data={
            "profile": "user2",
            "new_username": "Shiraori",
            "new_discriminator": "3333"
        })
        self.assertFalse(col_res.get("success"))
        self.assertEqual(col_res.get("error"), "Tag already taken")
        self.assertIn("suggested_discriminator", col_res)
        self.assertIn("suggested_tag", col_res)
        self.assertNotEqual(col_res.get("suggested_discriminator"), "3333")

        # Verify renaming with valid non-colliding name
        ok_res = req("/api/users/update_profile", method="POST", data={
            "profile": "user2",
            "new_username": "Hiếu Trần",
            "new_discriminator": "8691"
        })
        self.assertTrue(ok_res.get("success"))
        self.assertEqual(ok_res["user"]["tag"], "Hiếu Trần#8691")

    def test_04_notes_and_pulse_bar_synthesis(self):
        """Verify GET /api/notes synthesizes entries for cloud friends even without 24h note."""
        res = req("/api/notes?profile=user1")
        notes = res.get("notes", [])
        self.assertGreaterEqual(len(notes), 1)
        hieu_entry = next((n for n in notes if n.get("tag") == "Hiếu Trần#8691"), None)
        self.assertIsNotNone(hieu_entry, "Friend Hiếu Trần must appear in notes list for FriendsPulseBar")
        self.assertTrue(hieu_entry.get("is_friend"))
        self.assertEqual(hieu_entry.get("user_name"), "Hiếu Trần")

    def test_05_friendship_lifecycle(self):
        """Verify unfriend -> send request -> list pending -> accept cycle."""
        # 1. Unfriend
        unf_res = req("/api/friends/remove", method="POST", data={
            "profile": "user1",
            "target_id": "usr_8db357a9daa9442b"
        })
        self.assertTrue(unf_res.get("success"))

        # Verify no longer friends
        f1 = req("/api/friends?profile=user1")
        self.assertEqual(len(f1.get("friends", [])), 0)

        # 2. User 1 sends friend request to User 2
        send_res = req("/api/friends/request", method="POST", data={
            "profile": "user1",
            "target_id": "usr_8db357a9daa9442b"
        })
        self.assertTrue(send_res.get("success"))

        # 3. User 2 checks incoming requests
        f2 = req("/api/friends?profile=user2")
        inc = f2.get("incoming_requests", [])
        self.assertEqual(len(inc), 1)
        self.assertEqual(inc[0]["from_tag"], "Shiraori#3333")
        self.assertEqual(f2.get("unread_count"), 1)

        # 4. User 2 accepts friend request
        acc_res = req("/api/friends/respond", method="POST", data={
            "profile": "user2",
            "request_id": inc[0]["id"],
            "action": "accept"
        })
        self.assertTrue(acc_res.get("success"))

        # 5. Verify both users are friends again and unread count is 0
        f2_after = req("/api/friends?profile=user2")
        self.assertEqual(len(f2_after.get("friends", [])), 1)
        self.assertEqual(f2_after.get("unread_count"), 0)
        self.assertEqual(len(f2_after.get("incoming_requests", [])), 0)

        f1_after = req("/api/friends?profile=user1")
        self.assertEqual(len(f1_after.get("friends", [])), 1)
        self.assertEqual(f1_after["friends"][0]["tag"], "Hiếu Trần#8691")

    def test_06_now_playing_presence(self):
        """Verify presence & now_playing status update propagates to friend."""
        # User 1 reports playing a track
        np_res = req("/api/now_playing", method="POST", data={
            "profile": "user1",
            "title": "Dyna-Mind",
            "artist": "Yunomi",
            "image": "https://example.com/dyna.jpg"
        })
        self.assertTrue(np_res.get("success"))

        # User 2 checks notes or friends
        notes = req("/api/notes?profile=user2").get("notes", [])
        shiraori_note = next((n for n in notes if n.get("tag") == "Shiraori#3333"), None)
        self.assertIsNotNone(shiraori_note)
        self.assertIn("Dyna-Mind", shiraori_note.get("now_playing", ""))

if __name__ == "__main__":
    unittest.main()
