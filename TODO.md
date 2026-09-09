# TODO.md - Lộ Trình Phát Triển & Tính Năng Mới (Frostify Local)

Danh sách 12 hạng mục công việc (Todo List) được tổng hợp từ yêu cầu người dùng, phân loại theo mức độ ưu tiên kỹ thuật và phương án triển khai chi tiết cho các AI session tiếp theo.

---

## Danh Sách Nhiệm Vụ Chi Tiết (12 Items)

### 1. Waybar / Status Bar Phong Cách Game Gacha & Anime
- **Mục tiêu**: Tạo module thanh trạng thái (Waybar hoặc companion bar chạy trên Quickshell) lấy cảm hứng từ game gacha (Genshin / Star Rail) và video TikTok tham chiếu.
- **Tính năng**:
  - Mini disc xoay / waveform hiển thị trạng thái đang phát.
  - Tên bài hát và ca sĩ cuộn mượt mà với font chữ stylized.
  - Quick control (Play/Pause, Next) dạng popup kính mờ (glassmorphic) khi hover hoặc click.
- **Công nghệ đề xuất**: Quickshell Wayland Layer Shell hoặc custom Waybar custom module (JSON IPC).

---

### 2. Sửa Thanh Trượt Âm Lượng & Thời Lượng (Drag Scrubbing)
- **Vấn đề hiện tại**: Người dùng phải click vào một điểm cụ thể trên thanh progress/volume thì giá trị mới nhảy đến đó, không thể nhấn giữ cục tròn (handle) rồi kéo rê mượt mà.
- **Giải pháp**:
  - Thay thế `MouseArea` click-only trong `components/SpotifyPlayerBar.qml` bằng cơ chế **Draggable Handle** (hoặc `QtQuick.Controls.Slider`).
  - Sử dụng `MouseArea` với `drag.target`, liên tục tính toán tỷ lệ vị trí chuột `mouseX / width` khi đang giữ chuột (`pressed`).
  - Hỗ trợ preview thời gian khi rê chuột và cập nhật mượt mà theo thời gian thực tới `mpv`.

---

### 3. Bộ Lấy Lyric Tự Động Từ Internet (Online Lyrics Fetcher Fallback)
- **Vấn đề hiện tại**: Nhiều bài hát trong máy không có sẵn file `.lrc` đi kèm khiến widget không hiển thị được gì.
- **Giải pháp**:
  - Xây dựng fallback fetcher trong `backend/lyrics_helper.py`: Nếu không tìm thấy file `.lrc` cục bộ, tự động query lên internet theo `artist + title`.
  - **Dịch vụ đề xuất**: **LRCLIB API** (`https://lrclib.net/api/get`) - miễn phí 100%, mã nguồn mở, không cần API key, trả về timestamped synched lyrics chuẩn xác.
  - Tự động lưu file `.lrc` tải về vào cache hoặc thư mục bài hát để không cần fetch lại lần sau.

---

### 4. Bảng Điều Khiển Desktop Lyrics (Bật/Tắt & Tinh Chỉnh Màu Thủ Công / Tự Động)
- **Mục tiêu**: Cho phép người dùng toàn quyền kiểm soát Desktop Lyrics trên giao diện.
- **Tính năng**:
  - Switch bật/tắt hiển thị Desktop Lyrics ngay tại thanh điều khiển hoặc menu cài đặt.
  - Chế độ màu:
    - **Chế độ Auto (Mặc định)**: Tự động trích xuất màu sắc thích ứng từ hình nền qua `palette_extractor.py`.
    - **Chế độ Manual (Tùy chỉnh)**: Color Picker hoặc bảng chọn preset màu yêu thích (Vàng hoàng gia, Xanh thiên thanh, Hồng pastel, Trắng tối giản).

---

### 5. Tích Hợp Trình Tải Nhạc Qua `anpan` (One-Click Downloader)
- **Mục tiêu**: Thêm nút tải nhạc trong ứng dụng.
- **Quy trình hoạt động**:
  - Người dùng bấm nút "Download" -> Hiện popup dán link YouTube / YouTube Music.
  - App gọi CLI `anpan` đã có sẵn tại `/home/apple/.local/bin/anpan`:
    `anpan -o ~/Music/Downloads_Phone "<URL>"`
  - Hiển thị tiến trình tải trực tiếp trên giao diện.
  - Khi hoàn tất, tự động kích hoạt `backend/library.py` để quét và thêm ngay bài hát vào thư viện mà không cần khởi động lại.

---

### 6. Menu Chuột Phải & Quản Lý Hàng Đợi (Context Menu & Queue Management)
- **Tham khảo từ SimpMusic** (`/home/apple/Applications/SimpMusic`):
  - Nhấp chuột phải (Right Click) vào bất kỳ bài hát nào trong `TrackCard` hoặc `TrackRow` để mở Context Menu:
    - *Phát tiếp theo (Play Next)*.
    - *Thêm vào hàng đợi (Add to Queue)*.
    - *Xóa khỏi thư viện / Xóa file gốc trên đĩa*.
    - *Mở vị trí thư mục trong File Manager*.
    - *Xem chi tiết nghệ sĩ & Album*.
- **Hàng đợi (Queue)**: Thêm panel danh sách các bài hát chuẩn bị phát để người dùng sắp xếp thứ tự.

