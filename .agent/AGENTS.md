# EsquiloSpeak Custom Workspace Rules

## Quy tắc ngôn ngữ và giao tiếp (Language and Communication Rule)

- Khi developer viết bằng tiếng Việt, agent phải phản hồi bằng tiếng Việt.
- Giải thích rõ ràng, ngắn gọn và tập trung vào hành động thực tế.
- Trước khi sửa code cho tác vụ nhiều bước, phải tóm tắt ngắn gọn mục tiêu và cách thực hiện.
- Nếu chưa chắc chắn, phải nói rõ phần chưa chắc chắn thay vì suy đoán hoặc trình bày giả định như sự thật.

## Quy tắc làm việc và báo cáo (Working Style and Reporting Rule)

- Trước khi thay đổi, phải đọc cấu trúc dự án, rule ở phạm vi liên quan và các file cần thiết. Rule/module cụ thể của dự án được ưu tiên hơn rule dùng chung khi có khác biệt.
- Ưu tiên thay đổi nhỏ, tập trung và nằm trong phạm vi đã được yêu cầu.
- Không thực hiện refactor lớn, thay đổi kiến trúc, format toàn repository hoặc thay đổi public API nếu developer chưa yêu cầu hoặc phê duyệt rõ ràng.
- Sau khi thay đổi, phần tổng kết phải nêu:
  - File nào đã thay đổi.
  - Vì sao từng file hoặc nhóm file được thay đổi.
  - Các lệnh hoặc cách kiểm tra đã thực hiện.
  - Rủi ro còn lại và khu vực chưa được xác minh.
- Khi có file thay đổi, phải đề nghị developer review diff trước khi commit.

## Quy tắc an toàn và quyền hạn (Safety and Permissions Rule)

- Không đọc, in, sao chép, sửa hoặc commit file chứa thông tin đăng nhập, token, cookie, secret, private key, `.env`, `auth.json` hoặc nội dung nhạy cảm nếu developer chưa yêu cầu rõ ràng.
- Không chạy lệnh có thể phá hủy dữ liệu, reset lịch sử Git, force-push, format ổ đĩa, xóa thư mục lớn hoặc thay đổi quyền hệ thống.
- Không cài dependency mới hoặc thay đổi package manager nếu không có lý do cấp dự án và sự cho phép phù hợp.
- Không gửi secret hoặc dữ liệu nhạy cảm tới pastebin, gist, server ngoài, dịch vụ công khai hoặc bất kỳ nơi nào ngoài phạm vi được developer cho phép.
- Nếu phát hiện secret hoặc token trong repository, chỉ thông báo vị trí và đề xuất cách xử lý an toàn; không in toàn bộ giá trị secret.

## Quy tắc viết code nền tảng (General Coding Rule)

- Đọc convention và pattern hiện có trước khi viết code; giữ style nhất quán với codebase.
- Chỉ thêm comment khi logic không hiển nhiên hoặc cần ghi lại một quyết định kỹ thuật quan trọng.
- Ưu tiên code dễ đọc, dễ kiểm thử và dùng ít dependency nhất có thể.
- Không sửa file generated, lockfile, migration hoặc snapshot nếu việc đó không thực sự cần thiết cho yêu cầu.
- Không thay đổi public contract, schema, migration hoặc boundary giữa module ngoài phạm vi đã được phê duyệt.

## Quy tắc hạn chế hardcode cứng dữ liệu (Hardcoded Data Avoidance Rule)

- Không nhúng trực tiếp vào application logic các giá trị có khả năng thay đổi theo ngôn ngữ, locale, course, proficiency framework/level, lesson, exercise, media, product, entitlement, achievement, XP, lịch nhắc, múi giờ, retention hoặc policy vận hành.
- Dữ liệu nghiệp vụ và nội dung phải lấy từ source of truth phù hợp như learner profile/learning context, published content, catalog, versioned policy, typed configuration hoặc provider response. Không suy luận nghiệp vụ từ ID, tên hiển thị hay chuỗi dành cho fixture.
- Phân biệt rõ ba nhóm trước khi thay một literal bằng cấu hình:
  - **Hằng số kỹ thuật ổn định:** protocol value, validation bound, controlled vocabulary và invariant đã được contract/ADR chốt có thể giữ trong code bằng enum, value object hoặc named constant.
  - **Dữ liệu/policy có thể tiến hóa:** phải data-driven, versioned hoặc cấu hình typed; thay đổi không nên buộc sửa nhiều module hay phát hành lại client nếu không cần thiết.
  - **Fixture/local-only default:** chỉ được tồn tại trong test, seed hoặc local adapter có tên và profile rõ ràng; không được âm thầm làm fallback cho production.
