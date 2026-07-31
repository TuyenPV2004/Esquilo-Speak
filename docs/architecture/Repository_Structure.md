# EsquiloSpeak — Cấu trúc repository và thư mục

> Trạng thái: **Cấu trúc baseline để bắt đầu phát triển; mở rộng theo nhu cầu thực tế**  
> Cập nhật lần cuối: **2026-07-15**  
> Phạm vi: **Monorepo, vị trí source code, module boundary và nguyên tắc mở rộng**

## 1. Mục đích

Tài liệu này xác định cấu trúc repository đủ rõ để bắt đầu phát triển EsquiloSpeak mà không scaffold trước mọi capability tương lai.

Chiến lược được sử dụng là **baseline-first / incremental scaffolding**:

- Phạm vi sản phẩm vẫn là nền tảng hoàn chỉnh, không bị giới hạn thành MVP.
- Chỉ tạo vật lý những thư mục cần cho giai đoạn bắt đầu.
- Thư mục feature, module, service, worker hoặc hạ tầng mới chỉ được tạo khi có code, cấu hình hoặc owner thực tế.
- Kiến trúc dài hạn vẫn nằm trong [Tech_Stack_And_Architecture.md](Tech_Stack_And_Architecture.md), không cần biểu diễn toàn bộ bằng thư mục rỗng.

## 2. Cấu trúc baseline hiện tại

```text
EsquiloSpeak/
├── .agent/                              # Rule và skill riêng của workspace
├── .github/                             # CI/workflow khi được bổ sung
├── apps/
│   ├── mobile/                          # Flutter learner application
│   │   ├── android/
│   │   ├── ios/
│   │   ├── lib/
│   │   │   ├── app/                    # Bootstrap, routing và app configuration
│   │   │   ├── core/                   # Technical capability dùng xuyên feature
│   │   │   ├── features/               # Chỉ thêm feature con khi bắt đầu làm
│   │   │   └── l10n/                   # ARB và Flutter localization output
│   │   ├── test/
│   │   └── integration_test/
│   └── admin-web/                       # Next.js content/operations application
│       ├── public/
│       ├── src/
│       │   ├── app/                    # App Router; chưa tạo Route Group rỗng
│       │   ├── features/               # Chỉ thêm feature con khi bắt đầu làm
│       │   ├── components/             # Component thực sự dùng qua nhiều feature
│       │   └── lib/                    # Technical helper có owner rõ
│       └── tests/
├── backend/
│   └── core-platform/                   # Spring Boot Modular Monolith
│       └── src/
│           ├── main/
│           │   ├── java/com/esquilospeak/
│           │   └── resources/
│           └── test/
│               ├── java/com/esquilospeak/
│               └── resources/
├── contracts/
│   ├── openapi/                         # Mobile/admin REST contract
│   └── schema/                          # Course/lesson/exercise schema
├── content/
│   ├── courses/                         # Course source có version
│   └── locales/                         # Content/localization metadata
├── infrastructure/
│   └── local/
│       └── compose/                     # PostgreSQL/dependency local khi bắt đầu dùng
├── tests/
│   ├── contract/                        # Validation contract xuyên component
│   └── end-to-end/                      # User journey xuyên application
├── tools/                               # Chỉ thêm script/generator có consumer thật
├── docs/                                # Markdown và tài nguyên tài liệu
└── README.md
```

Đây là **cấu trúc để bắt đầu**, không phải danh sách toàn bộ capability của sản phẩm.

## 3. Ý nghĩa thư mục cấp cao

| Thư mục | Ý nghĩa |
| --- | --- |
| `apps/` | Ứng dụng người dùng hoặc nhân sự vận hành tương tác trực tiếp |
| `backend/` | Workload phía máy chủ; ban đầu chỉ có `core-platform/` |
| `contracts/` | Contract nguồn giữa client, backend và content tooling |
| `content/` | Nội dung học tập có thể version và review |
| `infrastructure/` | Cấu hình môi trường thực sự được sử dụng |
| `tests/` | Kiểm thử cần nhiều application hoặc public contract |
| `tools/` | Script/generator/validator có consumer rõ |
| `docs/` | Tài liệu sản phẩm, kiến trúc, cấu trúc và ADR |

Không tạo `packages/`, `data-platform/`, specialized service hoặc worker chỉ để dự liệu tương lai.

## 4. Mobile application

Baseline chỉ giữ bốn khu vực trong `lib/`:

```text
lib/
├── app/
├── core/
├── features/
└── l10n/
```

Khi bắt đầu một feature, tạo cấu trúc vừa đủ bên trong feature đó. Ví dụ:

