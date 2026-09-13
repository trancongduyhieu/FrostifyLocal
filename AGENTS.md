# AGENTS.md - Nutsty Pair-Programming Guide

Tài liệu đặc tả toàn diện về kiến trúc, cấu trúc thư mục, quy chuẩn mã nguồn, các quyết định thiết kế cốt lõi và hướng dẫn vận hành dự án **Nutsty** dành cho các AI Agent / Assistant trong các session làm việc tiếp theo.

---

## 1. Tổng Quan Dự Án (Project Overview)

**Nutsty** là trình phát nhạc cục bộ và máy tính để bàn (Desktop Music & Streaming Player) được tối ưu hóa chuyên sâu cho môi trường Linux Wayland (Niri compositor), kết hợp giữa:
- **Giao diện người dùng hiện đại**: Viết bằng **Quickshell (Qt 6 / QML)** với khả năng tăng tốc GPU phần cứng và hỗ trợ native Wayland layer-shell.
- **Backend phát nhạc độ trễ thấp**: Trình điều khiển **Python IPC daemon** (`backend/player_daemon.py`) giao tiếp trực tiếp qua Unix Domain Socket (`/tmp/nutsty_mpv.sock`) với một tiến trình `mpv` chuyên biệt (hỗ trợ gapless playback, hardware decoding, flac/m4a/opus/mp3/ytdl streams).
- **Desktop Lyrics ma thuật phong cách Gacha/Anime**: Hiển thị lyric nổi trực tiếp lên hình nền desktop (tọa độ trên tà váy nhân vật/vùng hạ tiêu cự) với font chữ cổ điển *Instrument Serif*, hiệu ứng pop chữ gacha và đổ bóng điện ảnh thích ứng màu sắc hình nền.
- **Bộ máy màu sắc thích ứng Chromatic Salience (OKLAB / OKLCH)**: Trích xuất màu điểm nhấn nghệ thuật (màu tóc, má hồng, mắt, trang phục) từ hình nền hiện tại và cập nhật theo thời gian thực vào `~/.config/noctalia/nutsty_palette.json`.

---

## 2. Quy Tắc Tối Thượng Cho AI (Critical Architectural Rules)

> [!CAUTION]
> 1. **TUYỆT ĐỐI KHÔNG DÙNG EMOJI TRONG GIAO DIỆN**: Mọi nút bấm, trạng thái, modal hay icon phải dùng file SVG hoặc component icon có sẵn (`components/AppIcon.qml` hoặc `assets/icons/*.svg`). Tuyệt đối không dùng ký tự emoji (như 🎵, 📥, ⚙️, ❌) vì gây vỡ giao diện và "phèn".
> 2. **KHÔNG DÙNG VIỀN TRẮNG (WHITE HALO) CHO LYRIC**: Luôn tuân thủ Universal Cinematic Shadows (bóng đổ đa tầng màu tối sâu điện ảnh `#a6020305` và `#66000000`).
> 3. **PORTABILITY**: Không hardcode đường dẫn người dùng. Luôn dùng `Quickshell.env("HOME")` hoặc `Path.home()`.
> 4. **WAYBAR & STATUS BAR THUỘC NOCTALIA**: Tinh chỉnh thanh trạng thái Waybar/Noctalia là của repo `noctalia-shell`, không trộn lẫn vào code của Nutsty.
> 5. **RANH GIỚI NGHIÊM NGẶT GIỮA TODO.MD VÀ AGENTS.MD**:
>    - `TODO.md`: Chứa toàn bộ lộ trình (Roadmap), danh sách công việc cần làm, ý tưởng và các tính năng đang/sắp triển khai kèm checklist `[ ]` / `[x]`.
>    - `AGENTS.md`: Là cẩm nang kiến trúc và chuẩn kỹ thuật của codebase. **CHỈ CHỨA NHỮNG GÌ ĐÃ ĐƯỢC THỰC THI VÀ KIỂM CHỨNG THÀNH CÔNG** trong mã nguồn. Tuyệt đối không đưa các tính năng chưa làm (như ADB sync, các hạng mục roadmap đang chờ) vào `AGENTS.md`. Chỉ khi một tính năng trong `TODO.md` hoàn thành và verify thực tế xong, mới được ghi nhận kiến trúc vào `AGENTS.md`.
> 6. **QUY TRÌNH NGHIÊN CỨU TRƯỚC KHI THAY ĐỔI (RESEARCH WORKFLOW)**:
>    - Trước khi thêm thư viện mới, thay đổi kiến trúc hoặc áp dụng pattern mới, AI **BẮT BUỘC** phải:
>      1. Tra cứu tài liệu chính thức (`search_web`, `read_url_content`).
>      2. Đánh giá ưu/nhược điểm, hiệu năng và các giải pháp thay thế.
>      3. Khảo sát các dự án nguồn mở hàng đầu (OSS Best Practices) xem cách họ giải quyết bài toán tương tự.
>      4. Đưa ra giải pháp kỹ thuật tối ưu và trình bày rõ ràng trước khi viết mã nguồn.
> 7. **QUY TẮC CẬP NHẬT TÀI LIỆU KIẾN TRÚC BẮT BUỘC (MANDATORY ARCHITECTURE UPDATE)**:
>    - Khi có bất kỳ thay đổi nào về kiến trúc, thêm module, đổi thư viện lõi, hoặc hoàn thành một tính năng lớn từ `TODO.md`, AI **BẮT BUỘC** phải cập nhật lại tài liệu `AGENTS.md` (mô tả kiến trúc chi tiết, giải pháp kỹ thuật, cơ chế hoạt động, file liên quan và các bẫy lỗi cần tránh) kèm tóm tắt changelog.

---

## 3. Cấu Trúc Thư Mục (Repository Structure)

