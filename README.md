<p align="center">
  <img src="assets/brand/app-icon/app-icon-1024.png" width="180" alt="EsquiloSpeak app icon">
</p>

<h1 align="center">EsquiloSpeak</h1>

<p align="center">
  <strong>Tích lũy từng từ, nói được từng ngày.</strong><br>
  Nền tảng học ngoại ngữ đa ngôn ngữ, giúp người học ghi nhớ lâu hơn và giao tiếp tự tin hơn.
</p>

## Giới thiệu

EsquiloSpeak là ứng dụng học ngoại ngữ kết hợp bài học ngắn, luyện tập chủ động, ôn tập ngắt quãng, luyện nghe–nói và phản hồi cá nhân hóa. Thay vì chỉ hoàn thành bài học, người dùng được hướng dẫn học đúng nội dung, ôn lại vào thời điểm phù hợp và từng bước chuyển kiến thức thành khả năng giao tiếp thực tế.

Sản phẩm được thiết kế để phù hợp với nhiều trình độ, mục tiêu và hoàn cảnh học tập. Người học có thể học trong vài phút mỗi ngày, luyện tập khi đang di chuyển, sử dụng chế độ không âm thanh hoặc tiếp tục học khi kết nối mạng không ổn định.

## EsquiloSpeak giúp người học

- Học theo lộ trình phù hợp với mục tiêu và trình độ cá nhân.
- Ghi nhớ từ vựng và kiến thức lâu hơn bằng active recall và spaced repetition.
- Luyện nghe, phát âm, phản xạ và hội thoại trong ngữ cảnh thực tế.
- Nhận phản hồi rõ ràng để hiểu lỗi sai và biết cách cải thiện.
- Theo dõi tiến bộ và luôn biết hoạt động nên học hoặc ôn tiếp theo.
- Duy trì thói quen học tập nhẹ nhàng, không tạo cảm giác áp lực.

## Dành cho ai?

EsquiloSpeak hướng tới người mới bắt đầu, người học lại từ đầu, học sinh, sinh viên và người đi làm muốn cải thiện ngoại ngữ cho giao tiếp, học tập, công việc hoặc các mục tiêu chuyên sâu.

## Câu chuyện thương hiệu

**Esquilo** có nghĩa là “con sóc” trong tiếng Bồ Đào Nha, tượng trưng cho khả năng tích lũy và ghi nhớ. **Speak** thể hiện mục tiêu cuối cùng của việc học ngôn ngữ: có thể nói, hiểu và giao tiếp tự tin.

Hình ảnh chú sóc đang đọc sách đại diện cho hành trình tích lũy từng đơn vị kiến thức nhỏ để xây dựng năng lực ngôn ngữ bền vững.

## Trạng thái triển khai

Repository đã có Foundation Sprint chạy được cho vertical slice học tập đầu tiên:

```text
Danh mục ngôn ngữ/khóa học
→ Danh sách bài học
→ Bài tập trắc nghiệm
→ Gửi attempt có idempotency
→ Nhận phản hồi tức thì
→ Xem tiến độ khóa học
```

Backend cũng đã có content publishing P0:

```text
Draft course version
→ Review
→ Approve
→ Schedule/publish
→ Learner-safe delivery
→ Retire hoặc rollback
```

- Mobile: Flutter `3.44.3`, Dart `3.12.2`, Android/iOS.
- Backend: Java `21`, Spring Boot `4.1.0`, Spring Modulith `2.1.0`.
- Build backend: Gradle Wrapper `9.6.1`.
- Data: PostgreSQL `18`, Flyway migration và seed content.
- Contract: OpenAPI `3.1.1` và JSON Schema `2020-12`.

## Cấu trúc có thể chạy

```text
apps/mobile/                         Flutter learner application
backend/core-platform/               Spring Boot modular monolith
contracts/openapi/                   Mobile API contract
contracts/schema/                    Authoring và learner delivery schemas
infrastructure/local/compose/        PostgreSQL local
```

## Quyết định và release gate

- ADR đã được chấp nhận nằm trong [`docs/decisions/`](docs/decisions/).
- P0 decision/delivery gate nằm tại
  [`docs/roadmap/P0_GATE.md`](docs/roadmap/P0_GATE.md).
- Test và evidence của Android end-to-end nằm trong
  [`tests/end-to-end/`](tests/end-to-end/).

## Prerequisites

- JDK 21.
- Flutter 3.44.3 với Dart 3.12.2.
- Android SDK cho Android development.
- Docker Desktop hoặc Docker Engine hỗ trợ Compose.

## Chạy local

