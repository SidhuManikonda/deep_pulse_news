/// A sponsor creative attached to an article, from the `ads` array on `/news`.
///
/// Modelled separately from [NewsMedia] on purpose. Adverts are not editorial
/// content: they have to be labelled, placed and (later) measured differently,
/// and giving them their own type stops one accidentally being rendered in the
/// story's photo carousel.
class NewsAd {
  final int id;

  /// Where the creative lives.
  final String url;

  /// `image` or `video`. Inferred from the file extension when the backend
  /// doesn't say.
  final String type;

  const NewsAd({required this.url, this.id = 0, this.type = 'image'});

  bool get isVideo => type == 'video';

  /// Builds an ad from whatever the backend sends, or null when there's no
  /// usable URL in it.
  ///
  /// Written defensively because no article carries an ad yet, so the exact
  /// element shape hasn't been observable. It accepts:
  ///   * a bare URL string, and
  ///   * an object keyed `file_url` / `url` / `path` / `image` / `ad`,
  ///     with the type under `media_type` / `type` / `file_type`.
  ///
  /// If the real shape turns out to be none of these, only this method needs
  /// to change.
  static NewsAd? tryParse(dynamic raw) {
    if (raw is String) {
      final url = raw.trim();
      return url.isEmpty ? null : NewsAd(url: url, type: _inferType(url));
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
      for (final key in ['media_type', 'type', 'file_type']) {
        final value = raw[key];
        if (value is String && value.trim().isNotEmpty) {
          declared = value.trim().toLowerCase();
          break;
        }
      }

      return NewsAd(
        id: raw['id'] is int ? raw['id'] as int : 0,
        url: url,
        // A declared type wins, but only when it's one we can render.
        type: (declared == 'video' || declared == 'image')
            ? declared!
            : _inferType(url),
      );
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
    'id': id,
    'file_url': url,
    'media_type': type,
  };
}