- Không thay hardcode bằng một “global constant” nếu giá trị thực tế thuộc ngữ cảnh người dùng, course, target language, thị trường, provider hoặc môi trường. Source of truth phải nằm ở đúng domain sở hữu dữ liệu.
- Khi bắt buộc giữ một giá trị cố định, phải dùng tên thể hiện ý nghĩa, giới hạn phạm vi nhỏ nhất, có test bảo vệ invariant và ghi rõ lý do/điều kiện đánh giá lại nếu giá trị không hiển nhiên.
- Khi thêm ngôn ngữ, framework, level, course, lesson, exercise type, media type, product hoặc achievement mới, ưu tiên thay đổi catalog/content/configuration cùng contract tương ứng; không thêm chuỗi ID mới vào nhiều nhánh `if/switch` rải rác.
- Trong review và validation, phải tìm các literal nghiệp vụ đáng chú ý, kiểm tra đường đi của locale/language/course/policy từ source of truth tới consumer, và xác nhận fixture/local default không đi vào production path.
- Không overengineering: không đưa mọi số hoặc chuỗi vào database/config. Chỉ trừu tượng hóa khi giá trị thay đổi theo ngữ cảnh, có owner/policy riêng, cần version/audit, hoặc việc giữ cứng làm tăng chi phí mở rộng và nguy cơ sai lệch.

## Quy tắc lập kế hoạch chung (General Planning Rule)

- Tạo kế hoạch ngắn trước khi triển khai nếu tác vụ phức tạp, mơ hồ, có nhiều bước, ảnh hưởng nhiều file, thay đổi kiến trúc hoặc bảo mật, hay cần nhiều vòng validation.
- Kế hoạch phải nêu mục tiêu, file/khu vực cần kiểm tra, các bước dự kiến, chiến lược validation, giả định, rủi ro và yêu cầu chưa rõ.
- Giữ kế hoạch ngắn gọn và có thể hành động; không lập kế hoạch dài cho câu hỏi trực tiếp hoặc thay đổi văn bản nhỏ, đơn giản.
- Sau khi lập kế hoạch, tiếp tục thực hiện nếu ngữ cảnh và quyền hạn đã đủ. Chỉ dừng chờ developer khi quyết định còn thiếu có thể làm thay đổi đáng kể kết quả hoặc liên quan đến rủi ro, phá hủy dữ liệu, bảo mật hay phạm vi ngoài yêu cầu.
- Kế hoạch chung này không thay thế `docs/plans/Ke_Hoach_1.md` và `docs/plans/Ke_Hoach_2.md`; mọi công việc ảnh hưởng roadmap vẫn phải tuân thủ Quy tắc bám sát kế hoạch triển khai bên dưới.

## Quy tắc kiểm thử và validation nền tảng (General Testing and Validation Rule)

- Sau khi thay đổi code, phải chạy test, lint, type check, build hoặc quality gate phù hợp mà dự án cung cấp.
- Nếu chưa biết lệnh validation, phải kiểm tra `README`, tài liệu setup, build file, package manifest và convention của module liên quan.
- Với bug fix, phải thêm hoặc cập nhật test tái hiện lỗi khi có test surface phù hợp.
- Nếu không thể chạy một kiểm tra, phải nêu rõ lý do, lệnh developer có thể chạy thủ công và rủi ro còn lại; không được coi phần chưa kiểm tra là đã pass.
- Quy tắc này là baseline; các yêu cầu hồi quy chi tiết hơn trong Feature Regression Testing Rule vẫn bắt buộc áp dụng.

## Quy tắc lựa chọn công nghệ và kiến trúc (Technology and Architecture Decision Rule)

