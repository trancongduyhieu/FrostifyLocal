# TODO.md - Lộ Trình Phát Triển Chi Tiết (Nutsty)

Tài liệu quản lý tác vụ (Roadmap & Todo List) cho Nutsty. Đã được làm rõ 100% qua quy trình phỏng vấn (/grill-me) cùng người dùng.

---

## Danh Sách Các Hạng Mục Tiếp Theo Đang Triển Khai

- [x] **2. Sửa Thanh Trượt Âm Lượng & Thời Lượng (Draggable Scrubbing)**
  - *Đã hoàn thành*: `components/PlayerBarBottom.qml` hỗ trợ kéo rê thumb thanh thời lượng và âm lượng theo thời gian thực (MouseArea `onPressed`, `onPositionChanged`, `onReleased` với `preventStealing: true`), mở rộng hit area 16px để thao tác nhạy, cập nhật text thời gian mượt mà không bị xung đột binding với daemon.

- [x] **3. Bộ Lấy Lyric Tự Động Từ Internet (Online Synced Lyrics Fallback)**
  - *Đã hoàn thành*: Tích hợp thư viện Python `syncedlyrics` với kiến trúc phân tầng: Cache `.lrc` $\rightarrow$ Online (LRCLIB $\rightarrow$ NetEase $\rightarrow$ Musixmatch) $\rightarrow$ Dự phòng cuối cùng (Nutsty SQLite DB). Tự động lưu cache file `.lrc` vào `~/.cache/frostify/lyrics/` để nạp offline trong ~30ms.

- [ ] **4. Bảng Điều Khiển Desktop Lyrics (Bật/Tắt & Tinh Chỉnh Màu)**
  - *Cấu hình*: Lưu trạng thái trong `~/.config/noctalia/nutsty_settings.json`.
  - *Tính năng*: Nút gạt Toggle On/Off desktop lyrics; Chuyển đổi giữa chế độ `Auto (Wallpaper Adaptive)` và chế độ `Manual (Tự chọn mã màu highlight)`.