```text
features/learning/
├── data/
├── presentation/
└── domain/                 # Chỉ thêm khi có business logic đáng kể
```

Không tạo trước `auth/`, `home/`, `speech/`, `subscription/`, `design_system/`, `generated/` hoặc toàn bộ các tầng con khi chưa có code.

`lib/l10n/` là vị trí mặc định cho ARB theo Flutter. Nguồn: [Flutter Internationalization](https://docs.flutter.dev/ui/internationalization). Hướng tổ chức View/ViewModel và Repository tham khảo [Flutter App Architecture](https://docs.flutter.dev/app-architecture/guide).

## 5. Admin web và dấu ngoặc trong tên thư mục

Next.js App Router hỗ trợ **Route Groups** bằng cách đặt tên thư mục trong dấu ngoặc:

```text
app/
└── (auth)/
    └── login/
        └── page.tsx
```

`(auth)` chỉ dùng để tổ chức route hoặc chia sẻ layout và không xuất hiện trong URL; ví dụ trên vẫn tạo URL `/login`. Nguồn: [Next.js Route Groups](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups).

Route Group là công cụ hợp lệ nhưng không bắt buộc. Baseline hiện tại chỉ giữ:

```text
src/
├── app/
├── features/
├── components/
└── lib/
```

Chỉ thêm `(auth)`, `(content)` hoặc group khác khi đã có route/layout thực sự cần nhóm. Chỉ thêm `server/`, `design-system/` hoặc `generated/` khi có code tương ứng.

Tham khảo thêm: [Next.js Project Structure](https://nextjs.org/docs/app/getting-started/project-structure).

## 6. Core backend — Modular Monolith

Baseline chỉ scaffold Java source set chuẩn:

```text
backend/core-platform/src/
├── main/
│   ├── java/com/esquilospeak/
│   └── resources/
└── test/
    ├── java/com/esquilospeak/
    └── resources/
```

Khi bắt đầu một business capability, tạo module trực tiếp dưới `com.esquilospeak`. Ví dụ khi bắt đầu learning flow:

```text
com/esquilospeak/
├── curriculumcontent/
├── learningsession/
└── assessment/
```

Không tạo sẵn toàn bộ `identityprofile`, `mastery`, `reviewscheduler`, `gamification`, `commerceentitlement`, `notification`, `adminaudit` hoặc `aigateway` khi chưa có implementation.

Mỗi direct sub-package có thể trở thành application module. Public API và internal implementation được mở rộng bên trong module khi complexity xuất hiện. Nguồn: [Spring Modulith Fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html), [Spring Modulith Verification](https://docs.spring.io/spring-modulith/reference/verification.html).

## 7. Generated code

`contracts/` chỉ chứa contract nguồn. Khi bắt đầu code generation:

```text
apps/mobile/lib/generated/               # Dart client
apps/admin-web/src/generated/            # TypeScript client
```

Hai thư mục trên chưa cần tạo khi chưa có generator hoặc generated output. Không tạo `contracts/generated/`.

## 8. Những thư mục chỉ thêm về sau

| Thư mục | Khi nào tạo |
| --- | --- |
| `apps/mobile/lib/design_system/` | Có token/component thực sự dùng qua nhiều feature |
| `apps/*/generated/` | Đã chọn generator và có generated output |
| `apps/admin-web/src/app/(group)/` | Có nhiều route cần chia sẻ layout hoặc nhóm logic |
| `backend/core-platform/.../<module>/` | Bắt đầu implementation capability tương ứng |
| `contracts/events/` | Có event contract đi ra ngoài backend process |
| `packages/design-tokens/` | Mobile và web cùng tiêu thụ token nguồn ổn định |
| `backend/specialized-services/` | Có workload cần runtime, scale hoặc failure isolation riêng |
| `backend/workers/` | Background workload cần queue/retry/scale độc lập |
| `data-platform/` | Có ingestion, warehouse, transformation và owner thật |
| `infrastructure/observability/` | Có telemetry pipeline, dashboard hoặc alert được vận hành |
| `infrastructure/kubernetes/` | Kubernetes được ADR chấp nhận |
| `infrastructure/gitops/` | Có cluster, controller và deployment workflow thực tế |
| `tests/performance/` | Có workload model, threshold, environment và runner |
| `tests/resilience/` | Có fault model và recovery objective |
| `tests/security/` | Có suite bảo mật xuyên hệ thống và CI job rõ |

Các workload tương lai vẫn dùng tên đã thống nhất khi điều kiện tách xuất hiện:

- `ai-speech-processing`
- `realtime-conversation`
- `billing-integration`
- `notification-delivery`
- `billing-reconciliation`

Việc ghi tên tại đây không yêu cầu tạo thư mục vật lý ngay.

## 9. Dependency và ownership rule

- Mobile/admin chỉ gọi public backend API, không truy cập database trực tiếp.
- Module backend chỉ gọi public application API/named interface của module khác.
- Không chia sẻ JPA entity hoặc repository giữa module.
- Generated code phụ thuộc source contract và không được sửa thủ công.
- Worker/service tương lai không ghi trực tiếp database do deployable unit khác sở hữu.
- Không tạo `common`, `shared` hoặc `utils` như nơi chứa code chưa rõ owner.
- Unit/component test nằm gần component; root `tests/` chỉ dành cho kiểm thử xuyên hệ thống.

## 10. Quy tắc mở rộng cây thư mục

Trước khi tạo một thư mục mới, trả lời ba câu hỏi:

1. Thư mục này sẽ chứa file/code/configuration nào ngay trong thay đổi hiện tại?
2. Thành phần nào sở hữu và kiểm thử nội dung đó?
3. Vị trí hiện có có thật sự không phù hợp hay chỉ đang dự liệu tương lai?

Nếu chưa trả lời được, chưa tạo thư mục.

Một feature có test `1, 2, 3` và được bổ sung hành vi mới kèm test `4` thì phải chạy lại toàn bộ `1, 2, 3, 4`; việc thêm module/thư mục mới không làm mất phạm vi regression cũ.

## 11. Naming convention

- Repository directory: `kebab-case`.
- Java package: lowercase, không underscore.
- Dart file: `snake_case.dart`.
- Route Group Next.js: `(group-name)` và chỉ dùng khi có nhu cầu routing/layout thật.
- Event type: `PascalCase`, diễn đạt sự kiện đã xảy ra.
- ADR: `ADR-NNNN-short-title.md`.

## 12. Ưu và nhược điểm của baseline-first

### Ưu điểm

- Cây thư mục ngắn, dễ học và dễ tìm file.
- Mỗi thư mục xuất hiện cùng nhu cầu thực tế nên ownership rõ hơn.
- Không tạo cảm giác hệ thống đã dùng microservices, data platform hoặc Kubernetes.
- Vẫn giữ được Modular Monolith và khả năng tiến hóa dài hạn.

### Nhược điểm

- Cây thư mục sẽ thay đổi dần khi capability mới được triển khai.
- Developer phải đọc tài liệu kiến trúc để biết vị trí tương lai thay vì nhìn thấy mọi nhánh vật lý.
- Cần giữ kỷ luật để feature mới không bị đặt tùy tiện.

## 13. Decision log

| ID | Đề xuất | Trạng thái |
| --- | --- | --- |
| R-001 | Dùng monorepo | Proposed |
| R-002 | Dùng `backend/` làm namespace cho server workload | Proposed |
| R-003 | Baseline chỉ có `backend/core-platform/` | Proposed |
| R-004 | Chỉ scaffold thư mục có nhu cầu gần hoặc implementation thực tế | Proposed |
| R-005 | Không tạo trước Route Group, feature, module, service, worker hoặc advanced infrastructure | Proposed |
| R-006 | Generated client nằm tại consumer khi generation bắt đầu | Proposed |
| R-007 | Markdown nằm trực tiếp trong `docs/` | Proposed |

## 14. Nguồn tham khảo

- [Next.js Route Groups](https://nextjs.org/docs/app/api-reference/file-conventions/route-groups)
- [Next.js Project Structure](https://nextjs.org/docs/app/getting-started/project-structure)
- [Flutter App Architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter Internationalization](https://docs.flutter.dev/ui/internationalization)
- [Spring Modulith Fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html)
- [Spring Modulith Verification](https://docs.spring.io/spring-modulith/reference/verification.html)
- [Alistair Cockburn — Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture)

Tên thư mục cấp repository là quyết định thiết kế suy ra từ phạm vi EsquiloSpeak; framework không bắt buộc các tên này.

## 15. Changelog

| Ngày | Thay đổi |
| --- | --- |
| 2026-07-15 | Chuyển từ full target scaffold sang baseline-first; bỏ Route Group, feature/module, service/worker, data platform và advanced infrastructure rỗng; giữ roadmap mở rộng trong tài liệu. |
| 2026-07-15 | Chuẩn hóa `backend/`, `infrastructure/`, generated code và Flutter l10n. |
| 2026-07-14 | Tách cấu trúc repository thành tài liệu độc lập. |