- Không mặc định dùng công nghệ từ dự án khác. Với EsquiloSpeak, trước hết phải tuân thủ ADR đã được chấp nhận, `docs/shared/Project.md`, `docs/architecture/Tech_Stack_And_Architecture.md`, `docs/architecture/Repository_Structure.md`, contract và roadmap hiện hành.
- Chỉ đánh giá hoặc đề xuất công nghệ mới cho quyết định chưa được source-of-truth của dự án chốt hoặc khi developer yêu cầu xem xét lại quyết định hiện có.
- Khi cần lựa chọn, phải cân nhắc yêu cầu thực tế, độ phức tạp, quy mô, khả năng bảo trì, kỹ năng đội ngũ, môi trường triển khai, bảo mật, chi phí và khả năng phát triển lâu dài.
- Phải so sánh các phương án phù hợp thay vì mặc định chọn công nghệ quen thuộc; ưu tiên công nghệ ổn định, có tài liệu tốt và được sử dụng rộng rãi nếu không có lý do rõ ràng để chọn hướng chuyên biệt hơn.
- Có thể tham khảo bài học từ hệ thống lớn khi dự án thực sự cần scale, nhưng không sao chép mô hình enterprise vào phạm vi nhỏ một cách máy móc.
- Tránh overengineering; chỉ bổ sung framework, database, infrastructure tool hoặc architectural layer khi có lý do cấp dự án và được phê duyệt phù hợp.
- Khi đề xuất stack hoặc thay đổi công nghệ, phải giải thích vì sao phù hợp, phương án thay thế đã cân nhắc, trade-off, rủi ro/migration cost và thời điểm nên đánh giá lại.
- Nếu không thể truy cập nguồn online, phải nêu giới hạn và dựa trên source-of-truth trong repository, tài liệu local cùng best practice đã biết.

## Error Documentation Rule
Chỉ thực hiện việc ghi nhận lỗi và lập tài liệu khi người dùng yêu cầu đưa ra giải pháp xử lý lỗi cụ thể. Không tự ý tạo file markdown cho mọi lỗi nhỏ phát hiện được trong quá trình lập trình/kiểm thử thông thường.

Khi được người dùng yêu cầu xử lý lỗi, agent phải thực hiện các bước sau:
1. **Lập tài liệu ghi nhận lỗi:** Ghi lại thông tin chi tiết lỗi vào:
   * File `docs/process/Walkthrough.md` trong hệ thống (artifact `walkthrough.md`).
   * Một file markdown mô tả lỗi trong `docs/process/errors/` (ví dụ: `docs/process/errors/Error_<Tên_Lỗi>.md`).
   * **Quy tắc đặt tên file ghi chú (Deferred/Note Rule):** Đối với các lỗi hoặc vấn đề người dùng yêu cầu "để sau" hoặc chỉ "note/ghi chú lại để review sau", tên file markdown bắt buộc phải bắt đầu bằng `note_error` (ví dụ: `note_error_<tên_lỗi>.md`).
2. **Lập Kế hoạch triển khai (Implementation Plan):** Trước khi thực hiện sửa lỗi, bắt buộc phải tạo/cập nhật `docs/plans/implementation_plan.md` mô tả các bước chỉnh sửa dự kiến và xin ý kiến phê duyệt của người dùng.

Nội dung ghi nhận lỗi phải bao gồm:
- **Tên lỗi**
- **Mô tả chi tiết lỗi**
- **Lỗi xuất hiện ở những file nào** (kèm link file cụ thể)
- **Ảnh hưởng của lỗi** đến hệ thống/người dùng
- **Các giải pháp đề xuất cho dev**
- **Giải pháp dev chọn**
- **Giải pháp đó đã được thực hiện như thế nào** (cập nhật sau khi hoàn thành)
- **Hướng dẫn sử dụng/vận hành sau khi sửa** (nếu có, ví dụ: các lệnh chạy/build mới, thiết lập môi trường mới. Nếu không có thì ghi "Không có")

## Quy tắc Ngôn ngữ cho Kế hoạch Triển khai (Implementation Plan Language Rule)
Kế hoạch triển khai (file artifact `docs/plans/implementation_plan.md`) bắt buộc phải được viết hoàn toàn bằng tiếng Việt.

## Quy tắc bám sát kế hoạch triển khai (Implementation Roadmap Alignment Rule)

`docs/plans/Ke_Hoach_1.md` lưu foundation đến Giai đoạn 13 đang tạm khóa; `docs/plans/Ke_Hoach_2.md` là roadmap hoàn thiện sản phẩm hiện hành trước khi mở khóa Giai đoạn 13. Khi lập kế hoạch hoặc thay đổi application, contract, schema, migration, test, cấu hình runtime, infrastructure hay tài liệu có ảnh hưởng đến phạm vi triển khai, agent bắt buộc phải:

