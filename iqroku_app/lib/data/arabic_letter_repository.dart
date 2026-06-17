import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/arabic_letter_models.dart';

class ArabicLetterRepository {
  const ArabicLetterRepository();

  static ArabicLetterGuide? _cached;

  Future<ArabicLetterGuide> load() async {
    if (_cached != null) {
      return _cached!;
    }

    final jsonStr = await rootBundle.loadString('assets/content/arabic_letters.json');
    final json = jsonDecode(jsonStr) as Map<String, Object?>;
    _cached = ArabicLetterGuide.fromJson(json);
    return _cached!;
  }

  Future<ArabicLetter?> getLetter(String arabic) async {
    final guide = await load();
    return guide.getLetter(arabic);
  }

  Future<String> getLatinName(String arabic) async {
    final guide = await load();
    return guide.getLatinName(arabic);
  }

  Future<String> getDescription(String arabic) async {
    final guide = await load();
    return guide.getDescription(arabic);
  }

  Future<String> getTips(String arabic) async {
    final guide = await load();
    return guide.getTips(arabic);
  }
}
