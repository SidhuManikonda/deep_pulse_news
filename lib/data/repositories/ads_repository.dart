import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../models/feed_ad.dart';

/// Standalone adverts — the full-page creatives the reader feed weaves between
/// articles, managed independently of any news item.
///
/// Every route here is authenticated; the reader feed gets its ads inline from
/// `GET /news` instead and never touches these.
abstract class AdsRepository {
  /// [status] narrows to `published` / `unpublished`; omit for all.
  Future<List<FeedAd>> listAds({String? status});

  /// One ad by id, for a shared ad link. Public on the backend, so it works
  /// for a reader who isn't logged in. Null when it can't be loaded.
  Future<FeedAd?> getAd(int id);

  /// [media] is the creative — image or video — and [youtubeUrl] is the
  /// alternative to it. Exactly one of the two carries the ad: a slot holds a
  /// file or a link, never both, so [media] is optional here even on create.
  ///
  /// Returns null on success, or the server's reason for refusing. A bool
  /// would leave the screen with nothing to say beyond "it failed", and these
  /// uploads fail for specific, fixable reasons — wrong file type, file over
  /// the 50 MB cap, missing targeting — that the admin needs to be told.
  Future<String?> createAd({
    File? media,
    String? youtubeUrl,
    required String title,
    required bool isShareable,
    required bool isLikeable,
    required bool isReportable,
    required String status,
    required List<int> topicIds,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  });

  /// [media] is optional on update — omit it to keep the existing creative.
  /// Returns null on success, or the server's reason for refusing.
  Future<String?> updateAd({
    required int id,
    File? media,
    String? youtubeUrl,
    required String title,
    required bool isShareable,
    required bool isLikeable,
    required bool isReportable,
    required String status,
    required List<int> topicIds,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  });

  /// Toggles this reader's like on a published ad.
  ///
  /// Returns the like state and count the server settled on, or null when the
  /// call failed — the caller then puts its optimistic update back.
  Future<({bool liked, int count})?> toggleLike(int id);

  /// Records a share and returns the link to share and the new total, or null
  /// when the call failed — the caller then shares the ad's own URL instead.
  Future<({String? url, int count})?> recordShare(int id);

  Future<bool> publish(int id);
  Future<bool> unpublish(int id);

  /// Refreshes `updated_at`, which is what lifts the ad back up the feed.
  Future<bool> republish(int id);

  /// Soft delete — the file is kept so the ad can be restored.
  Future<bool> softDelete(int id);
  Future<bool> restore(int id);

  /// Permanent: removes the ad, its targeting rows and the stored file.
  Future<bool> forceDelete(int id);
}

class AdsRepositoryImpl implements AdsRepository {
  final ApiService _apiService;

  AdsRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<FeedAd?> getAd(int id) async {
    try {
      // Sends the token when there is one, so `is_liked` is this reader's.
      final response = await _apiService.get(
        '${AppConstants.ads}/$id',
        useAuth: true,
        showErrorAlert: false,
      );
      // {"message": …, "ad": {…}}
      final ad = response is Map ? response['ad'] : null;
      if (ad is! Map<String, dynamic>) {
        debugPrint('[AdsRepo] get $id: no ad in $response');
        return null;
      }
      return FeedAd.tryParse(ad);
    } catch (e) {
      debugPrint('[AdsRepo] get $id threw: $e');
      return null;
    }
  }

  @override
  Future<List<FeedAd>> listAds({String? status}) async {
    try {
      final response = await _apiService.get(
        AppConstants.ads,
        queryParameters: {
          'per_page': '50',
          if (status != null && status.isNotEmpty) 'status': status,
        },
        useAuth: true,
        showErrorAlert: false,
      );

      // The list may come back bare, under `data`, or inside a paginator —
      // the same three shapes the rest of this API uses.
      final items = _extractList(response);
      final parsed = items.map(FeedAd.tryParse).whereType<FeedAd>().toList();
      // An item that parses to null had no creative we recognised. Worth a
      // line, because on screen a discarded ad is indistinguishable from an
      // empty list.
      if (parsed.length != items.length) {
        debugPrint(
          '[AdsRepo] listAds dropped ${items.length - parsed.length} of '
          '${items.length} — no usable creative on those rows',
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('[AdsRepo] listAds failed: $e');
      return const [];
    }
  }

  static List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is List) {
      return response.whereType<Map<String, dynamic>>().toList();
    }
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      // Nested paginator: { data: { data: [...] } }
      if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
    return const [];
  }

