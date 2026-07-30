# Hướng dẫn chạy và kiểm thử EsquiloSpeak — Giai đoạn 12

## 1. Trạng thái hiện tại

Anh **có thể chạy và kiểm thử ứng dụng ngay** trong phạm vi **local/closed
testing** đã thống nhất cho Giai đoạn 12.

Phạm vi đã sẵn sàng gồm hành trình học P0 và các nghiệp vụ Android advanced
learning P1: nghe và tải media, phát âm, phản hồi bài viết/hội thoại, xếp trình
độ A1 nội bộ, streak/XP/thành tích/lời nhắc, entitlement Premium giả lập, hỗ
trợ và báo cáo nội dung.

Đây chưa phải bản production. Các hạng mục sau thuộc Giai đoạn 13 hoặc release
gate:

- Google Play Billing thật và luồng thanh toán trên Play Store.
- Nhà cung cấp media, STT và AI production; môi trường local đang dùng provider
  xác định trước để kết quả kiểm thử ổn định.
- External OIDC trên staging/production, HTTPS production, app signing và
  kiểm tra chính sách store.
- Device matrix, benchmark và release evidence production đầy đủ.
- Bài xếp trình độ A1 chỉ phục vụ định hướng học nội bộ; kết quả hoàn thành
  **không phải chứng chỉ được công nhận**.

## 2. Yêu cầu môi trường

Kiểm tra máy đã có:

- JDK 21.
- Flutter 3.44.3 và Dart 3.12.2.
- Android Studio, Android SDK và một Android emulator; hoặc thiết bị Android
  thật đã bật Developer options/USB debugging.
- Docker Desktop hoặc Docker Engine có Docker Compose.
- PowerShell chạy tại thư mục gốc của repository.

Có thể kiểm tra nhanh:

```powershell
java -version
flutter --version
flutter doctor
flutter devices
docker version
docker compose version
```

Mọi lệnh dưới đây giả định thư mục gốc là:

```text
D:\Project\EsquiloSpeak App
```

## 3. Cấu hình local lần đầu

Tại thư mục gốc repository:

```powershell
Copy-Item -LiteralPath .env.example -Destination .env
```

Mở `.env`, thay hai password local theo hướng dẫn trong file. Không chia sẻ,
chụp màn hình, đưa vào báo cáo lỗi hoặc commit file `.env`.

Nếu cổng PostgreSQL `5432` đang được ứng dụng khác sử dụng, chọn một cổng host
trống và đặt cùng cổng đó cho `POSTGRES_PORT` và `ESQUILO_DB_URL` trong `.env`.

## 4. Khởi chạy toàn bộ ứng dụng

Nên dùng ba cửa sổ PowerShell riêng.

### Cửa sổ 1 — PostgreSQL

Từ thư mục gốc:

```powershell
docker compose --env-file .env -f infrastructure/local/compose/compose.yml up -d
docker ps
```

Container PostgreSQL phải ở trạng thái `Up`.

### Cửa sổ 2 — Backend

```powershell
Set-Location "D:\Project\EsquiloSpeak App\backend\core-platform"
.\gradlew.bat bootRun
```

Chờ backend khởi động xong. Kiểm tra readiness ở cửa sổ PowerShell khác:

```powershell
Invoke-WebRequest http://localhost:8080/readyz
```

Kết quả mong đợi là HTTP `200`. Liveness có thể kiểm tra tại
`http://localhost:8080/livez`.

### Cửa sổ 3 — Android app

Khởi động Android emulator trước bằng một trong hai cách sau.

#### Cách 1 — Android Studio

1. Mở Android Studio.
2. Tại màn hình chào, chọn `More Actions` → `Virtual Device Manager`; hoặc khi
   đang mở project, chọn `Tools` → `Device Manager`.
3. Nếu chưa có thiết bị ảo, chọn `Create Virtual Device`, chọn một mẫu Pixel và
   system image đã cài. Nên dùng Android API 33 trở lên để kiểm thử quyền thông
   báo trên Android 13+.
