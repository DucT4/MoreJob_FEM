# More Job IL mobile

Flutter app cho Android và iOS. Các luồng sinh viên cơ bản được viết bằng Flutter: đăng ký/đăng nhập, tìm việc nội bộ, lưu tin, tải CV PDF, ứng tuyển, xem đơn và chỉnh sửa hồ sơ. Những tính năng web còn lại được mở trong WebView tích hợp để có thể sử dụng ngay trong app.

## Tính năng web trong app

- Công khai: trang chủ, tin tuyển dụng và 9 tiện ích gồm MBTI, DISC, MI, tính lương/thuế/bảo hiểm, kiểm tra lừa đảo và chuyển đổi CV ngân hàng.
- Sinh viên: tìm việc theo CV, CV và mẫu CV, hồ sơ, phỏng vấn AI, gói tìm việc/thanh toán, đơn ứng tuyển, lịch phỏng vấn, tin nhắn, thông báo và lịch rảnh.
- Quản trị: duyệt tin tuyển dụng, quản lý mẫu CV và CV.

Các luồng web cần đăng nhập dùng phiên đăng nhập của trang web trong WebView, tách với phiên Flutter native. Các chức năng doanh nghiệp không có trong danh sách vì router web hiện chuyển các đường dẫn doanh nghiệp về trang chủ.

## Chạy ứng dụng

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1 --dart-define=WEB_BASE_URL=https://morejob-fe.vercel.app
```

`API_BASE_URL` phải là URL đầy đủ đến `/api/v1`. Nếu không truyền, app dùng `http://10.0.2.2:8080/api/v1` cho Android emulator. `WEB_BASE_URL` mặc định là web đang triển khai tại Vercel. Với iOS simulator hoặc thiết bị thật, truyền địa chỉ backend có thể truy cập từ thiết bị; bản phát hành nên dùng HTTPS. Android debug cho phép HTTP để thử local, bản release không bật HTTP thường.

Backend cần phiên bản có các API sinh viên và `GET /api/v1/jobs` cho tìm việc nội bộ. API tìm việc này đã được bổ sung trong `D:/project/more-job/more-job-be`; cần triển khai backend mới trước khi dùng chức năng tìm việc native với server production.

## Kiểm tra

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Trên máy Windows hiện tại, Gradle tải dependency Android bị lỗi chứng chỉ HTTPS của môi trường. Cần sửa trust store Java hoặc dùng môi trường build khác để xác nhận APK. iOS cần macOS/Xcode để chạy và kiểm tra.
