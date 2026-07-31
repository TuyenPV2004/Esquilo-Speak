# Quy trình phát triển phần mềm dùng chung cho nhiều dự án

> Loại tài liệu: Quy trình tham khảo và checklist  
> Phạm vi: Dự án web, mobile, backend, desktop, data hoặc hệ thống tích hợp  
> Cách dùng: Sao chép sang dự án mới, thay các mục `<...>` và bỏ những bước không áp dụng  
> Nguyên tắc: Điều chỉnh theo rủi ro và quy mô; không tạo công nghệ hoặc hạ tầng khi chưa có nhu cầu thật

## 1. Mục tiêu

Quy trình giúp dự án đi từ ý tưởng đến phần mềm có thể vận hành theo các giai đoạn có đầu ra và điều kiện hoàn thành rõ ràng:

```text
Discovery
  → Product definition
  → Technical decisions
  → Foundation Sprint
  → Vertical slices
  → Release readiness
  → Deployment
  → Operation and improvement
```

Khi có bằng chứng mới, backlog, yêu cầu và quyết định kỹ thuật phải được cập nhật có kiểm soát.

## 2. Nguyên tắc xuyên suốt

- Xây theo vertical slice có giá trị, không hoàn thiện từng tầng kỹ thuật cô lập trong thời gian dài.
- Chọn giải pháp đơn giản nhất đáp ứng yêu cầu hiện tại và có đường tiến hóa hợp lý.
- Quyết định quan trọng phải có bối cảnh, lựa chọn thay thế, hệ quả và điều kiện xem xét lại.
- Security, privacy, accessibility, testability và operations là yêu cầu từ đầu.
- Contract, migration và public API phải được review như code.
- Mỗi thay đổi phải có tiêu chí chấp nhận và bằng chứng kiểm thử tương ứng.
- Không đưa secret, token, dữ liệu thật hoặc thông tin cá nhân vào repository.

## 3. Giai đoạn 0 — Discovery và xác định mục tiêu

### 3.1 Câu hỏi phải trả lời

- Vấn đề nào đang được giải quyết?
- Ai là người dùng hoặc bên liên quan chính?
- Pain point và hành vi hiện tại là gì?
- Giá trị mong muốn là gì?
- Điều gì nằm ngoài phạm vi?
- Thành công được đo bằng chỉ số nào?
- Ràng buộc thời gian, ngân sách, pháp lý, dữ liệu và nền tảng là gì?
- Giả định và rủi ro nào chưa được kiểm chứng?

### 3.2 Đầu ra tối thiểu

- Product vision hoặc problem statement.
- Nhóm người dùng và job-to-be-done chính.
- Mục tiêu, non-goal và success metrics.
- Danh sách giả định, dependency và rủi ro.
- Phạm vi release đầu tiên ở mức outcome.

### 3.3 Điều kiện hoàn thành

- Có thể giải thích dự án trong một đoạn ngắn mà không nhắc trước tiên đến framework.
- Có ít nhất một chỉ số xác nhận sản phẩm tạo ra giá trị.
- Các bên liên quan đồng ý về mục tiêu và phạm vi đầu tiên.

## 4. Giai đoạn 1 — Yêu cầu và kế hoạch sản phẩm

### 4.1 Xây dựng yêu cầu

- Functional requirements và user journey.
- Non-functional requirements: security, privacy, performance, reliability, accessibility, localization và compliance.
- Data classification, retention và consent.
- Acceptance criteria có thể kiểm chứng.
- Error, empty, loading, retry, offline và permission states khi áp dụng.

### 4.2 Xây dựng backlog

- Nhóm yêu cầu thành capability, epic và vertical slice.
- Sắp xếp theo giá trị, rủi ro và dependency.
- Chọn vertical slice đầu tiên chạy được từ consumer đến dữ liệu.
- Định nghĩa Definition of Ready và Definition of Done.

### 4.3 Đầu ra tối thiểu

- Product backlog được ưu tiên.
- User journey hoặc sequence chính.
- Acceptance criteria cho slice đầu tiên.
- Release goal và milestone gần nhất.

## 5. Giai đoạn 2 — Lựa chọn kỹ thuật và kiến trúc

### 5.1 Tiêu chí lựa chọn công nghệ

- Phù hợp yêu cầu và workload.
- Năng lực đội ngũ và khả năng tuyển dụng.
- Mức trưởng thành, tài liệu và hệ sinh thái.
- Security support và vòng đời cập nhật.
- Chi phí phát triển, vận hành và migration.
- Khả năng test, quan sát và triển khai.
- Ràng buộc platform, hosting và licensing.

Không chọn framework, database, cloud hoặc kiến trúc chỉ vì đã dùng ở dự án trước.

### 5.2 Quyết định cần ghi nhận

