/// Totals the backend reports alongside a page of news — counts across the
/// WHOLE dataset, not just the page in hand.
///
/// Sent under a top-level `counts` key:
/// ```json
/// { "counts": { "all": 1484, "important": 20, "pending": 172,
///               "published": 1283, "rejected": 29 },
///   "data": { "data": [ … ], "next_cursor": … } }
/// ```
class NewsStatusCounts {
  final int all;
  final int important;
  final int pending;
  final int published;
  final int rejected;

  const NewsStatusCounts({
    required this.all,
    required this.important,
    required this.pending,
    required this.published,
    required this.rejected,
  });

  factory NewsStatusCounts.fromJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return NewsStatusCounts(
      all: read('all'),
      important: read('important'),
      pending: read('pending'),
      published: read('published'),
      rejected: read('rejected'),
    );
  }

  /// Count for one of the app's status tabs, or null for a tab the backend
  /// doesn't report.
  int? forStatus(String status) {
    switch (status) {
      case 'all':
        return all;
      case 'important':
        return important;
      case 'pending':
        return pending;
      case 'published':
        return published;
      case 'rejected':
        return rejected;
      default:
        return null;
    }
  }
}

class PaginatedResponse<T> {
  final List<T> data;
  final String? nextCursor;
  final String? prevCursor;
  final int perPage;
  final bool hasMore;

  /// Whole-dataset totals, when the backend sends them. Null on the older
  /// response shape.
  final NewsStatusCounts? counts;

  PaginatedResponse({
    required this.data,
    this.nextCursor,
    this.prevCursor,
    required this.perPage,
    required this.hasMore,
    this.counts,
  });

  /// Reads either response shape.
  ///
  /// Old (still live today):
  ///   `{ "data": [ … ], "next_cursor": "…", "per_page": 20 }`
  ///
  /// New (adds totals and nests the paginator):
  ///   `{ "counts": { … }, "data": { "data": [ … ], "next_cursor": "…" } }`
  ///
  /// Told apart by whether `data` is a List or a Map, so both work without a
  /// coordinated release — the app keeps running on the current backend and
  /// picks up the counts the moment they start arriving.
  /// [where] filters raw items before they're parsed. The feed now carries
  /// standalone adverts alongside articles (told apart by a `type` field), and
  /// a caller that only wants one kind has to drop the other *before* parsing —
  /// running an ad payload through `News.fromJson` would yield a hollow article
  /// with no title rather than an error.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT, {
    bool Function(Map<String, dynamic>)? where,
  }) {
    final rawData = json['data'];
    final page = rawData is Map<String, dynamic> ? rawData : json;

    final dataList =
        (page['data'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((item) => where == null || where(item))
            .map(fromJsonT)
            .toList() ??
        const [];

    final rawCounts = json['counts'];

    return PaginatedResponse(
      data: dataList,
      nextCursor: page['next_cursor'] as String?,
      prevCursor: page['prev_cursor'] as String?,
      perPage: (page['per_page'] as num?)?.toInt() ?? 20,
      hasMore: page['next_cursor'] != null,
      counts: rawCounts is Map<String, dynamic>
          ? NewsStatusCounts.fromJson(rawCounts)
          : null,
    );
  }
}
