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
