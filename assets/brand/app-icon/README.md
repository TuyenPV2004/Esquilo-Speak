# EsquiloSpeak app icon

## Ý tưởng đã chọn

Icon sử dụng phương án **AQ**:

- Sóc nhìn ngang là dấu hiệu nhận diện chính của `Esquilo`.
- Đuôi lớn bao quanh nhân vật gợi khả năng ghi nhớ và tích lũy kiến thức.
- Quyển sách mở cùng hai tay đang giữ sách thể hiện trực tiếp việc học và đọc.
- Hình khối tối giản, không dùng chữ hoặc biểu tượng âm thanh rời, để vẫn rõ ở kích thước launcher nhỏ.

## Bảng màu

| Token | Màu | Vai trò |
| --- | --- | --- |
| Deep teal | `#024F62` | Nền chính, tạo cảm giác tin cậy và tập trung |
| Warm cream | `#FCEEDC` | Sóc, tay và đường nét quyển sách |

Các khoảng teal bên trong mắt, thân và sách là negative space, giúp icon nhẹ và dễ đọc hơn.

## Tệp nguồn và đầu ra

- `esquilospeak-app-icon-master.svg`: artboard 1024 x 1024 tham chiếu bản AQ đã duyệt.
- `app-icon-1024.png`: bản raster 1024 x 1024 để review và xuất thêm kích thước.
- `play-store-icon-512.png`: icon Google Play 512 x 512, PNG RGBA, nền phủ kín hình vuông.
- `adaptive-icon-background.svg`: nền Android Adaptive Icon, artboard 108 x 108 dp.
- `adaptive-icon-foreground.png`: foreground RGBA 432 x 432 px; artwork được thu vào safe zone.
- `adaptive-icon-foreground.svg`: artboard 108 x 108 dp tham chiếu foreground PNG.
- `adaptive-icon-monochrome.png`: lớp monochrome RGBA 432 x 432 px cho themed icon.
- `adaptive-icon-monochrome.svg`: artboard 108 x 108 dp tham chiếu lớp monochrome.
- `launcher-size-preview.png`: kiểm tra icon ở 24, 32, 48, 64, 96 và 128 px.
- `android-mask-preview.png`: kiểm tra dưới mask tròn, squircle và rounded-square.

## Quy tắc xuất bản

### Google Play

- Dùng `play-store-icon-512.png` ở kích thước 512 x 512 px.
- Giữ hình vuông phủ nền đầy đủ; không tự bo góc và không thêm bóng ngoài.
- Không thêm tên app, chữ quảng cáo, huy hiệu, giá hoặc xếp hạng vào icon.

### Android launcher

- Dùng Adaptive Icon gồm `background`, `foreground` và `monochrome`.
- Mỗi lớp có artboard 108 x 108 dp; phần nhận diện chính nằm trong vùng an toàn giữa 66 x 66 dp.
- Khi dự án Flutter được scaffold, chuyển các nguồn này thành Android resources bằng Android Studio Image Asset hoặc pipeline icon được dự án chọn.
- Không dùng trực tiếp PNG Google Play làm launcher icon.

## Kiểm tra trước khi phát hành

1. Nhìn ra sóc nhìn ngang và quyển sách ở 48 px.
2. Hai tay vẫn đọc được như đang giữ sách, không hòa lẫn với trang sách.
3. Không có chi tiết quan trọng bị cắt dưới mask tròn, squircle hoặc rounded-square.
4. So sánh icon trong một hàng ứng dụng thật trên nền sáng và tối.
5. Kiểm tra định tính với người dùng: app gợi liên tưởng tới học tập/đọc và chi tiết nào được nhớ sau 10 giây.
