# AGENTS.md - Nutsty Master Architecture & Pair-Programming Guide

Tài liệu đặc tả "Hiến pháp kiến trúc", quy chuẩn kỹ thuật cốt lõi và hệ thống chỉ mục phân tầng dành cho AI Agent / Assistant khi phát triển dự án **Nutsty**.

---

## 1. Tổng Quan Dự Án (Project Overview)

**Nutsty** là trình phát nhạc cục bộ và máy tính để bàn (Desktop Music & Streaming Player) được tối ưu hóa chuyên sâu cho môi trường Linux Wayland (Niri compositor), kết hợp giữa:
- **Giao diện người dùng hiện đại**: Viết bằng **Quickshell (Qt 6 / QML)** với khả năng tăng tốc GPU phần cứng và hỗ trợ native Wayland layer-shell.
- **Backend phát nhạc độ trễ thấp**: Trình điều khiển **Python IPC daemon** (`backend/player_daemon.py`) giao tiếp trực tiếp qua Unix Domain Socket (`/tmp/nutsty_mpv.sock`) với một tiến trình `mpv` chuyên biệt (hỗ trợ gapless playback, hardware decoding, flac/m4a/opus/mp3/ytdl streams).
- **Desktop Lyrics ma thuật phong cách Gacha/Anime**: Hiển thị lyric nổi trực tiếp lên hình nền desktop với font chữ cổ điển *Instrument Serif*, hiệu ứng pop chữ gacha và đổ bóng điện ảnh thích ứng màu sắc hình nền.
- **Bộ máy màu sắc thích ứng Chromatic Salience (OKLAB / OKLCH)**: Trích xuất màu điểm nhấn nghệ thuật từ hình nền hiện tại và cập nhật theo thời gian thực vào `~/.config/noctalia/nutsty_palette.json`.

---

## 2. Quy Tắc Tối Thượng Bất Khả Xâm Phạm (Non-Negotiable Core Rules)

