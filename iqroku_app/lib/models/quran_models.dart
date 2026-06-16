class Surah {
  const Surah({
    required this.id,
    required this.name,
    required this.meaning,
    required this.arabicName,
    required this.ayahCount,
    required this.juz,
  });

  final int id;
  final String name;
  final String meaning;
  final String arabicName;
  final int ayahCount;
  final int juz;
}

class AyahPreview {
  const AyahPreview({required this.arabic, required this.translation});

  final String arabic;
  final String translation;
}

class QuranAyah {
  const QuranAyah({
    required this.number,
    required this.arabic,
    required this.translation,
    this.latin,
    this.audioUrl,
  });

  final int number;
  final String arabic;
  final String translation;
  final String? latin;
  final String? audioUrl;
}

class SurahDetail {
  const SurahDetail({required this.surah, required this.ayahs, this.audioUrl});

  final Surah surah;
  final List<QuranAyah> ayahs;
  final String? audioUrl;
}
