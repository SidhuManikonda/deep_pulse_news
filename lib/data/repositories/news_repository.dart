import 'package:flutter/foundation.dart';

import '../models/feed_ad.dart';
import '../models/news.dart';
import '../models/paginated_response.dart';
import '../models/create_news_request.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

/// One page of the mixed feed: the articles and the standalone adverts that
/// came back together, kept apart so each can be handled on its own terms.
class FeedPage {
  final List<News> news;
  final List<FeedAd> ads;
  final String? nextCursor;
  final bool hasMore;

  const FeedPage({
    required this.news,
    required this.ads,
    this.nextCursor,
    required this.hasMore,
  });
}

abstract class NewsRepository {
  /// [topicId] filters server-side (`?topic_id=`). Without it, a topic tab has
  /// to scan the whole date-ordered feed client-side — Jobs, for example, is
  /// roughly 1 in 40 articles, so a handful of pages yields one match.
  /// [search] queries the backend across the whole dataset (`?search=`),
  /// instead of only narrowing the pages already downloaded.
  ///
  /// [authorId] filters to one reporter's articles (`?author_id=`). Note this
  /// is NOT the same as [userId], which the backend ignores on this route —
  /// only `author_id` actually narrows the result set.
  Future<PaginatedResponse<News>> getNews({
    String? status,
    String? userId,
    String? cursor,
    int? topicId,
    String? search,
    int? authorId,

    /// Narrows to articles filed on or after [fromDate] and on or before
    /// [toDate], server-side, as `from_date` / `to_date` (`YYYY-MM-DD`).
    ///
    /// Filtering here rather than in the screen because the list is paged:
    /// the admin screen holds 20 of ~4,900 articles, so a local filter can
    /// only ever match within that page and any older date looks empty.
    DateTime? fromDate,
    DateTime? toDate,

    /// Narrows the feed to one mandal, server-side, via `mandal_id`.
    ///
    /// The only location filter the API honours: `district_id` and `state_id`
    /// are accepted and silently ignored (they come back with the unfiltered
    /// feed), while an unknown mandal 404s — so this one really is resolved.
    int? mandalId,
  });

  /// The same endpoint as [getNews], but keeping the standalone adverts the
  /// feed mixes in. Only the reader-facing feed wants them; every other caller
  /// (admin lists, deeplink lookups) uses [getNews] and never sees an ad.
  Future<FeedPage> getFeed({
    String? status,
    String? userId,
    String? cursor,
    int? topicId,
    String? search,
  });

  Future<News?> getNewsById(int id);
  Future<News?> createNews(CreateNewsRequest request);
  Future<News?> updateNews(int id, CreateNewsRequest request);
  Future<bool> deleteNews(int id);
  Future<bool> updateNewsStatus(int newsId, String status);
  Future<Map<String, dynamic>> shareNews(int newsId, String platform);
  Future<bool> saveNewsView(int newsId, String ipAddress);
  Future<bool> sendReport({
    required String type,
    required int itemId,
    required String reason,
    String? description,
  });
}

class NewsRepositoryImpl implements NewsRepository {
  final ApiService _apiService;

  NewsRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;
  @override
  Future<PaginatedResponse<News>> getNews({
    String? status,
    String? userId,
    String? cursor,
    int? topicId,
    String? search,
    int? authorId,
    DateTime? fromDate,
    DateTime? toDate,
    int? mandalId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) {
        queryParams['status'] = status;
      }
      if (userId != null) {
        queryParams['user_id'] = userId;
      }
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }
      if (topicId != null) {
        queryParams['topic_id'] = topicId.toString();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (authorId != null) {
        queryParams['author_id'] = authorId.toString();
      }
      if (mandalId != null) {
        queryParams['mandal_id'] = mandalId.toString();
      }
      // Dates only, no clock: the endpoint filters by day, and sending a
      // timestamp would make "today" depend on the device's timezone.
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      if (fromDate != null) {
        queryParams['from_date'] = ymd(fromDate);
      }
      if (toDate != null) {
        queryParams['to_date'] = ymd(toDate);
      }

      final response = await _apiService.get(
        AppConstants.news,
        queryParameters: queryParams,
        useAuth: userId != null,
        // A filter that matches nothing is a normal answer, not a failure.
        // The endpoint reports "no news found" as an error status, which
        // popped a red "Request Failed" banner over an empty list — so the
        // alert is suppressed here and the empty result handled below.
        showErrorAlert: false,
      );

      // Nothing matched: return an empty page rather than letting the caller
      // treat it as a broken request.
      if (response is Map && response.containsKey('error')) {
        debugPrint(
          '[NewsRepo] getNews non-200: status=${response['statusCode']} '
          'looksEmpty=${_looksEmpty(response)} body=${response['message']}',
        );
      }
      if (response is Map && _looksEmpty(response)) {
        // Growable, not `const []`: callers sort the list they get back, and
        // sorting a const list throws "Cannot modify an unmodifiable list".
        return PaginatedResponse(data: <News>[], perPage: 0, hasMore: false);
      }

      if (response is Map<String, dynamic> && response.containsKey('data')) {
        return PaginatedResponse.fromJson(
          response,
          News.fromJson,
          where: _isArticle,
        );
      }

      // Fallback for non-paginated response
      List<Map<String, dynamic>> newsData = [];
      if (response is List) {
        newsData = List<Map<String, dynamic>>.from(response);
      }
      return PaginatedResponse(
        data: newsData.map((json) => News.fromJson(json)).toList(),
        perPage: newsData.length,
        hasMore: false,
      );
    } catch (e, stack) {
      debugPrint('[NewsRepo] getNews threw: $e\n$stack');
      throw Exception('Failed to fetch news: $e');
    }
  }

  /// Feed items are discriminated by `type`. Anything that isn't explicitly an
  /// ad counts as an article, so responses from before adverts existed — which
  /// carry no `type` at all — still parse.
  static bool _isArticle(Map<String, dynamic> item) => item['type'] != 'ad';

  @override
  Future<FeedPage> getFeed({
    String? status,
    String? userId,
    String? cursor,
    int? topicId,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (userId != null) queryParams['user_id'] = userId;
      if (cursor != null) queryParams['cursor'] = cursor;
      if (topicId != null) queryParams['topic_id'] = topicId.toString();
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiService.get(
        AppConstants.news,
        queryParameters: queryParams,
        // Matches getNews: authenticated only when a user id is supplied, which
        // is what makes the response carry per-user like state.
        useAuth: userId != null,
      );

      if (response is! Map<String, dynamic>) {
        return const FeedPage(news: [], ads: [], hasMore: false);
      }

      // Same envelope as getNews: the paginator is either the top level or
      // nested under `data`.
      final rawData = response['data'];
      final page = rawData is Map<String, dynamic> ? rawData : response;
      final items =
          (page['data'] as List<dynamic>?)?.whereType<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      final news = <News>[];
      final ads = <FeedAd>[];
      for (final item in items) {
        if (_isArticle(item)) {
          news.add(News.fromJson(item));
        } else {
          // A creative that can't be resolved to a URL is dropped rather than
          // rendered as a blank full-screen page.
          var ad = FeedAd.tryParse(item);
          if (ad == null) {
            debugPrint(
              '[NewsRepo] feed ad ${item['id']} has no usable file '
              'url — keys: ${item.keys.join(', ')}',
            );
            continue;
          }

          // The feed is ordered by `updated_at`, and that timestamp is what
          // puts the ad back in the spot the backend chose once the app has
          // filtered the articles. If the payload omits it, borrow the time of
          // the article it arrived after, so the ad still lands there rather
          // than sinking to the bottom of the feed.
          if (ad.feedTime == null && news.isNotEmpty) {
            ad = ad.withFeedTime(news.last.displayTime);
          }
          ads.add(ad);
        }
      }

      final nextCursor = page['next_cursor'] as String?;
      return FeedPage(
        news: news,
        ads: ads,
        nextCursor: nextCursor,
        hasMore: nextCursor != null,
      );
    } catch (e) {
      throw Exception('Failed to fetch feed: $e');
    }
  }

  @override
  Future<News?> getNewsById(int id) async {
    // The backend exposes no `GET /news/{id}` route — `news/{id}` is POST-only
    // (used by updateNews). So we resolve a single article from the public list
    // endpoint (`GET /news`, which works) by matching on id, following the
    // cursor until we find it or run out of pages. Notification deeplinks point
    // at freshly published news, so the match is almost always on the first
    // page; the page bound is just a safety net against an unbounded scan.
    try {
      String? cursor;
      var pagesScanned = 0;
      const maxPages = 20;

      while (pagesScanned < maxPages) {
        final response = await getNews(cursor: cursor);
        for (final news in response.data) {
          if (news.id == id) return news;
        }
        pagesScanned++;
        if (!response.hasMore || response.nextCursor == null) break;
        cursor = response.nextCursor;
      }

      return null; // not found within the scanned range
    } catch (e) {
      // getNews() already wraps with "Failed to fetch news: ..." — rethrow as-is
      // to avoid a doubled-up message.
      rethrow;
    }
  }

  /// True when the endpoint's reply means "nothing matched" rather than
  /// "something went wrong".
  ///
  /// It answers an empty filter with an error-shaped body whose message is
  /// some wording of "no news found", so the two have to be told apart by the
  /// message rather than by the status alone.
  static bool _looksEmpty(Map response) {
    if (!response.containsKey('error') && !response.containsKey('message')) {
      return false;
    }
    // A list endpoint answering 404 means "nothing matched" — which is an
    // answer, not a fault. Checked before the wording so it holds whatever
    // phrasing the backend uses.
    final status = response['statusCode'];
    if (status is int && status == 404) return true;
    final text = '${response['message'] ?? ''} ${response['error'] ?? ''}'
        .toLowerCase();
    return text.contains('no news') ||
        text.contains('not found') ||
        text.contains('no records') ||
        text.contains('no data');
  }

  @override
  Future<News?> createNews(CreateNewsRequest request) async {
    try {
      final fields = request.toFormData();
      final response = await _apiService.postMultipart(
        AppConstants.news,
        fields: fields,
        files: request.files,
        fileFieldName: 'files[]',
        namedFiles: request.adFiles,
        useAuth: true,
        showErrorAlert: false,
      );
      debugPrint('[NewsRepo] POST /news raw response: $response');

      // If the server clearly saved something (id / news / data / a success
      // message), treat it as success even when an `error` key got tacked on
      // by a quirky non-2xx status code. Saw this with reader uploads: news
      // visible from admin, but Flutter would surface "Upload Failed" because
      // of a non-200 envelope.
      final body = response['news'] ?? response['data'];
      if (body is Map<String, dynamic>) {
        debugPrint(
          '[NewsRepo] POST /news response: is_important=${body['is_important']}, '
          'is_important (with trailing space)=${body['is_important ']}',
        );
        return News.fromJson(body);
      }

      if (_looksLikeCreatedDespiteError(response)) {
        debugPrint(
          '[NewsRepo] POST /news returned non-2xx but looks created '
          '(id/message present) — treating as success.',
        );
        return null;
      }

      if (response.containsKey('error')) {
        throw Exception(_extractReadableError(response));
      }

      return null;
    } catch (e) {
      throw Exception('Failed to create news: $e');
    }
  }

  /// Pulls the most useful error string from a Laravel-style failure
  /// envelope so the upload screen's snackbar shows something actionable
  /// instead of "Exception: Failed: 422". Order of preference:
  ///   1. First validation-error message from `errors.{field}[0]`
  ///   2. Top-level `message`
  ///   3. The raw `error` field we set ("Failed: 422" or similar)
  String _extractReadableError(Map<String, dynamic> response) {
    final errors = response['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstField = errors.values.first;
      if (firstField is List && firstField.isNotEmpty) {
        return firstField.first.toString();
      }
      if (firstField is String) return firstField;
    }
    final msg = response['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    return response['error']?.toString() ?? 'Unknown error';
  }

  /// Heuristic: response carried an `error` flag but the body still contains
  /// fields that suggest the server did create the record. Used so we don't
  /// scare the user when the API replies with a confusing envelope.
  bool _looksLikeCreatedDespiteError(Map<String, dynamic> response) {
    if (response['id'] != null) return true;
    final msg = response['message'];
    if (msg is String) {
      final lower = msg.toLowerCase();
      if (lower.contains('created') ||
          lower.contains('uploaded') ||
          lower.contains('success') ||
          lower.contains('saved')) {
        return true;
      }
    }

    // Known backend bug (Laravel 500): a post-save role-check calls
    // `$user->hasAnyRole()` which is undefined on the User model, so the
    // server returns 500 with:
    //   { message: "Something went wrong",
    //     error:   "Call to undefined method App\\Models\\User::hasAnyRole()" }
    // The news row is already committed before the exception fires —
    // verified by admin seeing the article in their list. Until the backend
    // patches hasAnyRole, treat this specific exception pattern as success
    // so reader uploads stop showing a false "Failed" toast.
    final err = response['error'];
    if (err is String &&
        err.contains('undefined method') &&
        err.contains('hasAnyRole')) {
      debugPrint(
        '[NewsRepo] ⚠️ Tolerating backend bug: User::hasAnyRole() '
        'undefined. News was likely saved — treating as success.',
      );
      return true;
    }
    return false;
  }

  @override
  Future<News?> updateNews(int id, CreateNewsRequest request) async {
    try {
      final fields = request.toFormData();
      debugPrint(
        '[NewsRepo] POST /news/$id fields: is_important=${fields['is_important']}, '
        'is_comment=${fields['is_comment']}, '
        'show_profile=${fields['show_profile']}, status=${fields['status']}, '
        'remove_ad_1=${fields['remove_ad_1']}, '
        'remove_ad_2=${fields['remove_ad_2']}, '
        'delete_media_ids=${fields.keys.where((k) => k.startsWith('delete_media_ids')).map((k) => fields[k]).join(',')}',
      );

      final response = await _apiService.postMultipart(
        '${AppConstants.news}/$id',
        fields: fields,
        files: request.files,
        fileFieldName: 'files[]',
        namedFiles: request.adFiles,
        useAuth: true,
        showErrorAlert: false,
      );
      debugPrint('[NewsRepo] POST /news/$id raw response: $response');

      final body = response['news'] ?? response['data'];
      if (body is Map<String, dynamic>) {
        debugPrint(
          '[NewsRepo] POST /news/$id response: '
          'is_important=${body['is_important']}, '
          'is_important (with trailing space)=${body['is_important ']}',
        );
        return News.fromJson(body);
      }

      if (_looksLikeCreatedDespiteError(response)) {
        debugPrint(
          '[NewsRepo] POST /news/$id returned non-2xx but looks updated '
          '(id/message present) — treating as success.',
        );
        return null;
      }

      if (response.containsKey('error')) {
        throw Exception(_extractReadableError(response));
      }

      return null;
    } catch (e) {
      throw Exception('Failed to update news: $e');
    }
  }

  @override
  Future<bool> deleteNews(int id) async {
    try {
      final response = await _apiService.delete(
        '${AppConstants.news}/$id',
        useAuth: true, // Require authentication for deleting news
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      return response.containsKey('success') || response['success'] == true;
    } catch (e) {
      throw Exception('Failed to delete news: $e');
    }
  }

  @override
  Future<bool> updateNewsStatus(int newsId, String status) async {
    try {
      final response = await _apiService.put(
        '${AppConstants.newsStatus}/$newsId',
        {'status': status},
        useAuth: true, // Require authentication for status updates
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      // Check for success by looking for message or news data
      return response.containsKey('message') || response.containsKey('news');
    } catch (e) {
      throw Exception('Failed to update news status: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> shareNews(int newsId, String platform) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.news}/shared',
        body: {'news_id': newsId, 'platform': platform},
        useAuth: true, // Require authentication for sharing
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      return response;
    } catch (e) {
      throw Exception('Failed to share news: $e');
    }
  }

  @override
  Future<bool> sendReport({
    required String type,
    required int itemId,
    required String reason,
    String? description,
  }) async {
    try {
      final body = {
        'type': type,
        'item_id': itemId.toString(),
        'reason': reason,
        if (description != null) 'description': description,
      };
      final response = await _apiService.post(
        AppConstants.report,
        body: body,
        useAuth: true,
      );

      if (response.containsKey('error')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> saveNewsView(int newsId, String ipAddress) async {
    try {
      final response = await _apiService.post(
        AppConstants.saveNewsView,
        body: {'news_id': newsId.toString(), 'ip_address': ipAddress},
        useAuth: true,
        showErrorAlert: false,
      );

      debugPrint('VIEW API RESPONSE: $response');

      if (response.containsKey('error')) {
        debugPrint('VIEW API ERROR: ${response['error']}');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('VIEW API EXCEPTION: $e');
      return false;
    }
  }
}