- Application type và runtime chính.
- Database, storage và ownership dữ liệu.
- Kiểu API, contract và integration.
- Authentication, authorization và trust boundary.
- Deployment topology và environment.
- Offline/sync, concurrency và idempotency nếu áp dụng.
- Observability và error handling.
- Các lựa chọn bị loại và điều kiện xem xét lại.

Quyết định dài hạn nên được ghi bằng Architecture Decision Record.

### 5.3 Điều kiện hoàn thành

- Kiến trúc hỗ trợ vertical slice đầu tiên mà không dự liệu quá mức.
- Boundary, data flow và owner của thành phần chính đã rõ.
- Quyết định có chi phí thay đổi cao đã được ghi nhận.

## 6. Giai đoạn 3 — Foundation Sprint

Foundation Sprint tạo nền móng có thể build, test và cộng tác; không xây toàn bộ infrastructure tương lai.

### 6.1 Repository và Git

- [ ] Khởi tạo repository và file ignore phù hợp.
- [ ] Chọn monorepo hoặc multi-repo dựa trên ownership và release boundary.
- [ ] Tạo cấu trúc thư mục baseline có owner rõ.
- [ ] Viết `README` với prerequisites, setup, build và test.
- [ ] Chọn chiến lược nhánh, tên branch và commit.
- [ ] Tạo Pull Request/issue template khi cần.
- [ ] Bảo vệ nhánh production bằng PR, review và status checks.
- [ ] Xác định versioning và release/tag convention.

### 6.2 Toolchain và phiên bản

- [ ] Ghi rõ phiên bản SDK, runtime, compiler và build tool.
- [ ] Chọn package manager theo ecosystem.
- [ ] Commit lockfile khi application ecosystem sử dụng lockfile.
- [ ] Thiết lập formatter, linter, type checker và editor settings.
- [ ] Có cách nâng cấp dependency và ghi nhận breaking change.
- [ ] Bảo đảm local và CI dùng runtime tương thích.

Ví dụ nơi khai báo phiên bản: `.tool-versions`, `.nvmrc`, `global.json`, Gradle toolchain, `pyproject.toml` hoặc `rust-toolchain.toml`.

### 6.3 Cấu hình và môi trường

- [ ] Tách configuration khỏi code khi phù hợp.
- [ ] Cung cấp file mẫu chỉ có giá trị không nhạy cảm.
- [ ] Không commit `.env`, token, private key, cookie hoặc production data.
- [ ] Xác định local, test, staging và production configuration.
- [ ] Có lệnh setup local lặp lại được.
- [ ] Có health/readiness check cho service khi áp dụng.

### 6.4 Application skeleton

- [ ] Bootstrap từng deployable unit thực sự cần.
- [ ] Thiết lập dependency direction và module boundary.
- [ ] Có error model và logging baseline.
- [ ] Có database connection và migration đầu tiên nếu cần.
- [ ] Có sample/seed data không chứa dữ liệu thật.
- [ ] Không tạo module hoặc service chỉ để dự liệu tương lai.

### 6.5 Contract và dữ liệu

- [ ] Định nghĩa domain glossary và identifier ổn định.
- [ ] Tạo API contract hoặc message schema trước khi consumer phát triển độc lập.
- [ ] Xác định compatibility và deprecation policy.
- [ ] Xác định migration, rollback, concurrency và idempotency.
- [ ] Tạo schema validation và contract test trong CI.

### 6.6 Test và quality gate

- [ ] Thiết lập test runner và cấu trúc test.
- [ ] Có smoke test chứng minh application khởi động.
- [ ] Có unit test cho business rule đầu tiên.
- [ ] Có integration test cho database/API khi cần.
- [ ] Xác định quality gate bắt buộc trước merge.
- [ ] Không làm yếu test cũ chỉ để thay đổi mới pass.

### 6.7 CI/CD baseline

- [ ] CI chạy khi push branch công việc và khi mở Pull Request.
- [ ] CI chạy build, lint, typecheck, test và contract validation.
- [ ] Bật dependency/security scanning theo mức rủi ro.
- [ ] Artifact có version và truy vết được về commit.
- [ ] Deployment lặp lại được và có rollback.
- [ ] Secret CI/CD nằm trong secret store của nền tảng.

### 6.8 Security, privacy và supply chain

- [ ] Xác định trust boundary và data flow chính.
- [ ] Threat model auth, dữ liệu nhạy cảm và integration quan trọng.
- [ ] Áp dụng least privilege cho developer, CI và runtime.
- [ ] Có dependency inventory và quy trình xử lý vulnerability.
- [ ] Xác định logging redaction, retention và incident contact.
- [ ] Kiểm tra license dependency và asset khi cần.

### 6.9 Tài liệu vận hành tối thiểu

- [ ] Hướng dẫn setup, build, test và troubleshooting.
- [ ] Sơ đồ kiến trúc/data flow ở mức cần thiết.
- [ ] ADR cho quyết định dài hạn.
- [ ] Owner và lịch review cho tài liệu quan trọng.
- [ ] Không lặp một quyết định ở nhiều source of truth.