Sao chép `.env.example` thành `.env`, thay hai giá trị password local và chạy
PostgreSQL:

```powershell
docker compose --env-file .env -f infrastructure/local/compose/compose.yml up -d
```

Chạy backend bằng profile `local`:

```powershell
cd backend/core-platform
.\gradlew.bat bootRun
```

Profile local sinh khóa JWT tạm thời trong bộ nhớ và cung cấp
`POST /internal/dev/token` để ứng dụng mobile chạy vertical slice. Endpoint này
không tồn tại trong profile `production`. Mỗi lần gọi endpoint tạo một guest
identity mới; ứng dụng phải giữ access token trong vòng đời guest session nếu
muốn tiếp tục cùng tiến độ.

Chạy Flutter trên Android emulator:

```powershell
cd apps/mobile
flutter pub get
flutter run
```

Android emulator dùng API mặc định `http://10.0.2.2:8080`. Có thể đổi endpoint:

```powershell
flutter run --dart-define=ESQUILO_API_URL=https://api.example.com
```

## Kiểm thử

Backend:

```powershell
cd backend/core-platform
.\gradlew.bat test
```

Lệnh này chạy kiểm tra boundary Spring Modulith và integration test với
PostgreSQL Testcontainers, do đó Docker phải đang hoạt động.

Mobile:

```powershell
cd apps/mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Contract:

```powershell
npx --yes @redocly/cli@2.39.0 lint contracts/openapi/esquilospeak-learning-v1.yaml --extends=spec
```

## Content publishing

Admin content API nằm dưới `/api/admin/v1/content` và yêu cầu
`SCOPE_content` cùng `ROLE_CONTENT_STAFF` hoặc `ROLE_ADMIN`. API quản lý course
version bất biến, unit/lesson/exercise, lifecycle, effective date, audit và
rollback.

Authoring payload chứa scoring data; learner API chỉ đọc `learner_content` đã
loại `correctOptionId`, `correctAnswer` và `explanation`. P0 hỗ trợ
`multiple_choice` và `true_false`.

Media hiện chỉ có metadata (`objectKey`, checksum, locale, duration/alt text).
Repository chưa thêm object storage; binary storage chỉ được triển khai khi có
audio hoặc image production thật.

## Learning, mastery, review và offline sync

- `POST /api/mobile/v1/learning-sessions` tạo session theo course content
  version; endpoint completion đóng session theo cách idempotent.
- `POST /api/mobile/v1/attempts` vẫn là API attempt đơn append-only và trả
  scoring/feedback/progress canonical.
- `GET /api/mobile/v1/mastery` trả mastery model version 1 cùng evidence count
  có thể giải thích; `GET /api/mobile/v1/reviews` chỉ trả item đã due theo server
  clock.
- `POST /api/mobile/v1/sync/push` nhận tối đa 100 `attempt.submit` mutation.
  `clientMutationId` và `idempotencyKey` phải được lưu trong local outbox và giữ
  nguyên khi retry.
- `GET /api/mobile/v1/sync/pull` phân trang change log bằng cursor opaque.
  Client chỉ ghi cursor mới sau khi áp dụng thành công toàn bộ page; operation
  `delete` là tombstone, không được bỏ qua.

Chi tiết completion, conflict, mastery và review rule nằm trong
[`ADR-005`](docs/decisions/ADR-005-learning-mastery-review-offline-sync.md).

## Cấu hình production

- Kích hoạt Spring profile `production`.
- Cung cấp `ESQUILO_DB_URL`, `ESQUILO_DB_USERNAME`,
  `ESQUILO_DB_PASSWORD`, `ESQUILO_JWT_ISSUER_URI` và
  `ESQUILO_JWT_AUDIENCE` từ secret store.
- External OIDC provider phải phát JWT có `iss`, `sub`, audience khớp cấu hình,
  `actor_type` là `guest` hoặc `account`, scope `learning`, và role thuộc
  `learner`, `content_staff`, `support`, `admin`. Mobile API hiện yêu cầu
  `SCOPE_learning` cùng `ROLE_LEARNER`; role không thuộc allow-list bị bỏ qua.
- Account learner phải hoàn tất age band trước khi đồng bộ tiến độ. P0 từ chối
  account dưới 16 tuổi cho đến khi có guardian-consent flow được phê duyệt.
- Không sử dụng local token endpoint hoặc password trong `.env.example` cho
  production.

External account registration, login, password/MFA và account recovery thuộc
OIDC provider. Backend chỉ lưu SHA-256 mapping của `issuer + subject`, không lưu
raw subject.
