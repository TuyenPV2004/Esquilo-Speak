# Closed Beta và Product Completion Gate

## 1. Phạm vi và nguyên tắc

Runbook này vận hành closed beta `closed-beta-v1` cho course `vi → en`, English
A1. Đây là bước thu bằng chứng sản phẩm trước release readiness, không phải quyền
phát hành công khai và không thay thế Giai đoạn 13.

Ba nguyên tắc bắt buộc:

1. Không dùng seed, fixture, widget test hoặc dữ liệu synthetic để khai là số liệu
   cohort thật.
2. Repository chỉ lưu evidence tổng hợp và mã giả danh; không commit tên, email,
   số điện thoại, voice, nội dung phỏng vấn thô, token hoặc database dump.
3. Telemetry là tùy chọn. Người không consent telemetry vẫn được học; metric outcome
   canonical phải phân biệt với funnel chỉ đại diện nhóm consent.

Contract có thể kiểm tra bằng máy nằm tại
`tests/closed-beta/Closed_Beta_Plan.json`. Quy mô tối thiểu 20 learner và 15 learner
đã trưởng thành D7 là baseline vận hành để ra quyết định beta, không phải tuyên bố
hiệu quả học tập có ý nghĩa thống kê.

## 2. Cohort, consent và kênh phản hồi

- Đối tượng: người Việt trưởng thành học tiếng Anh nền tảng; không nhận người dưới
  18 tuổi trong cohort V1.
- Thời gian quan sát: 14 ngày; enrollment phải đủ sớm để tối thiểu 15 learner có
  cửa sổ D7 hoàn chỉnh.
- Mỗi tester dùng `betaId` giả danh do coordinator quản lý ngoài repository.
- Trước khi bắt đầu, tester chấp thuận `beta-participation-v1`, được thông báo mục
  đích, dữ liệu thu thập, cách rút lui và kênh support. Consent
  `operational_telemetry` vẫn tách riêng và có thể từ chối.
- Kênh canonical cho lỗi/phản hồi là form Support trong app. Phản hồi định tính có
  thể phỏng vấn theo năm vùng onboarding, learning path, lesson, daily loop và
  feedback; repo chỉ nhận bản tổng hợp không thể truy về cá nhân.
- Rút lui hoặc yêu cầu dữ liệu dùng Support; export/delete đi qua privacy API hiện có.

## 3. SLA và severity

| Mức | Định nghĩa | Acknowledge | Hành động |
| --- | --- | --- | --- |
| P0 | Mất acknowledged attempt, privacy/safety nghiêm trọng, crash chặn hành trình hoặc nội dung gây hại | 4 giờ làm việc | Contain trong 8 giờ làm việc; chặn candidate; không được `accept_with_plan` |
| P1 | Hỏng chức năng chính, đáp án/content sai đáng kể, microphone/offline/reconnect không dùng được nhưng còn workaround giới hạn | 8 giờ làm việc | Có owner, action plan và release decision trong 16 giờ làm việc |
| P2 | Lỗi cục bộ/cosmetic hoặc cải thiện không chặn beta | 2 ngày làm việc | Triage vào backlog có lý do |

Privacy hoặc safety report luôn được acknowledge không quá 24 giờ dù severity ban
đầu chưa chắc chắn. Owner phải là mã team/operator như `team:content`, không dùng
email hay tên cá nhân.

Operations dùng:

- `GET /api/support/v1/tickets` để đọc queue có severity/owner/plan/decision.
- `PATCH /api/support/v1/tickets/{ticketId}/triage` để ghi triage. Mỗi lần ghi tạo
  immutable audit event với actor đã băm SHA-256.
- P0 chỉ có thể `pending`, `block`, rồi `fixed`; P1 có thể
  `accept_with_plan` khi quyết định release được ghi rõ.
- `resolved` bắt buộc `fixed` và resolution summary; `dismissed` bắt buộc
  `not_applicable` và summary. Support phải yêu cầu tester xác nhận lại trước khi
  tính vòng phản hồi nghiêm trọng đã đóng.

Endpoint `/status` cũ chỉ giữ tương thích; không dùng nó để đóng P0/P1 beta vì
không mang owner, plan và release decision.

## 4. Ma trận Android và hành trình

