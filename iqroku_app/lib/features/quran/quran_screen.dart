import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';
import '../../models/quran_models.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return switch (state.quranView) {
      QuranView.reader => QuranReaderScreen(state: state),
      QuranView.memorization => QuranMemorizationScreen(state: state),
      QuranView.murottal => MurottalScreen(state: state, onBack: onBack),
      QuranView.list => QuranSurahListScreen(state: state, onBack: onBack),
    };
  }
}

class QuranSurahListScreen extends StatelessWidget {
  const QuranSurahListScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final surahs = state.quranSurahs;

    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: "Al-Qur'an",
            trailing: Icons.search,
            onBack: onBack ?? state.goHome,
          ),
          if (state.quranLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.line,
            ),
          ],
          if (state.quranError != null) ...[
            const SizedBox(height: 12),
            _QuranErrorCard(
              message: state.quranError!,
              onRetry: () => unawaited(state.loadQuranContent()),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuranModeCard(
                  asset: AppAssets.quranNew,
                  title: "Baca Al-Qur'an",
                  subtitle: 'Ayat dan arti',
                  selected: !state.memorizationMode,
                  onTap: () => state.setQuranMode(QuranMode.reading),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuranModeCard(
                  asset: AppAssets.hafalan,
                  title: 'Hafalan',
                  subtitle: 'Rekam suara',
                  selected: state.memorizationMode,
                  onTap: () => state.setQuranMode(QuranMode.memorization),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: state.memorizationMode
                ? 'Pilih Surat Hafalan'
                : 'Pilih Surat',
          ),
          const SizedBox(height: 10),
          ...List.generate(surahs.length, (index) {
            return SurahRow(
              number: index + 1,
              surah: surahs[index],
              trailingIcon: state.memorizationMode
                  ? Icons.mic_none
                  : Icons.chevron_right,
              onTap: () => state.memorizationMode
                  ? state.openQuranMemorization(index)
                  : state.openQuranReader(index),
            );
          }),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class MurottalScreen extends StatelessWidget {
  const MurottalScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final surahs = state.quranSurahs;

    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: 'Murottal',
            trailing: Icons.volume_up_outlined,
            onBack: onBack ?? state.goHome,
          ),
          if (state.shouldShowAds) ...[
            const SizedBox(height: 12),
            const IqrokuAdBanner(),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Audio Al-Quran', style: AppText.caption),
                      SizedBox(height: 4),
                      Text(
                        'Pilih surat untuk mendengar murottal',
                        style: AppText.sectionTitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Image.asset(AppAssets.murottal, width: 76, height: 76),
              ],
            ),
          ),
          if (state.playbackError != null) ...[
            const SizedBox(height: 12),
            Text(
              state.playbackError!,
              style: AppText.caption.copyWith(color: AppColors.coral),
            ),
          ],
          const SizedBox(height: 18),
          ...List.generate(surahs.length, (index) {
            final selected = index == state.selectedSurahIndex;
            return SurahRow(
              number: index + 1,
              surah: surahs[index],
              selected: selected,
              trailingIcon: selected && state.quranAudioPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_outline,
              onTap: () async {
                await state.selectSurah(index);
                await state.toggleSelectedSurahMurottal();
              },
            );
          }),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class QuranReaderScreen extends StatelessWidget {
  const QuranReaderScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.selectedSurahDetail;
    final surah = detail?.surah ?? state.selectedSurahData;
    final ayahs = detail?.ayahs ?? const <QuranAyah>[];

    return AppPage(
      child: Column(
        children: [
          Padding(
            padding: AppInsets.page.copyWith(bottom: 0),
            child: AppTopBar(
              title: surah.name,
              trailing: Icons.menu_book_outlined,
              onBack: state.backToQuranList,
            ),
          ),
          if (state.surahDetailLoading)
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.line,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                _ReaderHeader(
                  surah: surah,
                  targetLabel: 'Target membaca: 0/5 mnt',
                  asset: AppAssets.quranNew,
                ),
                const SizedBox(height: 12),
                if (ayahs.isEmpty)
                  const Text('Ayat belum bisa dimuat.', style: AppText.body)
                else
                  ...ayahs.map((ayah) => QuranAyahBlock(ayah: ayah)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuranMemorizationScreen extends StatelessWidget {
  const QuranMemorizationScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.selectedSurahDetail;
    final surah = detail?.surah ?? state.selectedSurahData;
    final latestAttempt = state.selectedSurahLatestMemorizationAttempt;

    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: 'Hafalan ${surah.name}',
            trailing: Icons.mic_none,
            onBack: state.backToQuranList,
          ),
          const SizedBox(height: 12),
          _ReaderHeader(surah: surah, targetLabel: 'Target hafalan: rekam 1x'),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latihan Hafalan', style: AppText.sectionTitle),
                const SizedBox(height: 8),
                Text(
                  state.isQuranMemorizationRecording
                      ? 'Sedang merekam ${state.voiceRecordingSeconds} detik'
                      : 'Dengarkan atau hafalkan dulu, lalu rekam hafalan anak.',
                  style: AppText.body,
                ),
                if (state.voiceRecordingError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.voiceRecordingError!,
                    style: AppText.caption.copyWith(color: AppColors.coral),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: state.isQuranMemorizationRecording
                      ? () => unawaited(state.finishQuranMemorizationPractice())
                      : () => unawaited(state.startQuranMemorizationPractice()),
                  icon: Icon(
                    state.isQuranMemorizationRecording ? Icons.stop : Icons.mic,
                  ),
                  label: Text(
                    state.isQuranMemorizationRecording
                        ? 'Selesai Rekam'
                        : 'Mulai Rekam Hafalan',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: AppColors.primary,
                  ),
                ),
                if (latestAttempt != null) ...[
                  const Divider(height: 28),
                  Text(
                    'Rekaman terakhir: ${latestAttempt.durationSeconds} detik',
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 6),
                  Text(latestAttempt.note ?? '', style: AppText.caption),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (detail?.ayahs.isNotEmpty ?? false)
            ...detail!.ayahs.map((ayah) => QuranAyahBlock(ayah: ayah)),
        ],
      ),
    );
  }
}

class _QuranModeCard extends StatelessWidget {
  const _QuranModeCard({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mint : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Image.asset(asset, height: 58, fit: BoxFit.contain),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.smallStrong,
              ),
              const SizedBox(height: 3),
              Text(subtitle, textAlign: TextAlign.center, style: AppText.mini),
            ],
          ),
        ),
      ),
    );
  }
}