4. Nhấn nút chạy hình tam giác bên cạnh thiết bị và chờ đến khi màn hình chính
   Android xuất hiện.

#### Cách 2 — PowerShell

Liệt kê các Android Virtual Device đã tạo:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -list-avds
```

Khởi động một thiết bị bằng đúng tên nhận được từ lệnh trên, ví dụ:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd "Pixel_7_API_35"
```

Thay `Pixel_7_API_35` bằng tên AVD thực tế trên máy. Sau khi emulator đã vào màn
hình chính, xác nhận Flutter nhận diện được thiết bị:

```powershell
adb devices
flutter devices
```

Kết quả phải có một thiết bị ở trạng thái sẵn sàng, thường mang ID dạng
`emulator-5554`. Sau đó chạy ứng dụng:

```powershell
Set-Location "D:\Project\EsquiloSpeak App\apps\mobile"
flutter pub get
flutter devices
flutter run --flavor local --dart-define=ESQUILO_ENV=local
```

Android emulator mặc định truy cập backend của máy host qua
`http://10.0.2.2:8080`.

Nếu app không kết nối được backend, giữ backend đang chạy rồi dùng ADB reverse:

```powershell
adb reverse tcp:8080 tcp:8080
flutter run --flavor local --dart-define=ESQUILO_ENV=local --dart-define=ESQUILO_API_URL=http://127.0.0.1:8080
```

ADB reverse cũng là phương án thuận tiện khi chạy trên thiết bị Android thật
được nối USB.

> Kiểm thử ghi âm phát âm phải dùng thiết bị Android thật. Emulator có thể kiểm
> thử giao diện và nhánh từ chối quyền, nhưng không xác nhận được chất lượng ghi
> âm thực tế của microphone.

### Hướng dẫn xem log, nghiệp vụ và luồng hoạt động

Nên giữ các cửa sổ PostgreSQL, backend và Android app đang chạy, sau đó mở thêm
một cửa sổ PowerShell để theo dõi log. Mỗi nguồn log phản ánh một tầng khác nhau
của luồng xử lý.

#### Log Flutter

Cửa sổ đang chạy `flutter run` hiển thị lỗi Flutter/Dart, exception, stack trace,
trạng thái hot reload và các thông báo được ứng dụng ghi bằng `debugPrint`.

Có thể xem log Flutter trong một cửa sổ riêng:

```powershell
flutter devices
flutter logs -d emulator-5554
```

Thay `emulator-5554` bằng ID thiết bị thực tế từ `flutter devices`.

#### Log Android của riêng ứng dụng

Lấy process ID của bản local rồi chỉ theo dõi log thuộc tiến trình đó:

```powershell
$appPid = (adb shell pidof com.esquilospeak.mobile.local).Trim()
adb logcat --pid=$appPid
```

Nếu ứng dụng khởi động lại, process ID sẽ thay đổi và cần chạy lại hai lệnh trên.
Có thể dùng bộ lọc rộng hơn khi cần tìm crash hoặc lỗi plugin:

```powershell
adb logcat | Select-String "flutter|AndroidRuntime|FATAL EXCEPTION|EsquiloSpeak"
```

#### Log request tại backend

Cửa sổ chạy `.\gradlew.bat bootRun` ghi log cho các thao tác có gọi API. Một bản
ghi hoàn thành request thường có các trường:

```text
request_completed
httpMethod=GET
routeCategory=learner-api
httpStatus=200
durationMs=...
correlationId=...
```

Cách đọc nhanh:

- `httpStatus` thuộc nhóm `2xx`: request thành công.
- `4xx`: request, dữ liệu đầu vào hoặc xác thực không hợp lệ.
- `5xx`: backend gặp lỗi khi xử lý.
- `durationMs`: thời gian backend xử lý request.
- `correlationId`: mã dùng để đối chiếu cùng một request giữa mobile, response
  lỗi và backend.

Một thao tác chỉ chuyển màn hình hoặc cập nhật trạng thái cục bộ có thể không tạo
backend log. Các thao tác tải dữ liệu, gửi câu trả lời, đồng bộ hoặc cập nhật
profile thường tạo request và xuất hiện trong cửa sổ backend.

