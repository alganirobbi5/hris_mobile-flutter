# Firebase Cloud Messaging — langkah aktivasi

Kode FCM sudah tersedia di Flutter & backend. Supaya notifikasi muncul saat aplikasi ditutup,
perlu 5 langkah sekali saja:

## 1. Buat project Firebase

1. Buka https://console.firebase.google.com
2. Klik **Add project** / **Create a project**
3. Nama: `hris-dignity` (atau nama lain)
4. Google Analytics: boleh dimatikan
5. Klik **Create project**

## 2. Daftarkan aplikasi Android

1. Di halaman project, klik ikon **Android** (di "Get started by adding Firebase to your app")
2. Android package name: `com.example.hris_mobile`
   (lihat `android/app/build.gradle.kts` → `applicationId`)
3. App nickname: `HRIS Dignity`
4. Klik **Register app**
5. Download `google-services.json`
6. Taruh di:

   D:\Development\Projects\hris_mobile-flutter\android\app\google-services.json

   File ini sudah masuk `.gitignore` — jangan di-commit.

## 3. Service account untuk backend (PHP)

1. Firebase console → **Project settings** (gear) → tab **Service accounts**
2. Klik **Generate new private key** → file JSON terunduh
3. Buka file `src/common/fcm.local.php.example` di repo backend
4. Salin isi JSON tersebut ke `src/common/fcm.local.php` (file baru):

   ```php
   <?php
   return array(
       'project_id' => '...',
       'client_email' => '...',
       'private_key' => "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
   );
   ```

5. File `fcm.local.php` sudah masuk `.gitignore` — jangan di-commit.

## 4. Migrasi database

Jalankan ke database produksi VPS:

```
DB/migrations/20261125_add_fcm_token.sql
```

## 5. Deploy & cek

- Deploy backend (termasuk file yang sudah di-push) ke VPS.
- Build ulang APK Flutter (google-services.json sudah terpasang).
- Login di HP → token FCM otomatis terkirim ke `fcm_token.php`.
- Cek di server: `SELECT id, username, fcm_token IS NOT NULL AS has_token FROM users;`
- Coba: karyawan absen masuk → HR dapat notifikasi walau aplikasi HR ditutup.

## Catatan channel notifikasi

Backend mengirim `channel_id`:
- `attendance_channel` — absen
- `leave_channel` — cuti/izin

Pastikan ID ini sama dengan yang dibuat di `lib/services/notification_service.dart`.
