import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';
import '../../models/prayer_models.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          const AppTopBar(title: 'Waktu Sholat', trailing: Icons.tune),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18),
              SizedBox(width: 6),
              Text('Jakarta, Indonesia', style: AppText.bodyStrong),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Senin, 15 Juni 2026 / 29 Dzulhijjah 1447 H',
            style: AppText.caption,
          ),
          const SizedBox(height: 18),
          const PrayerHeroCard(compact: false),
          const SizedBox(height: 14),
          ...state.repository.prayerTimes.map(
            (time) => PrayerTimeRow(time: time),
          ),
          const SizedBox(height: 22),
          const QiblaCard(),
        ],
      ),
    );
  }
}

class PrayerTimeRow extends StatelessWidget {
  const PrayerTimeRow({super.key, required this.time});

  final PrayerTime time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: time.active ? AppColors.mint : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: time.active ? AppColors.primary : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _iconFor(time.name),
            color: time.active ? AppColors.primary : AppColors.gold,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(time.name, style: AppText.bodyStrong)),
          Text(time.time, style: AppText.bodyStrong),
          if (time.active) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.notifications_active,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'Imsak' => Icons.nightlight_round,
      'Subuh' => Icons.wb_twilight,
      'Terbit' => Icons.wb_sunny_outlined,
      'Dzuhur' => Icons.light_mode_outlined,
      'Ashar' => Icons.mosque_outlined,
      'Maghrib' => Icons.sunny_snowing,
      _ => Icons.dark_mode_outlined,
    };
  }
}

class QiblaCard extends StatelessWidget {
  const QiblaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text('Arah Kiblat', style: AppText.sectionTitle),
          const SizedBox(height: 18),
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.line, width: 2),
                    boxShadow: AppShadows.soft,
                  ),
                ),
                const Positioned(
                  top: 12,
                  child: Text('N', style: AppText.bodyStrong),
                ),
                const Positioned(
                  bottom: 12,
                  child: Text('S', style: AppText.bodyStrong),
                ),
                const Positioned(
                  left: 16,
                  child: Text('W', style: AppText.bodyStrong),
                ),
                const Positioned(
                  right: 16,
                  child: Text('E', style: AppText.bodyStrong),
                ),
                Transform.rotate(
                  angle: -0.9,
                  child: const Icon(
                    Icons.navigation,
                    color: AppColors.primary,
                    size: 108,
                  ),
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const AssetIcon(AppAssets.qibla, size: 70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('295 deg', style: AppText.hero),
          const Text('Arah Kiblat', style: AppText.caption),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pastikan perangkat jauh dari benda logam atau magnet agar arah kiblat lebih akurat.',
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh),
            label: const Text('Kalibrasi Kompas'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
