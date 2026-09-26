# ADR-0003: Audio Playback Engine Consolidation & Shell Deconstruction

- **Status**: Proposed
- **Date**: 2026-09-26
- **Deciders**: User, Antigravity
- **Informed by**: `codebase-design`, `grill-with-docs`, `improve-codebase-architecture`

---

## 1. Context and Problem Statement

`shell.qml` is currently 4,614 lines long and acts as a god-host orchestrator. Over 700 lines are dedicated to low-level audio playback logic, including:
1. Core playback execution (`playOnlineTrack`, `playTrack`, `togglePlay`, `playNext`, `playPrev`, `seekAudio`, `setVolume`).
2. Queue lifecycle and track transitions (`insertTrackPlayNext`, `appendTrackToQueue`, `removeTrackFromQueue`, `deleteLocalTrack`, `batchDeleteTracks`, `shufflePlayBrowsing`, `handleDislikedTrack`).
3. Player daemon status reconciliation (`statusProcess.onRead`), cold-start track recovery, auto-advance on track finish, and sleep timer countdown.
4. YouTube Music radio queue appending (`radioProc.onRead`).

This procedural logic is mixed with top-level window layout, Wayland layer-shell configuration, styling tokens, and navigation modals. Modifying playback behavior requires wading through thousands of lines of unrelated UI code.

---

## 2. Decision Drivers

- **Locality**: All playback transitions, socket IPC triggers, and queue mutators must reside in a single cohesive module.
- **Dual-Platform Parity**: Linux Wayland (Niri/CachyOS) and Windows (`launcher_win.py` + `compat/Quickshell`) must continue functioning with 0 regressions.
- **Contract Preservation**: Child QML components (`PlayerBarBottom.qml`, `AmberolDetailView.qml`, `TrackCard.qml`, `FriendStoryModal.qml`), desktop widgets, and IPC handlers call `win.playOnlineTrack(...)`, `win.togglePlay()`, `win.seekAudio(...)`, etc. These public seams must remain intact.
- **Zero Polish/Loop Regressions**: State changes must not re-trigger recursive QML layout loops.

---

## 3. Considered Options

### Option A (Recommended): Consolidate into `components/playback_engine.js` with 1-Line `win` Delegates
- Consolidate all audio functions, queue manipulations, and status reconciliation into `components/playback_engine.js`.
- Maintain thin 1-line delegate methods on `win` in `shell.qml` (`win.playOnlineTrack = ...`, `win.togglePlay = ...`).
- Quickshell `Process` components (`statusProcess`, `radioProc`) delegate their `onRead` handlers to `PlaybackEngine.handlePlayerStatus` and `PlaybackEngine.handleRadioResponse`.
- **Pros**:
  - Drops ~700-800 lines of complex procedural clutter from `shell.qml`.
  - 100% backward compatible with all QML bindings, child components, and Windows PySide6 runtime.
  - Aligns with the proven architecture of `components/social_engine.js` (ADR-0001).
  - Fast AST and contract validation via `scripts/verify_codebase.py`.
- **Cons**:
  - Declarative properties (`isPlaying`, `currentTime`, `totalDuration`, `currentTrack`, `currentTracks`) remain declared on `win`.

### Option B: Extract to `components/AudioPlaybackEngine.qml` with Property Aliases
- Create a dedicated QML element `AudioPlaybackEngine.qml` housing properties and processes.
- Expose properties to `win` via `property alias`.
- **Pros**:
  - State declarations are physically housed in a separate QML file.
- **Cons**:
  - `property alias` on complex dynamic JavaScript arrays (`currentTracks`) and objects can introduce binding pitfalls or compatibility issues with `compat/Quickshell` on Windows.
  - Adds an extra layer of indirection for every child component property access.

---

## 4. Decision Outcome

We choose **Option A**: Deepen `components/playback_engine.js` as the Single Source of Truth for audio playback operations and queue management, and thin out `shell.qml` into a clean visual host.

### Interfaces Exposed by `PlaybackEngine`:
- `isSameTrack(a, b)`
- `findLocalDownloadedTrack(win, trk)`
- `playOnlineTrack(win, trk, startRadio, radioProc, prewarmTimer, pollTimer)`
- `playTrack(win, trk, pollTimer)`
- `togglePlay(win, pollTimer)`
- `playNext(win)`
- `playPrev(win)`
- `seekAudio(win, sec)`
- `seekLocalOnly(win, sec)`
- `setVolume(win, vol)`
- `startSleepTimer(win, seconds, mode)`
- `cancelSleepTimer(win)`
- `rateSong(win, vid, rating)`
- `handleDislikedTrack(win, trk)`
- `insertTrackPlayNext(win, trk)`
- `appendTrackToQueue(win, trk)`
- `removeTrackFromQueue(win, trk)`
- `deleteLocalTrack(win, trk)`
- `batchDeleteTracks(win, paths)`
- `shufflePlayBrowsing(win)`
- `trackPlayback(win, trk, playbackTrackingProc)`
- `handlePlayerStatus(win, data, listenAlongSeekSafetyTimer, sessionFileView)`
- `handleRadioResponse(win, data)`
- Plus existing library/artist/album helpers: `startRadioFromTrack`, `playFriendTrack`, `playArtistShuffle`, `addTracksToQueue`, `downloadEntireAlbum`, `loadArtistDetails`, `goBackFromArtist`, `loadAlbumDetails`, `loadPlaylistTracks`, `deleteCustomPlaylist`.

---

## 5. Consequences

### Positive
- `shell.qml` shrinks significantly, improving readability and maintainability.
- All playback logic, daemon IPC communication, and queue transition handling are localized in a single JavaScript engine.
- Zero risk to child component bindings or dual-platform runtime.

### Negative / Trade-offs
- `win` acts as context provider passed into `PlaybackEngine` methods.
