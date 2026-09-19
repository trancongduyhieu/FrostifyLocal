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

## 7. Friends 24h Notes & Real-time Listen Along Engine
- **Tệp**: `backend/social_notes.py`, `backend/auth_server.py`, `shell.qml`, `components/FriendStoryModal.qml`, `components/CoListenersPopover.qml`, `components/FloatingChatBubble.qml`, `components/SuggestTrackToast.qml`.
- **Cơ chế hoạt động**:
  - Ghi chú 24h & bài hát đính kèm đồng bộ qua Cloudflare Worker / auth server daemon (`port 17890`).
  - **Đồng bộ 2 chiều thời gian thực (Bidirectional RPC)**: Hàng đợi FIFO `/api/notes/events` truyền sự kiện tức thì (`join`, `leave`, `play`, `pause`, `seek`, `track_change`, `track_suggest`, `chat_message`) độ trễ < 50ms.
  - **Seek Drift Reconciliation**: Tính toán `expectedPos = np.position + elapsed`. Tự động nắn chỉnh nếu độ lệch $\Delta t > 2.0\text{s}$, giữ trôi lệch thực tế $< 0.4\text{s}$.
  - **Bẫy lỗi**: Host khi pause vẫn phải gửi `now_playing` kèm `is_playing: false` thay vì gửi `null` để Co-Listener dừng đúng lúc. Cờ `isSyncingFromFriend` ngăn chặn loop phản hồi ngược vô tận.

---

## 8. Lưu Trữ Trạng Thái Người Dùng & Đồng Bộ Reactive (`nutsty_settings.json`)
- **Tệp lưu**: `~/.config/noctalia/nutsty_settings.json`.
- **Cơ chế đọc an toàn**: `shell.qml` nạp tự động qua `FileView` kết hợp timer trễ `delayedSettingsRead` (100ms) để bảo đảm tiến trình bất đồng bộ của Quickshell hoàn tất trước khi phân giải JSON.
- **Ràng buộc QML Binding**: Khi click Shuffle hoặc Repeat trong `components/PlayerBarBottom.qml`, chỉ phát signal `toggleShuffle()` / `toggleRepeat()` để `shell.qml` xử lý và gọi `saveSettings()`. Tuyệt đối không gán đè thuộc tính cục bộ làm phá vỡ reactive property binding.
