import '../models/iqro_models.dart';
import '../models/learning_status.dart';
import '../models/prayer_models.dart';
import '../models/profile_models.dart';
import '../models/quran_models.dart';

class DummyIqrokuRepository {
  const DummyIqrokuRepository();

  List<IqroBook> get iqroBooks => const [
    IqroBook(id: 1, title: 'Iqro 1', totalPages: 28, completedPages: 8),
    IqroBook(id: 2, title: 'Iqro 2', totalPages: 32, completedPages: 0),
    IqroBook(id: 3, title: 'Iqro 3', totalPages: 29, completedPages: 0),
    IqroBook(id: 4, title: 'Iqro 4', totalPages: 27, completedPages: 0),
    IqroBook(id: 5, title: 'Iqro 5', totalPages: 25, completedPages: 0),
    IqroBook(id: 6, title: 'Iqro 6', totalPages: 24, completedPages: 0),
  ];

  List<IqroPage> pagesForBook(int bookId, LearningStatus selectedStatus) {
    return List.generate(12, (index) {
      final page = index + 1;
      final status = switch (page) {
        1 || 2 => LearningStatus.fluent,
        3 || 7 => LearningStatus.learning,
        4 => LearningStatus.review,
        8 => selectedStatus,
        _ => LearningStatus.notStarted,
      };
      return IqroPage(bookId: bookId, pageNumber: page, status: status);
    });
  }

  List<Surah> get surahs => const [
    Surah(
      id: 1,
      name: 'Al-Fatihah',
      meaning: 'Pembuka',
      arabicName: 'الفاتحة',
      ayahCount: 7,
      juz: 1,
    ),
    Surah(
      id: 114,
      name: 'An-Nas',
      meaning: 'Manusia',
      arabicName: 'الناس',
      ayahCount: 6,
      juz: 30,
    ),
    Surah(
      id: 113,
      name: 'Al-Falaq',
      meaning: 'Waktu Subuh',
      arabicName: 'الفلق',
      ayahCount: 5,
      juz: 30,
    ),
    Surah(
      id: 112,
      name: 'Al-Ikhlas',
      meaning: 'Ikhlas',
      arabicName: 'الإخلاص',
      ayahCount: 4,
      juz: 30,
    ),
    Surah(
      id: 111,
      name: 'Al-Lahab',
      meaning: 'Gejolak Api',
      arabicName: 'اللهب',
      ayahCount: 5,
      juz: 30,
    ),
    Surah(
      id: 110,
      name: 'An-Nasr',
      meaning: 'Pertolongan',
      arabicName: 'النصر',
      ayahCount: 3,
      juz: 30,
    ),
  ];

  AyahPreview get readerPreview => const AyahPreview(
    arabic:
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\nقُلْ هُوَ اللَّهُ أَحَدٌ\nاللَّهُ الصَّمَدُ',
    translation:
        'Katakanlah: Dialah Allah, Yang Maha Esa. Allah tempat meminta segala sesuatu.',
  );

  List<PrayerTime> get prayerTimes => const [
    PrayerTime(name: 'Imsak', time: '04:27'),
    PrayerTime(name: 'Subuh', time: '04:37'),
    PrayerTime(name: 'Terbit', time: '05:54'),
    PrayerTime(name: 'Dzuhur', time: '11:53'),
    PrayerTime(name: 'Ashar', time: '15:35', active: true),
    PrayerTime(name: 'Maghrib', time: '17:48'),
    PrayerTime(name: 'Isya', time: '19:01'),
  ];

  List<ChildProfile> get children => const [
    ChildProfile(
      id: 'nedy',
      name: 'Nedy',
      age: 7,
      currentLesson: 'Iqro 1 - Halaman 8',
      progress: 0.60,
    ),
    ChildProfile(
      id: 'aisyah',
      name: 'Aisyah',
      age: 8,
      currentLesson: 'Iqro 2 - Halaman 12',
      progress: 0.40,
    ),
    ChildProfile(
      id: 'yusuf',
      name: 'Yusuf',
      age: 9,
      currentLesson: 'Hafal 8 surat',
      progress: 0.75,
    ),
  ];

  List<LearningNote> get learningNotes => const [
    LearningNote(
      title: 'Iqro 1 - Halaman 7',
      date: '15 Mei 2026',
      status: LearningStatus.fluent,
      note: 'Sudah lancar, perhatikan panjang pendek bacaan.',
    ),
    LearningNote(
      title: 'Iqro 1 - Halaman 4',
      date: '14 Mei 2026',
      status: LearningStatus.review,
      note: 'Masih tertukar antara bentuk huruf yang mirip.',
    ),
    LearningNote(
      title: 'Iqro 1 - Halaman 2',
      date: '12 Mei 2026',
      status: LearningStatus.learning,
      note: 'Mulai memahami huruf sambung. Tetap semangat!',
    ),
  ];
}
