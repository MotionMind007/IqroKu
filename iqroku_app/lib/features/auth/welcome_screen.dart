import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/asset_icon.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF7D8), AppColors.canvas, Colors.white],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  const SizedBox(height: 14),
                  const _BrandMark(),
                  const SizedBox(height: 28),
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 24,
                          child: Container(
                            width: 270,
                            height: 145,
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(80),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 24,
                          right: 36,
                          child: Icon(
                            Icons.nightlight_round,
                            color: AppColors.gold,
                            size: 42,
                          ),
                        ),
                        const Positioned(
                          bottom: 30,
                          child: AssetIcon(AppAssets.family, size: 185),
                        ),
                        const Positioned(
                          left: 24,
                          bottom: 32,
                          child: AssetIcon(AppAssets.iqroBasic, size: 82),
                        ),
                        const Positioned(
                          right: 24,
                          bottom: 34,
                          child: AssetIcon(AppAssets.quran, size: 82),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Belajar Ngaji Lebih Mudah, Terarah, dan Menyenangkan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'IqroKu membantu anak belajar Iqro, hafalan Juz Amma, membaca Qur’an, dan membangun kebiasaan ibadah harian.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const ValueKey('welcome_continue_button'),
                    onPressed: state.continueFromWelcome,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Mulai Sekarang',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: state.loginAsDemoUser,
                    child: const Text('Coba mode demo'),
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

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.nightlight_round, color: AppColors.gold, size: 42),
        const SizedBox(height: 2),
        Text(
          'IqroKu',
          style: AppText.hero.copyWith(
            color: AppColors.primaryDark,
            fontSize: 44,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text('Teman belajar ngaji keluarga', style: AppText.caption),
      ],
    );
  }
}
