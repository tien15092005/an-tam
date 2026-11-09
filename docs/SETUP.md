# Cài đặt môi trường

Tài liệu này sẽ được hoàn thiện ở Giai đoạn 0, sau khi các bước đã chạy thử thật trên máy.

## Công cụ cần có

| Công cụ | Dùng cho |
|---|---|
| Android Studio + Android SDK + máy ảo có Google Play | Chạy và debug app |
| Flutter SDK + plugin Flutter trong Android Studio | Viết app |
| JDK bản LTS | Backend Spring Boot |
| Docker Desktop | PostgreSQL, chạy cả hệ thống |
| Python 3 | Dịch vụ AI |
| Git | Quản lý code |

Kiểm tra Flutter bằng `flutter doctor`.

## Cài Flutter, JDK, Docker trên Windows

```bash
git clone -b stable https://github.com/flutter/flutter.git C:\dev\flutter
```

Thêm `C:\dev\flutter\bin` vào biến `Path` của tài khoản, mở lại terminal, rồi chạy `flutter doctor --android-licenses` để tự đọc và đồng ý giấy phép SDK.

```bash
winget install --id EclipseAdoptium.Temurin.25.JDK -e
```

```bash
winget install --id Docker.DockerDesktop -e
```

Docker Desktop cần WSL2. Mở PowerShell bằng **Run as administrator**, chạy lệnh sau, rồi khởi động lại máy:

```bash
wsl --install
```

Mở Docker Desktop, tự đọc và đồng ý điều khoản, chờ đến khi hiện **Engine running**.

## Chạy cả hệ thống

```bash
copy .env.example .env
```

Đặt một mật khẩu cho `DB_PASSWORD` trong `.env`, rồi chạy:

```bash
docker compose up --build
```

Kiểm tra: mở <http://localhost:8080/actuator/health>, phải thấy `{"status":"UP"}`.

Kiểm tra thêm backend gọi được AI service: <http://localhost:8080/api/health> phải thấy `"ai":"UP"`. `.env` cần có cả `DB_PASSWORD` và `AI_SERVICE_TOKEN`.

## Mở backend ra Internet (đường hầm HTTPS)

```bash
winget install --id Cloudflare.cloudflared -e
```

```bash
cloudflared tunnel --no-autoupdate --url http://localhost:8080
```

Terminal in ra địa chỉ dạng `https://xxxx.trycloudflare.com`. Mở app → ô **Địa chỉ máy chủ** → dán địa chỉ đó → **Lưu**. Địa chỉ đổi mỗi lần chạy lại lệnh, nên phải nhập lại trong app. Tắt đường hầm khi không dùng.

## Nếu dự án nằm trong OneDrive

OneDrive khóa file trong thư mục build làm `flutter build` lỗi "Unable to delete directory". Đưa thư mục build ra ngoài OneDrive bằng junction (chạy một lần, trong PowerShell):

```bash
New-Item -ItemType Directory -Force C:\dev\antam-build\app; Remove-Item -Recurse -Force app\build -ErrorAction SilentlyContinue; New-Item -ItemType Junction -Path app\build -Target C:\dev\antam-build\app
```

Cách triệt để hơn là để cả dự án ngoài OneDrive, ví dụ `C:\dev\an-tam`.

## Bật đường dẫn dài trên Windows (nên làm)

Một số plugin (ví dụ `image_picker`) tạo file có đường dẫn dài hơn 260 ký tự trong thư mục build. Khi Windows chưa bật "Long Paths", lần build thứ hai sẽ lỗi "Unable to delete directory ... .transforms". Cách sửa gốc: người dùng máy mở PowerShell **bằng quyền Administrator**, chạy lệnh sau rồi khởi động lại máy:

```bash
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
```

Khi chưa bật, build APK bằng script này (tự xóa các thư mục `.transforms` trước khi build):

```bash
powershell -ExecutionPolicy Bypass -File app\tool\build_apk.ps1
```

