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
> 8. **CHUẨN HÓA MŨI TÊN ĐIỀU HƯỚNG & CAROUSEL (`components/NavArrowButton.qml`)**:
>    - Mọi nút bấm mũi tên điều hướng, lướt ngang carousel `<` và `>` trên toàn bộ ứng dụng **BẮT BUỘC** phải dùng component chuẩn `components/NavArrowButton.qml`.
>    - Tuyệt đối không tự ý viết các khối `Rectangle` thủ công với màu xám tĩnh (`rgba(1,1,1,0.06)` hay viền chết).
>    - `NavArrowButton` tự động liên kết màu sắc động `accentColor` (đổi màu theo hình nền desktop / avatar bài hát đang phát), có hiệu ứng hover mượt mà, scale 1.06x và tự động làm mờ (`opacity: 0.28`, `enabled: false`) khi chạm giới hạn cuộn (`canScroll`).
>    - **Lưu ý**: Riêng tại trang Kết quả tìm kiếm (`CategorizedSearchView.qml`), không sử dụng các nút `< >` để giữ giao diện tối giản và tinh gọn, người dùng xem đầy đủ danh mục bằng cách chọn trực tiếp các Filter Chips ở đầu trang.
> 9. **QUY TẮC SONG NGỮ NGHIÊM NGẶT (STRICT BIMODAL LOCALIZATION - NO HYBRID SPANGLISH)**:
>    - Mọi chuỗi ký tự hiển thị trên toàn bộ giao diện (tiêu đề, nhãn, nút bấm, modal, context menu, danh mục, tooltip, trạng thái) **BẮT BUỘC** phải sử dụng qua helper `I18n.tr("Tiếng Việt", "English")` từ singleton `components/I18n.qml`.
>    - **Tuyệt đối không chèn tiếng Anh khi ở Tiếng Việt và ngược lại**:
>      - Khi `I18n.locale === "vi"`: Toàn bộ giao diện phải hiển thị 100% tiếng Việt thuần túy (*Danh sách phát*, *Hàng đợi*, *Tải xuống*, *Phát tất cả*, *Cài đặt*, *Nghe lại*, *Tuyển tập nhanh*...). Cấm để sót tiếng Anh nửa nạc nửa mỡ.
>      - Khi `I18n.locale === "en"`: Toàn bộ giao diện phải hiển thị 100% tiếng Anh chuẩn (*Playlists*, *Queue*, *Downloads*, *Play All*, *Settings*, *Listen again*, *Quick picks*...).
>    - **Quy tắc khi tạo tính năng mới**: Bất cứ khi nào tạo component, thêm màn hình, modal hay cập nhật giao diện, AI **BẮT BUỘC** cung cấp đồng thời cả 2 bản dịch tại chỗ qua `I18n.tr(vi, en)`. Không được phép chỉ viết một thứ tiếng rồi để lại TODO.
> 10. **QUY CHUẨN THIẾT KẾ MÀU SẮC NÚT BẤM (DYNAMIC CHROMATIC SALIENCE & MUTED ROSE SEMANTIC THEME - CẤM NÚT XÁM ĐEN)**:
>    - **Tuyệt đối cấm**: Không bao giờ tạo các nút bấm, pill button, selector, popover menu hay interactive controls mang màu xám đen chết (`rgba(255, 255, 255, 0.06)`, `0.08`, `#18181b`, `#27272a`) vì làm vỡ giao diện Dark Glass, gây thô ráp và tối tăm.
>    - **Chuẩn hóa màu sắc nút bấm và popover menu trên toàn bộ ứng dụng**:
>      - **Nút tương tác / Selector / Utility Controls (Dynamic Chromatic Salience)**:
>        - Hấp thụ màu sắc động `accentColor` trích xuất từ hình nền desktop / avatar bài hát đang phát (`root.accentColor` từ `nutsty_palette.json`).
>        - *Trạng thái tĩnh*: Nền kính mờ hấp thụ accent `Qt.rgba(accent.r, accent.g, accent.b, 0.12)`, viền hairline siêu mảnh 1px `Qt.rgba(accent.r, accent.g, accent.b, 0.25)`, text trắng `#ffffff`, icon và chi tiết điểm nhấn mang màu `accent`.
>        - *Trạng thái hover*: Nền sáng nhẹ `Qt.rgba(accent.r, accent.g, accent.b, 0.22)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.45)`.
>      - **Hộp thoại Popover Menu / Dropdown List**:
>        - Nền kính sẫm hữu cơ hòa quyện sắc tố accent: `Qt.rgba(0.06 + accent.r * 0.08, 0.06 + accent.g * 0.08, 0.08 + accent.b * 0.12, 0.96)`, viền hairline đồng điệu `Qt.rgba(accent.r, accent.g, accent.b, 0.35)`.
>        - Mục đang chọn (Selected Item): Nền `Qt.rgba(accent.r, accent.g, accent.b, 0.26)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.45)`, text trắng sáng kèm icon checkmark `emblem-ok-symbolic.svg` màu `accent`.
>        - Mục hover (Hovered Item): Nền `Qt.rgba(accent.r, accent.g, accent.b, 0.14)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.25)`.
>      - **Nút hành động nhạy cảm / Đăng xuất / Xóa (Destructive Muted Rose)**:
>        - Mang sắc thái đỏ nhung tinh tế (chuẩn Dark Mode Human Interface):
>        - *Trạng thái tĩnh*: Nền đỏ hoa hồng dịu `Qt.rgba(244, 63, 94, 0.12)`, viền mảnh `Qt.rgba(244, 63, 94, 0.26)`, text màu hồng đào `#fda4af`.
>        - *Trạng thái hover*: Nền đỏ hoa hồng ấm `Qt.rgba(239, 68, 68, 0.24)`, viền `Qt.rgba(239, 68, 68, 0.48)`, text trắng hồng `#ffe4e6`.
>    - **Quy Chuẩn Avatar Người Dùng**: Bắt buộc bo góc mượt mà bằng `MultiEffect` (`maskEnabled: true`), ảnh đại diện fill 100% diện tích không tạo viền đệm (moat/margin) trống gây lỗi render màu đen ở 4 góc, kết hợp viền hairline 1px trực tiếp trên mép ảnh theo công thức bo góc đồng tâm $R_{\text{trong}} = R_{\text{ngoài}} - \text{border.width}$.
>    - **Quy Chuẩn Danh Sách Hàng Đợi Tiếp Theo (Queue Track Items)**: Tuân thủ công thức bo góc đồng tâm $R_{\text{con}} = R_{\text{mẹ}} - \text{Padding}$ ($R_{\text{mẹ}} = 12\text{px}$, Padding $6\text{px}$, $R_{\text{ảnh}} = 6\text{px}$) kết hợp viền Hairline Border 1px (`rgba(1, 1, 1, 0.07)` tĩnh, `0.18` hover, `accent 0.45` bài đang phát) cho toàn bộ bài hát trên tất cả các Mood chips, có viền hairline 1px mép ảnh bìa, không để các bài khác trôi nổi không viền.

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
│   ├── NavArrowButton.qml        # Component nút mũi tên điều hướng < và > đồng bộ màu động accentColor
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
8. **Cơ Chế Bảo Toàn Danh Sách Bài Hát Album Khi Chuyển Đổi Mood Chips (Preserved Album Queue on Mood Chips)**:
   - File: `shell.qml` và `components/YTMusicNowPlayingView.qml`.
   - **Tách bạch Browsing Title và Playing Source Title**: `win.mainSectionTitle` chỉ phục vụ giao diện duyệt (browsing), trong khi `win.playingSourceTitle` đại diện cho nguồn phát thực tế (chỉ gán khi thực sự bấm phát bài hát/album/playlist/ca sĩ). Tránh triệt để race condition khi người dùng vừa nghe album 1 vừa bấm xem album 2.
   - **Cơ Chế Snapshot & Reset Queue An Toàn**:
     - Khi bắt đầu phát một bài hát/album mới (`!isAlreadyInQueue` trong `onTrackChanged` hoặc `playingPlaylistTitle` đổi), `root.originalAlbumQueue` được reset về `[]` và `root.selectedMoodIndex = 0`.
     - Ở tab "Tất cả" (`selectedMoodIndex === 0`), `originalAlbumQueue` tự động đồng bộ theo `queueTracks`.
     - Khi người dùng bấm chuyển sang mood phụ ("Khám phá", "Lãng mạn"...), `loadQueueForChipIndex` tự động snapshot toàn bộ danh sách bài hát đang hiển thị ở mood 0 vào `originalAlbumQueue` trước khi gọi API nạp radio mood.
     - Khi bấm quay lại tag "Tất cả" (`index 0`), hệ thống khôi phục ngay lập tức danh sách bài hát gốc của album vào `win.currentTracks` và phát tín hiệu `queueUpdated` mà không gọi API radio.
   - Chặn `moodChipsProc` tự động gọi `loadQueueForChipIndex` khi đang phát album/playlist để bảo đảm hàng đợi ban đầu không bị ghi đè.
9. **Cơ Chế Xuyên Thấu Hình Nền Khi Tạm Dừng & Hòa Sắc Khi Phát Nhạc (Dynamic Translucent Backdrop & Wallpaper Transparency on Pause)**:
   - File: `shell.qml` và `components/MainTrackGrid.qml`.
   - Ràng buộc cốt lõi:
     - `effectiveAccentColor`: `(win.currentTrack && win.isPlaying) ? win.songAccentColor : win.wallpaperAccentColor`
     - `playingBackdropCover.opacity`: `(win.currentTrack && win.isPlaying) ? 1.0 : 0.0` (với `duration: 400`, `Easing.InOutQuad`)
     - `fallbackPlayingImg.opacity`: `(win.currentTrack && win.isPlaying) ? 1.0 : 0.0`
     - `nutstySurfaceArtwork.opacity`: `(win.currentTrack && win.isPlaying) ? 0.70 : 0.0`
   - **Hành vi trực quan chuẩn xác**:
     - *Khi phát nhạc (`isPlaying === true`)*: Lớp backdrop tối `#0a0b0e` mờ dần hiện lên (opacity 1.0) che khuất hình nền desktop bên dưới, bung tỏa hiệu ứng velvet aurora blur từ bìa bài hát và đổi màu toàn bộ hệ thống theo `win.songAccentColor`.
     - *Khi tạm dừng / Dừng phát (`isPlaying === false`)*: Toàn bộ lớp backdrop bài hát mờ dần về `0.0` trong 400ms, đưa cửa sổ ứng dụng về trạng thái kính mờ acrylic 58% (`masterContainer color: Qt.rgba(0.04, 0.04, 0.06, 0.58)`), nhìn xuyên thấu 100% hình nền desktop bên dưới; đồng thời accent color chuyển mượt mà về màu của hình nền (`win.wallpaperAccentColor`).
   - **Bẫy lỗi tối thượng**: Tuyệt đối không được bỏ điều kiện `win.isPlaying` để thay bằng `win.currentTrack ? ... : ...`. Làm như vậy sẽ khóa chết ứng dụng ở trạng thái nền đen mờ đục và màu bài hát, làm mất tính năng xuyên thấu hình nền desktop khi tạm dừng.
   - Xóa bỏ triệt để khối gradient trắng 200px cục bộ khỏi `MainTrackGrid.qml` để bảo đảm chế độ xem Album/Playlist không bị màng sương trắng (layer 2) đè lên.
