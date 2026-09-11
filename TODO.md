# TODO.md - Lộ Trình Phát Triển Chi Tiết (Frostify Local)

Tài liệu quản lý tác vụ (Roadmap & Todo List) cho Frostify Local. Đã được làm rõ 100% qua quy trình phỏng vấn (/grill-me) cùng người dùng.

---

## Danh Sách Các Hạng Mục Tiếp Theo Đang Triển Khai

- [x] **2. Sửa Thanh Trượt Âm Lượng & Thời Lượng (Draggable Scrubbing)**
  - *Đã hoàn thành*: `components/SpotifyPlayerBar.qml` hỗ trợ kéo rê thumb thanh thời lượng và âm lượng theo thời gian thực (MouseArea `onPressed`, `onPositionChanged`, `onReleased` với `preventStealing: true`), mở rộng hit area 16px để thao tác nhạy, cập nhật text thời gian mượt mà không bị xung đột binding với daemon.

- [x] **3. Bộ Lấy Lyric Tự Động Từ Internet (Online Synced Lyrics Fallback)**
  - *Đã hoàn thành*: Tích hợp thư viện Python `syncedlyrics` với kiến trúc phân tầng: Cache `.lrc` $\rightarrow$ Online (LRCLIB $\rightarrow$ NetEase $\rightarrow$ Musixmatch) $\rightarrow$ Dự phòng cuối cùng (SimpMusic SQLite DB). Tự động lưu cache file `.lrc` vào `~/.cache/frostify/lyrics/` để nạp offline trong ~30ms.

- [ ] **4. Bảng Điều Khiển Desktop Lyrics (Bật/Tắt & Tinh Chỉnh Màu)**
  - *Cấu hình*: Lưu trạng thái trong `~/.config/noctalia/frostify_settings.json`.
  - *Tính năng*: Nút gạt Toggle On/Off desktop lyrics; Chuyển đổi giữa chế độ `Auto (Wallpaper Adaptive)` và chế độ `Manual (Tự chọn mã màu highlight)`.

