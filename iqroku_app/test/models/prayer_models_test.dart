import 'package:flutter_test/flutter_test.dart';
import 'package:iqroku/data/islamic_activity_service.dart';
import 'package:iqroku/models/prayer_models.dart';

void main() {
  group('PrayerTime', () {
    test('creates instance with defaults', () {
      const prayer = PrayerTime(
        name: 'Subuh',
        time: '04:37',
      );

      expect(prayer.name, 'Subuh');
      expect(prayer.time, '04:37');
      expect(prayer.active, false);
    });

    test('creates instance with active flag', () {
      const prayer = PrayerTime(
        name: 'Dzuhur',
        time: '11:53',
        active: true,
      );

      expect(prayer.active, true);
    });
  });

  group('PrayerSchedule', () {
    test('creates instance correctly', () {
      const schedule = PrayerSchedule(
        locationLabel: 'Jakarta, Indonesia',
        dateLabel: '17 Jun 2026 / 01 Muharram 1448 H',
        latitude: -6.2088,
        longitude: 106.8456,
        locationSource: LocationSource.device,
        times: [
          PrayerTime(name: 'Subuh', time: '04:37'),
          PrayerTime(name: 'Dzuhur', time: '11:53', active: true),
        ],
      );

      expect(schedule.locationLabel, 'Jakarta, Indonesia');
      expect(schedule.latitude, -6.2088);
      expect(schedule.longitude, 106.8456);
      expect(schedule.locationSource, LocationSource.device);
      expect(schedule.times.length, 2);
    });
  });

  group('QiblaDirection', () {
    test('creates instance correctly', () {
      const qibla = QiblaDirection(
        degrees: 295,
        latitude: -6.2088,
        longitude: 106.8456,
        locationLabel: 'Jakarta, Indonesia',
        locationSource: LocationSource.device,
      );

      expect(qibla.degrees, 295);
      expect(qibla.latitude, -6.2088);
      expect(qibla.longitude, 106.8456);
    });
  });

  group('DailyPrayer', () {
    test('fromJson with valid data', () {
      final json = {
        'id': 'doa-belajar',
        'title': 'Doa Sebelum Belajar',
        'category': 'Belajar',
        'arabic': 'رَبِّ زِدْنِي عِلْمًا',
        'latin': 'Rabbi zidnii ilman',
        'meaning': 'Ya Rabb, tambahkanlah ilmuku',
        'sortOrder': 10,
      };

      final prayer = DailyPrayer.fromJson(json);

      expect(prayer.id, 'doa-belajar');
      expect(prayer.title, 'Doa Sebelum Belajar');
      expect(prayer.category, 'Belajar');
      expect(prayer.arabic, 'رَبِّ زِدْنِي عِلْمًا');
      expect(prayer.latin, 'Rabbi zidnii ilman');
      expect(prayer.meaning, 'Ya Rabb, tambahkanlah ilmuku');
      expect(prayer.sortOrder, 10);
    });

    test('fromJson with missing optional fields', () {
      final json = {
        'id': 'doa-test',
        'title': 'Test Doa',
        'category': 'Test',
        'arabic': 'test',
        'meaning': 'test meaning',
      };

      final prayer = DailyPrayer.fromJson(json);

      expect(prayer.id, 'doa-test');
      expect(prayer.latin, '');
      expect(prayer.sortOrder, 100);
    });
  });

  group('LocationSource', () {
    test('has correct values', () {
      expect(LocationSource.values.length, 2);
      expect(LocationSource.values.contains(LocationSource.device), true);
      expect(LocationSource.values.contains(LocationSource.fallback), true);
    });
  });

  group('IslamicActivityException', () {
    test('stores message', () {
      const exception = IslamicActivityException('Location failed');

      expect(exception.message, 'Location failed');
    });
  });
}
