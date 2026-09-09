# AGENT.md - Frostify Local Pair-Programming Guide

Tài liệu đặc tả toàn diện về kiến trúc, cấu trúc thư mục, quy chuẩn mã nguồn, các quyết định thiết kế cốt lõi và hướng dẫn vận hành dự án **Frostify Local** dành cho các AI Agent / Assistant trong các session làm việc tiếp theo.

---

## 1. Tổng Quan Dự Án (Project Overview)

**Frostify Local** là trình phát nhạc cục bộ và máy tính để bàn (Desktop Music & Streaming Player) được tối ưu hóa chuyên sâu cho môi trường Linux Wayland (Niri compositor), kết hợp giữa:
- **Giao diện người dùng Spotify/Amberol hiện đại**: Viết bằng **Quickshell (Qt 6 / QML)** với khả năng tăng tốc GPU phần cứng và hỗ trợ native Wayland layer-shell.
- **Backend phát nhạc độ trễ thấp**: Trình điều khiển **Python IPC daemon** (`backend/player_daemon.py`) giao tiếp trực tiếp qua Unix Domain Socket (`/tmp/frostify_mpv.sock`) với một tiến trình `mpv` chuyên biệt (hỗ trợ gapless playback, hardware decoding, flac/m4a/opus/mp3/ytdl streams).
- **Desktop Lyrics ma thuật phong cách Gacha/Anime**: Hiển thị lyric nổi trực tiếp lên hình nền desktop (tọa độ trên tà váy nhân vật/vùng hạ tiêu cự) với font chữ cổ điển *Instrument Serif*, hiệu ứng pop chữ gacha và đổ bóng điện ảnh thích ứng màu sắc hình nền.
- **Bộ máy màu sắc thích ứng Chromatic Salience (OKLAB / OKLCH)**: Trích xuất màu điểm nhấn nghệ thuật (màu tóc, má hồng, mắt, trang phục) từ hình nền hiện tại và cập nhật theo thời gian thực vào `~/.config/noctalia/frostify_palette.json`.

---

## 2. Cấu Trúc Thư Mục (Repository Structure)

```
/home/apple/Applications/FrostifyLocal/
├── run.sh                          # Script khởi chạy 1-chạm (tự quét nhạc và chạy quickshell)
├── shell.qml                       # Entry point QML chính (FloatingWindow Spotify + DesktopLyricsWidget)
├── library.json                    # Dữ liệu cache danh sách bài hát, metadata và album
├── assets/                         # Font chữ Instrument Serif, icon SVG, dữ liệu tĩnh
├── backend/
│   ├── library.py                  # Bộ quét thư viện nhạc (~/Music) sử dụng Mutagen
│   ├── lyrics_helper.py            # Trích xuất và phân giải file LRC đồng bộ
│   ├── palette_extractor.py        # Thuật toán OKLAB Chromatic Salience Clustering
│   └── player_daemon.py            # CLI wrapper điều khiển mpv qua /tmp/frostify_mpv.sock
├── components/
│   ├── AmberolDetailView.qml       # Màn hình chi tiết bài hát, đĩa xoay và lyric cuộn Amberol
│   ├── DesktopLyricsWidget.qml     # Widget lyric nổi trên màn hình desktop (Wayland Layer Shell)
│   ├── EnchantingSentence.qml      # Component từng câu lyric: staggered baselines, Gacha pop, đổ bóng
│   ├── LibraryData.qml             # Model quản lý danh sách bài hát trong QML
│   ├── LibraryLoader.qml           # Loader nạp dữ liệu từ library.json
│   ├── ParticleBackground.qml      # Hiệu ứng hạt nền ambient
│   ├── PlayerBar.qml               # Thanh phát nhạc điều khiển cơ bản
│   ├── SpotifyHeader.qml           # Thanh tìm kiếm và tab lọc Spotify
│   ├── SpotifyMainGrid.qml         # Grid danh sách bài hát và card hiển thị
│   ├── SpotifyPlayerBar.qml        # Thanh phát nhạc chính Spotify (thời lượng, âm lượng, Amberol button)
│   ├── SpotifySidebar.qml          # Sidebar điều hướng playlist, thư viện
│   ├── Theme.qml                   # Hệ thống token màu, kích thước bo góc, padding
│   ├── TrackCard.qml               # Card hiển thị từng bài hát trong grid
│   └── TrackRow.qml                # Dòng hiển thị bài hát trong danh sách hàng đợi
├── AGENT.md                        # File này (chỉ dẫn dành cho AI)
└── TODO.md                         # Danh sách tính năng và lộ trình phát triển tiếp theo
```

---

## 3. Kiến Trúc Kỹ Thuật Chi Tiết (Technical Architecture)

### 3.1. Frontend: Quickshell (Qt 6 / QML)
- Chạy bằng binary `/usr/bin/quickshell -p /home/apple/Applications/FrostifyLocal/shell.qml`.
- `shell.qml` chứa 2 thành phần cửa sổ độc lập:
  1. `FloatingWindow { id: win }`: Cửa sổ ứng dụng chính (Spotify client UI).
  2. `DesktopLyricsWidget { id: desktopLyrics }`: Window dạng layer desktop nổi không viền (`PanelWindow`), gắn vào desktop compositor, không bắt chuột (`mask: Region {}` hoặc click-through), tự động sync theo `win.currentTime` và `win.activeLyrics`.

### 3.2. Hiệu Ứng Desktop Lyrics & Typography
- **Font chữ**:
  - Tiếng Anh: *Instrument Serif* (tải từ `assets/fonts/InstrumentSerif-Regular.ttf` & `Italic.ttf`).
  - Tiếng Việt: Tự động fallback sang *Noto Serif* qua regex `hasVietnamese`.
