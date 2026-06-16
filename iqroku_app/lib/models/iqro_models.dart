import 'learning_status.dart';

class IqroBook {
  const IqroBook({
    required this.id,
    required this.title,
    required this.totalPages,
    required this.completedPages,
  });

  final int id;
  final String title;
  final int totalPages;
  final int completedPages;
}

class IqroPage {
  const IqroPage({
    required this.bookId,
    required this.pageNumber,
    required this.status,
  });

  final int bookId;
  final int pageNumber;
  final LearningStatus status;
}

class IqroContent {
  const IqroContent({required this.metadata, required this.books});

  final Map<String, Object?> metadata;
  final List<IqroMaterialBook> books;

  factory IqroContent.fromJson(Map<String, Object?> json) {
    final rawBooks = json['jilid'] as List<Object?>? ?? const [];
    return IqroContent(
      metadata: Map<String, Object?>.from(
        json['metadata'] as Map<String, Object?>? ?? const {},
      ),
      books: rawBooks
          .whereType<Map<String, Object?>>()
          .map(IqroMaterialBook.fromJson)
          .toList(growable: false),
    );
  }
}

class IqroMaterialBook {
  const IqroMaterialBook({
    required this.id,
    required this.title,
    required this.totalPages,
    required this.method,
    required this.mainTopics,
    required this.pages,
  });

  final int id;
  final String title;
  final int totalPages;
  final String? method;
  final List<String> mainTopics;
  final List<IqroMaterialPage> pages;

  IqroBook toBook({int completedPages = 0}) {
    return IqroBook(
      id: id,
      title: title,
      totalPages: totalPages,
      completedPages: completedPages,
    );
  }

  factory IqroMaterialBook.fromJson(Map<String, Object?> json) {
    final id = json['jilid'] as int? ?? 1;
    final rawPages = json['halaman'] as List<Object?>? ?? const [];
    final pages = rawPages
        .whereType<Map<String, Object?>>()
        .map((pageJson) => IqroMaterialPage.fromJson(id, pageJson))
        .toList(growable: false);

    return IqroMaterialBook(
      id: id,
      title: json['judul'] as String? ?? 'Iqro $id',
      totalPages: json['total_halaman'] as int? ?? pages.length,
      method: json['metode'] as String?,
      mainTopics: (json['topik_utama'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      pages: pages,
    );
  }
}

class IqroMaterialPage {
  const IqroMaterialPage({
    required this.bookId,
    required this.pageNumber,
    required this.newLetters,
    required this.instruction,
    required this.concept,
    required this.similarPairs,
    required this.lines,
  });

  final int bookId;
  final int pageNumber;
  final List<String> newLetters;
  final String? instruction;
  final String? concept;
  final List<List<String>> similarPairs;
  final List<List<String>> lines;

  String get title => 'Iqro $bookId - Halaman $pageNumber';
  bool get hasMaterial => lines.any((line) => line.isNotEmpty);

  factory IqroMaterialPage.fromJson(int bookId, Map<String, Object?> json) {
    return IqroMaterialPage(
      bookId: bookId,
      pageNumber: json['nomor'] as int? ?? 1,
      newLetters: (json['huruf_baru'] as List<Object?>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      instruction: json['instruksi'] as String?,
      concept: json['konsep'] as String?,
      similarPairs: _stringMatrix(json['pasangan_mirip']),
      lines: _stringMatrix(json['baris']),
    );
  }

  static List<List<String>> _stringMatrix(Object? value) {
    final rawRows = value as List<Object?>? ?? const [];
    return rawRows
        .map((row) {
          if (row is List<Object?>) {
            return row.whereType<String>().toList(growable: false);
          }
          if (row is String) {
            return [row];
          }
          return <String>[];
        })
        .toList(growable: false);
  }
}
