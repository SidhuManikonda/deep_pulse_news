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

  /// `image` or `video`. Declared by the backend when it says, inferred from
  /// the file extension when it doesn't.
  final String mediaType;

  /// Where the ad was bought, in the same `{id, value, type}` shape articles
  /// use, so the feed can apply one location rule to news and ads alike.
  final List<NewsLocation> locations;

  /// `published`, `unpublished` or `draft`. Only meaningful in the
  /// management list — the reader feed only ever carries published ads.
  final String status;

  /// True once the ad has been soft-deleted; it can still be restored.
  final bool isDeleted;

  final DateTime? updatedAt;

  const FeedAd({
    required this.id,
    required this.url,
    this.mediaType = 'image',
    this.locations = const [],
    this.status = 'published',
    this.isDeleted = false,
    this.updatedAt,
  });

  bool get isVideo => mediaType == 'video';
  bool get isPublished => status.toLowerCase() == 'published';

  List<NewsLocation> get stateLocations =>
      locations.where((l) => l.isState).toList();
  List<NewsLocation> get districtLocations =>
      locations.where((l) => l.isDistrict).toList();
  List<NewsLocation> get mandalLocations =>
      locations.where((l) => l.isMandal).toList();

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
      status:
          (json['status'] as String?)?.trim().toLowerCase() ?? 'published',
      isDeleted: json['deleted_at'] != null,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
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
        final id = value is num ? value.toInt() : int.tryParse(value.toString());
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
