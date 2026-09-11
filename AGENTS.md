# AGENTS.md - Frostify Local Pair-Programming Guide

Tài liệu đặc tả toàn diện về kiến trúc, cấu trúc thư mục, quy chuẩn mã nguồn, các quyết định thiết kế cốt lõi và hướng dẫn vận hành dự án **Frostify Local** dành cho các AI Agent / Assistant trong các session làm việc tiếp theo.

---

## 1. Tổng Quan Dự Án (Project Overview)

**Frostify Local** là trình phát nhạc cục bộ và máy tính để bàn (Desktop Music & Streaming Player) được tối ưu hóa chuyên sâu cho môi trường Linux Wayland (Niri compositor), kết hợp giữa:
- **Giao diện người dùng hiện đại**: Viết bằng **Quickshell (Qt 6 / QML)** với khả năng tăng tốc GPU phần cứng và hỗ trợ native Wayland layer-shell.
- **Backend phát nhạc độ trễ thấp**: Trình điều khiển **Python IPC daemon** (`backend/player_daemon.py`) giao tiếp trực tiếp qua Unix Domain Socket (`/tmp/frostify_mpv.sock`) với một tiến trình `mpv` chuyên biệt (hỗ trợ gapless playback, hardware decoding, flac/m4a/opus/mp3/ytdl streams).
- **Desktop Lyrics ma thuật phong cách Gacha/Anime**: Hiển thị lyric nổi trực tiếp lên hình nền desktop (tọa độ trên tà váy nhân vật/vùng hạ tiêu cự) với font chữ cổ điển *Instrument Serif*, hiệu ứng pop chữ gacha và đổ bóng điện ảnh thích ứng màu sắc hình nền.
- **Bộ máy màu sắc thích ứng Chromatic Salience (OKLAB / OKLCH)**: Trích xuất màu điểm nhấn nghệ thuật (màu tóc, má hồng, mắt, trang phục) từ hình nền hiện tại và cập nhật theo thời gian thực vào `~/.config/noctalia/frostify_palette.json`.

---

## 2. Quy Tắc Tối Thượng Cho AI (Critical Architectural Rules)

> [!CAUTION]
> 1. **TUYỆT ĐỐI KHÔNG DÙNG EMOJI TRONG GIAO DIỆN**: Mọi nút bấm, trạng thái, modal hay icon phải dùng file SVG hoặc component icon có sẵn (`components/SpotifyIcon.qml` hoặc `assets/icons/*.svg`). Tuyệt đối không dùng ký tự emoji (như 🎵, 📥, ⚙️, ❌) vì gây vỡ giao diện và "phèn".
> 2. **KHÔNG DÙNG VIỀN TRẮNG (WHITE HALO) CHO LYRIC**: Luôn tuân thủ Universal Cinematic Shadows (bóng đổ đa tầng màu tối sâu điện ảnh `#a6020305` và `#66000000`).
> 3. **PORTABILITY**: Không hardcode đường dẫn người dùng. Luôn dùng `Quickshell.env("HOME")` hoặc `Path.home()`.
> 4. **WAYBAR & STATUS BAR THUỘC NOCTALIA**: Tinh chỉnh thanh trạng thái Waybar/Noctalia là của repo `noctalia-shell`, không trộn lẫn vào code của FrostifyLocal.

---

## 3. Cấu Trúc Thư Mục (Repository Structure)

