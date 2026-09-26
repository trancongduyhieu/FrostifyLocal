#!/usr/bin/env python3
"""
Unit and integration test suite for backend/social_relay_core.py and backward compatibility.
Verifies SSOT #1, #2, #3 contracts, unified caching, and deduplication.
"""

import os
import sys
import json
import time
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).parent.parent))

from backend.social_relay_core import SocialRelayCore, SOCIAL_RELAY_CORE
from backend import social_notes


def test_peer_normalization():
    print("[1] Testing SSOT #3 Peer Normalization Contract...")
    raw = {
        "id": "usr_test123",
        "tag": "shiraori#1234",
        "username": "Shiraori",
        "avatar_url": "https://example.com/avatar.png",
        "last_active_at": time.time(),
        "now_playing": {"title": "Test Song", "artist": "Test Artist"}
    }
    norm = SOCIAL_RELAY_CORE.normalize_peer(raw)
    assert norm["user_id"] == "usr_test123", f"Wrong user_id: {norm['user_id']}"
    assert norm["tag"] == "shiraori#1234", f"Wrong tag: {norm['tag']}"
    assert norm["email"] == "shiraori#1234", f"Wrong email: {norm['email']}"
    assert norm["name"] == "Shiraori", f"Wrong name: {norm['name']}"
    assert norm["avatar"] == "https://example.com/avatar.png", f"Wrong avatar: {norm['avatar']}"
    assert norm["is_online"] is True, f"Should be online"
    assert norm["now_playing"]["title"] == "Test Song"
    print("    -> PASS: SSOT #3 contract verified.")


def test_note_publishing_and_feed():
    print("[2] Testing Note Publishing & Unified Feed Caching...")
    test_text = f"Architecture Test Note {int(time.time())}"
    test_track = {"title": "Deep Module Theme", "artist": "John Ousterhout", "videoId": "ousterhout123"}
    
    pub_res = SOCIAL_RELAY_CORE.publish_note(test_text, test_track, profile="test")
    assert pub_res.get("success"), f"Publish failed: {pub_res}"
    print("    -> Note published successfully.")

    feed = SOCIAL_RELAY_CORE.get_feed(profile="test")
    assert feed.get("success"), f"Feed fetch failed: {feed}"
    assert feed.get("my_note") is not None, "my_note missing in feed"
    assert feed["my_note"]["note_text"] == test_text, f"Text mismatch: {feed['my_note']['note_text']}"
    print("    -> PASS: Note verified in feed cache.")

    del_res = SOCIAL_RELAY_CORE.delete_note(profile="test")
    assert del_res.get("success"), f"Delete failed: {del_res}"
    print("    -> PASS: Note deleted cleanly.")


def test_co_listening_and_chat_dedup():
    print("[3] Testing Co-Listening & Chat Message Deduplication...")
    core = SocialRelayCore()
    peer1 = {"id": "usr_peer_1", "username": "PeerOne", "avatar_url": "", "last_active_at": time.time()}
    core.register_co_listener(peer1)
    
    active = core.get_co_listeners()
    assert len(active) == 1, f"Expected 1 active listener, got {len(active)}"
    assert active[0]["user_id"] == "usr_peer_1"

    # Test chat broadcast
    ok1, msg1 = core.broadcast_chat("Hello from guest!", peer1)
    assert ok1 is True, f"First chat should succeed: {msg1}"
    assert msg1["text"] == "Hello from guest!"

    # Test duplicate suppression within rapid window
    ok2, msg2 = core.broadcast_chat("Hello from guest!", peer1)
    assert ok2 is False, f"Duplicate chat should be suppressed: {msg2}"
    print("    -> PASS: Chat deduplication prevented echo bubble loop.")

    core.unregister_co_listener("usr_peer_1")
    assert len(core.get_co_listeners()) == 0, "Listener was not unregistered"
    print("    -> PASS: Co-listener unregistered cleanly.")


def test_backward_compatibility():
    print("[4] Testing social_notes.py Backward Compatibility Forwarder...")
    u = social_notes.get_current_user()
    assert "user_id" in u or "email" in u, f"Invalid user: {u}"
    
    feed = social_notes.fetch_notes()
    assert "notes" in feed, f"Invalid feed format from social_notes: {feed}"
    print("    -> PASS: Backward compatibility with social_notes.py verified.")


if __name__ == "__main__":
    print("=== Running Social Relay Core Test Suite ===")
    test_peer_normalization()
    test_note_publishing_and_feed()
    test_co_listening_and_chat_dedup()
    test_backward_compatibility()
    print("\nALL 4 SOCIAL RELAY CORE TESTS PASSED SUCCESSFULLY!")
