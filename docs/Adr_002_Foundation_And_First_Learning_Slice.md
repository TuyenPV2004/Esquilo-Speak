# ADR-002 — Foundation và vertical slice học tập đầu tiên

> Trạng thái: **Accepted**  
> Ngày quyết định: **2026-07-28**  
> Phạm vi: Mobile learner application, core backend, persistence và local development

## Bối cảnh

Repository đã có baseline REST/OpenAPI và JSON Schema tại `contracts/`, nhưng
chưa có application có thể build, test hoặc chạy. Vertical slice đầu tiên cần
đi xuyên qua mobile, API và PostgreSQL cho luồng catalog, lesson,
multiple-choice attempt, immediate feedback và course progress.

## Quyết định

1. Mobile sử dụng Flutter `3.44.3` và Dart `3.12.2`, tổ chức theo
   View–ViewModel–Repository–Service. Android là platform build, test và phát
   hành được ưu tiên trong roadmap hiện tại. Flutter shared code và iOS skeleton
   được giữ để tránh tự đóng đường phát triển về sau, nhưng chưa thực hiện công
   việc native iOS cho đến khi có quyết định ưu tiên mới.
2. Core backend sử dụng Java `21`, Spring Boot `4.1.0`, Spring Modulith `2.1.0`
   và Gradle Wrapper `9.6.1`.
3. Backend là modular monolith. Slice đầu tiên có hai module nghiệp vụ:
   `curriculumcontent` và `learning`.
4. PostgreSQL `18` là transactional source of truth; Flyway quản lý migration.
5. Attempt là append-only, deduplicate theo cả `Idempotency-Key` và
   `clientAttemptId`; reuse khác payload trả conflict.
6. Progress chỉ ghi nhận exercise hoàn thành khi đã có ít nhất một attempt
   đúng. Sai đáp án vẫn được lưu để giữ lịch sử học tập.
7. Authoring lesson có đáp án, nhưng learner delivery schema không trả
   `correctOptionId` hoặc `explanation`. Hai trường chỉ xuất hiện sau khi submit
   attempt.
8. Profile `local` sinh RSA key tạm thời trong bộ nhớ và cấp guest token qua
   endpoint development. Profile `production` bắt buộc sử dụng external OIDC
   issuer; không lưu signing key hoặc production secret trong repository.
9. Không sử dụng Dependabot version-update bot. Dependency update được thực
   hiện có chủ đích qua review; Dependabot Alerts trên GitHub có thể tiếp tục
   hoạt động độc lập.

## Hệ quả

### Tích cực

- Developer có thể chạy một user journey hoàn chỉnh trên local.
- Mobile và backend cùng bị ràng buộc bởi contract và automated tests.
- Spring Modulith verification bảo vệ dependency boundary từ đầu.
- PostgreSQL Testcontainers kiểm tra migration và SQL trên đúng database engine.
- Client không thể đọc đáp án từ lesson response trước khi làm bài.

### Chi phí và giới hạn

- Docker phải chạy khi thực hiện backend integration test.
- Native iOS build, test và release chủ động nằm ngoài roadmap hiện tại để tập
  trung nguồn lực cho Android; đây không phải lỗi Android SDK hoặc blocker của
  Foundation Sprint.
- Local guest token chỉ phục vụ development, không thay thế identity contract.
- Offline persistence/sync chưa nằm trong slice này và vẫn là quyết định cần
  triển khai ở slice tiếp theo.
- Khi bỏ bot update tự động, team phải chủ động review dependency và cảnh báo
  bảo mật.

## Nguồn tham khảo

- [Flutter app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter testing](https://docs.flutter.dev/testing/overview)
- [Spring Boot system requirements](https://docs.spring.io/spring-boot/system-requirements.html)
- [Spring Modulith fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html)
- [Spring Modulith verification](https://docs.spring.io/spring-modulith/reference/verification.html)
- [Gradle Wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html)
- [PostgreSQL documentation](https://www.postgresql.org/docs/current/)
- [Flyway documentation](https://documentation.red-gate.com/flyway)
- [OAuth 2.0 resource server JWT](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