1. Đọc giai đoạn và quality gate liên quan trong cả `docs/plans/Ke_Hoach_1.md` và `docs/plans/Ke_Hoach_2.md` trước khi đề xuất hoặc thực hiện công việc.
2. Đối chiếu với ADR đã được chấp nhận, `docs/shared/Project.md`, `docs/architecture/Tech_Stack_And_Architecture.md`, `docs/architecture/Repository_Structure.md` và contract máy đọc được. Nếu có xung đột, không tự sửa lịch sử quyết định; phải nêu xung đột và xin developer chốt hướng xử lý.
3. Theo thứ tự hiện tại: hoàn thiện backend và backend quality gate của phạm vi được duyệt trước, sau đó mới triển khai Android frontend tương ứng. Không mở rộng native iOS khi chưa có yêu cầu ưu tiên mới từ developer.
4. Không bắt đầu một giai đoạn phụ thuộc khi điều kiện vào hoặc quality gate bắt buộc chưa đạt, trừ khi developer chủ động đổi ưu tiên. Ngoại lệ phải được ghi rõ trong kế hoạch cùng rủi ro.
5. Sau thay đổi làm dịch chuyển trạng thái roadmap, cập nhật hạng mục tương ứng và `docs/process/Development_Change_Log.md` trong cùng yêu cầu.
6. Chỉ đánh dấu `[x]` khi hạng mục đã có artifact hoặc implementation thực tế và đã vượt validation/acceptance tương ứng. Hạng mục làm một phần hoặc chưa kiểm tra phải giữ `[ ]` và ghi rõ phần đã có, phần còn thiếu.
7. Yêu cầu mới phải được đặt vào đúng giai đoạn, có dependency, điều kiện hoàn thành và validation. Không biến các file `Ke_Hoach_*.md` thành danh sách ý tưởng không có thứ tự.
8. Nếu developer thay đổi phạm vi hoặc thứ tự, cập nhật kế hoạch trước khi triển khai code để roadmap tiếp tục phản ánh quyết định mới nhất.

## Quy tắc câu hỏi làm rõ và đề xuất (Clarifying Questions and Recommendations Rule)

- Trước khi tạo kế hoạch hoặc thực hiện bất kỳ thay đổi nào, bao gồm chỉnh sửa hoặc tạo mới code, file, cấu hình, dữ liệu, kiến trúc hay tài liệu, agent phải xác định những thông tin còn thiếu có thể ảnh hưởng đáng kể đến kết quả.
- Chỉ liệt kê ngắn gọn các câu hỏi thực sự cần thiết. Câu hỏi có thể liên quan đến database, môi trường triển khai, nền tảng mục tiêu, tích hợp, quy mô, bảo mật, ràng buộc, tiêu chí nghiệm thu hoặc công nghệ ưu tiên.
- Ngay dưới mỗi câu hỏi, phải có mục **Recommended approach / Đề xuất tốt nhất** nêu phương án agent cho là phù hợp nhất, lý do lựa chọn và trade-off quan trọng để developer có thể phê duyệt hoặc dùng trực tiếp làm phương án mặc định.
- Phải phân biệt câu hỏi chặn triển khai và câu hỏi không chặn triển khai. Chờ developer trả lời nếu việc tiếp tục có thể gây rủi ro, phá hủy dữ liệu, ảnh hưởng bảo mật hoặc có khả năng cao tạo ra giải pháp sai. Với câu hỏi không chặn, nêu rõ giả định và tiếp tục theo đề xuất tốt nhất nếu developer không yêu cầu phương án khác.
- Không được tạo câu hỏi chỉ để đáp ứng hình thức của quy tắc này. Nếu ngữ cảnh hiện có đã đầy đủ, phải nói rõ không cần thêm thông tin và tiếp tục công việc.

## Quy tắc phê duyệt sửa đổi mã nguồn (Code Modification Approval Rule)
Tuyệt đối không tự ý thực hiện bất kỳ sửa đổi (chỉnh sửa, thêm mới, xóa) nào đối với mã nguồn của dự án mà không có sự cho phép rõ ràng từ nhà phát triển (developer).

Trước khi thực hiện bất kỳ chỉnh sửa nào đối với code, agent bắt buộc phải:
1. **Thông báo trước cho nhà phát triển:** Nêu rõ lỗi hoặc vấn đề đang cần sửa.
2. **Nêu rõ nguyên nhân:** Giải thích tại sao lỗi đó lại phát sinh.
3. **Liệt kê chi tiết nội dung sẽ sửa đổi:** Chỉ ra cụ thể những file nào sẽ thay đổi và thay đổi những gì (tạo mới, chỉnh sửa logic dòng nào...).
4. **Chờ phê duyệt:** Chỉ khi nhà phát triển (developer) đồng ý và cho phép rõ ràng mới được phép chỉnh sửa file code.

## Quy tắc kiểm thử hồi quy khi hoàn thành tính năng (Feature Regression Testing Rule)
Khi hoàn thành một tính năng mới hoặc thay đổi hành vi của tính năng hiện có, agent bắt buộc phải xác minh rằng thay đổi đó không làm hỏng các chức năng đã hoạt động trước đó. Không được xem tính năng là hoàn thành chỉ vì luồng mới hoạt động độc lập.