#### Flutter DevTools

Khi chạy `flutter run`, terminal cung cấp URL Flutter DevTools. Mở URL đó trên
trình duyệt và dùng:

- `Network` để xem request, HTTP status và thời gian.
- `Logging` để xem log Dart.
- `Performance` để tìm frame chậm và theo dõi quá trình render.
- `Widget Inspector` để xem cây widget của màn hình hiện tại.

Luồng nên đối chiếu khi kiểm thử là:

```text
Thao tác trên UI → chuyển màn hình hoặc gọi API → backend xử lý request
→ mobile nhận response → ViewModel cập nhật trạng thái → UI render lại
```

Ứng dụng hiện không ghi log cho mọi `onTap` hoặc `onPressed`, nên một click thuần
cục bộ có thể không xuất hiện trong log. Khi báo lỗi, chỉ đính kèm đoạn log liên
quan và phải loại bỏ access token, password, nội dung cá nhân, nội dung bài viết
hoặc dữ liệu giọng nói.

## 5. Dữ liệu và phiên kiểm thử

- Profile `local` tự tạo guest identity/token phục vụ kiểm thử; không cần tài
  khoản production.
- Dữ liệu PostgreSQL vẫn còn sau khi dừng container thông thường.
- Gỡ ứng dụng hoặc xóa dữ liệu app sẽ xóa guest session và dữ liệu local trên
  thiết bị. Chỉ làm việc này khi anh chủ động muốn bắt đầu một phiên sạch.
- Không dùng dữ liệu cá nhân thật, mật khẩu thật hoặc thông tin thanh toán thật
  trong các form closed testing.

## 6. Danh sách nghiệp vụ cần kiểm thử

Ghi `Pass`, `Fail` hoặc `Blocked` cho từng mã kiểm thử, kèm thiết bị/API level
và ảnh chụp nếu có lỗi.

### A. Khởi tạo và onboarding

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| A01 | Mở app lần đầu khi backend đang hoạt động. | App lấy được guest session và hiển thị Welcome/Onboarding, không lộ token hoặc lỗi kỹ thuật. |
| A02 | Chọn người dùng trưởng thành, hoàn tất các lựa chọn onboarding. | Vào được Home; lựa chọn mục tiêu/ngôn ngữ/thông báo được giữ đúng. |
| A03 | Đóng rồi mở lại app. | App tiếp tục cùng guest session và không bắt onboarding lại ngoài ý muốn. |

### B. Hành trình học cốt lõi

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| B01 | Tại Home, kiểm tra card đề xuất và lý do đề xuất. | Có hành động học tiếp theo, lý do dễ hiểu và CTA hoạt động. |
| B02 | Vào `Học` → English → Essential English → Basic Greetings. | Danh sách ngôn ngữ, khóa học và bài học tải thành công. |
| B03 | Chọn đáp án `Hello`, gửi câu trả lời. | Có phản hồi đúng/sai rõ ràng; không gửi lặp khi nhấn nhanh. |
| B04 | Mở tiến độ sau bài. | Progress/mastery được cập nhật và có nhãn dễ hiểu. |

### C. Offline, cache và đồng bộ lại

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| C01 | Khi online, mở nội dung học; sau đó tắt mạng trên thiết bị và mở lại nội dung đã tải. | Nội dung cache còn đọc được, app không crash. |
| C02 | Thực hiện một hành động học được hỗ trợ khi offline. | App hiển thị trạng thái chờ đồng bộ thay vì làm mất thao tác. |
| C03 | Bật mạng lại và dùng Retry/refresh nếu được yêu cầu. | Outbox đồng bộ một lần, tiến độ canonical được đối soát, không nhân đôi attempt. |
| C04 | Tắt backend trong khi app đang mở rồi thử tải dữ liệu. | Có lỗi thân thiện và hành động thử lại; khởi động backend lại thì phục hồi được. |

