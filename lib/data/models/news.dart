import 'news_translation.dart';
import 'news_media.dart';
import 'news_location.dart';

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
  final int dislikesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final bool isImportant;
  final bool showProfile;
  final bool isComment;
  final String shareUrl;
  final List<NewsTranslation> translations;
  final List<NewsMedia> media;
  final List<NewsLocation> locations;

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
    required this.dislikesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    this.isImportant = false,
    this.showProfile = true,
    this.isComment = true,
    required this.translations,
    required this.media,
    required this.shareUrl,
    required this.locations,
  });

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  factory News.fromJson(Map<String, dynamic> json) {
    // Handle nested 'counts' object (new API) or flat fields (old API)
    final counts = json['counts'] as Map<String, dynamic>?;
    final likesCount = counts?['likes'] ?? json['likes_count'] ?? 0;
    final dislikesCount = counts?['dislikes'] ?? json['dislikes_count'] ?? 0;
    final commentsCount = counts?['comments'] ?? json['comments_count'] ?? 0;
    final sharesCount = counts?['shares'] ?? json['shares_count'] ?? 0;
    final viewsCount = counts?['views'] ?? json['views_count'] ?? 0;

    // Handle nested 'author' object (new API) or flat field (old API)
    final authorObj = json['author'];
    final authorName = authorObj is Map
        ? (authorObj['name'] ?? '')
        : (json['author_name'] ?? '');

    // Handle nested 'approver' object (new API) or flat field (old API)
    final approverObj = json['approver'];
    final approverName = approverObj is Map
        ? (approverObj['name'] ?? '')
        : (json['approver_name'] ?? '');

    // Handle media as single object (new API) or list (old API)
    List<NewsMedia> mediaList = [];
    final mediaJson = json['media'];
    if (mediaJson is List) {
      mediaList = mediaJson
          .map((m) => NewsMedia.fromJson(m as Map<String, dynamic>))
          .toList();
    } else if (mediaJson is Map<String, dynamic>) {
      mediaList = [NewsMedia.fromJson(mediaJson)];
    }

    // Handle translations list (old API) or build from top-level fields (new API)
    List<NewsTranslation> translationsList = [];
    final translationsJson = json['translations'];
    if (translationsJson is List && translationsJson.isNotEmpty) {
      translationsList = translationsJson
          .map((t) => NewsTranslation.fromJson(t as Map<String, dynamic>))
          .toList();
    } else if (json['title'] != null) {
      // New API: title, slug, short_description, content are top-level
      translationsList = [
        NewsTranslation(
          id: 0,
          newsId: json['id'] ?? 0,
          languageId: 0,
          title: json['title'] ?? '',
          slug: json['slug'] ?? '',
          shortDescription: json['short_description'] ?? '',
          content: json['content'] ?? '',
          createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        ),
      ];
    }

    // authorId (the user's id) may be at top-level 'user_id', 'author_id',
    // or nested in 'author.id' / 'author.user_id'
    final authorObjForId = json['author'] is Map ? json['author'] as Map : null;
    final authorId = json['user_id'] ??
        json['author_id'] ??
        authorObjForId?['id'] ??
        authorObjForId?['user_id'] ??
        0;

    return News(
      id: json['id'] ?? 0,
      authorId: authorId,
      topicId: int.tryParse((json['topic_id'] ?? 0).toString()) ?? 0,
      stateId: int.tryParse((json['state_id'] ?? 0).toString()) ?? 0,
      districtId: int.tryParse((json['district_id'] ?? 0).toString()) ?? 0,
      mandalId: int.tryParse((json['mandal_id'] ?? 0).toString()) ?? 0,
      status: json['status'] ?? '',
      approvedBy: json['approved_by'],
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      authorName: authorName,
      approverName: approverName,
      isLiked: json['is_liked'],
      likesCount: likesCount,
      dislikesCount: dislikesCount,
      commentsCount: commentsCount,
      sharesCount: sharesCount,
      viewsCount: viewsCount,
      isImportant: _toBool(json['is_important']) || _toBool(json['is_important ']),
      showProfile: json.containsKey('show_profile') ? _toBool(json['show_profile']) : true,
      isComment: json.containsKey('is_comment') ? _toBool(json['is_comment']) : true,
      translations: translationsList,
      media: mediaList,
      shareUrl: json['share_url'] ?? '',
      locations:
          (json['locations'] as List<dynamic>?)
              ?.map((loc) => NewsLocation.fromJson(loc as Map<String, dynamic>))
              .toList() ??
          [],
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
      'dislikes_count': dislikesCount,
      'shares_count': sharesCount,
      'views_count': viewsCount,
      'is_important': isImportant ? 1 : 0,
      'show_profile': showProfile ? 1 : 0,
      'is_comment': isComment ? 1 : 0,
      'translations': translations.map((t) => t.toJson()).toList(),
      'media': media.map((m) => m.toJson()).toList(),
      'share_url': shareUrl,
      'locations': locations.map((l) => l.toJson()).toList(),
    };
  }

  // Location helper methods
  List<NewsLocation> get topicLocations =>
      locations.where((l) => l.isTopic).toList();
  List<NewsLocation> get stateLocations =>
      locations.where((l) => l.isState).toList();
  List<NewsLocation> get districtLocations =>
      locations.where((l) => l.isDistrict).toList();
  List<NewsLocation> get mandalLocations =>
      locations.where((l) => l.isMandal).toList();

  bool hasTopicId(int id) => topicLocations.any((l) => l.id == id);
  bool hasStateId(int id) => stateLocations.any((l) => l.id == id);
  bool hasDistrictId(int id) => districtLocations.any((l) => l.id == id);
  bool hasMandalId(int id) => mandalLocations.any((l) => l.id == id);

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
    int? dislikesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
    bool? isImportant,
    bool? showProfile,
    bool? isComment,
    List<NewsTranslation>? translations,
    List<NewsMedia>? media,
    String? shareUrl,
    List<NewsLocation>? locations,
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
      dislikesCount: dislikesCount ?? this.dislikesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isImportant: isImportant ?? this.isImportant,
      showProfile: showProfile ?? this.showProfile,
      isComment: isComment ?? this.isComment,
      translations: translations ?? this.translations,
      media: media ?? this.media,
      shareUrl: shareUrl ?? this.shareUrl,
      locations: locations ?? this.locations,
    );
  }
}
