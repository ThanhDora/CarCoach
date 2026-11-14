# CarCoach

Ứng dụng iOS & iPadOS ôn luyện và thi thử sát hạch lý thuyết Giấy phép lái xe (GPLX) tại Việt Nam, tích hợp trọn bộ **600 câu hỏi chuẩn**, **84 biển báo theo QCVN 41:2019**, lộ trình ôn tập ngắt quãng thông minh và nhận diện biển báo trực tiếp trên thiết bị bằng **Apple Vision**.

---

## Tính năng nổi bật

### 1. Ngân hàng 600 câu hỏi & 15 hạng GPLX
- Hỗ trợ đầy đủ **15 hạng giấy phép lái xe** theo phân hạng mới:
  - **Mô tô & Xe máy**: `A1` (250 câu, 20 câu điểm liệt), `A` (250 câu, 20 câu điểm liệt), `B1` (300 câu, 20 câu điểm liệt).
  - **Ô tô con, Xe tải, Xe khách & Rơ-moóc** (600 câu, 60 câu điểm liệt): `B`, `C1`, `C`, `D1`, `D2`, `D`, `BE`, `C1E`, `CE`, `D1E`, `D2E`, `DE`.
- Chia theo **6 chương chuẩn**:
  1. Quy định chung và quy tắc giao thông đường bộ *(180 câu)*
  2. Văn hóa giao thông, đạo đức người lái xe, PCCC và cứu hộ *(25 câu)*
  3. Kỹ thuật lái xe *(58 câu)*
  4. Cấu tạo và sửa chữa thông thường *(37 câu)*
  5. Biển báo hiệu đường bộ *(185 câu)*
  6. Giải thế sa hình và kỹ năng xử lý tình huống giao thông *(115 câu)*
- Tìm kiếm tức thì không dấu / có dấu theo nội dung câu hỏi, phương án trả lời, giải thích, số thứ tự câu hoặc mã biển báo.

### 2. Song hành 2 mốc quy định sát hạch (Hiện hành & Từ 01/03/2027)
- Cho phép chọn chế độ **Tự động theo ngày** (tự động chuyển đổi từ `00:00 01/03/2027` giờ Việt Nam) hoặc chuyển đổi thủ công giữa hai giai đoạn.

| Hạng GPLX | Trước 01/03/2027 (Số câu / Thời gian / Điểm đạt / Điểm liệt) | Từ 01/03/2027 (Số câu / Thời gian / Điểm đạt / Điểm liệt) |
| :--- | :--- | :--- |
| **A1** | 25 câu / 19 phút / 21 điểm / 1 câu liệt | 25 câu / 19 phút / 21 điểm / 1 câu liệt |
| **A, B1** | 25 câu / 19 phút / 23 điểm / 1 câu liệt | 25 câu / 19 phút / 23 điểm / 1 câu liệt |
| **B** | 30 câu / 20 phút / 27 điểm / 1 câu liệt | 50 câu / 33 phút / 45 điểm / 2 câu liệt |
| **C1** | 35 câu / 22 phút / 32 điểm / 1 câu liệt | 55 câu / 36 phút / 50 điểm / 2 câu liệt |
| **C** | 40 câu / 24 phút / 36 điểm / 1 câu liệt | 60 câu / 40 phút / 54 điểm / 2 câu liệt |
| **D1, D2, D, BE, C1E, CE, D1E, D2E, DE** | 45 câu / 26 phút / 41 điểm / 1 câu liệt | 65 câu / 42 phút / 59 điểm / 2 câu liệt |

### 3. Thi thử mô phỏng sát thực tế
- **Đề ngẫu nhiên chuẩn ma trận**: Phân bổ đúng tỷ lệ câu hỏi theo từng chương và trộn ngẫu nhiên câu điểm liệt.
- **Bộ đề cố định theo hạng**: Tạo đề ổn định bằng thuật toán sinh số ngẫu nhiên có seed theo từng hạng và giai đoạn quy định.
- **Luyện chuyên sâu câu điểm liệt**: Tập trung toàn bộ các câu sai là trượt trực tiếp.
- **Chấm điểm & lưu lịch sử**: Đồng hồ đếm ngược, gắn cờ câu phân vân, kiểm tra điều kiện trượt do sai/bỏ trống câu điểm liệt và xem lại chi tiết từng lần thi.

### 4. Lộ trình học thông minh & Giải thích chuyên sâu (AI Tutor)
- **Điểm sẵn sàng thi (Readiness Score)**: Tính toán tự động dựa trên độ phủ ngân hàng câu hỏi (40%), tỷ lệ vững câu điểm liệt (30%) và kết quả 3 đề thi gần nhất (30%).
- **Ôn tập ngắt quãng (Spaced Repetition)**: Tự động lên lịch nhắc ôn theo mức độ thành thạo của từng câu, gom nhóm câu hay sai, câu đến hạn và chương yếu nhất.
- **AI Tutor Offline**: Phân tích từng phương án đúng/sai, giải thích quy tắc cốt lõi kèm điều khoản biển báo liên quan, tình huống giao thông thực tế và mẹo ghi nhớ nhanh.

### 5. Thư viện Biển báo QCVN 41:2019 & Quét Biển báo bằng Apple Vision
- Tra cứu **84 biển báo & vạch kẻ đường** thuộc 6 nhóm: Biển báo cấm (`P`), Biển nguy hiểm (`W`), Biển hiệu lệnh (`R`), Biển chỉ dẫn (`I`), Biển phụ (`S`), Vạch kẻ đường (`V`), kèm mức phạt tham khảo và liên kết trực tiếp sang các câu hỏi sát hạch liên quan.
- **Vision Sign Scanner (100% On-Device)**: Kết hợp `VNRecognizeTextRequest` (`vi-VN`, `en-US`), `VNDetectRectanglesRequest` và phân tích hình học + phổ màu HSV trên thiết bị để nhận diện biển báo từ ảnh chụp mà không cần kết nối Internet.

