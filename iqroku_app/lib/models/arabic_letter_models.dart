class ArabicLetter {
  const ArabicLetter({
    required this.arabic,
    required this.latin,
    required this.description,
    required this.tips,
  });

  final String arabic;
  final String latin;
  final String description;
  final String tips;

  factory ArabicLetter.fromJson(String arabic, Map<String, Object?> json) {
    return ArabicLetter(
      arabic: arabic,
      latin: json['latin'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tips: json['tips'] as String? ?? '',
    );
  }
}

class ArabicLetterGuide {
  const ArabicLetterGuide({
    required this.letters,
    required this.fathah,
    required this.kasrah,
    required this.dammah,
    required this.sukun,
    required this.tasydid,
  });

  final Map<String, ArabicLetter> letters;
  final HarakatInfo fathah;
  final HarakatInfo kasrah;
  final HarakatInfo dammah;
  final HarakatInfo sukun;
  final HarakatInfo tasydid;

  ArabicLetter? getLetter(String arabic) {
    // Try exact match first
    if (letters.containsKey(arabic)) {
      return letters[arabic];
    }
    // Try without diacritics
    final cleaned = _removeDiacritics(arabic);
    return letters[cleaned];
  }

  String getLatinName(String arabic) {
    final letter = getLetter(arabic);
    return letter?.latin ?? arabic;
  }

  String getDescription(String arabic) {
    final letter = getLetter(arabic);
    return letter?.description ?? '';
  }

  String getTips(String arabic) {
    final letter = getLetter(arabic);
    return letter?.tips ?? '';
  }

  static String _removeDiacritics(String text) {
    // Remove common Arabic diacritics
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // Fathah, Kasrah, Dammah, etc.
        .replaceAll(RegExp(r'[\u0610-\u061A]'), '') // Additional marks
        .trim();
  }

  static ArabicLetterGuide fromJson(Map<String, Object?> json) {
    final lettersJson = json['letters'] as Map<String, Object?>? ?? {};
    final letters = <String, ArabicLetter>{};

    for (final entry in lettersJson.entries) {
      final letterJson = entry.value as Map<String, Object?>? ?? {};
      letters[entry.key] = ArabicLetter.fromJson(entry.key, letterJson);
    }

    return ArabicLetterGuide(
      letters: letters,
      fathah: _parseHarakat(json['fathah']),
      kasrah: _parseHarakat(json['kasrah']),
      dammah: _parseHarakat(json['dammah']),
      sukun: _parseHarakat(json['sukun']),
      tasydid: _parseHarakat(json['tasydid']),
    );
  }

  static HarakatInfo _parseHarakat(Object? json) {
    if (json is! Map<String, Object?>) {
      return const HarakatInfo(symbol: '', name: '', description: '', sound: '', example: '');
    }
    return HarakatInfo(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sound: json['sound'] as String? ?? '',
      example: json['example'] as String? ?? '',
    );
  }
}

class HarakatInfo {
  const HarakatInfo({
    required this.symbol,
    required this.name,
    required this.description,
    required this.sound,
    required this.example,
  });

  final String symbol;
  final String name;
  final String description;
  final String sound;
  final String example;
}
