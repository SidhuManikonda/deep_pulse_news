import 'news_translation.dart';
import 'news_media.dart';

class News {
  final int id;
  final int authorId;
  final int topicId;
  final int stateId;
  final int districtId;
  final int mandalId;
  final String status; // pending, published, rejected
  final int? approvedBy;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final List<NewsTranslation> translations;
  final List<NewsMedia> media;

  News({
    required this.id,
    required this.authorId,
    required this.topicId,
    required this.stateId,
    required this.districtId,
    required this.mandalId,
    required this.status,
    this.approvedBy,
    this.publishedAt,
    required this.createdAt,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    required this.translations,
    required this.media,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'] ?? 0,
      authorId: json['author_id'] ?? 0,
      topicId: json['topic_id'] ?? 0,
      stateId: json['state_id'] ?? 0,
      districtId: json['district_id'] ?? 0,
      mandalId: json['mandal_id'] ?? 0,
      status: json['status'] ?? 'pending',
      approvedBy: json['approved_by'],
      publishedAt: json['published_at'] != null 
          ? DateTime.parse(json['published_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      translations: (json['translations'] as List<dynamic>?)
          ?.map((translation) => NewsTranslation.fromJson(translation))
          .toList() ?? [],
      media: (json['media'] as List<dynamic>?)
          ?.map((mediaItem) => NewsMedia.fromJson(mediaItem))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'topic_id': topicId,
      'state_id': stateId,
      'district_id': districtId,
      'mandal_id': mandalId,
      'status': status,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'comments_count': commentsCount,
      'shares_count': sharesCount,
      'views_count': viewsCount,
      'translations': translations.map((t) => t.toJson()).toList(),
      'media': media.map((m) => m.toJson()).toList(),
    };
  }

  // Helper method to get primary translation (first one or by language)
  NewsTranslation? getPrimaryTranslation([int? languageId]) {
    if (translations.isEmpty) return null;
    
    if (languageId != null) {
      try {
        return translations.firstWhere((t) => t.languageId == languageId);
      } catch (e) {
        // If language not found, return first translation
        return translations.first;
      }
    }
    
    return translations.first;
  }

  // Helper method to get primary media (first image)
  NewsMedia? getPrimaryMedia([String type = 'image']) {
    if (media.isEmpty) return null;
    
    try {
      return media.firstWhere((m) => m.type == type);
    } catch (e) {
      // If type not found, return first media
      return media.first;
    }
  }
}
