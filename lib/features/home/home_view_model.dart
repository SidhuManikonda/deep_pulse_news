import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/onboarding_storage.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/news.dart';
import '../../data/repositories/news_repository.dart';

// Provider for HomeViewModel
final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>((ref) {
  return HomeViewModel();
});

class HomeViewModel extends ChangeNotifier {
  final OnboardingStorage _storage = OnboardingStorage();
  final NewsRepository _newsRepository = NewsRepositoryImpl();

  // Location data
  location_models.State? _selectedState;
  District? _selectedDistrict;
  Mandal? _selectedMandal;

  // Language and Topics data
  Map<String, dynamic>? _selectedLanguage;
  List<Map<String, dynamic>> _selectedTopics = [];

  // Current tab states
  String _selectedLocationTab = 'Your Area';
  int _selectedBottomNavIndex = 0;

  // Loading states
  bool _isLoadingLocation = false;
  bool _isLoadingNews = false;
  String? _error;

  // News data - using real API models
  List<News> _allNewsItems = []; // All news from API
  List<News> _filteredNewsItems = []; // Filtered news for current tab
  bool _hasMoreNews = true;
  bool _isLoadingMore = false;

  // Getters
  location_models.State? get selectedState => _selectedState;
  District? get selectedDistrict => _selectedDistrict;
  Mandal? get selectedMandal => _selectedMandal;
  Map<String, dynamic>? get selectedLanguage => _selectedLanguage;
  List<Map<String, dynamic>> get selectedTopics => _selectedTopics;
  String get selectedLocationTab => _selectedLocationTab;
  int get selectedBottomNavIndex => _selectedBottomNavIndex;
  bool get isLoadingLocation => _isLoadingLocation;
  bool get isLoadingNews => _isLoadingNews;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreNews => _hasMoreNews;
  String? get error => _error;
  List<News> get newsItems => _filteredNewsItems;

  // Initialize view model
  Future<void> initialize() async {
    await loadLocationData();
    await loadNewsData();
  }

  // Load location data from storage
  Future<void> loadLocationData() async {
    _isLoadingLocation = true;
    _error = null;
    notifyListeners();

    try {
      final state = await _storage.getSelectedState();
      final district = await _storage.getSelectedDistrict();
      final mandal = await _storage.getSelectedMandal();
      final language = await _storage.getSelectedLanguage();
      final topics = await _storage.getSelectedTopics();

      _selectedState = state;
      _selectedDistrict = district;
      _selectedMandal = mandal;
      _selectedLanguage = language;
      _selectedTopics = topics;
      _error = null;
    } catch (e) {
      _error = 'Failed to load location data: $e';
    }

    _isLoadingLocation = false;
    notifyListeners();
  }

  // Load news data from API
  Future<void> loadNewsData() async {
    _isLoadingNews = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch all news from API (no parameters)
      final news = await _newsRepository.getNews();

      // Filter by published status first, then by language and topics
      var filteredNews = news
          .where((item) => item.status == 'published')
          .toList();

      // Filter by selected language if available
      if (_selectedLanguage != null) {
        final languageId = _selectedLanguage!['id'] as int;
        filteredNews = news.where((item) {
          return item.translations.any(
            (translation) => translation.languageId == languageId,
          );
        }).toList();
      }

      // Filter by selected topics if available
      if (_selectedTopics.isNotEmpty) {
        final topicIds = _selectedTopics
            .map((topic) => topic['id'] as int)
            .toList();
        filteredNews = news
            .where((item) => topicIds.contains(item.topicId))
            .toList();
      }

      _allNewsItems = filteredNews;
      _allNewsItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _filterNewsForCurrentTab();
      _error = null;
    } catch (e) {
      _error = 'Failed to load news: $e';
      _allNewsItems = [];
      _filteredNewsItems = [];
    }

    _isLoadingNews = false;
    notifyListeners();
  }

  // Set selected location tab
  void setSelectedLocationTab(String tabName) {
    if (_selectedLocationTab != tabName) {
      _selectedLocationTab = tabName;
      // Filter news for the new tab
      _filterNewsForCurrentTab();
      notifyListeners();
    }
  }

  // Set selected bottom navigation index
  void setSelectedBottomNavIndex(int index) {
    if (_selectedBottomNavIndex != index) {
      _selectedBottomNavIndex = index;
      notifyListeners();
    }
  }

  // Load news for specific tab
  Future<void> loadNewsForTab(String tabName) async {
    // Just filter existing news, no need to reload from API
    _filterNewsForCurrentTab();
    notifyListeners();
  }

  // Get location tabs with dynamic names
  List<Map<String, dynamic>> getLocationTabs() {
    return [
      {
        'name': 'Your Area',
        'displayName': _selectedDistrict?.name ?? 'Your Area',
      },
      {'name': 'State Name', 'displayName': _selectedState?.name ?? 'State'},
      {'name': 'National', 'displayName': 'National'},
      {'name': 'International', 'displayName': 'International'},
    ];
  }

  // Filter news based on current location tab
  void _filterNewsForCurrentTab() {
    switch (_selectedLocationTab) {
      case 'Your Area':
        // Filter by mandal (most specific)
        if (_selectedMandal != null) {
          _filteredNewsItems = _allNewsItems
              .where((news) => news.mandalId == _selectedMandal!.id)
              .toList();
        } else {
          _filteredNewsItems = [];
        }
        break;

      case 'State Name':
        // Filter by state
        if (_selectedState != null) {
          _filteredNewsItems = _allNewsItems
              .where((news) => news.stateId == _selectedState!.id)
              .toList();
        } else {
          _filteredNewsItems = [];
        }
        break;

      case 'National':
        // Show all news from India (you might need to add country logic)
        _filteredNewsItems = _allNewsItems;
        break;

      case 'International':
        // Show international news (you might need to add country logic)
        _filteredNewsItems = _allNewsItems;
        break;

      default:
        _filteredNewsItems = _allNewsItems;
    }
  }

  // Refresh all data
  Future<void> refresh() async {
    await Future.wait([loadLocationData(), loadNewsData()]);
  }
}