  @override
  Future<String?> createAd({
    File? media,
    String? youtubeUrl,
    required String title,
    required bool isShareable,
    required bool isLikeable,
    required bool isReportable,
    required String status,
    required List<int> topicIds,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  }) {
    return _submit(
      path: AppConstants.ads,
      media: media,
      youtubeUrl: youtubeUrl,
      title: title,
      isShareable: isShareable,
      isLikeable: isLikeable,
      isReportable: isReportable,
      status: status,
      topicIds: topicIds,
      stateIds: stateIds,
      districtIds: districtIds,
      mandalIds: mandalIds,
    );
  }

  @override
  Future<String?> updateAd({
    required int id,
    File? media,
    String? youtubeUrl,
    required String title,
    required bool isShareable,
    required bool isLikeable,
    required bool isReportable,
    required String status,
    required List<int> topicIds,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  }) {
    // Update is a POST too, not a PUT — multipart can't ride on PUT here.
    return _submit(
      path: '${AppConstants.ads}/$id',
      media: media,
      youtubeUrl: youtubeUrl,
      title: title,
      isShareable: isShareable,
      isLikeable: isLikeable,
      isReportable: isReportable,
      status: status,
      topicIds: topicIds,
      stateIds: stateIds,
      districtIds: districtIds,
      mandalIds: mandalIds,
    );
  }

