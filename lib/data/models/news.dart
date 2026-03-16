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
  final String? authorName;
  final String? approverName;
  final int? isLiked;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final String shareUrl;
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
    this.authorName,
    this.approverName,
    this.isLiked,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    required this.translations,
    required this.media,
    required this.shareUrl,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      id: json['id'] ?? 0,
      authorId: json['author_id'] ?? 0,
      topicId: int.tryParse((json['topic_id'] ?? 0).toString()) ?? 0,
      stateId: int.tryParse((json['state_id'] ?? 0).toString()) ?? 0,
      districtId: int.tryParse((json['district_id'] ?? 0).toString()) ?? 0,
      mandalId: int.tryParse((json['mandal_id'] ?? 0).toString()) ?? 0,
      status: json['status'] ?? '',
      approvedBy: json['approved_by'],
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'])
          : null,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      authorName: json['author_name'] ?? '',
      approverName: json['approver_name'] ?? '',
      isLiked: json['is_liked'],
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      translations:
          (json['translations'] as List<dynamic>?)
              ?.map((translation) => NewsTranslation.fromJson(translation))
              .toList() ??
          [],
      media:
          (json['media'] as List<dynamic>?)
              ?.map((mediaItem) => NewsMedia.fromJson(mediaItem))
              .toList() ??
          [],
      shareUrl: json['share_url'] ?? '',
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
      'share_url': shareUrl,
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

  // Copy with method to update fields
  News copyWith({
    int? id,
    int? authorId,
    int? topicId,
    int? stateId,
    int? districtId,
    int? mandalId,
    String? status,
    int? approvedBy,
    DateTime? publishedAt,
    DateTime? createdAt,
    String? authorName,
    String? approverName,
    int? isLiked,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
    List<NewsTranslation>? translations,
    List<NewsMedia>? media,
    String? shareUrl,
  }) {
    return News(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      topicId: topicId ?? this.topicId,
      stateId: stateId ?? this.stateId,
      districtId: districtId ?? this.districtId,
      mandalId: mandalId ?? this.mandalId,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      authorName: authorName ?? this.authorName,
      approverName: approverName ?? this.approverName,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      translations: translations ?? this.translations,
      media: media ?? this.media,
      shareUrl: shareUrl ?? this.shareUrl,
    );
  }
}
