# TODO.md - Lộ Trình Phát Triển Chi Tiết (Frostify Local)

Tài liệu quản lý tác vụ (Roadmap & Todo List) cho Frostify Local. Đã được làm rõ 100% qua quy trình phỏng vấn (/grill-me) cùng người dùng.

---

## Danh Sách 12 Hạng Mục Đã Chốt Phương Án Triển Khai

- [ ] **1. Waybar / Status Bar Phong Cách Game Gacha & Anime (Tách riêng bên Noctalia)**
  - *Phạm vi*: Nằm bên repo `noctalia-shell` (`/etc/xdg/quickshell/noctalia-shell` hoặc cấu hình Waybar), **không** viết vào repo `FrostifyLocal`.
  - *Tích hợp*: Giao tiếp qua socket `/tmp/frostify_mpv.sock` để lấy trạng thái bài hát, mini waveform và đĩa xoay.

- [ ] **2. Sửa Thanh Trượt Âm Lượng & Thời Lượng (Draggable Scrubbing)**
  - *Hiện trạng*: Chỉ click-to-seek, không kéo rê được cục tròn (thumb).
  - *Giải pháp*: Cập nhật `components/SpotifyPlayerBar.qml` dùng `MouseArea` với `drag.target` (hoặc `Slider` có custom thumb) cho phép người dùng nhấn giữ cục tròn và kéo mượt mà theo thời gian thực.

- [ ] **3. Bộ Lấy Lyric Tự Động Từ Internet (Online Synced Lyrics Fallback)**
  - *Công cụ đã chọn*: Sử dụng thư viện Python `syncedlyrics`.
  - *Cơ chế*: Khi `backend/lyrics_helper.py` không tìm thấy file `.lrc` cục bộ, tự động truy vấn tuần tự qua các provider: **LRCLIB $\rightarrow$ NetEase Cloud Music $\rightarrow$ Musixmatch**. Tự động lưu cache file `.lrc` về thư mục bài hát.

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

- [ ] **8. Phát Nhạc Trực Tuyến Qua YouTube Music Token (Online Streaming - QUAN TRỌNG NHẤT)**
  - *Công cụ đã chọn*: Sử dụng thư viện `ytmusicapi` (Python) + `mpv` (với `yt-dlp` hook).
  - *Cơ chế*: Dùng `ytmusicapi` để quản lý token/tài khoản cá nhân, tìm kiếm và lấy luồng phát YouTube Music.
  - *Phát trực tiếp*: Truyền URL âm thanh trực tiếp sang `/tmp/frostify_mpv.sock` để `mpv` stream trực tuyến mà không cần tải file về đĩa, tối ưu RAM cực thấp (< 100MB RAM).

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