---

### 7. Hoàn Thiện & Kích Hoạt Tính Năng Album (Interactive Albums)
- **Vấn đề hiện tại**: Tab Album hiện chỉ hiển thị card và dấu cộng `+`, bấm vào không có tác dụng.
- **Giải pháp**:
  - Bấm vào Album Card: Mở trang danh sách toàn bộ bài hát thuộc Album đó (kèm cover art lớn, nghệ sĩ, năm phát hành).
  - Bấm vào dấu `+`: Thêm toàn bộ bài hát trong Album vào một Playlist mới hoặc thêm vào Hàng đợi (Queue).
  - Nút "Play All" để phát tuần tự toàn bộ Album.

---

### 8. Phát Nhạc Trực Tuyến Qua YouTube Music Token (Online Streaming)
- **Tính năng quan trọng nhất**: Mở và stream nhạc online trực tiếp từ YouTube Music sử dụng token/account như SimpMusic.
- **Nghiên cứu từ SimpMusic**:
  - SimpMusic sử dụng module Innertube giải mã chữ ký stream YouTube trên thiết bị (`CLAUDE.md`).
- **Phương án tối ưu trên Linux/Python**:
  - Sử dụng thư viện `ytmusicapi` (Python) để đăng nhập và lấy OAuth / Visitor Token của YouTube Music, lấy danh sách đề xuất, tìm kiếm online và playlist cá nhân.
  - `mpv` đã hỗ trợ native giao thức stream YouTube qua `yt-dlp` (`mpv ytdl://<videoId>` hoặc truyền trực tiếp audio URL 256kbps Opus/AAC). Không cần tải bài hát về ổ cứng mà vẫn nghe nhạc mượt mà.

---

### 9. Hệ Thống Đa Preset Cho Desktop Lyrics (Preset Lyrics System)
- **Mục tiêu**: Kiến trúc module linh hoạt cho phép người dùng chọn các kiểu hiển thị lyric khác nhau:
  - **Preset 1 (Gacha Harry Potter - Hiện tại)**: Chữ lệch sole tự nhiên trên tà váy, gacha pop nảy từ, câu kết thúc chìm sâu +52px và nghiêng 1.8°.
  - **Preset 2 (Spotify Classic Duo)**: 2 dòng lyric căn giữa truyền thống, câu đang hát phát sáng, câu kế tiếp mờ.
  - **Preset 3 (Cinematic Drift Flow)**: Lyric chạy ngang chậm rãi từ phải sang trái với dải gradient fade 2 bên mép.
  - **Preset 4 (Minimalist Floating Pill)**: Viên nang kính mờ nhỏ gọn ở góc màn hình hiển thị 1 dòng duy nhất.

---

### 10. Nút Đồng Bộ Nhạc 1-Chạm Từ Điện Thoại Qua ADB (1-Click ADB Phone Sync)
- **Mục tiêu**: Tự động đồng bộ các bài hát đã tải trên SimpMusic điện thoại về PC.
- **Công cụ**: Sử dụng Google Platform Tools `adb` (`/home/apple/.local/bin/adb`).
- **Quy trình hoạt động**:
  - Nút "Sync from Phone" trên thanh tiêu đề / sidebar.
  - Kiểm tra kết nối thiết bị: `adb devices` (thiết bị `2bd3dce5` đã kết nối).
  - Quét thư mục nhạc trên điện thoại (ví dụ: `/storage/emulated/0/Music/SimpMusic/` hoặc app data).
  - Tự động so sánh danh sách và chỉ `adb pull` các file mới tải về thư mục `~/Music/SimpMusic/Tracks/`.
  - Tự động re-scan thư viện sau khi kéo xong.

---

### 11. Tối Ưu Hiệu Năng & Tiết Kiệm RAM (Cân Nhắc Rust Backend)
- **Mục tiêu**: Giảm dung lượng RAM tiêu thụ và tăng tốc độ phản hồi.
- **Đánh giá**:
  - Hiện tại Quickshell (Qt 6) và mpv tiêu thụ khoảng 60-120MB RAM, rất nhẹ so với Electron (Spotify ngốn 600MB+).
  - **Lộ trình dài hạn**:
    - Viết lại `backend/player_daemon.py` và `library.py` bằng **Rust** (sử dụng `libmpv` crate hoặc Unix socket IPC + `symphonia` audio tagger).
    - Giúp backend chạy siêu nhẹ (< 10MB RAM) và thời gian quét thư viện hàng nghìn bài hát chỉ dưới 100ms.

---

### 12. Thiết Kế Bản Sắc Giao Diện Độc Bản (Diverge from Spotify Clone)
- **Mục tiêu**: Thoát khỏi cái bóng "bản sao Spotify" để xây dựng ngôn ngữ thiết kế độc quyền.
- **Ý tưởng thiết kế**:
  - Kết hợp phong cách **Anime Cyberpunk / Gacha Glassmorphic** (thủy tinh mờ, đường cắt góc sắc sảo, icon vẽ tay).
  - Hiệu ứng ánh sáng hào quang đồng bộ theo màu hình nền desktop.
  - Thẻ bài hát mô phỏng theo thẻ nhân vật game thẻ bài (Gacha Card Style).
