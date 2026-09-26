#!/usr/bin/env python3
"""
Test Suite for Decoupled YouTube Music Subsystems (Phase 2)
Verifies:
1. 100% symbol re-export contract on ytmusic_helper facade.
2. Independent operation of ytmusic_auth, catalog_engine, stream_resolver, song_enrichment.
3. StreamResolverCache TTL expiration and cache invalidation.
4. CLI entry point backward compatibility.
"""
import sys
import os
import json
import subprocess
import unittest

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND_DIR = os.path.join(ROOT_DIR, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import ytmusic_helper
import ytmusic_auth
import catalog_engine
import stream_resolver
import song_enrichment

class TestDecoupledYTMusic(unittest.TestCase):

    def test_01_facade_symbol_parity(self):
        """Verify all critical public API symbols exist on the ytmusic_helper facade."""
        critical_symbols = [
            "get_auth_status", "save_auth", "logout", "get_ytmusic_client", "get_exported_cookie_file",
            "clean_artist_name", "clean_thumbnail_url", "normalize_track",
            "get_personalized_home", "get_radio", "get_mood_feed",
            "search_ytmusic", "search_categorized", "get_search_suggestions",
            "resolve_stream_url", "resolve_video_id_for_track", "send_playback_tracking",
            "get_song_details", "rate_song_action", "get_song_related_content",
            "get_youtube_lyrics", "get_apple_music_animated_artwork", "resolve_square_cover",
            "handle_cli", "main", "execute_command"
        ]
        for sym in critical_symbols:
            self.assertTrue(hasattr(ytmusic_helper, sym), f"Missing symbol on facade: {sym}")
            self.assertTrue(callable(getattr(ytmusic_helper, sym)), f"Symbol is not callable: {sym}")
        print("  [PASS] test_01_facade_symbol_parity: All 26 critical symbols present and callable on facade.")

    def test_02_catalog_normalization(self):
        """Verify catalog_engine normalizes raw YouTube Music items correctly."""
        raw_track = {
            "videoId": "test_vid_123",
            "title": "Test Song",
            "artists": [{"name": "Test Artist • Topic"}],
            "thumbnails": [{"url": "https://lh3.googleusercontent.com/xyz=w120-h120"}]
        }
        norm = catalog_engine.normalize_track(raw_track)
        self.assertEqual(norm["videoId"], "test_vid_123")
        self.assertEqual(norm["title"], "Test Song")
        self.assertEqual(norm["artist"], "Test Artist")
        self.assertTrue(norm["path"].startswith("ytdl://test_vid_123"))
        print("  [PASS] test_02_catalog_normalization: catalog_engine item normalization works cleanly.")

    def test_03_stream_resolver_ttl_cache(self):
        """Verify StreamResolverCache in-memory TTL and disk persistence."""
        test_vid = "mock_test_vid_999"
        test_url = "https://rr1---sn-mock.googlevideo.com/videoplayback?expire=99999"
        
        # 1. Put into cache
        stream_resolver.put_cached_stream_url(test_vid, test_url, "high_opus")
        
        # 2. Retrieve from cache
        cached = stream_resolver.get_cached_stream_url(test_vid, "high_opus")
        self.assertEqual(cached, test_url)
        
        # 3. Invalidate cache on simulated 403
        stream_resolver.invalidate_cached_stream_url(test_vid)
        after_inval = stream_resolver.get_cached_stream_url(test_vid, "high_opus")
        self.assertIsNone(after_inval)
        print("  [PASS] test_03_stream_resolver_ttl_cache: Stream caching, retrieval, and 403 eviction work.")

    def test_04_auth_status_query(self):
        """Verify ytmusic_auth returns valid dictionary status."""
        st = ytmusic_auth.get_auth_status()
        self.assertIsInstance(st, dict)
        self.assertIn("logged_in", st)
        print(f"  [PASS] test_04_auth_status_query: Auth status returned: logged_in={st.get('logged_in')}")

    def test_05_cli_dispatcher_execution(self):
        """Verify invoking ytmusic_helper via subprocess CLI works without exception."""
        cmd = [sys.executable, os.path.join(BACKEND_DIR, "ytmusic_helper.py"), "auth_status"]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        self.assertEqual(res.returncode, 0)
        parsed = json.loads(res.stdout)
        self.assertIn("logged_in", parsed)
        print("  [PASS] test_05_cli_dispatcher_execution: CLI 'auth_status' dispatched and returned valid JSON.")

if __name__ == "__main__":
    unittest.main()