```
/home/apple/Applications/FrostifyLocal/
├── run.sh                          # Script khởi chạy 1-chạm (tự quét nhạc và chạy quickshell)
├── shell.qml                       # Entry point QML chính (FloatingWindow Spotify + DesktopLyricsWidget)
├── library.json                    # Dữ liệu cache danh sách bài hát, metadata và album
├── assets/                         # Font chữ Instrument Serif, icon SVG, dữ liệu tĩnh
├── backend/
│   ├── auth_server.py              # Resident HTTP daemon (port 17890) phục vụ xác thực Google & fast API
│   ├── browser_login.py            # Script hỗ trợ mở trình duyệt đăng nhập Google
│   ├── download_manager.py         # Daemon tải nhạc đa luồng (yt-dlp, FFmpeg audio 192k, ID3, socket IPC)
│   ├── library.py                  # Bộ quét thư viện nhạc (~/Music) sử dụng Mutagen
│   ├── lyrics_helper.py            # Trích xuất và phân giải file LRC (tích hợp syncedlyrics fallback)
│   ├── palette_extractor.py        # Thuật toán OKLAB Chromatic Salience Clustering
│   ├── player_daemon.py            # CLI wrapper điều khiển mpv qua /tmp/frostify_mpv.sock
│   ├── playlist_manager.py         # Quản lý danh sách phát cá nhân và danh sách phát hệ thống
│   └── ytmusic_helper.py           # Engine YouTube Music: personalized home, continuation scrapers, radio
├── components/
│   ├── AmberolDetailView.qml       # Màn hình chi tiết bài hát, đĩa xoay và lyric cuộn Amberol
│   ├── CircularSpinner.qml         # Con quay loading xoay tròn phong cách SimpMusic (270° arc Canvas)
│   ├── DesktopLyricsWidget.qml     # Widget lyric nổi trên màn hình desktop (Wayland Layer Shell)
│   ├── DownloadManager.qml         # State manager đồng bộ tác vụ tải xuống từ download_manager.py
│   ├── DownloadQueuePopover.qml    # Popover quản lý hàng đợi tải xuống Minimalist Clean (#121212)
│   ├── EnchantingSentence.qml      # Component từng câu lyric: staggered baselines, Gacha pop, đổ bóng
│   ├── HomeFeedView.qml            # Màn hình trang chủ online: Mood pills, carousels và track grids
│   ├── LibraryData.qml             # Model quản lý danh sách bài hát trong QML
│   ├── LibraryLoader.qml           # Loader nạp dữ liệu từ library.json
│   ├── ParticleBackground.qml      # Hiệu ứng hạt nền ambient
│   ├── PlayerBar.qml               # Thanh phát nhạc điều khiển cơ bản
│   ├── SettingsModal.qml           # Modal đăng nhập Google Account Dark Glass
│   ├── SpotifyHeader.qml           # Thanh tìm kiếm, tab lọc Spotify và Download pill
│   ├── SpotifyIcon.qml             # Component icon SVG độc lập (chuẩn hóa icon toàn app)
│   ├── SpotifyMainGrid.qml         # Grid danh sách bài hát, card hiển thị và nút [ ▶ Phát ] tuần tự
│   ├── SpotifyPlayerBar.qml        # Thanh phát nhạc chính Spotify (thời lượng, âm lượng, Amberol button)
│   ├── SpotifySidebar.qml          # Sidebar điều hướng [ Playlists | Queue ] hai tab tương tác
│   ├── Theme.qml                   # Hệ thống token màu, kích thước bo góc, padding
│   ├── TrackCard.qml               # Card hiển thị từng bài hát trong grid
│   ├── TrackContextMenu.qml        # Menu chuột phải Dark Glass kế thừa từ SimpMusic
│   └── TrackRow.qml                # Dòng hiển thị bài hát trong danh sách hàng đợi
├── AGENTS.md                       # File này (chỉ dẫn chuẩn dành cho AI)
└── TODO.md                         # Danh sách tính năng và lộ trình phát triển đã chốt
```

---

## 4. Công Cụ & Thư Viện Đã Được Chốt Phương Án Kỹ Thuật

1. **YouTube Music Online Streaming & Multi-Section Mood Engine (Item 8)**:
   - Thư viện: `ytmusicapi` (Python) để đăng nhập tài khoản / Visitor token, tìm kiếm bài hát và lấy playlist.
   - Trình phát: `mpv` tích hợp hook `yt-dlp` (`mpv --ytdl-format="bestaudio"`) để stream luồng âm thanh trực tiếp với dung lượng RAM tối thiểu (< 100MB RAM), không cần tải file về đĩa.
   - **Bóc Tách Continuation Shelves**: `backend/ytmusic_helper.py` dùng `_normalize_shelf_item` trích xuất cả initial shelves và continuation shelves (`sectionListContinuation`), cung cấp 10+ phân đoạn sâu (*Listen again*, *Mixed for you*, *Quick picks*, *Long listens*, *Classical for Sleeping*, v.v.) cho tất cả các mood tags (All, Sleep, Romance, Energize, Sad, Focus, Party,...).
