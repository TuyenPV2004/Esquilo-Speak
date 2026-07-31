# Walkthrough sửa lỗi Placement Test dùng sai locale

## Trạng thái

- Lỗi đã được xác nhận.
- Developer đã phê duyệt thực hiện bản sửa ngày 2026-08-01.
- Implementation và validation đã hoàn thành.

## Luồng lỗi

1. Learner chọn course có target language là English.
2. Learner chọn tiếng Việt làm ngôn ngữ giao diện.
3. Placement API trả prompt/option dạng localized text với locale mặc định `en`.
4. `PlacementScreen` dùng locale giao diện `vi` để resolve cả nội dung bài kiểm tra.
5. Câu `Complete: My ___ is Ana.` hiển thị lựa chọn `tên`, `ngày`, `đồ ăn`, làm
   nội dung đánh giá không còn ở target language.

## Kết quả mong đợi

- Tiêu đề, hướng dẫn, nút và kết quả dùng ngôn ngữ giao diện.
- Prompt và đáp án Placement Test dùng locale nội dung của assessment, tương ứng
  target language của course hiện hành.
- UI tiếng Việt + target English vẫn hiển thị câu hỏi và lựa chọn bằng English.

## Phạm vi sửa

- Điều chỉnh locale resolve prompt/option trong Flutter Placement UI.
- Thêm widget regression test cho UI `vi` và assessment content `en`.
- Không thay đổi API, schema, migration hoặc scoring ID.

## Validation dự kiến

- Dart format cho file thay đổi.
- Flutter analyzer và test Placement/P1 liên quan nếu SDK khả dụng.
- Static assertion bảo vệ tách biệt UI locale và assessment locale.
- Contract freeze, Markdown link và `git diff --check`.

## Kết quả thực hiện

- `PlacementScreen` dùng `assessment.defaultLocale` cho prompt và option; locale
  Flutter hiện tại chỉ còn dùng cho chrome và format UI.
- Regression test với UI `vi` xác nhận câu `Complete: My ___ is Ana.` cùng
  `name`, `day`, `food` hiển thị bằng English và bản dịch Vietnamese không xuất hiện.
- Targeted `p1_screens_test.dart`: 6 test pass.
- Dart format: 82 file được kiểm tra, không có thay đổi sau format.
- Flutter analyzer: không có issue.
- 42 test còn lại trong full suite pass; P0 fixture không tìm thấy file do layout
  `/tmp/mobile`, sau đó pass khi chạy lại trong layout `/tmp/repo/apps/mobile`
  đúng cấu trúc repository.

## Hướng dẫn xác nhận thủ công

1. Chọn tiếng Việt làm ngôn ngữ giao diện.
2. Chọn course có target language English.
3. Mở **Xếp trình độ**.
4. Xác nhận tiêu đề/nút bằng tiếng Việt nhưng prompt và lựa chọn kiểm tra bằng English.