- **Baseline Staggering**: Các từ trong câu không nằm trên một đường thẳng cứng nhắc mà được lệch nhẹ sole tự nhiên: `[-2.5, 3.5, -2.0, 2.5, -3.0, 2.0, -1.5, 2.5]px` theo phong cách Harry Potter / Swing Lynn.
- **Gacha Pop In & Out**:
  - Từ đang hát nhảy nảy nhẹ (`wordScale: 0.88 -> 1.06 -> 1.0`) kèm hiệu ứng chuyển màu từ trắng ngà sang màu ngọc highlight trong 240ms.
  - Câu đã hát xong (`colDeadText: #f1f5f9`) hạ thấp sâu `+52px` về phía dưới, nghiêng hữu cơ `1.8°` và mờ dần trong 1.6 giây trước khi biến mất.
- **Universal Cinematic Drop Shadows (Chuẩn Điện Ảnh)**:
  - **TUYỆT ĐỐI KHÔNG DÙNG VIỀN TRẮNG (White Halo)**: Không bao giờ dùng viền sáng bao quanh chữ vì gây nhòe mờ và kém sang.
  - **Lớp bóng 1 (Ambient Deep Diffuse)**: Offset `+3.5px`, màu `#66000000` tạo chiều sâu không gian.
  - **Lớp bóng 2 (Directional Sharp)**: Offset `+1.2px, +1.8px`, màu `#a6020305` tạo độ nổi khối sắc nét trên mọi nền sáng/tối.

### 3.3. Bộ Máy Trích Xuất Màu Sắc (Chromatic Salience trong OKLAB)
- Nằm tại: `backend/palette_extractor.py`.
- Được gọi tự động bởi Noctalia theme hook: `~/.config/noctalia/apply_theme.sh` mỗi khi người dùng đổi hình nền.
- **Thuật toán**:
  1. Chuyển đổi màu sắc sRGB $\rightarrow$ Linear RGB $\rightarrow$ OKLAB / OKLCH.
  2. Lọc bỏ toàn bộ pixel trung tính/xám xịt với ngưỡng Chroma $C \ge 0.028$.
  3. Phân cụm K-Means ($k=4$) trên các pixel sắc độ.
  4. Lựa chọn màu theo điểm thị giác $S = N^{0.35} \times C$ (ưu tiên các chi tiết nhỏ nhưng rực rỡ như mái tóc, màu mắt, má hồng của nhân vật anime).
  5. Chuẩn hóa về dải màu đá quý phát quang (*Luminous Jewel Tone*): Độ sáng $L = 0.82$, Sắc độ $C \in [0.08, 0.12]$.
  6. Xuất cấu hình ra `~/.config/noctalia/frostify_palette.json` và `assets/frostify_palette.json`.

### 3.4. Backend Điều Khiển Âm Thanh (mpv IPC)
- Quickshell định kỳ kích hoạt `backend/player_daemon.py status` để lấy trạng thái JSON:
  `{"is_playing": true, "time_pos": 16.5, "duration": 186.0, "filename": "...", "volume": 100.0}`.
- Các lệnh điều khiển:
  - Play / Pause: `python3 backend/player_daemon.py toggle`
  - Seek: `python3 backend/player_daemon.py seek <seconds>`
  - Volume: `python3 backend/player_daemon.py volume <0-100>`
  - Next / Prev / Play Track: `python3 backend/player_daemon.py play <file_path>`

---

## 4. Các Công Cụ & Thư Viện Liên Quan Trong Hệ Thống

1. **`adb` (Android Debug Bridge)**:
   - Đường dẫn: `/home/apple/.local/bin/adb`.
   - Thiết bị Android đã gắn kết nối: ID `2bd3dce5`.
   - Mục đích: Kéo trực tiếp các bài hát mới tải về từ SimpMusic trên điện thoại (`/storage/emulated/0/...`) về máy tính.
2. **`anpan` (Universal Media Downloader)**:
   - Đường dẫn: `/home/apple/.local/bin/anpan`.
   - Cú pháp: `anpan -o ~/Music/Downloads_Phone <url>` (hỗ trợ YouTube, YT Music, SoundCloud, Twitter, v.v.).
3. **Mã nguồn tham khảo SimpMusic**:
   - Vị trí clone: `/home/apple/Applications/SimpMusic/`.
   - Tài liệu kỹ thuật chi tiết: `/home/apple/Applications/SimpMusic/CLAUDE.md`.
   - Kỹ thuật cốt lõi để học hỏi:
     - Giải mã chữ ký số YouTube Innertube / `player_configs.json` / QuickJS cipher engine.
     - Cơ chế hàng đợi (Queue), Play Next, và Context Menu tương tác.

---

## 5. Quy Chuẩn Phát Triển & Kiểm Tra Cho AI (Dev Rules)

1. **Universal Portability & Không Hardcode**:
   - Tuyệt đối không hardcode đường dẫn tuyệt đối tĩnh trong QML/Python.
   - Luôn sử dụng `Quickshell.env("HOME")`, `Path.home()`, `os.path.expanduser("~")`.
2. **Quy Trình Kiểm Tra Bắt Buộc Trước Khi Commit**:
   - Cú pháp QML: `qmllint components/*.qml shell.qml` (phải đạt 0 lỗi).
   - Cú pháp Python: `python3 -m py_compile backend/*.py`.
   - Kiểm tra trực quan: Chụp ảnh bằng `/usr/bin/grim` -> xem bằng `view_file` trước khi báo cáo hoàn tất.
3. **Quản Lý Phiên Bản Git**:
   - Remote: `origin` -> `git@github.com:trancongduyhieu/FrostifyLocal.git` (nhánh `main`).
   - Luôn commit sạch, rõ ràng sau mỗi tính năng hoàn thành.
