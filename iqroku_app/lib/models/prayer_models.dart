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
