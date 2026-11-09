# Cài đặt môi trường

Các bước dưới đây đã chạy thử trên máy nhóm trưởng (Windows 11). Đọc README trước để có cái nhìn chung.

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

Không bắt buộc: thiếu Firebase thì app vẫn chạy, chỉ là người con nhận tin khi mở app (tab Hôm nay tự làm mới mỗi 30 giây).

1. Vào <https://console.firebase.google.com>, chọn **Create a project**, đặt tên `an-tam`, **tắt Google Analytics**. Giữ gói miễn phí, không cần thêm thẻ. Nhóm trưởng tự đọc và đồng ý điều khoản.
2. **Backend:** Project settings → Service accounts → **Generate new private key**. Lưu file thành `secrets/firebase.json` ở thư mục gốc (thư mục này không lên Git), rồi thêm vào `.env`:

   ```text
   FIREBASE_CREDENTIALS=/secrets/firebase.json
   ```

3. **App:** Project settings → General → **Add app → Android**, package name `vn.antam.app`. Không cần tải `google-services.json`; chỉ chép 4 giá trị (Web API key, App ID, Sender ID, Project ID) rồi build với:

   ```bash
   flutter build apk --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
   ```

4. Giữ các giá trị này ở chỗ riêng, không gửi vào chat và không đưa lên Git. Kiểm tra: `docker compose logs backend | findstr FCM` phải thấy "FCM pushes enabled".
5. Vào **Project settings → Users and permissions**, thêm email của 2 bạn với vai trò **Editor** nếu cần.

## Tài khoản quản trị (admin)

Đặt `ADMIN_EMAIL` và `ADMIN_PASSWORD` (từ 12 ký tự) trong `.env`, rồi `docker compose up -d backend`. Tài khoản được tạo một lần khi backend khởi động; đăng nhập trong app như người con. Admin chỉ thấy số liệu tổng hợp, tìm và khóa tài khoản.

## Dữ liệu demo giả

Khi backend đang chạy:

```bash
python scripts/seed_demo.py
```

Script tạo 2 người con, 1 nhóm, bà Lan với 3 thuốc và 1 lịch tập, rồi in email, mật khẩu và mã ghép máy (hết hạn sau 15 phút). Mọi tên và số liệu đều là giả. Với đường hầm: `python scripts/seed_demo.py https://xxxx.trycloudflare.com`.

## Sao lưu và khôi phục

```bash
powershell -ExecutionPolicy Bypass -File scripts\backup.ps1
```

Tạo `backups/antam-<thời gian>.sql` và `backups/media-<thời gian>.tgz` (giữ 14 bản gần nhất). Thư mục `backups/` chứa dữ liệu gia đình, không đưa lên Git.

Khôi phục (ghi đè dữ liệu hiện tại), chạy trong `cmd`:

```bash
type backups\antam-YYYYMMDD-HHMM.sql | docker compose exec -T db psql -U antam -d antam
```

```bash
type backups\media-YYYYMMDD-HHMM.tgz | docker compose exec -T backend tar -C /data -xzf -
```

## APK phát hành

Nhóm trưởng tạo keystore một lần và giữ riêng (không lên Git):

```bash
keytool -genkey -v -keystore %USERPROFILE%\antam-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias antam
```

Tạo `app/android/key.properties` (không lên Git):

```text
storeFile=C:/Users/<tên>/antam-release.jks
storePassword=...
keyAlias=antam
keyPassword=...
```

Build:

```bash
cd app && flutter build apk --release --dart-define=API_BASE_URL=https://xxxx.trycloudflare.com
```

Bản phát hành chỉ chấp nhận địa chỉ `https://`. Thiếu `key.properties` thì APK được ký bằng khóa debug: chỉ dùng thử, không phát tán.