### 6.10 Definition of Done của Foundation Sprint

Foundation hoàn thành khi developer mới có thể:

1. Clone repository.
2. Cài đúng toolchain theo tài liệu.
3. Khởi động application nền tảng.
4. Chạy formatter, lint, typecheck và test.
5. Tạo thay đổi nhỏ qua branch và Pull Request.
6. Nhận kết quả CI đáng tin cậy.
7. Không cần secret production hoặc thao tác không được ghi lại.

## 7. Giai đoạn 4 — Phát triển theo vertical slice

```text
Outcome và acceptance criteria
  → Contract/data change
  → Implementation
  → Automated tests
  → Review và CI
  → Staging/smoke test
  → Release
  → Telemetry và feedback
```

### Checklist cho mỗi slice

- [ ] Mục tiêu người dùng và non-goal rõ ràng.
- [ ] Phân tích ảnh hưởng tới module, API, dữ liệu và consumer.
- [ ] Contract/schema cập nhật trước hoặc cùng implementation.
- [ ] Happy path, error path và edge case có test.
- [ ] Test cũ liên quan được chạy lại.
- [ ] Security, privacy, accessibility và localization được xem xét.
- [ ] Migration tương thích và có rollback khi cần.
- [ ] Telemetry đo outcome nhưng không thu thập dữ liệu thừa.
- [ ] Tài liệu và changelog được cập nhật.

## 8. Giai đoạn 5 — Release readiness

- [ ] Acceptance criteria được xác minh.
- [ ] Unit, integration, contract và end-to-end test liên quan pass.
- [ ] Performance/reliability/security test chạy theo rủi ro.
- [ ] Migration và rollback được kiểm tra.
- [ ] Configuration và secret của environment sẵn sàng.
- [ ] Observability có log, metric, trace hoặc alert cần thiết.
- [ ] Runbook, support owner và incident path đã rõ.
- [ ] Artifact có version và liên kết tới commit.

## 9. Giai đoạn 6 — Deployment và xác minh sau phát hành

- Deploy từ artifact đã qua test, không rebuild khác biệt tại production.
- Dùng staged rollout, canary hoặc feature flag khi rủi ro yêu cầu.
- Chạy smoke test sau deploy.
- Theo dõi error rate, latency, user journey và business metric.
- Rollback hoặc tắt feature nếu vượt ngưỡng an toàn.

## 10. Giai đoạn 7 — Vận hành và cải tiến

- Theo dõi SLO/SLI dựa trên user journey thực tế.
- Triage bug, vulnerability, dependency update và technical debt.
- Kiểm tra backup/restore theo lịch.
- Review access, secret, retention và threat model định kỳ.
- Dùng telemetry và feedback để cập nhật backlog.
- Viết post-incident review và hành động phòng ngừa.
- Loại bỏ feature flag, code path và infrastructure không còn dùng.

## 11. Khi nào cần xem lại quyết định nền tảng?

- Workload thực tế vượt giả định ban đầu.
- Ownership hoặc release cadence thay đổi.
- Security/compliance yêu cầu isolation mới.
- Chi phí vận hành hoặc developer experience không còn chấp nhận được.
- Công nghệ hết support hoặc dependency có rủi ro nghiêm trọng.
- Dữ liệu chứng minh kiến trúc hiện tại là bottleneck.

Không đổi kiến trúc lớn chỉ vì có công nghệ mới hoặc dự đoán scale chưa có bằng chứng.

## 12. Mẫu tóm tắt khởi động một project

```text
Tên project: <name>
Vấn đề: <problem>
Người dùng chính: <users>
Outcome đầu tiên: <outcome>
Success metric: <metric>
Non-goal: <non-goals>
Vertical slice đầu tiên: <end-to-end slice>
Runtime/SDK: <name and pinned version>
Application/deployable units: <units>
Database/storage: <choice and reason>
API/contract: <style and location>
Repository strategy: <mono or multi repo>
Git workflow: <branches and protection>
Quality gates: <build/lint/typecheck/tests/security>
Environments: <local/test/staging/production>
Main risks: <risks>
Decisions still open: <questions>
```

## 13. Nguồn tham khảo

- [NIST SP 800-218 — Secure Software Development Framework](https://csrc.nist.gov/pubs/sp/800/218/final).
- [GitHub — Continuous integration](https://docs.github.com/en/actions/get-started/continuous-integration).
- [GitHub — Protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches).
- [OpenAPI Specification 3.1.1](https://spec.openapis.org/oas/v3.1.1.html).
- [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12).
- [Semantic Versioning](https://semver.org/).
- [The Twelve-Factor App — Config](https://12factor.net/config).
- [Architecture Decision Record — Martin Fowler](https://martinfowler.com/bliki/ArchitectureDecisionRecord.html).
