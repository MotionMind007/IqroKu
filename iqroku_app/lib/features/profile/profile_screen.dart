import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/asset_icon.dart';
import '../../models/profile_models.dart' as profile;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          const AppTopBar(
            title: 'Profil Anak',
            trailing: Icons.add_circle_outline,
          ),
          const SizedBox(height: 16),
          ...state.repository.children.map((child) {
            return ChildProfileCard(
              child: child,
              selected: child.id == state.selectedChildId,
              onTap: () => state.selectChild(child.id),
            );
          }),
          const SizedBox(height: 22),
          const ProgressSummaryCard(),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Catatan Belajar'),
          const SizedBox(height: 12),
          ...state.repository.learningNotes.map(
            (note) => LearningNoteCard(note: note),
          ),
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
            const AssetIcon(AppAssets.profile, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.name, style: AppText.bodyStrong),
                  Text(
                    '${child.age} tahun  -  ${child.currentLesson}',
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
  const ProgressSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
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
                    const CircularProgressIndicator(
                      value: 0.60,
                      strokeWidth: 7,
                      color: AppColors.primary,
                      backgroundColor: AppColors.line,
                    ),
                    Text(
                      '60%',
                      style: AppText.bodyStrong.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress Nedy', style: AppText.sectionTitle),
                    SizedBox(height: 4),
                    Text('Iqro 1 - Halaman 8 dari 28', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: MiniMetric(
                  label: 'Halaman Lancar',
                  value: '6',
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MiniMetric(
                  label: 'Sedang Belajar',
                  value: '2',
                  icon: Icons.hourglass_bottom,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: MiniMetric(
                  label: 'Perlu Ulang',
                  value: '1',
                  icon: Icons.replay_circle_filled,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MiniMetric(
                  label: 'Belum Dipelajari',
                  value: '19',
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
