# IqroKu Flutter App

Aplikasi Flutter untuk IqroKu: belajar Iqro, rekaman bacaan anak, dashboard orang tua, review bacaan, Al-Quran, Juz Amma, jadwal sholat, kiblat, doa-doa, murottal, profile, dan subscription gate.

## Run

```powershell
cd d:\MotionMind\iqroku\iqroku_app
flutter pub get
flutter run
```

For a quick web preview:

```powershell
flutter run -d chrome
```

For Android debug APK:

```powershell
flutter build apk --debug
```

The debug APK is generated at:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Validate

```powershell
flutter analyze
flutter test
flutter build web
```

## Current Product Rules

- Anak merekam bacaan, orang tua yang menentukan lancar atau perlu ulang.
- Assessment AI sudah tidak dipakai.
- Iqro jilid 1 free.
- Iqro jilid 2 sampai 6 premium, tetap bisa dibuka sebagai preview dengan halaman terkunci.
- Jadwal sholat, kiblat, doa-doa, Al-Quran, dan murottal free.
- User free bisa melihat slot iklan di fitur free.

## Project Structure

```text
lib/
  app/        App shell and shared app state
  core/       Theme, services, reusable widgets
  data/       Local storage and repositories
  features/   Feature screens
  models/     Domain models
```

## Dokumentasi Lanjut

- Arsitektur: `../docs/ARCHITECTURE.md`
- Flow produk: `../docs/FLOWS.md`
- Panduan perubahan: `../docs/CHANGE_GUIDE.md`
- Checklist production: `../docs/PRODUCTION_CHECKLIST.md`
