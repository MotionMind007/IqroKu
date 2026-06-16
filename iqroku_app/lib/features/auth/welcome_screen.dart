import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';

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
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AppAssets.welcomePage,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 42, 24, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Belajar Ngaji Lebih Mudah, Terarah, dan Menyenangkan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            height: 1.13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                            shadows: [
                              Shadow(
                                color: Colors.white,
                                blurRadius: 12,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "IqroKu membantu anak belajar Iqro, hafalan Juz Amma, membaca Qur'an, dan membangun kebiasaan ibadah harian.",
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Colors.white,
                                blurRadius: 10,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 118),
                    child: FilledButton(
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
