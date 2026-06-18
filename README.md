# IqroKu

IqroKu adalah aplikasi belajar Iqro untuk anak dan orang tua. Anak bisa belajar halaman Iqro, merekam bacaan, lalu orang tua yang menentukan hasilnya: lancar atau perlu ulang. Fitur pendukung seperti jadwal sholat, Al-Quran, kiblat, doa-doa, dan murottal tetap tersedia untuk pengguna free.

## Struktur Repo

```text
backend/      API Node.js, auth, review orang tua, audio, subscription, admin
iqroku_app/   Aplikasi Flutter
deploy/       Script VPS, Nginx, PM2, PostgreSQL, dan schema database
docs/         Dokumentasi arsitektur, flow, panduan perubahan, production
data/         Data lokal/prototype
```

## Mulai Local

Backend:

```powershell
cd backend
npm install
npm start
```

Flutter:

```powershell
cd iqroku_app
flutter pub get
flutter run -d chrome
```

API default berjalan di `http://localhost:8787`.

## Dokumentasi Penting

- [Arsitektur](docs/ARCHITECTURE.md) - gambaran frontend, backend, database, dan keamanan.
- [Flow Produk](docs/FLOWS.md) - onboarding, mode anak/orang tua, rekaman, review, premium, dan audio.
- [Panduan Perubahan](docs/CHANGE_GUIDE.md) - file mana yang perlu disentuh saat mengubah fitur.
- [Checklist Production](docs/PRODUCTION_CHECKLIST.md) - daftar kerja sebelum rilis production.
- [Deploy VPS](deploy/README.md) - setup server dan deploy.

## Validasi Umum

Backend:

```powershell
cd backend
npm run check
npm test
```

Flutter:

```powershell
cd iqroku_app
flutter analyze
flutter test
flutter build web
```

## Catatan Produk Saat Ini

- Assessment AI sudah dimatikan. Endpoint lama masih ada hanya untuk memberi response `410 assessment_disabled`.
- Hasil bacaan ditentukan oleh orang tua melalui dashboard parent.
- Free plan bisa mengakses Iqro jilid 1. Jilid 2 sampai 6 bisa dibuka sebagai preview, tetapi halaman dikunci premium.
- Jadwal sholat, kiblat, doa-doa, Al-Quran, dan murottal tetap free. Jika belum subscribe, app menampilkan slot iklan.
- Fondasi subscription sudah ada, tetapi payment gateway dan ads SDK belum disambungkan.
