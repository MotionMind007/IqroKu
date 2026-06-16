import 'package:flutter/material.dart';

import '../core/assets/app_assets.dart';
import '../core/widgets/asset_icon.dart';
import '../features/activity/activity_screen.dart';
import '../features/home/home_screen.dart';
import '../features/learning/learning_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/prayers/daily_prayers_screen.dart';
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
          DailyPrayersScreen(state: state),
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
                selectedIndex: state.selectedTab > 4 ? 0 : state.selectedTab,
                height: 72,
                indicatorColor: const Color(0xFFE7F5EC),
                backgroundColor: Colors.white,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: state.selectTab,
                destinations: const [
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.navHome, size: 30),
                    selectedIcon: AssetIcon(
                      AppAssets.navHome,
                      size: 34,
                      selected: true,
                    ),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.navLearning, size: 30),
                    selectedIcon: AssetIcon(
                      AppAssets.navLearning,
                      size: 34,
                      selected: true,
                    ),
                    label: 'Belajar',
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.navQuran, size: 30),
                    selectedIcon: AssetIcon(
                      AppAssets.navQuran,
                      size: 34,
                      selected: true,
                    ),
                    label: "Qur'an",
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.navActivity, size: 30),
                    selectedIcon: AssetIcon(
                      AppAssets.navActivity,
                      size: 34,
                      selected: true,
                    ),
                    label: 'Jadwal',
                  ),
                  NavigationDestination(
                    icon: AssetIcon(AppAssets.navAccount, size: 30),
                    selectedIcon: AssetIcon(
                      AppAssets.navAccount,
                      size: 34,
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