- [x] **5. Trình Quản Lý & Tải Nhạc Đa Luồng SimpMusic (SimpMusic Style Download Manager Daemon & Minimalist Popover - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Daemon & Worker Loop**: `backend/download_manager.py` chạy thường trú độc lập, giao tiếp socket IPC `/tmp/frostify_download.sock` và file trạng thái nguyên tử `/tmp/frostify_download_status.json`.
    - **Trích xuất & Tagging chuyên sâu**: Sử dụng `yt-dlp` + FFmpeg trích xuất âm thanh 192k AAC/M4A, nhúng bìa album chất lượng cao qua FFmpeg (`-an -frames:v 1 -update 1`) và gắn tag ID3 đầy đủ; tự động tải synced lyrics (`.lrc`) đi kèm bài hát.
    - **Hàng đợi tải đa tiến trình**: Theo dõi tiến trình tải theo thời gian thực (Tốc độ MB/s, Thời gian còn lại ETA, Phần trăm hoàn thành %) với độ trễ 0ms.
    - **Giao diện Popover Minimalist Clean**: `components/DownloadQueuePopover.qml` chuẩn Spotify Desktop (#121212, bo góc 8px, thanh progress 3px bo tròn), nút hủy tải từng bài, nút mở thư mục nhạc `~/Music/Downloads_Phone` (`folder-music-symbolic.svg`), nút dọn sạch danh sách đã tải xong (`edit-clear-all-symbolic.svg`) kèm Tooltip giải thích trực quan khi rê chuột.
    - **Header Pill & Con quay động**: `components/SpotifyHeader.qml` hiển thị pill tải nhạc với số lượng bài đang tải thực tế (`activeTasksCount`) và con quay `CircularSpinner.qml` xoay tròn khi đang có tác vụ tải.
    - **Desktop Notification**: Tự động thông báo qua `notify-send` kèm tên bài hát khi hoàn thành.

- [x] **6. Menu Chuột Phải & Quản Lý Hàng Đợi (Context Menu & Queue từ SimpMusic - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Tạo mới component `components/TrackContextMenu.qml` phong cách Dark Glass sang trọng, 100% SVG tượng trưng chuẩn hệ thống (TUYỆT ĐỐI KHÔNG DÙNG EMOJI), tự động căn chỉnh mép cửa sổ (auto-clamping) và backdrop dismiss.
    - Đầy đủ 5 tác vụ tiêu chuẩn kế thừa từ SimpMusic:
      1. *Phát tiếp theo (Play next)*: Chèn bài ngay sau bài đang phát trong hàng đợi.
      2. *Thêm vào hàng đợi (Add to queue)*: Thêm bài hát vào cuối hàng đợi phát nhạc.
      3. *Bắt đầu radio (Start radio)*: Tự động khởi tạo automix radio dựa trên bài hát.
      4. *Mở thư mục / Tải nhạc*: Tự động hiển thị "Open containing folder" với bài local hoặc "Download track" qua `anpan` với bài online.
      5. *Xóa khỏi hàng đợi / Xóa thư viện*: "Remove from queue" (khi click trong tab Queue của Sidebar) hoặc "Delete from library" (với bài local) hiển thị chữ đỏ cảnh báo.
    - Tích hợp kết nối sự kiện chuột phải trên toàn bộ các điểm chạm: `TrackCard.qml`, `TrackRow.qml`, `SpotifyMainGrid.qml`, `HomeFeedView.qml` (QuickPicks Grid, Section Carousel Cards, Fallback Grid), và `SpotifySidebar.qml` (Queue tab).

- [x] **7. Hoàn Thiện Tính Năng Album (Interactive Albums từ SimpMusic - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Metadata & Normalization**:
      - `backend/ytmusic_helper.py`: Bổ sung hàm `get_album_details(browse_id)` bóc tách đầy đủ cấu trúc album (ID, browseId, title, artist, year, type, trackCount, duration, ảnh phân giải cao 544x544 `w544-h544-l90-rj`, và mô tả Wikipedia/ghi chú album) kèm danh sách toàn bộ bài hát đã chuẩn hóa. Thêm endpoint CLI `album <browse_id>` và `search_albums <query>`.
      - `backend/library.py`: Bổ sung trích xuất tag `album` và `year` từ metadata ffprobe; hàm `get_grouped_albums()` phân nhóm toàn bộ bài hát cục bộ theo album thực tế hoặc danh mục đĩa đơn nghệ sĩ. Thêm endpoint CLI `albums`.
    - **Giao diện Hero Album Banner & Toolbar (`components/SpotifyMainGrid.qml`)**:
      - Bìa album lớn 160x160 với bóng đổ sâu điện ảnh và gradient fallback khi đang tải.
      - Huy hiệu loại phát hành động (`ALBUM` / `SINGLE` / `EP`), tiêu đề album lớn 26px đậm, phụ đề đầy đủ `Nghệ sĩ • Năm • Số bài hát • Thời lượng tổng` và mô tả album rút gọn.
      - Cụm 4 nút hành động bo tròn chuẩn SimpMusic / Spotify Desktop:
        1. `[ ▶ Phát ]`: Bắt đầu phát toàn bộ album tuần tự từ bài đầu tiên (track index 0).
        2. `[ 🔀 Phát ngẫu nhiên ]`: Xáo trộn và phát toàn bộ album.
        3. `[ + Hàng đợi ]`: Thêm toàn bộ các bài hát trong album vào cuối hàng đợi phát hiện tại (`win.currentTracks`).
        4. `[ 📥 Tải Album ]`: Tự động nạp hàng loạt bài hát trong album vào daemon tải nhạc `download_manager.py` (chỉ hiển thị cho album online).
      - **Downloads Sub-Tab Switcher**: Bộ lọc hai chế độ `[ Bài hát (N) ]` | `[ Albums (N) ]` trong tab Downloads, cho phép duyệt và mở nhanh toàn bộ album đã lưu trong máy.
    - **Home Feed & Shell State Routing**:
      - `components/HomeFeedView.qml`: Nhận diện và điều hướng click card album sang chế độ xem chi tiết album.
      - `shell.qml`: Điều phối các tác vụ `loadAlbumDetails()`, `addTracksToQueue()`, `downloadEntireAlbum()`, `refreshLocalAlbums()` và nút quay lại (Back) dọn dẹp view sạch sẽ.

- [x] **8. Phát Nhạc Trực Tuyến & Bóc Tách Thuật Toán Gợi Ý SimpMusic (Online Streaming & Personalized Feed - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*: 
    - **Thuật toán gợi ý Hybrid thông minh (SimpMusic Adaptation)**:
      - Khi chưa kết nối Google Account: Tự động học gu nghe nhạc cục bộ từ `frostify_session.json` / `library.json`, gọi `ytmusic.get_watch_playlist(videoId)` tạo ra 12–20 bài "Quick picks" (Radio mix) cá nhân hóa 100% thay vì các bài trending rác.
      - Khi kết nối Google Account: Gọi `ytmusic.get_home()` mang lại trang chủ chuẩn xác theo tài khoản cá nhân.
      - Bấm vào bài hát Quick Pick tự động khởi tạo hàng đợi Automix Radio (`get_watch_playlist`).
    - **Mặc định mở app ở chế độ Online**: Khởi động trực tiếp vào giao diện Home feed (`currentView: "home"`).
    - **Giao diện 3 cột chuẩn Desktop (SimpMusic Image 2 Layout)**:
      - Cột 1 (Sidebar trái - 240px): 3 nút chính gồm "Home (Online)", "Downloads (Local)", "Settings & Account" (đã loại bỏ hoàn toàn Mix & Analytics), bên dưới là "Local Collections".
      - Cột 2 (Center Content): Lời chào theo buổi ("Good Evening/Morning/Afternoon"), 11 Mood Pills ("All", "Relax", "Sleep", "Energize", "Sad", "Romance", "Feel Good", "Workout", "Party", "Commute", "Focus"), lưới 3 cột Quick picks, và lưới Featured Playlists.
      - Cột 3 (Right Collapsible Panel - 360px): Now Playing panel có switch [Lyrics | Artwork], hiển thị lyric cuộn Amberol hoặc ảnh bìa nghệ thuật chất lượng cao, có thể bật/tắt qua nút Details trên player bar.
    - **Bảo mật tối đa (No Browser-Sniffing)**: Tuyệt đối không đọc trộm cookie từ profile trình duyệt. Người dùng chủ động kết nối qua modal Settings Dark Glass (`SettingsModal.qml`), tự động phân giải `SAPISID` và băm `SAPISIDHASH` SHA1 an toàn cục bộ.
    - **Zero Emojis**: 100% icon trên toàn bộ giao diện sử dụng SVG tượng trưng chuẩn hệ thống.

- [ ] **9. Hệ Thống Đa Preset Nghệ Thuật & Cử Chỉ Cho Desktop Lyrics (Artistic Presets Suite & Magic Desktop Gestures - Điểm Độc Bản Của Dự Án)**
  - *Tầm nhìn cốt lõi*: Đây là "vũ khí sát thương độc bản" tạo nên sự khác biệt hoàn toàn giữa Frostify Local và các trình phát nhạc khác trên Linux Wayland (Niri/Hyprland/CachyOS). Triển khai sau khi toàn bộ tính năng cốt lõi (Core Playback & Sync) hoàn thiện.
  - *Kiến trúc*: Quản lý qua file JSON `~/.config/noctalia/frostify_settings.json`.
  - *Bộ 5 Preset Nghệ Thuật (Artistic Presets)*:
    1. `GachaPop` (Mặc định hiện tại): Font *Instrument Serif*, lệch dòng sole tự nhiên, câu kết thúc rớt sâu +52px và nghiêng 1.8°, đổ bóng điện ảnh thích ứng màu hình nền.
    2. `FloatingGlassPill` (MIO / Dynamic Island): Viên nang kính mờ nhỏ gọn, đĩa than mini xoay tròn bên trái, sóng âm mini nhảy múa, chữ chạy karaoke mượt mà.
    3. `CinematicSubtitle` (Makoto Shinkai): Font sans-serif thanh mảnh (Inter/Satoshi), 2 dòng căn giữa ở đáy màn hình, đổ bóng điện ảnh sâu như phụ đề phim anime chiếu rạp.
    4. `VerticalCalligraphy` (Thư pháp Đông Á): Chữ xếp dọc từ trên xuống dưới ở góc phải màn hình, mờ dần theo trục dọc tựa như thơ cổ phong hoặc MV Lofi Nhật/Trung.
    5. `CyberpunkNeon` (Sci-Fi Pulse): Font monospace kỹ thuật số, viền neon phát sáng đập nhẹ theo nhịp bass, hiệu ứng glitch tinh tế khi đổi câu.
  - *Cử chỉ tương tác trực tiếp trên Desktop (Direct Desktop Gestures)*:
    - Bấm đúp (Double-click) vào vùng chữ trên desktop để Play / Pause.
    - Cuộn chuột trên vùng lyric để tăng / giảm âm lượng mượt mà.
    - Vuốt chuột sang trái / phải để Next / Prev bài hát mà không cần mở app.
  - *Kéo thả tự do & Ghi nhớ vị trí thông minh (Per-Wallpaper Smart Anchor)*:
    - Giữ phím `Super` + chuột trái để kéo thả lyric đến bất kỳ vị trí nào trên màn hình.
    - Tự động lưu tọa độ gắn liền với mã băm của hình nền hiện tại (`frostify_settings.json`), đổi lại hình nền cũ là lyric tự động bay về đúng vị trí đã ghim.

- [ ] **10. Nút Đồng Bộ Nhạc 1-Chạm Từ Điện Thoại Qua ADB (1-Click ADB Phone Sync)**
  - *Công cụ*: Google Platform Tools `/home/apple/.local/bin/adb`.
  - *Thiết bị*: Đã nhận diện ID `2bd3dce5`.
  - *Đường dẫn điện thoại đã xác định*: `/storage/emulated/0/Music/SimpMusic/`.
  - *Đích đến trên PC*: `~/Music/SimpMusic/Tracks/`.
  - *Lệnh thực thi*: `adb pull -a /storage/emulated/0/Music/SimpMusic/. ~/Music/SimpMusic/Tracks/` -> sau đó tự động kích hoạt `library.py` quét lại thư viện.

- [ ] **11. Tối Ưu Hiệu Năng & Tiết Kiệm RAM**
  - *Định hướng đã chốt*: Hiện tại kiến trúc Quickshell (Qt 6) + Python daemon + mpv hoạt động rất nhẹ (< 100MB RAM, thấp hơn nhiều so với Spotify 600MB).
  - *Ưu tiên*: Tập trung hoàn thiện toàn bộ các tính năng người dùng và đổi giao diện Anime trước, chỉ viết lại core bằng Rust khi thực sự có nhu cầu mở rộng thư viện lên hàng chục nghìn bài.

- [ ] **12. Thiết Kế Bản Sắc Giao Diện Độc Bản (Diverge from Spotify Clone)**
  - *Định hướng*: Từng bước thoát ly bố cục Spotify để phát triển giao diện Anime / Gacha Cyberpunk riêng biệt.
  - *Yêu cầu mỹ thuật*: Tuyệt đối không dùng emoji; dùng icon SVG sắc sảo, hiệu ứng kính mờ (glassmorphism) và ánh sáng phát quang ăn khớp màu hình nền desktop.

- [ ] **13. Thay Đổi Giao Diện Theo Phong Cách MIO (Warm Butter Pastel & Vinyl Player - Đã Chốt Theo Ảnh Đính Kèm)**
  - *Tham chiếu trực quan*: Thiết kế MIO [mio_style_reference.png](file:///home/apple/Applications/FrostifyLocal/assets/mio_style_reference.png) (tải từ Dribbble).
  - *Bảng màu*: Butter Yellow Pastel (`#FCEEA7` / `#FDF2B8`) làm điểm nhấn, nền kem ấm (`#FFFDF5`), phân vùng điều khiển than chì tối (`#1E1E1E` / `#191919`).
  - *Đĩa Than Nổi Nghệ Thuật (Vinyl Peek Record)*: Đĩa than đen xoay tròn nhô một nửa ra khỏi bìa Album Art vuông khi đang phát nhạc.
  - *Đường Phân Cách Lượn Sóng Hữu Cơ (Organic Wavy Divider)*: Đường cong mềm mại ngăn cách giữa khu vực nội dung và thanh điều khiển bên dưới.
  - *Thanh Sóng Âm Trực Quan (Soundwave Visualizer)*: Bộ equalizer sóng âm (`||| | | |||`) tích hợp trực tiếp ngay trong thanh player bar cạnh nút Play/Pause.
  - *Tabs Điều Hướng Nghệ Thuật*: Phân nhóm "BY ALBUM", "BY PLAYLIST", "BY ARTIST" kèm avatar nghệ sĩ tròn viền tối giản.

- [x] **14. Đồng Bộ Lịch Sử Nghe Nhạc Lên YouTube Music (Watch History & Playback Tracking Sync - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Playback Tracking (SimpMusic Adaptation)**: Triển khai phương thức `send_playback_tracking` trong `backend/ytmusic_helper.py` trích xuất `playbackTracking` từ endpoint `v1/player`, sinh chuỗi `cpn` 16 ký tự, gửi tuần tự `videostatsPlaybackUrl` (GET) và `videostatsWatchtimeUrl` (`st=0, et=5.54`), background worker gửi tiếp `atrUrl` (POST) và watchtime thứ 2 (`st=0,5.54, et=5.54,12.xx`). Tất cả đều trả về mã chuẩn HTTP 204 No Content.
    - **Hỗ trợ đồng bộ cả Offline & Online**: Tự động phân giải ngầm `videoId` đối với các bài hát offline nội bộ theo `Title + Artist` (`resolve_video_id_for_track`) và lưu cache nhanh tại `~/.cache/frostify/local_yt_mappings.json`.
    - **Cài đặt Dark Glass & Switch On/Off**: Bổ sung toggle Switch "Sync Playback History to YouTube Music" trong `components/SettingsModal.qml` với icon SVG `sync-symbolic.svg`, lưu trữ bền vững trạng thái `syncHistoryToGoogle` vào `~/.config/noctalia/frostify_settings.json`.
    - **Phản hồi tức thì 0ms (Instant Reactive UI)**: Ngay khi phát bài, bài hát lập tức được đưa lên đầu hàng "Listen again" trên Home Feed mà không cần reload trang.
    - **Cơ chế chịu lỗi & Tự phục hồi (Fault-tolerant Pending Queue)**: Lưu bài hát vào `~/.cache/frostify/pending_history.json` khi rớt mạng và tự động flush gửi bù khi kết nối internet hoạt động trở lại.
  - *Cấu hình người dùng*: Bổ sung switch bật/tắt đồng bộ (`Sync Playback to Google / sendBackToGoogle`) trong Settings Dark Glass.

- [ ] **15. Mở Rộng Tìm Kiếm Đa Phân Loại: Kệ Album, Nghệ Sĩ & Bài Hát Liên Quan (Categorized Search)**
  - *Hiện trạng*: Tìm kiếm YouTube Music hiện tại chỉ trả về danh sách các bài hát đơn lẻ.
  - *Nâng cấp*: Phân loại kết quả tìm kiếm theo `resultType` (hoặc truy vấn kết hợp Songs, Albums, Artists):
    - **Top Result**: Kết quả trùng khớp nhất dạng Banner/Card lớn.
    - **Songs**: Lưới danh sách bài hát có thể click nghe ngay.
    - **Albums**: Kệ ngang các Album liên quan trực tiếp đến từ khóa tìm kiếm (bấm vào mở danh sách bài trong album).
    - **Artists & Playlists**: Kệ các Playlist tổng hợp và kênh nghệ sĩ chính thức.

- [x] **16. Tab Artwork: Hiển Thị Chi Tiết Nghệ Sĩ, Lượt Xem/Thích/Không Thích, Mô Tả & Thông Số Kỹ Thuật Audio (SimpMusic Metadata & Audio Specs Inspector - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Audio Specs Daemon**: Thêm action `audio_specs` trong `backend/player_daemon.py` đọc trực tiếp các thông số từ MPV Unix Domain Socket: codec (`audio-codec-name`), bitrate (`audio-bitrate` kbps), sample rate (`audio-params.samplerate` kHz) và kênh âm thanh (`audio-params.channels`).
    - **Backend Song Details & Return YouTube Dislike API**: Thêm hàm `get_song_details` trong `backend/ytmusic_helper.py` tích hợp Return YouTube Dislike API (`https://returnyoutubedislikeapi.com/votes?videoId={videoId}`) mang lại số lượt xem (`viewsStr`), lượt thích (`likesStr`), lượt không thích (`dislikesStr`), điểm đánh giá (`rating`), và tỷ lệ thích (`likeRatio`). Hỗ trợ tự động phân giải ngầm qua `ytm.search` khi phát bài hát offline trong thư viện để vẫn lấy được đầy đủ thống kê online.
    - **Artwork & Metadata Inspector Panel**: Thiết kế giao diện Dark Glass trong `components/AmberolDetailView.qml` gồm ảnh bìa bo tròn, các badge trạng thái (`CODEC • BITRATE`, `SOURCE`, `YEAR`), lưới thẻ 2x2 Audio Engine Specs (Codec, Bitrate, Sample Rate, Channels), thẻ tương tác Social Engagement (Lượt xem với icon con mắt, Thích với icon ngón tay cái, Không thích, thanh tiến trình tỷ lệ thích xanh neon), hộp chi tiết Album/Single với nút xem album, và cụm nút thao tác nhanh `[ 📥 Tải bài / 📁 Mở thư mục ]`, `[ 📻 Radio ]`, `[ 📋 Sao chép ]`.
    - **Zero Emoji**: 100% icon sử dụng SVG chuẩn hệ thống (`assets/icons/thumb-up-symbolic.svg`, `thumb-down-symbolic.svg`, `eye-symbolic.svg`).

- [x] **20. Pure Visual Skeleton Shimmer Lazy Loading (Tải Lười Dạng Khung Xương Xung Nhịp - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Loại bỏ triệt để dòng chữ Loading thô**: Xóa sạch toàn bộ các dòng chữ text nhàm chán như "Searching YouTube Music...", "Loading...", "Đang tạo đài phát...".
    - **Component SkeletonTrackRow**: Tạo mới `components/SkeletonTrackRow.qml` với hiệu ứng xung nhịp thở mượt mà (`SequentialAnimation` độ mờ từ `0.25` đến `0.70`), mô phỏng chân thực thumbnail 40x40/48x48, thanh tiêu đề bài hát, thanh phụ đề nghệ sĩ và thanh thời lượng. Hỗ trợ thuộc tính `isCompact` cho hàng đợi sidebar.
    - **Lưới Chính (SpotifyMainGrid)**: Hiển thị 8 dòng skeleton track row nhịp nhàng khi chuyển danh sách, bấm album, hoặc tìm kiếm.
    - **Hàng Đợi Bên Cạnh (SpotifySidebar Queue)**: Khi bấm phát bài hát mới và hệ thống đang tải danh sách Automix Radio (`radioProc.running = true`), hàng đợi hiển thị bài hát hiện tại kèm huy hiệu `Queue (1+)` và 5 dòng skeleton thu nhỏ bên dưới. Khi radio tải xong, toàn bộ bài hát tự động xuất hiện mượt mà mà không làm giật lag hay gây cảm giác ứng dụng bị đơ.

- [x] **17. Con Quay Loading Trực Tuyến (SimpMusic Circular Buffer Indicator - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Tạo mới `components/CircularSpinner.qml` với Canvas 270° arc, hai đầu bo tròn (round caps), `RotationAnimation` vô hạn 360° (tiêu thụ 0% CPU).
    - Tích hợp trực tiếp vào nút tròn Play/Pause 36px trong `components/SpotifyPlayerBar.qml` thông qua cờ `isLoadingAudio`.
    - Khi người dùng click phát bài hát trực tuyến hoặc chuyển bài, icon Play/Pause tạm thời ẩn và con quay xoay mượt mà cho đến khi MPV nhận được luồng stream và bắt đầu đếm thời gian phát (`time_pos > 0`), giúp người dùng nhận biết hệ thống đang xử lý và không gây cảm giác ứng dụng bị đơ hay giật.

- [x] **18. Nút Phát Tuần Tự & Tách Biệt Trạng Thái Playlist (Sequential Play All & Decoupled State - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Bổ sung nút chính `[ ▶ Phát ]` bo góc tròn màu xanh Spotify Green trong `components/SpotifyMainGrid.qml` cho phép phát toàn bộ danh sách nhạc hoặc danh sách tải về tuần tự từ bài đầu tiên (track index 0).
    - Giữ nút phụ `[ 🔀 Phát ngẫu nhiên ]` dạng kính mờ (glassmorphism).
    - Tách biệt hai biến trạng thái độc lập: `win.activePlaylistId` (danh mục đang duyệt trên giao diện) và `win.playingPlaylistId` (danh mục đang thực sự phát nhạc). Sóng âm equalizer 3-bar và chữ xanh giờ chỉ hiển thị duy nhất trên playlist đang phát nhạc, duyệt xem playlist khác không làm nhảy sóng âm.

- [x] **19. Xóa Bài Hát Cục Bộ Vĩnh Viễn & Sửa Lỗi Tự Động Phát Khi Xóa (Safe Permanent Deletion - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Xóa vĩnh viễn tệp âm thanh cục bộ trên đĩa cứng và cập nhật đồng bộ cache `library.json`, khắc phục triệt để lỗi bài hát xuất hiện trở lại sau khi khởi động lại ứng dụng.
    - Sửa lỗi khi xóa một bài trong tab Downloads không còn kích hoạt tự động phát toàn bộ danh sách bài hát tải về.
