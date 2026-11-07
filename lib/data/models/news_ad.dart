import '../../core/utils/youtube_url.dart';

/// A sponsor creative attached to an article, from the `ads` array on `/news`.
///
/// Modelled separately from [NewsMedia] on purpose. Adverts are not editorial
/// content: they have to be placed and (later) measured differently, and giving
/// them their own type stops one accidentally being rendered in the story's
/// photo carousel.
///
/// **An attached ad has no id.** The live payload is
/// `{"slot": 1, "file_url": "…/uploads/news/ads/3057/x.jpg"}` — a story's ads
/// are two files in a per-story folder, not rows in the `ads` table that the
/// standalone feed adverts live in (those do carry an `id`, and are managed by
/// the `/ads` routes). So the only handle on one of these is [slot], which is
/// also the slot it was uploaded under: `ad_1` or `ad_2`.
class NewsAd {
  /// Which of the article's two ad places this creative sits in — 1 or 2,
  /// matching the `ad_1` / `ad_2` upload fields. 0 when the backend didn't say
  /// and the position in the array couldn't stand in for it.
  final int slot;

  /// Where the creative lives.
  final String url;

  /// `image`, `video` or `youtube`. The first two are inferred from the file
  /// extension, which is all a file payload gives; `youtube` is set explicitly
  /// when the ad is a link rather than an upload.
  final String type;

  const NewsAd({required this.url, this.slot = 0, this.type = 'image'});

  /// Builds a YouTube-backed ad for [slot], or null when [url] isn't a
  /// YouTube link — a malformed one is no ad at all rather than a blank frame.
  static NewsAd? youtube({required String? url, required int slot}) {
    if (!YoutubeUrl.isValid(url)) return null;
    return NewsAd(url: url!.trim(), slot: slot, type: 'youtube');
  }

  bool get isVideo => type == 'video';

  /// A link to YouTube rather than a file we host. Rendered as a thumbnail
  /// that opens the YouTube app, so it plays nowhere inside this app.
  bool get isYoutube => type == 'youtube';

  /// Poster frame for a YouTube ad, null for anything else.
  String? get youtubeThumbnail => isYoutube ? YoutubeUrl.thumbnail(url) : null;

  /// Whether this ad can be addressed on the news update endpoint. False only
  /// for a payload that gave neither a slot nor a usable position.
  bool get hasSlot => slot == 1 || slot == 2;

  /// Builds an ad from whatever the backend sends, or null when there's no
  /// usable URL in it.
  ///
  /// [fallbackSlot] is the ad's 1-based position in the article's `ads` array,
  /// used when the element itself doesn't name a slot. The array comes back in
  /// slot order, so position and slot agree in practice; it's a fallback rather
  /// than the primary source because an article with only `ad_2` filled would
  /// make them disagree, and the element's own `slot` is the truth.
  ///
  /// Accepts a bare URL string as well as an object, since the shape has moved
  /// around during development.
  static NewsAd? tryParse(dynamic raw, {int fallbackSlot = 0}) {
    if (raw is String) {
      final url = raw.trim();
      if (url.isEmpty) return null;
      return NewsAd(url: url, slot: fallbackSlot, type: _inferType(url));
    }

    if (raw is Map) {
      String? url;
      for (final key in ['file_url', 'url', 'path', 'image', 'ad']) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) {
          url = value.trim();
          break;
        }
      }
      if (url == null) return null;

      String? declared;
      for (final key in ['media_type', 'file_type']) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) {
          declared = value.trim().toLowerCase();
          break;
        }
      }

      return NewsAd(
        slot: _parseSlot(raw) ?? fallbackSlot,
        url: url,
        // A declared type wins, but only when it's one we can render.
        type: (declared == 'video' || declared == 'image')
            ? declared!
            : _inferType(url),
      );
    }

    return null;
  }

  /// The slot, whether it arrives as a number or a numeric string.
  static int? _parseSlot(Map raw) {
    for (final key in ['slot', 'ad_slot', 'position']) {
      final value = raw[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static String _inferType(String url) {
    // Strip any query string first — a signed CDN URL ends in the signature,
    // not the extension.
    final path = url.toLowerCase().split('?').first;
    const videoExtensions = ['.mp4', '.mov', '.m3u8', '.webm', '.mkv', '.avi'];
    return videoExtensions.any(path.endsWith) ? 'video' : 'image';
  }

  Map<String, dynamic> toJson() => {
    'slot': slot,
    'file_url': url,
    'media_type': type,
  };
}
