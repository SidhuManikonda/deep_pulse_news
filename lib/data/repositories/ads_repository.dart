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

  /// [media] is the creative — image or video. Required on create.
  ///
  /// Returns null on success, or the server's reason for refusing. A bool
  /// would leave the screen with nothing to say beyond "it failed", and these
  /// uploads fail for specific, fixable reasons — wrong file type, file over
  /// the 50 MB cap, missing targeting — that the admin needs to be told.
  Future<String?> createAd({
    required File media,
    required String status,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  });

  /// [media] is optional on update — omit it to keep the existing creative.
  /// Returns null on success, or the server's reason for refusing.
  Future<String?> updateAd({
    required int id,
    File? media,
    required String status,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  });

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
      return items.map(FeedAd.tryParse).whereType<FeedAd>().toList();
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
    required File media,
    required String status,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  }) {
    return _submit(
      path: AppConstants.ads,
      media: media,
      status: status,
      stateIds: stateIds,
      districtIds: districtIds,
      mandalIds: mandalIds,
    );
  }

  @override
  Future<String?> updateAd({
    required int id,
    File? media,
    required String status,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  }) {
    // Update is a POST too, not a PUT — multipart can't ride on PUT here.
    return _submit(
      path: '${AppConstants.ads}/$id',
      media: media,
      status: status,
      stateIds: stateIds,
      districtIds: districtIds,
      mandalIds: mandalIds,
    );
  }

  Future<String?> _submit({
    required String path,
    File? media,
    required String status,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
  }) async {
    try {
      final fields = <String, dynamic>{'status': status};

      // Repeated keys, one row per id — the shape the API documents
      // (`state_id[]=1`, `state_id[]=2`). Indexed keys keep them distinct in
      // the multipart map while still arriving as an array server-side.
      void addAll(String key, List<int> ids) {
        for (var i = 0; i < ids.length; i++) {
          fields['$key[$i]'] = ids[i].toString();
        }
      }

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
        debugPrint('[AdsRepo] POST $path failed. Response: $response');
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
