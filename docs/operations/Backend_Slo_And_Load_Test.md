# Backend SLO And Load Test

## Mục tiêu P0

Đây là internal objective cho closed testing, không phải cam kết production:

| SLI | SLO 30 ngày |
| --- | --- |
| Backend API availability | Ít nhất 99,5% response không phải 5xx/network failure |
| Ordinary read latency | p95 ≤ 500 ms |
| Ordinary mutation latency | p95 ≤ 800 ms |
| Acknowledged attempt loss | 0 confirmed |
| Duplicate logical accepted attempt | < 0,01% |
| Backup recovery | RPO ≤ 24 giờ, RTO ≤ 4 giờ |

Availability 99,5% cho cửa sổ 30 ngày tương ứng error budget khoảng 216 phút.
Budget được đo theo request và theo thời gian; planned maintenance chỉ loại khỏi
SLI nếu được quyết định trước và ghi rõ trong báo cáo.

## Metric và truy vấn

- `http_server_requests_seconds_*`: request count/latency theo route template,
  method, status/outcome; không thêm learner ID.
- `esquilospeak_http_server_failures_total`: 5xx theo route category.
- `esquilospeak_rate_limit_rejected_total`: rejection theo policy.
- Hikari, JVM, process, disk và application startup/ready metrics từ Actuator.
- Attempt loss/duplicate lấy từ reconciliation query và sync mutation audit,
  không suy ra chỉ từ HTTP request count.

Burn-rate alert khởi điểm:

- Page: 14,4× budget trong cửa sổ 1 giờ và 6× trong 6 giờ.
- Ticket: 3× trong 24 giờ.
- Latency: read hoặc mutation p95 vượt mục tiêu trong 15 phút với tối thiểu 100
  sample.
- Rebaseline sau 30 ngày closed-test có traffic đại diện.

## Load journey

Script không có dependency ngoài Node.js 21+:

```powershell
node .\tests\load\P0_Journey_Load_Test.mjs `
  --base-url http://localhost:8080 `
  --concurrency 4 `
  --iterations 10 `
  --enforce true
```

Mỗi iteration tạo guest local riêng và chạy:

1. language/course/lesson discovery;
2. append-only attempt có idempotency key;
3. progress, mastery và review queue.

Output chỉ gồm aggregate latency/status, không chứa token, learner ID hoặc
payload. `--enforce true` trả exit code khác 0 nếu error rate > 0,5%, read p95 >
500 ms hoặc mutation p95 > 800 ms.

## Baseline evidence

Baseline local ngày 2026-07-30:

| Runtime | Journey | Request | Error rate | Read p95 | Mutation p95 |
| --- | --- | ---: | ---: | ---: | ---: |
| Spring Boot 4.1.0/JDK 21, PostgreSQL 18, Docker Desktop | 4 worker × 10 iteration | 361 | 0% | 40,42 ms | 244,19 ms |

Baseline đạt các ngưỡng P0 của script. Backup custom-format sau journey restore
thành công vào database cách ly, xác nhận Flyway version 5 và 40 attempt. SIGTERM
hoàn tất graceful shutdown trước giới hạn 20 giây. Đây chỉ là bằng chứng local
cho regression/load harness; không thay thế benchmark staging production-like
của Giai đoạn 9.

## Nguồn

- [Google SRE — Service level objectives](https://sre.google/sre-book/service-level-objectives/)
- [Google SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Spring Boot — HTTP server metrics](https://docs.spring.io/spring-boot/reference/actuator/metrics.html)
