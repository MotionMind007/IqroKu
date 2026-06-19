import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';
import '../../core/widgets/subscription_sheet.dart';
import '../../data/arabic_letter_repository.dart';
import '../../models/iqro_models.dart';
import '../../models/learning_status.dart';
import '../../models/profile_models.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final books = state.iqroBooks;
    final pages = state.selectedIqroPages;
    final latestAttempt = state.selectedPageLatestAttempt;
    final displayStatus = _reviewAwareStatus(
      state.selectedIqroStatus,
      latestAttempt,
    );

    return AppPage(
      child: ListView(
        key: const ValueKey('learning_scroll_view'),
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: 'Belajar Iqro',
            trailing: Icons.help_outline,
            onBack: state.goHome,
          ),
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
          if (state.iqroContentLoading) ...[
            const LinearProgressIndicator(
              minHeight: 5,
              color: AppColors.primary,
              backgroundColor: AppColors.line,
            ),
            const SizedBox(height: 14),
          ] else if (state.iqroContentError != null &&
              state.selectedIqroMaterialPage == null) ...[
            MaterialStatusBanner(message: state.iqroContentError!),
            const SizedBox(height: 14),
          ],
          const Text('Pilih Halaman', style: AppText.sectionTitle),
          const SizedBox(height: 12),
          if (state.subscriptionNotice != null) ...[
            SubscriptionAccessBanner(
              message: state.subscriptionNotice!,
              showUpgradeAction: state.isPremiumAccessNotice,
              onUpgrade: () => showIqrokuPlusSheet(
                context: context,
                onConfirm: state.startFamilyPlusCheckout,
                active: state.subscriptionActive,
                renewalLabel: state.subscriptionRenewalLabel,
                loading: state.subscriptionCheckoutLoading,
                errorMessage: state.subscriptionError,
              ),
              onClose: state.clearSubscriptionNotice,
            ),
            const SizedBox(height: 12),
          ],
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
                locked: state.isIqroPageLocked(page.bookId, page.pageNumber),
                premiumLocked: state.isIqroPagePremiumLocked(
                  page.bookId,
                  page.pageNumber,
                ),
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
            displayStatus: displayStatus,
            completedPages: state.selectedIqroCompletedPages,
            totalPages: state.selectedIqroTotalPages,
            materialPage: state.selectedIqroMaterialPage,
            isVoiceRecording: state.isVoiceRecording,
            voiceRecordingSeconds: state.voiceRecordingSeconds,
            voiceRecordingError: state.voiceRecordingError,
            latestAttempt: latestAttempt,
            playingAttemptId: state.playingAttemptId,
            playbackError: state.playbackError,
            onStartVoice: state.startVoicePractice,
            onFinishVoice: state.finishVoicePractice,
            onCancelVoice: state.cancelVoicePractice,
            onTogglePlayback: state.toggleAttemptPlayback,
            onNextPage: state.goToNextIqroPage,
          ),
        ],
      ),
    );
  }
}

LearningStatus _reviewAwareStatus(
  LearningStatus status,
  LearningAttempt? latestAttempt,
) {
  final attemptStatus = latestAttempt?.assessmentStatus;
  return switch (attemptStatus) {
    ReadingAssessmentStatus.fluent => LearningStatus.fluent,
    ReadingAssessmentStatus.needsReview => LearningStatus.review,
    _ => status,
  };
}

class PageTile extends StatelessWidget {
  const PageTile({
    super.key,
    required this.page,
    required this.selected,
    required this.locked,
    required this.premiumLocked,
    required this.onTap,
  });