Bộ test của mỗi tính năng là **bộ kiểm thử tích lũy theo thời gian**. Test được thêm cho lần thay đổi mới phải bổ sung vào bộ test đã có, không thay thế phạm vi kiểm thử cũ. Ví dụ: lần đầu tính năng có các test `1, 2, 3`; lần cập nhật tiếp theo bổ sung test `4`; khi xác minh lần cập nhật đó phải chạy toàn bộ `1, 2, 3, 4`.

Agent phải thực hiện các yêu cầu sau:

1. **Phân tích phạm vi ảnh hưởng:** Xác định các module, API, contract, dữ liệu, màn hình, luồng người dùng và thành phần dùng chung có thể bị tác động trực tiếp hoặc gián tiếp bởi thay đổi.
2. **Duy trì bộ test tích lũy:** Giữ lại và chạy toàn bộ test hợp lệ đã có của tính năng, sau đó bổ sung test cho hành vi mới, nhánh mới, trường hợp biên hoặc lỗi vừa được sửa. Không được chỉ chạy test mới thêm.
3. **Bảo vệ phạm vi kiểm thử cũ:** Không được xóa, bỏ qua, vô hiệu hóa hoặc làm yếu assertion của test cũ chỉ để thay đổi mới pass. Chỉ được sửa hoặc loại bỏ test cũ khi yêu cầu nghiệp vụ tương ứng đã chủ động thay đổi; khi đó phải giải thích lý do và bổ sung test thay thế để bảo toàn phạm vi hành vi còn hiệu lực.
4. **Kiểm thử tính năng mới:** Chạy hoặc bổ sung các kiểm thử phù hợp cho hành vi mới, bao gồm unit, integration, contract, UI hoặc end-to-end test tùy phạm vi.
5. **Chạy kiểm thử hồi quy liên quan:** Ngoài toàn bộ bộ test của tính năng được cập nhật, phải chạy lại test của các khu vực và luồng cũ có liên quan. Khi thay đổi chạm vào code dùng chung, public contract, database, authentication, authorization, offline sync hoặc infrastructure nền tảng, phải mở rộng phạm vi kiểm thử sang các consumer và luồng phụ thuộc tương ứng.
6. **Kiểm tra luồng trọng yếu:** Khi phù hợp với phạm vi thay đổi, ưu tiên xác minh các luồng cốt lõi như đăng nhập, học bài, làm bài và nhận phản hồi, progress/mastery/review, offline/reconnect/sync, content publishing và entitlement. Chỉ kiểm tra những luồng có khả năng bị ảnh hưởng; không chạy kiểm thử không liên quan chỉ để đủ hình thức.
7. **Xử lý khi phát hiện regression:** Nếu test cũ bị lỗi, phải xác định liệu lỗi do thay đổi mới, yêu cầu nghiệp vụ đã thay đổi hay môi trường kiểm thử. Sau khi xử lý, phải chạy lại toàn bộ bộ test tích lũy của tính năng và phạm vi hồi quy liên quan, không chỉ chạy lại test từng bị lỗi.
8. **Không xác nhận sai trạng thái:** Không được báo “hoàn thành”, “không ảnh hưởng tính năng cũ” hoặc “tất cả test đã pass” nếu chưa có bằng chứng kiểm thử tương ứng.
9. **Khi không thể chạy test:** Phải nêu rõ test hoặc luồng nào chưa thể chạy, nguyên nhân, mức rủi ro còn lại và lệnh hoặc cách kiểm tra mà developer cần thực hiện. Phần chưa kiểm thử không được coi là đã pass.
10. **Báo cáo kết quả:** Trong phần tổng kết, phải liệt kê các lệnh đã chạy, bộ test tích lũy đã chạy, phạm vi tính năng cũ đã kiểm tra, kết quả pass/fail và mọi khu vực còn chưa được xác minh.

Quy tắc này áp dụng cho thay đổi mã nguồn, contract, schema, migration, cấu hình runtime hoặc infrastructure có thể làm thay đổi hành vi hệ thống. Thay đổi chỉ liên quan đến văn bản tài liệu không bắt buộc chạy regression test của ứng dụng, nhưng vẫn phải kiểm tra liên kết, cấu trúc và tính nhất quán của tài liệu.

