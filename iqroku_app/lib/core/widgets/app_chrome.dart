import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/app_theme.dart';

class AppPage extends StatelessWidget {
  const AppPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.canvas, Colors.white],
        ),
      ),
      child: child,
    );
  }
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
    this.onTrailing,
  });

  final String title;
  final IconData? trailing;
  final VoidCallback? onBack;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        Expanded(
          child: Text(title, textAlign: TextAlign.center, style: AppText.title),
        ),
        IconButton(
          onPressed: onTrailing,
          icon: Icon(trailing ?? Icons.more_horiz, size: 22),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onPressed,
  });

  final String title;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.sectionTitle)),
        if (action != null)
          TextButton(
            onPressed: onPressed,
            child: Text(action!, style: AppText.link),
          ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.initial, required this.color});

  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 27,
      backgroundColor: color,
      child: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.white,
        child: Text(
          initial,
          style: AppText.title.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.text,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
      onSelected: (_) => onTap(),
    );
  }
}

class PrayerHeroCard extends StatelessWidget {
  const PrayerHeroCard({
    super.key,
    this.compact = true,
    this.prayerName = 'Ashar',
    this.prayerTime = '15:35',
  });

  final bool compact;
  final String prayerName;
  final String prayerTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? 'Sholat berikutnya' : 'Jadwal aktif',
                  style: AppText.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  compact ? prayerName : '$prayerName $prayerTime',
                  style: AppText.hero.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  compact ? prayerTime : 'Berdasarkan lokasi aktif',
                  style: AppText.bodyStrong.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const MosqueIllustration(),
        ],
      ),
    );
  }
}

class MosqueIllustration extends StatelessWidget {
  const MosqueIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 86,
      child: Image.asset(AppAssets.homeMosque, fit: BoxFit.contain),
    );
  }
}
