import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
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
          ProgressSummaryCard(child: selectedChild),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Catatan Belajar Terbaru'),
          const SizedBox(height: 12),
          ...state.learningNotes.map((note) => LearningNoteCard(note: note)),
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

  void _showUpgradeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _UpgradeChildLimitSheet(
        onUpgrade: () {
          state.activateFamilyPlus();
          Navigator.pop(context);
        },
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
    required this.onUpgrade,
  });

  final int childCount;
  final int childLimit;
  final bool familyPlusActive;
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
                      ? 'Paket Family Plus aktif'
                      : 'Akun Free: 1 profil anak',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  familyPlusActive
                      ? 'Kamu bisa menambahkan beberapa anak dalam satu akun orang tua.'
                      : 'Kuota terpakai $childCount/$childLimit. Tambah anak berikutnya perlu upgrade.',
                  style: AppText.caption,
                ),
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
  const ProgressSummaryCard({super.key, required this.child});

  final profile.ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final completedPages = (child.progress * 28).round();
    final learningPages = child.progress == 0 ? 1 : 2;
    final reviewPages = child.progress > 0.5 ? 1 : 0;
    final remainingPages = (28 - completedPages - learningPages - reviewPages)
        .clamp(0, 28);

    return AppCard(
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
                    Text('Progress ${child.name}', style: AppText.sectionTitle),
                    const SizedBox(height: 4),
                    Text(child.currentLesson, style: AppText.caption),
                    const SizedBox(height: 6),
                    Text(
                      'Orang tua bisa cek posisi belajar dan catatan terakhir anak di sini.',
                      style: AppText.caption.copyWith(color: AppColors.text),
                    ),
                  ],
                ),
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
    );
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

class _UpgradeChildLimitSheet extends StatelessWidget {
  const _UpgradeChildLimitSheet({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tambah Anak dengan Family Plus', style: AppText.title),
          const SizedBox(height: 8),
          const Text(
            'Akun free mendapat 1 profil anak. Untuk memantau lebih dari satu anak, aktifkan paket berbayar.',
            style: AppText.body,
          ),
          const SizedBox(height: 18),
          const _UpgradeBenefit(text: 'Tambah hingga 5 profil anak'),
          const _UpgradeBenefit(text: 'Dashboard progress per anak'),
          const _UpgradeBenefit(text: 'Catatan belajar dan riwayat hafalan'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onUpgrade,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Upgrade Rp29.000/bulan'),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nanti dulu'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBenefit extends StatelessWidget {
  const _UpgradeBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.bodyStrong)),
        ],
      ),
    );
  }
}