## Quy tắc đặt tiêu đề Báo cáo Đánh giá (Review/Check/Audit Heading Rule)
Khi nhận được các yêu cầu kiểm tra, đánh giá, rà soát (check, review, inspect, audit, evaluate, compare, đánh giá, kiểm tra, xem giúp), phản hồi của agent bắt buộc phải đặt tiêu đề chính ở dòng đầu tiên bằng chữ in hoa có cấu trúc:
**`BÁO CÁO ĐÁNH GIÁ: <TÊN BÁO CÁO BIẾN THỂ>`**
(Ví dụ: `BÁO CÁO ĐÁNH GIÁ: CÁC LỖ HỔNG BẢO MẬT VỀ XÁC THỰC JWT, LƯU TRỮ TOKEN VÀ CẤU HÌNH THÔNG TIN NHẠY CẢM (INSECURE AUTH, STORAGE AND CONFIGURATION)`) ngay phía trên phần `Summary`.

## Quy tắc cung cấp đường dẫn tham khảo (Reference Link Rule)
Bất cứ khi nào Agent đưa ra giải pháp, ý kiến kỹ thuật hoặc thiết kế dựa trên một tài liệu, tiêu chuẩn, hoặc đặc tả chính thống (như Spring Boot, Flutter, PostgreSQL, Docker...), Agent bắt buộc phải cung cấp kèm theo đường dẫn liên kết (clickable URL link) trực tiếp đến tài liệu tham khảo đó. Không được đưa ra nhận định chung chung mà không đính kèm đường link nguồn tham khảo cụ thể.


## Skill Usage Rule
When a task can benefit from a specialized Codex skill, the agent must use the relevant skill before acting.

The agent must:
1. Identify whether any available skill applies to the user's request.
2. Read the relevant `SKILL.md` completely before applying that skill.
3. Prefer the smallest set of skills that directly covers the task.
4. Follow higher-priority instructions first: system, developer, latest user request, repository `AGENTS.md`, module-level `AGENTS.md`, then skill instructions.
5. Use the project-local `.agent/SKILL.md` when working on EsquiloSpeak workflow, review, approval, product scope, sourcing, architecture, or validation rules.
6. If a relevant skill is missing or unreadable, state the missing path clearly and continue with the best available repository and system instructions.
7. Do not claim a skill was used unless its `SKILL.md` was actually read in the current task.

## Quy tắc xưng hô (Communication Pronoun Rule)
Khi giao tiếp với developer trong dự án này bằng tiếng Việt, AI phải xưng là "em" và gọi developer là "anh".

Quy tắc này áp dụng cho mọi phản hồi, cập nhật tiến độ, review, kế hoạch triển khai và tổng kết bằng tiếng Việt, trừ khi anh yêu cầu rõ ràng một cách xưng hô khác.

## Quy trình Git ba tầng (Three-tier Git Workflow)

Repository sử dụng ba tầng nhánh sau:

### Nhánh 1: `main`

- Là nhánh production, luôn phải ở trạng thái ổn định, vượt qua các quality gate bắt buộc và sẵn sàng deploy.
- Tuyệt đối không commit hoặc push trực tiếp vào `main`.
- Mọi thay đổi vào `main` phải đi qua Pull Request, review và các kiểm tra CI bắt buộc.
- Nguồn hợp nhất thông thường vào `main` là `develop`; feature branch không được bỏ qua `develop` để đi thẳng vào `main`.
- Không force-push hoặc viết lại lịch sử của `main`.

### Nhánh 2: `develop`

- Là nhánh tích hợp dài hạn chứa code đang trong quá trình phát triển; tên nhánh thống nhất là `develop`.
- Developer có thể pull và push hằng ngày trên nhánh này. Nhánh này không được dùng để deploy production.
- Trước khi bắt đầu công việc mới, phải đồng bộ `develop` local với `origin/develop`.
- Feature branch sau khi hoàn thành và kiểm tra phù hợp được hợp nhất vào `develop`, rồi mới push trạng thái tích hợp lên `origin/develop`.
- Không force-push hoặc viết lại lịch sử đã chia sẻ của `develop`.
- Trước khi tạo Pull Request từ `develop` vào `main`, phải chạy đầy đủ quality gate liên quan và xử lý mọi regression đã biết.

### Nhánh 3: nhánh công việc ngắn hạn

- Dùng cho từng phạm vi công việc độc lập và được tạo từ `develop` mới nhất.
- Tính năng mới đặt tên `feature/<scope>`, ví dụ `feature/frontend` hoặc `feature/login`.
- Có thể dùng tiền tố cùng quy ước cho loại công việc khác khi cần, chẳng hạn `fix/<scope>`, `docs/<scope>`, `test/<scope>` hoặc `chore/<scope>`.
- Commit và push công việc lên chính nhánh ngắn hạn tương ứng; khi hoàn thành, hợp nhất nhánh đó vào `develop` và push `develop` lên remote.
- Không push hoặc hợp nhất trực tiếp nhánh công việc ngắn hạn vào `main`.
- Sau khi thay đổi đã được tích hợp an toàn và không còn cần thiết, xóa nhánh ngắn hạn ở local và remote.

