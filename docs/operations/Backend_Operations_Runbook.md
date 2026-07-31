# Backend Operations Runbook

## Phạm vi

Runbook này áp dụng cho `core-platform` P0 trên PostgreSQL 18. Mục tiêu là giữ
learner API quan sát được, giới hạn lỗi dây chuyền, phục hồi được từ backup và
ưu tiên forward-fix migration. Đây chưa phải runbook cho Kubernetes hoặc hệ
thống nhiều instance.

## Health, readiness và graceful shutdown

| Endpoint | Ý nghĩa | Quyền truy cập |
| --- | --- | --- |
| `/livez` | JVM/application context còn sống; không phụ thuộc database | Công khai cho orchestrator |
| `/readyz` | Instance nhận traffic và PostgreSQL sẵn sàng | Công khai cho orchestrator |
| `/actuator/health/**` | Health group chi tiết | Công khai, không hiện chi tiết nhạy cảm |
| `/actuator/prometheus` | JVM, HTTP, datasource và custom operational metrics | `SCOPE_operations` + `ROLE_SUPPORT` hoặc `ROLE_ADMIN` |

Spring Boot nhận `SIGTERM`, chuyển readiness sang từ chối traffic, ngừng nhận
request mới và cho request đang chạy tối đa 20 giây để hoàn tất. Không dùng
`kill -9` trừ khi process không phản hồi sau thời gian grace và incident
commander đã ghi nhận nguy cơ request dở dang.

## Structured logging, metrics và traces

- Production console dùng ECS JSON.
- `correlationId` lấy từ `X-Correlation-ID` hợp lệ hoặc UUID do server sinh.
- OpenTelemetry `traceId`/`spanId` do tracing context quản lý; không ghi đè bằng
  correlation ID của client.
- Request completion log chỉ chứa method, route category/template, status,
  duration và correlation ID. Không log URL thực có object ID, query, body,
  Authorization header, raw OIDC subject, IP, profile hoặc voice.
- OTLP export mặc định tắt cho traces, metrics và logs. Chỉ bật
  `ESQUILO_OTEL_EXPORT_ENABLED=true` khi các endpoint
  `ESQUILO_OTEL_TRACES_ENDPOINT`, `ESQUILO_OTEL_METRICS_ENDPOINT` và
  `ESQUILO_OTEL_LOGS_ENDPOINT` thuộc collector đã được phê duyệt.
- Prometheus scrape interval đề xuất là 30 giây. Alert dùng metric tổng hợp,
  không thêm learner ID/client mutation ID làm label.

Operational audit lưu actor SHA-256, action, outcome, trace ID và metadata
allow-list. Security audit giữ tối đa 180 ngày. Content và identity audit vẫn do
module sở hữu dữ liệu tương ứng ghi trong cùng transaction nghiệp vụ.

## Timeout và retry budget

| Boundary | Timeout/budget P0 |
| --- | --- |
| HTTP connection vào Tomcat | 5 giây |
| Hikari lấy connection | 3 giây |
| Hikari validation | 2 giây |
| PostgreSQL connect | 3 giây |
| PostgreSQL socket/query | 10 giây |
| Graceful shutdown phase | 20 giây |
| OTLP export | Tắt mặc định; collector timeout do Spring cấu hình khi bật |

Client chỉ retry request khi response có `retryable=true`, hoặc khi mất kết nối
trước khi biết kết quả của mutation có stable `clientMutationId` và
`Idempotency-Key`. Budget mặc định: tối đa 2 retry, exponential backoff có
jitter (`250–500 ms`, sau đó `750–1500 ms`). Tôn trọng `Retry-After`; không
retry `400`, `401`, `403`, `404`, `409` hoặc `422` nếu payload/authority không
thay đổi.

## Rate limit P0

| Policy | Quota mặc định | Key |
| --- | --- | --- |
| Direct attempt | 60/phút | SHA-256 authenticated subject |
| Offline sync push | 30 batch/phút | SHA-256 authenticated subject |
| Privacy export/deletion | 5/giờ | SHA-256 authenticated subject |
| Content admin mutation | 60/phút | SHA-256 authenticated subject |

