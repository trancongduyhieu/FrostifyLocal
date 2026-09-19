# Design System, Liquid Glass & Visual Effects Specification

Tài liệu đặc tả chuyên sâu về hệ thống đồ họa, ngôn ngữ thiết kế Dark Glass, hiệu ứng quang học và quy chuẩn hình học thị giác của dự án Nutsty.

---

## 1. Thuật Toán Kính Lỏng Liquid Glass (Kế Thừa SimpMusic)
- **Tệp cốt lõi**: `components/LiquidGlassContainer.qml` (tham chiếu: `SimpMusic/LiquidGlassContainer.kt`).
- **Nguyên lý quang học**:
  - Tăng cường độ rực rỡ màu sắc quang học (`Vibrancy 1.6x`) kết hợp bù trừ bão hòa để triệt tiêu hiện tượng màng sữa đục trắng (`milky fog`) thường gặp trong Qt Quick và Wayland layer-shell.
  - Tán sắc viền quang học (Chromatic Dispersion Compensation): Giữ cho viền kính luôn trong suốt, không tạo quầng trắng quanh các góc bo.
- **Quy tắc tuyệt đối**: Tuyệt đối không thay thế Liquid Glass bằng các khối `Rectangle` đơn giản mang màu đục `rgba(255,255,255,0.1)` vì sẽ làm phá hủy hiệu ứng chiều sâu điện ảnh của ứng dụng.

---

## 2. Định Lý Bo Góc Đồng Tâm & Hairline Borders
- **Công thức hình học**:
  $$\large R_{\text{con}} = R_{\text{mẹ}} - \text{Padding}$$
  - *Ví dụ mẫu*: Với thẻ cha có $R_{\text{mẹ}} = 12\text{px}$ và `padding: 6px`, ảnh hoặc phần tử con bên trong bắt buộc phải có $R_{\text{ảnh}} = 12 - 6 = 6\text{px}$.
- **Hairline Border 1px**:
  - Toàn bộ card, hàng đợi (Queue Track Items) và Mood Chips bắt buộc phải có viền siêu mảnh 1px:
    - *Tĩnh (Idle)*: `Qt.rgba(1, 1, 1, 0.07)`
    - *Rê chuột (Hover)*: `Qt.rgba(1, 1, 1, 0.18)`
    - *Bài đang phát (Active)*: `Qt.rgba(accent.r, accent.g, accent.b, 0.45)`
  - Có viền hairline 1px trực tiếp trên mép ảnh bìa; tuyệt đối không để các thành phần trôi nổi không viền.

---

## 3. Quy Chuẩn Màu Sắc Nút Bấm & Popover (Cấm Tuyệt Đối Nút Xám Đen)
- **Cấm tiệt**: Không sử dụng màu xám đen chết (`rgba(255, 255, 255, 0.06)`, `0.08`, `#18181b`, `#27272a`) cho bất kỳ nút tương tác, pill button, selector hay popover nào.
- **Chuẩn hóa Interactive Controls (Dynamic Chromatic Salience)**:
  - Hấp thụ màu sắc động `accentColor` từ hình nền desktop hoặc ảnh bìa bài hát (`root.accentColor` từ `nutsty_palette.json`).
  - *Trạng thái tĩnh*: Nền `Qt.rgba(accent.r, accent.g, accent.b, 0.12)`, viền hairline 1px `Qt.rgba(accent.r, accent.g, accent.b, 0.25)`, text trắng sáng `#ffffff`, icon mang sắc thái `accent`.
  - *Trạng thái hover*: Nền `Qt.rgba(accent.r, accent.g, accent.b, 0.22)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.45)`.
- **Hộp thoại Popover Menu / Dropdown List**:
  - Nền kính sẫm hữu cơ: `Qt.rgba(0.06 + accent.r * 0.08, 0.06 + accent.g * 0.08, 0.08 + accent.b * 0.12, 0.96)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.35)`.
  - *Mục đang chọn*: Nền `Qt.rgba(accent.r, accent.g, accent.b, 0.26)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.45)`, text trắng kèm icon checkmark `emblem-ok-symbolic.svg` màu `accent`.
  - *Mục hover*: Nền `Qt.rgba(accent.r, accent.g, accent.b, 0.14)`, viền `Qt.rgba(accent.r, accent.g, accent.b, 0.25)`.
