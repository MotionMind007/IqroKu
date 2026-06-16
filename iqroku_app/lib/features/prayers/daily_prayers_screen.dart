import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class DailyPrayersScreen extends StatelessWidget {
  const DailyPrayersScreen({super.key, required this.state});

  final IqrokuState state;

  static const _prayers = [
    _DailyPrayer(
      title: 'Doa Sebelum Belajar',
      arabic: 'رَبِّ زِدْنِي عِلْمًا وَارْزُقْنِي فَهْمًا',
      meaning: 'Ya Rabb, tambahkanlah ilmuku dan berilah aku pemahaman.',
    ),
    _DailyPrayer(
      title: 'Doa Kedua Orang Tua',
      arabic: 'رَبِّ اغْفِرْ لِي وَلِوَالِدَيَّ وَارْحَمْهُمَا',
      meaning:
          'Ya Rabb, ampunilah aku dan kedua orang tuaku, sayangilah mereka.',
    ),
    _DailyPrayer(
      title: 'Doa Sebelum Tidur',
      arabic: 'بِاسْمِكَ اللَّهُمَّ أَحْيَا وَأَمُوتُ',
      meaning: 'Dengan nama-Mu ya Allah aku hidup dan aku mati.',
    ),
    _DailyPrayer(
      title: 'Doa Bangun Tidur',
      arabic: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا',
      meaning:
          'Segala puji bagi Allah yang menghidupkan kami setelah mematikan kami.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: 'Doa-doa',
            trailing: Icons.bookmark_border,
            onBack: state.goHome,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kumpulan doa harian untuk anak, belajar, dan aktivitas ibadah.',
                    style: AppText.bodyStrong.copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                Image.asset(AppAssets.doaDoa, width: 76, height: 76),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._prayers.map((prayer) => _DailyPrayerCard(prayer: prayer)),
        ],
      ),
    );
  }
}

class _DailyPrayerCard extends StatelessWidget {
  const _DailyPrayerCard({required this.prayer});

  final _DailyPrayer prayer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(prayer.title, style: AppText.bodyStrong),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              prayer.arabic,
              textAlign: TextAlign.right,
              style: AppText.arabicReader.copyWith(fontSize: 26),
            ),
          ),
          const SizedBox(height: 10),
          Text(prayer.meaning, style: AppText.caption),
        ],
      ),
    );
  }
}

class _DailyPrayer {
  const _DailyPrayer({
    required this.title,
    required this.arabic,
    required this.meaning,
  });

  final String title;
  final String arabic;
  final String meaning;
}
