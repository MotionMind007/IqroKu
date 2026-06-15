import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
    );
  }
}

class AppInsets {
  static const page = EdgeInsets.fromLTRB(18, 12, 18, 20);
}

class AppColors {
  static const canvas = Color(0xFFF8F6EF);
  static const surface = Color(0xFFFFFFFF);
  static const paper = Color(0xFFFFFBF1);
  static const cream = Color(0xFFFFF1C9);
  static const mint = Color(0xFFE7F5EC);
  static const line = Color(0xFFE7E1D6);
  static const text = Color(0xFF17201B);
  static const muted = Color(0xFF8D948F);
  static const primary = Color(0xFF23864B);
  static const primaryDark = Color(0xFF0F5B39);
  static const gold = Color(0xFFE2A83B);
  static const sun = Color(0xFFFFCA4F);
  static const coral = Color(0xFFE66C55);
  static const navy = Color(0xFF113F3C);
  static const blue = Color(0xFF4F8CC9);
  static const lavender = Color(0xFF9A79D6);
}

class AppText {
  static const hero = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    color: AppColors.text,
  );
  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    color: AppColors.text,
  );
  static const sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    color: AppColors.text,
  );
  static const bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.text,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.muted,
  );
  static const smallStrong = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
  static const mini = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.muted,
  );
  static const link = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );
  static const tileNumber = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: AppColors.text,
  );
  static const arabicList = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const arabicReader = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 2,
    color: AppColors.text,
  );
}

class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 6)),
  ];
  static const soft = [
    BoxShadow(color: Color(0x220F5B39), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
