import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          Row(
            children: [
              const AppAvatar(initial: 'A', color: AppColors.cream),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assalamu alaikum,', style: AppText.caption),
                    Text('Aisyah', style: AppText.title),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PrayerHeroCard(),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Menu Utama',
            action: 'Lihat semua',
            onPressed: () => state.selectTab(1),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              QuickAction(
                asset: AppAssets.iqroBasic,
                label: 'Iqro',
                color: AppColors.primary,
                onTap: () => state.selectTab(1),
              ),
              QuickAction(
                asset: AppAssets.juzAmma,
                label: 'Juz Amma',
                color: AppColors.gold,
                onTap: () => state.selectTab(2),
              ),
              QuickAction(
                asset: AppAssets.quran,
                label: "Al-Qur'an",
                color: AppColors.blue,
                onTap: () => state.selectTab(2),
              ),
              QuickAction(
                asset: AppAssets.prayer,
                label: 'Waktu Sholat',
                color: AppColors.primary,
                onTap: () => state.selectTab(3),
              ),
              QuickAction(
                asset: AppAssets.qibla,
                label: 'Kiblat',
                color: AppColors.navy,
                onTap: () => state.selectTab(3),
              ),
              QuickAction(
                asset: AppAssets.profile,
                label: 'Profil',
                color: AppColors.lavender,
                onTap: () => state.selectTab(4),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Lanjutkan Belajar'),
          const SizedBox(height: 12),
          const ContinueCard(
            asset: AppAssets.iqroBook,
            title: 'Iqro 1 - Halaman 8',
            subtitle: 'Belum selesai',
            progress: 0.60,
          ),
          const ContinueCard(
            asset: AppAssets.juzAmma,
            title: 'QS. Al-Ikhlas - Ayat 2',
            subtitle: 'Hafalan',
            progress: 0.40,
          ),
          const ContinueCard(
            asset: AppAssets.quran,
            title: 'Al-Baqarah - Ayat 25',
            subtitle: 'Terakhir baca',
            progress: 0.25,
          ),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.asset,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String asset;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: AssetIcon(asset, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppText.smallStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String asset;
  final String title;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            child: AssetIcon(asset, size: 34),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.caption),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: AppColors.primary,
                    backgroundColor: AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: Icon(Icons.arrow_forward, size: 18),
          ),
        ],
      ),
    );
  }
}