> [!CAUTION]
> 1. **TUYỆT ĐỐI KHÔNG DÙNG EMOJI TRONG GIAO DIỆN**: Mọi nút bấm, trạng thái, modal hay icon phải dùng file SVG hoặc component icon có sẵn (`components/AppIcon.qml` hoặc `assets/icons/*.svg`). Tuyệt đối không dùng ký tự emoji (như 🎵, 📥, ⚙️, ❌) vì gây vỡ giao diện và "phèn".
> 2. **QUY TẮC SONG NGỮ NGHIÊM NGẶT (STRICT BIMODAL LOCALIZATION - NO HYBRID SPANGLISH)**:
>    - Mọi chuỗi ký tự hiển thị trên toàn bộ giao diện **BẮT BUỘC** phải sử dụng qua helper `I18n.tr("Tiếng Việt", "English")` từ singleton `components/I18n.qml`.
>    - Khi ở tiếng Việt (`locale === "vi"`): 100% tiếng Việt thuần túy. Khi ở tiếng Anh (`locale === "en"`): 100% tiếng Anh chuẩn. Không để sót tiếng Anh nửa nạc nửa mỡ.
> 3. **PORTABILITY & NON-HARDCODING**: Tuyệt đối không hardcode đường dẫn người dùng (như `/home/apple/...`). Luôn dùng `Quickshell.env("HOME")` hoặc `pathlib.Path.home()`.
> 4. **WAYBAR & STATUS BAR THUỘC NOCTALIA**: Tinh chỉnh thanh trạng thái Waybar/Noctalia là của repo `noctalia-shell`, không trộn lẫn vào code của Nutsty.
> 5. **RANH GIỚI NGHIÊM NGẶT GIỮA TODO.MD VÀ AGENTS.MD**:
>    - `TODO.md`: Chứa toàn bộ lộ trình (Roadmap), danh sách công việc cần làm kèm checklist `[ ]` / `[x]`.
>    - `AGENTS.md`: Là cẩm nang kiến trúc và chuẩn kỹ thuật của codebase. **CHỈ CHỨA NHỮNG GÌ ĐÃ ĐƯỢC THỰC THI VÀ KIỂM CHỨNG THÀNH CÔNG**.
> 6. **QUY TRÌNH NGHIÊN CỨU TRƯỚC KHI THAY ĐỔI (RESEARCH WORKFLOW)**:
>    - Trước khi thêm thư viện mới, thay đổi kiến trúc hoặc áp dụng pattern mới, AI **BẮT BUỘC** phải:
>      1. Tra cứu tài liệu chính thức (`search_web`, `read_url_content`).
>      2. Đánh giá ưu/nhược điểm, hiệu năng và các giải pháp thay thế.
>      3. Khảo sát các dự án nguồn mở hàng đầu (OSS Best Practices) xem cách họ giải quyết bài toán tương tự.
>      4. Đưa ra giải pháp kỹ thuật tối ưu và trình bày rõ ràng trước khi viết mã nguồn.
> 7. **CHUẨN HÓA MŨI TÊN ĐIỀU HƯỚNG CAROUSEL (`components/NavArrowButton.qml`)**:
>    - Mọi nút lướt ngang carousel `<` và `>` **BẮT BUỘC** dùng `components/NavArrowButton.qml`.
>    - Tự động liên kết `accentColor`, hover scale 1.06x và tự làm mờ khi chạm giới hạn cuộn (`canScroll`). Riêng `CategorizedSearchView.qml` không dùng nút `< >`.
> 8. **CẤM NÚT XÁM ĐEN (DYNAMIC CHROMATIC SALIENCE & MUTED ROSE)**:
>    - Tuyệt đối cấm tạo các nút bấm hoặc popover menu mang màu xám đen chết (`rgba(255, 255, 255, 0.06)`, `#18181b`, `#27272a`).
>    - Nút tương tác phải hấp thụ màu sắc động `accentColor`. Nút xóa/nguy hiểm dùng sắc thái đỏ hoa hồng dịu (Muted Rose `Qt.rgba(244, 63, 94, 0.12)`).
> 9. **QUY TẮC CẬP NHẬT TÀI LIỆU KIẾN TRÚC (ANTI-BLOAT & STRICT BUDGET)**:
>    - **Cấm append nối đuôi mù quáng (No Blind Appends)**: Bắt buộc đọc file rule tương ứng trước (`view_file`), tích hợp có cấu trúc vào đúng domain trong `.agents/rules/`.
>    - **Giới hạn cứng ngân sách**: `AGENTS.md` $\le$ 150 dòng (< 15 KB), mỗi file trong `.agents/rules/` $\le$ 100 dòng (< 10 KB). Nếu vượt, bắt buộc phải refactor và nén gọn trước khi lưu.
>    - **Cấm paste code diffs**: Không đưa code diffs hay code mẫu dài > 5 dòng vào tài liệu kiến trúc. Mỗi đề mục chỉ dài 5–12 dòng: Tên tính năng, Tệp liên quan, Cơ chế hoạt động cốt lõi và Bẫy lỗi (Footgun).
> 10. **QUY TRÌNH ĐÚC KẾT KỸ NĂNG & CODE MẪU XUẤT SẮC (`04-code-recipes-and-patterns.md`)**:
>     - Khi người dùng yêu cầu lưu lại một kỹ năng, pattern hoặc đoạn code mẫu mà AI đã thực hiện tốt: AI **BẮT BUỘC** tự động đúc kết thành 1 thẻ Pattern chuẩn (Tên Pattern, Bài toán giải quyết, Khối code mẫu hoàn chỉnh ~15–25 dòng không hardcode, và Lưu ý quan trọng) rồi ghi vào `.agents/rules/04-code-recipes-and-patterns.md`.
>     - Ngân sách dòng linh hoạt cho file này là $\le$ 200 dòng (< 18 KB) để đảm bảo code mẫu không bị cắt xén logic cốt lõi.

---

## 3. Cấu Trúc Thư Mục (Repository Structure)

