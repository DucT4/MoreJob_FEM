# More Job IL mobile

Flutter app cho sinh viên trên Android và iOS. Bản hiện tại có đăng ký/đăng nhập, tìm việc nội bộ, lưu tin, tải CV PDF, ứng tuyển, xem đơn và chỉnh sửa hồ sơ cơ bản.

## Chạy ứng dụng

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

`API_BASE_URL` phải là URL đầy đủ đến `/api/v1`. Nếu không truyền, app dùng `http://10.0.2.2:8080/api/v1` cho Android emulator. Với iOS simulator hoặc thiết bị thật, truyền địa chỉ backend có thể truy cập từ thiết bị; bản phát hành nên dùng HTTPS. Android debug cho phép HTTP để thử local, bản release không bật HTTP thường.

Backend cần phiên bản có các API sinh viên và `GET /api/v1/jobs` cho tìm việc nội bộ. Thay đổi API này nằm trong worktree backend `mobile-api`, xuất phát từ commit `6b0d183`.

## Kiểm tra

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Trên Windows chưa thể biên dịch iOS; cần macOS/Xcode để chạy và kiểm tra bản iOS.