### D. Review, mastery và cá nhân hóa có giải thích

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| D01 | Mở tab `Ôn tập/Review`. | Hiển thị nội dung đến hạn hoặc trạng thái rỗng phù hợp. |
| D02 | Mở rộng một mastery item. | Thấy số đúng/tổng, công thức/phương pháp, model version và thời gian evidence. |
| D03 | Quay lại Home sau khi có tiến độ mới. | Card đề xuất ưu tiên review đến hạn/mastery yếu theo dữ liệu hiện có. |

### E. Hub học tập nâng cao

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| E01 | Từ Home chọn `Học tập nâng cao`. | Hub hiển thị đủ 5 mục: luyện nâng cao, xếp trình độ, engagement, Premium, hỗ trợ. |
| E02 | Mở từng mục rồi quay lại. | Điều hướng đúng, không mất trạng thái hoặc xuất hiện màn hình trắng. |

### F. Luyện nghe và media offline

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| F01 | Vào `Nghe, nói và viết`, tại `Luyện nghe` chọn Phát. | Mẫu A1 phát được qua endpoint có xác thực. |
| F02 | Chọn `Tải xuống`. | Nút chuyển thành `Đã tải`; tài nguyên được lưu trong vùng riêng của app. |
| F03 | Sau khi tải xong, ngắt mạng và phát lại trong cùng phiên. | Media đã tải vẫn phát được; app không yêu cầu URL công khai. |

### G. Luyện phát âm — thiết bị Android thật

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| G01 | Chọn bắt đầu ghi âm lần đầu. | Có disclosure về retention và Android hỏi quyền microphone. |
| G02 | Từ chối quyền microphone. | App giải thích quyền chưa được cấp, không crash và không giả vờ đang ghi âm. |
| G03 | Cấp quyền, ghi câu `Hello, my name is Ana.`, rồi dừng/đánh giá. | Nhận được phản hồi phát âm; trạng thái bận/kết quả hiển thị rõ. |
| G04 | Thực hiện lại sau khi đã cấp quyền. | Không hỏi quyền vô lý; file tạm được xử lý theo disclosure và backend không lưu raw voice. |

### H. Phản hồi bài viết

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| H01 | Nhập `Hello, I am learning English today.` rồi lấy phản hồi. | Có feedback và score/hướng dẫn; UI không bị khóa sau khi hoàn tất. |
| H02 | Để trống hoặc nhập quá ngắn. | Nút gửi bị vô hiệu hóa hoặc app yêu cầu nội dung hợp lệ. |
| H03 | Thử nội dung không an toàn. | App/provider từ chối an toàn, không trả nội dung gây hại và không crash. |

### I. Hội thoại có hướng dẫn

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| I01 | Trả lời lời chào, ví dụ `Hello! I am well, thank you.` | Có phản hồi hội thoại phù hợp với provider local. |
| I02 | Gửi nội dung trống/quá ngắn. | Không gửi request không hợp lệ; thông báo hoặc trạng thái nút rõ ràng. |

### J. Xếp trình độ A1 nội bộ

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| J01 | Mở `Xếp trình độ A1`. | Có thông báo rõ đây là đánh giá nội bộ, không phải chứng chỉ. |
| J02 | Chưa trả lời đủ câu rồi thử gửi. | Không thể hoàn tất hoặc có chỉ dẫn trả lời đủ. |
| J03 | Trả lời toàn bộ bài với các đáp án đúng tương ứng `hello`, `name`, `three`, `goodbye`. | Kết quả đạt 100% và tạo bản ghi hoàn thành A1 không được công nhận. |
| J04 | Làm lại với một số đáp án sai. | Score phản ánh câu trả lời và đưa ra hướng ôn tập/thử lại. |

### K. Streak, XP, thành tích và lời nhắc

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| K01 | Mở `Chuỗi ngày và thành tích`. | Hiển thị current streak, XP và danh sách/trạng thái thành tích. |
| K02 | Chọn `Hoàn thành một lượt luyện tập (+15 XP)`. | XP tăng đúng 15; thành tích đầu tiên xuất hiện khi đủ điều kiện. |
| K03 | Bật lời nhắc trên Android 13+. | Android hỏi quyền notification; khi được cấp, trạng thái lời nhắc bật cho 19:30. |
| K04 | Từ chối quyền notification. | Lời nhắc vẫn tắt và app hướng dẫn cấp quyền trong Android Settings. |
| K05 | Tắt lời nhắc đã bật. | Trạng thái tắt được lưu và lịch native được hủy. |