  final IqroPage page;
  final bool selected;
  final bool locked;
  final bool premiumLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = locked ? AppColors.muted : page.status.color;
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
          child: Stack(
            children: [
              Center(
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
                      premiumLocked ? 'Plus' : page.status.shortLabel,
                      style: AppText.mini.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              if (locked)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.lock, size: 15, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionAccessBanner extends StatelessWidget {
  const SubscriptionAccessBanner({
    super.key,
    required this.message,
    required this.showUpgradeAction,
    required this.onUpgrade,
    required this.onClose,
  });

  final String message;
  final bool showUpgradeAction;
  final VoidCallback onUpgrade;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.paper,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            showUpgradeAction ? Icons.lock_open : Icons.info_outline,
            color: showUpgradeAction ? AppColors.gold : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showUpgradeAction
                      ? 'Lanjut dengan IqroKu Plus'
                      : 'Ikuti arahan orang tua',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 3),
                Text(message, style: AppText.caption),
                if (showUpgradeAction) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: onUpgrade,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Aktifkan Rp49.000/bulan'),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Tutup',
          ),
        ],
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
    required this.displayStatus,
    required this.completedPages,
    required this.totalPages,
    required this.materialPage,
    required this.isVoiceRecording,
    required this.voiceRecordingSeconds,
    required this.voiceRecordingError,
    required this.latestAttempt,
    required this.playingAttemptId,
    required this.playbackError,
    required this.onStartVoice,
    required this.onFinishVoice,
    required this.onCancelVoice,
    required this.onTogglePlayback,
    required this.onNextPage,
  });

  final int bookId;
  final int page;
  final LearningStatus status;
  final LearningStatus displayStatus;
  final int completedPages;
  final int totalPages;
  final IqroMaterialPage? materialPage;
  final bool isVoiceRecording;
  final int voiceRecordingSeconds;
  final String? voiceRecordingError;
  final LearningAttempt? latestAttempt;
  final String? playingAttemptId;
  final String? playbackError;
  final Future<void> Function() onStartVoice;
  final Future<void> Function() onFinishVoice;
  final Future<void> Function() onCancelVoice;
  final Future<void> Function(LearningAttempt attempt) onTogglePlayback;
  final VoidCallback onNextPage;

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
          if (status == LearningStatus.fluent && page < totalPages) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onNextPage,
              icon: const Icon(Icons.arrow_forward),
              label: Text('Halaman Berikutnya (${page + 1})'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          MaterialSummary(page: materialPage),
          const SizedBox(height: 12),
          IqroMaterialReader(page: materialPage),
          const SizedBox(height: 14),
          VoicePracticePanel(
            isRecording: isVoiceRecording,
            recordingSeconds: voiceRecordingSeconds,
            errorMessage: voiceRecordingError,
            latestAttempt: latestAttempt,
            playingAttemptId: playingAttemptId,
            playbackError: playbackError,
            onStart: onStartVoice,
            onFinish: onFinishVoice,
            onCancel: onCancelVoice,
            onTogglePlayback: onTogglePlayback,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusIndicator(
                  label: 'Perlu Ulang',
                  active: displayStatus == LearningStatus.review,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusIndicator(
                  label: 'Lancar',
                  active: displayStatus == LearningStatus.fluent,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$completedPages / $totalPages halaman lancar',
            style: AppText.caption,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalPages == 0 ? 0 : completedPages / totalPages,
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

class MaterialStatusBanner extends StatelessWidget {
  const MaterialStatusBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.coral),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: AppText.caption)),
          ],
        ),
      ),
    );
  }
}

class MaterialSummary extends StatelessWidget {
  const MaterialSummary({super.key, required this.page});

  final IqroMaterialPage? page;

