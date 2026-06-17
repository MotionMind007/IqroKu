import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/data/quran_api_service.dart';
import 'package:iqroku/models/quran_models.dart';

void main() {
  group('Surah', () {
    test('creates instance with all fields', () {
      const surah = Surah(
        id: 1,
        name: 'Al-Fatihah',
        meaning: 'Pembuka',
        arabicName: 'الفاتحة',
        ayahCount: 7,
        juz: 1,
      );

      expect(surah.id, 1);
      expect(surah.name, 'Al-Fatihah');
      expect(surah.meaning, 'Pembuka');
      expect(surah.arabicName, 'الفاتحة');
      expect(surah.ayahCount, 7);
      expect(surah.juz, 1);
    });
  });

  group('QuranAyah', () {
    test('creates instance with required fields', () {
      const ayah = QuranAyah(
        number: 1,
        arabic: 'بسم الله الرحمن الرحيم',
        translation: 'Dengan nama Allah Yang Maha Pengasih',
      );

      expect(ayah.number, 1);
      expect(ayah.arabic, 'بسم الله الرحمن الرحيم');
      expect(ayah.translation, 'Dengan nama Allah Yang Maha Pengasih');
      expect(ayah.latin, null);
      expect(ayah.audioUrl, null);
    });

    test('creates instance with optional fields', () {
      const ayah = QuranAyah(
        number: 1,
        arabic: 'بسم الله الرحمن الرحيم',
        translation: 'Dengan nama Allah Yang Maha Pengasih',
        latin: 'Bismillaahir Rahmaanir Rahiim',
        audioUrl: 'https://example.com/audio.mp3',
      );

      expect(ayah.latin, 'Bismillaahir Rahmaanir Rahiim');
      expect(ayah.audioUrl, 'https://example.com/audio.mp3');
    });
  });

  group('SurahDetail', () {
    test('creates instance correctly', () {
      const surah = Surah(
        id: 1,
        name: 'Al-Fatihah',
        meaning: 'Pembuka',
        arabicName: 'الفاتحة',
        ayahCount: 7,
        juz: 1,
      );

      const detail = SurahDetail(
        surah: surah,
        audioUrl: 'https://example.com/fatihah.mp3',
        ayahs: [
          QuranAyah(
            number: 1,
            arabic: 'بسم الله الرحمن الرحيم',
            translation: 'Dengan nama Allah Yang Maha Pengasih',
          ),
        ],
      );

      expect(detail.surah.id, 1);
      expect(detail.audioUrl, 'https://example.com/fatihah.mp3');
      expect(detail.ayahs.length, 1);
    });
  });

  group('AyahPreview', () {
    test('creates instance correctly', () {
      const preview = AyahPreview(
        arabic: 'بسم الله الرحمن الرحيم',
        translation: 'Dengan nama Allah Yang Maha Pengasih',
      );

      expect(preview.arabic, 'بسم الله الرحمن الرحيم');
      expect(preview.translation, 'Dengan nama Allah Yang Maha Pengasih');
    });
  });

  group('QuranApiException', () {
    test('stores message', () {
      const exception = QuranApiException('Failed to fetch');

      expect(exception.message, 'Failed to fetch');
    });
  });
}
