import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/news_repository.dart';

class NewsViewTrackerService {
  static final NewsViewTrackerService _instance =
      NewsViewTrackerService._internal();

  factory NewsViewTrackerService() => _instance;

  NewsViewTrackerService._internal();

  final NewsRepository _newsRepository = NewsRepositoryImpl();
  final Set<int> _viewedNewsIds = {};
  String? _cachedIdentifier;

  static const _deviceIdKey = 'device_view_id';

  /// TODO: Re-enable dedup after testing
  bool trackView(int newsId) {
    // Dedup disabled for testing — every scroll triggers a view
    // if (_viewedNewsIds.contains(newsId)) {
    //   return false;
    // }
    // _viewedNewsIds.add(newsId);
    return true;
  }

  /// Get a unique identifier for this device/user.
  /// Uses userId if logged in, otherwise a persistent random device ID.
  Future<String> _getIdentifier({int? userId}) async {
    if (userId != null) {
      _cachedIdentifier = '$userId';
      return _cachedIdentifier!;
    }

    if (_cachedIdentifier != null) return _cachedIdentifier!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = 'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await prefs.setString(_deviceIdKey, deviceId);
    }
    _cachedIdentifier = deviceId;
    return deviceId;
  }

  /// Records a view for the given news ID.
  Future<void> recordView(int newsId, {int? userId}) async {
    if (!trackView(newsId)) return;

    final identifier = await _getIdentifier(userId: userId);
    debugPrint('VIEW TRACK: newsId=$newsId, identifier=$identifier');
    final result = await _newsRepository.saveNewsView(newsId, identifier);
    debugPrint('VIEW TRACK RESULT: $result');
  }
}
