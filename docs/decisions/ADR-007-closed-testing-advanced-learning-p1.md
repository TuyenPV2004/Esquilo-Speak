# ADR-007: Closed-testing advanced learning P1

- Status: Accepted
- Date: 2026-07-30

## Context

Giai đoạn 12 cần một backend contract ổn định để Android có thể tích hợp media,
pronunciation, writing/conversation, placement A1, engagement, commerce và
support. Môi trường hiện tại chưa có credential production cho object storage,
Google Cloud Speech-to-Text, Gemini hoặc Google Play Developer API.

Mục tiêu được chấp nhận là hoàn thiện phạm vi closed testing có hành vi xác định,
không giả định rằng adapter local đủ điều kiện production.

## Decision

- Giữ các miền P1 trong Java core platform theo Spring Modulith; chưa tách
  deployable service hoặc thêm data/ML platform.
- Công bố contract OpenAPI `0.5.0` và dùng provider-neutral ports cho media,
  speech, writing/conversation và purchase verification.
- Profile `local` dùng adapter deterministic: WAV sinh trong bộ nhớ, feedback
  kiểm thử và purchase token bắt đầu bằng `local-test-`.
- Profile khác `local` fail closed bằng `503` cho đến khi adapter production
  được cấu hình. Không tự động rơi về adapter giả trong production.
- Pronunciation chỉ giữ audio trong bộ nhớ trong thời gian xử lý; database chỉ
  lưu transcript, score, feedback dẫn xuất và provider. Không giữ raw voice.
- Purchase token không được lưu; backend chỉ lưu SHA-256 để chống claim/replay
  xuyên learner.
- Placement chỉ bao phủ A1 nội bộ. Record được phát hành khi đạt ngưỡng là
  `non_accredited_completion`, không được mô tả như chứng chỉ được công nhận.
- Premium entitlement là server-authoritative. Purchase và refund đều phải qua
  verifier; trạng thái refund thu hồi entitlement.
- Engagement activity dùng client event UUID để retry không cộng XP hai lần.
  Reminder preference là boundary cho local notification; push delivery thật
  vẫn là environment gate.
- Support/content report lưu trạng thái có thể triage. Endpoint tác nghiệp yêu
  cầu `SCOPE_operations` và `ROLE_SUPPORT` hoặc `ROLE_ADMIN`.
- Các miền mới tham gia privacy export/delete. Rate limit riêng áp dụng cho AI,
  commerce và support mutations.

## Consequences

Android có thể tích hợp và chạy closed testing end-to-end mà không cần credential
bên thứ ba. Migration V6 và integration tests tạo bằng chứng lặp lại được trên
PostgreSQL.

Production vẫn bị chặn cho đến khi có object storage/CDN, STT/AI safety và
evaluation thực, Play purchase verification/RTDN, push provider, secret
management và staging evidence. Organization/class, experimentation và
accredited certification không thuộc quyết định này.
