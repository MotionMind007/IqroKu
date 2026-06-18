class AppAssets {
  static const welcomePage = 'assets/brand/welcomepage.png';
  static const appLogo = 'assets/brand/logo.png';
  static const googleLogo = 'assets/brand/logo-google.webp';
  static const onboarding1 = 'assets/brand/onboarding_1.png';
  static const onboarding2 = 'assets/brand/onboarding_2.png';
  static const onboarding3 = 'assets/brand/onboarding_3.png';
  static const homeMosque = 'assets/brand/home_mosque.png';
  static const avatarMale = 'assets/brand/male-avatar.png';
  static const avatarFemale = 'assets/brand/female-avatar.png';
  static const parentAvatar = 'assets/brand/parent.png';
  static const boyKid = 'assets/brand/boykids.png';
  static const femaleKid = 'assets/brand/femalekids.png';

  static const home = 'assets/icons/home.png';
  static const navHome = 'assets/icons/nav_home.png';
  static const navLearning = 'assets/icons/nav_belajar.png';
  static const navQuran = 'assets/icons/nav_quran.png';
  static const navActivity = 'assets/icons/nav_aktivitas.png';
  static const navAccount = 'assets/icons/nav_akun.png';
  static const iqroBasic = 'assets/icons/iqro_basic.png';
  static const iqroBook = 'assets/icons/iqro_book.png';
  static const juzAmma = 'assets/icons/juz_amma.png';
  static const juzAmmaNew = 'assets/icons/juz_amma_new.png';
  static const murottal = 'assets/icons/murottal.png';
  static const kabah = 'assets/icons/kabah.png';
  static const doaDoa = 'assets/icons/doa_doa.png';
  static const quran = 'assets/icons/quran.png';
  static const quranNew = 'assets/icons/quran_new.png';
  static const prayer = 'assets/icons/prayer.png';
  static const prayerTime = 'assets/icons/prayer_time.png';
  static const qibla = 'assets/icons/qibla.png';
  static const qiblaCompass = 'assets/icons/qibla_compass.png';
  static const bookmark = 'assets/icons/bookmark.png';
  static const star = 'assets/icons/star.png';
  static const progress = 'assets/icons/progress.png';
  static const bookOpen = 'assets/icons/book_open.png';
  static const family = 'assets/icons/family.png';
  static const profile = 'assets/icons/profile.png';
  static const profileChild = 'assets/icons/profile_child.png';

  static String iqroBookByLevel(int level) {
    final safeLevel = level.clamp(1, 6);
    return 'assets/icons/iqro_$safeLevel.png';
  }
}
