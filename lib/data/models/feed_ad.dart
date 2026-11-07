import '../../core/utils/youtube_url.dart';
import 'news_location.dart';

/// A standalone advertisement — a paid item that occupies a whole feed page of
/// its own, rather than sitting inside an article the way [NewsAd] does.
///
/// The backend returns these inline in `GET /news`, discriminated by the item's
/// `type` field (`news` vs `ad`), ordered with the articles by `updated_at`.
/// An ad carries only a creative and its targeting — there is no headline, body
/// or click-through URL in the payload, which is why the card built from it is
/// all picture.
class FeedAd {
  final int id;

  /// The creative. One image or video file.
  final String url;

  /// `image`, `video` or `youtube`. The first two are declared by the backend
  /// when it says so and inferred from the file extension when it doesn't;
  /// `youtube` is set when the ad is a link rather than an uploaded file.
  final String mediaType;

  /// Where the ad was bought, in the same `{id, value, type}` shape articles
  /// use, so the feed can apply one location rule to news and ads alike.
  final List<NewsLocation> locations;

  /// Topics the ad is bought against. The save endpoint requires at least one
  /// (`topic_id => required|array|min:1`), so the edit form needs them back to
  /// re-submit an existing ad without the admin re-picking them every time.
  final List<int> topicIds;

  /// Optional headline shown over the creative. Blank for ads that are all
  /// picture, which is how every ad behaved before this field existed.
  final String title;

  /// What a reader is allowed to do with this ad, decided per ad by whoever
  /// sold it. Each one hides its button rather than showing a dead control.
  final bool isShareable;
  final bool isLikeable;
  final bool isReportable;

  /// Whether this reader has already liked it, and the running total. Parsed
  /// defensively: the list endpoint may not carry them, in which case the
  /// button starts unlit at zero and the server's reply corrects it.
  final bool isLiked;
  final int likesCount;

  /// Running share total, shown on the share button. Zero when the feed
  /// doesn't carry it; the share endpoint's reply corrects it.
  final int sharesCount;

  /// `published`, `unpublished` or `draft`. Only meaningful in the
  /// management list — the reader feed only ever carries published ads.
  final String status;

  /// True once the ad has been soft-deleted; it can still be restored.
  final bool isDeleted;

  final DateTime? updatedAt;

  /// When the ad went live. Preferred over [updatedAt] for ordering: editing
  /// an ad's title or toggling a reader action should not move it to the top
  /// of the feed, which is what sorting on `updated_at` did.
  final DateTime? publishedAt;

  const FeedAd({
    required this.id,
    required this.url,
    this.mediaType = 'image',
    this.locations = const [],
    this.topicIds = const [],
    this.title = '',
    this.isShareable = true,
    this.isLikeable = true,
    this.isReportable = true,
    this.isLiked = false,
    this.likesCount = 0,
    this.sharesCount = 0,
    this.status = 'published',
    this.isDeleted = false,
    this.updatedAt,
    this.publishedAt,
  });

  /// Where the ad belongs in the feed's ordering: when it went live, falling
  /// back to its last change only when the backend sent no publish date.
  DateTime? get feedTime => publishedAt ?? updatedAt;

  /// The link shared for this ad. On the API host because that is where
  /// `assetlinks.json` lives, so tapping it opens the app (Android App Links)
  /// and falls back to the backend's web page when the app isn't installed.
  String get shareLink => 'https://api.deeppulse.media/ads/$id';

  bool get isVideo => mediaType == 'video';

  /// A link to YouTube rather than a file we host, shown as a thumbnail that
  /// opens the YouTube app. Never played inside this app.
  bool get isYoutube => mediaType == 'youtube';

  /// Poster frame for a YouTube ad, null for anything else.
  String? get youtubeThumbnail => isYoutube ? YoutubeUrl.thumbnail(url) : null;

  bool get isPublished => status.toLowerCase() == 'published';

  List<NewsLocation> get stateLocations =>
      locations.where((l) => l.isState).toList();
  List<NewsLocation> get districtLocations =>
      locations.where((l) => l.isDistrict).toList();
  List<NewsLocation> get mandalLocations =>
      locations.where((l) => l.isMandal).toList();