```
/home/apple/Applications/FrostifyLocal/
├── run.sh                          # Script khởi chạy 1-chạm (tự quét nhạc và chạy quickshell)
├── shell.qml                       # Entry point QML chính (FloatingWindow Nutsty + DesktopLyricsWidget)
├── library.json                    # Dữ liệu cache danh sách bài hát, metadata và album
├── assets/                         # Font chữ Instrument Serif, icon SVG, dữ liệu tĩnh
├── scripts/
│   └── run_dual_profile_test.sh    # Launcher test 2 profile song song (user1 & user2)
├── backend/
│   ├── auth_server.py              # Resident HTTP daemon (port 17890) phục vụ xác thực Google & fast API
│   ├── browser_login.py            # Script hỗ trợ mở trình duyệt đăng nhập Google
│   ├── download_manager.py         # Daemon tải nhạc đa luồng (yt-dlp, FFmpeg audio 192k, ID3, socket IPC)
│   ├── library.py                  # Bộ quét thư viện nhạc (~/Music) sử dụng Mutagen
│   ├── lyrics_helper.py            # Trích xuất và phân giải file LRC (tích hợp syncedlyrics fallback)
│   ├── palette_extractor.py        # Thuật toán OKLAB Chromatic Salience Clustering
│   ├── player_daemon.py            # CLI wrapper điều khiển mpv qua /tmp/nutsty_mpv.sock
│   ├── playlist_manager.py         # Quản lý danh sách phát cá nhân và danh sách phát hệ thống
│   ├── social_notes.py             # Đồng bộ ghi chú 24h & bắn event nghe cùng (/api/notes/events)
│   └── ytmusic_helper.py           # Engine YouTube Music: personalized home, continuation scrapers, radio
├── components/
│   ├── AmberolDetailView.qml       # Màn hình chi tiết bài hát, đĩa xoay và lyric cuộn Amberol
│   ├── AppleMusicDesktopLyrics.qml # Mẫu 2: Parametric Multi-Line Engine (5 dòng, DoF quang học, phosphor bloom)
│   ├── CircularSpinner.qml         # Con quay loading xoay tròn phong cách Nutsty (270° arc Canvas)
│   ├── DesktopLyricsWidget.qml     # Universal Lyrics Harness (Host Layer-Shell, kéo thả toàn màn hình, palette sync)
│   ├── DownloadManager.qml         # State manager đồng bộ tác vụ tải xuống từ download_manager.py
│   ├── DownloadQueuePopover.qml    # Popover quản lý hàng đợi tải xuống Minimalist Clean (#121212)
│   ├── EnchantingSentence.qml      # Component từng câu lyric: staggered baselines, Gacha pop, đổ bóng
│   ├── FriendsPulseBar.qml         # Thanh avatar bạn bè 24h pulse lướt ngang ở HomeFeed
│   ├── FriendStoryModal.qml        # Modal xem ghi chú bạn bè, đĩa nhạc xoay & nút Nghe Cùng
│   ├── GachaAnimeLyricsView.qml    # Mẫu 1: Presentation view Gacha / Anime Pop (1-line Instrument Serif)
│   ├── HomeFeedView.qml            # Màn hình trang chủ online: Mood pills, carousels và track grids
│   ├── LibraryData.qml             # Model quản lý danh sách bài hát trong QML
│   ├── LibraryLoader.qml           # Loader nạp dữ liệu từ library.json
│   ├── MainTrackGrid.qml           # Grid danh sách bài hát, card hiển thị và nút [ ▶ Phát ] tuần tự
│   ├── NavArrowButton.qml          # Component nút mũi tên điều hướng < và > đồng bộ màu động accentColor
│   ├── NavSidebar.qml              # Sidebar điều hướng [ Playlists | Queue ] hai tab tương tác
│   ├── PlayerBarBottom.qml         # Thanh phát nhạc chính Nutsty (thời lượng, âm lượng, Amberol button)
│   ├── PostNoteModal.qml           # Modal đăng ghi chú 24h kèm đính kèm bài hát
│   ├── RoundedImage.qml            # Chuẩn bo góc Design System (HiDPI 2x, lazy VRAM, fallback)
│   ├── SettingsModal.qml           # Modal đăng nhập Google Account Dark Glass
│   ├── Theme.qml                   # Hệ thống token màu, kích thước bo góc, padding
│   ├── TrackCard.qml               # Card hiển thị từng bài hát trong grid
│   ├── TrackContextMenu.qml        # Menu chuột phải Dark Glass kế thừa từ Nutsty
│   ├── TrackRow.qml                # Dòng hiển thị bài hát trong danh sách hàng đợi
│   └── UserNoteDetailModal.qml     # Modal xem/xóa ghi chú cá nhân Dark Glass
├── .agents/
│   └── rules/                      # Hệ thống quy tắc & kiến trúc chuyên sâu phân tầng
│       ├── 01-design-system-and-visual-effects.md
│       ├── 02-audio-backend-and-queue-lifecycle.md
│       ├── 03-desktop-lyrics-engine.md
│       └── 04-code-recipes-and-patterns.md
├── AGENTS.md                       # File này (Hiến pháp kiến trúc tối cao)
└── TODO.md                         # Danh sách tính năng và lộ trình phát triển đã chốt
```

