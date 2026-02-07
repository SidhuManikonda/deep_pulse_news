import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/onboarding_storage.dart';
import '../../data/models/create_news_request.dart';
import '../../data/repositories/news_repository.dart';

final newsUploadViewModelProvider = ChangeNotifierProvider<NewsUploadViewModel>(
  (ref) => NewsUploadViewModel(),
);

class NewsUploadViewModel extends ChangeNotifier {
  final NewsRepository _newsRepository = NewsRepositoryImpl();
  final OnboardingStorage _storage = OnboardingStorage();

  bool _isUploading = false;
  String? _error;

  bool get isUploading => _isUploading;
  String? get error => _error;

  Future<bool>  uploadNews({
    required String headline,
    required String description,
    required String content,
    required String category,
    required List<File> mediaFiles,
  }) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      // Get user's location data
      final state = await _storage.getSelectedState();
      final district = await _storage.getSelectedDistrict();
      final mandal = await _storage.getSelectedMandal();

      if (state == null || district == null || mandal == null) {
        _error = 'Location data not found. Please complete onboarding first.';
        _isUploading = false;
        notifyListeners();
        return false;
      }

      // Map category to topic ID (you may need to adjust these mappings)
      final topicId = _getCategoryTopicId(category);

      // Create news request
      final newsRequest = CreateNewsRequest(
        topicId: topicId,
        status: 'pending', // News needs approval
        title: headline,
        slug: _generateSlug(headline),
        shortDescription: description,
        content: content.isNotEmpty ? content : description,
        stateId: state.id,
        districtId: district.id,
        mandalId: mandal.id,
        files: mediaFiles,
      );

      // Upload news
      await _newsRepository.createNews(newsRequest);
      
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload news: $e';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  int _getCategoryTopicId(String category) {
    // Map category names to topic IDs
    // You may need to adjust these based on your actual topic IDs from the API
    switch (category) {
      case 'Your Area':
        return 1;
      case 'State':
        return 2;
      case 'National / International':
        return 3;
      case 'Cinema':
        return 4;
      case 'Games':
        return 5;
      case 'Special':
        return 6;
      case 'Mobiles / Electronics':
        return 7;
      case 'Education':
        return 8;
      default:
        return 1; // Default to 'Your Area'
    }
  }

  String _generateSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .trim();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