- **Nút hành động nhạy cảm / Đăng xuất / Xóa (Destructive Muted Rose)**:
  - *Trạng thái tĩnh*: Nền đỏ hoa hồng `Qt.rgba(244, 63, 94, 0.12)`, viền `Qt.rgba(244, 63, 94, 0.26)`, text hồng đào `#fda4af`.
  - *Trạng thái hover*: Nền đỏ ấm `Qt.rgba(239, 68, 68, 0.24)`, viền `Qt.rgba(239, 68, 68, 0.48)`, text trắng hồng `#ffe4e6`.

---

## 4. Cơ Chế Xuyên Thấu Khi Pause & Hòa Sắc Khi Play (Footgun #1)
- **Tệp**: `shell.qml` và `components/MainTrackGrid.qml`.
- **Ràng buộc cốt lõi**:
  - `effectiveAccentColor`: `(win.currentTrack && win.isPlaying) ? win.songAccentColor : win.wallpaperAccentColor`
  - `playingBackdropCover.opacity`: `(win.currentTrack && win.isPlaying) ? 1.0 : 0.0` (với `duration: 400`, `Easing.InOutQuad`)
  - `fallbackPlayingImg.opacity`: `(win.currentTrack && win.isPlaying) ? 1.0 : 0.0`
  - `nutstySurfaceArtwork.opacity`: `(win.currentTrack && win.isPlaying) ? 0.70 : 0.0`
- **Hành vi trực quan**:
  - *Khi phát nhạc (`isPlaying === true`)*: Backdrop tối `#0a0b0e` mờ dần hiện lên (opacity 1.0) che hình nền desktop, bung tỏa hiệu ứng velvet aurora blur từ bìa bài hát và hòa sắc toàn hệ thống theo `win.songAccentColor`.
  - *Khi tạm dừng (`isPlaying === false`)*: Toàn bộ backdrop mờ dần về `0.0` trong 400ms, đưa cửa sổ về kính mờ acrylic 58% (`Qt.rgba(0.04, 0.04, 0.06, 0.58)`), nhìn xuyên thấu 100% hình nền desktop; accent chuyển mượt mà về `win.wallpaperAccentColor`.
- > [!CAUTION]
  > **Bẫy lỗi tối thượng**: Tuyệt đối không thay `win.isPlaying` bằng `win.currentTrack ? ... : ...`. Làm như vậy sẽ khóa chết ứng dụng ở trạng thái màn hình đen đục và mất tính năng xuyên thấu hình nền khi pause.

---

## 5. Bo Góc Avatar Người Dùng & Chống Lỗi Render Mép Đen
- Sử dụng `MultiEffect` với `maskEnabled: true` để bo góc ảnh mượt mà bằng phần cứng GPU.
- Ảnh đại diện phải lấp đầy 100% diện tích thẻ, không để lại khoảng đệm (moat/margin) trống gây lỗi render màu đen ở 4 góc bo.
- Viền hairline 1px áp dụng trực tiếp trên mép ảnh theo công thức bo góc đồng tâm: $R_{\text{trong}} = R_{\text{ngoài}} - \text{border.width}$.

---

## 6. Nút Điều Hướng Chuẩn Hóa (`components/NavArrowButton.qml`)
- Mọi nút lướt ngang carousel `<` và `>` bắt buộc dùng `NavArrowButton.qml`.
- Tự động liên kết `accentColor`, hiệu ứng hover scale 1.06x và tự động làm mờ (`opacity: 0.28`, `enabled: false`) khi chạm giới hạn cuộn (`canScroll`).
- Không dùng nút `< >` tại `CategorizedSearchView.qml` để giữ giao diện tối giản, người dùng lọc danh mục trực tiếp qua Filter Chips.

---

## 7. Cấm Tự Tiện Dùng Hình Con Nhộng (Anti-Capsule Mandate) & Bố Cục Đồng Phẳng
- **Tuyệt đối cấm hình con nhộng (Pill / Capsule)**: Không dùng `radius = height / 2` trên nút bấm, thẻ, khung hay badge trừ khi được người dùng yêu cầu rõ ràng (như Mood Chips).
- **Chuẩn hóa nút bấm & badge**: Nút bấm dùng $R = 8\text{px}$ (`rounded-lg`), badge $R = 4\text{px}$/6px (`rounded-md`).
- **Bố cục đồng phẳng (Planar Purity)**: Không lồng các khối hộp nổi viền dày chồng chéo (box-in-a-box). Phân vùng bằng khoảng trắng hệ 8pt/16pt và đường kẻ viền siêu mảnh hairline 1px `Qt.rgba(1, 1, 1, 0.08)`.
