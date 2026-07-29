# Những điểm chưa phù hợp trong cấu trúc repository — Kết quả xử lý

> Trạng thái: **Đã rà soát và hợp nhất; scaffold vật lý đã được thu gọn theo baseline-first**  
> Cập nhật lần cuối: **2026-07-15**  
> Source of truth hiện tại: [Repository_Structure.md](Repository_Structure.md)

## 1. Mục đích

Tài liệu này lưu kết quả xử lý review cấu trúc repository. Nó không thay thế tài liệu cấu trúc chính và không được dùng làm source of truth cho layout mới.

## 2. Các quyết định sau review

| # | Vấn đề đã review | Quyết định xử lý |
| ---: | --- | --- |
| 1 | `services/`/`infra/` không thống nhất với `backend/`/`infrastructure/` | Chuẩn hóa toàn repository thành `backend/` và `infrastructure/` |
| 2 | Nhánh tương lai dễ bị hiểu là thành phần đang hoạt động | Chỉ ghi trong bảng điều kiện mở rộng; không tạo vật lý khi chưa có implementation |
| 3 | Generated code xuất hiện ở cả contract và consumer | `contracts/` chỉ giữ contract nguồn; Dart/TypeScript output nằm tại consumer |
| 4 | Flutter localization bị chia giữa `lib/app/` và root `l10n/` | Dùng `lib/l10n/` cho ARB/output, `lib/app/localization/` cho runtime wiring; bổ sung `main.dart`, `l10n.yaml`, `analysis_options.yaml` |
| 5 | `lint-config` bị hiểu là dùng chung Dart và TypeScript | Loại bỏ generic lint package; Flutter dùng `analysis_options.yaml`; chỉ tạo `eslint-config` khi có nhiều TS consumer |
| 6 | Test nâng cao được thể hiện cùng mức với baseline | Contract/E2E là baseline; performance/security là conditional; resilience là evolution |
| 7 | Service tương lai trùng tên module domain | Đổi thành `ai-speech-processing`, `realtime-conversation`, `billing-integration`, `notification-delivery` |
| 8 | Reconciliation worker có nguy cơ được tách quá sớm | Bắt đầu bằng scheduled job trong core module; chỉ tách `billing-reconciliation` khi có bằng chứng |
| 9 | `data-platform/schemas` mơ hồ với `contracts/` | Dùng `warehouse-models/`, `ingestion/`, `transformations/`, `data-quality/`, `dashboards/` |
| 10 | Observability bị xếp cùng mức trưởng thành với Kubernetes/GitOps | Đánh dấu `[CONDITIONAL — EARLY]`; Kubernetes/GitOps vẫn là `[EVOLUTION]` |
| 11 | Java source layout chưa đầy đủ | Bổ sung `src/main/resources`, `src/test/java` và `src/test/resources` |
| 12 | `interfaces/` dễ nhầm với Java interface | Đổi composition boundary thành `entrypoints/mobileapi` và `entrypoints/adminapi` |
| 13 | Full target scaffold tạo quá nhiều thư mục rỗng và khó đọc | Chuyển sang baseline-first; chỉ giữ khung mobile, admin, core backend, contract, content, local infrastructure và cross-system test |

## 3. Kết quả

- Tài liệu chi tiết đã được hợp nhất vào [Repository_Structure.md](Repository_Structure.md).
- Tên workload và mức trưởng thành đã được đồng bộ với [Tech_Stack_And_Architecture.md](Tech_Stack_And_Architecture.md).
- Cây thư mục vật lý và hình ảnh phải bám theo hai tài liệu trên.
- Phạm vi sản phẩm vẫn đầy đủ; “làm dần” chỉ là chiến lược scaffold và thứ tự triển khai, không phải giới hạn sản phẩm thành MVP.

## 4. Nguồn xác minh chính

- [Spring Modulith — Fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html)
- [Spring Modulith — Verification](https://docs.spring.io/spring-modulith/reference/verification.html)
- [Flutter — Internationalization](https://docs.flutter.dev/ui/internationalization)
- [OpenTelemetry — Observability primer](https://opentelemetry.io/docs/concepts/observability-primer/)

Tên thư mục cấp repository là quyết định thiết kế suy ra từ phạm vi EsquiloSpeak. Các nguồn trên được dùng để xác minh nguyên tắc module, localization và observability, không được hiểu là framework bắt buộc các tên thư mục này.
