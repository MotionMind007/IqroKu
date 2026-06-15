import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';
import '../../models/iqro_models.dart';
import '../../models/learning_status.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final books = state.repository.iqroBooks;
    final pages = state.repository.pagesForBook(
      state.selectedIqroBook,
      state.selectedIqroStatus,
    );

    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          const AppTopBar(title: 'Belajar Iqro', trailing: Icons.help_outline),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final book = books[index];
                return AppChip(
                  label: book.title,
                  selected: state.selectedIqroBook == book.id,
                  onTap: () => state.selectIqroBook(book.id),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text('Pilih Halaman', style: AppText.sectionTitle),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final page = pages[index];
              return PageTile(
                page: page,
                selected: page.pageNumber == state.selectedIqroPage,
                onTap: () => state.selectIqroPage(page.pageNumber),
              );
            },
          ),
          const SizedBox(height: 18),
          const StatusLegend(),
          const SizedBox(height: 20),
          ReadingPracticeCard(
            bookId: state.selectedIqroBook,
            page: state.selectedIqroPage,
            status: state.selectedIqroStatus,
            onStatusChanged: state.setIqroStatus,
          ),
        ],
      ),
    );
  }
}

class PageTile extends StatelessWidget {
  const PageTile({
    super.key,
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final IqroPage page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = page.status.color;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AppColors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${page.pageNumber}', style: AppText.tileNumber),
              const SizedBox(height: 5),
              Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: page.status == LearningStatus.notStarted
                      ? AppColors.line
                      : color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                page.status.shortLabel,
                style: AppText.mini.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusLegend extends StatelessWidget {
  const StatusLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: LearningStatus.values.map((status) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 4, backgroundColor: status.color),
            const SizedBox(width: 6),
            Text(status.label, style: AppText.mini),
          ],
        );
      }).toList(),
    );
  }
}

class ReadingPracticeCard extends StatelessWidget {
  const ReadingPracticeCard({
    super.key,
    required this.bookId,
    required this.page,
    required this.status,
    required this.onStatusChanged,
  });

  final int bookId;
  final int page;
  final LearningStatus status;
  final ValueChanged<LearningStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetIcon(AppAssets.iqroBookByLevel(bookId), size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Iqro $bookId - Halaman $page',
                  style: AppText.sectionTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                'أَ  إِ  أُ\nبَ  بِ  بُ\nتَ  تِ  تُ\nثَ  ثِ  ثُ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  height: 1.75,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const AudioScrubber(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow),
            label: Text('Mulai Belajar Halaman $page'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatusButton(
                  label: 'Perlu Ulang',
                  selected: status == LearningStatus.review,
                  color: AppColors.coral,
                  onTap: () => onStatusChanged(LearningStatus.review),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatusButton(
                  label: 'Belajar Lagi',
                  selected: status == LearningStatus.learning,
                  color: AppColors.gold,
                  onTap: () => onStatusChanged(LearningStatus.learning),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatusButton(
                  label: 'Lancar',
                  selected: status == LearningStatus.fluent,
                  color: AppColors.primary,
                  onTap: () => onStatusChanged(LearningStatus.fluent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('8 / 28 halaman', style: AppText.caption),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 8 / 28,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.line,
            ),
          ),
        ],
      ),
    );
  }
}

class AudioScrubber extends StatelessWidget {
  const AudioScrubber({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: Icon(Icons.play_arrow, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 5,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.line,
                  thumbColor: AppColors.primary,
                ),
                child: const Slider(value: 0.28, onChanged: null),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('00:05', style: AppText.mini),
                  Text('00:28', style: AppText.mini),
                ],
              ),
            ],
          ),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.replay)),
      ],
    );
  }
}

class StatusButton extends StatelessWidget {
  const StatusButton({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? color : color.withValues(alpha: 0.12),
        foregroundColor: selected ? Colors.white : color,
        side: BorderSide(color: color.withValues(alpha: 0.25)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.smallStrong,
      ),
    );
  }
}
