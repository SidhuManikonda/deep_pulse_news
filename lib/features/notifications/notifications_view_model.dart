import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/news.dart';
import '../../data/repositories/news_repository.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsViewModel extends ChangeNotifier {
  final NewsRepository _newsRepository;

  List<News> _pendingNews = [];
  bool _isLoading = false;
  String? _error;

  NotificationsViewModel({required NewsRepository newsRepository})
    : _newsRepository = newsRepository {
    loadPendingNews();
  }

  // Getters
  List<News> get pendingNews => _pendingNews;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load pending news for admin review
  Future<void> loadPendingNews() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _newsRepository.getNews(status: 'pending');
      _pendingNews = response.data;
          _pendingNews.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;

      return bDate.compareTo(aDate); // Descending (latest first)
    });
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh pending news
  Future<void> refreshPendingNews() async {
    await loadPendingNews();
  }

  // Approve news
  Future<bool> approveNews(int newsId) async {
    try {
      // Captured the article before it left the list, because the push needed
      // its title and locations. Only needed by the disabled push below.
      // final matches = _pendingNews.where((n) => n.id == newsId);
      // final approved = matches.isEmpty ? null : matches.first;

      final success = await _newsRepository.updateNewsStatus(
        newsId,
        'published',
      );
      if (success) {
        // DISABLED 2026-08-01 at backend's request — they are moving the push
        // trigger server-side (fires automatically when status becomes
        // `published`), so the app must not call /api/send-notification.
        // Kept, not deleted: re-enable only if that plan is dropped.
        //
        // if (approved != null) {
        //   unawaited(_fireNewsPushNotification(approved));
        // }
        // Remove the approved news from the list
        _pendingNews.removeWhere((news) => news.id == newsId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Notifies readers in the article's locations that it went live. Mirrors
  /// `_fireNewsPushNotification` in news_management_screen so both approval
  /// entry points produce an identical request. Failures are swallowed — a
  /// push problem must never look like a failed approval.
  ///
  /// Currently unused — the call site in [approveNews] is commented out
  /// because the backend now owns the publish trigger.
  // ignore: unused_element
  Future<void> _fireNewsPushNotification(News news) async {
    final title = news.translations.isNotEmpty
        ? news.translations.first.title.trim()
        : '';
    final body = news.translations.isNotEmpty
        ? news.translations.first.shortDescription.trim()
        : '';

    try {
      final result = await NotificationRepositoryImpl().sendNotification(
        title: title.isEmpty ? 'New News Posted' : title,
        body: body.isEmpty ? 'Check out the latest update' : body,
        target: NotificationTarget.all,
        stateIds: news.stateLocations.map((l) => l.id).toList(),
        districtIds: news.districtLocations.map((l) => l.id).toList(),
        mandalIds: news.mandalLocations.map((l) => l.id).toList(),
        data: {'type': 'news_published', 'news_id': news.id.toString()},
      );
      debugPrint(
        '[Notifications] push for news ${news.id}: '
        '${result == null ? 'FAILED' : 'success=${result.successCount}, '
              'failure=${result.failureCount}'}',
      );
    } catch (e) {
      debugPrint('[Notifications] sendNotification threw: $e');
    }
  }

  // Reject news
  Future<bool> rejectNews(int newsId) async {
    try {
      final success = await _newsRepository.updateNewsStatus(
        newsId,
        'rejected',
      );
      if (success) {
        // Remove the rejected news from the list
        _pendingNews.removeWhere((news) => news.id == newsId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
