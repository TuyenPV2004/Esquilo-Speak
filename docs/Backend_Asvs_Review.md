# Backend ASVS Review

## Phạm vi và phương pháp

Review ngày 2026-07-30 dùng **OWASP ASVS 5.0.0 stable**, áp dụng baseline Level 1
và các control Level 2 liên quan identity, privacy, admin content và offline
mutation. Đây là self-review dựa trên source, configuration và integration test;
không phải chứng nhận độc lập hoặc penetration test.

## Kết quả

| Nhóm ASVS 5.0 | Trạng thái | Evidence/kết luận |
| --- | --- | --- |
| Encoding, injection và data validation | Đạt P0 | Controller validation, identifier allow-list, JDBC named parameters, JSON schema/OpenAPI lint |
| Web frontend security | Không áp dụng backend API | Không render HTML; CSRF tắt vì stateless bearer API, không dùng cookie session |
| API và web service | Đạt P0 | TLS là deployment gate; JSON/problem contract, body size/framework limits, idempotency, cursor validation và object ownership test |
| File handling | Không áp dụng P0 | Backend không nhận upload; backup script chỉ nhận local operator path và từ chối overwrite |
| Authentication | Một phần, release blocker đã biết | Production issuer/audience/expiry validation có test; external OIDC staging tenant và MFA/recovery thuộc provider chưa được diễn tập |
| Session management | Đạt phạm vi API | Stateless bearer; deletion/merge state thu hồi quyền learner nội bộ; không có server HTTP session |
| Authorization | Đạt P0 | Mobile/admin/operations scope + role, internal learner ID từ token, cross-learner privacy tests |
| Self-contained tokens | Đạt P0 | JWT issuer/audience/expiry và role allow-list; không log raw token; key rotation phụ thuộc external IdP |
| OAuth/OIDC | Một phần, release blocker đã biết | Resource server đúng boundary; PKCE/login/mobile token custody cần xác minh cùng IdP và Android ở Giai đoạn 9–10 |
| Cryptography | Một phần | SHA-256 pseudonymization/checksum; TLS, encryption at rest, KMS/key rotation là deployment evidence còn thiếu |
| Secure communication | Một phần | Production yêu cầu external HTTPS issuer; TLS termination/cipher/HSTS/mTLS chưa có environment để kiểm tra |
| Configuration | Đạt source baseline | Local issuer profile-only, secret lấy từ environment, Actuator allow-list, structured production logging, graceful shutdown |
| Data protection/privacy | Đạt P0 source | Pseudonymous identity mapping, consent, export/deletion, retention processors, no P0 voice, backup reconciliation rule |
| Secure coding/architecture | Đạt P0 | Spring Modulith boundary test, append-only attempts, transactional events, immutable published content |
| Logging and error handling | Đạt P0 | ECS logs, correlation + OTel trace context, allow-listed audit metadata, RFC 9457-style problem payload, no body/token logging |
| WebRTC | Không áp dụng | Không có WebRTC P0 |
| Security headers/browser controls | Không áp dụng trực tiếp | JSON bearer API; admin frontend headers sẽ review ở frontend/reverse proxy gate |
| Business logic | Đạt P0 | Age restriction, content approval, guest merge, privacy ownership, idempotency/conflict/concurrency/rate-limit tests |
| Malicious code/dependency | Một phần | Gradle wrapper/CI regression có; SBOM, dependency vulnerability gate và artifact signing thuộc Giai đoạn 9 |

## Finding còn mở

| ID | Mức | Finding | Điều kiện đóng |
| --- | --- | --- | --- |
| ASVS-P0-01 | High release blocker | Chưa xác minh external OIDC, PKCE/token lifecycle và key rotation trên staging | IdP staging + Android auth integration test |
| ASVS-P0-02 | High release blocker | Chưa có TLS/encryption-at-rest/KMS evidence production-like | Chọn environment, TLS scan và key/backup access review |
| ASVS-P0-03 | Medium | Rate limit trong tiến trình không tạo quota toàn cục khi scale ngang | Giữ một instance hoặc chuyển enforcement lên gateway/distributed limiter trước horizontal scale |
| ASVS-P0-04 | Medium | Chưa có independent DAST/penetration test | Chạy trên staging release candidate và triage P0 finding |
| ASVS-P0-05 | Medium | Chưa có SBOM/signing/vulnerability release gate đầy đủ | Hoàn thành Giai đoạn 9 supply-chain checks |

Không có finding P0 mới yêu cầu thay đổi product decision. Các finding trên là
release/environment gate đã được giữ mở, không được diễn giải là đã pass.

## Nguồn

- [OWASP ASVS project](https://owasp.org/www-project-application-security-verification-standard/)
- [OWASP ASVS 5.0.0 stable repository](https://github.com/OWASP/ASVS/tree/v5.0.0_release)
- [OWASP ASVS release list](https://github.com/OWASP/ASVS/releases)
