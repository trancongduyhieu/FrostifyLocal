# Code Recipes & Proven Best-Practice Patterns

Tài liệu lưu trữ các kỹ năng lập trình xuất sắc, mẫu kiến trúc (patterns) và đoạn mã chuẩn mực (code recipes) đã được chứng minh hiệu quả trong dự án Nutsty.

---

## Cấu Trúc Chuẩn Cho Mỗi Thẻ Pattern
Mỗi khi người dùng yêu cầu "lưu kỹ năng / mẫu code này lại", AI tự động đúc kết theo cấu trúc 4 phần:
1. **Tên Pattern**: Tên ngắn gọn định danh giải pháp.
2. **Bài Toán Giải Quyết**: Vấn đề kỹ thuật hoặc tình huống áp dụng.
3. **Mã Nguồn Chuẩn Mực**: Đoạn code mẫu hoàn chỉnh (~15–25 dòng), không hardcode, tuân thủ I18n và Liquid Glass.
4. **Lưu Ý Quan Trọng**: Bẫy lỗi, reactive binding hoặc điều kiện biên.

---

## Pattern 1: Nút Bấm Tương Tác Chuẩn Dynamic Accent & Liquid Glass
- **Bài toán**: Tạo nút tương tác, tab pill hoặc icon button hấp thụ màu động `accentColor`, có hover scale và viền hairline 1px mà không bao giờ bị màu xám đen chết.
- **Mã nguồn chuẩn**:
```qml
Rectangle {
    id: btn
    implicitWidth: contentRow.implicitWidth + 24
    implicitHeight: 36
    radius: 18
    color: mouseArea.containsMouse 
           ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
           : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)
    border.color: mouseArea.containsMouse
                  ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.45)
                  : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
    border.width: 1

    scale: mouseArea.containsMouse ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    Behavior on color { ColorAnimation { duration: 150 } }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
```
- **Lưu ý**: Luôn dùng `accentColor` từ context (Theme/Palette); không hardcode màu xám; luôn bọc `scale` và `color` trong `Behavior` để chuyển động êm ái.

---

## Pattern 2: Đa Ngôn Ngữ Song Ngữ Triệt Để & Bố Cục Tự Động Co Giãn
- **Bài toán**: Hiển thị text song ngữ với độ dài chuỗi Tiếng Việt thường dài hơn 1.5x so với Tiếng Anh, tránh bị đè chữ trong `RowLayout` hoặc cắt cụt văn bản.
- **Mã nguồn chuẩn**:
```qml
Row {
    id: buttonContent
    anchors.centerIn: parent
    spacing: 8

    AppIcon {
        iconName: "media-playback-start-symbolic"
        iconSize: 16
        iconColor: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        id: label
        text: I18n.tr("Phát tất cả", "Play All")
        font.pixelSize: 13
        font.weight: Font.Medium
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
    }
}
```
- **Lưu ý**: Dùng `Row` với `anchors.centerIn: parent` và khai báo `implicitWidth: buttonContent.implicitWidth + padding` cho container cha. Tránh dùng fixed width cứng.

---

## Pattern 3: Hình Ảnh Bo Góc Chuẩn Hóa Bằng RoundedImage
- **Bài toán**: Hiển thị ảnh bìa, thumbnail bài hát, avatar hoặc video với các bán kính bo góc khác nhau (`radius: 6`, `8`, `16`, `width/2`), tự động tối ưu RAM/VRAM mà không sinh cụm mask/MultiEffect thủ công.
- **Mã nguồn chuẩn**:
```qml
RoundedImage {
    width: 48; height: 48
    radius: 8
    source: track.cover || track.image || ""
    placeholderColor: Qt.rgba(1, 1, 1, 0.08)
    borderColor: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
    borderWidth: 1
    fallbackIcon: "../assets/icons/folder-music-symbolic.svg"
    fallbackIconSize: 18
    fallbackIconColor: accentColor
}
```
- **Lưu ý**: BẮT BUỘC dùng `RoundedImage` thay vì tự tạo `Rectangle mask + MultiEffect`. Tự động downscale HiDPI 2x tiết kiệm 99% RAM, và tiêu tốn 0 byte VRAM shader khi ảnh chưa tải.
