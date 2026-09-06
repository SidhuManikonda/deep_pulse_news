class NewsTranslation {
  final int id;
  final int newsId;
  final int languageId;
  final String title;
  final String slug;
  final String shortDescription;
  final String content;
  final DateTime createdAt;

  /// Optional title color hex ("#RRGGBB"). The backend returns it inside the
  /// translation. Null/blank when the author didn't pick one.
  final String? titleColor;

  /// Optional description color hex. Backend key is `content_color`.
  final String? descriptionColor;

  /// Optional full-article color hex. Backend key is `full_text_color`.
  final String? fullTextColor;

  NewsTranslation({
    required this.id,
    required this.newsId,
    required this.languageId,
    required this.title,
    required this.slug,
    required this.shortDescription,
    required this.content,
    required this.createdAt,
    this.titleColor,
    this.descriptionColor,
    this.fullTextColor,
  });

  static String? _cleanHex(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  factory NewsTranslation.fromJson(Map<String, dynamic> json) {
    return NewsTranslation(
      id: json['id'] ?? 0,
      newsId: json['news_id'] ?? 0,
      languageId: json['lanuguage_id'] ?? 0, // Note: API has typo "lanuguage_id"
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      shortDescription: json['short_description'] ?? '',
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      titleColor: _cleanHex(json['title_color']),
      descriptionColor: _cleanHex(json['content_color']),
      fullTextColor: _cleanHex(json['full_text_color']),
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
      if (titleColor != null) 'title_color': titleColor,
      if (descriptionColor != null) 'content_color': descriptionColor,
      if (fullTextColor != null) 'full_text_color': fullTextColor,
    };
  }
}
