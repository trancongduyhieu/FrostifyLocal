# Kế Hoạch Triển Khai: Kết Bạn Toàn Cầu Cloudflare D1 & Discord-style Tag (Nutsty Global Friends Relay)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống kết bạn toàn cầu cho Nutsty Music Player qua Cloudflare D1 & Workers, hỗ trợ định danh Discord Tag (`Username#1234`), đổi tên/tag tự do không mất bạn bè nhờ User UUID bất biến, và đồng bộ hai chiều thời gian thực.

**Architecture:** Cloudflare Worker chạy trên Edge xử lý REST API giao tiếp với cơ sở dữ liệu Cloudflare D1 (SQLite Edge). Daemon cục bộ `backend/auth_server.py` làm cầu nối giữa giao diện QML và Cloudflare Worker, duy trì danh bạ bạn bè theo UUID và tự động lưu đệm cục bộ (Offline-first fallback).

**Tech Stack:** Cloudflare Workers (JavaScript/TypeScript), Cloudflare D1 (Serverless SQLite), Python 3 (Daemon HTTP/IPC), Quickshell (Qt 6 / QML).

---

## 1. Phân Tách Nhiệm Vụ (Task Breakdown)

### Task 1: Xây Dựng Cloudflare Worker & Schema D1 (`cloud_relay/`)
**Files:**
- Create: `cloud_relay/schema.sql`
- Create: `cloud_relay/src/index.js`
- Create: `cloud_relay/wrangler.toml`

- [ ] **Step 1: Định nghĩa Schema SQL Cloudflare D1**
  - Tạo bảng `nutsty_users` (id, secret_key, username, discriminator, tag, avatar_url, created_at, updated_at).
  - Tạo bảng `nutsty_friendships` (id, user_id_1, user_id_2, status, initiated_by, created_at, updated_at).
  - Tạo bảng `nutsty_events` (id, to_user_id, from_user_id, event_type, payload, consumed, created_at).
- [ ] **Step 2: Triển khai Worker Router & Controller**
  - Xử lý `POST /api/users/register`: Đăng ký tài khoản, sinh UUID và 4 số discriminator ngẫu nhiên không trùng.
  - Xử lý `POST /api/users/update_profile`: Cho phép đổi username và đổi discriminator. Kiểm tra trùng `tag UNIQUE`.
  - Xử lý `GET /api/users/search`: Tìm kiếm theo tag chính xác (`Name#1234`), username (`Name`) hoặc số tag (`#1234`).
  - Xử lý `POST /api/friends/request`, `POST /api/friends/respond`, `POST /api/friends/remove`.
  - Xử lý `GET /api/friends`, `GET /api/events`.
- [ ] **Step 3: Kiểm thử cục bộ Worker với Wrangler / Mock Test**
  - Chạy kiểm thử các endpoint đăng ký, đổi tên, tìm kiếm, kết bạn.
- [ ] **Step 4: Commit**

---

### Task 2: Nâng Cấp Backend Client Bridge (`backend/auth_server.py`)
**Files:**
- Modify: `backend/auth_server.py`

- [ ] **Step 1: Quản lý danh tính đám mây an toàn (`nutsty_cloud_identity.json`)**
  - Tự động nạp hoặc tạo `cloud_user_id`, `secret_key`, `username`, `tag`.
  - Không hardcode bất kỳ email hay tên người dùng nào.
- [ ] **Step 2: Kết nối API Cloud Relay xuyên suốt**
  - Định tuyến tìm kiếm `GET /api/users/search` tới Cloud Relay khi có mạng.
  - Chuyển tiếp gửi/nhận/hủy kết bạn tới Cloud Relay.
  - Định kỳ đồng bộ sự kiện `GET /api/events` từ Cloud Relay về local vault.
- [ ] **Step 3: Kiểm tra cú pháp Python**
  - `python3 -m py_compile backend/auth_server.py`.
- [ ] **Step 4: Commit**

---

### Task 3: Cập Nhật Giao Diện Thẻ Cá Nhân & Đổi Tên/Tag (`components/ManageFriendsModal.qml`)
**Files:**
- Modify: `components/ManageFriendsModal.qml`
- Modify: `shell.qml`

- [ ] **Step 1: Cập nhật Thẻ Định Danh Cá Nhân hiển thị chuẩn Discord Tag**
  - Tên to: **Shiraori** kèm Tag màu tím **#6180**.
  - Nút **[ 📋 Sao chép Tag ]**: chép `Shiraori#6180` vào clipboard kèm tooltip `"Đã chép!"`.
  - Nút **[ ✎ Đổi tên ]**: mở dialog/popover phẳng Dark Glass cho phép đổi username và đổi số tag.
- [ ] **Step 2: Cập nhật Thanh Tìm Kiếm Đa Năng**
  - Placeholder: `"Nhập Nutsty Tag (ví dụ: Shiraori#6180) hoặc tên..."`.
- [ ] **Step 3: Hiển thị kết quả tìm kiếm và danh bạ theo Tag**
  - Hiển thị tên hiển thị + Tag tím `#NNNN`, avatar Google Material, nút `[ + Kết bạn ]`.
- [ ] **Step 4: Kiểm tra cú pháp QML**
  - `qmllint components/ManageFriendsModal.qml shell.qml`.
- [ ] **Step 5: Commit**

---

### Task 4: Kiểm Thử Đa Tài Khoản & Nghiệm Thu Trực Quan
**Files:**
- Cả 2 instance Nutsty (`user1` và `user2`)

- [ ] **Step 1: Khởi động backend và 2 instance Nutsty**
  - `scripts/run_dual_profile_test.sh`.
- [ ] **Step 2: Kiểm thử đổi tên và đổi tag**
  - Đổi tên trên User 1 -> Kiểm tra User 2 thấy tên mới cập nhật thời gian thực, không mất quan hệ bạn bè.
- [ ] **Step 3: Kiểm thử tìm kiếm bằng Tag**
  - User 2 gõ Tag của User 1 vào ô tìm kiếm -> Ra đúng User 1.
  - Gửi lời mời -> User 1 nhận chuông đỏ +1.
  - Bấm Chấp nhận -> Cả 2 hiện avatar của nhau trên FriendsPulseBar.
- [ ] **Step 4: Chụp ảnh màn hình nghiệm thu**
  - `/usr/bin/grim` -> `view_file` đánh giá kết quả trực quan.
- [ ] **Step 5: Commit hoàn thành**
