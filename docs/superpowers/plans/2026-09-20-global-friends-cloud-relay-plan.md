# Kế Hoạch Triển Khai: Kết Bạn Toàn Cầu & Cloud Relay (Mã PIN, Nutsty Tag & Google Initials Avatar)

> **Mục tiêu**: Xây dựng hệ thống kết bạn toàn cầu qua Mã PIN 6 số và Nutsty Tag, xóa bỏ hoàn toàn icon cờ lê bằng Google Material Initials Avatar Engine, và đồng bộ sự kiện thời gian thực hai chiều xuyên Internet.

---

## 1. Phân Rã Công Việc & Kiến Trúc Từng File

### Các File Tác Động:
1. `components/RoundedImage.qml`:
   - Bổ sung property `initialsText`, `useInitialsFallback` (mặc định `true`).
   - Tích hợp bảng 8 màu Google Material (`#1a73e8`, `#1e8e3e`, `#e37400`, `#8430ce`, `#d93025`, `#0097a7`, `#f29900`, `#3949ab`).
   - Tự động băm (hash) `initialsText` hoặc `source` ra màu nền phẳng và chữ cái đầu in hoa màu trắng.
   - Loại bỏ vĩnh viễn icon cờ lê fallback.
2. `backend/auth_server.py`:
   - Tích hợp bộ sinh và quản lý PIN 6 số: `ensure_user_pin_and_tag(user_email)`.
   - Endpoint `GET /api/users/me`: Trả về thông tin cá nhân kèm `pin_code` và `nutsty_tag`.
   - Endpoint `POST /api/users/regenerate_pin`: Tạo mã PIN mới cho tài khoản.
   - Nâng cấp `GET /api/users/search`: Tự động nhận diện PIN 6 số, Nutsty Tag (chứa `#`), email (chứa `@`), hoặc tên hiển thị.
   - Chuẩn hóa xóa bạn bè `/api/friends/remove` đồng bộ thời gian thực hai chiều cho mọi alias.
3. `components/ManageFriendsModal.qml`:
   - Thêm **Thẻ định danh cá nhân phẳng (My Nutsty PIN & Tag Card)** ở đầu modal:
     - Avatar tròn cá nhân (ảnh Google thật hoặc Google Initials).
     - Tên người dùng và **Nutsty Tag** (`Name#1234`).
     - **Mã PIN 6 số** to rõ (ví dụ: `842 109`) với nút **[ Sao chép ]** (Copy clipboard kèm tooltip "Đã chép!").
     - Nút **[ ↻ Đổi mã ]** đổi PIN mới.
   - Cập nhật ô tìm kiếm với placeholder đa năng và icon định danh.
   - Kết quả tìm kiếm và danh sách bạn bè hiển thị chuẩn Avatar Google Initials.
4. `shell.qml`:
   - Quản lý state `currentUserPin` và `currentUserTag`.
   - Lắng nghe event `friend_removed`, `friend_request`, `friend_accepted` để tự động làm mới danh sách bạn bè tức thì.

---

## 2. Chi Tiết Từng Nhiệm Vụ (Bite-Sized Tasks)

### Task 1: Nâng Cấp `components/RoundedImage.qml` với Google Material Initials Avatar Engine
- **Files**: `components/RoundedImage.qml`
- [ ] **Step 1**: Khai báo properties `initialsText`, `useInitialsFallback` (default `true`).
- [ ] **Step 2**: Xây dựng thuật toán băm chuỗi ra màu Google Material và trích xuất ký tự đầu tiên in hoa.
- [ ] **Step 3**: Render hình tròn nền màu Material phẳng + chữ cái trắng SemiBold khi không có ảnh (`source === ""` hoặc `status !== Image.Ready`).
- [ ] **Step 4**: Kiểm tra cú pháp: `qmllint components/RoundedImage.qml`.

### Task 2: Triển Khai Mã PIN & Nutsty Tag trong `backend/auth_server.py`
- **Files**: `backend/auth_server.py`
- [ ] **Step 1**: Thêm hàm sinh PIN 6 số ngẫu nhiên không trùng lặp và sinh Nutsty Tag `username#NNNN`.
- [ ] **Step 2**: Thêm endpoint `GET /api/users/me` và `POST /api/users/regenerate_pin`.
- [ ] **Step 3**: Nâng cấp `GET /api/users/search` hỗ trợ tìm kiếm bằng PIN 6 số, Nutsty Tag, Email và Tên.
- [ ] **Step 4**: Kiểm tra cú pháp: `python3 -m py_compile backend/auth_server.py`.
- [ ] **Step 5**: Test curl endpoints kiểm chứng PIN và tìm kiếm bằng PIN.

### Task 3: Thiết Kế UI Thẻ Định Danh Cá Nhân & Cập Nhật `components/ManageFriendsModal.qml`
- **Files**: `components/ManageFriendsModal.qml`, `shell.qml`
- [ ] **Step 1**: Thêm thẻ Định Danh Cá Nhân (My Nutsty Tag & PIN) với thiết kế phẳng Dark Glass, nút Copy PIN và nút Đổi mã PIN.
- [ ] **Step 2**: Cập nhật ô tìm kiếm hỗ trợ nhập PIN / Tag / Email.
- [ ] **Step 3**: Truyền `initialsText: modelData.name || modelData.email` vào mọi component `RoundedImage` trong modal.
- [ ] **Step 4**: Kiểm tra cú pháp: `qmllint components/ManageFriendsModal.qml shell.qml`.

### Task 4: Kiểm Thử Tích Hợp Real-Time & Nghiệm Thu Trực Quan
- **Files**: Cả 2 profile (`user1` Shiraori và `user2` Hiếu Trần)
- [ ] **Step 1**: Khởi động daemon `backend/auth_server.py`.
- [ ] **Step 2**: Khởi chạy 2 cửa sổ test qua script `scripts/run_dual_profile_test.sh`.
- [ ] **Step 3**: Kiểm tra:
  - Shiraori lấy mã PIN của Hiếu Trần nhập vào ô tìm kiếm -> Ra đúng Hiếu Trần với avatar chữ H màu xanh biển.
  - Bấm gửi lời mời -> Hiếu Trần nhận thông báo và chuông badge +1 ngay lập tức.
  - Hiếu Trần bấm Đồng ý -> Cả 2 bên hiện avatar của nhau trên thanh bạn bè.
  - Bấm Hủy kết bạn -> Cả 2 bên tự động cập nhật về rỗng ngay lập tức (0ms).
- [ ] **Step 4**: Chụp ảnh màn hình bằng `/usr/bin/grim` và gọi `view_file` để nghiệm thu trực quan.
- [ ] **Step 5**: Git commit toàn bộ thay đổi với thông điệp rõ ràng theo Conventional Commits.
