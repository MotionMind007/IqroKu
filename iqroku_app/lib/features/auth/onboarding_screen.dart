import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      asset: AppAssets.onboarding3,
      title: 'Belajar Iqro Bertahap',
      description:
          'Dari jilid 1 sampai 6, anak belajar membaca huruf hijaiyah dengan audio panduan dan progress yang jelas.',
    ),
    _OnboardingData(
      asset: AppAssets.onboarding1,
      title: "Baca, Hafalan, dan Murottal",
      description:
          "Anak bisa membaca Al-Qur'an, latihan hafalan, dan mendengar murottal sebagai panduan.",
    ),
    _OnboardingData(
      asset: AppAssets.onboarding2,
      title: 'Pantau Progress Anak',
      description:
          'Orang tua dan guru bisa melihat perkembangan belajar, memberi catatan, dan mendampingi dari rumah.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    widget.state.completeOnboarding();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // Auto-navigate ketika sampai di slide terakhir (setelah delay singkat)
    if (index == _pages.length - 1) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _currentPage == _pages.length - 1) {
          widget.state.completeOnboarding();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, right: 16),
                    child: TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Lewati',
                        style: AppText.bodyStrong.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _OnboardingPage(data: page);
                    },
                  ),
                ),

                // Dot indicators
                Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : AppColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(32)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              data.asset,
              width: 240,
              height: 240,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: AppText.hero.copyWith(
              fontSize: 24,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 14),

          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: AppColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.asset,
    required this.title,
    required this.description,
  });

  final String asset;
  final String title;
  final String description;
}
