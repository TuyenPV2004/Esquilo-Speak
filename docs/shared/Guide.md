# Hướng dẫn chạy và kiểm thử EsquiloSpeak — Giai đoạn 12

## 1. Trạng thái hiện tại

Anh **có thể chạy và kiểm thử ứng dụng ngay** trong phạm vi **local/closed
testing** đã thống nhất cho Giai đoạn 12.

Phạm vi đã sẵn sàng gồm hành trình học P0 và các nghiệp vụ Android advanced
learning P1: nghe và tải media, phát âm, phản hồi bài viết/hội thoại, xếp trình
độ nội bộ theo khóa học, streak/XP/thành tích/lời nhắc, entitlement Premium giả lập, hỗ
trợ và báo cáo nội dung.

Đây chưa phải bản production. Các hạng mục sau thuộc Giai đoạn 13 hoặc release
gate:

- Google Play Billing thật và luồng thanh toán trên Play Store.
- Nhà cung cấp media, STT và AI production; môi trường local đang dùng provider
  xác định trước để kết quả kiểm thử ổn định.
- External OIDC trên staging/production, HTTPS production, app signing và
  kiểm tra chính sách store.
- Device matrix, benchmark và release evidence production đầy đủ.
- Bài xếp trình độ chỉ phục vụ định hướng học nội bộ; framework/level lấy từ
  khóa học đang chọn và kết quả hoàn thành
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

Khi mở app trực tiếp từ icon trên emulator, PowerShell chưa tự kết nối với app.
Vì vậy, để xem đầy đủ log và Network, nên chạy app từ PowerShell hoặc dùng
`flutter attach`.

#### Cách dễ nhất cho mỗi lần kiểm thử

Tại thư mục mobile:

```powershell
Set-Location "D:\Project\EsquiloSpeak App\apps\mobile"
flutter devices
flutter run -d emulator-5554 --flavor local --dart-define=ESQUILO_ENV=local
```

Thay `emulator-5554` bằng ID thật hiển thị trong `flutter devices`.

- Lần chạy đầu tiên: chạy `flutter pub get` trước `flutter run`.
- Những lần sau: thường chỉ cần chạy lại `flutter run`.
- Giữ cửa sổ PowerShell này mở để xem log Flutter và lỗi của app.
- Khi muốn dừng app, nhấn `Ctrl+C`.

#### Khi app đã mở từ icon

Nếu app đang chạy sẵn trên emulator, có thể kết nối PowerShell với app bằng:

```powershell
Set-Location "D:\Project\EsquiloSpeak App\apps\mobile"
flutter attach -d emulator-5554
```

Nếu `flutter attach` không tìm thấy app, hãy dùng lại `flutter run`. Nhấn `d` để
ngắt kết nối PowerShell mà không đóng app.

#### Xem Network

Sau khi `flutter run` hoặc `flutter attach` thành công:

1. Tìm dòng có URL `Flutter DevTools` trong PowerShell.
2. Mở URL đó bằng trình duyệt.
3. Chọn tab `Network`.
4. Thao tác trên app để xem request mới.

Tab `Network` chỉ hiển thị request phát sinh sau khi DevTools đã kết nối. Đồng
thời quan sát Cửa sổ 2 — Backend để xem request được server xử lý.

Backend thường hiển thị log dạng:

```text
request_completed httpMethod=GET httpStatus=200 durationMs=...
```

- `2xx`: thành công.
- `4xx`: request hoặc thông tin xác thực không hợp lệ.
- `5xx`: backend gặp lỗi.
- `durationMs`: thời gian backend xử lý request.

#### Chỉ xem log, không cần mở DevTools

Xem log Flutter:

```powershell
flutter logs -d emulator-5554
```

Xem log Android của riêng ứng dụng:

```powershell
$appPid = (adb shell pidof com.esquilospeak.mobile.local).Trim()
adb logcat --pid=$appPid
```

Nếu app khởi động lại, hãy chạy lại hai lệnh `adb` vì process ID đã thay đổi.

#### Cách hiểu luồng hoạt động

```text
Nhấn nút trên app → app gọi API → backend xử lý → app nhận kết quả → màn hình cập nhật
```

