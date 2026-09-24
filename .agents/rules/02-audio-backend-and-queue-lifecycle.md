# Audio Backend, IPC & Queue Lifecycle Specification

Tài liệu đặc tả chuyên sâu về hệ thống daemon phát nhạc, giao thức IPC Unix Domain Socket, YouTube Music engine và vòng đời quản lý hàng đợi phát nhạc của dự án Nutsty.

---

## 1. Backend Daemon & Giao Thức IPC MPV
- **Tiến trình**: `backend/player_daemon.py` quản lý một instance `mpv` thường trú.
- **Giao tiếp**: Unix Domain Socket tại `/tmp/nutsty_mpv.sock`.
- **Tính năng âm thanh**:
  - Hỗ trợ phát liền mạch (gapless playback), giải mã phần cứng (hardware decoding).
  - Tích hợp hook `yt-dlp` (`mpv --ytdl-format="bestaudio"`) để stream luồng YouTube Music trực tiếp (< 100MB RAM, độ trễ cực thấp).
  - **Tránh HTTP 403 CDN & Autoplay tức thì**: `resolve_stream_url()` dùng `player_client: ["android"]` (không ép cookie web vào direct googlevideo URL). MPV bổ sung `--referrer=https://www.youtube.com/` và `--audio-buffer=0.4` để mở stream ngay trong ~1.0s, autoplay 100% không bị abort.
- **Quy tắc an toàn**: Không bao giờ giao tiếp trực tiếp với tiến trình con `mpv` bằng stdin/stdout shell thô; mọi lệnh phát, dừng, tìm bài, điều chỉnh âm lượng bắt buộc phải gửi qua socket IPC JSON.

---

## 2. YouTube Music Streaming & Bóc Tách Phân Đoạn (Continuation Shelves)
- **Tệp**: `backend/ytmusic_helper.py`.
- **Thư viện**: `ytmusicapi` (Python).
- **Cơ chế bóc tách phân đoạn sâu**:
  - Hàm `_normalize_shelf_item` xử lý đồng thời initial shelves và continuation shelves (`sectionListContinuation`).
  - Cung cấp hơn 10 phân đoạn sâu (*Listen again*, *Mixed for you*, *Quick picks*, *Long listens*, *Classical for Sleeping*...) cho mọi mood tag (All, Sleep, Romance, Energize, Sad, Focus, Party...).

---

## 3. Phân Lập Luồng Duyệt (Browsing) & Hàng Đợi Phát Nhạc (Playback Queue)
- **Hai thuộc tính độc lập tại `shell.qml`**:
  - `win.browsingTracks`: Danh sách bài hát đang hiển thị trên giao diện duyệt (kết quả tìm kiếm, tab Downloads, danh sách bài của album/nghệ sĩ).
  - `win.currentTracks`: Hàng đợi phát nhạc thực sự (Queue).
- **Nguyên tắc bất khả xâm phạm**: Thao tác duyệt xem playlist, gõ tìm kiếm bài hát hoặc mở tab Tải xuống **tuyệt đối không được làm gián đoạn hay ghi đè hàng đợi phát nhạc** (`win.currentTracks`). Chỉ khi người dùng click trực tiếp vào một bài hát thì bài hát đó mới được kích hoạt phát.

---

## 4. Tách Bạch Browsing Title & Playing Source Title
- **Ràng buộc cốt lõi**:
  - `win.mainSectionTitle`: Tiêu đề phục vụ giao diện duyệt (browsing UI).
  - `win.playingSourceTitle`: Nguồn gốc thực tế của bài hát đang phát (album, playlist, artist hoặc queue).
- **Mục đích**: Triệt tiêu hoàn toàn hiện tượng xung đột trạng thái (race condition) khi người dùng đang nghe Album A nhưng bấm chuột sang xem Album B. `playingSourceTitle` chỉ được gán lại khi người dùng thực sự bấm phát một nguồn mới.

---

## 5. Cơ Chế Snapshot & Reset Queue An Toàn Khi Chuyển Mood Chips
- **Tệp**: `shell.qml` và `components/YTMusicNowPlayingView.qml`.
- **Cơ chế hoạt động**:
  1. **Khởi tạo bài/album mới**: Khi phát bài hát mới từ album (`!isAlreadyInQueue` trong `onTrackChanged` hoặc `playingPlaylistTitle` đổi), `root.originalAlbumQueue` được reset về `[]` và `root.selectedMoodIndex = 0`.
  2. **Đồng bộ tab Tất cả**: Tại tab "Tất cả" (`selectedMoodIndex === 0`), `originalAlbumQueue` tự động cập nhật theo `queueTracks`.
  3. **Snapshot khi đổi Mood**: Khi người dùng bấm sang mood phụ ("Khám phá", "Lãng mạn"), `loadQueueForChipIndex` tự động snapshot toàn bộ danh sách bài hát đang hiển thị ở mood 0 vào `originalAlbumQueue` trước khi gọi API nạp radio mood.
  4. **Khôi phục nguyên bản**: Khi bấm quay lại tag "Tất cả" (`index 0`), hệ thống khôi phục ngay lập tức danh sách bài hát gốc của album vào `win.currentTracks` và phát tín hiệu `queueUpdated` mà không gọi API radio.