  @override
  Future<({bool liked, int count})?> toggleLike(int id) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.ads}/$id/like',
        body: const {},
        useAuth: true,
        showErrorAlert: false,
      );
      if (response.containsKey('error')) {
        debugPrint('[AdsRepo] like $id failed: $response');
        return null;
      }
      // The reply shape isn't pinned down, so read the usual spellings and
      // fall back to the data envelope some routes wrap results in.
      final data = response['data'] is Map ? response['data'] as Map : response;
      final liked =
          data['is_liked'] ?? data['liked'] ?? data['status'] ?? false;
      final counts = data['counts'];
      final count =
          (counts is Map ? counts['likes'] : null) ??
          data['likes_count'] ??
          data['count'];
      return (
        liked: FeedAd.parseFlag(liked, fallback: false),
        count: int.tryParse(count?.toString() ?? '') ?? 0,
      );
    } catch (e) {
      debugPrint('[AdsRepo] like $id threw: $e');
      return null;
    }
  }

  @override
  Future<({String? url, int count})?> recordShare(int id) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.ads}/$id/share',
        body: const {},
        useAuth: true,
        showErrorAlert: false,
      );
      if (response.containsKey('error')) {
        debugPrint('[AdsRepo] share $id failed: $response');
        return null;
      }
      // {"message": …, "share_url": "https://deeppulse.media/ads/123",
      //  "share_count": 1}
      final url = response['share_url']?.toString().trim();
      return (
        url: (url == null || url.isEmpty) ? null : url,
        count: int.tryParse(response['share_count']?.toString() ?? '') ?? 0,
      );
    } catch (e) {
      // A share that the backend never counted is still a share the reader
      // made, so this never interrupts them.
      debugPrint('[AdsRepo] share $id threw: $e');
      return null;
    }
  }

  Future<String?> _submit({
    required String path,
    File? media,
    String? youtubeUrl,
    required String title,
    required bool isShareable,
    required bool isLikeable,
    required bool isReportable,
    required String status,
    required List<int> topicIds,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  }) async {
    try {
      // Always sent, empty when the ad has no link, so clearing one on an
      // edit says so rather than leaving the backend to infer it.
      final fields = <String, dynamic>{
        'status': status,
        'youtube_url': youtubeUrl ?? '',
        'title': title,
        // Sent as 1/0 like every other boolean on these multipart routes.
        'is_shareable': isShareable ? '1' : '0',
        'is_likeable': isLikeable ? '1' : '0',
        'is_reportable': isReportable ? '1' : '0',
      };

      // Repeated keys, one row per id — the shape the API documents
      // (`state_id[]=1`, `state_id[]=2`). Indexed keys keep them distinct in
      // the multipart map while still arriving as an array server-side.
      void addAll(String key, List<int> ids) {
        for (var i = 0; i < ids.length; i++) {
          fields['$key[$i]'] = ids[i].toString();
        }
      }

      // Required by the endpoint (`topic_id => required|array|min:1`), so it
      // goes out ahead of the optional location targeting.
      addAll('topic_id', topicIds);
      addAll('state_id', stateIds);
      addAll('district_id', districtIds);
      addAll('mandal_id', mandalIds);

      final response = await _apiService.postMultipart(
        path,
        fields: fields,
        // The creative goes under `image` whether it's a photo or a video —
        // that's the field name the endpoint expects for both.
        namedFiles: media == null ? null : {'image': media},
        useAuth: true,
        showErrorAlert: false,
      );

      if (response.containsKey('error')) {
        // Log the whole envelope, not just the summary: a Laravel 422 puts the
        // useful part under `errors.{field}[0]`, and that's exactly the detail
        // that was being dropped while the screen said only "Could not save".
        debugPrint(
          '[AdsRepo] POST $path failed. Sent: $fields, '
          'file=${media?.path ?? 'none'}. Response: $response',
        );
        return _readableError(response);
      }
      return null;
    } catch (e) {
      debugPrint('[AdsRepo] POST $path threw: $e');
      return e.toString();
    }
  }

  /// Pulls the most useful line out of a Laravel-style failure envelope.
  ///
  /// Order matters, and it isn't the obvious one. On a 422 the detail lives in
  /// `errors.{field}[0]`, so that wins. On a 500 the envelope is
  /// `{message: "Something went wrong", error: "SQLSTATE[...] ..."}` — there
  /// `message` is a placeholder and `error` is the only thing that says what
  /// broke, so a specific `error` is preferred over `message`. The exception is
  /// the short "Failed: 500" string this app sets itself when the body carried
  /// nothing better; that's less useful than any real message.
  static String _readableError(Map<String, dynamic> response) {
    final errors = response['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstField = errors.values.first;
      if (firstField is List && firstField.isNotEmpty) {
        return firstField.first.toString();
      }
      if (firstField is String) return firstField;
    }

    final error = response['error']?.toString();
    final message = response['message']?.toString();

    final errorIsSpecific =
        error != null &&
        error.isNotEmpty &&
        !RegExp(r'^Failed:\s*\d+$').hasMatch(error.trim());
    if (errorIsSpecific) return error;

    if (message != null && message.isNotEmpty) return message;
    return error?.isNotEmpty == true ? error! : 'Unknown error';
  }

  @override
  Future<bool> publish(int id) => _action('${AppConstants.ads}/$id/publish');

  @override
  Future<bool> unpublish(int id) =>
      _action('${AppConstants.ads}/$id/unpublish');

  @override
  Future<bool> republish(int id) =>
      _action('${AppConstants.ads}/$id/republish');

  @override
  Future<bool> restore(int id) => _action('${AppConstants.ads}/$id/restore');

  Future<bool> _action(String path) async {
    try {
      final response = await _apiService.post(
        path,
        body: const {},
        useAuth: true,
        showErrorAlert: false,
      );
      if (response.containsKey('error')) {
        debugPrint('[AdsRepo] $path failed: ${response['error']}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[AdsRepo] $path threw: $e');
      return false;
    }
  }

  @override
  Future<bool> softDelete(int id) => _delete('${AppConstants.ads}/$id');

  @override
  Future<bool> forceDelete(int id) => _delete('${AppConstants.ads}/$id/force');

  Future<bool> _delete(String path) async {
    try {
      final response = await _apiService.delete(path, useAuth: true);
      if (response.containsKey('error')) {
        debugPrint('[AdsRepo] DELETE $path failed: ${response['error']}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[AdsRepo] DELETE $path threw: $e');
      return false;
    }
  }
}
