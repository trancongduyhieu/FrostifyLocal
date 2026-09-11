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
│   ├── SkeletonTrackCard.qml       # Thẻ khung xương card vuông shimmer tải lười đồng bộ TrackCard (176x250)
│   ├── SkeletonTrackRow.qml        # Khung xương dòng ngang shimmer cho hàng đợi sidebar
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
14. **Hệ Thống Album Tương Tác Đa Tầng (Interactive Albums Suite - Item 7)**:
    - **Backend API**:
      - `backend/ytmusic_helper.py`: `get_album_details(browse_id)` bóc tách metadata (ID, browseId, title, artist, year, type, trackCount, duration, ảnh phân giải cao 544x544 `w544-h544-l90-rj`, description) và chuẩn hóa danh sách `tracks`. Endpoint CLI: `python3 backend/ytmusic_helper.py album <browse_id>` và `search_albums <query>`.
      - `backend/library.py`: Quét tag `album` và `year` từ ffprobe, phân nhóm album cục bộ qua `get_grouped_albums()`. Endpoint CLI: `python3 backend/library.py albums`.
    - **Giao Diện QML**:
      - `components/SpotifyMainGrid.qml`: Hero Album Banner với ảnh bìa 160x160, badge `ALBUM` / `SINGLE`, tiêu đề 26px đậm, phụ đề thời lượng và mô tả.
      - Toolbar cụm 4 nút: `[ ▶ Phát ]`, `[ 🔀 Phát ngẫu nhiên ]`, `[ + Hàng đợi ]`, `[ 📥 Tải Album ]`.
      - Sub-tab Switcher: `[ Bài hát (N) ]` | `[ Albums (N) ]` trong tab Downloads.
      - `components/HomeFeedView.qml`: Tự động nhận diện `type === "album"` hoặc `MPREb_` khi click card để chuyển vào chế độ xem chi tiết album.
15. **Tải Lười Dạng Khung Xương Xung Nhịp (Pure Visual Skeleton Shimmer Lazy Loading)**:
    - **Triết lý thiết kế**: Tuyệt đối không hiển thị các chuỗi text gây thô phèn như "Loading...", "Searching YouTube Music...", "Đang tạo đài phát...". Toàn bộ trạng thái chờ được thay bằng các thẻ/thanh khung xương (skeleton placeholder) với hiệu ứng xung nhịp thở mượt mà (`SequentialAnimation` độ mờ từ `0.25` sang `0.70`).
    - **Lưới chính (`SpotifyMainGrid.qml`)**: Sử dụng lưới `Flow` 10 thẻ card vuông `SkeletonTrackCard.qml` (176x250 px, artwork 148x148) khi `isLoading` (chuyển playlist, bấm album, tìm kiếm), bảo đảm cấu trúc layout dạng card grid chuẩn xác 1:1 với `TrackCard.qml`.
    - **Hàng đợi (`SpotifySidebar.qml`)**: Sử dụng `SkeletonTrackRow.qml` (dòng ngang thu nhỏ). Nhận reactive property `isLoadingRadio: radioProc.running` từ `shell.qml`. Khi click phát bài hát mới từ Home/Search, hàng đợi lập tức giữ bài hiện tại và hiển thị huy hiệu `Queue (1+)` kèm 5 dòng skeleton thu nhỏ bên dưới. Khi radio nạp xong danh sách 50 bài, các skeleton biến mất nhường chỗ cho danh sách thật mà không gây giật lag hay trống rỗng đột ngột.