`app/android/gradle.properties` đã tắt tính năng theo dõi file của Gradle (`org.gradle.vfs.watch=false`), vì trên Windows nó giữ khóa thư mục giữa các lần build.

## Chạy app

```bash
cd app
flutter run
```

## Android Studio

1. Cài Android Studio bản ổn định từ <https://developer.android.com/studio>.
2. Mở Android Studio, chọn kiểu cài **Standard**, đọc và đồng ý các điều khoản SDK, rồi chờ tải xong.
3. Vào **More Actions → Virtual Device Manager → Create Virtual Device**.
4. Chọn **Pixel 8**, chọn bản Android mới nhất có biểu tượng **Google Play**, rồi bấm Finish.
5. Bấm nút ▶ để chạy thử máy ảo.

Cần thêm **Android SDK Command-line Tools**: vào **Settings → Languages & Frameworks → Android SDK → SDK Tools**, tích **Android SDK Command-line Tools (latest)**, bấm Apply và tự đồng ý giấy phép. Sau đó chạy `flutter doctor --android-licenses`.

**Lần đầu mở máy ảo rất chậm.** Trên máy nhóm trưởng (Intel Core Ultra 5 125H, image API 37, emulator 37.2.13), lần khởi động đầu mất khoảng **3–4 phút**, màn hình đen trong lúc đó. Terminal có thể báo `detected a hanging thread 'QEMU2 CPU0 thread'`: đây là cảnh báo tạm thời, không phải treo. Hãy đợi đủ 5 phút trước khi kết luận là lỗi.

Để các lần sau nhanh hơn:

1. Trong **Device Manager**, bấm ✏️ ở máy ảo, mở **Show Advanced Settings**, đặt **RAM** = 4096 MB. Nếu máy ảo vẫn treo hoặc lỗi đồ họa, đổi **Graphics** sang **Software**.
2. Đợi máy ảo khởi động xong hoàn toàn, rồi tắt bằng nút ✕ của cửa sổ máy ảo (không tắt cưỡng bức). Máy ảo lưu trạng thái, lần sau bật lại chỉ mất vài giây.
3. Docker Desktop cũng tốn RAM. Khi chỉ làm app, có thể tắt Docker Desktop cho máy ảo chạy nhanh hơn.

Cách chạy không cửa sổ đã được xác nhận hoạt động (dùng để kiểm tra nhanh bằng dòng lệnh):

```bash
"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_8 -no-window -gpu swiftshader_indirect -no-snapshot
```

Nếu máy ảo báo thiếu tăng tốc phần cứng: mở **Turn Windows features on or off**, bật **Windows Hypervisor Platform**, khởi động lại máy. Nếu vẫn lỗi, bật Intel VT-x hoặc AMD-V trong BIOS.

## Điện thoại Samsung thật

1. Vào **Cài đặt → Thông tin điện thoại → Thông tin phần mềm**, bấm **Số hiệu bản tạo** 7 lần.
2. Vào **Cài đặt → Tùy chọn nhà phát triển**, bật **Gỡ lỗi USB**.
3. Cắm cáp vào máy tính và chọn **Cho phép** trên điện thoại.
4. Ghi đời máy và phiên bản Android vào `docs/DECISIONS.md`.

## Firebase cho thông báo đẩy (nhóm trưởng)

1. Vào <https://console.firebase.google.com>, chọn **Create a project**, đặt tên `an-tam`, **tắt Google Analytics**. Giữ gói miễn phí, không cần thêm thẻ.
2. Thêm app Android với package name `vn.antam.app`, tải file `google-services.json`.
3. Giữ file ở chỗ riêng, không gửi vào chat và không đưa lên Git. Vị trí đặt file sẽ được hướng dẫn khi tạo xong project Flutter.
4. Không cần bật Authentication hay Firestore. Nếu đã tạo rồi thì để đó, không ảnh hưởng.
5. Vào **Project settings → Users and permissions**, thêm email của 2 bạn với vai trò **Editor**.
