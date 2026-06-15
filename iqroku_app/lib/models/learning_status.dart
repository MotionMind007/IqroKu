import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

enum LearningStatus {
  fluent('Lancar', 'Lancar', AppColors.primary),
  learning('Belajar', 'Belajar', AppColors.gold),
  review('Perlu Ulang', 'Ulang', AppColors.coral),
  notStarted('Belum dipelajari', 'Belum', AppColors.muted);

  const LearningStatus(this.label, this.shortLabel, this.color);

  final String label;
  final String shortLabel;
  final Color color;
}
