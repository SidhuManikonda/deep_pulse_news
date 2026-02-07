class NewsTranslation {
  final int id;
  final int newsId;
  final int languageId;
  final String title;
  final String slug;
  final String shortDescription;
  final String content;
  final DateTime createdAt;

  NewsTranslation({
    required this.id,
    required this.newsId,
    required this.languageId,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.content,
    required this.createdAt,
  });

  factory NewsTranslation.fromJson(Map<String, dynamic> json) {
    return NewsTranslation(
      id: json['id'] ?? 0,
      newsId: json['news_id'] ?? 0,
      languageId: json['lanuguage_id'] ?? 0, // Note: API has typo "lanuguage_id"
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      shortDescription: json['short_description'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'news_id': newsId,
      'lanuguage_id': languageId, // Keep API typo for consistency
      'title': title,
      'slug': slug,
      'short_description': shortDescription,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
