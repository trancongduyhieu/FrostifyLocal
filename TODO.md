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

- [ ] **5. Tích Hợp Trình Tải Nhạc Qua `anpan` (One-Click Downloader)**
  - *Công cụ*: Binary `/home/apple/.local/bin/anpan`.
  - *Giao diện*: Nút bấm trên Header dùng **icon SVG chuẩn (TUYỆT ĐỐI KHÔNG DÙNG EMOJI)** mở modal dán link YouTube / YouTube Music.
  - *Luồng chạy*: Chạy ngầm `anpan -o ~/Music/Downloads_Phone "<URL>"`, hiển thị thanh progress bar, tự động trigger `backend/library.py` cập nhật thư viện ngay khi tải xong.

- [ ] **6. Menu Chuột Phải & Quản Lý Hàng Đợi (Context Menu & Queue từ SimpMusic)**
  - *Tham khảo*: Đã clone sẵn mã nguồn SimpMusic tại `/home/apple/Applications/SimpMusic`.
  - *Tính năng*: Chuột phải vào bài hát (`TrackCard`, `TrackRow`):
    - Phát tiếp theo (Play Next).
    - Thêm vào hàng đợi (Add to Queue).
    - Xóa bài hát khỏi thư viện / xóa file đĩa.
    - Mở thư mục chứa file trong file manager.

- [ ] **7. Hoàn Thiện Tính Năng Album (Interactive Albums từ SimpMusic)**
  - *Hiện trạng*: Bấm vào Album không có phản hồi dù hiện dấu cộng.
  - *Giải pháp (học từ SimpMusic)*: Bấm vào Album Card sẽ mở trang hiển thị danh sách toàn bộ bài hát thuộc Album đó; có nút "Play All" để phát từ đầu và nút "Add Album to Queue".

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

- [ ] **9. Hệ Thống Đa Preset Cho Desktop Lyrics (Preset Lyrics System)**
  - *Kiến trúc*: Quản lý qua file JSON `~/.config/noctalia/frostify_settings.json`.
  - *Các Preset hỗ trợ*:
    1. `GachaPop` (Mặc định: lệch dòng sole, gacha pop nảy từ, câu kết thúc rớt sâu +52px và nghiêng 1.8°).
    2. `SpotifyClassic` (2 dòng căn giữa, dòng đang hát sáng rực, dòng tiếp theo mờ).
    3. `CinematicFlow` (Chữ trôi ngang với gradient mờ 2 bên).
    4. `MinimalistPill` (Viên nang kính mờ nhỏ gọn ở góc màn hình).

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

- [ ] **14. Đồng Bộ Lịch Sử Nghe Nhạc Lên YouTube Music (Watch History & Playback Tracking Sync - Đã Làm Rõ 100% Qua /grill-me)**
  - *Mục tiêu*: Gửi lượt nghe thực tế từ Frostify Local lên YouTube Music để Google tính lượt xem/nghe, tối ưu hóa thuật toán cá nhân hóa và kích hoạt lại toàn bộ danh sách "Listen again" (Nghe lại).
  - *Thời điểm kích hoạt (Trigger Threshold)*: Bắt đầu gửi tín hiệu tracking ngay từ những giây đầu tiên (~5 giây đầu khi bắt đầu phát bài hát) theo chuẩn SimpMusic (`initPlayback` với `videostatsPlaybackUrl` và `atrUrl`), tránh chờ quá lâu.
  - *Phạm vi bài hát (Sync Scope)*:
    - Bài Online stream: Sử dụng trực tiếp `videoId` có sẵn.
    - Bài Offline cục bộ (Local MP3/FLAC): Tự động lấy `Title + Artist` tra cứu ngầm trên YouTube Music để tìm `videoId` tương ứng và gửi đồng bộ lên tài khoản Google.
  - *Phản hồi trực quan trên UI (Instant Reactive Update)*:
    - Khi bài hát được ghi nhận lịch sử thành công, tự động chèn bài hát vừa nghe lên vị trí đầu tiên của hàng "Listen again" trong bộ nhớ cache QML ngay lập tức (0ms visual feedback) mà không cần chờ tải lại toàn bộ trang.
  - *Cơ chế dự phòng & Khắc phục rớt mạng (Pending Queue & Self-Healing)*:
    - Nếu mất mạng hoặc API timeout, lưu tạm bài hát vào `~/.cache/frostify/pending_history.json`.
    - Tự động quét hàng đợi và gửi bù lên YouTube Music khi có kết nối mạng trở lại hoặc khi chuyển sang bài hát tiếp theo.
  - *Cấu hình người dùng*: Bổ sung switch bật/tắt đồng bộ (`Sync Playback to Google / sendBackToGoogle`) trong Settings Dark Glass.

- [ ] **15. Mở Rộng Tìm Kiếm Đa Phân Loại: Kệ Album, Nghệ Sĩ & Bài Hát Liên Quan (Categorized Search)**
  - *Hiện trạng*: Tìm kiếm YouTube Music hiện tại chỉ trả về danh sách các bài hát đơn lẻ.
  - *Nâng cấp*: Phân loại kết quả tìm kiếm theo `resultType` (hoặc truy vấn kết hợp Songs, Albums, Artists):
    - **Top Result**: Kết quả trùng khớp nhất dạng Banner/Card lớn.
    - **Songs**: Lưới danh sách bài hát có thể click nghe ngay.
    - **Albums**: Kệ ngang các Album liên quan trực tiếp đến từ khóa tìm kiếm (bấm vào mở danh sách bài trong album).
    - **Artists & Playlists**: Kệ các Playlist tổng hợp và kênh nghệ sĩ chính thức.

- [ ] **16. Tab Artwork: Hiển Thị Chi Tiết Nghệ Sĩ, Lượt Xem/Thích/Không Thích & Mô Tả Bài Hát (SimpMusic Metadata Inspector)**
  - *Mục tiêu*: Biến tab Artwork trong `AmberolDetailView` thành bảng thông tin chi tiết bài hát chuyên nghiệp như SimpMusic.
  - *Dữ liệu tích hợp*:
    - Tên nghệ sĩ kèm số lượng người đăng ký (Subscribers count, ví dụ: "mindfreakkk • 120K subscribers").
    - Thời gian phát hành / Ngày tải lên (Publish / Upload Date).
    - Lượt xem (View count), lượt thích (Like count).
    - Lượt không thích (Dislike count - tích hợp API `https://returnyoutubedislikeapi.com/Votes?videoId={videoId}`).
    - Mô tả bài hát (Song description / Credits / Lyrics text nếu có).
