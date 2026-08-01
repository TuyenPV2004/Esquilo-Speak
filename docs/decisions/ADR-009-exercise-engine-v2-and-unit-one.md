# ADR-009: Exercise Engine V2 và Unit 1 vertical slice

- Trạng thái: Accepted
- Ngày: 2026-08-01

## Bối cảnh

Learning slice hiện chỉ render và chấm `multiple_choice`/`true_false`, màn hình luôn
lấy exercise đầu tiên và attempt chỉ mang option response. Curriculum A1 yêu cầu
nhiều modality, evidence độc lập UI, offline resume và một Unit 1 đủ năm lesson.

## Quyết định

1. Exercise là dữ liệu có `type`; Flutter và backend dùng registry theo type. Không
   tạo endpoint hay bảng attempt riêng cho từng renderer.
2. Response là tagged object có `kind`: `option`, `boolean`, `self_assessment`,
   `pairs`, `sequence` hoặc `text`. Evidence là object riêng gồm thời gian phản hồi,
   hint, retry, confidence và input modality.
3. Server xác thực response theo exercise type và là nguồn scoring canonical. Client
   không nhận answer policy trong lesson delivery và không tự quyết định correctness.
4. `selectedOptionId` được giữ làm adapter đọc trong một vòng chuyển tiếp; V2 client
   chỉ ghi `response` và `evidence` vào cùng outbox/idempotency flow hiện hữu.
5. Flashcard là self-assessment hợp lệ, không có “đáp án sai”. Chuẩn hóa text dùng
   trim, Unicode NFKC, co khoảng trắng và case-fold khi policy cho phép.
6. Lesson runtime lưu checkpoint theo lesson/version, chạy mistake review trước
   summary và chỉ coi lesson hoàn tất theo attempt canonical phía server.
7. Audio exercise bắt buộc có transcript và silent path; matching có tương tác tuần
   tự để screen reader không phụ thuộc drag-and-drop.
8. Writing, pronunciation và conversation tiếp tục dùng provider boundary P1 hiện
   hữu; Unit 1 liên kết activity definition thay vì giả lập deterministic P0 score.

## Hệ quả

- Có thể thêm dạng bài mà không đổi endpoint attempt, nhưng mọi type mới phải bổ sung
  đồng thời schema, semantic validator, scorer, renderer và contract/widget test.
- Answer leakage trở thành release blocker của content pipeline.
- Resume local là UX checkpoint; server attempts/progress vẫn là nguồn canonical khi
  reconnect và idempotency bảo vệ gửi trùng.