  /// A copy carrying [time] as its publish date, for a payload that sent no
  /// timestamp of its own.
  ///
  /// Spelled out as a copy rather than rebuilding the ad inline, because a
  /// partial rebuild silently dropped the title, topics and reader-action
  /// flags — the ad came back intact but stripped of everything the feed
  /// needed to place and render it.
  FeedAd withFeedTime(DateTime time) => FeedAd(
    id: id,
    url: url,
    mediaType: mediaType,
    locations: locations,
    topicIds: topicIds,
    title: title,
    isShareable: isShareable,
    isLikeable: isLikeable,
    isReportable: isReportable,
    isLiked: isLiked,
    likesCount: likesCount,
    sharesCount: sharesCount,
    status: status,
    isDeleted: isDeleted,
    updatedAt: updatedAt,
    publishedAt: time,
  );

  /// A copy with the like state swapped, so the button can update before the
  /// server replies.
  FeedAd withLike({required bool liked, required int count}) => FeedAd(
    id: id,
    url: url,
    mediaType: mediaType,
    locations: locations,
    topicIds: topicIds,
    title: title,
    isShareable: isShareable,
    isLikeable: isLikeable,
    isReportable: isReportable,
    isLiked: liked,
    likesCount: count,
    sharesCount: sharesCount,
    status: status,
    isDeleted: isDeleted,
    updatedAt: updatedAt,
    publishedAt: publishedAt,
  );

  bool hasStateId(int id) => stateLocations.any((l) => l.id == id);
  bool hasDistrictId(int id) => districtLocations.any((l) => l.id == id);
  bool hasMandalId(int id) => mandalLocations.any((l) => l.id == id);

