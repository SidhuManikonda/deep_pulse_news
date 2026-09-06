import 'news_translation.dart';
import 'news_media.dart';
import 'news_ad.dart';
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
  final DateTime? updatedAt;
  final String? authorName;
  final String? authorProfilePhoto;
  final String? authorRoleName;

  /// The reporter's own district / mandal — where the story was filed from,
  /// as opposed to `locations`, which is where it was published to. Null
  /// until the backend adds them to the `author` object.
  final String? authorDistrictName;
  final String? authorMandalName;

  /// Sponsor creatives attached to the article, from the `ads` array.
  ///
  /// Kept apart from [media] deliberately: these are adverts, and the UI must
  /// label and place them differently from the article's own photos.
  final List<NewsAd> ads;
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

  /// Optional title color as a hex string (e.g. "#FF3366" or "#AARRGGBB").
  /// Null when the author didn't pick one — UI falls back to the theme color.
  final String? titleColor;

  /// Optional description color hex. Backend key is `content_color`.
  final String? descriptionColor;

  /// Optional full-article color hex. Backend key is `full_text_color`.
  final String? fullTextColor;

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
    this.updatedAt,
    this.authorName,
    this.authorProfilePhoto,
    this.authorRoleName,
    this.authorDistrictName,
    this.authorMandalName,
    this.ads = const [],
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
    this.titleColor,
    this.descriptionColor,
    this.fullTextColor,
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
    final authorProfilePhoto = authorObj is Map
        ? (authorObj['profile_photo']?.toString())
        : (json['author_profile_photo']?.toString());
    final authorRoleName = authorObj is Map
        ? (authorObj['author_role_name']?.toString() ??
              authorObj['role_name']?.toString())
        : (json['author_role_name']?.toString());

    // Where the reporter filed from — distinct from `locations`, which is
    // where an editor chose to publish the story. A state-wide publish carries
    // hundreds of districts and says nothing about the story's origin, so a
    // dateline can only come from here.
    //
    // Not sent by the backend yet; the several key spellings are so it starts
    // working the moment it is, without another app release.
    String? authorPlace(List<String> keys) {
      if (authorObj is! Map) return null;
      for (final key in keys) {
        final value = authorObj[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is Map) {
          final name = value['name'];
          if (name is String && name.trim().isNotEmpty) return name.trim();
        }
      }
      return null;
    }

    final authorDistrictName = authorPlace(['district_name', 'district']);
    final authorMandalName = authorPlace(['mandal_name', 'mandal']);

    // Adverts come back under `ads`. Uploads still go up as ad_1 / ad_2, so
    // those flat keys are read as a fallback in case a response echoes them.
    final adsJson = json['ads'];
    final adsList = <NewsAd>[];
    if (adsJson is List) {
      for (final entry in adsJson) {
        final ad = NewsAd.tryParse(entry);
        if (ad != null) adsList.add(ad);
      }
    }
    if (adsList.isEmpty) {
      for (final key in ['ad_1', 'ad_2']) {
        final ad = NewsAd.tryParse(json[key]);
        if (ad != null) adsList.add(ad);
      }
    }

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
          createdAt:
              DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
          titleColor: json['title_color'] as String?,
          descriptionColor: json['content_color'] as String?,
          fullTextColor: json['full_text_color'] as String?,
        ),
      ];
    }

    // Colors may arrive top-level OR inside the translation (backend puts them
    // with the translation). Prefer top-level, fall back to the primary
    // translation, then normalize blank → null.
    String? resolveColor(String key, String? Function(NewsTranslation) pick) {
      final raw =
          (json[key] as String?) ??
          (translationsList.isNotEmpty ? pick(translationsList.first) : null);
      return (raw != null && raw.trim().isNotEmpty) ? raw.trim() : null;
    }

    final resolvedTitleColor = resolveColor('title_color', (t) => t.titleColor);
    final resolvedDescriptionColor = resolveColor(
      'content_color',
      (t) => t.descriptionColor,
    );
    final resolvedFullTextColor = resolveColor(
      'full_text_color',
      (t) => t.fullTextColor,
    );

    // authorId (the user's id) may be at top-level 'user_id', 'author_id',
    // or nested in 'author.id' / 'author.user_id'
    final authorObjForId = json['author'] is Map ? json['author'] as Map : null;
    final authorId =
        json['user_id'] ??
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
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      authorName: authorName,
      authorProfilePhoto: authorProfilePhoto,
      authorRoleName: authorRoleName,
      authorDistrictName: authorDistrictName,
      authorMandalName: authorMandalName,
      ads: adsList,
      approverName: approverName,
      isLiked: json['is_liked'],
      likesCount: likesCount,
      dislikesCount: dislikesCount,
      commentsCount: commentsCount,
      sharesCount: sharesCount,
      viewsCount: viewsCount,
      isImportant:
          _toBool(json['is_important']) || _toBool(json['is_important ']),
      showProfile: json.containsKey('show_profile')
          ? _toBool(json['show_profile'])
          : true,
      isComment: json.containsKey('is_comment')
          ? _toBool(json['is_comment'])
          : true,
      titleColor: resolvedTitleColor,
      descriptionColor: resolvedDescriptionColor,
      fullTextColor: resolvedFullTextColor,
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
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'comments_count': commentsCount,
      'dislikes_count': dislikesCount,
      'shares_count': sharesCount,
      'views_count': viewsCount,
      'is_important': isImportant ? 1 : 0,
      'show_profile': showProfile ? 1 : 0,
      'is_comment': isComment ? 1 : 0,
      // Same key fromJson reads, so a saved article keeps its ads when it
      // round-trips through local storage.
      'ads': ads.map((a) => a.toJson()).toList(),
      if (titleColor != null) 'title_color': titleColor,
      if (descriptionColor != null) 'content_color': descriptionColor,
      if (fullTextColor != null) 'full_text_color': fullTextColor,
      'translations': translations.map((t) => t.toJson()).toList(),
      'media': media.map((m) => m.toJson()).toList(),
      'share_url': shareUrl,
      'locations': locations.map((l) => l.toJson()).toList(),
    };
  }

  /// Time to show in the UI: prefer `updated_at` so edits surface as
  /// "Just now / Xm ago" instead of frozen at the original create time.
  /// Falls back to `created_at` when the API doesn't return `updated_at`
  /// (older responses, cached models built before the field was added).
  DateTime get displayTime => updatedAt ?? createdAt;

  /// True when the article has been edited at least once. Useful for
  /// optionally annotating the timestamp with "(edited)" in the UI.
  bool get isEdited {
    if (updatedAt == null) return false;
    // Treat any updated_at within 2 seconds of created_at as the original
    // creation (some backends stamp both in the same transaction with a
    // microsecond delta).
    return updatedAt!.difference(createdAt).inSeconds > 2;
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

  /// True when there is at least one advert to show.
  bool get hasAds => ads.isNotEmpty;

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
    DateTime? updatedAt,
    String? authorName,
    String? authorProfilePhoto,
    String? authorRoleName,
    String? authorDistrictName,
    String? authorMandalName,
    List<NewsAd>? ads,
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
    String? titleColor,
    String? descriptionColor,
    String? fullTextColor,
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
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: authorName ?? this.authorName,
      authorProfilePhoto: authorProfilePhoto ?? this.authorProfilePhoto,
      authorRoleName: authorRoleName ?? this.authorRoleName,
      authorDistrictName: authorDistrictName ?? this.authorDistrictName,
      authorMandalName: authorMandalName ?? this.authorMandalName,
      ads: ads ?? this.ads,
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
      titleColor: titleColor ?? this.titleColor,
      descriptionColor: descriptionColor ?? this.descriptionColor,
      fullTextColor: fullTextColor ?? this.fullTextColor,
      translations: translations ?? this.translations,
      media: media ?? this.media,
      shareUrl: shareUrl ?? this.shareUrl,
      locations: locations ?? this.locations,
    );
  }
}