  @override
  Widget build(BuildContext context) {
    final currentPage = page;
    if (currentPage == null) {
      return const MaterialStatusBanner(
        message: 'Materi JSON sedang dimuat. Progress tetap bisa dipakai.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentPage.concept != null) ...[
          _InfoBlock(
            icon: Icons.lightbulb_outline,
            label: 'Konsep',
            value: currentPage.concept!,
          ),
          const SizedBox(height: 8),
        ],
        if (currentPage.instruction != null) ...[
          _InfoBlock(
            icon: Icons.tips_and_updates_outlined,
            label: 'Instruksi',
            value: currentPage.instruction!,
          ),
          const SizedBox(height: 8),
        ],
        if (currentPage.newLetters.isNotEmpty) ...[
          Text(
            'Huruf baru',
            style: AppText.mini.copyWith(color: AppColors.text),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            textDirection: TextDirection.rtl,
            children: currentPage.newLetters
                .map((letter) => _ArabicToken(token: letter))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.mini.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: AppText.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArabicToken extends StatelessWidget {
  const _ArabicToken({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: ArabicLetterRepository().getLatinName(token),
      builder: (context, snapshot) {
        final latinName = snapshot.data ?? '';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  token,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                if (latinName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    latinName,
                    style: AppText.mini.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class IqroMaterialReader extends StatelessWidget {
  const IqroMaterialReader({super.key, required this.page});

  final IqroMaterialPage? page;

  @override
  Widget build(BuildContext context) {
    final currentPage = page;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: currentPage == null || !currentPage.hasMaterial
          ? const Text(
              'Materi halaman ini belum tersedia di JSON.',
              textAlign: TextAlign.center,
              style: AppText.body,
            )
          : Column(
              children: [
                for (final line in currentPage.lines) ...[
                  _ArabicMaterialLine(tokens: line),
                  if (line != currentPage.lines.last)
                    const Divider(height: 20, color: AppColors.line),
                ],
              ],
            ),
    );
  }
}

class _ArabicMaterialLine extends StatelessWidget {
  const _ArabicMaterialLine({required this.tokens});

  final List<String> tokens;

  @override
  Widget build(BuildContext context) {
    final joined = tokens.join('   ');
    final compactLength = tokens.join().length;
    final fontSize = compactLength > 60
        ? 19.0
        : compactLength > 38
        ? 22.0
        : 28.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        joined,
        textAlign: TextAlign.center,
        softWrap: true,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.75,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      ),
    );
  }
}

class VoicePracticePanel extends StatelessWidget {
  const VoicePracticePanel({
    super.key,
    required this.isRecording,
    required this.recordingSeconds,
    required this.errorMessage,
    required this.latestAttempt,
    required this.playingAttemptId,
    required this.playbackError,
    required this.onStart,
    required this.onFinish,
    required this.onCancel,
    required this.onTogglePlayback,
  });

  final bool isRecording;
  final int recordingSeconds;
  final String? errorMessage;
  final LearningAttempt? latestAttempt;
  final String? playingAttemptId;
  final String? playbackError;
  final Future<void> Function() onStart;
  final Future<void> Function() onFinish;
  final Future<void> Function() onCancel;
  final Future<void> Function(LearningAttempt attempt) onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isRecording
            ? AppColors.coral.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecording
              ? AppColors.coral.withValues(alpha: 0.35)
              : AppColors.line,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: isRecording
                      ? AppColors.coral
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Icon(isRecording ? Icons.mic : Icons.mic_none),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRecording ? 'Merekam bacaan...' : 'Baca dengan suara',
                        style: AppText.bodyStrong,
                      ),
                      if (isRecording) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Durasi ${_formatDuration(recordingSeconds)}',
                          style: AppText.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (latestAttempt != null && !isRecording) ...[
              const SizedBox(height: 12),
              _AttemptSummary(
                attempt: latestAttempt!,
                isPlaying: playingAttemptId == latestAttempt!.id,
                onTogglePlayback: onTogglePlayback,
              ),
            ],
            if (errorMessage != null && !isRecording) ...[
              const SizedBox(height: 12),
              MaterialStatusBanner(message: errorMessage!),
            ],
            if (playbackError != null && !isRecording) ...[
              const SizedBox(height: 12),
              MaterialStatusBanner(message: playbackError!),
            ],
            const SizedBox(height: 12),
            if (isRecording)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => unawaited(onFinish()),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop & Simpan'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.coral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () => unawaited(onCancel()),
                    icon: const Icon(Icons.close),
                    color: AppColors.coral,
                    tooltip: 'Batalkan rekam',
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => unawaited(onStart()),
                icon: const Icon(Icons.mic),
                label: const Text('Mulai Rekam Bacaan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _AttemptSummary extends StatelessWidget {
  const _AttemptSummary({
    required this.attempt,
    required this.isPlaying,
    required this.onTogglePlayback,
  });

  final LearningAttempt attempt;
  final bool isPlaying;
  final Future<void> Function(LearningAttempt attempt) onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final hasAudio = attempt.audioPath != null && attempt.audioPath!.isNotEmpty;
    final assessmentColor = _assessmentColor(attempt.assessmentStatus);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Percobaan terakhir ${VoicePracticePanel._formatDuration(attempt.durationSeconds)} pada ${attempt.date}',
                    style: AppText.caption.copyWith(color: AppColors.text),
                  ),
                ),
                _ReviewBadge(
                  label: attempt.assessmentStatus.label,
                  color: assessmentColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              attempt.note ?? 'Rekaman masuk antrean review orang tua.',
              style: AppText.caption.copyWith(color: AppColors.text),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: hasAudio
                  ? () => unawaited(onTogglePlayback(attempt))
                  : null,
              icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
              label: Text(isPlaying ? 'Stop' : 'Putar Ulang'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: hasAudio
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _assessmentColor(ReadingAssessmentStatus status) {
    return switch (status) {
      ReadingAssessmentStatus.recorded => AppColors.gold,
      ReadingAssessmentStatus.assessing => AppColors.blue,
      ReadingAssessmentStatus.fluent => AppColors.primary,
      ReadingAssessmentStatus.needsReview => AppColors.coral,
    };
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppText.mini.copyWith(color: color)),
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

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.label,
    required this.active,
    required this.color,
  });

  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? color : color.withValues(alpha: 0.2),
          width: active ? 2 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (active) ...[
            Icon(
              Icons.check_circle,
              size: 16,
              color: active ? Colors.white : color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.smallStrong.copyWith(
              color: active ? Colors.white : color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