class SurahRow extends StatelessWidget {
  const SurahRow({
    super.key,
    required this.number,
    required this.surah,
    required this.trailingIcon,
    required this.onTap,
    this.selected = false,
  });

  final int number;
  final Surah surah;
  final IconData trailingIcon;
  final Future<void> Function() onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      color: selected ? AppColors.mint : AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => unawaited(onTap()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.canvas,
                foregroundColor: selected ? Colors.white : AppColors.primary,
                child: Text('$number', style: AppText.smallStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surah.name, style: AppText.bodyStrong),
                    Text(
                      '${surah.ayahCount} ayat  -  ${surah.meaning}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(surah.arabicName, style: AppText.arabicList),
              ),
              const SizedBox(width: 10),
              Icon(
                trailingIcon,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.surah,
    required this.targetLabel,
    this.asset = AppAssets.bookmark,
  });

  final Surah surah;
  final String targetLabel;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          AssetIcon(asset, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${surah.id}. ${surah.meaning}',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(targetLabel, style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class QuranAyahBlock extends StatelessWidget {
  const QuranAyahBlock({super.key, required this.ayah});

  final QuranAyah ayah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Ayat 1:${ayah.number}', style: AppText.caption),
            ),
          ),
          const SizedBox(height: 26),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              ayah.arabic,
              textAlign: TextAlign.right,
              style: AppText.arabicReader.copyWith(fontSize: 34, height: 1.8),
            ),
          ),
          if (ayah.latin != null && ayah.latin!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              ayah.latin!,
              textAlign: TextAlign.center,
              style: AppText.bodyStrong.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            ayah.translation,
            textAlign: TextAlign.center,
            style: AppText.sectionTitle.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _QuranErrorCard extends StatelessWidget {
  const _QuranErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.caption)),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}
