# ADR-0002: Decouple Audio Streaming and Catalog Browsing Monolith

- **Status**: Accepted
- **Date**: 2026-09-26
- **Deciders**: User, Antigravity
- **Informed by**: `codebase-design`, `grill-with-docs`, `improve-codebase-architecture`

---

## 1. Context and Problem Statement

The `backend/ytmusic_helper.py` file had grown into a 3,840-line monolith accumulating 32 commits. It mixed 4 completely separate domain responsibilities:
1. **Audio Streaming & Resolution**: Video ID extraction, CDN direct stream scraping, client spoofing (Android/iOS Innertube), anti-bot token synthesis, and URL disk caching.
2. **Catalog Browsing & Discovery**: Personalized home feeds, mood carousels, radio queues, categorized searches, artist discographies, and playlist parsing.
3. **Song Details & Metadata Enrichment**: Track credits, related tracks, Apple Music animated album artwork extraction, and lyric synchronization.
4. **Google Account Authentication**: Cookie sanitation, SAPISID token computation, and session validation.

This lack of locality created high regression risks: a fix in anti-bot streaming logic could inadvertently break home feed parsing or cookie validation.

---

## 2. Decision Drivers

- **Locality & Leverage**: Streaming logic must be completely isolated from scraping home feeds and radio queues.
- **Zero Breaking Changes**: Existing callers (`player_daemon.py`, `download_manager.py`, `shell.qml`, `launcher_win.py`) must continue operating without changing their import paths or CLI commands.
- **Seam Clarity**: A thin facade must re-export all symbols while delegating internal work to specialized deep modules.
- **Robust Cache Eviction**: Stream URLs expire every ~6 hours from Google CDN; caching must include TTL eviction (5h) and 403 invalidation.

---

## 3. Decision Outcome

We decompose `backend/ytmusic_helper.py` into 4 deep modules behind a backward-compatible facade:

1. **`backend/ytmusic_auth.py`**:
   - Manages Google cookie validation, SAPISID hashing, and authenticated `ytmusicapi` sessions.
   - Functions: `get_auth_status()`, `save_auth()`, `logout()`, `get_ytmusic_client()`, `get_exported_cookie_file()`.

2. **`backend/stream_resolver.py`**:
   - Manages direct audio stream URL extraction, multi-client fallback (Android, iOS, Web, yt-dlp), and TTL-aware stream caching (`StreamResolverCache`).
   - Functions: `resolve_stream_url()`, `resolve_video_id_for_track()`, `send_playback_tracking()`.

3. **`backend/catalog_engine.py`**:
   - Manages all catalog discovery and search algorithms.
   - Functions: `get_personalized_home()`, `get_mood_categories_live()`, `get_mood_feed()`, `get_radio()`, `get_artist()`, `get_album_details()`, `search_categorized()`, `get_playlist_tracks()`.

4. **`backend/song_enrichment.py`**:
   - Manages song details, related content recommendations, Apple Music animated video art resolution, and YouTube lyrics.
   - Functions: `get_song_details()`, `get_song_related_content()`, `rate_song_action()`, `get_apple_music_animated_artwork()`, `resolve_square_cover()`, `get_youtube_lyrics()`.

5. **`backend/ytmusic_helper.py` (Facade & CLI Dispatcher)**:
   - Re-exports all public symbols from the 4 sub-modules.
   - Routes CLI subcommands (`home`, `radio`, `mood`, `playlist`, `search`, `get_url`, `auth_status`, etc.) directly to their respective handlers.

---

## 4. Consequences

### Positive
- **Independent Evolution**: Audio stream extraction and anti-bot logic can be updated without touching catalog or auth code.
- **Testability**: `stream_resolver.py` and `catalog_engine.py` can be tested independently with isolated mocks.
- **Reduced Complexity**: `ytmusic_helper.py` shrinks from 3,840 lines to ~250 lines.

### Negative / Trade-offs
- Internal cross-module imports must carefully share common utilities (like `load_json`, `save_json`, `normalize_track`) without circular dependencies.