2. **Tách Biệt Hàng Đợi Phát Nhạc & Luồng Duyệt (Decoupled Browsing vs Playback Queue)**:
   - `win.browsingTracks`: Danh sách bài hát đang hiển thị trên giao diện duyệt (kết quả tìm kiếm, tab Downloads, danh sách album).
   - `win.currentTracks`: Hàng đợi phát nhạc thực sự (Queue).
   - Duyệt tab Downloads hoặc gõ tìm kiếm không bao giờ làm gián đoạn hay ghi đè hàng đợi phát nhạc; chỉ khi người dùng click trực tiếp vào bài hát thì `win.currentTracks` mới được kích hoạt.
3. **Điều Hướng Ngang Carousel (Header Pagination Arrows `<` & `>`)**:
   - `components/HomeFeedView.qml`: Cụm nút bấm bo tròn ở góc phải tiêu đề của từng section carousel (> 4 bài).
   - Sử dụng SVG `assets/icons/go-previous-symbolic.svg` (tuyệt đối không dùng emoji).
   - Hoạt ảnh lướt mượt `NumberAnimation` (520px, cubic easing), độ mờ động thông minh (dim 0.35 ở mép giới hạn).
4. **Online Synced Lyrics Fetcher (Item 3)**:
   - Thư viện: `syncedlyrics` (Python) tự động fallback tuần tự qua các nguồn: **LRCLIB $\rightarrow$ NetEase Cloud Music $\rightarrow$ Musixmatch** khi thiếu file `.lrc` cục bộ.
