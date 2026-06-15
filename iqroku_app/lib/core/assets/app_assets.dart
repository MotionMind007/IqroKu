class AppAssets {
  static const home = 'assets/icons/home.png';
  static const iqroBasic = 'assets/icons/iqro_basic.png';
  static const iqroBook = 'assets/icons/iqro_book.png';
  static const juzAmma = 'assets/icons/juz_amma.png';
  static const quran = 'assets/icons/quran.png';
  static const prayer = 'assets/icons/prayer.png';
  static const qibla = 'assets/icons/qibla.png';
  static const bookmark = 'assets/icons/bookmark.png';
  static const star = 'assets/icons/star.png';
  static const progress = 'assets/icons/progress.png';
  static const bookOpen = 'assets/icons/book_open.png';
  static const family = 'assets/icons/family.png';
  static const profile = 'assets/icons/profile.png';

  static String iqroBookByLevel(int level) {
    final safeLevel = level.clamp(1, 6);
    return 'assets/icons/iqro_$safeLevel.png';
  }
}
