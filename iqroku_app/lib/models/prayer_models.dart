class PrayerTime {
  const PrayerTime({
    required this.name,
    required this.time,
    this.active = false,
  });

  final String name;
  final String time;
  final bool active;
}

class PrayerSchedule {
  const PrayerSchedule({
    required this.locationLabel,
    required this.dateLabel,
    required this.times,
    required this.latitude,
    required this.longitude,
    required this.locationSource,
  });

  final String locationLabel;
  final String dateLabel;
  final List<PrayerTime> times;
  final double latitude;
  final double longitude;
  final LocationSource locationSource;
}

class QiblaDirection {
  const QiblaDirection({
    required this.degrees,
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
    required this.locationSource,
  });

  final double degrees;
  final double latitude;
  final double longitude;
  final String locationLabel;
  final LocationSource locationSource;
}

enum LocationSource { device, fallback }

class DailyPrayer {
  const DailyPrayer({
    required this.id,
    required this.title,
    required this.category,
    required this.arabic,
    required this.latin,
    required this.meaning,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String category;
  final String arabic;
  final String latin;
  final String meaning;
  final int sortOrder;

  static DailyPrayer fromJson(Map<String, Object?> json) {
    return DailyPrayer(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Doa',
      category: json['category'] as String? ?? 'Harian',
      arabic: json['arabic'] as String? ?? '',
      latin: json['latin'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 100,
    );
  }
}