- [x] **5. Trình Quản Lý & Tải Nhạc Đa Luồng Nutsty (Nutsty Style Download Manager Daemon & Minimalist Popover - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Daemon & Worker Loop**: `backend/download_manager.py` chạy thường trú độc lập, giao tiếp socket IPC `/tmp/nutsty_download.sock` và file trạng thái nguyên tử `/tmp/frostify_download_status.json`.
    - **Trích xuất & Tagging chuyên sâu**: Sử dụng `yt-dlp` + FFmpeg trích xuất âm thanh 192k AAC/M4A, nhúng bìa album chất lượng cao qua FFmpeg (`-an -frames:v 1 -update 1`) và gắn tag ID3 đầy đủ; tự động tải synced lyrics (`.lrc`) đi kèm bài hát.
    - **Hàng đợi tải đa tiến trình**: Theo dõi tiến trình tải theo thời gian thực (Tốc độ MB/s, Thời gian còn lại ETA, Phần trăm hoàn thành %) với độ trễ 0ms.
    - **Giao diện Popover Minimalist Clean**: `components/DownloadQueuePopover.qml` chuẩn Nutsty Desktop (#121212, bo góc 8px, thanh progress 3px bo tròn), nút hủy tải từng bài, nút mở thư mục nhạc `~/Music/Downloads_Phone` (`folder-music-symbolic.svg`), nút dọn sạch danh sách đã tải xong (`edit-clear-all-symbolic.svg`) kèm Tooltip giải thích trực quan khi rê chuột.
    - **Header Pill & Con quay động**: `components/TopHeaderBar.qml` hiển thị pill tải nhạc với số lượng bài đang tải thực tế (`activeTasksCount`) và con quay `CircularSpinner.qml` xoay tròn khi đang có tác vụ tải.
    - **Desktop Notification**: Tự động thông báo qua `notify-send` kèm tên bài hát khi hoàn thành.

- [x] **6. Menu Chuột Phải & Quản Lý Hàng Đợi (Context Menu & Queue từ Nutsty - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Tạo mới component `components/TrackContextMenu.qml` phong cách Dark Glass sang trọng, 100% SVG tượng trưng chuẩn hệ thống (TUYỆT ĐỐI KHÔNG DÙNG EMOJI), tự động căn chỉnh mép cửa sổ (auto-clamping) và backdrop dismiss.
    - Đầy đủ 5 tác vụ tiêu chuẩn kế thừa từ Nutsty:
      1. *Phát tiếp theo (Play next)*: Chèn bài ngay sau bài đang phát trong hàng đợi.
      2. *Thêm vào hàng đợi (Add to queue)*: Thêm bài hát vào cuối hàng đợi phát nhạc.
      3. *Bắt đầu radio (Start radio)*: Tự động khởi tạo automix radio dựa trên bài hát.
      4. *Mở thư mục / Tải nhạc*: Tự động hiển thị "Open containing folder" với bài local hoặc "Download track" qua `anpan` với bài online.
      5. *Xóa khỏi hàng đợi / Xóa thư viện*: "Remove from queue" (khi click trong tab Queue của Sidebar) hoặc "Delete from library" (với bài local) hiển thị chữ đỏ cảnh báo.
    - Tích hợp kết nối sự kiện chuột phải trên toàn bộ các điểm chạm: `TrackCard.qml`, `TrackRow.qml`, `MainTrackGrid.qml`, `HomeFeedView.qml` (QuickPicks Grid, Section Carousel Cards, Fallback Grid), và `NavSidebar.qml` (Queue tab).

- [x] **7. Hoàn Thiện Tính Năng Album (Interactive Albums từ Nutsty - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Metadata & Normalization**:
      - `backend/ytmusic_helper.py`: Bổ sung hàm `get_album_details(browse_id)` bóc tách đầy đủ cấu trúc album (ID, browseId, title, artist, year, type, trackCount, duration, ảnh phân giải cao 544x544 `w544-h544-l90-rj`, và mô tả Wikipedia/ghi chú album) kèm danh sách toàn bộ bài hát đã chuẩn hóa. Thêm endpoint CLI `album <browse_id>` và `search_albums <query>`.
      - `backend/library.py`: Bổ sung trích xuất tag `album` và `year` từ metadata ffprobe; hàm `get_grouped_albums()` phân nhóm toàn bộ bài hát cục bộ theo album thực tế hoặc danh mục đĩa đơn nghệ sĩ. Thêm endpoint CLI `albums`.
    - **Giao diện Hero Album Banner & Toolbar (`components/MainTrackGrid.qml`)**:
      - Bìa album lớn 160x160 với bóng đổ sâu điện ảnh và gradient fallback khi đang tải.
      - Huy hiệu loại phát hành động (`ALBUM` / `SINGLE` / `EP`), tiêu đề album lớn 26px đậm, phụ đề đầy đủ `Nghệ sĩ • Năm • Số bài hát • Thời lượng tổng` và mô tả album rút gọn.
      - Cụm 4 nút hành động bo tròn chuẩn Nutsty / Nutsty Desktop:
        1. `[ ▶ Phát ]`: Bắt đầu phát toàn bộ album tuần tự từ bài đầu tiên (track index 0).
        2. `[ 🔀 Phát ngẫu nhiên ]`: Xáo trộn và phát toàn bộ album.
        3. `[ + Hàng đợi ]`: Thêm toàn bộ các bài hát trong album vào cuối hàng đợi phát hiện tại (`win.currentTracks`).
        4. `[ 📥 Tải Album ]`: Tự động nạp hàng loạt bài hát trong album vào daemon tải nhạc `download_manager.py` (chỉ hiển thị cho album online).
      - **Downloads Sub-Tab Switcher**: Bộ lọc hai chế độ `[ Bài hát (N) ]` | `[ Albums (N) ]` trong tab Downloads, cho phép duyệt và mở nhanh toàn bộ album đã lưu trong máy.
    - **Home Feed & Shell State Routing**:
      - `components/HomeFeedView.qml`: Nhận diện và điều hướng click card album sang chế độ xem chi tiết album.
      - `shell.qml`: Điều phối các tác vụ `loadAlbumDetails()`, `addTracksToQueue()`, `downloadEntireAlbum()`, `refreshLocalAlbums()` và nút quay lại (Back) dọn dẹp view sạch sẽ.

- [x] **8. Phát Nhạc Trực Tuyến & Bóc Tách Thuật Toán Gợi Ý Nutsty (Online Streaming & Personalized Feed - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*: 
    - **Thuật toán gợi ý Hybrid thông minh (Nutsty Adaptation)**:
      - Khi chưa kết nối Google Account: Tự động học gu nghe nhạc cục bộ từ `frostify_session.json` / `library.json`, gọi `ytmusic.get_watch_playlist(videoId)` tạo ra 12–20 bài "Quick picks" (Radio mix) cá nhân hóa 100% thay vì các bài trending rác.
      - Khi kết nối Google Account: Gọi `ytmusic.get_home()` mang lại trang chủ chuẩn xác theo tài khoản cá nhân.
      - Bấm vào bài hát Quick Pick tự động khởi tạo hàng đợi Automix Radio (`get_watch_playlist`).
    - **Mặc định mở app ở chế độ Online**: Khởi động trực tiếp vào giao diện Home feed (`currentView: "home"`).
    - **Giao diện 3 cột chuẩn Desktop (Nutsty Image 2 Layout)**:
      - Cột 1 (Sidebar trái - 240px): 3 nút chính gồm "Home (Online)", "Downloads (Local)", "Settings & Account" (đã loại bỏ hoàn toàn Mix & Analytics), bên dưới là "Local Collections".
      - Cột 2 (Center Content): Lời chào theo buổi ("Good Evening/Morning/Afternoon"), 11 Mood Pills ("All", "Relax", "Sleep", "Energize", "Sad", "Romance", "Feel Good", "Workout", "Party", "Commute", "Focus"), lưới 3 cột Quick picks, và lưới Featured Playlists.
      - Cột 3 (Right Collapsible Panel - 360px): Now Playing panel có switch [Lyrics | Artwork], hiển thị lyric cuộn Amberol hoặc ảnh bìa nghệ thuật chất lượng cao, có thể bật/tắt qua nút Details trên player bar.
    - **Bảo mật tối đa (No Browser-Sniffing)**: Tuyệt đối không đọc trộm cookie từ profile trình duyệt. Người dùng chủ động kết nối qua modal Settings Dark Glass (`SettingsModal.qml`), tự động phân giải `SAPISID` và băm `SAPISIDHASH` SHA1 an toàn cục bộ.
    - **Zero Emojis**: 100% icon trên toàn bộ giao diện sử dụng SVG tượng trưng chuẩn hệ thống.

- [ ] **9. Hệ Thống Đa Preset Nghệ Thuật & Cử Chỉ Cho Desktop Lyrics (Artistic Presets Suite & Magic Desktop Gestures - Điểm Độc Bản Của Dự Án)**
  - *Tầm nhìn cốt lõi*: Đây là "vũ khí sát thương độc bản" tạo nên sự khác biệt hoàn toàn giữa Nutsty và các trình phát nhạc khác trên Linux Wayland (Niri/Hyprland/CachyOS). Triển khai sau khi toàn bộ tính năng cốt lõi (Core Playback & Sync) hoàn thiện.
  - *Kiến trúc*: Quản lý qua file JSON `~/.config/noctalia/nutsty_settings.json`.
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
    - Tự động lưu tọa độ gắn liền với mã băm của hình nền hiện tại (`nutsty_settings.json`), đổi lại hình nền cũ là lyric tự động bay về đúng vị trí đã ghim.

- [ ] **10. Nút Đồng Bộ Nhạc 1-Chạm Từ Điện Thoại Qua ADB (1-Click ADB Phone Sync)**
  - *Công cụ*: Google Platform Tools `/home/apple/.local/bin/adb`.
  - *Thiết bị*: Đã nhận diện ID `2bd3dce5`.
  - *Đường dẫn điện thoại đã xác định*: `/storage/emulated/0/Music/Nutsty/`.
  - *Đích đến trên PC*: `~/Music/Nutsty/Tracks/`.
  - *Lệnh thực thi*: `adb pull -a /storage/emulated/0/Music/Nutsty/. ~/Music/Nutsty/Tracks/` -> sau đó tự động kích hoạt `library.py` quét lại thư viện.

- [ ] **11. Tối Ưu Hiệu Năng & Tiết Kiệm RAM**
  - *Định hướng đã chốt*: Hiện tại kiến trúc Quickshell (Qt 6) + Python daemon + mpv hoạt động rất nhẹ (< 100MB RAM, thấp hơn nhiều so với Nutsty 600MB).
  - *Ưu tiên*: Tập trung hoàn thiện toàn bộ các tính năng người dùng và đổi giao diện Anime trước, chỉ viết lại core bằng Rust khi thực sự có nhu cầu mở rộng thư viện lên hàng chục nghìn bài.

- [ ] **12. Thiết Kế Bản Sắc Giao Diện Độc Bản (Diverge from Nutsty Clone)**
  - *Định hướng*: Từng bước thoát ly bố cục Nutsty để phát triển giao diện Anime / Gacha Cyberpunk riêng biệt.
  - *Yêu cầu mỹ thuật*: Tuyệt đối không dùng emoji; dùng icon SVG sắc sảo, hiệu ứng kính mờ (glassmorphism) và ánh sáng phát quang ăn khớp màu hình nền desktop.


- [x] **14. Đồng Bộ Lịch Sử Nghe Nhạc Lên YouTube Music (Watch History & Playback Tracking Sync - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Playback Tracking (Nutsty Adaptation)**: Triển khai phương thức `send_playback_tracking` trong `backend/ytmusic_helper.py` trích xuất `playbackTracking` từ endpoint `v1/player`, sinh chuỗi `cpn` 16 ký tự, gửi tuần tự `videostatsPlaybackUrl` (GET) và `videostatsWatchtimeUrl` (`st=0, et=5.54`), background worker gửi tiếp `atrUrl` (POST) và watchtime thứ 2 (`st=0,5.54, et=5.54,12.xx`). Tất cả đều trả về mã chuẩn HTTP 204 No Content.
    - **Hỗ trợ đồng bộ cả Offline & Online**: Tự động phân giải ngầm `videoId` đối với các bài hát offline nội bộ theo `Title + Artist` (`resolve_video_id_for_track`) và lưu cache nhanh tại `~/.cache/frostify/local_yt_mappings.json`.
    - **Cài đặt Dark Glass & Switch On/Off**: Bổ sung toggle Switch "Sync Playback History to YouTube Music" trong `components/SettingsModal.qml` với icon SVG `sync-symbolic.svg`, lưu trữ bền vững trạng thái `syncHistoryToGoogle` vào `~/.config/noctalia/nutsty_settings.json`.
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

- [x] **16. Tab Artwork: Bố Cục Thẻ Biểu Cảm Nutsty, Mô Tả Bài Hát & Hệ Thống Blacklist Like/Dislike (Nutsty Expressive Cards, Description & Dislike Blacklist - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Thẻ Nghệ Sĩ Nutsty (Artist Hero Card)**:
      - Thiết kế thẻ nghệ sĩ bo tròn 16px với nền avatar nghệ sĩ phân giải cao (960px) từ YouTube Innertube `v1/next`.
      - Lớp phủ gradient scrim điện ảnh sâu, huy hiệu `"Nghệ sĩ"` bo viền thanh lịch ở góc trên bên trái, tên nghệ sĩ in đậm 17px và số người đăng ký kênh (`subscribers`).
    - **Thẻ Thống Kê, Mô Tả & Tương Tác (Stats, Engagement & Expandable Description Card)**:
      - Hiển thị ngày phát hành (`Phát hành lúc ...`), tổng lượt xem từ YouTube Music API.
      - Nút **Thích (Like)** tương tác: Chuyển màu xanh Nutsty (#1ed760) kèm số lượt thích, đồng bộ đánh giá `LIKE` về YouTube Music (`rate_song_action`).
      - Nút **Không Thích (Dislike)** tương tác & **Cơ chế Blacklist triệt để**:
        - Khi người dùng bấm Dislike: Tự động lưu bài hát vào danh sách đen `~/.config/noctalia/nutsty_disliked_songs.json`.
        - Lập tức tự động bỏ qua và chuyển sang bài tiếp theo (`win.playNext()`).
        - Loại bỏ bài hát vĩnh viễn khỏi hàng đợi phát hiện tại (`win.currentTracks`), danh sách duyệt (`win.browsingTracks`), và bộ lọc thuật toán Home Feed, Quick Picks, Carousel và Automix Radio (`normalize_track` & `_normalize_shelf_item`).
      - Thanh tỷ lệ thích / không thích (Like Ratio Bar) màu xanh neon (#1ed760) hiển thị tỷ lệ thực tế.
      - Khối **Mô tả bài hát (YouTube Description)**: Bóc tách toàn bộ mô tả bài hát từ YouTube Music, hỗ trợ nút bấm `[ Xem thêm ▼ / Thu gọn ▲ ]` mượt mà, co giãn linh hoạt mà không làm vỡ layout.
    - **Sửa Lỗi Hiển Thị "Single / Nutsty"**:
      - Xóa bỏ triệt để chuỗi fallback cứng `"Nutsty"`.
      - Tự động phân giải tên album thực tế hoặc hiển thị chuẩn xác `"Single"` khi bài hát là đĩa đơn độc lập.
    - **Lưới Thông Số Audio Kỹ Thuật (Audio Engine Specs)**:
      - Thẻ 2x2 Dark Glass (Codec, Bitrate, Sample Rate, Channels) chiều cao 96px tối ưu, lề đối xứng 12px không bị lệch viền.
    - **Zero Emoji**: 100% icon sử dụng SVG chuẩn hệ thống (`thumb-up-symbolic.svg`, `thumb-down-symbolic.svg`, `eye-symbolic.svg`, `folder-music-symbolic.svg`).
- [x] **20. Pure Visual Skeleton Shimmer Lazy Loading (Tải Lười Dạng Khung Xương Xung Nhịp - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Loại bỏ triệt để dòng chữ Loading thô**: Xóa sạch toàn bộ các dòng chữ text nhàm chán như "Searching YouTube Music...", "Loading...", "Đang tạo đài phát...".
    - **Lưới Chính Chuẩn Card Vuông (`components/SkeletonTrackCard.qml`)**: Tạo mới component card khung xương dạng thẻ vuông (176x250 px) đồng bộ 1:1 với `TrackCard.qml`. Khi tải playlist hoặc tìm kiếm trong `MainTrackGrid.qml`, hiển thị lưới `Flow` gồm 10 thẻ vuông xung nhịp thở mượt mà (`SequentialAnimation` độ mờ từ `0.25` đến `0.70`), khắc phục triệt để tình trạng lệch bố cục danh sách ngang.
    - **Hàng Đợi Sidebar Dạng Dòng Ngang (`components/SkeletonTrackRow.qml`)**: Component dạng dòng ngang thu nhỏ với hiệu ứng thở nhịp nhàng. Khi bấm phát bài hát mới và hệ thống đang tải Automix Radio (`radioProc.running = true`), hàng đợi hiển thị bài hiện tại kèm huy hiệu `Queue (1+)` và 5 dòng skeleton thu nhỏ bên dưới, khi radio tải xong các bài thật xuất hiện tự nhiên không giật lag.
    - **Cân Đối Tọa Độ Thẻ Audio Specs & Chuẩn Hóa Icon Trắng Sáng**:
      - Mở rộng chiều cao thẻ Audio Engine Specs trong `components/AmberolDetailView.qml` lên 96px, căn lề đối xứng 12px và khoảng cách hàng 10px, xóa bỏ hoàn toàn hiện tượng dòng thông số `44.1 kHz / Stereo` bị xệ chạm đáy.
      - Chuẩn hóa toàn bộ 12 file icon hệ thống sang màu trắng tinh (`fill="#ffffff"`) và bổ sung `MultiEffect.brightness: 1.0` vào `components/AppIcon.qml`, giúp icon luôn sáng rõ nét trên nền tối.

- [x] **17. Con Quay Loading Trực Tuyến (Nutsty Circular Buffer Indicator - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Tạo mới `components/CircularSpinner.qml` với Canvas 270° arc, hai đầu bo tròn (round caps), `RotationAnimation` vô hạn 360° (tiêu thụ 0% CPU).
    - Tích hợp trực tiếp vào nút tròn Play/Pause 36px trong `components/PlayerBarBottom.qml` thông qua cờ `isLoadingAudio`.
    - Khi người dùng click phát bài hát trực tuyến hoặc chuyển bài, icon Play/Pause tạm thời ẩn và con quay xoay mượt mà cho đến khi MPV nhận được luồng stream và bắt đầu đếm thời gian phát (`time_pos > 0`), giúp người dùng nhận biết hệ thống đang xử lý và không gây cảm giác ứng dụng bị đơ hay giật.

- [x] **18. Nút Phát Tuần Tự & Tách Biệt Trạng Thái Playlist (Sequential Play All & Decoupled State - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Bổ sung nút chính `[ ▶ Phát ]` bo góc tròn màu xanh Emerald Green trong `components/MainTrackGrid.qml` cho phép phát toàn bộ danh sách nhạc hoặc danh sách tải về tuần tự từ bài đầu tiên (track index 0).
    - Giữ nút phụ `[ 🔀 Phát ngẫu nhiên ]` dạng kính mờ (glassmorphism).
    - Tách biệt hai biến trạng thái độc lập: `win.activePlaylistId` (danh mục đang duyệt trên giao diện) và `win.playingPlaylistId` (danh mục đang thực sự phát nhạc). Sóng âm equalizer 3-bar và chữ xanh giờ chỉ hiển thị duy nhất trên playlist đang phát nhạc, duyệt xem playlist khác không làm nhảy sóng âm.

- [x] **19. Xóa Bài Hát Cục Bộ Vĩnh Viễn & Sửa Lỗi Tự Động Phát Khi Xóa (Safe Permanent Deletion - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - Xóa vĩnh viễn tệp âm thanh cục bộ trên đĩa cứng và cập nhật đồng bộ cache `library.json`, khắc phục triệt để lỗi bài hát xuất hiện trở lại sau khi khởi động lại ứng dụng.
    - Sửa lỗi khi xóa một bài trong tab Downloads không còn kích hoạt tự động phát toàn bộ danh sách bài hát tải về.

- [x] **21. Màn Hình Trang Nghệ Sĩ Toàn Diện Chuẩn Nutsty (Nutsty Interactive Artist Page Suite - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Backend Engine & API Bóc Tách Chuyên Sâu**:
      - `backend/ytmusic_helper.py`: Bổ sung `get_artist(channel_id_or_name)` tự động phân giải tên nghệ sĩ sang browseId và bóc tách cấu trúc nghệ sĩ đầy đủ từ YouTube Music: metadata (`name`, `subscribers`, `views`, avatar chất lượng cao `w544-h544-l90-rj` / `s960`), `radioId`, `shuffleId`, danh sách bài hát nổi tiếng ("Phổ biến" / Popular), carousels "Albums", "Đĩa đơn & EPs", "Video âm nhạc", danh sách tròn "Nghệ sĩ liên quan" (Similar Artists) và khối tiểu sử "Giới thiệu" (Description).
      - Triển khai `subscribe_artist_action(channel_id, subscribe)` tương thích YouTube Music API (`ytmusic.subscribe_artist` / `unsubscribe_artist`). Thêm endpoint CLI `artist <query|id>` và `subscribe <id> <true|false>`.
    - **Giao Diện QML Độc Lập Chuẩn Dark Glass (`components/ArtistDetailView.qml`)**:
      - Hero Artist Header: Avatar tròn 140px sử dụng `MultiEffect` mask chuẩn viền sáng, huy hiệu `"Nghệ sĩ"` thanh lịch, tiêu đề tên nghệ sĩ lớn 32px đậm, lượt theo dõi và lượt xem.
      - Cụm 3 nút hành động chuẩn Nutsty:
        1. `[ 📻 Đài phát ]`: Khởi tạo và phát ngay automix radio của nghệ sĩ.
        2. `[ 🔀 Xáo trộn ]`: Xáo trộn toàn bộ bài hát phổ biến của nghệ sĩ vào hàng đợi.
        3. `[ 👤+ Theo dõi / ✔ Đã theo dõi ]`: Cơ chế Hybrid thông minh — tự động đổi sang màu xanh Nutsty khi đã theo dõi, lưu trạng thái động vào `~/.config/noctalia/nutsty_settings.json` (tuyệt đối không hardcode) và đồng bộ trực tiếp lên tài khoản Google / YouTube Music nếu đã đăng nhập.
      - Section "Phổ biến" (Popular Songs): Số thứ tự, bìa bài hát bo góc, soundwave xanh khi đang phát, hover play icon, click phát bài nạp danh sách vào hàng đợi (`win.currentTracks`), chuột phải mở toàn diện `TrackContextMenu`.
      - Các Carousels cuộn ngang phong cách Nutsty Desktop: "Albums", "Đĩa đơn & EPs", "Video âm nhạc", và "Nghệ sĩ liên quan" (avatar tròn 108px với `MultiEffect` mask). Nút phân trang `<` và `>` mượt mà.
      - Khối "Giới thiệu" (Bio Description): Co giãn linh hoạt với nút `[ Xem thêm ▼ / Thu gọn ▲ ]`.
    - **Tích Hợp Điều Hướng Toàn Diện (`shell.qml`, `PlayerBarBottom.qml`, `AmberolDetailView.qml`, `TrackContextMenu.qml`)**:
      - Hỗ trợ navigation history stack (`artistHistoryStack`) với nút quay lại (Back `<`) mượt mà, chuyển đổi mượt giữa `home`, `library`, `playlist` và `artist`.
      - Cho phép mở trang nghệ sĩ từ mọi nơi: Click tên nghệ sĩ trên thanh phát nhạc, click thẻ nghệ sĩ trong Now Playing, click "Go to artist" trong context menu, hoặc click nghệ sĩ liên quan.

- [x] **22. Tối Ưu Tốc Độ Nạp & Xóa Bỏ Hiện Tượng Nhảy Giật Ảnh Avatar Nghệ Sĩ (Instant Artist Avatar Cache & Shimmer Fallback - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Xóa bỏ hoàn toàn fallback mượn tạm ảnh bìa bài hát**: Loại bỏ triệt để biểu thức mượn tạm `track.image` trong `components/AmberolDetailView.qml`, ngăn chặn hoàn toàn hiện tượng avatar nghệ sĩ nhảy giật từ ảnh bìa album sang ảnh chân dung sau 1-2 giây.
    - **Hiệu ứng Khung Xương Xung Nhịp (Shimmer Placeholder)**: Khi avatar nghệ sĩ chưa tải xong hoặc đang nạp từ mạng, hiển thị hình khối mờ bo tròn với hoạt ảnh thở nhịp nhàng (`SequentialAnimation` độ mờ `0.35` $\leftrightarrow$ `0.70`).
    - **Bộ Nhớ Đệm Avatar Nghệ Sĩ 0ms (`~/.cache/frostify/artist_avatars.json`)**:
      - Backend daemon tự động trích xuất và lưu ảnh avatar nghệ sĩ phân giải cao vào file cache JSON ngay khi nạp chi tiết bài hát (`get_song_details`) hoặc trang nghệ sĩ (`get_artist`).
      - QML nạp đồng bộ file cache qua `FileView`, binding ngay tức thì `cachedArtistAvatar` khi vừa chuyển bài hát, giúp hiển thị avatar nghệ sĩ trong 0ms đối với bất kỳ nghệ sĩ nào đã từng phát.

- [x] **23. Khắc Phục Lỗi Trễ & Rò Rỉ Trạng Thái Like/Dislike Khi Chuyển Bài (Instant State Clean Reset on Track Change - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **0ms Instant State Clean Reset**: Trong `components/AmberolDetailView.qml`, sự kiện `onTrackChanged` lập tức dọn sạch toàn bộ trạng thái của bài hát trước (`songDetails = null`, `localLikesCount = 0`, `localDislikesCount = 0`, `isLoadingDetails = true`).
    - **Đọc Blacklist Đồng Bộ Bộ Nhớ Trong 0ms**: Ngay khi `track` thay đổi, `onTrackChanged` tra cứu trực tiếp file blacklist `~/.config/noctalia/nutsty_disliked_songs.json` qua `FileView`. Nếu bài hát mới nằm trong danh sách đen, nút Dislike lập tức sáng đỏ ngay trong 0ms; nếu không, trạng thái được reset tức thì về `"INDIFFERENT"`. Xóa bỏ vĩnh viễn hiện tượng bài hát mới bị "dính" nút Dislike đỏ của bài hát trước trong 1-2 giây chờ API.

- [x] **24. Loại Bỏ Hiện Tượng Tự Động Phát Bài "Propose" Khi Đóng/Mở App (Disable Cold-Start Auto-Play & Clean Initial Queue - ĐÃ HOÀN THÀNH)**
  - *Đã hoàn thành*:
    - **Tách biệt hoàn toàn hàng đợi phát nhạc khởi động**: Xóa bỏ lệnh gán `win.currentTracks = win.allTracks` trong `LibraryLoader.onLoaded`, giữ hàng đợi `win.currentTracks` hoàn toàn trống `[]` lúc khởi động cho đến khi người dùng chủ động bấm phát bài hát hoặc playlist.
    - **Bảo vệ `togglePlay()`, `playNext()` & `playPrev()`**: Khi chưa có bài hát nào được chọn (`!win.currentTrack`), các hàm này lập tức thoát (`return`), tuyệt đối không tự ý lấy bài hát index 0 ("9Lana - プロポーズ - propose") trong thư mục Downloads ra phát.
    - **Bảo vệ vòng lặp Auto-advance**: Bổ sung cờ `win.isPlaying &&` vào điều kiện chuyển bài trong `statusProcess`, ngăn chặn việc tự động kích hoạt bài tiếp theo khi app ở trạng thái dừng hoặc tạm dừng.
    - **Vô hiệu hóa auto-fallback trong MPV daemon**: Trong `backend/player_daemon.py`, loại bỏ cơ chế tự nạp file cũ từ session khi MPV đang idle.
    - **Trạng thái trực quan trên thanh Player Bar**: Khi chưa chọn bài, nút Play, Prev, Next hiển thị mờ thanh lịch (opacity 0.65/0.4), con trỏ chuột dạng thường và khóa tương tác click.

- [ ] **25. Bìa Album Động Apple Music (Apple Music Animated Album Artwork Suite - Phần 2)**
  - *Mục tiêu*: Tích hợp ảnh bìa động dạng video loop nghệ thuật từ Apple Music thay thế cho ảnh vuông tĩnh khi đang phát nhạc.
  - *Backend Bóc Tách (`backend/ytmusic_helper.py`)*:
    - Bóc tách token web player Apple Music từ `music.apple.com/assets/index~*.js`.
    - Truy vấn Apple Music Search API (`types=songs&include[songs]=albums&extend=editorialVideo` và `types=albums`) theo Tên bài + Nghệ sĩ + Thời lượng (sai số $\le 3\text{s}$).
    - Lọc master playlist HLS `.m3u8` chọn luồng video AVC1 độ phân giải $\ge 720\text{px}$ tối ưu băng thông và giải mã mượt mà.
  - *Giao diện QML (`components/AmberolDetailView.qml` & Cài đặt)*:
    - Phát video loop HLS mượt mà trong thẻ Artwork của AmberolDetailView, có hiệu ứng phủ nền ambient mờ phía sau.
    - Tùy chọn Bật/Tắt "Bìa album động (Animated Cover)" trong `components/SettingsModal.qml`, lưu cấu hình vào `nutsty_settings.json`.

- [ ] **26. Tinh Chỉnh Chiều Sâu Lời Bài Hát & Chuẩn Bo Góc Đồng Tâm (DoF Per-Character Bloom & Concentric Corners - Phần 2)**
  - *Desktop Lyrics Preset 2 (`components/AppleMusicDesktopLyrics.qml`)*:
    - Nâng cấp thuật toán phát quang chữ karaoke: Chiếu sáng bloom chuẩn xác theo từng ký tự dựa trên khoảng cách playhead ($1 - |\text{progress} - \text{charCentre}| / \text{reach}$).
    - Hiệu ứng nhấn nốt ngân dài (held notes): Gia tăng tỷ lệ scale và độ bung sáng bloom khi gặp nốt ngân dài; mở rộng bounding box không giới hạn (unbounded blur) chống xén biên chữ.
  - *Quy chuẩn Bo Góc Đồng Tâm Toàn App*:
    - Chuẩn hóa toàn bộ card bài hát, thumbnail và icon theo công thức $R_{\text{inner}} = R_{\text{outer}} - \text{padding}$, xóa bỏ hoàn toàn hiện tượng lệch góc giữa khung ngoài và phần tử bên trong.

- [ ] **27. Bộ Phiên Âm Lời Bài Hát Đa Ngôn Ngữ (Multi-Language Lyrics Romanization Suite - Phần 3)**
  - *Mục tiêu*: Giúp người dùng dễ dàng hát theo các bài hát tiếng Nhật (Anime/J-pop), tiếng Hàn (K-pop) và tiếng Trung (C-pop) bằng chữ cái Latinh.
  - *Backend Phiên Âm (`backend/lyrics_helper.py`)*:
    - Tích hợp engine phiên âm: Tiếng Nhật (Romaji), Tiếng Hàn (Romaja), Tiếng Trung (Pinyin).
    - Tự động nhận diện ngôn ngữ theo từng câu; sinh dòng phiên âm Latinh tương ứng giữ nguyên mốc thời gian timestamp của synced lyrics.
  - *Giao diện QML (`AmberolDetailView.qml` & `DesktopLyricsWidget.qml`)*:
    - Hiển thị dòng phiên âm Latinh ngay bên dưới câu gốc ở cả màn hình chi tiết bài hát và Desktop Lyrics nổi.
    - Cung cấp toggle switch "Phiên âm lời bài hát Latinh (Romanization)" trong `SettingsModal.qml`.

- [ ] **28. Tối Ưu Hóa Stream Bitrate Cao & Bộ Lọc Hàng Đợi Radio Audio-Only (High Opus/AAC Stream & Radio UGC Filter - Phần 3)**
  - *Chất lượng Stream Bitrate Cao*:
    - Cung cấp cấu hình trong Settings: "Chất lượng cao nhất (High - Opus 256k / itag 774 & 251, AAC 256k / itag 141)" và "Tiêu chuẩn (Normal)".
    - Cấu hình hook `yt-dlp` trong MPV daemon ưu tiên các itag master bitrate cao trước khi fallback về luồng tiêu chuẩn.
  - *Bộ Lọc Radio Audio-Only*:
    - Khi tạo đài phát tự động (`get_watch_playlist` / automix radio), tự động kiểm tra `musicVideoType`, loại bỏ các video fan-made UGC, mashup không chính thức để đảm bảo hàng đợi 50 bài luôn là các bản ghi studio master chính thức.

- [ ] **29. Hẹn Giờ Ngủ Âm Lượng Cosine & Bộ Điều Phối MPV IPC Phân Tầng (Sleep Timer Cosine Fade & Centralized MPV Filter Chain - Phần 5)**
  - *Hẹn Giờ Ngủ (Sleep Timer)*:
    - Bổ sung tùy chọn hẹn giờ tắt nhạc (15 phút, 30 phút, 45 phút, 60 phút, hoặc Hết bài hát hiện tại) trong Settings / Player Bar.
    - Khi hết giờ, tự động hạ âm lượng êm dịu theo đường cong Cosine trong 5 giây, giữ im lặng 800ms rồi mới Pause.
    - Tuyệt đối không can thiệp vào thanh volume người dùng; điều khiển qua `ao-volume` trong MPV để giữ nguyên mức âm lượng ban đầu khi mở lại app.
  - *Kiến Trúc MPV IPC & Quản Lý Bộ Lọc `af` Phân Tầng*:
    - Phân tầng chuỗi bộ lọc `af` tập trung: `[Equalizer] -> [Audio Effects / Reverb] -> [Crossfade]`, thoát ký tự an toàn (`\\` cho `:`, `=`, `\\\` cho `'`).
    - Bảo vệ lệnh tua (`seek`) khi đang crossfade: Lập tức cam kết bài tiếp theo thành bài chính (`commit incoming as current`) trước khi seek để không tua nhầm vào bài đang tắt dần.
    - Tập trung hóa toàn bộ lệnh ghi thuộc tính MPV qua 1 luồng IPC trong daemon để chống xung đột trạng thái.