16. **Bảng Điều Tra Siêu Dữ Liệu & Thông Số Kỹ Thuật Audio (Metadata & Audio Specs Inspector)**:
    - **Backend Engine**:
      - `backend/player_daemon.py`: Lệnh `audio_specs` truy xuất trực tiếp từ MPV Unix Domain Socket các trường `audio-codec-name`, `audio-bitrate`, `audio-params` (samplerate, channels) hiển thị thẻ 2x2 Dark Glass thời gian thực.
      - `backend/ytmusic_helper.py`: Lệnh `song_details <videoId|query>` tích hợp API **Return YouTube Dislike** (`https://returnyoutubedislikeapi.com/votes?videoId={videoId}`) trả về số lượt xem (`viewsStr`), lượt thích (`likesStr`), lượt không thích (`dislikesStr`), điểm đánh giá (`rating`), và tỷ lệ thích (`likeRatio`). Tự động phân giải ngược từ `Title + Artist` qua `ytm.search` đối với các file nhạc offline nội bộ.
    - **Panel QML (`AmberolDetailView.qml`)**:
      - Tab Switcher pill: `[ Lời bài hát ]` | `[ Artwork & Chi tiết ]` khi hiển thị ở chế độ compact (< 720px) và hiển thị song song hai cột khi ở chế độ mở rộng.
      - Thẻ thông số audio: CODEC, BITRATE, SAMPLE RATE, CHANNELS. Chiều cao tối ưu `96px` với lề đối xứng 12px và khoảng cách hàng 10px, đảm bảo các thông số `44.1 kHz` và `Stereo (2ch)` hiển thị cân đối hoàn hảo, không bị xệ viền.
      - Thẻ tương tác: Lượt xem (icon mắt), Lượt thích (icon like), Lượt không thích (icon dislike) kèm thanh tỷ lệ thích xanh neon (#1ed760).
      - Hộp chi tiết Album và cụm nút tương tác nhanh: `[ 📥 Tải bài / 📁 Mở thư mục ]`, `[ 📻 Radio ]`, `[ 📋 Sao chép ]`.
      - Hệ thống Icon Trắng Sáng & Zero Emoji: Toàn bộ SVG trong `assets/icons/*.svg` chuẩn hóa `fill="#ffffff"`, kết hợp `MultiEffect.brightness: 1.0` trong `components/SpotifyIcon.qml` để mọi icon luôn hiển thị màu trắng sáng rực rỡ và dễ dàng đổi màu trên nền Dark Glass.
17. **Hệ Thống Thẻ Biểu Cảm SimpMusic, Mô Tả Bài Hát & Blacklist Dislike (SimpMusic Expressive Cards & Dislike Blacklist)**:
    - **Backend Innertube & Blacklist**:
      - `backend/ytmusic_helper.py`: Gọi endpoint `v1/next` của YouTube Innertube (`WEB` client) lấy nhanh (~0.2s) avatar nghệ sĩ chất lượng cao (960px), số người đăng ký kênh (`subscribers`), ngày phát hành, và toàn bộ mô tả bài hát.
      - Phân giải album: Thay thế triệt để chuỗi fallback "SimpMusic", tự động phân giải tên album thực tế hoặc hiển thị "Single".
      - Blacklist lưu trữ tại `~/.config/noctalia/frostify_disliked_songs.json`. Áp dụng `is_song_disliked()` trong `normalize_track` và `_normalize_shelf_item` để loại bỏ vĩnh viễn các bài hát bị dislike khỏi toàn bộ feed, carousel, radio và search.
      - Hành động `rate_song_action`: Đồng bộ trạng thái like/dislike về YouTube Music qua `ytmusic.rate_song`.
    - **Giao Diện QML (`AmberolDetailView.qml` & `shell.qml`)**:
      - Thẻ Nghệ Sĩ SimpMusic (140px): Avatar nghệ sĩ lớn, gradient scrim, badge `Nghệ sĩ`, tên và số lượng người đăng ký.
      - Thẻ Thống Kê & Mô Tả: Ngày phát hành, số lượt xem, nút Thích (xanh Spotify), nút Không Thích (đỏ neon), thanh tỷ lệ like neon, và khối mô tả mở rộng với nút `[ Xem thêm ▼ / Thu gọn ▲ ]`.
      - Khi bấm Không Thích: Lập tức ghi vào blacklist, loại bài khỏi `currentTracks`/`browsingTracks`, và tự động chuyển sang bài tiếp theo (`playNext()`).
18. **Màn Hình Trang Nghệ Sĩ Toàn Diện Chuẩn SimpMusic (Interactive Artist Page Suite - Item 21)**:
    - **Backend Engine (`backend/ytmusic_helper.py`)**:
      - `get_artist(channel_id_or_name)` tự động phân giải tên nghệ sĩ sang browseId và bóc tách metadata (avatar phân giải cao 544x544 / 960px, subscribers, views), top bài hát phổ biến ("Phổ biến"), carousels "Albums", "Đĩa đơn & EPs", "Video âm nhạc", danh sách tròn "Nghệ sĩ liên quan", và khối tiểu sử "Giới thiệu".
      - `subscribe_artist_action(channel_id, subscribe)` tích hợp `ytmusic.subscribe_artist` / `unsubscribe_artist`.
    - **Giao Diện QML (`components/ArtistDetailView.qml` & `shell.qml`)**:
      - Top sticky bar với nút Back bo tròn `<` và navigation history stack (`artistHistoryStack`).
      - Hero Artist Header: Avatar tròn 140px cắt mặt nạ chuẩn `MultiEffect`, badge `Nghệ sĩ`, tên nghệ sĩ 32px bold, cụm 3 nút `[ 📻 Đài phát ]`, `[ 🔀 Xáo trộn ]`, `[ 👤+ Theo dõi / ✔ Đã theo dõi ]`.
      - Nút Theo dõi: Cơ chế Hybrid — lưu động vào `~/.config/noctalia/frostify_settings.json` (`win.followedArtists`, tuyệt đối không hardcode) và đồng bộ YouTube Music nếu có tài khoản.
      - Danh sách "Phổ biến": Phát bài nạp hàng đợi `win.currentTracks`, chuột phải mở toàn diện `TrackContextMenu`.
      - Carousels ngang: Albums, Đĩa đơn & EPs, Videos, và Nghệ sĩ liên quan (avatar tròn 108px `MultiEffect`).
      - Đa điểm chạm điều hướng: Click tên nghệ sĩ trên `SpotifyPlayerBar`, thẻ nghệ sĩ trong `AmberolDetailView`, "Go to artist" trong `TrackContextMenu`.
19. **Tối Ưu Avatar Nghệ Sĩ 0ms Cache & Shimmer Fallback (Item 22)**:
    - Xóa bỏ triệt để biểu thức mượn tạm ảnh bài hát `track.image` trong `AmberolDetailView.qml`.
    - Hiển thị Shimmer placeholder thở mượt mà (`SequentialAnimation` độ mờ 0.35 - 0.70) khi ảnh chưa sẵn sàng.
    - Bộ nhớ đệm avatar `~/.cache/frostify/artist_avatars.json` ánh xạ tên nghệ sĩ sang thumbnail phân giải cao; QML nạp qua `FileView` hiển thị avatar trong 0ms khi bài hát vừa bắt đầu phát.
20. **0ms State Clean Reset & Chống Rò Rỉ Trạng Thái Like/Dislike (Item 23)**:
    - Trong `AmberolDetailView.qml`, sự kiện `onTrackChanged` lập tức reset `currentLikeStatus = "INDIFFERENT"`, `songDetails = null`, `localLikesCount = 0`, `localDislikesCount = 0` ngay trong 0ms.
    - Đọc nhanh danh sách blacklist đồng bộ từ `frostify_disliked_songs.json` qua `FileView`: Nếu bài hát mới nằm trong blacklist, lập tức sáng đỏ `DISLIKE` ngay trong 0ms; nếu không, giữ nguyên `INDIFFERENT`. Ngăn chặn hoàn toàn hiện tượng bài mới bị "dính" nút Dislike đỏ của bài trước trong thời gian chờ API.
21. **Khởi Tạo Hàng Đợi Sạch & Ngăn Chặn Auto-Play Khởi Động (Clean Queue & Cold-Start Protection)**:
    - Tuyệt đối không gán `win.currentTracks = win.allTracks` lúc khởi động trong `LibraryLoader`. Hàng đợi phát nhạc phải giữ nguyên trạng thái trống `[]` cho đến khi người dùng chủ động click chọn bài hát hoặc playlist.
    - Hàm `togglePlay()`, `playNext()`, `playPrev()` phải luôn kiểm tra `if (!win.currentTrack) return;`. Tuyệt đối không tự ý fallback về `currentTracks[0]` (bài propose trong Downloads) khi chưa có bài hát được chọn.
    - Vòng lặp Auto-advance trong `statusProcess` bắt buộc phải kèm điều kiện `win.isPlaying &&` để chỉ chuyển bài khi nhạc đang thực sự phát.

---

## 5. Quy Chuẩn Kiểm Tra Trước Khi Hoàn Thành (Mandatory Verification)

1. Cú pháp QML: `qmllint components/*.qml shell.qml` (phải đạt 0 lỗi).
2. Cú pháp Python: `python3 -m py_compile backend/*.py`.
3. Kiểm tra trực quan: Chụp màn hình bằng `/usr/bin/grim` -> xem bằng `view_file`.
4. Git push: Luôn commit và push lên `git@github.com:trancongduyhieu/FrostifyLocal.git` (nhánh `main`).