Nếu thao tác chỉ chuyển màn hình hoặc thay đổi dữ liệu cục bộ, có thể không có
Network hoặc backend log. Khi gửi báo lỗi, không đưa access token, password, dữ
liệu cá nhân, nội dung bài viết hoặc dữ liệu giọng nói vào log.

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
và ảnh chụp nếu có lỗi. Cột **API tương ứng** ghi request chính cần quan sát trong
DevTools Network hoặc cửa sổ backend. `Không gọi API` nghĩa là thao tác được xử
lý cục bộ trên app hoặc Android. Danh sách endpoint được đối chiếu với
[`esquilospeak-learning-v1.yaml`](../../contracts/openapi/esquilospeak-learning-v1.yaml)
và request thực tế của mobile app.

### A. Khởi tạo và onboarding

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| A01 | Mở app lần đầu khi backend đang hoạt động. | App lấy được guest session và hiển thị Welcome/Onboarding, không lộ token hoặc lỗi kỹ thuật. | `POST /internal/dev/token`<br>`GET /api/mobile/v1/me/profile`<br>`GET /api/mobile/v1/me/consents`<br>Preload: `GET /api/mobile/v1/languages`, `GET /api/mobile/v1/mastery`, `GET /api/mobile/v1/reviews`, `GET /api/mobile/v1/engagement`; placement chỉ tải sau khi chọn course |
| A02 | Chọn ngôn ngữ nguồn, ngôn ngữ đích, khóa học khả dụng và người dùng trưởng thành; hoàn tất các lựa chọn onboarding. | Vào được Home; locale, cặp ngôn ngữ, active course, mục tiêu và thông báo được giữ đúng. Không thể chọn source trùng target hoặc course sai cặp. | `GET /api/mobile/v1/languages`<br>`GET /api/mobile/v1/courses?sourceLanguage=...&targetLanguage=...`<br>`PUT /api/mobile/v1/me/profile` |
| A03 | Đóng rồi mở lại app. | App tiếp tục cùng guest session và không bắt onboarding lại ngoài ý muốn. | Các API `GET` khởi động: `/api/mobile/v1/me/profile`, `/api/mobile/v1/me/consents`, `/api/mobile/v1/languages`, `/api/mobile/v1/mastery`, `/api/mobile/v1/reviews`, `/api/mobile/v1/engagement`; placement dùng `GET /api/mobile/v1/assessments/placement?courseId={courseId}` khi có course đang chọn<br>`POST /internal/dev/token` chỉ khi thiếu hoặc hết hạn token |

### B. Hành trình học cốt lõi

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| B01 | Tại Home, kiểm tra card đề xuất và lý do đề xuất. | Có hành động học tiếp theo, lý do dễ hiểu và CTA hoạt động. | `GET /api/mobile/v1/mastery`<br>`GET /api/mobile/v1/reviews?limit=20` |
| B01a | Từ Home bấm CTA daily session một lần. | Vào bài tiếp theo hoặc quick practice trong tổng cộng không quá hai thao tác kể từ khi mở app; Home chỉ có một primary CTA và hiển thị recommendation source. | `GET /api/mobile/v1/engagement`<br>`POST /api/mobile/v1/engagement/activities` với `daily_session_started` |
| B01b | Hoàn tất daily session rồi quay lại Home. | Summary hiển thị outcome, số lỗi và bước tiếp theo; lifecycle completion được ghi nhưng không tự cộng XP/streak. Khi mọi lesson đã hoàn tất vẫn mở được quick practice 3–5 phút. | `POST /api/mobile/v1/engagement/activities` với `daily_session_completed`; nếu là lesson mới, gửi thêm `lesson_completed` cùng completion evidence canonical |
| B02 | Vào `Học` từ hồ sơ đã có active course rồi mở bài đầu tiên. | App dùng source/target/active course trong learner profile, tải đúng danh sách bài mà không fallback về Việt–Anh. | `GET /api/mobile/v1/languages`<br>`GET /api/mobile/v1/courses?sourceLanguage=...&targetLanguage=...`<br>`GET /api/mobile/v1/courses/{courseId}/lessons`<br>`GET /api/mobile/v1/lessons/{lessonId}` |
| B03 | Chọn đáp án `Hello`, gửi câu trả lời. | Có phản hồi đúng/sai rõ ràng; không gửi lặp khi nhấn nhanh. | `POST /api/mobile/v1/sync/push` với mutation `attempt.submit`<br>`GET /api/mobile/v1/sync/pull` |
| B04 | Mở tiến độ sau bài. | Progress/mastery được cập nhật và có nhãn dễ hiểu. | `GET /api/mobile/v1/progress/courses/{courseId}` |

