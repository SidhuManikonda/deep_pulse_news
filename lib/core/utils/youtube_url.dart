
class YoutubeUrl {
  const YoutubeUrl._();

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static String? videoId(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;

    if (_id.hasMatch(text)) return text;

    final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
    if (uri == null) return null;

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final isYoutube =
        host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com' ||
        host == 'youtu.be';
    if (!isYoutube) return null;

    if (host == 'youtu.be') return _valid(uri.pathSegments.firstOrNull);

    final query = uri.queryParameters['v'];
    if (query != null) return _valid(query);

    // youtube.com/{shorts,embed,v,live}/<id>
    final segments = uri.pathSegments;
    if (segments.length >= 2 &&
        const {'shorts', 'embed', 'v', 'live'}.contains(segments.first)) {
      return _valid(segments[1]);
    }
    return null;
  }

  static String? _valid(String? candidate) {
    final value = candidate?.trim();
    if (value == null || !_id.hasMatch(value)) return null;
    return value;
  }

  static bool isValid(String? raw) => videoId(raw) != null;

  /// Poster frame for [raw]. `hqdefault` is used rather than `maxresdefault`
  /// because every video has one — maxres is absent on older and low-quality
  /// uploads, which would leave those ads blank.
  static String? thumbnail(String? raw) {
    final id = videoId(raw);
    return id == null ? null : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  /// Canonical watch URL, for handing to the YouTube app.
  static String? watchUrl(String? raw) {
    final id = videoId(raw);
    return id == null ? null : 'https://www.youtube.com/watch?v=$id';
  }
}
