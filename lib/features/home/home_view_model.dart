import 'package:deep_pulse_news/data/models/likeable_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/onboarding_storage.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/news.dart';
import '../../data/repositories/news_repository.dart';
import '../../data/repositories/topics_repository.dart';
import '../../data/models/topic.dart';
import '../../data/repositories/comments_repository.dart';
import '../../features/auth/auth_view_model.dart';
import '../../providers/app_providers.dart';

// Like status for news items
enum LikeStatus { neutral, liked, disliked }

// Provider for HomeViewModel
final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>((ref) {
  final authViewModel = ref.read(authViewModelProvider);
  return HomeViewModel(authViewModel: authViewModel);
});

class HomeViewModel extends ChangeNotifier {
  final OnboardingStorage _storage = OnboardingStorage();
  final NewsRepository _newsRepository = NewsRepositoryImpl();
  final CommentsRepository _commentsRepository = CommentsRepositoryImpl();
  final TopicsRepository _topicsRepository = TopicsRepositoryImpl();
  final AuthViewModel _authViewModel;

  HomeViewModel({required AuthViewModel authViewModel})
    : _authViewModel = authViewModel,
      _isLoadingNews = true;

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

  // Topics data
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;
  Topic? _selectedTopic;

  // Like statuses for news items
  Map<int, LikeStatus> _likeStatuses = {};

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
  List<Topic> get topics => _topics;
  bool get isLoadingTopics => _isLoadingTopics;
  Topic? get selectedTopic => _selectedTopic;
  Map<int, LikeStatus> get likeStatuses => _likeStatuses;

  // Initialize view model
  Future<void> initialize() async {
    await loadLocationData();
    await loadTopicsData();
    if (_selectedTopic == null && _topics.isNotEmpty) {
      _selectedTopic = _topics.first;
    }

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
      final userId = _authViewModel.user?.id.toString();
      final newsData = await _newsRepository.getNews(
        status: 'published',
        userId: userId,
      );

      // Filter by selected language if available
      if (_selectedLanguage != null) {
        final languageId = _selectedLanguage!['id'] as int;
        newsData.where((item) {
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
        newsData.where((item) => topicIds.contains(item.topicId)).toList();
      }

      _allNewsItems = newsData;
      _allNewsItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _filterNewsForCurrentTab();
      _error = null;

      // Populate like statuses from API data
      for (var news in _allNewsItems) {
        if (news.isLiked == 1) {
          _likeStatuses[news.id] = LikeStatus.liked;
        } else if (news.isLiked == 0) {
          _likeStatuses[news.id] = LikeStatus.disliked;
        } else {
          _likeStatuses[news.id] = LikeStatus.neutral;
        }
      }
    } catch (e) {
      _error = 'Failed to load news: $e';
      _allNewsItems = [];
      _filteredNewsItems = [];
    }

    _isLoadingNews = false;
    notifyListeners();
  }

  // Load topics data from API
  Future<void> loadTopicsData() async {
    _isLoadingTopics = true;
    _error = null;
    notifyListeners();

    try {
      final topicsData = await _topicsRepository.getTopics();
      _topics = topicsData;
      _topics.removeAt(0);
      _error = null;
    } catch (e) {
      _error = 'Failed to load topics: $e';
      _topics = [];
    }

    _isLoadingTopics = false;
    notifyListeners();
  }

  // Set selected location tab
  void setSelectedLocationTab(String tabName) {
    if (_selectedLocationTab != tabName) {
      _selectedLocationTab = tabName;

      // When More is selected, automatically select first topic to show topic tab
      if (tabName == 'More' && _selectedTopic == null && _topics.isNotEmpty) {
        _selectedTopic = _topics.first;
        // Don't navigate to the topic, just make it visible as a tab
      }

      // Filter news for the new tab
      _filterNewsForCurrentTab();
      notifyListeners();
    }
  }

  // Select a topic and make it the active tab
  void selectTopic(Topic topic) {
    if (_selectedTopic != topic) {
      _selectedTopic = topic;
      // Set the location tab to the topic name (which will be handled as dynamic tab)
      _selectedLocationTab = topic.name;
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
    final tabs = [
      {
        'name': 'Your Area',
        'displayName': _selectedMandal?.name ?? 'Your Area',
      },
      {'name': 'State Name', 'displayName': _selectedState?.name ?? 'State'},
      {'name': 'More', 'displayName': 'More'},
    ];

    // Add selected topic as dynamic tab if exists
    if (_selectedTopic != null) {
      tabs.insert(2, {
        'name': _selectedTopic!.name,
        'displayName': _selectedTopic!.name,
      });
    }

    return tabs;
  }

  void _filterNewsForCurrentTab() {
    if (_selectedTopic != null &&
        _selectedLocationTab == _selectedTopic!.name) {
        _filteredNewsItems = _allNewsItems
            .where((news) {
              if (news.topicId != _selectedTopic!.id) return false;
              
              if (_selectedMandal != null) {
                return news.mandalId == _selectedMandal!.id;
              } else if (_selectedDistrict != null) {
                return news.districtId == _selectedDistrict!.id;
              } else if (_selectedState != null) {
                return news.stateId == _selectedState!.id;
              } else {
                return true;
              }
            })
            .toList();
      // }
      return;
    }

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

      default:
        _filteredNewsItems = _allNewsItems;
    }
  }

  // Refresh all data
  Future<void> refresh() async {
    await Future.wait([loadLocationData(), loadNewsData()]);
  }

  Future<void> refreshForMore() async {
    await Future.wait([loadTopicsData()]);
  }

  // Like or dislike a news item
  Future<void> likeDislike({
    required int likeableId,
    required LikeableType likeableType,
    required bool isLike,
  }) async {
    try {
      await _commentsRepository.likeDislike(
        likeableId: likeableId,
        likeableType: likeableType,
        isLike: isLike,
      );
      // Update local status
      _likeStatuses[likeableId] = isLike
          ? LikeStatus.liked
          : LikeStatus.disliked;

      // Update the news item locally
      final newsIndex = _allNewsItems.indexWhere((n) => n.id == likeableId);
      if (newsIndex != -1) {
        _allNewsItems[newsIndex] = _allNewsItems[newsIndex].copyWith(
          isLiked: isLike ? 1 : 0,
        );
        _filterNewsForCurrentTab();
      }

      notifyListeners();
    } catch (e) {
      // Handle error, perhaps notify listeners with error
      _error = 'Failed to like/dislike: $e';
      notifyListeners();
    }
  }

  // Share news item
  Future<bool> shareNews(int newsId, String platform) async {
    try {
      await _newsRepository.shareNews(newsId, platform);

      // Update the shares count locally
      final newsIndex = _allNewsItems.indexWhere((n) => n.id == newsId);
      if (newsIndex != -1) {
        final currentShares = _allNewsItems[newsIndex].sharesCount;
        _allNewsItems[newsIndex] = _allNewsItems[newsIndex].copyWith(
          sharesCount: currentShares + 1,
        );
        _filterNewsForCurrentTab();
        notifyListeners();
      }

      return true;
    } catch (e) {
      _error = 'Failed to share news: $e';
      notifyListeners();
      return false;
    }
  }
}
