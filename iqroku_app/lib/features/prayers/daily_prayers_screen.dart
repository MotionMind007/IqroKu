import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/widgets/app_chrome.dart';
import '../../models/prayer_models.dart';

class DailyPrayersScreen extends StatelessWidget {
  const DailyPrayersScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final prayers = state.dailyPrayers;
    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: 'Doa-doa',
            trailing: state.dailyPrayersLoading
                ? Icons.hourglass_empty
                : Icons.refresh,
            onBack: onBack ?? state.goHome,
            onTrailing: () => state.loadDailyPrayers(forceRefresh: true),
          ),
          if (state.shouldShowAds) ...[
            const SizedBox(height: 12),
            const IqrokuAdBanner(),
          ],
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
          if (state.dailyPrayersError != null)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              color: AppColors.cream,
              child: Text(
                state.dailyPrayersError!,
                style: AppText.caption.copyWith(color: AppColors.muted),
              ),
            ),
          ...prayers.map((prayer) => _DailyPrayerCard(prayer: prayer)),
        ],
      ),
    );
  }
}

class _DailyPrayerCard extends StatelessWidget {
  const _DailyPrayerCard({required this.prayer});

  final DailyPrayer prayer;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(prayer.title, style: AppText.bodyStrong),
          const SizedBox(height: 4),
          Text(prayer.category, style: AppText.caption),
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
          if (prayer.latin.isNotEmpty) ...[
            Text(
              prayer.latin,
              style: AppText.caption.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 6),
          ],
          Text(prayer.meaning, style: AppText.caption),
        ],
      ),
    );
  }
}
