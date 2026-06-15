import 'package:flutter/material.dart';

import '../core/assets/app_assets.dart';
import '../core/widgets/asset_icon.dart';
import '../features/activity/activity_screen.dart';
import '../features/home/home_screen.dart';
import '../features/learning/learning_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quran/quran_screen.dart';
import 'app_state.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final pages = [
          HomeScreen(state: state),
          LearningScreen(state: state),
          QuranScreen(state: state),
          ActivityScreen(state: state),
          ProfileScreen(state: state),
        ];

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: pages[state.selectedTab],
              ),
            ),
          ),
          bottomNavigationBar: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: NavigationBar(
                selectedIndex: state.selectedTab,
                height: 72,
                indicatorColor: const Color(0xFFE7F5EC),
                backgroundColor: Colors.white,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: state.selectTab,
                destinations: const [
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.home, size: 28),
                    selectedIcon: AssetIcon(
                      AppAssets.home,
                      size: 32,
                      selected: true,
                    ),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.iqroBook, size: 28),
                    selectedIcon: AssetIcon(
                      AppAssets.iqroBook,
                      size: 32,
                      selected: true,
                    ),
                    label: 'Belajar',
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.quran, size: 28),
                    selectedIcon: AssetIcon(
                      AppAssets.quran,
                      size: 32,
                      selected: true,
                    ),
                    label: "Qur'an",
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.prayer, size: 28),
                    selectedIcon: AssetIcon(
                      AppAssets.prayer,
                      size: 32,
                      selected: true,
                    ),
                    label: 'Aktivitas',
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.profile, size: 28),
                    selectedIcon: AssetIcon(
                      AppAssets.profile,
                      size: 32,
                      selected: true,
                    ),
                    label: 'Akun',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
