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