### L. Premium closed testing

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| L01 | Mở `Premium`, chọn kích hoạt Premium closed-testing. | Entitlement chuyển sang active; không mở Play Store và không phát sinh thanh toán thật. |
| L02 | Chọn giả lập refund đã xác minh. | Entitlement chuyển sang revoked; quyền Premium không còn active. |
| L03 | Đóng/mở màn hình Premium. | Trạng thái entitlement đọc lại nhất quán từ backend. |

### M. Hỗ trợ và báo cáo nội dung

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| M01 | Nhập mô tả hỗ trợ hợp lệ và gửi. | Tạo ticket, hiển thị mã/trạng thái `open` hoặc trạng thái tương đương. |
| M02 | Bật báo cáo nội dung và nhập content reference. | Ticket chứa đúng loại content report/reference, không làm mất mô tả. |
| M03 | Gửi form trống hoặc thiếu trường bắt buộc. | Không gửi request không hợp lệ. |
| M04 | Kiểm tra cảnh báo riêng tư. | Có nhắc không gửi mật khẩu, thanh toán hoặc dữ liệu nhạy cảm. |

### N. Profile và quyền riêng tư

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| N01 | Mở Profile, thay daily goal/notification preference nếu có. | Giá trị được lưu và đọc lại nhất quán. |
| N02 | Thay telemetry consent tùy chọn. | Lựa chọn được tôn trọng; app vẫn dùng được khi không đồng ý telemetry tùy chọn. |
| N03 | Gửi yêu cầu export dữ liệu. | Có trạng thái xác nhận, không hiển thị dữ liệu nhạy cảm trên log/UI. |
| N04 | Chỉ ở cuối phiên test, kiểm tra xóa tài khoản/profile thử nghiệm. | Có cảnh báo hành động phá hủy và kết quả đúng theo contract; không dùng profile cần giữ lại. |

### O. Ngôn ngữ, giao diện và accessibility

| Mã | Thao tác | Kết quả mong đợi |
|---|---|---|
| O01 | Đổi ngôn ngữ hệ thống giữa Việt/Anh rồi mở lại app. | Nội dung UI dùng đúng locale, không lẫn khóa localization thô. |
| O02 | Kiểm tra light/dark mode. | Text, button, card và trạng thái lỗi có độ tương phản/khả năng đọc tốt. |
| O03 | Đặt font scale Android tới 200%. | Không mất CTA quan trọng, không tràn chữ nghiêm trọng; màn hình cuộn được. |
| O04 | Dùng TalkBack đi qua hành trình chính. | Control có nhãn, thứ tự focus hợp lý và feedback/progress được thông báo. |

## 7. Thứ tự kiểm thử khuyến nghị

### Smoke test nhanh — khoảng 10–15 phút

Chạy A01–A03, B01–B04, E01, F01–F02, H01, J01–J03, L01–L02 và
M01. Nếu một bước smoke fail, ghi nhận lỗi trước khi kiểm thử sâu.

### Functional pass — khoảng 30–45 phút

Chạy toàn bộ A–O trên emulator. Sau đó chạy riêng G01–G04 và K03–K05 trên
thiết bị Android thật.

### Regression tự động

Backend:

```powershell
Set-Location "D:\Project\EsquiloSpeak App\backend\core-platform"
.\gradlew.bat test bootJar
```

Mobile:

```powershell
Set-Location "D:\Project\EsquiloSpeak App\apps\mobile"
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --flavor local --dart-define=ESQUILO_ENV=local
```

E2E trên emulator đang chạy và backend local:

