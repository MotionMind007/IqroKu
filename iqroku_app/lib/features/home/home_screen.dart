import 'dart:async';

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
    final child = state.selectedChild;
    final initial = child.name.trim().isEmpty
        ? 'A'
        : child.name.trim().substring(0, 1).toUpperCase();

    return AppPage(
      child: ListView(
        key: const ValueKey('home_scroll_view'),
        padding: AppInsets.page,
        children: [
          Row(
            children: [
              AppAvatar(initial: initial, color: AppColors.cream),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assalamu alaikum,', style: AppText.caption),
                    Text(child.name, style: AppText.title),
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
          HomePrayerHeroCard(
            prayerName: state.activePrayerTime.name,
            prayerTime: state.activePrayerTime.time,
          ),
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
            childAspectRatio: 0.96,
            children: [
              QuickAction(
                asset: AppAssets.iqroBasic,
                label: 'Iqro',
                color: AppColors.primary,
                onTap: () => state.selectTab(1),
              ),
              QuickAction(
                asset: AppAssets.murottal,
                label: 'Murottal',
                color: AppColors.gold,
                onTap: state.openMurottal,
              ),
              QuickAction(
                asset: AppAssets.quranNew,
                label: "Al-Qur'an",
                color: AppColors.blue,
                onTap: () => state.selectTab(2),
              ),
              QuickAction(
                asset: AppAssets.prayerTime,
                label: 'Jadwal Solat',
                color: AppColors.primary,
                onTap: state.openPrayerSchedule,
              ),
              QuickAction(
                asset: AppAssets.qiblaCompass,
                label: 'Kiblat',
                color: AppColors.navy,
                onTap: state.openQiblaCompass,
              ),
              QuickAction(
                asset: AppAssets.doaDoa,
                label: 'Doa-doa',
                color: AppColors.lavender,
                onTap: state.openDailyPrayers,
              ),
            ],
          ),
          const SizedBox(height: 22),
          SectionHeader(title: 'Progress ${child.name}'),
          const SizedBox(height: 12),
          ContinueCard(
            asset: AppAssets.iqroBook,
            title: child.currentLesson,
            subtitle: 'Progress anak ${(child.progress * 100).round()}%',
            progress: child.progress,
            onTap: () => state.selectTab(1),
          ),
          ContinueCard(
            asset: AppAssets.quran,
            title: state.selectedSurahData.name,
            subtitle: "Lanjut baca Al-Qur'an",
            progress: 0.25,
            onTap: () =>
                unawaited(state.openQuranReader(state.selectedSurahIndex)),
          ),
        ],
      ),
    );
  }
}

class HomePrayerHeroCard extends StatelessWidget {
  const HomePrayerHeroCard({
    super.key,
    required this.prayerName,
    required this.prayerTime,
  });

  final String prayerName;
  final String prayerTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -24,
            child: Image.asset(
              AppAssets.homeMosque,
              width: 190,
              height: 190,
              fit: BoxFit.contain,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary.withValues(alpha: 0.72),
                    AppColors.primary.withValues(alpha: 0.08),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sholat berikutnya',
                  style: AppText.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  prayerName,
                  style: AppText.hero.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  prayerTime,
                  style: AppText.bodyStrong.copyWith(color: Colors.white),
                ),
              ],
            ),
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
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 7),
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
    this.onTap,
  });

  final String asset;
  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
        ),
      ),
    );
  }
}
