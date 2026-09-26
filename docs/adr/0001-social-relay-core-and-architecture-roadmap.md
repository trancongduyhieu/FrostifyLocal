# ADR-0001: Social Relay Core Consolidation & 3-Phase Deepening Roadmap

- **Status**: Accepted
- **Date**: 2026-09-26
- **Deciders**: User, Antigravity
- **Informed by**: `improve-codebase-architecture`, `codebase-design`, `grill-with-docs`

---

## 1. Context and Problem Statement

The Nutsty / FrostifyLocal codebase has experienced architectural friction across its three largest hotspots:
1. **The Social & Co-listening cluster** (`social_notes.py`, `cloud_relay_client.py`, `social_routes.py`, `social_engine.js`) has suffered 7 consecutive emergency bugfixes due to fragmented state, multi-identifier cache collision (`user_id` vs `username` vs `email`), and leaky communication between layers.
2. **The `shell.qml` god-host** (4,611 lines, 49 commits) directly coordinates 25+ global audio properties, process IPC runners, and poll timers, forcing all subviews to mutate window-level state.
3. **The `backend/ytmusic_helper.py` monolith** (3,839 lines, 32 commits) entangles YouTube catalog browsing, Google account auth, and yt-dlp audio stream extraction with bot-evasion logic.

We need a structured, risk-minimized roadmap to deepen these shallow modules into high-leverage deep modules without destabilizing the working application.

---

## 2. Decision Drivers

- **Locality**: Bug fixes and state synchronization must concentrate inside single modules rather than scattering across HTTP routes and QML timers.
- **Seam Clarity**: Replace fragile, multi-layered pass-throughs with clean, testable seams.
- **Stability First**: Refactor backend components into verified units before touching the top-level QML shell.
- **SSOT Identity**: Eliminate ambiguous user identification across network and cache boundaries.

---

## 3. Considered Options

### For Execution Sequencing:
- **Option A (Accepted)**: Phase 1 (Social Relay Core) &rarr; Phase 2 (Streaming vs Catalog split) &rarr; Phase 3 (`shell.qml` AudioPlaybackEngine).
- **Option B**: Start with `shell.qml` refactoring first.
- **Option C**: Start with `ytmusic_helper.py` split first.

### For Social Relay Architecture:
- **Option A (Accepted)**: Extract `backend/social_relay_core.py` as a deep module with a unified cache and `canonical_user_id` SSOT; keep `cloud_relay_client.py` as a pure transport adapter at the seam; eliminate `social_notes.py` (passes deletion test).
- **Option B**: Maintain 4 layers and continue patching identifier sets and cache lookups.

---

## 4. Decision Outcome

### Decision 1: Phased Roadmap Sequence
We execute the refactoring in 3 sequential phases:
1. **Phase 1: Deepen Social & Co-Listening** (`SocialRelayCore`).
2. **Phase 2: Decouple Audio Streaming & Catalog** (`AudioStreamResolver` + `CatalogEngine`).
3. **Phase 3: Deconstruct `shell.qml` God-Host** (`AudioPlaybackEngine` in QML/JS).

### Decision 2: `SocialRelayCore` Deep Module
We consolidate `backend/social_notes.py` and `backend/cloud_relay_client.py` into a unified `SocialRelayCore` module:
- **Exposed Interface**:
  - `get_active_feed() -> List[Note]`
  - `publish_note(text, track) -> Note`
  - `delete_note() -> bool`
  - `get_co_listeners() -> List[CoListener]`
  - `sync_co_listen_state(role, track, position, is_playing) -> CoListenSync`
  - `send_chat(text) -> ChatMessage`
- **Internalized Logic**:
  - Unified thread-safe in-memory cache with automatic 24h TTL eviction.
  - Multi-identifier lookup table normalizing all inputs to `canonical_user_id`.
  - Cloudflare Worker HTTP polling and offline fallback.

### Decision 3: `canonical_user_id` as the Sole SSOT Key
Every entity (Note, Co-listener, Event, Chat) uses UUIDv4 `canonical_user_id` as its unique key. Display names (`username#1234`) are resolved strictly at presentation time.

---

## 5. Consequences

### Positive
- **Concentrated Locality**: Identity resolution and chat deduplication occur in exactly one place.
- **Fast Testability**: A mock or in-memory transport can be plugged into the seam, enabling instant unit tests for co-listening and notes without hitting the Cloudflare Worker.
- **Deletion Win**: Removes ~500 lines of redundant pass-through code from `social_notes.py`.

### Negative / Trade-offs
- Call sites in `backend/social_routes.py` and tests must be retargeted to `SocialRelayCore`.
- Existing user profile caches must be migrated to index strictly by `canonical_user_id`.