### C. Offline, cache và đồng bộ lại

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| C01 | Khi online, mở nội dung học; sau đó tắt mạng trên thiết bị và mở lại nội dung đã tải. | Nội dung cache còn đọc được, app không crash. | Khi online: `GET /api/mobile/v1/languages`, `GET /api/mobile/v1/courses`, `GET /api/mobile/v1/courses/{courseId}/lessons`, `GET /api/mobile/v1/lessons/{lessonId}`<br>Khi đọc cache offline: **Không gọi API** |
| C02 | Thực hiện một hành động học được hỗ trợ khi offline. | App hiển thị trạng thái chờ đồng bộ thay vì làm mất thao tác. | Lưu mutation `attempt.submit` cục bộ; `POST /api/mobile/v1/sync/push` chỉ thành công khi có mạng |
| C03 | Bật mạng lại và dùng Retry/refresh nếu được yêu cầu. | Outbox đồng bộ một lần, tiến độ canonical được đối soát, không nhân đôi attempt. | `POST /api/mobile/v1/sync/push`<br>`GET /api/mobile/v1/sync/pull` |
| C04 | Tắt backend trong khi app đang mở rồi thử tải dữ liệu. | Có lỗi thân thiện và hành động thử lại; khởi động backend lại thì phục hồi được. | API đang tải, ví dụ `GET /api/mobile/v1/languages`; request lỗi khi backend tắt và thành công sau Retry |

### D. Review, mastery và cá nhân hóa có giải thích

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| D01 | Mở tab `Ôn tập/Review`. | Hiển thị nội dung đến hạn hoặc trạng thái rỗng phù hợp. | `GET /api/mobile/v1/mastery`<br>`GET /api/mobile/v1/reviews?limit=20` |
| D02 | Mở rộng một mastery item. | Thấy số đúng/tổng, công thức/phương pháp, model version và thời gian evidence. | Dữ liệu từ `GET /api/mobile/v1/mastery`; mở rộng item: **Không gọi API mới** |
| D03 | Quay lại Home sau khi có tiến độ mới. | Card đề xuất ưu tiên review đến hạn/mastery yếu theo dữ liệu hiện có. | `GET /api/mobile/v1/mastery`<br>`GET /api/mobile/v1/reviews?limit=20` |

### E. Hub học tập nâng cao

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| E01 | Từ Home chọn `Học tập nâng cao`. | Hub hiển thị đủ 5 mục: luyện nâng cao, xếp trình độ, engagement, Premium, hỗ trợ. | Điều hướng hub: **Không gọi API** |
| E02 | Mở từng mục rồi quay lại. | Điều hướng đúng, không mất trạng thái hoặc xuất hiện màn hình trắng. | Engagement preload từ `GET /api/mobile/v1/engagement`; màn placement gọi `GET /api/mobile/v1/assessments/placement?courseId={courseId}` theo course đang chọn |

### F. Luyện nghe và media offline

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| F01 | Vào `Nghe, nói và viết`, tại `Luyện nghe` chọn Phát. | Mẫu A1 phát được qua endpoint có xác thực. | `GET /api/mobile/v1/media/{mediaId}` |
| F02 | Chọn `Tải xuống`. | Nút chuyển thành `Đã tải`; tài nguyên được lưu trong vùng riêng của app. | `GET /api/mobile/v1/media/{mediaId}` |
| F03 | Sau khi tải xong, ngắt mạng và phát lại trong cùng phiên. | Media đã tải vẫn phát được; app không yêu cầu URL công khai. | **Không gọi API**; đọc file đã tải trong vùng riêng của app |

