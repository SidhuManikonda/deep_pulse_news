class NewsMedia {
  final int id;
  final int newsId;
  final String type; // image, video, audio, etc.
  final String filePath;
  final String fileUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  NewsMedia({
    required this.id,
    required this.newsId,
    required this.type,
    required this.filePath,
    required this.fileUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NewsMedia.fromJson(Map<String, dynamic> json) {
    return NewsMedia(
      id: json['id'] ?? 0,
      newsId: json['news_id'] ?? 0,
      type: json['media_type'] ?? 'image',
      filePath: json['file_path'] ?? '',
      fileUrl: json['file_url'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'news_id': newsId,
      'media_type': type,
      'file_path': filePath,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