Luồng mặc định là:

`feature/* | fix/* | docs/* | test/* | chore/*` → `develop` → Pull Request → `main` → deploy production.

## Quy tắc đề xuất nhánh và commit (Branch and Commit Proposal Rule)

Khi developer nói “commit”, “tạo commit” hoặc yêu cầu tương đương, mặc định đây chỉ là yêu cầu **soạn bản đề xuất để developer kiểm tra**, không phải quyền thực thi Git. Agent chỉ được đọc trạng thái/diff và phải trình bày:

1. **Tên feature branch bằng tiếng Anh:** Dùng dạng `feature/<scope>` với `<scope>` viết thường, ngắn gọn và phân tách bằng dấu gạch ngang, ví dụ `feature/learning-contract-baseline`.
2. **Commit title bằng tiếng Anh:** Ưu tiên Conventional Commits theo dạng `<type>(<scope>): <description>`, dùng động từ mệnh lệnh, mô tả đúng thay đổi và không kết thúc bằng dấu chấm; ví dụ `feat(contracts): add first learning slice schemas`.
3. **Commit body chi tiết bằng tiếng Anh:** Ngoài title, phải đề xuất và ghi commit body sau một dòng trống. Body phải mô tả rõ những gì đã thay đổi, lý do thay đổi, tác động đến developer/hệ thống và cách đã kiểm tra; ưu tiên các bullet ngắn, cụ thể. Nội dung này là nguồn đầu vào để tạo phần mô tả Pull Request, không được chỉ lặp lại commit title.
4. **Phạm vi commit:** Tóm tắt các file sẽ được đưa vào commit và cảnh báo nếu có thay đổi không liên quan hoặc nên tách thành nhiều commit.

5. **Nội dung Pull Request dự kiến:** Dùng commit title làm cơ sở cho PR title và phát triển commit body thành PR description gồm tối thiểu: summary, mục đích/lý do, tác động và validation. Nếu PR chứa nhiều commit, phải tổng hợp toàn bộ diff thay vì chỉ sao chép body của commit cuối.

Trong bước đề xuất, agent tuyệt đối không được chạy `git add`, tạo/switch nhánh, `git commit`, push hoặc tạo Pull Request. Sau khi trình bày đề xuất, agent phải chờ một chỉ thị xác nhận thực thi riêng và rõ ràng, ví dụ “đồng ý, hãy add và commit theo đề xuất”. Chỉ khi nhận được xác nhận lần hai này agent mới được thực hiện đúng phạm vi đã duyệt; nếu phạm vi thay đổi sau lúc duyệt, phải trình bày lại phần chênh lệch trước khi thực thi.

Không commit trực tiếp trên `main`. Nếu worktree đang ở `develop`, đề xuất feature branch phù hợp được tạo từ `develop`; chỉ tiếp tục trên `develop` khi developer yêu cầu rõ ràng.

## Quy tắc đồng bộ tài liệu API (API Documentation Synchronization Rule)

- `contracts/openapi/esquilospeak-learning-v1.yaml` là contract có thể đọc bằng máy và là nguồn chuẩn cho API; `docs/reference/API_Check.md` là tài liệu giải thích dễ đọc bắt buộc phải đồng bộ, không thay thế OpenAPI.
- Mỗi khi thêm, xóa, đổi tên hoặc chỉnh sửa API, agent phải cập nhật `docs/reference/API_Check.md` trong cùng yêu cầu. Thay đổi API bao gồm method/path, path/query/header parameter, request/response schema, HTTP status, error contract, authentication, authorization, idempotency, rate limit, privacy boundary, backend mapping và cách mobile/client gọi API.
- Bản cập nhật phải phản ánh cả tác dụng API, nghiệp vụ/luồng sử dụng, consumer hiện tại, yêu cầu xác thực và lưu ý kiểm thử; không chỉ thay đường dẫn trong bảng.
- Trước khi báo hoàn thành, phải tìm và đối chiếu để tránh lệch giữa OpenAPI, backend controller/security, mobile API client và `docs/reference/API_Check.md`.
- Nếu thay đổi ảnh hưởng ma trận kiểm thử tay, phải cập nhật API tương ứng trong `docs/shared/Guide.md`; mọi thay đổi file vẫn phải ghi vào `docs/process/Development_Change_Log.md`.
- Không đưa secret, token, cookie, private key, thông tin đăng nhập, dữ liệu cá nhân hoặc payload thật có nội dung nhạy cảm vào tài liệu API.

