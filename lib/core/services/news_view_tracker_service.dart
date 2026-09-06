import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/news_repository.dart';

/// Tracks news article views with two guards layered on top of the API call:
///
///   1. **Dwell time (10s).** The user must actually stay on an article for
///      at least 10 seconds. Quickly scrolling past several articles never
///      registers any of them.
///   2. **Per-article cooldown (5m).** The same identifier (logged-in user
///      or persistent guest id) doesn't double-count the same article inside
///      a 5-minute window — useful when a user scrolls back to a story.
///
/// Call [scheduleView] when the user lands on an article and
/// [cancelPendingView] when they leave (e.g. on PageView change, screen
/// dispose, app backgrounding). The dwell timer only fires the API once
/// both rules are satisfied.
class NewsViewTrackerService {
  static final NewsViewTrackerService _instance =
      NewsViewTrackerService._internal();

  factory NewsViewTrackerService() => _instance;

  NewsViewTrackerService._internal();

  final NewsRepository _newsRepository = NewsRepositoryImpl();
  String? _cachedIdentifier;

  static const _deviceIdKey = 'device_view_id';

  // Tunables — keep in code so backend changes don't need a redeploy of
  // either side. If the product wants different windows, change here.
  static const Duration _dwellTime = Duration(seconds: 10);
  static const Duration _cooldown = Duration(minutes: 1);

  // Per-article last-recorded timestamp. In-memory only — resets when the
  // app process dies, which is fine for "noise control" purposes.
  final Map<int, DateTime> _lastViewedAt = {};

  // Exactly one dwell timer is pending at a time — the article currently on
  // screen. Cancelled the moment the user moves on.
  Timer? _pendingDwellTimer;
  int? _pendingNewsId;

  /// Start the 10s dwell countdown for [newsId]. If the user is still
  /// looking at this article when the timer fires AND this article is past
  /// its 5-minute cooldown, the view is recorded.
  ///
  /// [onCounted] runs after the view is accepted (post-dwell, post-cooldown).
  /// Use it to bump the local UI counter.
  void scheduleView(int newsId, {int? userId, VoidCallback? onCounted}) {
    // Already counting down for this exact article — leave it alone.
    if (_pendingNewsId == newsId) return;

    cancelPendingView();

    // Cooldown shortcut: skip the timer entirely if we already counted
    // this article inside the last 5 minutes.
    final last = _lastViewedAt[newsId];
    if (last != null && DateTime.now().difference(last) < _cooldown) {
      debugPrint(
        '[NewsViewTracker] skip newsId=$newsId — within '
        '${_cooldown.inMinutes}min cooldown '
        '(last ${DateTime.now().difference(last).inSeconds}s ago)',
      );
      return;
    }

    _pendingNewsId = newsId;
    debugPrint(
      '[NewsViewTracker] scheduled newsId=$newsId — '
      'fires in ${_dwellTime.inSeconds}s',
    );
    _pendingDwellTimer = Timer(_dwellTime, () async {
      _pendingDwellTimer = null;
      _pendingNewsId = null;
      // Re-check cooldown — a parallel detail-screen open could have
      // recorded the view in the meantime.
      final last = _lastViewedAt[newsId];
      if (last != null && DateTime.now().difference(last) < _cooldown) return;
      _lastViewedAt[newsId] = DateTime.now();
      onCounted?.call();
      await _fireView(newsId, userId: userId);
    });
  }

  /// Cancel the pending dwell timer (user scrolled away, screen closed).
  void cancelPendingView() {
    if (_pendingDwellTimer != null) {
      debugPrint(
        '[NewsViewTracker] cancelled pending newsId=$_pendingNewsId',
      );
    }
    _pendingDwellTimer?.cancel();
    _pendingDwellTimer = null;
    _pendingNewsId = null;
  }

  /// Direct view record — skips dwell (caller already decided it's a
  /// genuine view, e.g. detail screen opened) but still respects cooldown.
  Future<void> recordView(int newsId, {int? userId}) async {
    final last = _lastViewedAt[newsId];
    if (last != null && DateTime.now().difference(last) < _cooldown) {
      debugPrint(
        '[NewsViewTracker] recordView skip newsId=$newsId — within cooldown',
      );
      return;
    }
    _lastViewedAt[newsId] = DateTime.now();
    await _fireView(newsId, userId: userId);
  }

  Future<void> _fireView(int newsId, {int? userId}) async {
    final identifier = await _getIdentifier(userId: userId);
    debugPrint(
      '[NewsViewTracker] firing newsId=$newsId, identifier=$identifier',
    );
    final result = await _newsRepository.saveNewsView(newsId, identifier);
    debugPrint('[NewsViewTracker] result newsId=$newsId → $result');
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
      deviceId =
          'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await prefs.setString(_deviceIdKey, deviceId);
    }
    _cachedIdentifier = deviceId;
    return deviceId;
  }
}