5. **Trình Quản Lý Tải Nhạc Đa Luồng SimpMusic (Download Manager Daemon & Queue Popover)**:
   - Backend Daemon: `backend/download_manager.py` chạy thường trú, giao tiếp qua Unix Domain Socket (`/tmp/frostify_download.sock`) và atomic JSON (`/tmp/frostify_download_status.json`).
   - Tự động trích xuất âm thanh chất lượng cao 192k AAC/M4A qua `yt-dlp` và nhúng metadata ID3 + bìa album chất lượng cao qua FFmpeg (`-an -frames:v 1 -update 1`).
   - Tự động tải synced lyrics (`.lrc`) kèm theo vào thư mục tải về `~/Music/Downloads_Phone`.
   - Hỗ trợ đầy đủ lệnh: `enqueue`, `cancel`, `clear_completed` và phát desktop notification qua `notify-send`.
   - Frontend State: `components/DownloadManager.qml` nạp file trạng thái qua `FileView` + polling timer 250ms, cung cấp reactive property `activeTasksCount`.
   - Popover Giao Diện: `components/DownloadQueuePopover.qml` phong cách Minimalist Clean (#121212 Spotify Desktop, 8px radius, thanh progress 3px mượt mà, nút hủy từng bài, nút mở folder nhạc `~/Music/Downloads_Phone` và nút xóa bài đã tải xong kèm Tooltip chuẩn).
6. **Đồng bộ điện thoại qua ADB (Item 10)**:
   - Binary: `/home/apple/.local/bin/adb` (thiết bị `2bd3dce5` đã gắn kết nối).
   - Thư mục nguồn trên điện thoại: `/storage/emulated/0/Music/SimpMusic/`.
   - Thư mục đích trên máy tính: `~/Music/SimpMusic/Tracks/`.
   - Lệnh sync: `adb pull -a /storage/emulated/0/Music/SimpMusic/. ~/Music/SimpMusic/Tracks/`.
7. **Cấu hình & Tinh chỉnh Preset (Item 4 & 9)**:
   - File cấu hình: `~/.config/noctalia/frostify_settings.json`.
   - Lưu trữ trạng thái người dùng: `isShuffle`, `isRepeat`, preset lyrics, chế độ màu.
   - `shell.qml` nạp tự động qua `FileView` và timer `delayedSettingsRead` (100ms) để bảo đảm Quickshell async read hoàn tất trước khi parse JSON.
   - Khi click Shuffle / Repeat trong `components/SpotifyPlayerBar.qml`, chỉ phát signal `toggleShuffle()` / `toggleRepeat()` để `shell.qml` xử lý và gọi `saveSettings()`. Tuyệt đối không gán đè thuộc tính cục bộ làm phá vỡ reactive property binding.
   - Nút "MIC" đã được xóa bỏ hoàn toàn khỏi player bar để giữ giao diện tối giản chuẩn Spotify.
8. **Cơ Chế Đồng Bộ Màu Sắc Tức Thì Với Noctalia Bar (Zero-Lag Palette Sync)**:
   - File hook: `~/.config/noctalia/apply_theme.sh`.
   - `palette_extractor.py` chạy ngầm song song (`&`) ngay từ đầu để xuất `frostify_palette.json` trong ~0.3s.
   - `~/.config/quickshell/noctalia-shell/Commons/Color.qml`: `frostifyPaletteWatcher` gọi `reload()` trước và dùng `delayedFrostifyTimer` (200ms) để đọc dữ liệu khi đĩa đã nạp xong, giúp Waybar và Desktop Lyrics đổi màu đồng bộ 100% ngay từ lần đổi hình nền đầu tiên.
9. **Mã nguồn tham khảo SimpMusic**:
   - Vị trí clone: `/home/apple/Applications/SimpMusic/`.
   - Dùng để tham khảo logic Context Menu (Play Next, Add to Queue, Delete), Playback Tracking (`videostatsPlaybackUrl`, `atrUrl`, `videostatsWatchtimeUrl`) và Return YouTube Dislike API.
10. **Con Quay Loading Trực Tuyến (SimpMusic Circular Loader)**:
    - Component: `components/CircularSpinner.qml` vẽ bằng Canvas với cung tròn 270°, hai đầu bo tròn (round cap) và `RotationAnimation` vô hạn 360° (0% CPU overhead).
    - Tích hợp vào nút Play/Pause 36px trong `components/SpotifyPlayerBar.qml` qua thuộc tính `isLoadingAudio`. Khi chuyển bài hát online, icon Play/Pause tạm thời ẩn và con quay xoay mượt mà cho đến khi MPV bắt đầu đếm thời lượng phát nhạc thực tế (`time_pos > 0`).
11. **Tách Biệt Trạng Thái Duyệt Playlist & Phát Nhạc (Decoupled Playlist State)**:
    - `win.activePlaylistId`: ID danh sách đang xem trên giao diện.
    - `win.playingPlaylistId`: ID danh sách đang thực sự phát nhạc.
    - Chỉ hiển thị sóng âm Equalizer 3-bar và text xanh khi `isCurrentlyPlaying && root.isPlaying`. Người dùng bấm duyệt playlist khác sẽ không làm nhảy sóng âm sai lệch.
12. **Nút Phát Tuần Tự Toàn Bộ Bài Hát (Sequential Play All Button)**:
    - `components/SpotifyMainGrid.qml`: Thêm nút chính `[ ▶ Phát ]` bo góc tròn màu Spotify Green để bắt đầu phát playlist từ bài đầu tiên (track index 0), kết hợp cùng nút phụ `[ 🔀 Phát ngẫu nhiên ]` dạng kính mờ.
13. **Xóa Bài Hát Cục Bộ Vĩnh Viễn (Safe Permanent Local File Deletion)**:
    - Context Menu chuột phải hỗ trợ "Xóa khỏi thư viện" (`deleteTrack`). Xóa vĩnh viễn tệp âm thanh trên đĩa cứng (`os.remove`) và đồng bộ ngay vào `library.json`, ngăn chặn tình trạng bài hát xuất hiện lại sau khi khởi động lại app.

---

## 5. Quy Chuẩn Kiểm Tra Trước Khi Hoàn Thành (Mandatory Verification)

1. Cú pháp QML: `qmllint components/*.qml shell.qml` (phải đạt 0 lỗi).
2. Cú pháp Python: `python3 -m py_compile backend/*.py`.
3. Kiểm tra trực quan: Chụp màn hình bằng `/usr/bin/grim` -> xem bằng `view_file`.
4. Git push: Luôn commit và push lên `git@github.com:trancongduyhieu/FrostifyLocal.git` (nhánh `main`).