### 6. Kiến trúc & Giao diện
- **Claude-inspired Design System (`ClaudeTheme`)**: Typography kết hợp Serif & Sans-serif hiện đại, độ tương phản cao, hỗ trợ chế độ Sáng / Tối / Theo hệ thống.
- **Vector Graphics (`DiagramCanvasView`)**: Vẽ trực tiếp hệ thống biển báo và sa hình giao thông bằng SwiftUI sắc nét ở mọi kích thước màn hình.
- **Nạp dữ liệu 4 tầng an toàn**: `Bundle` JSON → `NSDataAsset` trong Asset Catalog → Source Fallback khi Debug → Dữ liệu nhúng nén RFC-1951 Deflate (`EmbeddedContentData`), đảm bảo hoạt động 100% ngoại tuyến.

---

## Công nghệ sử dụng

- **Ngôn ngữ**: Swift 5 (`MainActor` default isolation, Approachable Concurrency)
- **UI Framework**: SwiftUI + Observation (`@Observable`)
- **Lưu trữ cục bộ**: SwiftData (`QuestionProgressRecord`, `ExamAttemptRecord`, `UserSettingsRecord`)
- **Thị giác máy tính**: Apple Vision & Core Image
- **Thanh toán trong ứng dụng**: StoreKit 2 (`CarCoach.storekit`)
- **Nền tảng mục tiêu**: iOS / iPadOS 17.0 trở lên

---

## Cấu trúc thư mục

```text
CarCoach/
├── Packages/                         # Bản đóng gói cài đặt (.ipa đã ký / LiveContainer)
│   └── CarCoach.app_1.0_1794649228-LC-signed.ipa
├── CarCoach.xcodeproj/               # Dự án Xcode (project.xcproj)
└── CarCoach/
    ├── CarCoachApp.swift             # Điểm khởi chạy ứng dụng & cấu hình SwiftData ModelContainer
    ├── ContentView.swift             # Điều hướng chính (Onboarding & TabView 4 phân mục)
    ├── Assets.xcassets/              # AppIcon, BrandLogo, AccentColor & Data Assets dự phòng
    ├── DesignSystem/
    │   ├── ClaudeTheme.swift         # Bảng màu động, Typography, Card & Button Styles
    │   └── DiagramCanvasView.swift   # Bộ dựng vector biển báo giao thông & sa hình SwiftUI
    ├── Models/
    │   ├── DomainModels.swift        # Mô hình nghiệp vụ (LicenseClass, ExamStructure, Question, TrafficSign...)
    │   └── SwiftDataModels.swift     # Mô hình lưu trữ bền vững SwiftData
    ├── Resources/
    │   ├── questions_600.json        # Ngân hàng 600 câu hỏi lý thuyết GPLX
    │   ├── traffic_signs.json        # Dữ liệu 84 biển báo & vạch kẻ đường QCVN 41:2019
    │   └── CarCoach.storekit         # Cấu hình kiểm thử StoreKit cục bộ
    ├── Services/
    │   ├── CarCoachRepository.swift  # Quản lý dữ liệu, tạo đề, chấm thi, Spaced Repetition & AI Tutor
    │   ├── EmbeddedContentData.swift # Dữ liệu dự phòng nén Deflate RFC-1951
    │   └── StoreKitManager.swift     # Quản lý giao dịch và quyền lợi StoreKit 2
    └── Views/
        ├── Onboarding/               # Thiết lập hạng bằng, mốc quy định & ngày thi mục tiêu
        ├── Dashboard/                # Tổng quan tiến độ, điểm sẵn sàng & lộ trình học thông minh
        ├── Study/                    # Học theo chương, bộ lọc câu hỏi ưu tiên & luyện tập chi tiết
        ├── Exam/                     # Phòng chờ thi, giao diện làm bài đếm ngược & kết quả chấm thi
        ├── Signs/                    # Thư viện biển báo & trình nhận diện biển báo bằng Vision
        └── Profile/                  # Hồ sơ học viên, cài đặt giao diện & CarCoach Premium
```

---

## Hướng dẫn cài đặt & Chạy dự án

### Cài đặt nhanh từ gói `.ipa`
- Tải tệp `CarCoach.app_1.0_1794649228-LC-signed.ipa` trực tiếp tại thư mục [`Packages/`](./Packages/) hoặc trong mục [**Releases (v1.0.0)**](https://github.com/ThanhDora/CarCoach/releases/tag/v1.0.0) để cài đặt qua **LiveContainer** / công cụ Sideload trên iOS & iPadOS 17.0+.

### Biên dịch từ mã nguồn Xcode
1. **Yêu cầu môi trường**:
   - macOS với **Xcode 27.2+** (hỗ trợ định dạng `project.xcproj`).
   - Thiết bị thật hoặc Simulator chạy **iOS / iPadOS 17.0+**.

2. **Mở và chạy dự án**:
   ```bash
   git clone git@github.com:ThanhDora/CarCoach.git
   cd CarCoach
   open CarCoach.xcodeproj
   ```
3. Trong Xcode:
   - Chọn target **CarCoach** và thiết bị iPhone / iPad mong muốn.
   - *(Tùy chọn)* Để kiểm thử thanh toán cục bộ, vào **Edit Scheme → Run → Options → StoreKit Configuration** và chọn `CarCoach.storekit`.
   - Nhấn **Cmd + R** để biên dịch và khởi chạy ứng dụng.

---

## Giấy phép

Dự án thuộc bản quyền phát triển của **Dora** (`com.dora.CarCoach`). Mọi quyền được bảo lưu.
