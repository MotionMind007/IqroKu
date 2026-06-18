import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/legal_documents.dart';
import '../../core/widgets/subscription_sheet.dart';
import '../../models/learning_status.dart';
import '../../models/profile_models.dart' as profile;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final selectedChild = state.selectedChild;

    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          _ParentDashboardHeader(
            planLabel: state.planLabel,
            quotaLabel: state.childQuotaLabel,
            onAddChild: () => _handleAddChild(context),
          ),
          const SizedBox(height: 16),
          _PlanNoticeCard(
            childCount: state.childProfiles.length,
            childLimit: state.childLimit,
            familyPlusActive: state.familyPlusActive,
            renewalLabel: state.subscriptionRenewalLabel,
            onUpgrade: () => _showUpgradeSheet(context),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Profil Anak'),
          const SizedBox(height: 12),
          ...state.childProfiles.map((child) {
            return ChildProfileCard(
              child: child,
              selected: child.id == state.selectedChildId,
              onTap: () => state.selectChild(child.id),
            );
          }),
          const SizedBox(height: 22),
          ProgressSummaryCard(
            child: selectedChild,
            onTap: () => _openProgressDetail(context),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Riwayat Rekaman Bacaan'),
          const SizedBox(height: 12),
          if (state.selectedChildLearningAttempts.isEmpty)
            const EmptyAttemptHistoryCard()
          else
            ...state.selectedChildLearningAttempts.map((attempt) {
              return LearningAttemptHistoryCard(attempt: attempt);
            }),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Catatan Belajar Terbaru'),
          const SizedBox(height: 12),
          ...state.learningNotes.map((note) => LearningNoteCard(note: note)),
          const SizedBox(height: 18),
          ParentSettingsCard(
            familyPlusActive: state.familyPlusActive,
            renewalLabel: state.subscriptionRenewalLabel,
            onManagePlan: () => _showUpgradeSheet(context),
            onResetProgress: () => _confirmResetProgress(context),
            onLogout: () => _confirmLogout(context),
            onOpenTerms: () =>
                showLegalDocument(context, LegalDocumentType.terms),
            onOpenPrivacy: () =>
                showLegalDocument(context, LegalDocumentType.privacy),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _handleAddChild(BuildContext context) {
    if (state.canAddFreeChild) {
      state.startAddChild();
      return;
    }

    _showUpgradeSheet(context);
  }

  void _openProgressDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChildProgressDetailScreen(state: state),
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context) {
    showIqrokuPlusSheet(
      context: context,
      onConfirm: state.activateFamilyPlus,
      active: state.subscriptionActive,
      renewalLabel: state.subscriptionRenewalLabel,
    );
  }

  void _confirmResetProgress(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress anak?'),
        content: Text(
          'Progress ${state.selectedChild.name} akan kembali ke Iqro 1 Halaman 1. Catatan belajar Iqro juga akan dibersihkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              state.resetSelectedChildProgress();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Untuk prototype ini, data lokal tetap tersimpan. Kamu bisa masuk lagi dan melanjutkan progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              state.logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _ParentDashboardHeader extends StatelessWidget {
  const _ParentDashboardHeader({
    required this.planLabel,
    required this.quotaLabel,
    required this.onAddChild,
  });

  final String planLabel;
  final String quotaLabel;
  final VoidCallback onAddChild;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard Orang Tua', style: AppText.title),
              SizedBox(height: 4),
              Text(
                'Pantau progress belajar anak dari satu akun.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _PlanBadge(label: planLabel),
            const SizedBox(height: 6),
            Text(quotaLabel, style: AppText.mini),
          ],
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onAddChild,
          icon: const Icon(Icons.add),
          tooltip: 'Tambah anak',
        ),
      ],
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: AppText.smallStrong.copyWith(color: AppColors.primaryDark),
      ),
    );
  }
}

class _PlanNoticeCard extends StatelessWidget {
  const _PlanNoticeCard({
    required this.childCount,
    required this.childLimit,
    required this.familyPlusActive,
    required this.renewalLabel,
    required this.onUpgrade,
  });