- **Chặn đè queue**: `moodChipsProc` bị chặn tự động gọi `loadQueueForChipIndex` khi đang phát album/playlist để bảo đảm hàng đợi ban đầu không bị ghi đè.

---

## 6. Trình Quản Lý Tải Nhạc Đa Luồng (Download Manager Daemon)
- **Backend**: `backend/download_manager.py` chạy thường trú, giao tiếp qua Unix Domain Socket `/tmp/nutsty_download.sock` và file trạng thái nguyên tử (atomic JSON) `/tmp/frostify_download_status.json`.
- **Chất lượng**: Tự động tải âm thanh 192k AAC/M4A qua `yt-dlp`, nhúng metadata ID3 và bìa album chất lượng cao qua FFmpeg (`-an -frames:v 1 -update 1`).
- **Synced Lyrics**: Tự động tải file lời bài hát đồng bộ (`.lrc`) đi kèm vào thư mục `~/Music/Downloads_Phone`.
- **Giao diện**: `components/DownloadManager.qml` (State engine qua `FileView` + polling timer 250ms) và `components/DownloadQueuePopover.qml` (Minimalist Clean #121212 Nutsty, progress bar 3px, nút hủy, nút mở thư mục nhạc).

---

## 7. Kiến Trúc Modular Social & Music Engine (3 SSOT Chuẩn Hóa)
- **Backend Modular**: `backend/auth_server.py` (~224 dòng) đóng vai trò HTTP Router thuần túy điều phối sang `backend/music_routes.py` (YTMusic/auth), `backend/social_routes.py` (Notes 24h, Friends, Events, Profile) và `backend/cloud_relay_client.py` (`CloudRelayEngine`, `CloudRelayClient`, vaults).
- **Frontend JS Engine**: Logic mạng xã hội/Listen Along tách vào `components/social_engine.js` và logic phát nhạc/album/shuffle tách vào `components/playback_engine.js`; `shell.qml` giữ các hàm wrapper 1 dòng trên `win` để bảo toàn 100% visual tree (`MultiEffect`) và QML bindings.
- **3 Single Sources of Truth (SSOT)**:
  1. **SSOT #1 (Config Path)**: `platform_compat.get_config_dir()` trả về `~/.config/noctalia` đồng nhất trên cả Linux & Windows (tự động migrate file cũ từ `%APPDATA%/Nutsty`).
  2. **SSOT #2 (Canonical Identity)**: `cloud_relay_client.get_canonical_user()` lấy định danh chuẩn từ `nutsty_cloud_identity.json` (`user_id`, `username#pin`, `secret_key`).
  3. **SSOT #3 (Peer Normalization)**: `SocialEngine.normalizePeer(raw)` chuẩn hóa mọi đối tượng bạn bè/co-listener về `{ user_id, tag, email, name, avatar, is_online }`.

---

## 8. Friends 24h Notes & Real-time Listen Along Engine
- **Tệp**: `backend/social_routes.py`, `components/social_engine.js`, `components/FriendStoryModal.qml`, `components/CoListenersPopover.qml`, `components/FloatingChatBubble.qml`.
- **Đồng bộ 2 chiều thời gian thực (Bidirectional RPC)**: Hàng đợi FIFO `/api/notes/events` truyền sự kiện tức thì (`join`, `leave`, `play`, `pause`, `seek`, `track_change`, `track_suggest`, `chat_message`) độ trễ < 50ms.
- **Seek Drift Reconciliation**: Tính toán `expectedPos = np.position + elapsed`. Tự động nắn chỉnh nếu độ lệch $\Delta t > 2.0\text{s}$, giữ trôi lệch thực tế $< 0.4\text{s}$.
- **Bẫy lỗi**: Host khi pause vẫn phải gửi `now_playing` kèm `is_playing: false` thay vì `null`. Cờ `isSyncingFromFriend` chặn loop phản hồi ngược.

---

## 9. Lưu Trữ Cài Đặt (`nutsty_settings.json`) & Hiện Diện Thời Gian Thực (Presence)
- **Cài đặt (`~/.config/noctalia/nutsty_settings.json`)**: `shell.qml` nạp qua `FileView` + timer `delayedSettingsRead` (100ms). Nút Shuffle/Repeat chỉ phát signal `toggleShuffle()` / `toggleRepeat()` để `shell.qml` xử lý và gọi `saveSettings()`.
- **Presence & Liveness**: Cloudflare Edge Worker & local daemon áp dụng ngưỡng 25s (`ONLINE_THRESHOLD_MS = 25000`). Khi thoát app, `shell.qml` gọi `sendOfflineSignal()` tới `/api/users/offline` để xóa `now_playing` và đặt `last_active_at = 0` tức thì.


