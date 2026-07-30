# Backend Release Gate

## Phạm vi

Evidence này theo dõi Giai đoạn 9 cho backend P0 và đợt tích hợp Android
`p0-android-0.4.0`. Một mục chỉ đạt khi có artifact cùng validation local hoặc
môi trường tương ứng. Tài liệu này không cấp quyền public production release.

## Trạng thái gate

| Gate | Trạng thái | Evidence |
| --- | --- | --- |
| Contract lint và compatibility | Đạt | Redocly 2.39.0 lint pass; oasdiff 1.17.0 so `HEAD` với release contract không phát hiện thay đổi; CI tiếp tục so với PR base và fail từ mức `WARN` |
| Backend regression | Đạt | 24 test, 0 failure/error/skip; Spring Modulith và `bootJar` pass |
| PostgreSQL mục tiêu và migration | Đạt | Testcontainers `postgres:18-alpine` áp dụng tuần tự Flyway V1→V5 và xác nhận các bảng P0 |
| External identity staging | Chưa đạt | Chưa có external non-production OIDC tenant, Android PKCE/token lifecycle hoặc production-like TLS configuration |
| Backup/restore và runbook | Đạt | PostgreSQL 18 custom-format backup/restore drill xác nhận Flyway V5 và 40 attempt; graceful shutdown và forward-fix runbook đã diễn tập ở Giai đoạn 8 |
| P0 security/privacy | Chưa đạt | ASVS-P0-01 và ASVS-P0-02 vẫn là high release blocker; chưa có risk acceptance; DAST và supply-chain evidence vẫn mở |
| API/Android fixture freeze | Một phần | OpenAPI 0.4.0 và fixture cho 21 mobile operation đã khóa SHA-256, Node validator pass; Flutter SDK không có trong môi trường hiện tại nên consumer test mới chưa chạy |

## Contract và fixture freeze

Nguồn đóng băng:

- `contracts/openapi/esquilospeak-learning-v1-0.4.0.yaml`
- `tests/contract/P0_Release_Freeze_Manifest.json`
- `tests/contract/fixtures/P0_Android_Integration.json`

Validator bắt buộc:

1. OpenAPI version và checksum trùng manifest.
2. Mọi fixture JSON có checksum trùng manifest.
3. Fixture bao phủ đủ mọi `operationId` dưới `/api/mobile/v1/**`.
4. Fixture không chứa access/refresh token, authorization, password hoặc
   private key.
5. Learner lesson fixture không chứa đáp án hoặc explanation.

Checksum không phải cơ chế phê duyệt. Mọi thay đổi contract/fixture vẫn phải qua
compatibility review, backend regression, consumer test và review của
developer. Breaking change có chủ đích yêu cầu API major version mới cùng
decision record được chấp nhận.

## Lệnh validation đã chạy

```powershell
node .\tests\contract\Validate_P0_Release_Freeze.mjs

pnpm --package=@redocly/cli@2.39.0 dlx redocly lint `
  .\contracts\openapi\esquilospeak-learning-v1.yaml --extends=spec

docker run --rm -v "<repository>:/repo" -w /repo `
  tufin/oasdiff:v1.17.0 breaking --fail-on WARN `
  HEAD:contracts/openapi/esquilospeak-learning-v1.yaml `
  contracts/openapi/esquilospeak-learning-v1.yaml

cd .\backend\core-platform
.\gradlew.bat test bootJar
```

Kết quả ngày 2026-07-30:

- Release-freeze validator: 21 mobile operations, 1 fixture bundle, pass.
- Redocly: API description hợp lệ.
- oasdiff: không phát hiện thay đổi.
- Backend: 24 test pass; 0 failure, error hoặc skipped; `bootJar` pass.
- PostgreSQL: version 18, Flyway V1→V5 pass.

## Việc còn phải làm ngoài môi trường local

1. Chạy job `mobile` và `android-end-to-end` trên pull request để xác nhận
   `p0_contract_fixture_test.dart` cùng emulator API 35.
2. Cấu hình external non-production OIDC staging; kiểm tra issuer, audience,
   PKCE, refresh, logout/revocation và key rotation.
3. Thu thập TLS, encryption-at-rest, KMS và backup access evidence.
4. Chạy DAST/penetration test trên release candidate staging.
5. Xác minh repository có GitHub Dependency Review entitlement trước khi bật
   gate; public repository hoặc GitHub Code Security là điều kiện của tính năng.

## Nguồn

- [Redocly CLI lint](https://redocly.com/docs/cli/commands/lint)
- [oasdiff breaking-change checks](https://github.com/oasdiff/oasdiff/blob/main/docs/BREAKING-CHANGES.md)
- [GitHub dependency review](https://docs.github.com/en/code-security/concepts/supply-chain-security/dependency-review)
- [Flyway migrations](https://documentation.red-gate.com/flyway/flyway-concepts/migrations)
- [PostgreSQL 18 backup and restore](https://www.postgresql.org/docs/18/backup.html)
