import 'package:flutter/material.dart';
import '../../data/models/news.dart';
import '../../data/repositories/news_repository.dart';

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
      final success = await _newsRepository.updateNewsStatus(
        newsId,
        'published',
      );
      if (success) {
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