```powershell
adb reverse tcp:8080 tcp:8080
Set-Location "D:\Project\EsquiloSpeak App\apps\mobile"
flutter test integration_test/learning_flow_integration_test.dart --flavor local --dart-define=ESQUILO_ENV=local --dart-define=ESQUILO_API_URL=http://127.0.0.1:8080 -d emulator-5554
```

Nếu thiết bị của anh không có ID `emulator-5554`, lấy ID đúng từ
`flutter devices` và thay phần cuối lệnh.

## 8. Các giới hạn không nên ghi là lỗi Giai đoạn 12

- Premium local không hiển thị Google Play purchase sheet và không thu tiền.
- Feedback phát âm/bài viết/hội thoại local có tính xác định trước, chưa đại
  diện chất lượng provider AI/STT production.
- Placement chỉ tạo non-accredited completion.
- Emulator không phải bằng chứng đủ cho microphone thật.
- Backend local dùng HTTP cleartext; staging/production phải dùng HTTPS.
- Chưa có external OIDC, production signing/store rollout và device matrix của
  Giai đoạn 13.

## 9. Xử lý lỗi thường gặp

### `readyz` không trả HTTP 200

1. Kiểm tra Docker Desktop đang chạy.
2. Chạy `docker ps` và xem PostgreSQL có ở trạng thái `Up`.
3. Xem cửa sổ backend để tìm lỗi kết nối database hoặc cổng `8080` bị chiếm.
4. Kiểm tra cổng trong `POSTGRES_PORT` và `ESQUILO_DB_URL` khớp nhau, nhưng
   không đưa nội dung `.env` vào báo cáo công khai.

### App báo lỗi mạng dù backend đã chạy

1. Mở `http://localhost:8080/readyz` trên máy phát triển.
2. Chạy `adb devices`.
3. Chạy `adb reverse tcp:8080 tcp:8080`.
4. Chạy lại app với
   `--dart-define=ESQUILO_API_URL=http://127.0.0.1:8080`.

### Không thấy emulator/thiết bị

Chạy `flutter doctor -v`, `flutter devices` và `adb devices`. Với thiết bị thật,
xác nhận hộp thoại cho phép USB debugging trên điện thoại.

### Muốn tạo lại guest session sạch

Lệnh sau xóa dữ liệu ứng dụng local trên thiết bị, vì vậy chỉ dùng khi không cần
giữ tiến độ test:

```powershell
adb uninstall com.esquilospeak.mobile.local
```

Sau đó chạy lại `flutter run`. Không xóa Docker volume nếu chỉ cần tạo guest
session mới.

## 10. Dừng môi trường

Nhấn `Ctrl+C` tại cửa sổ Flutter và backend. Sau đó, từ thư mục gốc:

```powershell
docker compose --env-file .env -f infrastructure/local/compose/compose.yml down
adb reverse --remove tcp:8080
```

Lệnh `down` giữ lại volume dữ liệu. Không thêm `-v` nếu anh còn cần dữ liệu
kiểm thử.

## 11. Mẫu báo lỗi

```text
Mã test:
Ngày giờ:
Thiết bị / Android API:
Flutter flavor: local
Trạng thái backend /readyz:
Điều kiện mạng: online / offline / vừa kết nối lại

Các bước tái hiện:
1.
2.
3.

Kết quả mong đợi:
Kết quả thực tế:
Tần suất: luôn xảy ra / thỉnh thoảng / một lần
Ảnh hoặc video:
Log liên quan đã loại bỏ token, password và dữ liệu nhạy cảm:
```

## 12. Tài liệu liên quan

- Kế hoạch: [`docs/Ke_Hoach.md`](docs/Ke_Hoach.md)
- Hướng dẫn mobile: [`apps/mobile/README.md`](apps/mobile/README.md)
- Hướng dẫn E2E: [`tests/end-to-end/README.md`](tests/end-to-end/README.md)
- Evidence Giai đoạn 12:
  [`tests/end-to-end/evidence/2026-07-31-android-p1-emulator.md`](tests/end-to-end/evidence/2026-07-31-android-p1-emulator.md)
- Android MediaRecorder:
  <https://developer.android.com/media/platform/mediarecorder>