Trước enrollment, coordinator ghi API level thực tế từ thiết bị, không suy ra từ
tên máy. Evidence tối thiểu:

- 3 API level khác nhau, bao phủ minimum supported, một mức giữa và target supported;
- 2 model thiết bị thật khác nhau;
- 2 lần pass microphone trên thiết bị thật;
- emulator chỉ bổ sung, không thay bằng chứng thiết bị thật.

Mỗi bucket chạy full journey theo `docs/shared/Guide.md`: onboarding → path → lesson
→ daily session → review/practice → summary; ít nhất một thiết bị chạy offline,
submit, reconnect và đối chiếu acknowledged attempt không mất/nhân đôi. Thiết bị
thật chạy pronunciation/conversation với quyền microphone deny/allow/revoke.

Lệnh tham chiếu:

```powershell
flutter devices
adb devices -l
Set-Location apps/mobile
flutter test integration_test/learning_flow_integration_test.dart `
  --flavor local --dart-define=ESQUILO_ENV=local `
  --dart-define=ESQUILO_API_URL=http://127.0.0.1:8080 -d <device-id>
```

Không đưa device serial thật vào Git. Trường `modelRef` trong evidence phải là mã
giả danh ổn định như `physical-a`.

## 5. Lịch beta và evidence

### Trước ngày 0

1. Chạy contract/content/backend/mobile regression và build APK candidate.
2. Diễn tập backup/restore, privacy export/delete và support closed loop.
3. Xác nhận dashboard trả source, sample size và `null` khi denominator chưa trưởng thành.
4. Chốt candidate; mọi thay đổi code/content sau đó tạo candidate mới hoặc ghi rõ lý do.

### Ngày 0–6

1. Theo dõi activation, first-lesson/Unit 1 completion, crash và support hằng ngày.
2. Triage P0/P1 theo SLA; dừng enrollment khi P0 chưa contain.
3. Phỏng vấn tổng hợp năm vùng trải nghiệm; không ghi raw transcript vào repository.
4. Không kết luận D7 từ cohort chưa trưởng thành.

### Ngày 7–14

1. Chốt denominator D1/D7 theo catalog metric; ghi sample size và cửa sổ UTC.
2. Đóng vòng content report nghiêm trọng với tester.
3. Rerun regression sau mọi P0/P1 fix và cập nhật candidate evidence.
4. Product owner/developer review dashboard, feedback tổng hợp, defect register và
   mọi gate kỹ thuật trước khi ký.

Copy template thành một file mới dạng `YYYY-MM-DD-<candidate>.json` trong
`tests/closed-beta/evidence/`. Mỗi device record dùng cấu trúc:

```json
{
  "modelRef": "physical-a",
  "physical": true,
  "androidApiLevel": 35,
  "apiBucket": "target_supported",
  "journeyPass": true,
  "offlineReconnectPass": true,
  "microphonePass": true
}
```

`decisionSummary` chỉ ghi kết luận tổng hợp. Sign-off ghi role + ngày + decision
reference, không ghi chữ ký số bí mật hoặc contact data.

## 6. Lệnh gate

Kiểm tra contract luôn phải pass trước khi mở beta:

```powershell
node --test tests/closed-beta/Closed_Beta_Contract_Test.mjs
```

Kiểm tra completion fail-closed:

```powershell
node tests/closed-beta/Evaluate_Closed_Beta_Gate.mjs
```

Nếu chưa có evidence thật, exit code `2` là kết quả đúng. Chỉ khi lệnh này pass,
không còn P0, P1 đủ owner/plan/decision, reviewer ký và developer xác nhận bằng
văn bản thì mới đánh dấu toàn bộ Product Completion Gate và mở Giai đoạn 13.

## 7. Stop/rollback rule

Dừng enrollment hoặc candidate khi có P0, privacy/safety breach, acknowledged
attempt loss, duplicate vượt ngưỡng, crash-free dưới 99,5%, first-lesson completion
dưới 60%, hoặc evidence không truy vết được. Không hạ ngưỡng để hợp thức hóa beta.
Fix phải có regression và tester verification; nếu thay đổi contract/content semantics
lớn, bắt đầu lại cửa sổ quan sát bị ảnh hưởng.