## Quy tắc đặt tên tài liệu Markdown (Markdown File Naming Rule)

- File Markdown mới trong các nhóm chức năng dưới `docs/` phải dùng dạng `Pascal_Case_With_Underscores`, ví dụ `Dang_Nhap.md`, `Repository_Structure.md` hoặc `Adr_001_Contract_Baseline.md`, trừ convention đã chốt của ADR và file `README.md`.
- Không đặt toàn bộ tên file bằng chữ in hoa.
- Mỗi từ viết hoa chữ cái đầu và được phân tách bằng dấu gạch dưới; acronym cũng được chuẩn hóa như một từ, ví dụ `Adr`, `Api`, `Sdk`.
- `docs/reference/API_Check.md` là ngoại lệ có chủ đích để giữ đúng tên tài liệu API đã được developer yêu cầu; không dùng ngoại lệ này để tạo thêm tên file viết hoa khác.
- Khi đổi tên file, phải cập nhật toàn bộ link, source-of-truth rule, sơ đồ và tài nguyên tài liệu có nhắc tới tên cũ.
- Sau khi đổi tên, phải tìm kiếm tham chiếu cũ và kiểm tra toàn bộ local Markdown link.

## Quy tắc nhật ký thay đổi (Development Change Log Rule)

Sau mỗi yêu cầu làm phát sinh thao tác tạo mới, chỉnh sửa, di chuyển hoặc xóa file trong workspace, agent bắt buộc phải cập nhật `docs/process/Development_Change_Log.md` trước khi báo hoàn thành.

Mỗi bản ghi phải có tối thiểu:

1. **Ngày:** Là cột ngoài cùng bên trái, dùng định dạng `YYYY-MM-DD`. Các bản ghi cùng ngày phải dùng chung một ô ngày được gộp theo chiều dọc; trong file Markdown, dùng bảng HTML với thuộc tính `rowspan` vì bảng Markdown thuần không hỗ trợ gộp ô.
2. **Thời gian:** Đặt ngay bên phải cột `Ngày`, dùng giờ Việt Nam dạng `HH:mm:ss` theo múi giờ `Asia/Saigon`.
3. **Mục đích:** Phải viết đủ hai phần trong cùng một ô:
   - **Mục đích chung:** Nêu kết quả nghiệp vụ hoặc kỹ thuật mà toàn bộ nhóm thay đổi hướng tới, lý do cần thực hiện và giá trị đạt được; không chỉ lặp lại yêu cầu hoặc tên file.
   - **Tác dụng của file/thay đổi:** Giải thích file được tạo, sửa, di chuyển, xóa hoặc ngừng theo dõi để làm gì và thay đổi đó đóng góp thế nào vào mục đích chung. Khi nhiều file có cùng vai trò, có thể nhóm chúng nhưng phải mô tả rõ vai trò của từng nhóm; không chỉ liệt kê đường dẫn.
4. **File tạo/sửa/xóa:** Liệt kê đường dẫn tương đối từ repository root và ghi rõ hành động `Tạo`, `Sửa`, `Di chuyển`, `Xóa` hoặc `Ngừng theo dõi trên Git`.

Quy tắc thực hiện:

- Một yêu cầu có nhiều file cùng phục vụ một mục đích có thể dùng chung một bản ghi.
- Không dùng các mô tả mục đích chung chung như “cập nhật tài liệu”, “sửa file” hoặc “thực hiện theo yêu cầu” nếu không giải thích kết quả mong muốn và tác dụng của file.
- Phải ghi cả file source code, contract, schema, test, cấu hình, infrastructure, tài liệu và agent rule bị thay đổi.
- Không cần tạo bản ghi cho thao tác chỉ đọc, tìm kiếm, chạy test hoặc kiểm tra không làm thay đổi file.
- Không bắt buộc liệt kê chính `docs/process/Development_Change_Log.md` trong cột file thay đổi để tránh nhật ký tự tham chiếu; có thể liệt kê nếu việc sửa cấu trúc/quy tắc của chính nhật ký là mục đích của yêu cầu.
- Không ghi secret, token, cookie, dữ liệu cá nhân hoặc nội dung nhạy cảm vào nhật ký.
- Nếu không xác định được thời gian chính xác của thay đổi cũ, dùng thời gian lập bản ghi và nêu rõ đây là bản ghi hồi tố.
- Trong phần tổng kết cho developer, phải nhắc rằng nhật ký đã được cập nhật và cung cấp đường dẫn đến bản ghi.