10. **Kho Mã Nguồn Tham Khảo Bên Ngoài (External Reference Repositories)**:
   - **Nutsty**: `/home/apple/Applications/Nutsty/`
     - Dùng để tham khảo logic Context Menu (Play Next, Add to Queue, Delete), Playback Tracking (`videostatsPlaybackUrl`, `atrUrl`, `videostatsWatchtimeUrl`) và Return YouTube Dislike API.
   - **SimpMusic**: `/home/apple/Applications/SimpMusic/` (Compose Multiplatform / Jetpack Compose / Skiko)
     - Dùng để tham khảo và kế thừa các thuật toán đồ họa UI/UX cao cấp:
       1. *Thuật toán Kính Lỏng Liquid Glass (Thấu kính quang học, Vibrancy 1.6x, chống đục trắng & tán sắc viền)*:
          - Tệp mẫu cốt lõi: [`composeApp/src/commonMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassContainer.kt`](file:///home/apple/Applications/SimpMusic/composeApp/src/commonMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassContainer.kt) (chứa `Modifier.liquidGlass`, `drawInteractiveGlass`, Kyant's backdrop effect stack, `colorControls`, `blur`, `lens`, `vibrancy`, adaptive darken `lerp(minScrim, maxScrim, ...)`).
       2. *Thanh điều hướng lơ lửng, viên thuốc trượt Damped Drag và chỉ báo blob đàn hồi*:
          - Tệp mẫu: [`composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassTabBar.android.kt`](file:///home/apple/Applications/SimpMusic/composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassTabBar.android.kt).
       3. *Tích hợp Mini Player và Navigation Bar trên bề mặt kính lỏng*:
          - Tệp mẫu: [`composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassAppBottomNavigationBar.android.kt`](file:///home/apple/Applications/SimpMusic/composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassAppBottomNavigationBar.android.kt).
       4. *Giao diện Apple Music Now Playing (3-stop dynamic gradient, lyric cuộn DoF quang học)*:
          - Tệp mẫu: `composeApp/src/commonMain/kotlin/com/maxrave/simpmusic/ui/screens/nowplaying/NowPlayingContentAppleMusic.kt`.
   - **liquid-glass-react**: `https://github.com/rdev/liquid-glass-react` (Apple's Liquid Glass effect by rdev / Shu Ding)
     - Dùng để tham khảo và chuyển hóa giải thuật quang học kính lỏng từ React / SVG / WebGL sang GLSL Shader Qt 6 RHI:
       1. *Signed Distance Field (SDF Rounded Box)*:
          - Tệp mẫu: `src/shader-utils.ts` (chứa `roundedRectSDF(x, y, width, height, radius)` và hàm tính mép `fragmentShaders.liquidGlass`).
          - Đo khoảng cách giải tích chính xác từ pixel đến mép bo góc để tạo mặt nạ khử răng cưa và xác định vùng khúc xạ biên.
       2. *Bẻ cong khúc xạ mép kính (Edge-Only Displacement Mapping)*:
          - Tệp mẫu: `src/shader-utils.ts` (chứa `smoothStep(0.8, 0, distanceToEdge - 0.15)`).
          - Bẻ cong và dịch chuyển tọa độ UV tại rìa kính, mô phỏng thấu kính lồi kéo dãn hình nền bên dưới.
       3. *Quang sai tán sắc quang phổ (RGB Channel Splitting / Chromatic Aberration)*:
          - Tệp mẫu: `src/index.tsx` (chứa bộ lọc SVG `<feDisplacementMap>` kết hợp `<feColorMatrix>` tách biệt 3 kênh R, G, B với tỷ lệ dịch chuyển khác nhau và hòa trộn bằng `<feBlend mode="screen">`).
          - Mô phỏng hiện tượng tán sắc lăng kính khi ánh sáng đi qua rìa mép kính bị bẻ cong lệch pha màu sắc.
       4. *Khử gờ viền sắc và làm dịu biên (Edge Softening)*:
          - Tệp mẫu: `src/index.tsx` (sử dụng Gaussian blur làm mờ nhẹ viền tán sắc để hòa quyện vào phông nền).
   - **kotlin-footguns (224 Battle-Tested Agent Skills by maxrave-dev)**: `references/kotlin-footguns/`
     - Kho tri thức 224 agent skills dạng chuẩn `SKILL.md` đúc kết từ quá trình phát triển thực chiến của SimpMusic (tác giả Max Rave). Được lưu trong thư mục `references/` (đã thêm vào `.gitignore` để không commit lên git dự án).
     - **Cách tra cứu siêu tốc cho AI**:
       - Tra cứu mục lục 1 dòng/skill tại: [`references/kotlin-footguns/CATALOG.md`](file:///home/apple/Applications/FrostifyLocal/references/kotlin-footguns/CATALOG.md).
       - Đọc file chi tiết tại: `references/kotlin-footguns/skills/<skill_name>/SKILL.md`.
     - **Các nhóm kỹ năng trọng tâm trực tiếp cho Nutsty**:
       1. *Group D (Media playback engine internals - 18 skills)*: Crossfade, DSP chain, player transitions, gapless queues, audio focus traps.
       2. *Group F (Compose theming, palette extraction & scrims - 7 skills)*: Thuật toán trích xuất bảng màu động, xử lý độ tương phản màu chữ và gradient điện ảnh.
       3. *Group Δ6 & Δ7 (Release sprint features - 84 skills)*: Word-timed lyrics (karaoke từng từ), Romanization (phiên âm Romaji/Pinyin), player styles, UI visual effects.
     - **Quy tắc thực thi**: Bất cứ khi nào gặp bài toán khó hoặc bẫy lỗi về audio buffer, crossfade, lyrics syncing hay theme palette, AI **BẮT BUỘC** mở `CATALOG.md` tra cứu và đọc `SKILL.md` liên quan trước khi triển khai.
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
21. **Hệ Thống Đồ Họa Kính Lỏng Liquid Glass & Phong Cách Apple Music (Kế Thừa SimpMusic & liquid-glass-react - Item 24)**:
    - **Kho mã nguồn tham khảo**:
      - `/home/apple/Applications/SimpMusic/` (Jetpack Compose / Compose Multiplatform / Skiko).
      - `https://github.com/rdev/liquid-glass-react` (Apple's Liquid Glass React / GLSL / SVG Filters).
    - **Cơ Chế Liquid Glass (Thấu Kính Quang Học Chống Đục Trắng & Chống Đen Ngòm)**:
      - *Tệp cốt lõi*: `LiquidGlass.kt`, `LiquidGlassContainer.kt`, `LiquidGlassTabBar.android.kt`, `assets/shaders/liquid_glass.frag`.
      - *Quy tắc Sibling*: Layer nền mang `.layerBackdrop()` và bề mặt kính mang `.drawBackdrop()` bắt buộc phải là anh em (siblings), tuyệt đối không lồng nhau để tránh render-feedback loop.
      - *Khúc xạ thấu kính lồi (Convex Lens)*: Bán kính khúc xạ khống chế dưới `size.minDimension / 2` để loại bỏ vết rãnh đen ở trục giữa viên thuốc capsule.
      - *Phương Án Chromatic Salience Ambient Glass (Kính Thích Ứng Sắc Độ Hình Nền)*:
        - **Tuyệt đối không dùng viền trắng Hairline 1px nhân tạo**: Viền trắng 1px làm khối kính trông như miếng dán sticker dán đè lên giao diện. Mép kính thực thụ phải là sự khúc xạ ánh sáng và màu sắc quang sai hữu cơ (Organic Lens Refraction) phản chiếu trực tiếp từ tranh bên dưới (`directEdgeCol` + `glowingRim`).
        - **Hấp thụ sắc độ Wallpaper (`accentColor`)**: `tintColor` gắn trực tiếp theo màu sắc trích xuất từ hình nền (`root.accentColor` từ `nutsty_palette.json`). Nền gel hữu cơ (`salienceBase`) hòa sắc giữa màu wallpaper và màu khuếch tán, nâng ngưỡng sáng tối thiểu để kính không bao giờ bị rơi về màu đen thui.
        - **Quy chuẩn xuất Alpha (Qt RHI Premultiplied Alpha Safe)**: Không để alpha quá thấp (< 0.40) vì sẽ làm màu sắc bị dìm tối khi Qt Quick render đè lên nền đen. Giữ `baseAlpha` từ `0.65` đến `0.88` để kính giữ được độ dày quang học, trong trẻo và nổi bật.
      - *Quy chuẩn Biên Dịch Shader Đa Nền Tảng (Multi-GLSL ES Baking)*:
        - Khi biên dịch shader Qt 6 cho Quickshell trên Linux Wayland (Intel/AMD/Mesa), hệ thống tìm các phiên bản GLSL ES (`300 es`, `310 es`, `320 es`, `100 es`).
        - Lệnh biên dịch chuẩn bắt buộc:
          ```bash
          /usr/lib/qt6/bin/qsb --glsl "300 es,310 es,320 es,100 es,120,150,330,440" -o assets/shaders/liquid_glass.frag.qsb assets/shaders/liquid_glass.frag
          ```
        - Không được chỉ truyền `--glsl "440,120"` vì sẽ gây lỗi crash pipeline `No GLSL shader code found` và làm kính biến thành khối đen đặc.
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

24. **Hệ Thống Kính Lỏng Đa Nền Tảng (Dual-Engine Liquid Glass: SimpMusic + liquid-glass-react) & Floating Player Bar (Item 24)**:
    - **Kho Mã Nguồn Tham Khảo & Các File Mẫu Gốc (Dual-Engine Source References)**:
      - **Nguồn 1: SimpMusic** (`/home/apple/Applications/SimpMusic/` - Jetpack Compose / Skiko):
        1. [`composeApp/src/commonMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassContainer.kt`](file:///home/apple/Applications/SimpMusic/composeApp/src/commonMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassContainer.kt):
           - Tệp mẫu quan trọng nhất. Chứa hàm `Modifier.liquidGlass(...)` và `Modifier.drawInteractiveGlass(...)`.
           - Chứa toàn bộ hiệu ứng Kyant's backdrop: `vibrancy()`, `colorControls(brightness = 0.05f, contrast = 1f, saturation = 1.5f)`, `blur(lerp(...))`, `lens(minDimension / 4f, minDimension / 2f, false)`.
           - Công thức "Đục đen" (Adaptive Scrim): `val darken = lerp(minScrim, maxScrim, ((luminance - 0.3f) / 0.5f))` — tối dần khi nền sáng để chữ trắng không bao giờ bị chìm hoặc đục trắng ("anti-white veil").
        2. [`composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassTabBar.android.kt`](file:///home/apple/Applications/SimpMusic/composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassTabBar.android.kt):
           - Thanh điều hướng capsule 3 lớp: Nền kính lỏng thích ứng độ sáng -> Blob trượt đàn hồi Damped Drag -> Ký tự/icon sắc nét trên cùng.
        3. [`composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassAppBottomNavigationBar.android.kt`](file:///home/apple/Applications/SimpMusic/composeApp/src/androidMain/kotlin/com/maxrave/simpmusic/ui/component/LiquidGlassAppBottomNavigationBar.android.kt):
           - Kỹ thuật tích hợp Mini Player và Tab Bar trên cùng một bề mặt kính lỏng không tạo viền nối.
      - **Nguồn 2: liquid-glass-react** (`https://github.com/rdev/liquid-glass-react` - Apple's Liquid Glass by rdev & Shu Ding):
        1. `src/shader-utils.ts`:
           - Giải thuật hình học giải tích Signed Distance Field: `roundedRectSDF(x, y, width, height, radius)`.
           - Hàm tính độ sâu khúc xạ mép kính: `displacement = smoothStep(0.8, 0, distanceToEdge - 0.15)`.
           - Hàm chuyển vị UV: `fragmentShaders.liquidGlass`.
        2. `src/index.tsx`:
           - Thuật toán tán sắc quang phổ phân tách 3 kênh RGB: `<feDisplacementMap>` + `<feColorMatrix>` với độ lệch scale khác nhau giữa R, G, B kết hợp `<feBlend mode="screen">`.
           - Bộ lọc làm mờ làm mềm biên: `<feGaussianBlur>` khử gờ viền tán sắc.

    - **Cấu Trúc Tệp Triển Khai Trong Nutsty / FrostifyLocal (Implementation Files)**:
      1. [`components/LiquidGlass.qml`](file:///home/apple/Applications/FrostifyLocal/components/LiquidGlass.qml): Component QML dùng chung cho toàn bộ app. Đóng gói `ShaderEffectSource` bắt ảnh nền động từ `backgroundSourceItem` (`smooth: true`, `mipmap: true`, `live: true`), tự động tính toán tọa độ ánh xạ `globalOffset: root.mapToItem(backgroundSourceItem, 0, 0)` và truyền toàn bộ ma trận/uniforms vào shader.
      2. [`assets/shaders/liquid_glass.frag`](file:///home/apple/Applications/FrostifyLocal/assets/shaders/liquid_glass.frag): Fragment shader GLSL 440 chứa thuật toán quang học đa tầng (SDF Rounded Box, Circle Map Displacement, 2-tier Viscous Gel Diffusion, Chromatic Saturation Isolation, Adaptive Darken).
      3. `assets/shaders/liquid_glass.frag.qsb`: File bytecode nhị phân Qt 6 RHI được biên dịch từ `liquid_glass.frag`.
      4. [`components/PlayerBarBottom.qml`](file:///home/apple/Applications/FrostifyLocal/components/PlayerBarBottom.qml): Tệp mẫu thực tế số 1 — Thanh phát nhạc lơ lửng bo góc mềm 16px sử dụng `LiquidGlass`.
      5. [`components/TopHeaderBar.qml`](file:///home/apple/Applications/FrostifyLocal/components/TopHeaderBar.qml): Tệp mẫu thực tế số 2 — Cụm viên thuốc điều hướng và thanh tìm kiếm sử dụng `LiquidGlass`.
      6. [`shell.qml`](file:///home/apple/Applications/FrostifyLocal/shell.qml): Khởi tạo `id: mainContentBackdrop` (chứa toàn bộ nội dung cuộn bên dưới) và truyền vào làm `backgroundSourceItem` cho các component nổi.

    - **Cẩm Nang Thực Hành: Hướng Dẫn Từng Bước Áp Dụng Liquid Glass Cho Mọi Component Mới**:
      - **Bước 1: Nắm vững quy tắc Sibling bất biến (The Golden Sibling Rule)**:
        - Bề mặt kính `LiquidGlass` và layer nền `backgroundSourceItem` **BẮT BUỘC PHẢI LÀ ANH EM (SIBLINGS)** hoặc overlay ở tầng Z cao hơn (`z: 50`).
        - **TUYỆT ĐỐI KHÔNG** đặt component chứa `LiquidGlass` vào bên trong chính item mà `backgroundSourceItem` trỏ tới. Việc này sẽ khiến `ShaderEffectSource` bắt lại chính nó, tạo thành vòng lặp vô tận (render-feedback loop) gây sập engine đồ họa hoặc xuất hiện lỗi đen kịt toàn màn hình.
      - **Bước 2: Mẫu Code QML Chuẩn (Copy-Pasteable Template)**:
        ```qml
        import QtQuick
        import QtQuick.Layouts
        import "." // hoặc import "./components" nếu gọi từ file gốc shell.qml

        Item {
            id: root
            property Item backgroundSourceItem: null // nhận từ shell.qml (thường là mainContentBackdrop)
            property real radius: 16

            // Khối Liquid Glass lót nền
            LiquidGlass {
                id: glassDock
                anchors.fill: parent
                radius: root.radius
                displacement: 18.0    // Độ phóng đại thấu kính uốn cong
                aberration: 0.03      // Độ tán sắc viền quang sai
                bevelWidth: 24.0      // Độ rộng vát mép
                tintColor: Qt.rgba(0.04, 0.05, 0.07, 0.65) // Nền tối chống đục trắng
                backgroundSourceItem: root.backgroundSourceItem
                z: 2

                // Toàn bộ nội dung con (Layout, text, icon, button) đặt tự nhiên bên trong
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    // Nội dung hiển thị sắc nét 100% trên bề mặt kính lỏng
                }
            }
        }
        ```
      - **Bước 3: Bảng Tra Cứu Thông Số Kỹ Thuật (Parameter Cheat Sheet)**:
        | Thông Số | Player Bar / Dock Lớn | Pill Switch / Nút Bấm | Modal / Popover / Bento Card | Ý Nghĩa Kỹ Thuật |
        |---|---|---|---|---|
        | `radius` | `16` | `18` (Capsule $H/2$) | `12` - `16` | Bán kính bo góc ngoài của khối kính |
        | `displacement` | `18.0` | `5.0` - `6.0` | `8.0` - `12.0` | Độ kéo dãn & phóng đại thấu kính âm (pulling & magnifying avatar) |
        | `bevelWidth` | `24.0` | `6.0` - `8.0` | `12.0` - `16.0` | Bề rộng mép vát cong uốn lượn quang học |
        | `aberration` | `0.03` | `0.02` | `0.03` | Độ tán sắc quang phổ viền đỏ-xanh |
        | `tintColor` | `Qt.rgba(0.04, 0.05, 0.07, 0.65)` | `Qt.rgba(0.08, 0.08, 0.10, 0.70)` | `Qt.rgba(0.06, 0.07, 0.09, 0.55)` | Màu nền tối thích ứng ("đục đen"), giữ tương phản chữ |
      - **Bước 4: Quy trình biên dịch Shader bắt buộc khi chỉnh sửa file GLSL**:
        - Mọi thay đổi trong `assets/shaders/liquid_glass.frag` **BẮT BUỘC** phải được biên dịch lại sang nhị phân Qt 6 RHI:
          ```bash
          /usr/lib/qt6/bin/qsb --qt6 assets/shaders/liquid_glass.frag -o assets/shaders/liquid_glass.frag.qsb
          ```
        - *Lưu ý sống còn*: Quickshell nạp file bytecode `.frag.qsb`. Nếu sửa file `.frag` mà quên chạy lệnh `qsb`, giao diện sẽ tiếp tục chạy shader cũ và không có bất kỳ thay đổi nào hiển thị.

    - **Nguyên Lý Quang Học Cốt Lõi: Sự Kết Tinh Giữa liquid-glass-react & SimpMusic (Dual-Engine Optical Principles)**:
      - **1. Đóng Góp Từ liquid-glass-react (Apple VisionOS / React GLSL by rdev & Shu Ding)**:
        - *Hình học giải tích SDF Rounded Box (`sdRoundedBox`)*: Sử dụng hàm khoảng cách có dấu chuẩn xác của Inigo Quilez. Đo khoảng cách âm từ pixel tới mép biên (`distInside = -d`), tạo mặt nạ khử răng cưa mượt mà (`smoothstep(-edgeWidth, edgeWidth, d)`) và xác định chính xác độ sâu khúc xạ `refrHeight`.
        - *Khúc xạ mép biên chọn lọc (Edge-Only Displacement Mapping)*: Khúc xạ chỉ xảy ra ở viền ngoài (`distInside < bevelWidth`), giữ cho 90% diện tích lòng kính phẳng và trong suốt, bảo đảm các nút bấm, ảnh avatar và thông tin bài hát không bị biến dạng.
        - *Tán sắc quang phổ quang học (Chromatic Aberration Dispersion)*: Tham số `u_aberration` mô phỏng hiện tượng lăng kính tách ánh sáng trắng thành các vệt quang phổ RGB lệch pha khi đi qua mép vát của thấu kính cong.
      - **2. Đóng Góp Từ SimpMusic (Compose Multiplatform / Skiko by maxrave-dev)**:
        - *Khuếch tán keo nước hai tầng (Two-tier Viscous Liquid Gel Diffusion)*: Lấy mẫu 2 tầng kết hợp: Tầng khí quyển rộng (Wide atmospheric bloom, Mipmap LOD 3.8 + 20px taps) chiếm 65% + Tầng định hình (Form preservation, Mipmap LOD 2.0 + 8px taps) chiếm 35%. Giúp màu sắc bìa album bên dưới tan chảy và lan tỏa sóng sánh như một lớp keo nước đặc trong lòng kính.
        - *Khúc xạ thấu kính dẻo làm lan tỏa & phóng đại Avatar (Curvature Liquid Lens Displacement)*: Sử dụng hàm cung tròn `circleMap(t) = 1.0 - sqrt(max(0.0, 1.0 - t * t))` kết hợp độ dịch chuyển âm (`dispAmount = -18.0px`) theo hướng pháp tuyến giải tích, kéo dãn và phóng to avatar bài hát nằm sát mép kính nở bung vào lòng thanh player bar ("playerbar bên trong bị lan ra bởi avatar của bài hát").
        - *Tăng cường độ rực màu Vibrancy 1.6x*: Đẩy bão hòa màu sắc của bìa album bên dưới (`saturation 1.6x` + nâng nhẹ độ sáng luma) giúp kính không bao giờ bị xỉn màu.
        - *Độ tối bề mặt thích ứng (Adaptive Surface Darken / Scrim)*: Tối nhẹ 12% trên nền đen giúp màu sắc bài hát xuyên qua rực rỡ trong vắt; tự động nâng lên tối đa 48% trên nền trắng để đảm bảo nút bấm và chữ luôn dễ đọc, chống hiện tượng đục trắng ("anti-white veil").
      - **3. Cải Tiến Độc Quyền Của Nutsty Dành Riêng Cho Linux Wayland / Qt 6 RHI**:
        - *Pháp tuyến giải tích mịn màng (`gradSdRoundedRect`)*: Thay thế hoàn toàn phép xấp xỉ vi phân hữu hạn bằng đạo hàm giải tích của hình chữ nhật bo góc, loại bỏ 100% hiện tượng rung giật số và răng cưa mép tại 4 góc bo.
        - *Thuật toán cô lập màu quang phổ & Viền phát sáng đúng màu lem (Chromatic Saturation Isolation)*:
          - Lấy mẫu trực tiếp tại mép viền (`directUV`) kết hợp màu khuếch tán (`rimSourceCol = mix(vibrantColor, directEdgeCol, 0.45)`).
          - Đo đạc độ bão hòa quang phổ: `chromaSat = (maxC - minC) / maxC` và độ sáng `chromaLum = dot(rimSourceCol, Luma)`.
          - **Loại trừ màu trắng tuyệt đối**: Ký tự chữ màu trắng (như "Replay") có `chromaSat ~ 0.0` -> `isChromatic == 0.0`, viền tuyệt đối **KHÔNG BAO GIỜ bị trắng**.
          - **Phát sáng đúng màu lem**: Avatar màu tím có `chromaSat > 0.45` -> `isChromatic = 1.0`, kích hoạt viền 2.2px phát sáng rực rỡ đúng màu tím neon (`pureHue = mix(chromaLum, rimSourceCol, 2.5) * 1.65`). Tương tự, card vàng viền vàng neon, card xanh viền xanh neon.
          - **Triệt tiêu 100% lỗi viền trên nền đen**: Nền đen có `chromaLum < 0.04` -> `isChromatic == 0.0`, viền tối đen tuyền tuyệt đối, 4 góc hoàn toàn liền mạch không còn vệt sáng.
        - *Triệt tiêu viền giả bằng Premultiplied Alpha RHI*: Đầu ra shader bắt buộc tuân thủ chuẩn hòa trộn RHI: `fragColor = vec4(finalColor * glassAlpha, glassAlpha) * qt_Opacity`. Điều này loại bỏ hoàn toàn viền halo màu trắng/xám tại các pixel khử răng cưa ở 4 góc bo trên nền tối.

    - **Thiết Kế Thanh Player Bar SimpMusic 16dp (`PlayerBarBottom.qml`)**:
      - *Hình dạng bo góc mềm*: Bo góc vuông nhẹ `radius: 16px` (chuẩn `RoundedCornerShape(16.dp)` của SimpMusic Desktop).
      - *Hoạt ảnh Marquee Loop (Ping-Pong Animation)*: Khi tên bài hát hoặc tên ca sĩ dài vượt khung, `SequentialAnimation` trong `Item { clip: true }` tự động dừng 1.8s ở đầu $\rightarrow$ trượt mượt sang trái $\rightarrow$ dừng 1.8s ở cuối $\rightarrow$ trượt về đầu. Tuyệt đối không cắt cụt chữ bằng dấu `...`.
      - *Đồng bộ màu nghệ sĩ*: Tên nghệ sĩ có cùng màu trắng sáng với tên bài hát (`Theme.textPrimary`), khi rê chuột sáng theo `root.accentColor`.
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

27. **Tối Ưu Khử Viền Trắng Nghệ Sĩ, Khắc Phục Lỗi Render Góc Thumbnail & Liquid Glass Toàn Màn Hình (Item 27)**:
    - **Khử Viền Trắng Trang Nghệ Sĩ (`ArtistDetailView.qml`)**:
      - Xóa bỏ toàn bộ viền trắng tĩnh xung quanh bài hát phổ biến, album, đĩa đơn & EP, và video âm nhạc (MV) trên trang nghệ sĩ. Các thẻ card chuyển sang phong cách tối giản phẳng (frameless clean glass) chỉ sáng nền nhẹ khi di chuột hover (`Qt.rgba(1.0, 1.0, 1.0, 0.08)`), bảo đảm giao diện sang trọng, không bị chia ô thô cứng.
      - Nền trang nghệ sĩ chuyển hoàn toàn sang `color: "transparent"` để kế thừa lớp kính Acrylic mờ đục của cửa sổ chính thay cho dải gradient tối trước đó.
    - **Khắc Phục Triệt Để Vệt Đen 4 Góc Thumbnail (Letterbox Scale 1.48 & Concentric Mask)**:
      - Tỷ lệ zoom ảnh thumbnail YouTube 16:9 (`hqdefault.jpg`) nâng từ `1.34` lên `1.48`, loại bỏ 100% dải đen letterbox ở trên/dưới ảnh để góc bo tròn không bao giờ bị cắt dính viền đen.
      - Lớp nền placeholder `#202024` trong item mask được ẩn khi ảnh đã tải xong (`visible: !img.visible || img.status !== Image.Ready`), ngăn chặn hiện tượng viền đen lem qua đường cong antialiasing.
      - Bán kính mask được tính toán đồng tâm chuẩn xác: \(R_{\text{mask}} = R_{\text{outer}} - 1\).
    - **Liquid Glass Alpha Tự Thích Ứng & Nút Maximize Cửa Sổ Chuẩn Wayland (`liquid_glass.frag` & `TopHeaderBar.qml`)**:
      - `liquid_glass.frag`: Sửa công thức alpha và hòa trộn nền `baseGlass = mix(u_tint.rgb, tintedArtwork, artworkPresence)`. Khi thanh phát nhạc trôi trên vùng trống/trong suốt (`lum = 0`), shader xuất alpha mờ đục `u_tint.a` thay vì xuất đen kịt `vec4(..., 1.0)`.
      - Nút Phóng To / Khôi Phục `[ ◻ ]` (`window-maximize-symbolic.svg`): Tích hợp vào `TopHeaderBar.qml` và phím tắt `F11` gọi `win.maximized = !win.maximized`. Tránh kích hoạt chế độ `fullscreen-window` của Niri (vốn tạo phông nền đen đặc sau cửa sổ), giữ trọn vẹn khả năng nhìn xuyên thấu hình nền desktop qua hiệu ứng kính Acrylic.

28. **Hệ Thống Lời Bài Hát Tràn Viền Phong Cách SimpMusic, Karaoke Từng Từ Độc Lập & Bokeh Quang Học Đa Tầng (SimpMusic-Style Frameless Lyrics, Word-by-Word Karaoke & Deep Optical Bokeh - Item 28)**:
    - **Xóa Bỏ Khung Viền Thô Cứng & Dải Chắn Đen Trên/Dưới**:
      - `components/AmberolDetailView.qml`: Chuyển đổi container lyrics từ `Rectangle` viền thô sang layout tràn viền trong suốt hoàn toàn (`Item`).
      - Xóa bỏ dòng tiêu đề "LYRICS ... lines synced" và hai dải gradient tối đè trên/dưới, giúp các dòng lyric trôi tự do tràn viền.
      - Xóa bỏ thanh chỉ báo xanh lá cây (`Theme.accentGreen`) cạnh câu hát hiện tại, nhường trọn sự tập trung vào hiệu ứng phát sáng của con chữ.
    - **Engine Karaoke Từng Từ Độc Lập (Word-by-Word RichText Formatting)**:
      - Khắc phục triệt để lỗi va chạm bounding box: Khi một câu hát dài tự động rớt dòng (wrapped lines), kỹ thuật clip 2D cũ (`clip: true; width: parent.width * progress`) khiến cả dòng 1 và dòng 2 cùng sáng lên tại một tọa độ X.
      - Chuyển sang kiến trúc định dạng HTML RichText (`formatKaraokeWords(rawText, progress)`): Phân tách từng từ trong câu theo trật tự đọc, từ đã hát sáng trắng `#ffffff`, từ đang hát chuyển tiếp mượt mà từ xám `#757a88` sang trắng tinh, từ chưa hát giữ màu xám thanh lịch. Tự nhiên thích ứng với mọi độ dài câu hát và số dòng rớt xuống.
    - **Hiệu Ứng Bokeh Quang Học Chiều Sâu (Deep Optical Bokeh Fallback)**:
      - Tích hợp `MultiEffect` trên từng dòng lời bài hát với độ mờ quang học theo khoảng cách (`blurMax: 48`):
        - Dòng hiện tại (\(dist = 0\)): Cỡ chữ 28px bold, nét căng, độ mờ 0.
        - Dòng kề cận (\(dist = 1\)): Cỡ chữ 24px, độ mờ nhẹ `0.35`, độ đục `0.45`.
        - Dòng cách xa (\(dist = 2\)): Cỡ chữ 21px, độ mờ trung bình `0.70`, độ đục `0.18`.
        - Dòng rất xa (\(dist \ge 3\)): Cỡ chữ 18px, độ mờ sâu cực đại `1.0`, độ đục `0.08` tan biến vào nền bokeh.
        - Tương tác Hover: Khi di chuột lên bất kỳ dòng nào, blur lập tức về `0.0` và độ đục lên `0.95` phục vụ click-to-seek trực quan.
    - **Nền Ambient Album Artwork Bokeh Mềm Mại (Deep Velvet Bokeh Background)**:
      - Ảnh bìa album nền chuyển sang `MultiEffect` với `blur: 1.0`, `blurMax: 64`, `saturation: 1.5`, `opacity: 0.52`, hòa cùng dải vignette tối sâu, xóa bỏ hoàn toàn các cạnh biên sắc nét của ảnh gốc.
    - **Khắc Phục Màn Hình Đen Khi Bấm `Shift+F11` (Niri Maximize-Window-To-Edges)**:
      - Hành động `fullscreen-window` của Niri compositor luôn vẽ một phông nền đen đặc sau cửa sổ để phục vụ trình phát video, làm mất hoàn toàn hiệu ứng kính xuyên thấu.
      - Chuyển phím tắt `Shift+F11` sang `maximize-window-to-edges;` trong `~/.config/niri/cfg/keybinds.kdl` và khai báo `Shortcut { sequences: ["F11", "Shift+F11"] }` trong `shell.qml`, cho phép mở rộng cửa sổ tối đa sát mép màn hình mà vẫn giữ trọn vẹn lớp kính Acrylic nhìn thấu hình nền.

29. **Hệ Thống Cuộn Mượt Kinetic Web-like, Dynamic Chromatic Salience & Bento Glass Inspector (Item 29)**:
    - **Cuộn Lời Bài Hát Mượt Mà Chuẩn Web (Kinetic Web-Like Lyric Scrolling)**:
      - Loại bỏ triệt để hiện tượng giật cục/dịch chuyển tức thời (teleporting jump) do gọi trực tiếp `positionViewAtIndex` khi phát nhạc.
      - Chuyển sang cơ chế dynamic highlight indexing: Trong `updateActiveLyric(forceScroll)`, chỉ cập nhật `lyricsView.currentIndex = found`, kích hoạt engine nội suy chuyển động của Qt Quick với `highlightRangeMode: ListView.StrictlyEnforceRange`, `highlightMoveDuration: 600`, và `highlightMoveVelocity: -1`. Lời bài hát lướt êm ái, mượt mà như cuộn trang web hiện đại.
      - Ẩn hoàn toàn thanh cuộn dọc (`ScrollBar.vertical`) trên cả hai tab Lyrics và Artwork, tạo thẩm mỹ tối giản, sạch sẽ tuyệt đối.
    - **Header Tinh Gọn 1 Dòng & Trả Lại Không Gian Thở Cho Lời Hát**:
      - Xóa bỏ `RowLayout` phụ (chiều cao 56px) vốn chứa thumbnail mini trùng lặp và tên nghệ sĩ màu xanh lá, giải phóng hoàn toàn không gian phía trên.
      - Tích hợp tên bài hát (13px bold) và nghệ sĩ (11px, màu trắng/slate thanh nhã `rgba(255, 255, 255, 0.65)`) trực tiếp vào thanh Top Bar cạnh nút Back.
      - Đặt `topMargin: 32` và `bottomMargin: height * 0.45` cho `lyricsView`, đảm bảo các câu hát trên cùng không bao giờ bị cắt cụt hay dính sát vào mép header.
    - **Xóa Bỏ Triệt Để Màu Xanh Lá Cây & Chuyển Sang Dynamic Chromatic Salience**:
      - Loại bỏ 100% màu xanh neon `#1ed760` / `Theme.accentGreen` trên toàn bộ Player Bar và Amberol Details View (nút Shuffle, Repeat, Volume scrub, Like ratio bar, nút "Xem thêm ▼", icon album và tên nghệ sĩ).
      - Đồng bộ động với màu điểm nhấn hình nền (`accentColor` lấy từ `~/.config/noctalia/nutsty_palette.json` -> `highlightColor` / `accentColor` thông qua `FileView` và timer 80ms/100ms trên cả `shell.qml` và `components/AmberolDetailView.qml`).
      - Pill Switch `[ Lyrics | Artwork ]`: Thiết kế lại thành khoang con nhộng kính mờ Acrylic cao cấp (`Qt.rgba(1, 1, 1, 0.16)` với viền `Qt.rgba(root.accentColor, 0.40)` khi active, không còn xanh lá).
    - **Tái Thiết Kế Tab Artwork & Inspector Thành Bento Glass Đẳng Cấp**:
      - Loại bỏ hoàn toàn các khối hộp đen kịt thô ráp (`#161618`, `#28282c`).
      - Áp dụng triết lý Bento Glass với độ trong suốt tinh tế: `color: Qt.rgba(1, 1, 1, 0.04)`, viền `border.color: Qt.rgba(1, 1, 1, 0.08)`, bo góc đồng tâm \(R = 12\) - \(16\).
      - Thẻ thông số Audio Specs (CODEC, BITRATE, SAMPLE RATE, CHANNELS) và thẻ Album/Single tinh gọn, tỷ lệ hiển thị cân đối 96px, font chữ sắc nét không bị tràn lề.
      - Tương tác Like/Dislike mượt mà với thanh tỷ lệ like neon chuyển sang màu `accentColor` đồng bộ hoàn hảo với hình nền.
29. **Kiến Trúc Giao Diện YouTube Music Now Playing & Điều Hướng Header Liquid Glass (Item 30)**:
    - **Triết Lý Thiết Kế Bố Cục Tách Đôi 50/50 (Split-Screen Now Playing Architecture)**:
      - *Component cốt lõi*: `components/YTMusicNowPlayingView.qml` kết hợp `shell.qml`.
      - *Cột Trái (Left Area - 46%)*:
        - Mode Switcher Pill `[ Bài hát | Video ]`: Viên nang Liquid Glass khúc xạ thấu kính GPU (`displacement: 5.0`, `bevelWidth: 6.0`, `radius: 18px`), chuyển đổi tức thì giữa chế độ ảnh bìa tĩnh và luồng video in-app nhúng từ YouTube.
        - Ảnh bìa lớn tỷ lệ 1:1 cắt bo góc mềm mại 18px, lớp phủ phát quang ambient blur từ bìa album phía sau (`MultiEffect` blur: 1.0, blurMax: 64, saturation: 1.4).
        - Trình phát Video In-App: `MediaPlayer` + `VideoOutput` (`muted: true` để không xung đột luồng âm thanh bit-perfect từ MPV daemon), phân giải URL video trực tiếp qua `ytmusic_helper.py get_url <videoId>`.
        - Khối thông tin: Tên bài hát (22px bold, text `#ffffff`), nghệ sĩ, cụm 4 nút **Pure Frameless Icons** (`Like`, `Dislike`, `Download`, `Plus`) xóa bỏ hoàn toàn viền xám thô, khối capsule và dải phân cách 1px, hỗ trợ phản hồi micro-glow hover mềm mại (`Qt.rgba(1, 1, 1, 0.08)`) và scale 1.10x êm ái.
      - *Cột Phải (Right Area - 54%)*:
        - Thanh điều hướng 3 tab: `[ UP NEXT | LYRICS | RELATED ]` với vạch chỉ báo trượt mượt mà theo `accentColor`.
        - *Tab 1 - UP NEXT*: Hiển thị danh sách hàng đợi đang phát `win.currentTracks`, sóng âm Equalizer 3 thanh dao động cạnh bài đang chạy, chuột phải mở toàn diện `TrackContextMenu`.
        - *Tab 2 - LYRICS*: Engine kinetic scrolling DoF với chữ đang hát trắng sáng tuyệt đối 28px bold ở tâm quang học, các câu trước/sau mờ nhạt dần theo khoảng cách ($dist = 1 \rightarrow 2 \rightarrow 3$), hiệu ứng karaoke word-by-word mượt mà. Tự động chuyển sang `UP NEXT` và làm mờ tab Lyrics (`opacity: 0.35`) khi bài hát không có lyric.
        - *Tab 3 - RELATED*: Bóc tách tự động qua `get_song_related_content` trong `backend/ytmusic_helper.py`, hiển thị 3 nhóm carousels: "You might also like", "Recommended playlists", và "Similar artists".
    - **Loại Bỏ Sidebar & Điều Hướng Liquid Glass Trên Top Header**:
      - Xóa bỏ hoàn toàn `NavSidebar.qml` khỏi giao diện để trả lại 100% không gian hiển thị cho Home feed và Now Playing.
      - Chuyển 3 nút điều hướng (`Home`, `Downloads/Library`, `Settings`) lên cụm Liquid Glass ở góc phải của `TopHeaderBar.qml`. Nút đang kích hoạt có viền sáng neon theo `accentColor` và hiệu ứng hover êm dịu.
    - **Cơ Chế Thu Gọn / Mở Rộng 1-Chạm Bằng Nút Chevron Trên Player Bar**:
      - Giữ nguyên kích thước thanh dock 66px của `PlayerBarBottom.qml`.
      - Thay thế nút lyric bằng nút chevron xoay tròn `[ ∨ / ∧ ]` (`rotation: root.isNowPlayingOpen ? -90 : 90`).
      - Bấm vào chevron hoặc click tên bài / bìa album trên player bar để chuyển đổi giữa chế độ duyệt (Home) và Now Playing view.
      - Click phát bất kỳ bài hát nào từ Home, Search, Downloads tự động mở bung Now Playing view.
    - **Bẫy Lỗi Cần Tránh (Crucial Gotchas)**:
      - Trong Quickshell, `Process` không sử dụng `StdioCollector { onDataChanged }` mà **bắt buộc** phải dùng `SplitParser { splitMarker: "\n"; onRead: data => { ... } }` kết hợp `onExited` để nạp dữ liệu từ Python daemon.
      - Khi lồng các phần tử con bên trong `LiquidGlass.qml`, cần khai báo `property alias radius: root.radius` trên `contentContainer` để tránh lỗi cảnh báo `Unable to assign [undefined] to double` khi con gọi `parent.radius`.
30. **Kiến Trúc Keo 502 Thấu Kính Trong Suốt & Sóng Lỏng Dẻo Lan Màu (Water-Clear Keo 502 Resin & Viscous Flow Wave)**:
    - **Chất Liệu Kính Keo 502 Ngoài Đời (Water-Clear Optical Resin)**:
      - Loại bỏ hoàn toàn nền xám chì/đen đục ngầu (`salienceBase`).
      - Lấy mẫu trực tiếp texture nền phía sau (`clearRefraction` ở LOD 0.5) với tán sắc quang sai nhẹ, bảo đảm nhìn thấu 100% chữ và hình ảnh của card bài hát bên dưới với độ sắc nét quang học chân thực.
      - Sức căng bề mặt & độ dẻo (Meniscus Specular): Khúc xạ dạng thấu kính lồi giọt keo lỏng lướt qua các vật thể kết hợp vệt phản quang óng ả `keo502Gloss` (rimSheen 3.5-power + top light reflection) mang lại cảm giác căng bóng trơn dẻo như một giọt keo 502 đọng trên mặt phẳng.
      - Khóa độ mờ `glassAlpha` ở mức `0.48 - 0.58` thanh thoát, không bao giờ bị bết hay biến thành thanh nhựa đặc.
    - **Thuật Toán Sóng Lỏng Dẻo Lan Màu Từ Từ (Viscous Flow Wave Diffusion)**:
      - Tự động lấy mẫu 2 gam màu đại diện `songColorA` và `songColorB` từ bài hát đang phát (ví dụ: xanh biển sâu và trắng pha lê của FocusTunes) ngay trên GPU texture LOD 6.0.
      - Tích hợp trường sóng chất lỏng dẻo 3 tầng (`wave1`, `wave2`, `wave3`) giao thoa chậm rãi (chu kỳ ~14 giây) theo biến thời gian `u_time`.
      - 2 gam màu từ từ chảy qua nhau và lan tỏa nhẹ nhàng (`tintStrength: 0.22`) khắp bề mặt thanh keo, chuyển màu êm dịu khi bài hát thay đổi.
31. **Kiến Trúc Mood Filter Chips Up Next, Download Toggle Delete & PlayerBar Cover Masking (Item 31)**:
    - **Mood Filter Chips Động Trong UP NEXT (`YTMusicNowPlayingView.qml` & `backend/ytmusic_helper.py`)**:
      - *Backend Innertube next endpoint*: Bóc tách `subHeaderChipCloud.chipCloudRenderer.chips` từ `v1/next` (`playlistId=f"RDAMVM{videoId}"`) trả về toàn bộ chip tâm trạng cá nhân hóa: `All`, `Deep cuts`, `Popular`, `Discover`, `Familiar`, `Romance`, `Party`, `Workout`, `2010s`, `2020s`, `Pop`, `Latin pop`, `Reggaeton`,...
      - *Lọc hàng đợi theo Mood*: Hàm `get_filtered_radio_queue(videoId, playlistId, params)` gửi request `v1/next` với `playlistId` và `params` của chip, chuẩn hóa 25 bài hát qua `parse_watch_playlist` và `normalize_track` kèm tính toán thời lượng `durationMs`.
      - *Thanh trượt ngang Flickable & WheelHandler*: Bo góc viên thuốc `radius: 15` (cao 30px, padding ngang 12px). Chip được chọn có nền trắng tinh khiết `#ffffff`, chữ đen đậm `#000000`; chip chưa chọn có nền kính mờ `0.08`, viền `0.12`, chữ trắng sáng. Tích hợp `WheelHandler` tự động chuyển đổi `angleDelta.y` của chuột dọc sang cuộn ngang trên Flickable.
      - *Phản hồi UI êm ái*: Khi bấm chip tâm trạng, hàng đợi `queueListView` làm mờ nhẹ (opacity 0.45) với animation 150ms, bảo lưu bài hát đang phát ở vị trí đầu tiên (track index 0), nạp 24 bài hát mới vào `queueTracks` và đồng bộ vào `win.currentTracks`.
    - **Cơ Chế Nút Download Đổi Chiều (Toggle Delete Khi Đã Tải Xong)**:
      - *3 Trạng thái phản hồi*:
        1. *Chưa tải*: Icon mũi tên tải xuống (`download-symbolic.svg`), click để bắt đầu tải qua `downloadManager.enqueue(trk)`.
        2. *Đang tải*: Con quay `DownloadingSpinner` xoay tròn kèm % tiến trình.
        3. *Đã tải xong hoặc là bài offline*: Dấu kiểm tra verify `emblem-ok-symbolic.svg` màu `root.accentColor`.
      - *Xóa 0ms không tải trùng*: Khi click vào dấu verify, hàm `downloadManager.deleteDownloaded(videoId, track)` lập tức:
        - Xóa vĩnh viễn file âm thanh và `.lrc` trên đĩa cứng qua `backend/library.py delete <path> "" <title>`.
        - Gửi lệnh `remove <videoId>` đến socket daemon `backend/download_manager.py` để xóa task khỏi file trạng thái.
        - Lập tức lọc bỏ bài hát khỏi `win.allTracks` và `downloadTasks` trong bộ nhớ QML, giúp reactive binding `isDone` chuyển thành `false` ngay tức thì (0ms).
        - Icon lập tức đổi từ dấu verify trở lại mũi tên download và phát thông báo desktop qua `notify-send`.
    - **Bo Góc Tròn MultiEffect Chuẩn 8px & Khử Dải Đen Cho PlayerBar (`PlayerBarBottom.qml`)**:
      - *Khắc phục bẫy góc chữ nhật*: `Rectangle { radius: 8; clip: true }` trong Qt Quick không bo tròn được góc của con `Image`. Thay thế bằng cấu trúc mặt nạ `Rectangle { id: miniCoverMask; radius: 8; visible: false; layer.enabled: true }` kết hợp `Item { layer.enabled: true; layer.effect: MultiEffect { maskEnabled: true; maskSource: miniCoverMask } }`.
      - *Khử letterbox 16:9 YouTube*: Tự động phóng đại `scale: (implicitWidth / implicitHeight > 1.3) ? 1.48 : 1.0; transformOrigin: Item.Center; fillMode: Image.PreserveAspectCrop` giúp thumbnail 38x38 luôn tràn khung đều đặn, không còn viền đen trên dưới.
      - *Viền hairline 1px đồng bộ*: Lớp phủ `border.color: miniCoverMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.16)` mang lại độ hoàn thiện pixel-perfect như các card trong Home và Downloads.

36. **Hệ Thống Gợi Ý Tìm Kiếm Thời Gian Thực Kèm Avatar Chuẩn SimpMusic, Pinned Search Bar & Non-Intrusive Search Playback (Item 36)**:
    - **Trải Nghiệm Gợi Ý Tìm Kiếm Thời Gian Thực Từng Ký Tự (< 90ms)**:
      - Cấu trúc `Timer` debounce 90ms lắng nghe đồng thời `onDisplayTextChanged` và `onTextEdited` trong `components/CategorizedSearchView.qml`.
      - Gõ bất kỳ ký tự nào (ví dụ `k` $\rightarrow$ `kh` $\rightarrow$ "Không Buông", "Khuôn Mặt Đáng Thương") là lập tức cập nhật gợi ý theo thời gian thực mà không bắt buộc phải nhấn phím Space hay Tab.
    - **Bố Cục Gợi Ý 2 Tầng Chuẩn SimpMusic (Artwork + Text Queries)**:
      - **Tầng 1 (Bài hát đề xuất)**: Hiển thị các bài hát đề xuất với ảnh cover/avatar vuông bo góc tròn (40x40 px, radius 6px), tên bài hát in đậm, nghệ sĩ và số lượt phát phân giải sạch sẽ từ Innertube. Click phát trực tiếp ở background player bar.
      - **Tầng 2 (Từ khóa tìm kiếm)**: Danh sách các từ khóa text với icon kính lúp bên trái và nút mũi tên ↗ bên phải để điền nhanh vào thanh tìm kiếm.
    - **Tối Ưu Hóa Header Bar Chill & Tinh Gọn (Zero Redundant Buttons)**:
      - Xóa bỏ hoàn toàn 2 nút tròn `<` và `>` (Back/Forward) ở góc trái trên cùng `components/TopHeaderBar.qml`.
      - Tích hợp nút Search icon borderless (`system-search-symbolic.svg`) vào cụm điều hướng chính (Home, Search, Downloads/Library, Queue, Settings).
      - Pinned Top Search Bar chuyên dụng cố định ở đầu trang tìm kiếm với nút `<` quay lại, ô input bo góc 19px, kính lúp, nút `✕` xóa nhanh.
    - **Trải Nghiệm Phát Nhạc Không Gián Đoạn (Non-intrusive Search Playback)**:
      - Khi đang ở tab Search, việc chuyển bài hát (click bài gợi ý, next/prev, auto-advance) giữ nguyên màn hình tìm kiếm, chỉ cập nhật âm thanh và thông tin ở Player Bar bên dưới, tuyệt đối không tự động bung màn hình Now Playing / Lyrics (`AmberolDetailView`).
    - **Xóa Bỏ Viền Lạc Màu Hero Top Result Card**:
      - Chuyển `topResultCard` và nút Đài phát sang dạng borderless glass (`border.width: 0`, `color: Qt.rgba(1, 1, 1, 0.04)`), hòa quyện hoàn hảo với phông nền anime và màu chủ đạo hình nền.
    - **Backend Innertube & Resident Daemon Hiệu Năng Cao**:
      - `backend/ytmusic_helper.py`: Phân giải đồng thời Section 0 (`queries`) và Section 1 (`recommended`) từ endpoint Innertube `music/get_search_suggestions`.
    - **Cơ Chế Khắc Phục Lỗi IME Tiếng Việt (Fcitx5 / IBus / Bamboo Pre-edit Composition)**:
      - *Hiện tượng & Nguyên nhân gốc (Root Cause)*:
        - Khi người dùng gõ tiếng Việt trên Linux Wayland bằng bộ gõ (Fcitx5 / Bamboo / Unikey), các ký tự đang soạn thảo (như `e` $\rightarrow$ `em`) được hệ thống IME lưu dưới dạng chuỗi tiền cam kết (*pre-edit text*) và hiển thị trên `displayText` hoặc `preeditText`.
        - Thuộc tính `text` của `TextInput` trong Qt Quick chỉ chứa văn bản *đã cam kết* (*committed text*). Trong suốt quá trình đang gõ nguyên âm hoặc từ chưa hoàn tất, `searchTextInput.text` vẫn là rỗng `""`.
        - Nếu mã nguồn chỉ đọc `searchTextInput.text`:
          1. Timer gợi ý đọc phải chuỗi rỗng `""` và dọn sạch danh sách gợi ý.
          2. Khi phản hồi API từ `auth_server` trả về, điều kiện kiểm tra `searchTextInput.text.trim().toLowerCase() === cleanQ.toLowerCase()` so sánh `"" === "em"` (kết quả `false`), làm dữ liệu gợi ý bị vứt bỏ hoàn toàn cho đến khi người dùng nhấn Space hoặc Tab để cam kết từ.
          3. Khi nhấn phím Backspace (`kh` $\rightarrow$ `k`), IME lập tức cam kết phần còn lại vào `text`, nên thao tác xóa từ lại chạy mượt mà tức thì.
      - *Giải pháp Kiến trúc Đa tầng Triệt để (Universal Solution Protocol)*:
        1. **Hàm Phân Giải Chuỗi Tìm Kiếm Thực Tế (`getCurrentSearchQuery()`)**:
           - Kiểm tra đa tầng: `displayText` (chuỗi thực sự hiển thị trên mắt người dùng) $\rightarrow$ `text + preeditText` (kết hợp văn bản đã cam kết và văn bản đang gõ) $\rightarrow$ `preeditText` $\rightarrow$ `text`.
           - Bảo đảm chuỗi tìm kiếm luôn phản ánh chính xác 100% từng phím bấm của người dùng theo thời gian thực dù IME đang ở trạng thái pre-edit hay committed.
        2. **Đón Đầu Toàn Bộ Sự Kiện Vòng Đời IME Của Qt Quick `TextInput`**:
           - Lắng nghe đồng thời 5 tín hiệu: `onDisplayTextChanged`, `onTextEdited`, `onTextChanged`, `onPreeditTextChanged`, `onInputMethodComposingChanged` với bộ đệm `realtimeSuggestTimer` (interval 60ms).
        3. **So Sánh Đồng Bộ Trong Callback `fetchSuggestions`**:
           - Sử dụng `getCurrentSearchQuery()` để đối chiếu kết quả trả về từ `auth_server`, cho phép nạp dữ liệu mượt mà ngay cả khi từ khóa vẫn đang nằm trong bộ đệm IME.
        4. **Đồng Bộ Placeholder & Nút Clear `✕`**:
           - Chuyển `visible` của placeholder và nút clear sang phụ thuộc `getCurrentSearchQuery().length`, loại bỏ hiện tượng placeholder đè chữ khi đang gõ tiếng Việt.
    - **Bẫy Lỗi Tránh Lặp Lại (Crucial Gotchas)**:
      - *Vỡ Binding Thuộc Tính QML (Broken Property Binding)*: Khi `CategorizedSearchView` nhận `suggestions` qua binding từ cha, nếu trong code con tự ý gán `suggestions = []` thì binding của QML sẽ bị hủy vĩnh viễn. Giải pháp: để `CategorizedSearchView` tự quản lý dữ liệu gợi ý cục bộ thông qua `fetchSuggestions(q)` trực tiếp đến `auth_server`, bảo đảm tính tự đóng gói (self-contained) và tốc độ cập nhật 0ms.
      - *Không Dùng `TextInput.text` Độc Lập Cho Tìm Kiếm Thời Gian Thực*: Tuyệt đối không chỉ đọc `TextInput.text` trên Linux Wayland khi hỗ trợ gõ tiếng Việt / CJK. Luôn đọc qua `getCurrentSearchQuery()` để thu thập cả `displayText` và `preeditText`.

32. **Kiến Trúc Dynamic Play/Pause Palette Engine, Clean Edge-to-Edge Hover-to-Scroll Mood Bar & Unbroken Reactive Queue Continuity (Item 32)**:
    - **Dynamic Play/Pause Palette Engine (Tách Biệt Màu Sắc Theo Bài Hát & Hình Nền)**:
      - *Khi phát nhạc (`isPlaying === true`)*: Trích xuất màu sắc nghệ thuật (chromatic salience) trực tiếp từ ảnh bìa bài hát đang phát (`track.image`) qua `palette_extractor.py`, cập nhật động `root.accentColor`, sóng âm Equalizer, thanh tiến trình, nút Play/Pause và chip tab đang active.
      - *Khi tạm dừng (`isPlaying === false`)*: Tự động khôi phục màu điểm nhấn gốc từ hình nền desktop hiện tại (`wallpaperPalette` trong `~/.config/noctalia/nutsty_palette.json`).
      - *Chuyển đổi êm dịu*: Đồng bộ qua reactive binding giữa `shell.qml` và `YTMusicNowPlayingView.qml`, đảm bảo giao diện luôn phản ánh chính xác trạng thái phát nhạc mà không bị gián đoạn hay sai lệch màu sắc.
    - **Clean Edge-to-Edge Hover-to-Scroll Mood Bar (Loại Bỏ Bóng Đen 2 Mép & Tự Cuộn Khi Rê Chuột)**:
      - *Xóa bỏ hoàn toàn dải che đen*: Loại bỏ hai `Rectangle` nền gradient đen đục ở hai cạnh trái/phải của thanh Mood Chips, mang lại bề mặt trong suốt chuẩn dark glass đồng nhất với tổng thể giao diện.
      - *Vùng cảm biến tự động cuộn (Zero-Interference Hover Sensor)*: Thiết lập hai dải cảm biến vô hình rộng 36px (`leftMoodScrim` và `rightMoodScrim`) ở mép trái và mép phải thanh Mood Chips.
      - *Cuộn mượt mà*: Khi con trỏ chuột hover vào khoảng trống hai bên, timer `hoverScrollTimer` tự động cuộn `moodFlickable.contentX` êm dịu (tốc độ 4px/frame).
      - *Không chặn click*: Thiết lập `MouseArea { propagateComposedEvents: true; onPressed: (mouse) => { mouse.accepted = false; } }` đảm bảo người dùng có thể click chọn trực tiếp các chip tâm trạng nằm dưới vùng cảm biến mà không hề bị cản trở.
    - **Unbroken Reactive Queue Continuity & High-Res Cover Sync**:
      - *Khắc phục lỗi avatar bị đứng ở bài cũ*:
        - Bẫy lỗi trước đó: Trong `YTMusicNowPlayingView.qml`, sự kiện `onStatusChanged` gán thủ công `source = root.track.image` khi ảnh độ phân giải cao bị lỗi (404), khiến declarative property binding của QML bị đứt vĩnh viễn và không cập nhật được ảnh khi chuyển sang bài hát tiếp theo.
        - Giải pháp triệt để: Sử dụng cờ phản ứng `property bool highResFailed: false`. Thuộc tính `source` của ảnh lớn được khai báo phụ thuộc phản ứng (`highResFailed ? (root.track ? root.track.image : "") : ...`). Khi đổi bài (`onTrackChanged`), reset cờ `root.highResFailed = false`, đảm bảo binding luôn toàn vẹn và ảnh bài hát mới lập tức hiển thị.
      - *Khắc phục lỗi hàng đợi "All" chỉ hiện 1 bài*:
        - Bẫy lỗi trước đó: Trong `onTrackChanged`, lệnh gán thủ công `root.queueTracks = [root.track]` làm đứt binding `queueTracks: win.currentTracks`. Khi `radioProc` hoặc `moodQueueProc` nạp xong danh sách bài hát trong background và cập nhật `win.currentTracks`, `root.queueTracks` không nhận được dữ liệu mới.
        - Giải pháp triệt để: Loại bỏ hoàn toàn các lệnh gán đè thủ công lên `root.queueTracks`. Mọi cập nhật danh sách bài hát được chuyển tiếp qua signal phản ứng `root.queueUpdated(newQueue)` và gán tập trung vào `win.currentTracks`.
        - Trong hàm `fetchMoodChips()`, bổ sung điều kiện kiểm tra `if (vid === lastMoodChipsVid && root.moodChips.length > 0 && root.queueTracks && root.queueTracks.length > 1) return;` và xóa cache `root.lastMoodChipsVid = ""` khi `!isAlreadyInQueue`, bảo đảm khi chọn bài hát mới từ ngoài vào luôn kích hoạt nạp mới đầy đủ hàng đợi (20+ bài) và bộ chip tâm trạng tương ứng.
33. **Thanh Tìm Kiếm Không Viền Thu Gọn (Collapsible Borderless Search Icon) & Cơ Chế Cuộn Hover/Drag/Wheel Cho Carousels Related (Item 33)**:
    - **Thanh Tìm Kiếm Thu Gọn Tối Giản Không Nền Đen (`components/TopHeaderBar.qml`)**:
      - Xóa bỏ hoàn toàn khối nền đen đục chữ nhật (`#242424`) và border cố định phía dưới thanh tìm kiếm.
      - Trạng thái nghỉ (Idle): Thu gọn thành icon kính lúp borderless thuần túy (`search-symbolic.svg`), kích thước 32x32 px, nền `transparent`, đồng bộ 100% ngôn ngữ thiết kế tối giản với các nút điều hướng khác (Downloads, Home, Library, Settings). Hover phóng nhẹ 1.12x kèm đổi màu theo `accentColor`.
      - Trạng thái mở rộng (Expanded): Khi người dùng click vào icon hoặc khi đang có từ khóa tìm kiếm (`searchExpanded || searchText.length > 0`), thanh tìm kiếm bung rộng mượt mà (`width: 340px`, `NumberAnimation` 250ms cubic easing), áp dụng nền kính trong suốt siêu nhẹ `Qt.rgba(1, 1, 1, 0.08)` và viền hairline `0.15` (sáng theo `accentColor` khi focus), tự động focus con trỏ vào ô nhập liệu (`searchInput.forceActiveFocus()`).
      - Nút dọn / thu gọn (✕) và phím `Escape`: Tự động xóa nội dung tìm kiếm hoặc thu gọn trở lại icon khi để trống. Khi rời khỏi view tìm kiếm, thanh tìm kiếm tự động thu gọn nếu không còn từ khóa.
    - **Cơ Chế Cuộn 3 Chế Độ Cho Carousels Related (`components/YTMusicNowPlayingView.qml`)**:
      - Áp dụng cho cả hai kệ carousels trong tab `RELATED`: "Recommended playlists" (`recPlFlickable`) và "Similar artists" (`artFlickable`).
      - *Cảm biến tự động cuộn khi rê chuột (Zero-Interference Edge Hover Scrims)*: Bố trí hai dải cảm biến vô hình rộng 36px ở mép trái (`leftRecPlScrim`, `leftArtScrim`) và mép phải (`rightRecPlScrim`, `rightArtScrim`). Rê chuột vào khoảng không hai mép sẽ kích hoạt timer cuộn mượt mà (interval 16ms, bước 8px), loại bỏ hoàn toàn các nút mũi tên bấm thô cứng. Thiết lập `propagateComposedEvents: true` và `onPressed: mouse.accepted = false` để không cản trở thao tác click vào card hoặc nghệ sĩ nằm dưới vùng cảm biến.
      - *Kéo thả tự do (DragHandler)*: Tích hợp `DragHandler { target: null; cursorShape: Qt.OpenHandCursor; ... }` cho phép người dùng click giữ chuột và kéo lướt carousel như trên màn hình cảm ứng hoặc mobile.
      - *Cuộn chuột thông minh (WheelHandler)*: Tự động chuyển đổi con lăn chuột dọc (`angleDelta.y`) sang cuộn ngang (`contentX`), mang lại trải nghiệm mượt mà không cần phím Shift.

34. **Kiến Trúc Bố Cục YouTube Music 3-Archetype & Cụm Nút Điều Hướng Liquid Glass Accent Năng Động (Item 34)**:
    - **Thống Nhất 3 Archetype Bố Cục Chuẩn YouTube Music Toàn Bộ Mood Feeds (`components/HomeFeedView.qml`)**:
      - *Video Music Carousel (Hình chữ nhật 16:9)*: Áp dụng cho các video âm nhạc, clip trình diễn trực tiếp và đĩa đơn video. Card tỷ lệ 16:9 (`width: 240px`, thumbnail 240x135), bo góc tròn mềm mại 10px, hiển thị badge thời lượng video và thông tin kênh/nghệ sĩ.
      - *Quick Picks Grid (Lưới 4 dòng x N cột)*: Áp dụng cho danh sách tuyển chọn nhanh cá nhân hóa. Mỗi cột cao 4 dòng, mỗi item có thumbnail vuông nhỏ 48x48 px (bo góc 6px), tiêu đề bài hát, phụ đề nghệ sĩ và thời lượng, hỗ trợ click phát trực tiếp.
      - *Playlists & Albums Carousel (Hình vuông 1:1)*: Áp dụng cho các album, đĩa đơn, EP và danh sách phát đề xuất. Card tỷ lệ 1:1 (`width: 160px`, thumbnail 160x160), bo góc tròn 8px, hiển thị tên album/playlist và loại phát hành.
      - *Xóa bỏ toàn bộ nút "Play all" capsule*: Loại bỏ hoàn toàn các nút con nhộng "Play all" tại header của các section để giải phóng không gian thở và tôn trọng ngôn ngữ tối giản cao cấp.
    - **Cụm Nút Điều Hướng `< >` Liquid Glass Đổi Màu Thích Ứng (Option 1)**:
      - *Thiết kế Kính Liquid Glass Dark Tint & Glow*: Nền kính đen mờ phủ nhẹ 10% sắc màu chủ đạo (`Qt.rgba(accent.r, accent.g, accent.b, 0.10)`), viền hairline 1px điểm xuyết (`0.30`), icon mũi tên SVG (`go-previous-symbolic.svg`, `go-next-symbolic.svg`) nhuộm theo `accentColor`.
      - *Tương tác Hover & Vô hiệu hóa*: Khi rê chuột (hover), nền kính sáng lên `0.28`, viền rực rỡ `0.75`, phóng to 1.06x êm dịu. Khi chạm giới hạn cuộn trang (mép trái/phải), nút tự động giảm độ đục xuống `0.25` và vô hiệu hóa click.
      - *Chuyển đổi màu sắc 2 chiều (Dynamic 2-Way Accent Sync)*:
        - Khi phát nhạc (`win.isPlaying === true`): Cụm nút đồng bộ tức thì với màu điểm nhấn trích xuất từ ảnh bìa bài hát (`win.songAccentColor`).
        - Khi dừng / tạm dừng (`win.isPlaying === false`): Cụm nút tự động chuyển tiếp mềm mại (animation 300ms) trở về màu điểm nhấn của hình nền desktop (`win.wallpaperAccentColor`).
    - **Khắc Phục Lỗi Dữ Liệu Mood Feeds Bị Trống (`backend/ytmusic_helper.py`)**:
      - Khắc phục lỗi `UnboundLocalError: cannot access local variable 'creator'` trong hàm `_normalize_shelf_item` bằng cách khởi tạo mặc định `creator = artist_name or ""` trước các khối kiểm tra community badge. Giúp toàn bộ các tab tâm trạng (Sleep, Relax, Sad, Romance, Focus, Party, v.v.) hiển thị đầy đủ và phong phú các kệ nội dung mà không bị crash ngầm.

35. **Khắc Phục Lỗi Tràn Biên Mood Chips Ra Vùng Ảnh Bìa & Chuẩn Hóa DragHandler (Item 35)**:
    - **Cắt Biên Tuyệt Đối (`clip: true`) Cho Flickables Ngang**:
      - *Bẫy lỗi trước đó*: Trong `YTMusicNowPlayingView.qml`, `moodFlickable` đặt `clip: false`. Trong bố cục chia đôi màn hình 50/50, khi người dùng cuộn hoặc kéo danh sách Mood Chips về phía phải, các chip ở đầu hàng (như "All", "Deep cuts", "Popular") bị dịch chuyển tọa độ sang âm và vẽ tràn qua ranh giới cột, đè trực tiếp lên vùng ảnh bìa bài hát và hình nền desktop.
      - *Giải pháp triệt để*: Kích hoạt `clip: true` trên toàn bộ các Flickables trượt ngang (`moodFlickable`, `recPlFlickable`, `artFlickable` trong `YTMusicNowPlayingView.qml` và `homeMoodFlickable` trong `HomeFeedView.qml`), bảo đảm nội dung luôn bị giới hạn trong khung hiển thị của nó và cắt gọt sắc nét tại mép cột.
    - **Chuẩn Hóa Cơ Chế Tọa Độ 1:1 Của `DragHandler`**:
      - *Bẫy lỗi trước đó*: `DragHandler.translation` trong Qt Quick là độ dịch chuyển tích lũy từ mốc bắt đầu cử chỉ, không phải delta từng frame. Việc liên tục lấy `contentX - translation.x` mỗi frame tạo ra hiện tượng gia tốc ảo lũy tiến (exponential jumping), khiến danh sách bị văng mất kiểm soát khi rê chuột.
      - *Giải pháp triệt để*: Khai báo thuộc tính `property real startContentX: 0`, lưu mốc tọa độ gốc khi `active` trở thành `true` (`startContentX = flickable.contentX`), và tính toán `flickable.contentX = Math.max(0, Math.min(maxScroll, startContentX - translation.x))` khi cử chỉ đang diễn ra, mang lại trải nghiệm kéo rê trực tiếp 1:1 mượt mà và dừng lại chuẩn xác tại hai đầu biên.
37. **Kiến Trúc Unified Top Result Card & Hiệu Ứng Ryan Mulligan Shiny CTA (`ShinyCardContainer.qml`) (Item 37)**:
    - **Hợp Nhất Khối Kết Quả Hàng Đầu (Unified Top Result Card Container)**:
      - *Hiện trạng trước đó*: Thẻ nghệ sĩ (bên trái) nằm trong một ô chữ nhật tối màu bo góc, trong khi 3 bài hát tiêu biểu (bên phải) lại trôi nổi trơ trọi không có nền ngoài trang tìm kiếm, gây mất cân đối thị giác.
      - *Giải pháp triệt để*: Hợp nhất toàn bộ khối Hero nghệ sĩ và 3 bài hát tiêu biểu vào chung một khối card duy nhất (`components/ShinyCardContainer.qml`).
      - *Bố cục đáp ứng liền mạch (Seamless 2-Column Responsive Layout)*: Bên trái là Hero Artist / Album / Song (Avatar tròn 92px cắt mặt nạ chuẩn `MultiEffect`, tên nghệ sĩ 20px Bold, subtitle người đăng ký, cụm nút `[ 🔀 Phát ngẫu nhiên ]` và `[ 📻 Mix ]`); bên phải là 3 dòng bài hát nổi bật (thumbnail 42px bo góc 8px, overlay icon Play/Pause, thời lượng và lượt xem/views).
      - *Loại bỏ vạch ngăn cách cứng*: Đã xóa bỏ hoàn toàn thanh chia dọc ở giữa theo đúng chuẩn Gestalt Law of Common Region, giúp toàn bộ không gian thẻ thở tự nhiên và thông thoáng.
    - **Chuyển Hóa Hiệu Ứng Ryan Mulligan CSS `@property` Shiny CTA Sang QML Hardware-Accelerated**:
      - *Tệp cốt lõi*: `components/ShinyCardContainer.qml`.
      - *Hollow Border Mask (Triệt tiêu 100% tia sáng tâm)*: Dùng `Shape` với `PathRectangle` vẽ stroke `1.5px`, `fillColor: "transparent"` làm `maskSource` cho `MultiEffect`, đảm bảo ruột trong suốt tuyệt đối và chỉ có đúng đường viền mép là nhận ánh sáng quay.
      - *Cơ chế quét viền Conic (`border-box conic-gradient`)*: Sử dụng `Shape` với `fillGradient: ConicalGradient` xoay tròn liên tục $0^\circ \rightarrow 360^\circ$ quanh tâm card bằng `RotationAnimation` (chu kỳ 4s, 100% GPU matrix transform, 0% CPU overhead).
      - *Phổ màu chùm sáng điện ảnh*: Chùm sáng hẹp 18% chu vi: `transparent` $\rightarrow$ `accentColor` (4%) $\rightarrow$ `#ffffff` (8% specular core chói sáng) $\rightarrow$ `subtleAccentColor` (12%) $\rightarrow$ `transparent` (18%..100%).
    - **Kiến Trúc Bề Mặt Liquid Glass Quang Học & Hairline Accent Border (Phương án 1)**:
      - *Đồng bộ 100% công nghệ Liquid Glass với PlayerBar*: `ShinyCardContainer` kế thừa trực tiếp engine `LiquidGlass` (`displacement: 18.0`, `aberration: 0.03`, `bevelWidth: 24.0`, `tintColor: rgba(accentColor, 0.16)`), nhận nguồn đệm tổng hợp `backgroundSourceItem: glassCompositeBackdrop` từ `shell.qml` xuyên qua `CategorizedSearchView`.
      - *Phản xạ quang học & Tán sắc lăng kính*: Bề mặt thẻ có khúc xạ thấu kính uốn cong hình nền bên dưới, kết hợp tán sắc quang sai biên (chromatic aberration) và sức căng bề mặt chất lỏng (keo 502 resin meniscus) tương đồng hoàn hảo với PlayerBar.
      - *Dark Scrim & Gradient Chống Bệt Màu (smooth-scrim-gradient & liquid-glass-backdrop)*: Áp dụng lớp scrim tối `rgba(0.04, 0.05, 0.07, 0.52)` bảo đảm độ tương phản chữ đọc; dải gradient ngang trải dài toàn phần sử dụng sắc độ `accentColor` ở cả 3 điểm dừng (tránh dùng `Color.Transparent` gây vết xám bẩn ở giữa); đã xóa bỏ hoàn toàn quầng sáng tròn mờ cũ phía sau avatar giúp chân dung nghệ sĩ nổi bật sắc nét trên nền kính lỏng.
      - *Xóa bỏ vĩnh viễn viền đen lạnh (Hairline Accent Border)*: Viền tĩnh bao quanh 360 độ sử dụng `border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)` (hover `0.35`), xóa bỏ hiện tượng viền đen ở cạnh phải.
      - *Chuẩn hóa tương tác dòng bài hát*: Dòng bài hát đang phát (`isCurrent`) hoặc rê chuột (`containsMouse`) nhận lớp nền và viền tóc mang sắc thái `accentColor` mượt mà, loại bỏ các mảng chữ nhật xám chắp vá.
    - **Tối Ưu Nền Acrylic & Tích Hợp Niri GPU Hardware Blur**:
      - *Cấu hình `window-rule` trong `~/.config/niri/cfg/rules.kdl`*: Khai báo `background-effect { blur true }` cho cả `match title=r#"^Nutsty.*$"#`, `match app-id="dev.noctalia.noctalia-qs"` và `match app-id="frostify-local"`.
      - *Hiệu ứng quang học*: Cửa sổ Nutsty khi nổi trên desktop Linux Wayland (Niri) làm mờ sâu toàn bộ hình nền anime và các cửa sổ bên dưới thành hiệu ứng bokeh mịn màng, giúp giao diện trong suốt acrylic cực kỳ dịu mắt và nội dung văn bản luôn nổi bật, sắc nét 100%.

38. **Cơ Chế Artist Shuffle Mở Up Next Chuẩn YouTube Music & Khắc Phục Triệt Để Category Tabs (0) (Item 38)**:
    - **Khắc Phục Triệt Để Lỗi Các Tab Thể Loại Trả Về `(0)` (`run.sh` & `CategorizedSearchView.qml`)**:
      - *Nguyên nhân gốc (Root Cause)*:
        - Trong `run.sh`, các tiến trình chạy ngầm (`auth_server.py`, `tray_indicator.py`) sử dụng đường dẫn tuyệt đối `/usr/bin/python3`.
        - Trên hệ điều hành Linux của người dùng, `/usr/bin/python3` là Python mặc định của hệ thống và **không** có thư viện `ytmusicapi` (thư viện được cài trong môi trường Python người dùng / Miniconda `~/.local` hoặc `~/miniconda3/bin/python3`).
        - Khi `run.sh` khởi chạy `backend/auth_server.py` bằng `/usr/bin/python3`, mọi request `/api/filter_search` đều gặp ngoại lệ `ModuleNotFoundError: No module named 'ytmusicapi'`, khiến server trả về mảng rỗng `[]` và toàn bộ các tab ("Bài hát", "Albums", "Danh sách phát cộng đồng") hiển thị `(0)`.
      - *Giải pháp triệt để*:
        1. Chuẩn hóa `run.sh` sử dụng `python3` từ biến môi trường `$PATH` thay vì hardcode `/usr/bin/python3`, tuân thủ nghiêm ngặt nguyên tắc Zero-Setup & Universal Portability.
        2. Bổ sung cơ chế **Instant Pre-population (Độ trễ 0ms)** trong `CategorizedSearchView.qml`: Khi người dùng chuyển đổi giữa các tab filter chips (`songs`, `albums`, `community_playlists`, `featured_playlists`, `artists`), nếu `searchData` đã có sẵn dữ liệu từ lượt tìm kiếm tổng hợp ban đầu, giao diện lập tức gán và hiển thị ngay danh sách đó, tuyệt đối không để màn hình trắng hay hiện `(0)` trong khi request HTTP background đang tải đầy đủ 60 mục từ YouTube Music.
    - **Cơ Chế Artist Shuffle Mở Up Next Chuẩn YouTube Music (Ảnh 5 - Item 38)**:
      - *Hiện trạng trước đó*: Khi người dùng bấm nút `[ 🔀 Phát ngẫu nhiên ]` tại Hero Artist Card, hệ thống chỉ lấy bài hát đầu tiên trong 3 bài hát đang hiển thị trên card (`top_tracks[0]`), gọi `startRadioFromTrack` và đóng màn hình Now Playing (`isNowPlayingOpen = false`).
      - *Kiến trúc nâng cấp toàn diện*:
        1. **Thuật toán gom bài & chọn ngẫu nhiên tức thì (< 100ms)**:
           - Khi click `[ 🔀 Phát ngẫu nhiên ]` trên thẻ nghệ sĩ, `CategorizedSearchView.qml` phát tín hiệu `artistShuffleRequested(topItem, allSongs)`.
           - Hàm `playArtistShuffle(artistItem, candidateTracks)` trong `shell.qml` lập tức tổng hợp toàn bộ các bài hát hiện có của nghệ sĩ đó (từ `searchData.songs`, `songsFilterItems` hoặc `top_tracks`), lọc bỏ các bài đã dislike.
           - Chọn ngẫu nhiên một bài hát bất kỳ bằng `Math.floor(Math.random() * pool.length)` để phát ngay lập tức (không bị đóng đinh ở bài 0), xáo trộn các bài còn lại bằng thuật toán Fisher-Yates shuffle và nạp vào hàng đợi `win.currentTracks`.
        2. **Tự động mở bung màn hình Now Playing & chuyển tab `UP NEXT`**:
           - Thiết lập `win.isNowPlayingOpen = true;` và chuyển đổi trực tiếp `ytNowPlayingView.activeTab = "up_next";`.
           - Cập nhật tiêu đề hàng đợi `win.mainSectionTitle = aName;` để giao diện hiển thị dòng chữ đẳng cấp: `Playing from <Tên Nghệ Sĩ>` (ví dụ: `Playing from Sơn Tùng M-TP`, `Playing from 9Lana`).
           - Kích hoạt engine bóc tách `fetchMoodChips()` trên bài hát vừa chọn, hiển thị trọn vẹn dãy viên thuốc tâm trạng: `[ All ] [ Deep cuts ] [ Popular ] [ Discover ] [ Familiar ] [ Pump-up ] [ Romance ]...` giống hệt YouTube Music Web trong Ảnh 5.
        3. **Backend API chính thức `/api/artist_shuffle` (`backend/ytmusic_helper.py` & `auth_server.py`)**:
           - Bổ sung hàm `get_artist_shuffle(name, browse_id)`: Bóc tách mã danh sách phát ngẫu nhiên chính thức của nghệ sĩ từ YouTube Music (`shuffleId` có tiền tố `RDAO...`, ví dụ `RDAOeyKnYmm7ScRhnRO9nwOSNA` của Sơn Tùng M-TP hoặc `RDAOKZCelfsluv5omwg3OslA4g` của 9Lana).
           - Gọi `ytm.get_watch_playlist(playlistId=shuffleId)` để lấy 50 bài hát chính thức do YouTube Music biên tập riêng cho nghệ sĩ đó.
           - Endpoint resident daemon `/api/artist_shuffle` trả về JSON nhanh chóng; `shell.qml` nhận kết quả ngầm và mở rộng hàng đợi `win.currentTracks` mượt mà, bảo lưu bài hát đang phát ở vị trí đầu tiên.
           - Đồng bộ hoàn toàn cả nút Shuffle tại màn hình chi tiết nghệ sĩ (`ArtistDetailView.qml` - `onShuffleArtistRequested`).

39. **Hệ Thống Lời Bài Hát Động Học Anime MV (Anime MV Kinetic Typography Engine - Preset 4)**:
    - **Triết Lý Thiết Kế & Nguồn Cảm Hứng (Reference Video - Dua Lipa Break My Heart Anime Edit)**:
      - Kế thừa trọn vẹn 10 phong cách chuyển động chữ (Kinetic Choreographies) từ video âm nhạc anime đỉnh cao:
        1. *Flanking (2 từ đối xứng 2 mép biên)*: e.g. "OH ... NO", "AM ... I" kèm vạch góc L-ticks sắc nét.
        2. *Stack Equal (2 từ xếp tầng trên dưới)*: e.g. "FALLING / IN" kèm thước đo L-bracket.
        3. *Pyramid (3 từ kim tự tháp kích thước)*: e.g. "LOVE > WITH > ME" (44px > 34px > 26px).
        4. *Vertical Stack (3 từ cột đứng đồng đều)*: e.g. "BUT / WHEN / YOU" (34px).
        5. *Architectural Bento (Bố cục kiến trúc đa tầng)*: e.g. Cột chữ cái lớn "I" (56px) ôm trọn cụm "WAS DOING" (24px), tầng giữa "BETTER" (34px), tầng đáy "ALONE" (42px).
        6. *Vertical Letter Drop (Cột chữ cái rơi nảy từng ký tự)*: e.g. "H-E-A-R-T" (24px, nảy lò xo `Easing.OutBounce`).
        7. *Single Giant Word (1 từ khổng lồ tạo điểm nhấn)*: e.g. "SAID" (62px, Overshoot 1.15).
        8. *Compound Merge (1 từ ghép 2 nửa đối xứng)*: e.g. "“HEL”" + "“LO”" -> "“HELLO”" (44px) kèm ngoặc kép `“ ”`.
        9. *Kinetic Push-Left (Đẩy dạt sang trái từ tâm giữa - 4 đến 5 từ)*: e.g. "ONE THAT COULD BREAK MY" (36px).
        10. *Full-Length Kinetic Push-Left (Câu dài toàn cảnh từ 6 từ trở lên)*: e.g. "I KNEW THAT WAS THE END OF ALL" (28px).
    - **Quy Chuẩn Màu Sắc Phân Tầng Điện Ảnh (Selective Color Rule)**:
      - *Câu dài nhất (`PUSH_LEFT_FULL` từ 6 từ trở lên)*: **Cố định 100% Trắng Tinh Khiết (`#ffffff`)** trên nền bóng đổ Cel Shadow đen sâu (`#000000`, 0% blur). Ngăn chặn hoàn toàn hiện tượng lốm đốm màu sắc hình nền xen kẽ gây rối mắt khi hát câu dài.
      - *Toàn bộ 9 kiểu còn lại (Flanking, Stack Equal, Pyramid, Vertical Stack, Bento Column, Letter Drop, Giant Word, Compound Merge, Push-Left 4-5 từ)*: Kết hợp nhịp nhàng giữa màu Trắng tinh khiết (`#ffffff`) và **Màu Điểm Nhấn Hình Nền (`colAccent` trích xuất từ OKLAB / OKLCH `nutsty_palette.json`)** tạo độ bật thị giác nghệ thuật rực rỡ, độc đáo.
    - **Động Cơ Khử Chớp Nháy Chuyển Câu (Anti-Flash Gate Engine)**:
      - *Cơ chế*: Boolean flag `isSentenceTransitioning` kết hợp `transitionGateTimer` (35ms).
      - Ngay khi `idx !== currentLyricIndex`, lập tức khóa `isSentenceTransitioning = true` và reset `lineProgress = 0.0` ngay trước khi bất kỳ ký tự nào được render.
      - Trong lúc gate đóng, `isWordRevealed(i)` trả về `false` vô điều kiện và tạm ngắt toàn bộ `Behavior` animation.
      - Sau khi cấu trúc hình học ổn định, gate tự động mở lại cho phép các từ xuất hiện tuần tự word-by-word mượt mà, triệt tiêu 100% lỗi nháy hiện cả câu cũ/mới trong 1 frame đầu tiên.
    - **Chuẩn Hóa Kích Thước Tỉ Lệ Vàng Desktop (Proportional Halved Typography)**:
      - Toàn bộ kích thước pixel chữ được tinh chỉnh giảm ~50% (câu dài 28px, chữ lớn 34-44px, cột Bento 24-56px), bảo đảm văn bản luôn nằm gọn gàng, trang nhã trong vùng hạ tiêu cự/tà váy nhân vật mà không bao giờ bị tràn biên màn hình.
    - **Bộ Phân Tách Ngữ Nghĩa Đa Ngôn Ngữ & Cân Bằng Thị Giác Chữ Đông Á (CJK Bunsetsu Tokenizer & Adaptive Typography Balancing)**:
      - *Nguyên nhân chữ tiếng Nhật / tiếng Trung bị khổng lồ trước đó*:
        - Chữ Hán/Kanji/Kana không sử dụng dấu cách (` `) giữa các từ (ví dụ: `所以那就离开吧` hoặc `何回だってきっと`).
        - Bộ tách từ cũ dùng `split(/\s+/)` chỉ tạo ra mảng có độ dài 1 từ duy nhất (`n === 1`).
        - Bộ phân loại điều hướng toàn bộ câu 7-10 ký tự CJK vào kiểu `GIANT_WORD` với kích thước 62px. Vì ký tự CJK có tỉ lệ hình vuông toàn phần 1:1 (full em-width), câu trải dài > 400px gây choán ngợp toàn bộ màn hình.
      - *Giải pháp triệt để*:
        1. **Bộ Tokenizer Đa Tầng CJK Thông Minh (`tokenizeText`)**:
           - Tách theo hệ thống dấu câu CJK phong phú: `[\s,，、。！？!?…~～·・—\-_()（）\[\]【】\"'“”‘’「」『』]+`.
           - Đối với tiếng Nhật: Bóc tách theo cụm Bunsetsu (`[\u4e00-\u9fff]+[\u3040-\u309f]{0,2}|[\u30a0-\u30ff]+|[\u3040-\u309f]{1,3}|[a-zA-Z0-9]+`) kết hợp Kanji gốc với trợ từ Kana đi kèm, từ mượn Katakana và cụm Hiragana.
           - Đối với chữ Hán (tiếng Trung): Gom thành các từ 2 chữ cái kinh điển (`k += 2`) hoặc cụm 3 chữ cái (`我爱你` $\rightarrow$ `['我', '爱', '你']`), biến câu 7 chữ `所以那就离开吧` thành 4 từ ngữ nghĩa (`['所以', '那就', '离开', '吧']`), tự động kích hoạt vũ điệu `BENTO_COLUMN` hoặc `PUSH_LEFT` mượt mà theo từng từ.
        2. **Chuyển Đổi Font Stack Động (`displayFontFamily`)**:
           - Tự động nhận diện `isCJK` qua regex `[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff]`.
           - Khi là tiếng Nhật/Trung/Hàn: Chuyển thẳng sang `Noto Sans CJK JP, Noto Sans CJK SC, Noto Sans CJK KR, Montserrat, sans-serif` với trọng số `Font.Black` sắc nét, không để font Latinh `Impact` gây lỗi render ký tự CJK.
        3. **Tỉ Lệ Kích Thước Chữ Thích Ứng (Adaptive Proportional Scaling - Tăng +20% Cho Ngôn Ngữ Đông Á)**:
           - Tự động nhận diện chữ không phải La-tinh (tiếng Nhật, Trung, Hàn) qua Unicode regex `[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uac00-\ud7af\u1100-\u11ff\u3130-\u318f]`.
           - Áp dụng hệ số co giãn tỉ lệ vàng tăng 20% giúp chữ Đông Á rõ ràng, sắc sảo mà không bị quá khổ:
             - *Flanking / Pyramid 1 / Compound*: `root.isCJK ? 36 : 44` (tăng từ 30 lên 36px)
             - *Stack Equal / Push-Left (4-5 từ)*: `root.isCJK ? 31 : 36` (tăng từ 26 lên 31px)
             - *Push-Left Full (6+ từ)*: `root.isCJK ? 26 : 28` (tăng từ 22 lên 26px)
             - *Bento Pillar*: `root.isCJK ? 46 : 56` (tăng từ 38 lên 46px)
             - *Bento Top (Was/Doing)*: `root.isCJK ? 22 : 24` (tăng từ 18 lên 22px)
             - *Bento Better*: `root.isCJK ? 31 : 34` (tăng từ 26 lên 31px)
             - *Bento Alone*: `root.isCJK ? 36 : 42` (tăng từ 30 lên 36px)
             - *Vertical Stack*: `root.isCJK ? 29 : 34` (tăng từ 24 lên 29px)
             - *Giant Word (1 từ duy nhất thực sự)*: `root.isCJK ? 44 : 62` (tăng từ 36 lên 44px)
           - Đảm bảo lời bài hát tiếng Nhật, tiếng Trung, tiếng Hàn và tiếng Anh hiển thị đồng đều, tinh tế, vừa vặn hoàn hảo trên desktop.

26. **Động Cơ Syllable-Level Karaoke & Held Notes Elastic Scaling (Kế Thừa SimpMusic Footgun #217 & AMLL Architecture)**:
    - **Backend Bóc Tách Syllable Timestamps (`backend/lyrics_helper.py`)**:
      - Bóc tách thẻ `<mm:ss.xx>` chính xác từng từ/âm tiết, tính toán `start`, `end`, `duration` và nhận diện nốt ngân dài `isHeld: true` (thời lượng $\ge 0.85\text{s}$).
      - Khai thác trọn vẹn 627 bài hát Rich Syllable có sẵn trong local database; ưu tiên trả về trong 0.05s không độ trễ mạng.
    - **Frontend Flow Word Transform & SimpMusic Breath Curve (`YTMusicNowPlayingView.qml` & `AmberolDetailView.qml`)**:
      - **Kiến trúc Flow tách biệt từng từ**: Thay thế chuỗi text đơn dòng bằng `Flow { Repeater { delegate: Item (wordItem) } }`. Khóa cứng `lyricRow.scale = 1.0` (cấp câu), chỉ áp dụng GPU transform (`scale`, `y`) lên riêng bounding box của từ ngân dài `isHeld`.
      - **Độ dày font đồng nhất**: Giữ nguyên `font.weight: Font.Bold`, loại bỏ hoàn toàn `Font.Black` (900) để không làm vỡ nét hay dày cộm bất thường so với cả câu.
      - **Công thức nhịp thở quang học đã chốt thực nghiệm (SimpMusic Organic Curve)**:
        $$\text{bump} = \sin(\pi \times \text{wordProgress})^{2.0}$$
        $$\text{scale} = 1.0 + \text{bump} \times 0.008 \quad (+0.8\% / 1.008\text{x})$$
        $$y = -\text{bump} \times 1.5\text{px} \quad (\text{nhấc nhẹ 1.5px})$$
        Biên độ $+0.8\%$ tương đương ~1px viền trên font 28px kết hợp lũy thừa bậc 2 làm mềm hoàn toàn khởi đầu và kết thúc của nốt ngân. Người nghe cảm nhận được sự sống động tự nhiên theo nhịp hát của ca sĩ mà không thấy bị giật nảy hay phóng to thô bạo.
      - **Chống văng layout**: Bọc delegate trong `Item` cố định `width: wordTxt.implicitWidth` và `height: wordTxt.implicitHeight`, neo đáy `transformOrigin: Item.Bottom`, giúp transform chỉ diễn ra trên GPU raster layer mà không gây reflow layout xung quanh.
      - Tự động fallback mượt mà về text thông thường khi bài hát chỉ có LRC line-level.

27. **Hộp Thoại Cài Đặt CSS Shaded Frosted Glass & In-App Backdrop Blur (`components/SettingsModal.qml`)**:
    - **Cơ chế In-App Backdrop Blur (Khử triệt để lỗi xuyên hình nền desktop)**:
      - `ShaderEffectSource`: Bắt texture trực tiếp từ `mainContentBackdrop` (chứa toàn bộ HomeFeed cards, Music Videos, TopHeader, Playlists) tại đúng tọa độ hộp thoại (`sourceRect: Qt.rect(dialog.x, dialog.y, dialog.width, dialog.height)`).
      - Hiệu năng GPU tối ưu: Chỉ render offscreen đúng kích thước hộp thoại (600x560 px), tự động tắt hoàn toàn khi modal đóng (`live: root.visible`), 0% lãng phí tài nguyên.
      - `MultiEffect`: Làm mờ quang học 9-tap (`blur: 0.85`, `blurMax: 48`, `saturation: 1.15`) biến các card bài hát bên dưới thành phông nền màu sắc ambient mềm mại, sống động.
    - **Lớp Phủ Shaded Tint Chuẩn CSS & Độ Tương Phản WCAG AAA**:
      - Dựa trên đặc tả Compass CSS3 `.blurred-bg.shaded` kết hợp gradient 3 nấc: `linear-gradient(180deg, rgba(14,16,22,0.65), rgba(8,9,13,0.86))`.
      - Bảo đảm mọi nhãn chữ, công tắc switch và badge đều đạt tỷ lệ tương phản > 7:1 (chuẩn AAA) dù thẻ bài hát bên dưới có màu sáng hay tối.
    - **Khử Hoàn Toàn Các Lỗi Thị Giác & Bẫy Render**:
      - Triệt tiêu 100% thanh ngang specular sheen từng cắt ngang chữ "Tài khoản".
      - Xóa bỏ các khối chữ nhật drop shadow unblurred gây lỗi viền đen bậc thang.
      - Hairline border siêu mảnh 1px `rgba(255, 255, 255, 0.22)` kết hợp Top Specular Rim Sheen `1px rgba(255, 255, 255, 0.32)`.
    - **Sliding Capsule Pill & Bento Grid 2x2**:
      - Viên nang kính chuyển tab mượt mà `Easing.OutCubic` 240ms giữa "Tài khoản" và "Lời bài hát Desktop" ($R_{\text{con}} = 12 - 3 = 9\text{px}$).
      - Bento Grid 2x2 cho 4 Presets lời bài hát với Live Hover Micro-interaction (chữ tự động nảy/lướt nhẹ) và viền phát quang theo `accentColor`.
    - **Tuân Thủ Tuyệt Đối `ui-layout-design-rules`**:
      - Bo góc đồng tâm: Dialog ($R = 20$), Bento card ($R = 14$), Preview box ($R = 8$).
      - Hệ thống lưới khoảng cách 4px/8px, 100% icon SVG trắng sáng (`fill="#ffffff"`), zero emoji.

28. **Hệ Thống Đa Ngôn Ngữ Song Ngữ Toàn Diện (Strict Bimodal Localization Engine - `I18n.qml`) & Quản Lý Tệp Chuyển Ngữ**:
    - **Triết Lý Thiết Kế Singleton Trung Tâm (`components/I18n.qml`)**:
      - Quản lý trạng thái ngôn ngữ toàn cục qua `property string locale: "vi"` (hoặc `"en"`), đồng bộ bền vững với `~/.config/noctalia/nutsty_settings.json`.
      - Hàm dịch chuỗi tĩnh: `I18n.tr(vi, en)` — chuyển đổi tức thì không cần reload ứng dụng.
      - Bộ lọc & từ điển YouTube Music động:
        - `formatMoodChipTitle(title)`: Chuyển ngữ toàn bộ 30+ mood chips & thể loại (`Relax`, `Sleep`, `Energize`, `Sad`, `Romance`, `Focus`, `Party`, `Reading`, `Classical focus`, `Deep cuts`, `Popular`, `Down beat`, `Instrumental`, các thập niên `2000s`, `1990s`...).
        - `formatSectionTitle(title)`: Chuyển ngữ các danh mục trang chủ (`Recommended for you`, `Listen again`, `Quick picks`, `Mixed for you`, `Long listens`, `Music video for you`, `Trending community playlists`, `Peaceful bedtime`, `Gentle piano`, `Sweetheart & romance`, `Classical for sleeping`, `Rain sounds`, `Deep focus`, `Power boost`, `Kicking back`...).
        - Tự động bóc tách tiền tố/hậu tố động (`... Playlists` -> `... - Danh sách phát`, `Similar to ...` -> `Tương tự như ...`).
    - **Bộ Chọn Ngôn Ngữ Dark Glass Tối Giản (`components/SettingsModal.qml`)**:
      - Loại bỏ hoàn toàn outer border không cần thiết (`border.width: 0`), thiết kế phẳng tối giản phong cách Dark Glass.
      - Hiển thị ngôn ngữ hiện tại dạng viên thuốc `[ Tiếng Việt  ▾ ]` với icon mũi tên xoay mượt mà `go-down-symbolic.svg`.
      - Khi click: Mở Dropdown Popover Menu kính sẫm phủ sắc tố accent hữu cơ (`color: Qt.rgba(0.06 + accent.r * 0.08, ...)`), viền hairline đồng điệu, hiển thị danh sách ngôn ngữ động từ mảng `languages: [ { code: "vi", name: "Tiếng Việt" }, { code: "en", name: "English" } ]`.
      - Highlight màu `accentColor` cho ngôn ngữ đang chọn, có icon checkmark `emblem-ok-symbolic.svg`, hover highlight accent mềm mại. Triệt tiêu 100% màu xám đen chết. Dễ dàng mở rộng thêm ngôn ngữ mới trong tương lai.
    - **Tích Hợp Tên Tài Khoản Vào Lời Chào (`components/HomeFeedView.qml` & `shell.qml`)**:
      - `HomeFeedView` nhận thuộc tính `property string accountName: ""` (truyền từ `win.authAccountName` trong `shell.qml`).
      - Hàm `getGreeting()` tự động ghép tên tài khoản cùng khu vực lời chào ở đầu trang: *"Chào buổi sáng, Shiraori"*, *"Chào buổi chiều, Shiraori"*, *"Chào buổi tối, Shiraori"*.
      - Hàm `formatSectionSubtitle(sub)`: Tự động kiểm tra và ẩn subtitle nếu trùng với tên tài khoản (`root.accountName`), loại bỏ hoàn toàn chữ `SHIRAORI` hiển thị lẻ loi bên trên section *"Nghe lại"*.
    - **Khắc Phục Lỗi Đè Chữ Tab Trong `components/YTMusicNowPlayingView.qml`**:
      - Chuyển cụm tab điều hướng từ `RowLayout` sang `Row` (`spacing: 28`). Trong QtQuick, các item con trong `RowLayout` thiếu `Layout.preferredWidth` sẽ bị layout engine coi `implicitWidth = 0`, khiến tab bị dồn đè lên nhau khi chữ tiếng Việt dài hơn. `Row` thuần túy sắp xếp tuần tự theo chiều rộng thực tế của từng tab, giải quyết triệt để lỗi visual overlap.
    - **Danh Sách Các Tệp Đã Chuẩn Hóa Chuyển Ngữ (Dành Cho Việc Mở Rộng Thêm Ngôn Ngữ Sau Này Qua Git Diff)**:
      1. `components/I18n.qml`: Core translation engine, mood dictionary, section title dictionary, dynamic pattern matcher.
      2. `components/SettingsModal.qml`: Nhãn cài đặt, các tab Cài đặt, Bento Presets, bộ chọn ngôn ngữ dropdown.
      3. `components/HomeFeedView.qml`: Lời chào theo buổi, chip moods, carousels, section titles & subtitles.
      4. `components/YTMusicNowPlayingView.qml`: Cụm tabs (Tiếp theo, Lời bài hát, Liên quan), Up Next chips, các nhãn radio.
      5. `components/PlayerBarBottom.qml`: Tooltips điều khiển, nguồn phát âm thanh (Local/YouTube), nhãn chế độ.
      6. `components/NavSidebar.qml`: Nhãn Playlists, Queue, danh mục danh sách phát.
      7. `components/DownloadQueuePopover.qml`: Tiêu đề hàng đợi tải xuống, trạng thái tiến độ, nút xóa, nút mở thư mục.
      8. `components/AmberolDetailView.qml`: Thông tin bài hát, nút điều khiển Amberol, nhãn thời lượng.
      9. `components/TrackContextMenu.qml`: Menu chuột phải (Phát tiếp theo, Thêm vào hàng đợi, Tải xuống, Xóa vĩnh viễn...).
29. **Động Cơ Bìa Album Động Apple Music (Apple Music Animated Album Artwork Video Loop Suite - Item 25)**:
    - **Kiến Trúc Tích Hợp Đa Tầng (SimpMusic Footgun #212 & Apple Music HLS Video Stream)**:
      - *Mô hình hoạt động*: Kế thừa giải pháp kỹ thuật từ SimpMusic (`getAMAnimatedArtwork` trong `LyricsCanvasRepositoryImpl.kt` và `NowPlayingContentAppleMusic.kt`).
      - *Backend Daemon (`backend/ytmusic_helper.py`)*:
        - Hàm `get_apple_music_animated_artwork(title, artist, duration_seconds, album_hint)`:
        - Bóc tách token web player Apple Music từ `music.apple.com/assets/index~*.js`.
        - **Khắc phục triệt để lỗi gán nhầm bìa động (SimpMusic pickSongMatch Architecture - Zero False Positives)**:
          - *Nguyên nhân lỗi cũ*: Search API của Apple Music trả về danh sách bài hát và album theo độ phổ biến (ranking) chứ không phải đáp án chính xác. Mã nguồn cũ trước đây không lọc tên bài hát và nghệ sĩ trên tập bài hát trả về, đồng thời có vòng lặp fallback duyệt qua toàn bộ `albums.items()` để lấy bất kỳ album nào có `editorialVideo`. Điều này khiến các bài hát như *"Anh Sai Rồi"* (Sơn Tùng) bị gán nhầm bìa *"Come My Way"*, và *"Em Của Ngày Hôm Qua"* bị gán nhầm bìa *"Show Của Đen"* (Đen Vâu).
          - *Thuật toán bảo vệ đa tầng theo SimpMusic*:
            1. `clean_for_search(text)`: Loại bỏ các thẻ phụ đề `(feat. ...)`, `[Official MV]`, `(Lyrics)`...
            2. `normalize_for_match(text)`: Giữ lại toàn bộ ký tự chữ cái (hỗ trợ Unicode tiếng Việt đầy đủ) và số qua `c.isalnum()`, thay dấu câu bằng khoảng trắng.
            3. `artist_agrees(cand_artist, query_artist)`: Kiểm tra độ đồng điệu của nghệ sĩ (`matches_loosely` và tập hợp từ $\ge 50\%$).
            4. `match_score(candidate, subject)`: Phân cấp độ khớp tên bài hát thành 4 Tier (0: Trùng khớp tuyệt đối; 1: Bắt đầu bằng tiền tố; 2: Chứa chuỗi con; 3: Chuỗi cha). Nếu không thuộc 4 Tier này $\rightarrow$ Loại bỏ ngay lập tức.
            5. `demote`: Phạt điểm nếu thời lượng lệch $> 5.5\text{s}$ (+4 điểm) hoặc không khớp `album_hint` (+2 điểm) hoặc album không có bìa động (+1 điểm).
            6. **Chỉ kiểm tra `editorialVideo` trên album thuộc về bài hát được chọn**: Tuyệt đối không fallback sang các album trôi nổi khác trong response. Nếu bài hát trùng khớp không có bìa động $\rightarrow$ Trả về `{"found": false}` ngay lập tức để giao diện hiển thị ảnh bìa tĩnh mượt mà.
            7. **Ưu tiên Storefront kép (`vn` $\rightarrow$ `us`)**: Truy vấn kho `vn` trước (đầy đủ ca khúc Việt Nam lẫn quốc tế chất lượng cao), nếu không có bài hát trùng khớp mới fallback sang `us`.
        - Chọn rendition HLS video `.m3u8` chất lượng cao 768x768 AVC1 qua hàm `select_am_rendition(master_url)` và lưu đệm 7 ngày vào `~/.cache/nutsty/animated_artworks.json`.
      - *Frontend Render Engine (`components/YTMusicNowPlayingView.qml`)*:
        - **Khắc phục lỗi thiếu `videoOutput`**: Trong Qt 6 `QtMultimedia`, `MediaPlayer` bắt buộc phải khai báo thuộc tính `videoOutput: amVideoOutput`. Nếu thiếu thuộc tính này, `MediaPlayer` không thể truyền video frames tới `VideoOutput`, dẫn đến việc video không hiển thị.
        - **Hoạt ảnh chuyển tiếp mượt mà (Smooth Crossfade)**:
          - Khắc phục lỗi `visible: <boolean>` làm ngắt hoạt ảnh `opacity`. Sử dụng công thức chuẩn:
            `visible: opacity > 0.01`
            `opacity: (root.animatedCoverEnabled && root.animatedArtworkUrl !== "" && (amPlayer.playbackState === MediaPlayer.PlayingState || amPlayer.playbackState === MediaPlayer.PausedState)) ? 1.0 : 0.0`
            `Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }`
          - Khi bài hát bắt đầu phát hoặc chưa tải xong video, ảnh tĩnh `bigCoverImg` hiển thị bên dưới. Khi video tải xong và phát, `VideoOutput` chuyển tiếp mượt mà 400ms đè lên ảnh tĩnh.
        - **Đồng bộ hóa Play/Pause thông minh (`Connections`)**:
          - Khi tạm dừng bài hát, `amPlayer.pause()` giữ nguyên khung hình hiện tại trên màn hình thay vì biến mất đột ngột.
          - Khi đóng màn hình Now Playing hoặc ẩn cửa sổ (`root.visible === false`), tự động pause video để tiết kiệm 100% tài nguyên giải mã GPU.
        - **Chuẩn hóa Duration Parsing**:
          - Phân giải an toàn `root.track.durationMs / 1000` hoặc parse chuỗi `mm:ss` thành số giây thực tế, tránh truyền `NaN` vào tiến trình bóc tách Python.
        - **Cơ chế Cold-Open Trigger**:
          - Trong `onVisibleChanged`: Tự động kích hoạt `fetchAnimatedArtwork()` nếu người dùng mở màn hình Now Playing khi bài hát đã đang phát từ trước.

30. **Hệ Thống Lịch Sử Tra Tìm Bài Hát Bền Vững (Persistent Search History & Minimalist Clean Dark Glass List - Item 27)**:
    - **Lưu Trữ Bền Vững & Thuật Toán MRU**:
      - Lưu trữ danh sách JSON tại: `~/.config/noctalia/nutsty_search_history.json`.
      - Thuật toán Most Recently Used (MRU): Giới hạn tối đa 20 từ khóa gần nhất. Khi tìm kiếm từ khóa mới, tự động đưa lên đầu danh sách; nếu từ khóa đã tồn tại trong lịch sử (so khớp không phân biệt hoa thường), tự động di chuyển lên đầu danh sách và loại bỏ mục cũ.
      - Chuẩn hóa khoảng trắng: Biểu thức `replace(/\s+/g, " ").trim()` tự động triệt tiêu khoảng trắng thừa, tab và ký tự ngắt dòng khi paste văn bản.
      - Đồng bộ hóa 0ms qua Quickshell `FileView` và cơ chế ghi atomic bất đồng bộ qua Python `tempfile` + `os.replace`.
      - **Cơ Chế Tự Bảo Vệ Chống Race Đĩa (Self-Reload Guard)**:
        - Quản lý qua `lastSavedJson` và `lastSaveTime` (khung thời gian 600ms).
        - Khi người dùng thao tác xóa/chọn liên tiếp, tín hiệu `onFileChanged` từ hệ thống tập tin đĩa trễ sẽ bị chặn, ngăn hoàn toàn tình trạng nạp lại dữ liệu cũ đè lên dữ liệu mới trong RAM.
    - **Giao Diện Dark Glass Danh Sách Dòng Tối Giản (`components/CategorizedSearchView.qml`)**:
      - Khi ô tìm kiếm trống (`searchText.trim().length === 0` và không có preeditText): Tự động hiển thị phân khu Lịch sử tìm kiếm thay cho màn hình trống.
      - *Header Lịch sử*:
        - Tiêu đề: `I18n.tr("Lịch sử tìm kiếm", "Search history")`.
        - Nút hành động "Xóa tất cả" / "Clear all": Áp dụng chuẩn **Destructive Muted Rose** (nền đỏ hoa hồng dịu `rgba(244, 63, 94, 0.12)`, viền `rgba(244, 63, 94, 0.26)`, text `#fda4af`, hover sáng). Nút này tự động ẩn khi lịch sử trống.
      - *Dòng Lịch Sử (History Row)*:
        - Chiều cao 40px, bo góc 8px.
        - Bên trái: Icon đồng hồ `assets/icons/document-open-recent-symbolic.svg`.
        - Ở giữa: Text từ khóa (font 14px, màu trắng `#ffffff`, elided khi vượt quá độ dài, an toàn tuyệt đối khi modelData giải phóng).
        - Bên phải: Nút xóa nhanh ✕ (`assets/icons/window-close-symbolic.svg`) tự động sáng rõ khi hover vào dòng hoặc khi dòng được highlight bằng bàn phím. Vùng bấm cảm ứng (hit target) mở rộng $38\times 38\text{px}$ qua `anchors.margins: -6` chống bấm nhầm trên màn hình cảm ứng.
        - Hiệu ứng Highlight: Nền kính đổi màu thích ứng theo `accentColor` (`Qt.rgba(accent.r, accent.g, accent.b, 0.12)` khi hover chuột, `0.18` khi chọn bằng phím).
        - Tương tác: Click vào dòng lịch sử sẽ tự động gán từ khóa vào ô tìm kiếm và kích hoạt tìm kiếm bài hát tức thì; click vào nút ✕ xóa riêng mục đó ngay lập tức.
      - *Điều Hướng Bàn Phím Toàn Diện (Keyboard Navigation)*:
        - `ArrowDown` / `ArrowUp`: Duyệt vệt sáng highlight qua các mục lịch sử, tự động chặn tràn biên và trở về -1 để lấy lại focus ô nhập liệu.
        - Hàm `ensureHistoryVisible(idx)`: Tính toán hình học viewport ($44 + idx \times 46\text{px}$) tự động cuộn `historyFlickable.contentY` mượt mà khi di chuyển vượt quá mép khung nhìn.
        - Phím `Enter`: Kích hoạt tìm kiếm ngay lập tức với từ khóa đang highlight và đưa lên đầu MRU.
        - Phím `Delete`: Xóa tức thì mục đang highlight khỏi lịch sử mà không cần chuột.
        - Phím `Escape`: Hủy chọn highlight đưa con trỏ về ô nhập liệu, hoặc xóa text, hoặc quay lại view trước.
      - *Trạng Thái Trống (Empty State)*:
        - Hiển thị thông điệp nhẹ nhàng `I18n.tr("Chưa có lịch sử tìm kiếm", "No recent searches")` kèm phụ đề hướng dẫn căn giữa khung nhìn.
39. **Chuẩn Hóa Kích Thước Bố Cục Toolbar, Bộ Lọc Sắp Xếp Toàn Diện & Khử Lớp Nền Trắng Bìa Album (Item 39)**:
    - **Khắc Phục Đè Chữ Tiếng Việt Trong Thanh Công Cụ (`components/MainTrackGrid.qml`)**:
      - *Nguyên nhân*: Các nút `Rectangle` con trong `RowLayout` chỉ khai báo `width` mà không khai báo `implicitWidth` hoặc `Layout.preferredWidth`. Khi chuyển sang tiếng Việt, chuỗi "Phát ngẫu nhiên" dài hơn nhiều so với "Shuffle", khiến `RowLayout` dùng `implicitWidth = 0` và đặt nút "Hàng đợi" đè lên chữ của nút trước.
      - *Giải pháp*: Chuẩn hóa toàn bộ các nút con (`playBtn`, `shuffleBtn`, `queueBtn`, `dlAlbBtn`) khai báo tường minh `implicitHeight: 36`, `implicitWidth: row.implicitWidth + 28`, `Layout.preferredHeight: 36`, và `Layout.preferredWidth: implicitWidth`. Các hàng bên trong chuyển từ `RowLayout` sang `Row` với `anchors.centerIn: parent` và `spacing: 8` để QtQuick tự động tính toán kích thước tự nhiên chính xác 100%.
    - **Kích Hoạt Sắp Xếp Toàn Diện & Sửa Lỗi Tràn Nút Nghệ Sĩ (`components/MainTrackGrid.qml`)**:
      - *Tính năng Sắp xếp*: Gỡ bỏ điều kiện chặn `if (!isDownloadsView) return list;` trong `sortedTracks`. Cho phép sắp xếp mượt mà trên tất cả các chế độ xem:
        - `recent` ("Mới nhất"): Sắp xếp theo `mtime` trên Downloads; giữ nguyên thứ tự tracklist gốc của album / playlist.
        - `title` ("Tên A-Z"): Sắp xếp theo bảng chữ cái qua `localeCompare`.
        - `artist` ("Nghệ sĩ"): Sắp xếp theo tên ca sĩ / nghệ sĩ qua `localeCompare`.
      - *Sửa Lỗi Tràn Mép Phải*: Chuyển `sortInnerRow` sang `Row` với `spacing: 4`, padding 4px; container `sortControlBox` khai báo `implicitWidth: sortInnerRow.implicitWidth + 16` và `Layout.preferredWidth: implicitWidth`. Các pill con có `implicitWidth: text.implicitWidth + 24`, giúp căn lề hoàn hảo, nằm gọn gàng bên trong hộp kính và không bao giờ bị cắt chữ hay lòi sang phải.
    - **Khử Lớp Nền Trắng Bìa Album Phủ Đè Lên Nền App (`shell.qml`)**:
      - *Nguyên nhân*: `playingBackdropCover` vô tình bị đổi điều kiện kích hoạt thành `(win.currentTrack && win.isPlaying)`, khiến khi duyệt album/home trong lúc phát nhạc, ảnh bìa phóng to bị phủ đè lên toàn bộ cửa sổ. Với các bài hát có bìa nhiều mảng trắng như "RASEN", ảnh bìa tạo ra lớp nền trắng xám loang lổ đè lên lớp nền Dark Acrylic sâu thẳm của app.
      - *Giải pháp*: Đưa điều kiện hiển thị về chuẩn thiết kế gốc: `(win.isNowPlayingOpen && win.currentTrack)`. Khi duyệt nhạc bình thường, nền của app luôn giữ 100% màu Dark Acrylic nguyên bản của Nutsty, xóa sạch hiện tượng 2 lớp nền và vệt trắng bao quanh.

---

## 5. Quy Chuẩn Kiểm Tra Trước Khi Hoàn Thành (Mandatory Verification)

1. Cú pháp QML: `qmllint components/*.qml shell.qml` (phải đạt 0 lỗi).
2. Cú pháp Python: `python3 -m py_compile backend/*.py`.
3. Kiểm tra trực quan: Chụp màn hình bằng `/usr/bin/grim` -> xem bằng `view_file`.
4. Git push: Luôn commit và push lên `git@github.com:trancongduyhieu/Nutsty.git` (nhánh `main`).

