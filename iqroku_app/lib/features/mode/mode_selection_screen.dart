import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.appLogo,
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Pilih Mode',
                    style: AppText.hero.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masuk sebagai orang tua atau anak',
                    style: AppText.body.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 48),
                  _ModeButton(
                    icon: Icons.person,
                    label: 'Mode Orang Tua',
                    description: 'Review bacaan, kelola profil anak',
                    color: AppColors.primary,
                    onTap: () => state.selectMode(AppMode.parent),
                  ),
                  const SizedBox(height: 16),
                  _ModeButton(
                    icon: Icons.child_care,
                    label: 'Mode Anak',
                    description: 'Belajar Iqro, rekam bacaan',
                    color: AppColors.gold,
                    onTap: () => state.selectMode(AppMode.child),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Akun: ${state.parentAccount?.email ?? ''}',
                    style: AppText.caption.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: state.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.coral,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                foregroundColor: color,
                child: Icon(icon, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.bodyStrong),
                    const SizedBox(height: 4),
                    Text(description, style: AppText.caption),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