  final int childCount;
  final int childLimit;
  final bool familyPlusActive;
  final String renewalLabel;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: familyPlusActive ? AppColors.mint : AppColors.paper,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium_outlined, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  familyPlusActive
                      ? 'IqroKu Plus aktif'
                      : 'Akun Free: 1 anak + Iqro jilid 1',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  familyPlusActive
                      ? 'Semua materi Iqro terbuka dan kamu bisa memantau beberapa anak.'
                      : 'Kuota anak $childCount/$childLimit. Iqro jilid 2 sampai 6 perlu subscription Rp49.000/bulan.',
                  style: AppText.caption,
                ),
                if (familyPlusActive) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Aktif sampai $renewalLabel',
                    style: AppText.caption.copyWith(color: AppColors.text),
                  ),
                ],
              ],
            ),
          ),
          if (!familyPlusActive)
            TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
        ],
      ),
    );
  }
}

class ChildProfileCard extends StatelessWidget {
  const ChildProfileCard({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final profile.ChildProfile child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? AppColors.mint : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: AppColors.cream,
              child: ClipOval(
                child: Image.asset(
                  child.avatarAsset,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name, style: AppText.bodyStrong),
                  Text(
                    '${child.age} tahun - ${child.currentLesson}',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: child.progress,
                      minHeight: 5,
                      color: AppColors.primary,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(child.progress * 100).round()}%',
              style: AppText.bodyStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    super.key,
    required this.child,
    required this.onTap,
  });

  final profile.ChildProfile child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completedPages = (child.progress * 28).round();
    final learningPages = child.progress == 0 ? 1 : 2;
    final reviewPages = child.progress > 0.5 ? 1 : 0;
    final remainingPages = (28 - completedPages - learningPages - reviewPages)
        .clamp(0, 28);

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: child.progress,
                        strokeWidth: 7,
                        color: AppColors.primary,
                        backgroundColor: AppColors.line,
                      ),
                      Text(
                        '${(child.progress * 100).round()}%',
                        style: AppText.bodyStrong.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress ${child.name}',
                        style: AppText.sectionTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(child.currentLesson, style: AppText.caption),
                      const SizedBox(height: 6),
                      Text(
                        'Tap untuk lihat status per halaman dan rekaman terakhir.',
                        style: AppText.caption.copyWith(color: AppColors.text),
                      ),
                    ],
                  ),
                ),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.chevron_right, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MiniMetric(
                    label: 'Halaman Lancar',
                    value: '$completedPages',
                    icon: Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MiniMetric(
                    label: 'Sedang Belajar',
                    value: '$learningPages',
                    icon: Icons.hourglass_bottom,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: MiniMetric(
                    label: 'Perlu Ulang',
                    value: '$reviewPages',
                    icon: Icons.replay_circle_filled,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MiniMetric(
                    label: 'Belum Dipelajari',
                    value: '$remainingPages',
                    icon: Icons.radio_button_unchecked,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChildProgressDetailScreen extends StatefulWidget {
  const ChildProgressDetailScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<ChildProgressDetailScreen> createState() =>
      _ChildProgressDetailScreenState();
}

class _ChildProgressDetailScreenState extends State<ChildProgressDetailScreen> {
  late int selectedBookId = widget.state.selectedIqroBook;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AppPage(
              child: AnimatedBuilder(
                animation: widget.state,
                builder: (context, _) {
                  final child = widget.state.selectedChild;
                  final books = widget.state.iqroBooks;
                  final selectedBook = books.firstWhere(
                    (book) => book.id == selectedBookId,
                    orElse: () => books.first,
                  );
                  final pages = widget.state.iqroPagesForBook(selectedBook.id);
                  final completed = widget.state.completedPagesForBook(
                    selectedBook.id,
                  );
                  final learning = widget.state.learningPagesForBook(
                    selectedBook.id,
                  );
                  final review = widget.state.reviewPagesForBook(
                    selectedBook.id,
                  );
                  final remaining =
                      selectedBook.totalPages - completed - learning - review;

                  return ListView(
                    padding: AppInsets.page,
                    children: [
                      _ProgressDetailTopBar(childName: child.name),
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
                              selected: selectedBook.id == book.id,
                              onTap: () {
                                setState(() => selectedBookId = book.id);
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ProgressDetailSummary(
                        bookTitle: selectedBook.title,
                        completed: completed,
                        learning: learning,
                        review: review,
                        remaining: remaining.clamp(0, selectedBook.totalPages),
                        total: selectedBook.totalPages,
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: 'Detail Halaman'),
                      const SizedBox(height: 12),
                      ...pages.map((page) {
                        return ProgressPageCard(
                          pageNumber: page.pageNumber,
                          status: page.status,
                          attempt: widget.state.latestAttemptForIqroPage(
                            selectedBook.id,
                            page.pageNumber,
                          ),
                          onTap: () {
                            widget.state.openIqroPage(
                              selectedBook.id,
                              page.pageNumber,
                            );
                            Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressDetailTopBar extends StatelessWidget {
  const _ProgressDetailTopBar({required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        Expanded(
          child: Column(
            children: [
              Text('Progress Anak', style: AppText.title),
              const SizedBox(height: 2),
              Text(childName, style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _ProgressDetailSummary extends StatelessWidget {
  const _ProgressDetailSummary({
    required this.bookTitle,
    required this.completed,
    required this.learning,
    required this.review,
    required this.remaining,
    required this.total,
  });

  final String bookTitle;
  final int completed;
  final int learning;
  final int review;
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      color: AppColors.primary,
                      backgroundColor: AppColors.line,
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: AppText.smallStrong.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookTitle, style: AppText.sectionTitle),
                    const SizedBox(height: 4),
                    Text(
                      '$completed dari $total halaman sudah lancar',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: MiniMetric(
                  label: 'Lancar',
                  value: '$completed',
                  icon: Icons.check_circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniMetric(
                  label: 'Perlu Ulang',
                  value: '$review',
                  icon: Icons.replay_circle_filled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MiniMetric(
                  label: 'Belajar',
                  value: '$learning',
                  icon: Icons.hourglass_bottom,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MiniMetric(
                  label: 'Belum',
                  value: '$remaining',
                  icon: Icons.radio_button_unchecked,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProgressPageCard extends StatelessWidget {
  const ProgressPageCard({
    super.key,
    required this.pageNumber,
    required this.status,
    required this.attempt,
    required this.onTap,
  });

  final int pageNumber;
  final LearningStatus status;
  final profile.LearningAttempt? attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latestAttempt = attempt;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('$pageNumber', style: AppText.bodyStrong),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Halaman $pageNumber', style: AppText.bodyStrong),
                  const SizedBox(height: 3),
                  Text(
                    latestAttempt == null
                        ? 'Belum ada rekaman bacaan'
                        : 'Rekaman ${_formatDuration(latestAttempt.durationSeconds)} - ${latestAttempt.date}',
                    style: AppText.caption,
                  ),
                  if (latestAttempt?.note != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      latestAttempt!.note!,
                      style: AppText.caption.copyWith(color: AppColors.text),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _AttemptStatusPill(
                  label: status.shortLabel,
                  color: status.color,
                ),
              ],
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

class MiniMetric extends StatelessWidget {
  const MiniMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppText.mini)),
          Text(value, style: AppText.bodyStrong),
        ],
      ),
    );
  }
}

class LearningNoteCard extends StatelessWidget {
  const LearningNoteCard({super.key, required this.note});

  final profile.LearningNote note;

  @override
  Widget build(BuildContext context) {
    final color = note.status.color;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(note.title, style: AppText.bodyStrong)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  note.status.label,
                  style: AppText.smallStrong.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(note.date, style: AppText.caption),
          const SizedBox(height: 10),
          Text(note.note, style: AppText.body),
        ],
      ),
    );
  }
}

class EmptyAttemptHistoryCard extends StatelessWidget {
  const EmptyAttemptHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      margin: EdgeInsets.only(bottom: 12),
      child: Text(
        'Belum ada rekaman bacaan. Setelah anak merekam, hasilnya muncul di sini.',
        style: AppText.caption,
      ),
    );
  }
}

class LearningAttemptHistoryCard extends StatelessWidget {
  const LearningAttemptHistoryCard({super.key, required this.attempt});

  final profile.LearningAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final color = _assessmentColor(attempt.assessmentStatus);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(_assessmentIcon(attempt.assessmentStatus), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Iqro ${attempt.bookId} - Halaman ${attempt.pageNumber}',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 3),
                Text(
                  '${attempt.date} - ${_formatDuration(attempt.durationSeconds)}',
                  style: AppText.caption,
                ),
                const SizedBox(height: 8),
                Text(
                  attempt.note ?? 'Menunggu review orang tua.',
                  style: AppText.body,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AttemptStatusPill(
                label: attempt.assessmentStatus.label,
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _assessmentColor(profile.ReadingAssessmentStatus status) {
    return switch (status) {
      profile.ReadingAssessmentStatus.recorded => AppColors.gold,
      profile.ReadingAssessmentStatus.assessing => AppColors.blue,
      profile.ReadingAssessmentStatus.fluent => AppColors.primary,
      profile.ReadingAssessmentStatus.needsReview => AppColors.coral,
    };
  }

  static IconData _assessmentIcon(profile.ReadingAssessmentStatus status) {
    return switch (status) {
      profile.ReadingAssessmentStatus.recorded => Icons.schedule,
      profile.ReadingAssessmentStatus.assessing => Icons.graphic_eq,
      profile.ReadingAssessmentStatus.fluent => Icons.check_circle,
      profile.ReadingAssessmentStatus.needsReview => Icons.replay_circle_filled,
    };
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _AttemptStatusPill extends StatelessWidget {
  const _AttemptStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppText.mini.copyWith(color: color)),
    );
  }
}

class ParentSettingsCard extends StatelessWidget {
  const ParentSettingsCard({
    super.key,
    required this.familyPlusActive,
    required this.renewalLabel,
    required this.onManagePlan,
    required this.onResetProgress,
    required this.onLogout,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool familyPlusActive;
  final String renewalLabel;
  final VoidCallback onManagePlan;
  final VoidCallback onResetProgress;
  final VoidCallback onLogout;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pengaturan Akun', style: AppText.sectionTitle),
          const SizedBox(height: 12),
          _SettingsAction(
            icon: Icons.workspace_premium_outlined,
            title: familyPlusActive ? 'IqroKu Plus aktif' : 'Kelola paket',
            subtitle: familyPlusActive
                ? 'Subscription aktif sampai $renewalLabel.'
                : 'Subscription Rp49.000/bulan untuk buka semua Iqro dan tambah anak.',
            onTap: onManagePlan,
          ),
          const Divider(color: AppColors.line),
          _SettingsAction(
            icon: Icons.restart_alt,
            title: 'Reset progress anak',
            subtitle: 'Kembalikan progress anak terpilih ke awal.',
            color: AppColors.coral,
            onTap: onResetProgress,
          ),
          const Divider(color: AppColors.line),
          _SettingsAction(
            icon: Icons.description_outlined,
            title: 'Syarat & Ketentuan',
            subtitle: 'Aturan penggunaan IqroKu.',
            onTap: onOpenTerms,
          ),
          const Divider(color: AppColors.line),
          _SettingsAction(
            icon: Icons.privacy_tip_outlined,
            title: 'Kebijakan Privasi',
            subtitle: 'Cara IqroKu mengelola data akun, anak, dan rekaman.',
            onTap: onOpenPrivacy,
          ),
          const Divider(color: AppColors.line),
          _SettingsAction(
            icon: Icons.logout,
            title: 'Keluar',
            subtitle: 'Kembali ke welcome page. Data lokal tetap tersimpan.',
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