### G. Luyện phát âm — thiết bị Android thật

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| G01 | Chọn bắt đầu ghi âm lần đầu. | Có disclosure về retention và Android hỏi quyền microphone. | **Không gọi API**; Android xử lý quyền microphone |
| G02 | Từ chối quyền microphone. | App giải thích quyền chưa được cấp, không crash và không giả vờ đang ghi âm. | **Không gọi API** |
| G03 | Cấp quyền, ghi câu `Hello, my name is Ana.`, rồi dừng/đánh giá. | Nhận được phản hồi phát âm; trạng thái bận/kết quả hiển thị rõ. | `POST /api/mobile/v1/advanced/pronunciation` |
| G04 | Thực hiện lại sau khi đã cấp quyền. | Không hỏi quyền vô lý; file tạm được xử lý theo disclosure và backend không lưu raw voice. | `POST /api/mobile/v1/advanced/pronunciation`; ghi/xóa file tạm là xử lý cục bộ |

### H. Phản hồi bài viết

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| H01 | Nhập `Hello, I am learning English today.` rồi lấy phản hồi. | Có feedback và score/hướng dẫn; UI không bị khóa sau khi hoàn tất. | `POST /api/mobile/v1/advanced/writing` |
| H02 | Để trống hoặc nhập quá ngắn. | Nút gửi bị vô hiệu hóa hoặc app yêu cầu nội dung hợp lệ. | **Không gọi API** do validation trên app |
| H03 | Thử nội dung không an toàn. | App/provider từ chối an toàn, không trả nội dung gây hại và không crash. | `POST /api/mobile/v1/advanced/writing` |

### I. Hội thoại có hướng dẫn

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| I01 | Trả lời lời chào, ví dụ `Hello! I am well, thank you.` | Có phản hồi hội thoại phù hợp với provider local. | `POST /api/mobile/v1/advanced/conversation` |
| I02 | Gửi nội dung trống/quá ngắn. | Không gửi request không hợp lệ; thông báo hoặc trạng thái nút rõ ràng. | **Không gọi API** do validation trên app |

### J. Xếp trình độ nội bộ theo khóa học

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| J01 | Chọn course `vi → en`, rồi mở `Xếp trình độ`. | Có nhãn framework/level từ server (seed hiện tại là CEFR A1) và thông báo rõ đây là đánh giá nội bộ, không phải chứng chỉ. | `GET /api/mobile/v1/assessments/placement?courseId=course-en-for-vi` |
| J02 | Chưa trả lời đủ câu rồi thử gửi. | Không thể hoàn tất hoặc có chỉ dẫn trả lời đủ. | **Không gọi API** do validation trên app |
| J03 | Trả lời toàn bộ bài với các đáp án đúng tương ứng `hello`, `name`, `three`, `goodbye`. | Kết quả đạt 100%, trả đúng framework/version/level và tạo bản ghi hoàn thành không được công nhận. | `POST /api/mobile/v1/assessments/placement/attempts` với `assessmentId` nhận từ J01 |
| J04 | Làm lại với một số đáp án sai. | Score phản ánh câu trả lời và đưa ra hướng ôn tập/thử lại; level không bị app tự gán. | `POST /api/mobile/v1/assessments/placement/attempts` với `assessmentId` nhận từ J01 |

### K. Streak, XP, thành tích và lời nhắc

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| K01 | Mở `Chuỗi ngày và thành tích`. | Hiển thị current streak, XP và danh sách/trạng thái thành tích. | `GET /api/mobile/v1/engagement` |
| K02 | Hoàn thành một lesson hoặc lượt advanced practice có feedback canonical, sau đó ghi nhận hoạt động. Thử gửi lại cùng evidence với `clientEventId` khác. | Lần đầu tăng XP/streak theo policy; lần lặp không tăng XP, streak hoặc achievement. Evidence giả/khác learner bị từ chối `422`. | `POST /api/mobile/v1/engagement/activities` |
| K03 | Bật lời nhắc trên Android 13+. | Android hỏi quyền notification; khi được cấp, trạng thái lời nhắc bật cho 19:30. | Sau khi cấp quyền: `PUT /api/mobile/v1/engagement/notification-preference`<br>`GET /api/mobile/v1/engagement` |
| K04 | Từ chối quyền notification. | Lời nhắc vẫn tắt và app hướng dẫn cấp quyền trong Android Settings. | **Không gọi API** vì app dừng trước bước cập nhật preference |
| K05 | Tắt lời nhắc đã bật. | Trạng thái tắt được lưu và lịch native được hủy. | `PUT /api/mobile/v1/engagement/notification-preference`<br>`GET /api/mobile/v1/engagement` |
| K06 | Chọn thời gian trong quiet hours hiện hành (mặc định policy v1: 21:00–07:00). | App hiển thị denial state, không xin/lập lịch notification; nếu gọi API trực tiếp thì server trả `422 REMINDER_IN_QUIET_HOURS`. | `GET /api/mobile/v1/engagement`<br>`PUT /api/mobile/v1/engagement/notification-preference` |

