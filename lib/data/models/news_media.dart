class NewsMedia {
  final int id;
  final int newsId;
  final String type; // image, video, audio, etc.
  final String url;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final DateTime createdAt;

  NewsMedia({
    required this.id,
    required this.newsId,
    required this.type,
    required this.url,
    this.fileName,
    this.fileSize,
    this.mimeType,
    required this.createdAt,
  });

  factory NewsMedia.fromJson(Map<String, dynamic> json) {
    return NewsMedia(
      id: json['id'] ?? 0,
      newsId: json['news_id'] ?? 0,
      type: json['media_type'] ?? 'image',
      url: json['file_path'] ?? '',
      fileName: json['file_name'],
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'news_id': newsId,
      'type': type,
      'url': url,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
