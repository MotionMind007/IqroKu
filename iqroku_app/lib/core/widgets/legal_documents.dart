import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_chrome.dart';

enum LegalDocumentType {
  terms('Syarat & Ketentuan'),
  privacy('Kebijakan Privasi');

  const LegalDocumentType(this.title);

  final String title;
}

Future<void> showLegalDocument(BuildContext context, LegalDocumentType type) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(type: type)),
  );
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.type});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final sections = switch (type) {
      LegalDocumentType.terms => _termsSections,
      LegalDocumentType.privacy => _privacySections,
    };

    return Scaffold(
      appBar: AppBar(title: Text(type.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: AppInsets.page,
              children: [
                Text(type.title, style: AppText.hero.copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Berlaku sejak 19 Juni 2026. Dokumen ini adalah draft operasional IqroKu dan dapat diperbarui sebelum rilis publik.',
                  style: AppText.caption.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                ...sections.map((section) => _LegalSection(section: section)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.section});

  final _DocumentSection section;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: AppText.bodyStrong),
          const SizedBox(height: 8),
          ...section.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(item, style: AppText.caption.copyWith(height: 1.45)),
            );
          }),
        ],
      ),
    );
  }
}

class _DocumentSection {
  const _DocumentSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

const _termsSections = [
  _DocumentSection(
    title: '1. Penggunaan Aplikasi',
    items: [
      'IqroKu membantu orang tua mendampingi anak belajar Iqro, Al-Quran, hafalan, doa, jadwal solat, dan kiblat.',
      'Akun dibuat dan dikelola oleh orang tua atau wali. Anak menggunakan aplikasi melalui mode anak dan PIN yang diatur orang tua.',
      'Orang tua bertanggung jawab atas pendampingan, review bacaan, dan keputusan apakah anak sudah lancar atau perlu mengulang.',
    ],
  ),
  _DocumentSection(
    title: '2. Akun, PIN, dan Keamanan',
    items: [
      'Pengguna wajib menjaga kerahasiaan email, password, login Google, dan PIN.',
      'PIN orang tua dipakai untuk membatasi akses dashboard orang tua. PIN anak dipakai untuk masuk mode anak.',
      'Jika ada penggunaan tidak sah, pengguna perlu mengganti password/PIN dan menghubungi pengelola IqroKu.',
    ],
  ),
  _DocumentSection(
    title: '3. Rekaman Bacaan Anak',
    items: [
      'Fitur rekaman dipakai agar orang tua dapat meninjau bacaan anak.',
      'Hasil lancar atau perlu ulang ditentukan oleh orang tua, bukan penilaian otomatis AI.',
      'Pengguna tidak boleh mengunggah konten yang melanggar hukum, mengandung data pihak lain tanpa izin, atau konten di luar tujuan belajar.',
    ],
  ),
  _DocumentSection(
    title: '4. Paket Free, Iklan, dan Premium',
    items: [
      'Akun Free dapat menggunakan Iqro jilid 1 serta fitur jadwal solat, kiblat, doa-doa, dan murottal.',
      'Iqro jilid 2 sampai 6, penambahan kuota anak, atau fitur premium lain dapat memerlukan subscription.',
      'Pada akun Free, aplikasi dapat menampilkan iklan. Integrasi iklan dan payment gateway akan mengikuti ketersediaan layanan produksi.',
    ],
  ),
  _DocumentSection(
    title: '5. Perubahan Layanan',
    items: [
      'IqroKu dapat memperbarui fitur, harga, batasan paket, atau dokumen ini untuk meningkatkan layanan.',
      'Jika perubahan berdampak penting pada pengguna, IqroKu akan menampilkan pemberitahuan di aplikasi atau kanal resmi.',
    ],
  ),
];

const _privacySections = [
  _DocumentSection(
    title: '1. Data yang Dikumpulkan',
    items: [
      'Data akun orang tua: nama, email, metode login, dan status subscription.',
      'Data profil anak: nama, usia, avatar, progress Iqro, repeat page, jadwal belajar, dan PIN yang disimpan dalam bentuk hash.',
      'Data belajar: status halaman, catatan review, riwayat rekaman, durasi rekaman, dan file audio bacaan jika pengguna merekam.',
      'Data perangkat yang diperlukan fitur: lokasi perkiraan untuk jadwal solat/kiblat dan izin microphone untuk rekaman.',
    ],
  ),
  _DocumentSection(
    title: '2. Cara Data Digunakan',
    items: [
      'Data digunakan untuk login, sinkronisasi progress, dashboard orang tua, review bacaan, jadwal solat, kiblat, notifikasi, subscription, dan dukungan pengguna.',
      'Rekaman audio digunakan agar orang tua dapat memutar dan menilai bacaan anak.',
      'IqroKu tidak menggunakan AI untuk menentukan hasil lancar atau perlu ulang pada bacaan anak.',
    ],
  ),
  _DocumentSection(
    title: '3. Penyimpanan dan Keamanan',
    items: [
      'Data disimpan di perangkat dan server IqroKu sesuai kebutuhan fitur.',
      'Token, PIN hash, dan file audio dilindungi dengan kontrol akses agar hanya akun orang tua terkait yang dapat mengaksesnya.',
      'Pengguna tetap perlu menjaga keamanan perangkat, akun email/Google, password, dan PIN.',
    ],
  ),
  _DocumentSection(
    title: '4. Iklan dan Pihak Ketiga',
    items: [
      'Akun Free dapat melihat iklan setelah integrasi iklan produksi aktif.',
      'Layanan pihak ketiga seperti Google Sign-In, payment gateway, analytics, crash reporting, iklan, atau API jadwal dapat memproses data sesuai kebijakan masing-masing.',
      'IqroKu akan membatasi pembagian data hanya untuk kebutuhan operasional aplikasi.',
    ],
  ),
  _DocumentSection(
    title: '5. Hak Pengguna',
    items: [
      'Orang tua dapat memperbarui profil anak, mengatur PIN, menghapus progress lokal, atau meminta penghapusan data akun sesuai prosedur dukungan.',
      'Pengguna dapat menolak izin microphone atau lokasi, tetapi fitur rekaman, jadwal berbasis lokasi, dan kiblat dapat terbatas.',
      'Untuk rilis publik, kontak dukungan resmi akan ditampilkan di aplikasi dan halaman store.',
    ],
  ),
];
