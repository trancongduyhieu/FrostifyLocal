# Desktop Lyrics Engine & Kinetic Typography Specification

Tài liệu đặc tả chuyên sâu về hệ thống lời bài hát hiển thị trên Desktop (Desktop Lyrics), các hiệu ứng kinetic typography, đổ bóng điện ảnh và thuật toán đồng bộ từng âm tiết (Syllable-level Karaoke) của dự án Nutsty.

---

## 1. Universal Lyrics Harness (`components/DesktopLyricsWidget.qml`)
- **Kiến trúc Host**: Chạy trên nền native Wayland Layer-Shell thông qua Quickshell, neo trực tiếp lên không gian desktop mà không tạo khung cửa sổ XWayland truyền thống.
- **Tọa độ trực quan**: Hiển thị nổi lên hình nền desktop tại vùng hạ tiêu cự / tà váy nhân vật.
- **Tương tác**: Cho phép kéo thả tự do trên màn hình và tự động lưu tọa độ, đồng bộ màu sắc tức thời theo bảng màu `nutsty_palette.json`.

---

## 2. Các Bộ Mẫu Hiển Thị (Lyrics Engine Presets)

### Preset 1: Gacha / Anime Pop (`GachaAnimeLyricsView.qml`)
- **Font chữ**: *Instrument Serif* cổ điển nghệ thuật.
- **Hiệu ứng**:
  - Pop chữ Gacha khi bắt đầu câu mới (scale nảy nhẹ kèm chuyển động baseline so le - staggered baselines).
  - Đổ bóng điện ảnh đa tầng Universal Cinematic Shadows (`#a6020305` và `#66000000`) giúp chữ luôn sắc nét và đọc rõ trên mọi loại hình nền sáng/tối.
  - > [!CAUTION]
    > **Tuyệt đối không dùng viền trắng (White Halo)** quanh chữ lyric vì gây thô ráp và phá hủy thẩm mỹ điện ảnh.

### Preset 2: Apple Music Parametric Multi-Line Engine (`AppleMusicDesktopLyrics.qml`)
- **Bố cục**: Hiển thị đồng thời 5 dòng lời parametric.
- **Hiệu ứng quang học**:
  - Độ sâu trường ảnh quang học (Optical Depth-of-Field - DoF): Dòng hiện tại sắc nét nhất, các dòng trước và sau mờ dần theo gradient Gaussian blur thực tế.
  - Hiệu ứng phát quang lân tinh (Phosphor Bloom) theo nhịp nhạc.

### Preset 3: Minimalist Word-by-Word Motion Blur Engine
- Hiển thị tối giản, làm nhòe chuyển động (motion blur) theo từng từ khi ca sĩ phát âm.

### Preset 4: Anime MV Kinetic Typography Engine
- Hiển thị theo phong cách Motion Graphic trong các MV Anime (chữ trượt, phóng to/thu nhỏ động học).

---

## 3. Đồng Bộ Từng Âm Tiết & Elastic Scaling (Syllable-Level Karaoke)
- **Kế thừa kiến trúc**: Tham chiếu từ SimpMusic Footgun #217 & AMLL (Apple Music Like Lyrics).
- **Nguyên lý hoạt động**:
  - Phân tích cú pháp lời bài hát nâng cao (enhanced LRC / TTML / syllable timestamps).
  - Với các nốt ngân dài (held notes), áp dụng hoạt ảnh co giãn đàn hồi (elastic scaling) cho từ đang hát thay vì dịch chuyển đột ngột.
  - Đảm bảo chuyển động mượt mà ở 60/120 FPS trên Wayland bằng cách sử dụng các thuộc tính nội suy GPU của Qt Quick.

---

## 4. Cơ Chế Tìm Lời Bài Hát Tự Động (Online Synced Lyrics Fetcher)
- **Tệp**: `backend/lyrics_helper.py`.
- **Thứ tự ưu tiên nạp lời**:
  1. File `.lrc` cục bộ có sẵn cùng thư mục với file nhạc.
  2. Fallback trực tuyến tự động qua thư viện `syncedlyrics` theo tuần tự:
     $$\text{LRCLIB} \longrightarrow \text{NetEase Cloud Music} \longrightarrow \text{Musixmatch}$$
- **Bộ nhớ đệm (Cache)**: Tự động lưu cache file lời bài hát tìm được để tái sử dụng tức thì trong các lần phát sau mà không tốn băng thông mạng.
