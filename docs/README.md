# Tài liệu EsquiloSpeak

Tài liệu được nhóm theo vai trò để giữ đường dẫn và nguồn chuẩn rõ ràng.

## Bắt đầu đọc

1. [Tổng quan dự án](shared/Esquilo_Speak.md)
2. [Phạm vi và mô hình sản phẩm](shared/Project.md)
3. [Nghiệp vụ hoàn chỉnh](shared/Nghiep_Vu.md)
4. [Kế hoạch Phần 1](plans/Ke_Hoach_1.md)
5. [Kế hoạch Phần 2](plans/Ke_Hoach_2.md)
6. [Hướng dẫn chạy và kiểm thử](shared/Guide.md)

## Nhóm tài liệu

```text
docs/
├── README.md                  Chỉ mục tài liệu
├── plans/                     Roadmap, gate và kế hoạch thực thi
├── shared/                    Product, nghiệp vụ và hướng dẫn dùng chung
├── architecture/              Kiến trúc và cấu trúc repository
├── decisions/                 ADR và quyết định đã được chấp nhận
├── operations/                Runbook, SLO, security và release gate backend
├── reference/                 Tài liệu tra cứu API/contract
├── process/                   Quy trình phát triển và nhật ký thay đổi
└── assets/                    Hình ảnh/tài nguyên của tài liệu
```

### Plans

- [Kế hoạch Phần 1](plans/Ke_Hoach_1.md): foundation đến Giai đoạn 12 và Giai
  đoạn 13 release readiness đang tạm khóa.
- [Kế hoạch Phần 2](plans/Ke_Hoach_2.md): các giai đoạn hoàn thiện learning
  product trước khi mở Giai đoạn 13.
- [Kế hoạch triển khai](plans/implementation_plan.md): kế hoạch kỹ thuật chi tiết cho
  các thay đổi đang hoặc đã được phê duyệt.
- [P0 Gate](plans/P0_GATE.md): quyết định, acceptance criteria và service target P0.

### Shared

- [Esquilo Speak](shared/Esquilo_Speak.md)
- [Project](shared/Project.md)
- [Nghiệp vụ](shared/Nghiep_Vu.md)
- [Guide](shared/Guide.md)

### Architecture và decisions

- [Tech stack và kiến trúc](architecture/Tech_Stack_And_Architecture.md)
- [Cấu trúc repository](architecture/Repository_Structure.md)
- [Danh mục ADR](decisions/README.md)

### Operations và reference

- [Backend operations](operations/Backend_Operations_Runbook.md)
- [Backend SLO/load test](operations/Backend_Slo_And_Load_Test.md)
- [Backend ASVS review](operations/Backend_Asvs_Review.md)
- [Backend release gate](operations/Backend_Release_Gate.md)
- [API Check](reference/API_Check.md)

### Process

- [Quy trình phát triển](process/General_Software_Development_Workflow.md)
- [Walkthrough](process/Walkthrough.md): luồng tái hiện, kết quả mong đợi và bằng
  chứng xác nhận cho lỗi đang được xử lý.
- [Nhật ký thay đổi](process/Development_Change_Log.md)

## Quy tắc đường dẫn

- Tài liệu mới phải đặt vào nhóm phù hợp, không đặt trực tiếp ở `docs/` nếu đã
  có nhóm chức năng tương ứng.
- Khi di chuyển tài liệu phải cập nhật toàn bộ Markdown link trong cùng thay đổi.
- Historical path trong change log được giữ nguyên nếu nó mô tả đúng vị trí ở
  thời điểm thay đổi.
