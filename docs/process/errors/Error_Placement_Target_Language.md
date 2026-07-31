# Lỗi Placement Test hiển thị sai target language

## Tên lỗi

Placement Test dùng UI locale cho prompt và đáp án thay vì target/content locale.

## Mô tả chi tiết

Khi learner chọn target language là English nhưng chọn tiếng Việt làm ngôn ngữ
giao diện, màn hình Xếp trình độ resolve `question.prompt` và `option.text` theo
`Localizations.localeOf(context)`. Vì assessment có cả bản `en` và `vi`, nội dung
kiểm tra bị dịch sang tiếng Việt. Ví dụ câu `Complete: My ___ is Ana.` hiển thị
`tên`, `ngày`, `đồ ăn` thay vì `name`, `day`, `food`.

## File xuất hiện lỗi

- [`placement_screen.dart`](../../../apps/mobile/lib/features/assessment/presentation/placement_screen.dart):
  lấy UI locale và dùng cùng locale để resolve prompt/option.
- [`V12__localize_presentation_content.sql`](../../../backend/core-platform/src/main/resources/db/migration/V12__localize_presentation_content.sql):
  chứa localized presentation data; dữ liệu hợp lệ nhưng làm lộ lỗi chọn locale ở consumer.
- [`p1_screens_test.dart`](../../../apps/mobile/test/learner_journey/p1_screens_test.dart):
  test cũ chỉ dùng UI `en` và không bảo vệ trường hợp UI locale khác target language.

## Ảnh hưởng

- Placement Test không đo khả năng hiểu target language như dự kiến.
- Người học có thể chọn đáp án dựa trên bản dịch, làm sai lệch score/evidence.
- Các course target language khác có thể gặp cùng lỗi nếu assessment cung cấp
  localized presentation theo nhiều locale.

## Các giải pháp đề xuất

1. **Được chọn:** giữ UI chrome theo `uiLocale`, nhưng resolve prompt/option theo
   `assessment.defaultLocale`, là locale canonical của nội dung assessment hiện hành.
   Đây là thay đổi nhỏ, không phá contract và dùng source of truth đã có.
2. Truyền `targetLanguage` từ learner profile vào `P1ViewModel`. Cách này tăng
   coupling với profile state và có nguy cơ lệch assessment/course response.
3. Thêm `targetLanguage` mới vào Assessment API. Rõ nghĩa hơn nhưng làm tăng phạm
   vi contract/backend khi trường `defaultLocale` hiện đã đủ cho lỗi này.

## Giải pháp developer chọn

Developer đã phê duyệt thực hiện phương án 1 sau khi nguyên nhân và kế hoạch được
trình bày ngày 2026-08-01.

## Cách triển khai

- `PlacementScreen` tách locale nội dung assessment khỏi UI locale và resolve cả
  prompt/option theo `assessment.defaultLocale`.
- Fake assessment tái hiện đúng dữ liệu EN/VI của câu `My ___ is Ana.`.
- Widget test chạy app với UI locale `vi`, xác nhận nội dung English xuất hiện và
  các bản dịch `tên`, `ngày`, `đồ ăn` không xuất hiện.
- Không thay đổi answer ID, submission order, scoring, API, schema hoặc migration.

Validation: targeted 6 widget test pass; Dart format pass; Flutter analyzer không
có issue; 42 test khác trong full suite pass và P0 fixture test pass khi chạy lại
trong cấu trúc thư mục repository đúng; contract freeze và document checks pass.

## Hướng dẫn sử dụng/vận hành sau khi sửa

Không có thay đổi cấu hình hoặc thao tác vận hành. Tester đặt UI locale là tiếng
Việt, chọn course target English, mở Xếp trình độ và xác nhận phần câu hỏi/đáp án
vẫn bằng English trong khi tiêu đề/nút vẫn bằng tiếng Việt.