---

## 4. Hệ Thống Quy Tắc & Kiến Trúc Chuyên Sâu (Progressive Disclosure Index)

Để tối ưu hóa ngữ cảnh và không làm tràn bộ nhớ của AI, các đặc tả kỹ thuật chi tiết và bẫy lỗi xương máu (Footguns) được phân tầng vào thư mục `.agents/rules/`. AI **BẮT BUỘC** gọi `view_file` trên tệp quy tắc tương ứng trước khi thực hiện chỉnh sửa trong từng phân vùng:

| Lĩnh vực phụ trách | Tệp quy tắc chuyên sâu | Nội dung cốt lõi & Bẫy lỗi (Footguns) |
| :--- | :--- | :--- |
| **Giao diện, Đồ họa & Kính lỏng** | [01-design-system-and-visual-effects.md](file:///.agents/rules/01-design-system-and-visual-effects.md) | - Thuật toán Kính lỏng Liquid Glass (Vibrancy 1.6x, chống đục trắng SimpMusic).<br/>- Định lý bo góc đồng tâm $R_{\text{con}} = R_{\text{mẹ}} - \text{Padding}$ & viền hairline 1px.<br/>- **Footgun #1**: Cơ chế xuyên thấu hình nền khi pause (`win.isPlaying ? 1.0 : 0.0`).<br/>- Bo góc avatar người dùng qua `MultiEffect` không vỡ góc đen. |
| **Âm thanh, IPC & Hàng đợi** | [02-audio-backend-and-queue-lifecycle.md](file:///.agents/rules/02-audio-backend-and-queue-lifecycle.md) | - Backend Python daemon & Unix Socket `/tmp/nutsty_mpv.sock` (gapless stream).<br/>- Phân lập luồng duyệt (`browsingTracks`) vs Hàng đợi thực tế (`currentTracks`).<br/>- Tách bạch Browsing Title vs Playing Source Title (chống xung đột trạng thái).<br/>- **Cơ chế Snapshot & Reset Queue an toàn** khi chuyển đổi Mood Chips.<br/>- Trình tải nhạc đa luồng `download_manager.py` & Lưu trữ cài đặt an toàn. |
| **Lời bài hát Desktop Lyrics** | [03-desktop-lyrics-engine.md](file:///.agents/rules/03-desktop-lyrics-engine.md) | - Host Native Wayland Layer-Shell qua Quickshell.<br/>- 4 Presets: Gacha Anime Pop (Instrument Serif), Apple Music Multi-line DoF, Motion Blur, Kinetic Typography.<br/>- **Tuyệt đối cấm viền trắng (White Halo)**, dùng Universal Cinematic Shadows.<br/>- Đồng bộ âm tiết Syllable-level Karaoke & Elastic scaling (SimpMusic Footgun #217). |
| **Kỹ Năng & Mẫu Code Chuẩn** | [04-code-recipes-and-patterns.md](file:///.agents/rules/04-code-recipes-and-patterns.md) | - Thẻ Pattern chuẩn cho các kỹ năng/giải pháp xuất sắc đã được kiểm chứng.<br/>- Code mẫu chuẩn Dynamic Accent & Liquid Glass Button.<br/>- Bố cục đa ngôn ngữ song ngữ co giãn (`Row` + `I18n.tr`). |

---

## 5. Quy Chuẩn Kiểm Tra Trước Khi Hoàn Thành (Mandatory Verification)

Mọi thay đổi mã nguồn trước khi báo cáo hoàn thành hoặc commit đều **BẮT BUỘC** trải qua quy trình kiểm thử 4 bước:
1. **Kiểm tra cú pháp QML**: `qmllint components/*.qml shell.qml` (đảm bảo không phát sinh lỗi biên dịch).
2. **Kiểm tra cú pháp Python**: `python3 -m py_compile backend/*.py`.
3. **Thực nghiệm giao diện trực quan**: Chạy ứng dụng qua `run_command` -> Chụp ảnh màn hình bằng `/usr/bin/grim` -> Xem trực tiếp bằng `view_file` để đánh giá kết quả thực tế.
4. **Git Commit & Push**: Đảm bảo commit thông điệp rõ ràng theo chuẩn Conventional Commits và push lên nhánh `main`.