Response vượt quota là `429 RATE_LIMIT_EXCEEDED`, `retryable=true` và có
`Retry-After`. Limiter hiện nằm trong tiến trình và phù hợp baseline một
instance. Trước khi scale ngang phải chuyển enforcement lên API gateway hoặc
distributed limiter; không được giả định quota trên từng instance là quota toàn
hệ thống.

## Backup

Mục tiêu nội bộ P0:

- RPO không quá 24 giờ.
- RTO không quá 4 giờ.
- Backup rolling expiry không quá 90 ngày.
- Backup production phải mã hóa, kiểm soát truy cập và nằm khác failure domain
  với database chính.

Backup drill local:

```powershell
.\infrastructure\operations\Backup_Postgres.ps1 `
  -ContainerName <postgres-container> `
  -OutputPath .\tmp\esquilospeak.dump
```

Script chạy `pg_dump --format=custom --no-owner --no-privileges`, không đọc hoặc
in password và từ chối ghi đè file đã có. Lưu SHA-256 cùng artifact trong hệ
thống backup; không commit dump vào Git.

## Restore drill

Restore luôn vào database mới có hậu tố `_restore_drill`; script không cho phép
ghi vào database active:

```powershell
.\infrastructure\operations\Restore_Postgres_Drill.ps1 `
  -ContainerName <postgres-container> `
  -BackupPath .\tmp\esquilospeak.dump `
  -TargetDatabase esquilospeak_restore_drill `
  -ConfirmRestore
```

Sau restore:

1. Xác nhận `flyway_schema_history` có version kỳ vọng và không có row failed.
2. So sánh row count của learner, attempt, content version, mastery và audit.
3. Chạy backend smoke test với database restore ở cổng/instance cách ly.
4. Xác nhận dữ liệu đã xóa theo privacy workflow không được đưa lại vào active
   use. Nếu backup còn dữ liệu theo retention hợp lệ, chạy deletion
   reconciliation trước cutover.
5. Ghi thời gian backup, bắt đầu restore, hoàn tất validation và RPO/RTO thực tế.

## Migration rollback và forward-fix

Flyway migration production là forward-only:

1. Chụp backup và xác minh checksum trước deploy.
2. Dừng promotion nếu Flyway validation hoặc migration thất bại.
3. Không sửa file migration đã áp dụng và không chạy down migration ad-hoc.
4. Tạo migration `Vnext` nhỏ, idempotent khi có thể, để sửa schema/data.
5. Chỉ restore database khi migration gây hỏng dữ liệu không thể forward-fix
   trong RTO; restore vào instance mới rồi kiểm tra trước cutover.
6. App rollback chỉ hợp lệ nếu binary cũ tương thích schema mới. Nếu không,
   tiếp tục forward-fix cả app và schema.

## Incident response tối thiểu

1. **Detect:** alert từ availability, p95, 5xx, readiness, pool connection,
   rate-limit rejection hoặc backup failure.
2. **Triage:** dùng correlation/trace ID; không yêu cầu token hoặc dữ liệu cá
   nhân trong ticket.
3. **Contain:** dừng rollout, vô hiệu hóa publisher/processor gây lỗi bằng
   configuration, hoặc đưa instance unready. Không xóa dữ liệu để “khắc phục”.
4. **Recover:** forward-fix; nếu cần thì restore theo quy trình database mới.
5. **Validate:** chạy catalog → lesson → attempt → progress → mastery → review
   smoke journey và kiểm tra privacy/security audit.
6. **Communicate:** security/privacy/access incident được acknowledge trong 24
   giờ theo P0 gate; không cam kết 24/7 ở P0.
7. **Learn:** ghi timeline, impact, detection gap, action owner và test ngăn tái
   diễn. Không đưa secret/PII vào postmortem.

## Nguồn

- [Spring Boot — Observability](https://docs.spring.io/spring-boot/reference/actuator/observability.html)
- [Spring Boot — Graceful shutdown](https://docs.spring.io/spring-boot/reference/web/graceful-shutdown.html)
- [Spring Boot — Metrics](https://docs.spring.io/spring-boot/reference/actuator/metrics.html)
- [PostgreSQL 18 — Backup and restore](https://www.postgresql.org/docs/18/backup.html)