### L. Premium closed testing

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| L01 | Mở `Premium`, chọn kích hoạt Premium closed-testing. | Entitlement chuyển sang active; không mở Play Store và không phát sinh thanh toán thật. | `POST /api/mobile/v1/commerce/purchases/verify` |
| L02 | Chọn giả lập refund đã xác minh. | Entitlement chuyển sang revoked; quyền Premium không còn active. | `POST /api/mobile/v1/commerce/purchases/refund` |
| L03 | Đóng/mở màn hình Premium. | Trạng thái entitlement đọc lại nhất quán từ backend. | `GET /api/mobile/v1/commerce/entitlements` theo contract; nếu không thấy request khi mở lại thì ghi `Fail` vì mobile hiện chưa có bước tải lại rõ ràng |

### M. Hỗ trợ và báo cáo nội dung

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| M01 | Nhập mô tả hỗ trợ hợp lệ và gửi. | Tạo ticket, hiển thị mã/trạng thái `open` hoặc trạng thái tương đương. | `POST /api/mobile/v1/support/tickets` |
| M02 | Bật báo cáo nội dung và nhập content reference. | Ticket chứa đúng loại content report/reference, không làm mất mô tả. | `POST /api/mobile/v1/support/tickets` với `type=content_report` |
| M03 | Gửi form trống hoặc thiếu trường bắt buộc. | Không gửi request không hợp lệ. | **Không gọi API** do validation trên app |
| M04 | Kiểm tra cảnh báo riêng tư. | Có nhắc không gửi mật khẩu, thanh toán hoặc dữ liệu nhạy cảm. | **Không gọi API** |

### N. Profile và quyền riêng tư

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| N01 | Mở Profile, đổi daily goal giữa phút/lesson/review và chọn target trong range policy. | Loại/target được lưu trong profile; Home hiển thị tiến độ goal độc lập với streak và backend clamp target theo policy. | `GET /api/mobile/v1/engagement`<br>`GET /api/mobile/v1/me/profile`<br>`PUT /api/mobile/v1/me/profile` |
| N02 | Thay telemetry consent tùy chọn. | Lựa chọn được tôn trọng; app vẫn dùng được khi không đồng ý telemetry tùy chọn. | `PUT /api/mobile/v1/me/consents/operational_telemetry`<br>`GET /api/mobile/v1/me/consents` |
| N03 | Gửi yêu cầu export dữ liệu. | Có trạng thái xác nhận, không hiển thị dữ liệu nhạy cảm trên log/UI. | `POST /api/mobile/v1/me/privacy/exports`<br>Kiểm tra trạng thái nếu có: `GET /api/mobile/v1/me/privacy/requests/{requestId}` |
| N04 | Chỉ ở cuối phiên test, kiểm tra xóa tài khoản/profile thử nghiệm. | Có cảnh báo hành động phá hủy và kết quả đúng theo contract; không dùng profile cần giữ lại. | `POST /api/mobile/v1/me/privacy/deletions` |

### O. Ngôn ngữ, giao diện và accessibility

| Mã | Thao tác | Kết quả mong đợi | API tương ứng |
|---|---|---|---|
| O01 | Đổi ngôn ngữ hệ thống giữa Việt/Anh rồi mở lại app. | Nội dung UI dùng đúng locale, không lẫn khóa localization thô. | **Không có API riêng**; khi mở lại app vẫn có các API khởi động như A01 |
| O02 | Kiểm tra light/dark mode. | Text, button, card và trạng thái lỗi có độ tương phản/khả năng đọc tốt. | **Không gọi API** |
| O03 | Đặt font scale Android tới 200%. | Không mất CTA quan trọng, không tràn chữ nghiêm trọng; màn hình cuộn được. | **Không gọi API** |
| O04 | Dùng TalkBack đi qua hành trình chính. | Control có nhãn, thứ tự focus hợp lý và feedback/progress được thông báo. | Không có API riêng; API phụ thuộc hành trình đang thao tác |

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