```
/home/apple/Applications/Nutsty/
├── run.sh                          # Script khởi chạy 1-chạm (tự quét nhạc và chạy quickshell)
├── shell.qml                       # Entry point QML chính (FloatingWindow Nutsty + DesktopLyricsWidget)
├── library.json                    # Dữ liệu cache danh sách bài hát, metadata và album
├── assets/                         # Font chữ Instrument Serif, icon SVG, dữ liệu tĩnh
├── backend/
│   ├── auth_server.py              # Resident HTTP daemon (port 17890) phục vụ xác thực Google & fast API
│   ├── browser_login.py            # Script hỗ trợ mở trình duyệt đăng nhập Google
│   ├── download_manager.py         # Daemon tải nhạc đa luồng (yt-dlp, FFmpeg audio 192k, ID3, socket IPC)
│   ├── library.py                  # Bộ quét thư viện nhạc (~/Music) sử dụng Mutagen
│   ├── lyrics_helper.py            # Trích xuất và phân giải file LRC (tích hợp syncedlyrics fallback)
│   ├── palette_extractor.py        # Thuật toán OKLAB Chromatic Salience Clustering
│   ├── player_daemon.py            # CLI wrapper điều khiển mpv qua /tmp/nutsty_mpv.sock
│   ├── playlist_manager.py         # Quản lý danh sách phát cá nhân và danh sách phát hệ thống
│   └── ytmusic_helper.py           # Engine YouTube Music: personalized home, continuation scrapers, radio
├── components/
│   ├── AmberolDetailView.qml       # Màn hình chi tiết bài hát, đĩa xoay và lyric cuộn Amberol
│   ├── AppleMusicDesktopLyrics.qml # Mẫu 2: Parametric Multi-Line Engine (5 dòng, DoF quang học, phosphor bloom)
│   ├── CircularSpinner.qml         # Con quay loading xoay tròn phong cách Nutsty (270° arc Canvas)
│   ├── DesktopLyricsWidget.qml     # Universal Lyrics Harness (Host Layer-Shell, kéo thả toàn màn hình, palette sync)
│   ├── DownloadManager.qml         # State manager đồng bộ tác vụ tải xuống từ download_manager.py
│   ├── DownloadQueuePopover.qml    # Popover quản lý hàng đợi tải xuống Minimalist Clean (#121212)
│   ├── EnchantingSentence.qml      # Component từng câu lyric: staggered baselines, Gacha pop, đổ bóng
│   ├── GachaAnimeLyricsView.qml    # Mẫu 1: Presentation view Gacha / Anime Pop (1-line Instrument Serif)
│   ├── HomeFeedView.qml            # Màn hình trang chủ online: Mood pills, carousels và track grids
│   ├── LibraryData.qml             # Model quản lý danh sách bài hát trong QML
│   ├── LibraryLoader.qml           # Loader nạp dữ liệu từ library.json
│   ├── ParticleBackground.qml      # Hiệu ứng hạt nền ambient
│   ├── PlayerBar.qml               # Thanh phát nhạc điều khiển cơ bản
│   ├── SettingsModal.qml           # Modal đăng nhập Google Account Dark Glass
│   ├── SkeletonTrackCard.qml       # Thẻ khung xương card vuông shimmer tải lười đồng bộ TrackCard (176x250)
│   ├── SkeletonTrackRow.qml        # Khung xương dòng ngang shimmer cho hàng đợi sidebar
│   ├── AppIcon.qml             # Component icon SVG độc lập (chuẩn hóa icon toàn app)
│   ├── MainTrackGrid.qml         # Grid danh sách bài hát, card hiển thị và nút [ ▶ Phát ] tuần tự
│   ├── PlayerBarBottom.qml        # Thanh phát nhạc chính Nutsty (thời lượng, âm lượng, Amberol button)
│   ├── NavSidebar.qml          # Sidebar điều hướng [ Playlists | Queue ] hai tab tương tác
│   ├── Theme.qml                   # Hệ thống token màu, kích thước bo góc, padding
│   ├── TrackCard.qml               # Card hiển thị từng bài hát trong grid
│   ├── TrackContextMenu.qml        # Menu chuột phải Dark Glass kế thừa từ Nutsty
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
5. **Trình Quản Lý Tải Nhạc Đa Luồng Nutsty (Download Manager Daemon & Queue Popover)**:
   - Backend Daemon: `backend/download_manager.py` chạy thường trú, giao tiếp qua Unix Domain Socket (`/tmp/nutsty_download.sock`) và atomic JSON (`/tmp/frostify_download_status.json`).
   - Tự động trích xuất âm thanh chất lượng cao 192k AAC/M4A qua `yt-dlp` và nhúng metadata ID3 + bìa album chất lượng cao qua FFmpeg (`-an -frames:v 1 -update 1`).
   - Tự động tải synced lyrics (`.lrc`) kèm theo vào thư mục tải về `~/Music/Downloads_Phone`.
   - Hỗ trợ đầy đủ lệnh: `enqueue`, `cancel`, `clear_completed` và phát desktop notification qua `notify-send`.
   - Frontend State: `components/DownloadManager.qml` nạp file trạng thái qua `FileView` + polling timer 250ms, cung cấp reactive property `activeTasksCount`.
   - Popover Giao Diện: `components/DownloadQueuePopover.qml` phong cách Minimalist Clean (#121212 Nutsty Desktop, 8px radius, thanh progress 3px mượt mà, nút hủy từng bài, nút mở folder nhạc `~/Music/Downloads_Phone` và nút xóa bài đã tải xong kèm Tooltip chuẩn).
6. **Cơ Chế Lưu Trữ & Đồng Bộ Trạng Thái Người Dùng (`nutsty_settings.json`)**:
   - File cấu hình: `~/.config/noctalia/nutsty_settings.json`.
   - Lưu trữ trạng thái người dùng: `isShuffle`, `isRepeat`, preset lyrics, chế độ màu.
   - `shell.qml` nạp tự động qua `FileView` và timer `delayedSettingsRead` (100ms) để bảo đảm Quickshell async read hoàn tất trước khi parse JSON.
   - Khi click Shuffle / Repeat trong `components/PlayerBarBottom.qml`, chỉ phát signal `toggleShuffle()` / `toggleRepeat()` để `shell.qml` xử lý và gọi `saveSettings()`. Tuyệt đối không gán đè thuộc tính cục bộ làm phá vỡ reactive property binding.
   - Nút "MIC" đã được xóa bỏ hoàn toàn khỏi player bar để giữ giao diện tối giản chuẩn Nutsty.
7. **Cơ Chế Đồng Bộ Màu Sắc Tức Thì Với Noctalia Bar (Zero-Lag Palette Sync)**:
   - File hook: `~/.config/noctalia/apply_theme.sh`.
   - `palette_extractor.py` chạy ngầm song song (`&`) ngay từ đầu để xuất `nutsty_palette.json` trong ~0.3s.
   - `~/.config/quickshell/noctalia-shell/Commons/Color.qml`: `frostifyPaletteWatcher` gọi `reload()` trước và dùng `delayedNutstyTimer` (200ms) để đọc dữ liệu khi đĩa đã nạp xong, giúp Waybar và Desktop Lyrics đổi màu đồng bộ 100% ngay từ lần đổi hình nền đầu tiên.
8. **Mã nguồn tham khảo Nutsty**:
   - Vị trí clone: `/home/apple/Applications/Nutsty/`.
   - Dùng để tham khảo logic Context Menu (Play Next, Add to Queue, Delete), Playback Tracking (`videostatsPlaybackUrl`, `atrUrl`, `videostatsWatchtimeUrl`) và Return YouTube Dislike API.
9. **Con Quay Loading Trực Tuyến (Nutsty Circular Loader)**:
    - Component: `components/CircularSpinner.qml` vẽ bằng Canvas với cung tròn 270°, hai đầu bo tròn (round cap) và `RotationAnimation` vô hạn 360° (0% CPU overhead).
    - Tích hợp vào nút Play/Pause 36px trong `components/PlayerBarBottom.qml` qua thuộc tính `isLoadingAudio`. Khi chuyển bài hát online, icon Play/Pause tạm thời ẩn và con quay xoay mượt mà cho đến khi MPV bắt đầu đếm thời lượng phát nhạc thực tế (`time_pos > 0`).
10. **Tách Biệt Trạng Thái Duyệt Playlist & Phát Nhạc (Decoupled Playlist State)**:
    - `win.activePlaylistId`: ID danh sách đang xem trên giao diện.
    - `win.playingPlaylistId`: ID danh sách đang thực sự phát nhạc.
    - Chỉ hiển thị sóng âm Equalizer 3-bar và text xanh khi `isCurrentlyPlaying && root.isPlaying`. Người dùng bấm duyệt playlist khác sẽ không làm nhảy sóng âm sai lệch.
11. **Nút Phát Tuần Tự Toàn Bộ Bài Hát (Sequential Play All Button)**:
    - `components/MainTrackGrid.qml`: Thêm nút chính `[ ▶ Phát ]` bo góc tròn màu Emerald Green để bắt đầu phát playlist từ bài đầu tiên (track index 0), kết hợp cùng nút phụ `[ 🔀 Phát ngẫu nhiên ]` dạng kính mờ.
12. **Xóa Bài Hát Cục Bộ Vĩnh Viễn (Safe Permanent Local File Deletion)**:
    - Context Menu chuột phải hỗ trợ "Xóa khỏi thư viện" (`deleteTrack`). Xóa vĩnh viễn tệp âm thanh trên đĩa cứng (`os.remove`) và đồng bộ ngay vào `library.json`, ngăn chặn tình trạng bài hát xuất hiện lại sau khi khởi động lại app.
13. **Hệ Thống Album Tương Tác Đa Tầng (Interactive Albums Suite - Item 7)**:
    - **Backend API**:
      - `backend/ytmusic_helper.py`: `get_album_details(browse_id)` bóc tách metadata (ID, browseId, title, artist, year, type, trackCount, duration, ảnh phân giải cao 544x544 `w544-h544-l90-rj`, description) và chuẩn hóa danh sách `tracks`. Endpoint CLI: `python3 backend/ytmusic_helper.py album <browse_id>` và `search_albums <query>`.
      - `backend/library.py`: Quét tag `album` và `year` từ ffprobe, phân nhóm album cục bộ qua `get_grouped_albums()`. Endpoint CLI: `python3 backend/library.py albums`.
    - **Giao Diện QML**:
      - `components/MainTrackGrid.qml`: Hero Album Banner với ảnh bìa 160x160, badge `ALBUM` / `SINGLE`, tiêu đề 26px đậm, phụ đề thời lượng và mô tả.
      - Toolbar cụm 4 nút: `[ ▶ Phát ]`, `[ 🔀 Phát ngẫu nhiên ]`, `[ + Hàng đợi ]`, `[ 📥 Tải Album ]`.
      - Sub-tab Switcher: `[ Bài hát (N) ]` | `[ Albums (N) ]` trong tab Downloads.
      - `components/HomeFeedView.qml`: Tự động nhận diện `type === "album"` hoặc `MPREb_` khi click card để chuyển vào chế độ xem chi tiết album.
14. **Tải Lười Dạng Khung Xương Xung Nhịp (Pure Visual Skeleton Shimmer Lazy Loading)**:
    - **Triết lý thiết kế**: Tuyệt đối không hiển thị các chuỗi text gây thô phèn như "Loading...", "Searching YouTube Music...", "Đang tạo đài phát...". Toàn bộ trạng thái chờ được thay bằng các thẻ/thanh khung xương (skeleton placeholder) với hiệu ứng xung nhịp thở mượt mà (`SequentialAnimation` độ mờ từ `0.25` sang `0.70`).
    - **Lưới chính (`MainTrackGrid.qml`)**: Sử dụng lưới `Flow` 10 thẻ card vuông `SkeletonTrackCard.qml` (176x250 px, artwork 148x148) khi `isLoading` (chuyển playlist, bấm album, tìm kiếm), bảo đảm cấu trúc layout dạng card grid chuẩn xác 1:1 với `TrackCard.qml`.
    - **Hàng đợi (`NavSidebar.qml`)**: Sử dụng `SkeletonTrackRow.qml` (dòng ngang thu nhỏ). Nhận reactive property `isLoadingRadio: radioProc.running` từ `shell.qml`. Khi click phát bài hát mới từ Home/Search, hàng đợi lập tức giữ bài hiện tại và hiển thị huy hiệu `Queue (1+)` kèm 5 dòng skeleton thu nhỏ bên dưới. Khi radio nạp xong danh sách 50 bài, các skeleton biến mất nhường chỗ cho danh sách thật mà không gây giật lag hay trống rỗng đột ngột.
15. **Bảng Điều Tra Siêu Dữ Liệu & Thông Số Kỹ Thuật Audio (Metadata & Audio Specs Inspector)**:
    - **Backend Engine**:
      - `backend/player_daemon.py`: Lệnh `audio_specs` truy xuất trực tiếp từ MPV Unix Domain Socket các trường `audio-codec-name`, `audio-bitrate`, `audio-params` (samplerate, channels) hiển thị thẻ 2x2 Dark Glass thời gian thực.
      - `backend/ytmusic_helper.py`: Lệnh `song_details <videoId|query>` tích hợp API **Return YouTube Dislike** (`https://returnyoutubedislikeapi.com/votes?videoId={videoId}`) trả về số lượt xem (`viewsStr`), lượt thích (`likesStr`), lượt không thích (`dislikesStr`), điểm đánh giá (`rating`), và tỷ lệ thích (`likeRatio`). Tự động phân giải ngược từ `Title + Artist` qua `ytm.search` đối với các file nhạc offline nội bộ.
    - **Panel QML (`AmberolDetailView.qml`)**:
      - Tab Switcher pill: `[ Lời bài hát ]` | `[ Artwork & Chi tiết ]` khi hiển thị ở chế độ compact (< 720px) và hiển thị song song hai cột khi ở chế độ mở rộng.
      - Thẻ thông số audio: CODEC, BITRATE, SAMPLE RATE, CHANNELS. Chiều cao tối ưu `96px` với lề đối xứng 12px và khoảng cách hàng 10px, đảm bảo các thông số `44.1 kHz` và `Stereo (2ch)` hiển thị cân đối hoàn hảo, không bị xệ viền.
      - Thẻ tương tác: Lượt xem (icon mắt), Lượt thích (icon like), Lượt không thích (icon dislike) kèm thanh tỷ lệ thích xanh neon (#1ed760).
      - Hộp chi tiết Album và cụm nút tương tác nhanh: `[ 📥 Tải bài / 📁 Mở thư mục ]`, `[ 📻 Radio ]`, `[ 📋 Sao chép ]`.
      - Hệ thống Icon Trắng Sáng & Zero Emoji: Toàn bộ SVG trong `assets/icons/*.svg` chuẩn hóa `fill="#ffffff"`, kết hợp `MultiEffect.brightness: 1.0` trong `components/AppIcon.qml` để mọi icon luôn hiển thị màu trắng sáng rực rỡ và dễ dàng đổi màu trên nền Dark Glass.
16. **Hệ Thống Thẻ Biểu Cảm Nutsty, Mô Tả Bài Hát & Blacklist Dislike (Nutsty Expressive Cards & Dislike Blacklist)**:
    - **Backend Innertube & Blacklist**:
      - `backend/ytmusic_helper.py`: Gọi endpoint `v1/next` của YouTube Innertube (`WEB` client) lấy nhanh (~0.2s) avatar nghệ sĩ chất lượng cao (960px), số người đăng ký kênh (`subscribers`), ngày phát hành, và toàn bộ mô tả bài hát.
      - Phân giải album: Thay thế triệt để chuỗi fallback "Nutsty", tự động phân giải tên album thực tế hoặc hiển thị "Single".
      - Blacklist lưu trữ tại `~/.config/noctalia/nutsty_disliked_songs.json`. Áp dụng `is_song_disliked()` trong `normalize_track` và `_normalize_shelf_item` để loại bỏ vĩnh viễn các bài hát bị dislike khỏi toàn bộ feed, carousel, radio và search.
      - Hành động `rate_song_action`: Đồng bộ trạng thái like/dislike về YouTube Music qua `ytmusic.rate_song`.
    - **Giao Diện QML (`AmberolDetailView.qml` & `shell.qml`)**:
      - Thẻ Nghệ Sĩ Nutsty (140px): Avatar nghệ sĩ lớn, gradient scrim, badge `Nghệ sĩ`, tên và số lượng người đăng ký.
      - Thẻ Thống Kê & Mô Tả: Ngày phát hành, số lượt xem, nút Thích (xanh Nutsty), nút Không Thích (đỏ neon), thanh tỷ lệ like neon, và khối mô tả mở rộng với nút `[ Xem thêm ▼ / Thu gọn ▲ ]`.
      - Khi bấm Không Thích: Lập tức ghi vào blacklist, loại bài khỏi `currentTracks`/`browsingTracks`, và tự động chuyển sang bài tiếp theo (`playNext()`).
17. **Màn Hình Trang Nghệ Sĩ Toàn Diện Chuẩn Nutsty (Interactive Artist Page Suite - Item 21)**:
    - **Backend Engine (`backend/ytmusic_helper.py`)**:
      - `get_artist(channel_id_or_name)` tự động phân giải tên nghệ sĩ sang browseId và bóc tách metadata (avatar phân giải cao 544x544 / 960px, subscribers, views), top bài hát phổ biến ("Phổ biến"), carousels "Albums", "Đĩa đơn & EPs", "Video âm nhạc", danh sách tròn "Nghệ sĩ liên quan", và khối tiểu sử "Giới thiệu".
      - `subscribe_artist_action(channel_id, subscribe)` tích hợp `ytmusic.subscribe_artist` / `unsubscribe_artist`.
    - **Giao Diện QML (`components/ArtistDetailView.qml` & `shell.qml`)**:
      - Top sticky bar với nút Back bo tròn `<` và navigation history stack (`artistHistoryStack`).
      - Hero Artist Header: Avatar tròn 140px cắt mặt nạ chuẩn `MultiEffect`, badge `Nghệ sĩ`, tên nghệ sĩ 32px bold, cụm 3 nút `[ 📻 Đài phát ]`, `[ 🔀 Xáo trộn ]`, `[ 👤+ Theo dõi / ✔ Đã theo dõi ]`.
      - Nút Theo dõi: Cơ chế Hybrid — lưu động vào `~/.config/noctalia/nutsty_settings.json` (`win.followedArtists`, tuyệt đối không hardcode) và đồng bộ YouTube Music nếu có tài khoản.
      - Danh sách "Phổ biến": Phát bài nạp hàng đợi `win.currentTracks`, chuột phải mở toàn diện `TrackContextMenu`.
      - Carousels ngang: Albums, Đĩa đơn & EPs, Videos, và Nghệ sĩ liên quan (avatar tròn 108px `MultiEffect`).
      - Đa điểm chạm điều hướng: Click tên nghệ sĩ trên `NutstyPlayerBar`, thẻ nghệ sĩ trong `AmberolDetailView`, "Go to artist" trong `TrackContextMenu`.
18. **Tối Ưu Avatar Nghệ Sĩ 0ms Cache & Shimmer Fallback (Item 22)**:
    - Xóa bỏ triệt để biểu thức mượn tạm ảnh bài hát `track.image` trong `AmberolDetailView.qml`.
    - Hiển thị Shimmer placeholder thở mượt mà (`SequentialAnimation` độ mờ 0.35 - 0.70) khi ảnh chưa sẵn sàng.
    - Bộ nhớ đệm avatar `~/.cache/frostify/artist_avatars.json` ánh xạ tên nghệ sĩ sang thumbnail phân giải cao; QML nạp qua `FileView` hiển thị avatar trong 0ms khi bài hát vừa bắt đầu phát.
19. **0ms State Clean Reset & Chống Rò Rỉ Trạng Thái Like/Dislike (Item 23)**:
    - Trong `AmberolDetailView.qml`, sự kiện `onTrackChanged` lập tức reset `currentLikeStatus = "INDIFFERENT"`, `songDetails = null`, `localLikesCount = 0`, `localDislikesCount = 0` ngay trong 0ms.
    - Đọc nhanh danh sách blacklist đồng bộ từ `nutsty_disliked_songs.json` qua `FileView`: Nếu bài hát mới nằm trong blacklist, lập tức sáng đỏ `DISLIKE` ngay trong 0ms; nếu không, giữ nguyên `INDIFFERENT`. Ngăn chặn hoàn toàn hiện tượng bài mới bị "dính" nút Dislike đỏ của bài trước trong thời gian chờ API.
20. **Khởi Tạo Hàng Đợi Sạch & Ngăn Chặn Auto-Play Khởi Động (Clean Queue & Cold-Start Protection)**:
    - Tuyệt đối không gán `win.currentTracks = win.allTracks` lúc khởi động trong `LibraryLoader`. Hàng đợi phát nhạc phải giữ nguyên trạng thái trống `[]` cho đến khi người dùng chủ động click chọn bài hát hoặc playlist.
    - Hàm `togglePlay()`, `playNext()`, `playPrev()` phải luôn kiểm tra `if (!win.currentTrack) return;`. Tuyệt đối không tự ý fallback về `currentTracks[0]` (bài propose trong Downloads) khi chưa có bài hát được chọn.
    - Vòng lặp Auto-advance trong `statusProcess` bắt buộc phải kèm điều kiện `win.isPlaying &&` để chỉ chuyển bài khi nhạc đang thực sự phát.
21. **Hệ Thống Đồ Họa Kính Lỏng Liquid Glass & Phong Cách Apple Music (Kế Thừa Tinh Hoa SimpMusic - Item 24)**:
    - **Kho mã nguồn tham khảo**: `/home/apple/Applications/SimpMusic/` (Jetpack Compose / Compose Multiplatform).
    - **Cơ Chế Liquid Glass (Thấu Kính Quang Học Chống Đục Trắng)**:
      - *Tệp cốt lõi*: `LiquidGlass.kt`, `LiquidGlassContainer.kt`, `LiquidGlassTabBar.android.kt`.
      - *Quy tắc Sibling*: Layer nền mang `.layerBackdrop()` và bề mặt kính mang `.drawBackdrop()` bắt buộc phải là anh em (siblings), tuyệt đối không lồng nhau để tránh render-feedback loop.
      - *Khúc xạ thấu kính lồi (Convex Lens)*: Bán kính khúc xạ khống chế dưới `size.minDimension / 2` để loại bỏ vết rãnh đen ở trục giữa viên thuốc capsule.
      - *Adaptive Scrim ("Đục Đen", Không Bị Đục Trắng)*: Giữ vibrancy (`saturation = 1.5f`, `contrast = 1f`, `brightness = 0.05f`), lấy mẫu độ sáng CIE 1931 ($0.2126R + 0.7152G + 0.0722B$) để tăng scrim tối khi nền sáng, bảo đảm chữ và icon luôn tương phản tối đa.
      - *Tương tác chạm co giãn (Spring Touch & Specular Rim)*: Khi chạm/kéo, viên thuốc co giãn đàn hồi (Spring), phát vệt sáng tâm chạm ngón tay (`radialGradient` + `BlendMode.Plus`), và bắt sáng viền mép 45° (`Highlight.Default`).
    - **Phong Cách Apple Music Now Playing Suite**:
      - *Tệp cốt lõi*: `NowPlayingContentAppleMusic.kt`, `AppleMusicShared.kt`, `AppleMusicLyricsLines.kt`.
      - *Nền Blurred Artwork + 3-Stop Gradient*: Artwork làm mờ sâu 80dp (`alpha: 0.6f`), phủ gradient 3 điểm dừng tính động từ `seedColor`: đỉnh `0.0` (tối 5%), giữa `0.48` (tối 32%), đáy `1.0` (tối 78% gần như đen ấm) giúp các nút điều khiển màu trắng luôn sắc nét.
      - *Apple Music Dock Switcher*: Đáy cố định thanh Dock 3 nút (`LYRICS` • `CAST` • `QUEUE`), hoán đổi mượt qua `Crossfade` 300ms thay vì cuộn dài.
      - *Apple Music Lyrics (Depth of Field Blur)*: Chữ lớn 28sp / 34sp leading; câu đang hát sắc nét tuyệt đối (`blur: 0, alpha: 1.0`); các câu trước và sau mờ dần bằng `blur` và `alpha` tỉ lệ thuận với khoảng cách dòng, tạo cảm giác chiều sâu trường ảnh điện ảnh.
    - **Quy Chuẩn Trình Bày Bài Hát & MV / Video**:
      - *Tệp cốt lõi*: `FullWidthItems.kt` (`SongFullWidthItems`), `AdapterItems.kt` (`HomeItemVideo`), `PlaybackIndicators.kt` (`AudioPlayingIndicator`).
      - *Quy Tắc Bo Góc Đồng Tâm (Concentric Rounded Corners)*: Bắt buộc tuân thủ công thức $R_{\text{inner}} = R_{\text{outer}} - \text{padding}$ cho mọi card bài hát, thumbnail và icon. Nếu khung ngoài bo góc 30px và khoảng cách lề (padding/border margin) là 6px thì phần tử bên trong (ảnh bìa/icon) phải bo góc chính xác $30 - 6 = 24\text{px}$, tuyệt đối không dùng bán kính bo góc tùy tiện làm vỡ đường cong đồng tâm.
      - *Sóng Equalizer 6 Cột Cyan*: `AudioPlayingIndicator` vẽ thuần trên Canvas (thay thế Lottie), 6 thanh viên thuốc dao động đối xứng từ tâm giữa (y=75), màu xanh Cyan cố định khi bài hát đang phát.

22. **Kiến Trúc Universal Lyrics Harness & Parametric Multi-Line Engine (Desktop Lyrics Architecture Suite)**:
    - **Triết Lý Thiết Kế Universal Harness & Presentation Plugins (Tách Biệt Host vs UI)**:
      - *Host Duy Nhất (`components/DesktopLyricsWidget.qml`)*: Đóng vai trò là Universal Harness quản lý tập trung toàn bộ hạ tầng:
        - Layer-shell window (`WlrLayershell.layer: WlrLayer.Bottom`),
        - Dynamic palette extraction (`nutsty_palette.json`) với `delayedPaletteTimer`,
        - Lưu trữ và đồng bộ tọa độ (`nutsty_settings.json`),
        - Vùng kéo thả toàn năng duy nhất (`universalDragArea` với `z: 100`),
        - Kéo thả tự do không rào cản (`drag.maximumX: Math.max(0, root.width - 120)`),
        - Thích ứng chiều rộng động sát mép phải (`Math.min(currentPresetMaxWidth, Math.max(120, root.width - containerBox.x))`),
        - Loại bỏ 100% tooltip, badge, hoặc viền hover nhằm bảo tồn vẻ đẹp trong suốt điện ảnh của hình nền desktop.
      - *Presentation Plugins Thuần Túy (Pure UI Views)*: Các mẫu lyric chỉ tập trung vào việc render văn bản và hiệu ứng chuyển động, hoàn toàn không chứa mã nguồn kéo thả hay lưu trữ tọa độ:
        - `components/GachaAnimeLyricsView.qml`: Mẫu 1 — Gacha / Anime Pop (1-line Instrument Serif, staggered baselines, Gacha pop và falling fade-down exit).
        - `components/AppleMusicDesktopLyrics.qml`: Mẫu 2 — Apple Music Parametric Multi-Line Engine.
      - *Mở Rộng Vô Hạn Không Lặp Code (Zero Redundant Boilerplate)*: Khi bổ sung mẫu mới (Mẫu 3, 4, 5...) trong tương lai, chỉ cần tạo file QML presentation view và gán vào Host Harness. Không bao giờ phải viết lại logic kéo thả, lưu tọa độ hay bắt biên màn hình.
    - **Cơ Chế Parametric Multi-Line & Công Thức Chiều Sâu Quang Học (Parametric DoF Engine)**:
      - Thuộc tính cấu hình số dòng: `property int visibleLinesCount: 5` (dễ dàng đổi thành 3, 5, 7 dòng mà không cần sửa cấu trúc component).
      - Tự động sinh các dòng tiếp theo bằng `Repeater` (`model: root.visibleLinesCount`), áp dụng các công thức quang học toán học liên tục theo khoảng cách dòng $s$:
        - *Độ trong suốt*: $\text{calcBaseOpacity}(s) = \max(0.08, 0.58 - 0.20 \times (s - 2))$. Slot 1 = 1.0, Slot 2 = 0.58, Slot 3 = 0.38, Slot 4 = 0.18.
        - *Độ mờ quang học*: $\text{calcBaseBlur}(s) = \min(0.95, 0.35 + 0.25 \times (s - 2))$. Slot 1 = 0.0, Slot 2 = 0.35, Slot 3 = 0.60, Slot 4 = 0.85 (tạo cảm giác xa dần vào hậu cảnh vô cực).
        - *Tỷ lệ phối cảnh*: $\text{calcBaseScale}(s) = \max(0.70, 1.0 - 0.05 - 0.09 \times (s - 2))$. Slot 1 = 1.0, Slot 2 = 1.0, Slot 3 = 0.93, Slot 4 = 0.84.
    - **Thuật Toán Perspective Scaling Tránh Giật Font (GPU Transform Origin)**:
      - Sử dụng `transformOrigin: Item.Left` kết hợp thuộc tính `scale` của QML thay vì thay đổi trực tiếp `font.pixelSize`. Điều này giúp GPU scale texture nguyên vẹn, loại bỏ triệt để hiện tượng rasterize lại font chữ gây khựng khung hình (stutter/jank).
    - **Chuyển Màu Mượt Mà Liên Tục (Color Lerp Continuity)**:
      - Khắc phục hiện tượng giật màu (color jump/flash) khi dòng 1 chuyển lên dòng 0: Thuộc tính `sungColor` nội suy mượt từ `#ffffff` về `colPendingText` thông qua `ColorAnimation` trong suốt thời gian `rollAnimation` (450ms).
    - **Phát Quang Đơn Điểm Ký Tự Karaoke (Single-Character Phosphorescent Glow)**:
      - Tại mỗi thời điểm, chỉ duy nhất ký tự/từ đang hát được kích hoạt hiệu ứng bloom sáng rực rỡ (`glowEffect`). Các từ đã hát xong giữ màu trắng tĩnh tinh khiết (`#ffffff`), các từ chưa hát mang màu xám mờ (`colPendingText`).
    - **Đồng Bộ Tọa Độ Tự Động & Đặt Lại Mặc Định Tức Thì (Reactive Auto-Reset Binding)**:
      - Tọa độ lưu bền vững vào `~/.config/noctalia/nutsty_settings.json` (`desktopLyricsCustomX`, `desktopLyricsCustomY`).
23. **Hệ Thống Lyric Tối Giản Điện Ảnh Lướt Nhòe (Minimalist Word-by-Word Motion Blur Engine - Preset 3)**:
    - **Triết Lý Thiết Kế & Cấu Trúc Bố Cục (1 Câu Chia 2 Dòng)**:
      - *Căn lề*: Căn lề trái (`anchors.left: parent.left`), tự động tách 1 câu lyric thành 2 hàng cân đối (Hàng 1: nửa đầu câu, Hàng 2: nửa sau câu).
      - *Typography*: Toàn bộ chữ thường (`toLowerCase()`), font cổ điển thơ mộng *Instrument Serif* 34px (tự động fallback sang *Noto Serif* khi có dấu tiếng Việt), màu trắng tinh khiết `#ffffff`, viền bóng điện ảnh thích ứng sâu (`colShadowDir` và `colShadowAmb`).
    - **Cơ Chế Động Lực Học Trục X (Đẩy Từ Sang Trái $X = 3 \rightarrow 2 \rightarrow 1$)**:
      - Từ đầu tiên xuất hiện ở vị trí lệch phải (`dynamicLine1ShiftX` tính theo tổng độ rộng các từ chưa xuất hiện).
      - Mỗi khi một từ mới xuất hiện theo nhịp hát, toàn bộ các từ trước trượt mượt mà sang trái (`Easing.OutCubic`, 250ms).
      - Khi Hàng 1 đã xuất hiện đủ tất cả các từ (hoặc khi bắt đầu xuống Hàng 2): Khóa cố định trục X tại $X = 0$, tuyệt đối không đẩy nữa.
    - **Cơ Chế Động Lực Học Trục Y (Đẩy Lên Hàng Trên Khi Xuống Hàng $Y = 1 \rightarrow 2$)**:
      - Ban đầu, Hàng 1 xuất hiện ở vị trí cơ sở trung tâm ($Y = 50$).
      - Khi Hàng 2 bắt đầu xuất hiện (`isLine2Active === true`): Hàng 1 được đẩy trượt mượt mà lên trên ($Y = 6$, `Easing.OutCubic`, 320ms), nhường vị trí hàng dưới ($Y = 54$) cho Hàng 2 xuất hiện từng từ.
    - **Hiệu Ứng Nhòe Chuyển Động Từng Từ (Word-by-Word Motion Blur & Ghost Streaks)**:
      - *Vệt tốc độ kép (Dual Ghost Streaks)*: Mỗi từ khi xuất hiện mang vệt lướt ngang (`x: ±streakOffset`) và trượt nhẹ 18px (`wordGlideX: 18 -> 0`).
      - *GPU Shader tối ưu 0% overhead qua `layer.effect: MultiEffect`*: Hiệu ứng nhòe chuyển động chỉ kích hoạt trong đúng 220ms của animation xuất hiện (`layer.enabled: wordBlur > 0.02`), tự động tắt hoàn toàn khi từ đã rõ nét.
    - **Chuyển Câu Dạng Trượt Cuộn Lên (400ms Slide-Up Fade Out & Reset)**:
      - Khi chuyển sang câu lyric mới, toàn bộ 2 hàng của câu cũ cùng trượt cuộn lên trên (`y: -exitProgress * 44`) kèm hiệu ứng nhòe toàn câu trong 400ms (`Easing.OutCubic`), sau đó reset lại trạng thái và bắt đầu lại chu trình cho câu tiếp theo.

24. **Công Thức Kính Lỏng Thuần Khiết SimpMusic & Floating Player Bar (SimpMusic Pure Liquid Glass - Item 24)**:
    - **Triết Lý Kiến Trúc Kính Lỏng Thuần Khiết (SimpMusic Pure Backdrop Lens Architecture)**:
      - *Mục tiêu*: Tái hiện hoàn hảo hiệu ứng kính lỏng (Liquid Glass) sóng sánh như keo nước của SimpMusic Desktop / Android trên nền Linux Wayland (Quickshell / Qt Quick RHI / GLSL 440).
      - *Cấu trúc các tệp tin liên quan (Component Files)*:
        1. `components/LiquidGlass.qml`: Harness QML đóng gói `ShaderEffectSource` bắt ảnh nền động từ `backgroundSourceItem` (`smooth: true`, `mipmap: true`, `live: true`), tự động tính toán tọa độ ánh xạ `globalOffset: root.mapToItem(backgroundSourceItem, 0, 0)` và truyền toàn bộ ma trận/uniforms vào shader.
        2. `assets/shaders/liquid_glass.frag`: Fragment shader GLSL 440 chứa thuật toán quang học đa tầng.
        3. `assets/shaders/liquid_glass.frag.qsb`: Shader nhị phân RHI biên dịch cho Qt 6 thông qua lệnh: `/usr/lib/qt6/bin/qsb --qt6 assets/shaders/liquid_glass.frag -o assets/shaders/liquid_glass.frag.qsb`.
        4. `components/PlayerBarBottom.qml`: Floating dock sử dụng `LiquidGlass` với bo góc mềm 16px, chứa mini cover, marquee title loop, cụm nút điều khiển SVG và thanh tiến trình tối giản.
        5. `shell.qml`: Khởi tạo `mainContentBackdrop` (chứa toàn bộ nội dung scrollable) và gắn làm `backgroundSourceItem` cho `PlayerBarBottom`.
      - *Khuếch tán keo nước hai tầng (Two-tier Viscous Liquid Gel Diffusion)*:
        - Lấy mẫu 2 tầng kết hợp: Tầng khí quyển rộng (Wide atmospheric bloom, Mipmap LOD 3.8 + 20px taps) chiếm 65% + Tầng định hình (Form preservation, Mipmap LOD 2.0 + 8px taps) chiếm 35%.
        - Tăng cường độ bão hòa màu 1.6x (`vibrancy`), giúp màu sắc của bìa album bên dưới tan chảy và lan tỏa mềm mại, sóng sánh như keo nước ("như keo nước").
      - *Khúc xạ thấu kính dẻo làm lan tỏa & phóng đại Avatar (Curvature Liquid Lens Displacement)*:
        - Sử dụng hàm cung tròn `circleMap(t) = 1.0 - sqrt(max(0.0, 1.0 - t * t))` kết hợp độ dịch chuyển âm (`dispAmount = -18.0px`) theo hướng pháp tuyến giải tích `gradSdRoundedRect`.
        - Kéo dãn và phóng đại các đối tượng/avatar bài hát nằm sát mép kính, tạo cảm giác hình ảnh nở bung và tan chảy vào lòng thanh player bar ("playerbar bên trong bị lan ra bởi avatar của bài hát").
      - *Thuật toán cô lập màu quang phổ & Viền phát sáng đúng màu lem (Chromatic Saturation Isolation)*:
        - Lấy mẫu trực tiếp tại mép viền (`directUV`) kết hợp màu khuếch tán (`rimSourceCol = mix(vibrantColor, directEdgeCol, 0.45)`).
        - Đo đạc độ bão hòa quang phổ: `chromaSat = (maxC - minC) / maxC` và độ sáng `chromaLum = dot(rimSourceCol, Luma)`.
        - **Loại trừ màu trắng tuyệt đối**: Ký tự chữ màu trắng (như "Replay") có `chromaSat ~ 0.0` $\rightarrow$ `isChromatic = smoothstep(0.07, 0.18, chromaSat) * smoothstep(0.04, 0.12, chromaLum) == 0.0`, viền tuyệt đối **KHÔNG BAO GIỜ bị trắng**.
        - **Phát sáng đúng màu lem**: Avatar màu tím có `chromaSat > 0.45` $\rightarrow$ `isChromatic = 1.0`, kích hoạt viền 2.2px phát sáng rực rỡ đúng màu tím neon (`pureHue = mix(chromaLum, rimSourceCol, 2.5) * 1.65`). Tương tự, card vàng viền vàng neon, card xanh viền xanh neon.
        - **Triệt tiêu 100% lỗi viền trên nền đen**: Nền đen có `chromaLum < 0.04` $\rightarrow$ `isChromatic == 0.0`, viền tối đen tuyền tuyệt đối, 4 góc hoàn toàn liền mạch không còn vệt sáng.
      - *Triệt tiêu viền giả bằng Premultiplied Alpha*:
        - Đầu ra shader bắt buộc tuân thủ chuẩn hòa trộn RHI: `fragColor = vec4(finalColor * mask, mask) * qt_Opacity`. Điều này loại bỏ hoàn toàn viền halo màu trắng/xám tại các pixel khử răng cưa ở 4 góc.
      - *Độ tối bề mặt thích ứng (Adaptive Surface Darken)*:
        - Tối nhẹ 12% trên nền đen giúp màu sắc bài hát xuyên qua rực rỡ trong vắt; tự động nâng lên tối đa 48% trên nền trắng để đảm bảo nút bấm và chữ luôn dễ đọc.
    - **Thiết Kế Thanh Player Bar SimpMusic 16dp**:
      - *Hình dạng bo góc mềm*: Bo góc vuông nhẹ `radius: 16px` (chuẩn `RoundedCornerShape(16.dp)` của SimpMusic Desktop).
      - *Hoạt ảnh Marquee Loop (Ping-Pong Animation)*: Khi tên bài hát hoặc tên ca sĩ dài vượt khung, `SequentialAnimation` trong `Item { clip: true }` tự động dừng 1.8s ở đầu $\rightarrow$ trượt mượt sang trái $\rightarrow$ dừng 1.8s ở cuối $\rightarrow$ trượt về đầu. Tuyệt đối không cắt cụt chữ bằng dấu `...`.
      - *Đồng bộ màu nghệ sĩ*: Tên nghệ sĩ có cùng màu trắng sáng với tên bài hát (`Theme.textPrimary`), khi rê chuột sáng xanh `Theme.accentGreen`.
      - *Thanh tiến trình trong suốt tối giản (100% Transparent Background Track)*:
        - `progressBg.color: "transparent"`: Xóa bỏ hoàn toàn vạch màu xám ở phần bài hát chưa chạy.
        - Chỉ hiển thị thanh màu trắng `#ffffff` thanh mảnh 2.0px (hover 3.5px) cho phần thời lượng đã phát (`elapsed progress`), giúp thanh player bar trong suốt và thanh thoát tuyệt đối.
        - Scrub handle dot 6px màu trắng và tooltip thời gian mượt mà khi hover/scrub.
    - **Bẫy Lỗi "Xương Máu" & Bài Học Tránh Lặp Lại Khi Tạo Component Liquid Glass Mới (Crucial Gotchas & Pitfalls)**:
      1. *Lỗi 4 góc và viền bị vệt sáng trắng trên nền tối (Un-premultiplied Alpha)*:
         - **Hiện tượng**: Trên nền đen, 4 góc bo của player bar xuất hiện vệt sáng mờ hoặc viền trắng trông như một miếng sticker dán đè lên.
         - **Nguyên nhân**: Qt Quick RHI (Vulkan/OpenGL) sử dụng công thức hòa trộn Premultiplied Alpha (`GL_ONE, GL_ONE_MINUS_SRC_ALPHA`). Nếu shader xuất `vec4(color, mask)` mà không nhân màu với mask, các pixel khử răng cưa ở biên sẽ bị đội độ sáng lên bất thường.
         - **Khắc phục**: Luôn luôn xuất `fragColor = vec4(finalColor * mask, mask) * qt_Opacity`.
      2. *Lỗi viền bị bắt nhầm màu trắng của chữ bên ngoài (White Text Pollution)*:
         - **Hiện tượng**: Khi thanh player bar đè lên avatar màu tím nhưng gần đó có chữ trắng (như tên bài hát, chữ "Replay"), viền trên bị biến thành màu trắng bệt thay vì phát sáng màu tím.
         - **Nguyên nhân**: Lấy mẫu biên ngoài `max(vibrantColor, edgeCol)` mà không lọc độ bão hòa, khiến màu trắng `#ffffff` của chữ đè bẹp màu tím của avatar.
         - **Khắc phục**: Đo độ bão hòa quang phổ `chromaSat = (maxC - minC) / maxC`. Chữ trắng có `chromaSat ~ 0.0` bị triệt tiêu hoàn toàn qua `isChromatic = smoothstep(0.07, 0.18, chromaSat) * smoothstep(...)`. Viền chỉ phát sáng khi tiếp xúc với màu sắc bão hòa thực sự (`chromaSat > 0.45`).
      3. *Lỗi kính bị đục đen hoặc cứng đơ không có tính dẻo ("keo nước")*:
         - **Hiện tượng**: Kính trông như một mảng nhựa đen mờ phẳng lì, khi cuộn qua album không thấy màu sắc lan tỏa hay phóng to.
         - **Nguyên nhân**: Dùng độ tối cố định quá lớn (`darken > 0.4`), thiếu thuật toán thấu kính uốn cong (`circleMap`) và chỉ dùng blur bán kính nhỏ.
         - **Khắc phục**: Áp dụng công thức SimpMusic: `darken` thích ứng từ 12% (nền đen) đến 48% (nền trắng); kết hợp khuếch tán 2 tầng (wide bloom 20px chiếm 65% + form 8px chiếm 35%) và thấu kính uốn cong âm (`dispAmount = -18.0px`) để kéo và phóng to avatar nở bung vào lòng kính.
      4. *Lỗi thanh tiến trình có vạch màu xám làm đục bề mặt kính*:
         - **Hiện tượng**: Xuất hiện một đường chỉ màu xám chạy ngang đáy thanh player bar, làm mất đi tính nguyên khối và độ trong suốt của kính.
         - **Khắc phục**: Đặt `progressBg.color: "transparent"`. Tuyệt đối không dùng bất kỳ dải màu xám nào làm nền unplayed track.
      5. *Lỗi quên biên dịch shader `.frag` ra `.frag.qsb`*:
         - **Cảnh báo**: Mọi sửa đổi trong file mã nguồn `assets/shaders/liquid_glass.frag` sẽ KHÔNG có hiệu lực trong Quickshell nếu chưa chạy lệnh biên dịch: `/usr/lib/qt6/bin/qsb --qt6 assets/shaders/liquid_glass.frag -o assets/shaders/liquid_glass.frag.qsb` và restart lại tiến trình Quickshell.
25. **Hệ Thống Nền Kính Trầm Tĩnh & Tích Hợp Niri GPU Hardware Blur (Calm Deep Acrylic Window Background Suite - Item 25)**:
    - **Triết Lý Phân Cấp Thị Giác 3 Tầng (`ui-layout-design-rules`)**:
      - *Tier 1: Primary Focal Point (10% diện tích)*: Thanh `PlayerBarBottom` lơ lửng mang hiệu ứng **Liquid Glass** cường độ cao (độ cong mép kính lồi, viền tán sắc quang phổ chromatic phát sáng theo bìa album, bão hòa 1.6x).
      - *Tier 2: Secondary / Supporting (30% diện tích)*: Các card bài hát, bìa album, danh sách hàng đợi và tab navigation.
      - *Tier 3: Tertiary / Background Canvas (60% diện tích)*: Toàn bộ nền cửa sổ `masterContainer`. **Bắt buộc phải tĩnh lặng, êm dịu và ít chi tiết hơn Player Bar rất nhiều** (`Nền < PlayerBar`) nhằm triệt tiêu hoàn toàn hiện tượng nhiễu thị giác, chống mỏi mắt và bảo đảm độ tương phản chữ (readability) đạt chuẩn WCAG AAA.
    - **Tích Hợp Niri Compositor GPU Hardware Blur**:
      - Cấu hình Wayland Niri tại `~/.config/niri/cfg/rules.kdl`:
        ```kdl
        window-rule {
            match title=r#"^Nutsty.*$"#
            open-floating true
            background-effect {
                blur true
            }
        }
        ```
      - Sử dụng trực tiếp GPU compositor của hệ điều hành Linux để khuếch tán hình nền Desktop (wallpaper) và các ứng dụng bên dưới cửa sổ với tần số quét 144Hz/120Hz mượt mà tuyệt đối, **0% CPU/GPU overhead** cho tiến trình Nutsty.
    - **Thông Số Cấu Trúc Mặt Kính Calm Deep Acrylic**:
      - `masterContainer` (`shell.qml`): `color: Qt.rgba(0.04, 0.04, 0.06, 0.74)` với đường viền siêu mảnh `border.color: Qt.rgba(1.0, 1.0, 1.0, 0.08)`, `border.width: 1`, bo góc `radius: 16px`.
      - *Ambient Edge Vignette (Spatial Depth)*: 4 dải gradient mềm mại ở 4 cạnh mép cửa sổ (đỉnh 80px `0.45`, đáy 120px `0.55` tạo nền đen sâu cho player bar lơ lửng, hai bên hông 60px `0.35`) giúp dồn tiêu điểm thị giác người dùng vào khu vực trung tâm bài hát.
      - *Quy tắc Bo góc đồng tâm (Concentric Radii)*:
        - Cửa sổ mẹ `masterContainer`: `radius: 16px`.
        - Sidebar `NavSidebar`: `radius: 12px` ($R_{\text{con}} = R_{\text{mẹ}} - \text{Padding} = 16 - 4$).
        - Card bài hát `TrackCard`: `radius: 8px`.
        - Player Bar `PlayerBarBottom`: `radius: 20px` (dạng capsule lơ lửng độc lập).
      - *Đồng bộ trong suốt các view con*:
        - `NavSidebar`: `color: Qt.rgba(0.06, 0.07, 0.09, 0.42)` + viền phân tách `1px Qt.rgba(1, 1, 1, 0.05)`.
        - `HomeFeedView` & `MainTrackGrid`: `color: "transparent"` cho phép ánh sáng mờ từ hình nền xuyên qua liền mạch giữa các card bài hát.
26. **Hệ Thống Hairline Border Đồng Tâm & Thuật Toán Khử Black Bar Video (Hairline Borders & Letterbox Auto-Zoom Suite - Item 26)**:
    - **Vấn Đề Kỹ Thuật & Hiện Tượng Lỗi Cũ (Root Cause Analysis)**:
      - *Lỗi 4 góc đen ở bài hát (ảnh 1)*: Thumbnail video ca nhạc từ YouTube (`hq720.jpg`) có tỷ lệ 16:9 (800x450 px) và thường bị đúc cứng hai dải đen letterbox (cinematic black bars) ở đỉnh và đáy (chiếm ~13% mỗi đầu). Khi đưa vào container hình vuông với `fillMode: Image.PreserveAspectCrop`, Qt Quick chỉ scale theo chiều cao (giữ nguyên dải đen ở đỉnh và đáy) và cắt hai bên hông. Do đó, khi bo góc tròn 8px, 4 góc của card bị dải đen letterbox đè lên, tạo cảm giác như lỗi render loang lổ.
      - *Lỗi Queue và Playlist thiếu border (ảnh 2, 3)*: Ở phiên bản trước, các delegate `plItem` và `qItem` trong `NavSidebar.qml` chưa được gán border (`border.width: 0`), thumbnail chỉ dùng `Rectangle { clip: true }` (vốn không bo góc được ảnh con trong Qt Quick), và ảnh con `Image { anchors.fill: parent }` đè lên hoàn toàn viền của Rectangle cha.
      - *Vệt tròn ở góc playlist Gentle Piano (ảnh 3)*: Đây thực chất là logo tròn chính thức của Spotify được nhúng sẵn ở góc trên bên trái của ảnh bìa playlist gốc từ Spotify, không phải lỗi render mã nguồn.
    - **Giải Pháp Kiến Trúc & Triển Khai Kỹ Thuật (Architecture & Implementation)**:
      - *Thuật Toán Tự Động Phóng Zoom Khử Letterbox (Letterbox Auto-Zoom)*:
        - Áp dụng trên toàn bộ ảnh thumbnail (`HomeFeedView.qml`, `TrackCard.qml`, `NavSidebar.qml`):
          ```qml
          scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.3)) ? 1.34 : 1.0
          transformOrigin: Item.Center
          ```
        - Đối với ảnh vuông chuẩn (album audio, tỷ lệ ~1.0): `scale` giữ nguyên 1.0 (sắc nét 100%, không suy hao chất lượng).
        - Đối với thumbnail video YouTube 16:9 (tỷ lệ > 1.3): tự động scale 1.34x từ tâm, đẩy toàn bộ dải đen letterbox và logo vevo ra khỏi khung hình vuông, biến thumbnail video thành ảnh chân dung album nghệ thuật hoàn hảo không tì vết.
      - *Quy Chuẩn Masking Đa Tầng MultiEffect & Overlay Hairline Border*:
        - Để bo góc ảnh chính xác và viền 1px không bao giờ bị ảnh đè:
          ```qml
          Item {
              Layout.fillWidth: true
              Layout.preferredHeight: width

              // 1. Mặt nạ trắng (BẮT BUỘC màu #ffffff để kênh luminance/alpha đạt 1.0)
              Rectangle {
                  id: coverMask
                  anchors.fill: parent
                  radius: 8
                  color: "#ffffff"
                  visible: false
                  layer.enabled: true
              }

              // 2. Container ảnh được mask qua MultiEffect
              Item {
                  anchors.fill: parent
                  layer.enabled: true
                  layer.effect: MultiEffect {
                      maskEnabled: true
                      maskSource: coverMask
                      autoPaddingEnabled: false
                  }
                  Rectangle { anchors.fill: parent; color: "#202024" }
                  Image {
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectCrop
                      scale: (implicitWidth > 0 && implicitHeight > 0 && (implicitWidth / implicitHeight > 1.3)) ? 1.34 : 1.0
                      transformOrigin: Item.Center
                  }
              }

              // 3. Viền Hairline 1px phủ lên trên cùng (z: 1)
              Rectangle {
                  anchors.fill: parent
                  radius: 8
                  color: "transparent"
                  border.color: cardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.40) : Qt.rgba(1.0, 1.0, 1.0, 0.16)
                  border.width: 1
                  z: 1
              }
          }
          ```
      - *Thống Nhất Phân Cấp Viền (Border Tokens)*:
        - **Song Card (`TrackCard` & `cCard`)**: Container có viền hover `Qt.rgba(1, 1, 1, 0.12)`, ảnh bìa có viền tĩnh `Qt.rgba(1, 1, 1, 0.16)` và viền hover `Qt.rgba(1, 1, 1, 0.40)`.
        - **Playlist Item (`plItem`)**: Container radius 8px, viền thường `0.04`, hover `0.12`, selected `0.20`. Thumbnail 38x38 radius 6px có viền hairline `0.16` (hover `0.35`).
        - **Queue Item (`qItem`)**: Container radius 8px, viền thường `0.04`, hover `0.12`, active playing `Theme.accentGreen`. Thumbnail 32x32 radius 6px có viền hairline `0.16` (hover `0.35`).

---


## 5. Quy Chuẩn Kiểm Tra Trước Khi Hoàn Thành (Mandatory Verification)

1. Cú pháp QML: `qmllint components/*.qml shell.qml` (phải đạt 0 lỗi).
2. Cú pháp Python: `python3 -m py_compile backend/*.py`.
3. Kiểm tra trực quan: Chụp màn hình bằng `/usr/bin/grim` -> xem bằng `view_file`.
4. Git push: Luôn commit và push lên `git@github.com:trancongduyhieu/Nutsty.git` (nhánh `main`).