  /// Builds an ad from a feed item, or null when there's no usable creative.
  ///
  /// Written to accept several spellings because the ad endpoints are
  /// authenticated, so the exact response shape couldn't be observed while this
  /// was written — only the upload contract (`image`, `status`, `state_id[]`)
  /// from the Postman collection. Whichever key the backend actually returns,
  /// one of these matches; if it turns out to be none of them, this method is
  /// the only place that needs to change.
  static FeedAd? tryParse(Map<String, dynamic> json) {
    // A YouTube ad carries no uploaded file, so it's read first — otherwise
    // the file-URL search below finds nothing and discards the ad entirely.
    final youtube = json['youtube_url']?.toString();
    if (YoutubeUrl.isValid(youtube)) {
      return FeedAd(
        id: (json['id'] as num?)?.toInt() ?? 0,
        url: youtube!.trim(),
        mediaType: 'youtube',
        locations: _parseLocations(json),
        topicIds: _parseTopicIds(json),
        title: _parseTitle(json),
        isShareable: _flag(json['is_shareable']),
        isLikeable: _flag(json['is_likeable']),
        isReportable: _flag(json['is_reportable']),
        isLiked: _flag(json['is_liked'], fallback: false),
        likesCount: _parseCount(json, 'likes'),
        sharesCount: _parseCount(json, 'shares'),
        status:
            (json['status'] as String?)?.trim().toLowerCase() ?? 'published',
        isDeleted: json['deleted_at'] != null,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
        publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
      );
    }

    String? url;
    for (final key in [
      'image',
      'image_url',
      'file_url',
      'media_url',
      'url',
      'path',
      'file',
      'ad',
    ]) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        url = value.trim();
        break;
      }
      // Some payloads nest the file in an object of its own.
      if (value is Map) {
        for (final inner in ['file_url', 'url', 'path']) {
          final nested = value[inner];
          if (nested is String && nested.trim().isNotEmpty) {
            url = nested.trim();
            break;
          }
        }
        if (url != null) break;
      }
    }
    if (url == null) return null;

    // NOT read from `type` — at feed level that key holds the discriminator
    // ("ad"), so trusting it here would label every creative a non-video.
    String? declared;
    for (final key in ['media_type', 'file_type', 'mime_type']) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        declared = value.trim().toLowerCase();
        break;
      }
    }

    return FeedAd(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: url,
      mediaType: (declared != null && declared.contains('video'))
          ? 'video'
          : (declared != null && declared.contains('image'))
          ? 'image'
          : _inferType(url),
      locations: _parseLocations(json),
      topicIds: _parseTopicIds(json),
      title: _parseTitle(json),
      isShareable: _flag(json['is_shareable']),
      isLikeable: _flag(json['is_likeable']),
      isReportable: _flag(json['is_reportable']),
      isLiked: _flag(json['is_liked'], fallback: false),
      likesCount: _parseCount(json, 'likes'),
      sharesCount: _parseCount(json, 'shares'),
      status: (json['status'] as String?)?.trim().toLowerCase() ?? 'published',
      isDeleted: json['deleted_at'] != null,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    );
  }

  /// Reads a backend boolean, which arrives as `true`, `1`, `"1"` or `"true"`
  /// depending on the route.
  ///
  /// [fallback] is what an absent key means. The three permission flags default
  /// to true so a payload without them keeps the behaviour readers already had,
  /// rather than silently losing like, share and report.
  /// Exposed for the repository, which reads the same loose booleans back off
  /// the like endpoint's reply.
  static bool parseFlag(dynamic value, {bool fallback = true}) =>
      _flag(value, fallback: fallback);

  static bool _flag(dynamic value, {bool fallback = true}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    return text == '1' || text == 'true' || text == 'yes';
  }

  static String _parseTitle(Map<String, dynamic> json) {
    for (final key in ['title', 'ad_title', 'name']) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// Reads a total such as `likes` from `counts.likes` or `likes_count`.
  static int _parseCount(Map<String, dynamic> json, String name) {
    final counts = json['counts'];
    final raw = (counts is Map ? counts[name] : null) ?? json['${name}_count'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  /// Reads the ad's topics from whichever shape the payload uses: a `topics`
  /// array of objects, or a flat `topic_id` list like the one the form posts.
  ///
  /// Defensive for the same reason [_parseLocations] is — these routes are
  /// authenticated, so the exact response shape isn't pinned down here. An ad
  /// whose topics can't be read comes back empty, and the form then asks the
  /// admin to pick one rather than silently posting none.
  static List<int> _parseTopicIds(Map<String, dynamic> json) {
    final out = <int>{};
    void readId(dynamic entry) {
      if (entry is num) {
        out.add(entry.toInt());
      } else if (entry is Map) {
        final id = entry['id'] ?? entry['topic_id'];
        if (id is num) {
          out.add(id.toInt());
        } else if (id != null) {
          final parsed = int.tryParse(id.toString());
          if (parsed != null) out.add(parsed);
        }
      } else if (entry != null) {
        final parsed = int.tryParse(entry.toString());
        if (parsed != null) out.add(parsed);
      }
    }

    for (final key in ['topics', 'topic_id', 'topic_ids', 'topicIds']) {
      final value = json[key];
      if (value is List) {
        value.forEach(readId);
      } else if (value != null) {
        readId(value);
      }
      if (out.isNotEmpty) break;
    }

    // The feed (`GET /news`) sends no `topics` key at all: an ad's topics come
    // inside `locations` as entries typed "topic". Missing them made every
    // feed ad look untargeted, so it ran on every tab.
    if (out.isEmpty) {
      final locations = json['locations'];
      if (locations is List) {
        for (final entry in locations) {
          if (entry is Map && entry['type'] == 'topic') readId(entry);
        }
      }
    }
    return out.toList()..sort();
  }

  /// Reads targeting from either the `locations` array articles use, or the
  /// flat `state_id` / `district_id` / `mandal_id` lists the upload form posts.
  static List<NewsLocation> _parseLocations(Map<String, dynamic> json) {
    final raw = json['locations'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(NewsLocation.fromJson)
          .toList();
    }

    final out = <NewsLocation>[];
    void readIds(String key, String type) {
      final value = json[key] ?? json['${key}s'];
      if (value is List) {
        for (final entry in value) {
          final id = entry is num
              ? entry.toInt()
              : int.tryParse(entry.toString());
          if (id != null) out.add(NewsLocation(id: id, value: '', type: type));
        }
      } else if (value != null) {
        final id = value is num
            ? value.toInt()
            : int.tryParse(value.toString());
        if (id != null) out.add(NewsLocation(id: id, value: '', type: type));
      }
    }

    readIds('state_id', 'state');
    readIds('district_id', 'district');
    readIds('mandal_id', 'mandal');
    return out;
  }

  static String _inferType(String url) {
    // Strip the query first — a signed CDN URL ends in its signature, not the
    // file extension.
    final path = url.toLowerCase().split('?').first;
    const videoExtensions = ['.mp4', '.mov', '.m3u8', '.webm', '.mkv', '.avi'];
    return videoExtensions.any(path.endsWith) ? 'video' : 'image';
  }
}