### Kiểm tra Giai đoạn 6 — Practice modes

1. Từ Home chọn **Chọn chế độ luyện**, lần lượt mở Flashcards, Học thích ứng,
   Practice Test, Match, Lỗi gần đây và Khái niệm yếu.
2. Đổi phạm vi toàn khóa/unit/lesson/concept. Xác nhận màn Learn luôn nêu lý do chọn
   nội dung; Practice Test tôn trọng số câu và loại bài đã chọn.
3. Với Flashcards, dùng nút lật (không vuốt), phát audio nếu nút khả dụng, chọn
   biết/chưa biết và xáo thẻ. Khi mất mạng, audio chưa cache có thể không phát nhưng
   transcript/silent path và thao tác trả lời vẫn dùng được.
4. Trả lời sai một exercise, hoàn tất sync rồi mở **Lỗi gần đây**; exercise phải xuất
   hiện. Trả lời đúng lại, mở phiên mới và xác nhận item không còn được ưu tiên như lỗi
   mới nhất.
5. Ghi lại `completedExerciseCount`, luyện đúng toàn bộ một mode rồi đọc lại
   `GET /progress/courses/{courseId}`: curriculum progress phải không đổi. Đồng thời
   `GET /mastery` phải có thêm evidence và `GET /reviews` tiếp tục phản ánh scheduler.
6. Bật cỡ chữ 200% và TalkBack: mọi mode phải dùng được bằng nút/control native, lỗi và
   summary được đọc, không phụ thuộc màu, tốc độ, swipe hoặc gesture ẩn.

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

- Danh mục API và luồng nghiệp vụ: [`API_Check.md`](../reference/API_Check.md)
- Kế hoạch Phần 1: [`Ke_Hoach_1.md`](../plans/Ke_Hoach_1.md)
- Kế hoạch Phần 2: [`Ke_Hoach_2.md`](../plans/Ke_Hoach_2.md)
- Hướng dẫn mobile: [`apps/mobile/README.md`](../../apps/mobile/README.md)
- Hướng dẫn E2E: [`tests/end-to-end/README.md`](../../tests/end-to-end/README.md)
- Evidence Giai đoạn 12:
  [`tests/end-to-end/evidence/2026-07-31-android-p1-emulator.md`](../../tests/end-to-end/evidence/2026-07-31-android-p1-emulator.md)
- Android MediaRecorder:
  <https://developer.android.com/media/platform/mediarecorder>

## 13. Kiểm tra regression sau khi loại hardcode

1. Tạo guest mới: profile ban đầu không được tự gán `vi`, `en`, A1 hay course.
2. Onboarding: chọn source/target khác nhau và course từ catalog; mở lại app để xác nhận active course được giữ.
3. Attempt mới phải gửi `response: {kind: option, optionId: ...}`; mutation cũ chỉ có `selectedOptionId` vẫn được backend đọc trong giai đoạn chuyển tiếp.
4. Advanced practice phải gọi `GET /courses/{courseId}/advanced-activities`; media, câu phát âm và `contentRef` lấy từ response.
5. Engagement activity chỉ gửi `eventType` và `evidenceRef`; XP do policy server quyết định.
6. Khi bật reminder, app phải hiện time picker và gửi giờ đã chọn cùng IANA timezone của thiết bị, không tự gán 19:30.
7. Trong onboarding và Profile, đổi **Ngôn ngữ giao diện** giữa English/Tiếng
   Việt rồi kiểm tra app đổi text ngay, giữ lựa chọn sau khi khởi động lại và
   không đổi cặp ngôn ngữ học.
8. Kiểm tra giờ nhắc dùng định dạng 12/24 giờ của locale thiết bị; phần trăm và
   số điểm không được ghép thủ công bằng ký tự `%` hoặc `/100`.
9. Placement hiển thị câu hỏi/đáp án theo locale nhưng vẫn chấm đúng stable
   option ID; Review/Engagement không hiển thị raw concept/achievement code khi
   server đã trả presentation metadata.
