import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';
import '../../models/quran_models.dart';

class QuranScreen extends StatelessWidget {
  const QuranScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final surahs = state.repository.surahs;
    final selectedSurah = surahs[state.selectedSurahIndex];

    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          const AppTopBar(title: "Al-Qur'an", trailing: Icons.search),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Daftar Surat')),
              ButtonSegment(value: true, label: Text('Mode Hafalan')),
            ],
            selected: {state.memorizationMode},
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.surface,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColors.text,
              ),
            ),
            onSelectionChanged: (value) =>
                state.setMemorizationMode(value.first),
          ),
          const SizedBox(height: 16),
          const QuranContinueCard(),
          const SizedBox(height: 18),
          ...List.generate(surahs.length, (index) {
            return SurahRow(
              number: index + 1,
              surah: surahs[index],
              playing: index == state.selectedSurahIndex,
              memorizationMode: state.memorizationMode,
              onTap: () => state.selectSurah(index),
            );
          }),
          const SizedBox(height: 16),
          QuranReaderPreview(
            surah: selectedSurah,
            preview: state.repository.readerPreview,
          ),
        ],
      ),
    );
  }
}

class QuranContinueCard extends StatelessWidget {
  const QuranContinueCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lanjutkan Membaca', style: AppText.caption),
                const SizedBox(height: 4),
                const Text('QS. Yasin - Ayat 12', style: AppText.sectionTitle),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    value: 12 / 83,
                    minHeight: 5,
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Lanjutkan'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const AssetIcon(AppAssets.quran, size: 72),
        ],
      ),
    );
  }
}

class SurahRow extends StatelessWidget {
  const SurahRow({
    super.key,
    required this.number,
    required this.surah,
    required this.playing,
    required this.memorizationMode,
    required this.onTap,
  });

  final int number;
  final Surah surah;
  final bool playing;
  final bool memorizationMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      color: playing ? AppColors.mint : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: playing ? AppColors.primary : AppColors.canvas,
              foregroundColor: playing ? Colors.white : AppColors.primary,
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
              memorizationMode
                  ? (playing ? Icons.check_circle : Icons.bookmark_border)
                  : (playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_outline),
              color: playing ? AppColors.primary : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class QuranReaderPreview extends StatelessWidget {
  const QuranReaderPreview({
    super.key,
    required this.surah,
    required this.preview,
  });

  final Surah surah;
  final AyahPreview preview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetIcon(
                surah.name == 'Al-Ikhlas' ? AppAssets.juzAmma : AppAssets.quran,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(surah.name, style: AppText.sectionTitle)),
            ],
          ),
          Text('Juz ${surah.juz} - Mode baca', style: AppText.caption),
          const Divider(height: 28),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              preview.arabic,
              textAlign: TextAlign.right,
              style: AppText.arabicReader,
            ),
          ),
          const SizedBox(height: 14),
          Text(preview.translation, style: AppText.body),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton.filled(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow),
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.skip_next),
              ),
              IconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.text_fields),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
