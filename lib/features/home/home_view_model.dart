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
  String? _nextCursor; // Cursor for pagination

  // Topics data
  List<Topic> _allTopics = []; // Full list from API (includes "Your Area")
  List<Topic> _topics = []; // Display list (first item removed for tab UI)
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
    // Location must be first — news filter depends on it.
    await loadLocationData();
    // Topics and news are independent of each other — run in parallel.
    await Future.wait([loadTopicsData(), loadNewsData()]);
    if (_selectedTopic == null && _topics.isNotEmpty) {
      _selectedTopic = _topics.first;
      // Re-filter now that we know which topic is selected.
      _filterNewsForCurrentTab();
      notifyListeners();
    }
  }

  // Load location data from storage
  Future<void> loadLocationData() async {
    _isLoadingLocation = true;
    try {
      // Run all storage reads in parallel — they are independent.
      final results = await Future.wait([
        _storage.getSelectedState(),
        _storage.getSelectedDistrict(),
        _storage.getSelectedMandal(),
        _storage.getSelectedLanguage(),
        _storage.getSelectedTopics(),
      ]);
      _selectedState = results[0] as location_models.State?;
      _selectedDistrict = results[1] as District?;
      _selectedMandal = results[2] as Mandal?;
      _selectedLanguage = results[3] as Map<String, dynamic>?;
      _selectedTopics = results[4] as List<Map<String, dynamic>>;
      _error = null;
    } catch (e) {
      _error = 'Failed to load location data: $e';
    }
    _isLoadingLocation = false;
    // No notifyListeners here — caller (initialize) will notify when everything is ready.
  }

  // Load news data from API
  // When silent is true, existing data stays visible while fetching (no loading spinner)
  Future<void> loadNewsData({bool silent = false}) async {
    if (!silent) {
      _isLoadingNews = true;
      _error = null;
      notifyListeners();
    }

    try {
      // Fetch first page of news from API
      final userId = _authViewModel.user?.id.toString();
      final paginatedResponse = await _newsRepository.getNews(
        status: 'published',
        userId: userId,
      );

      final newsData = paginatedResponse.data;
      _nextCursor = paginatedResponse.nextCursor;
      _hasMoreNews = paginatedResponse.hasMore;

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
        newsData
            .where(
                (item) => item.topicLocations.any((l) => topicIds.contains(l.id)))
            .toList();
      }

      _allNewsItems = newsData;
      _allNewsItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _filterNewsForCurrentTab();
      _error = null;

      // Populate like statuses from API data
      _updateLikeStatuses(_allNewsItems);
    } catch (e) {
      _error = 'Failed to load news: $e';
      _allNewsItems = [];
      _filteredNewsItems = [];
    }

    _isLoadingNews = false;
    notifyListeners();
  }

  // Load more news (next page)
  Future<void> loadMoreNews() async {
    if (_isLoadingMore || !_hasMoreNews || _nextCursor == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final userId = _authViewModel.user?.id.toString();
      final paginatedResponse = await _newsRepository.getNews(
        status: 'published',
        userId: userId,
        cursor: _nextCursor,
      );

      final newNews = paginatedResponse.data;
      _nextCursor = paginatedResponse.nextCursor;
      _hasMoreNews = paginatedResponse.hasMore;

      // Avoid duplicates
      final existingIds = _allNewsItems.map((n) => n.id).toSet();
      final uniqueNews = newNews.where((n) => !existingIds.contains(n.id)).toList();

      _allNewsItems.addAll(uniqueNews);
      _allNewsItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _filterNewsForCurrentTab();

      _updateLikeStatuses(uniqueNews);
    } catch (e) {
      // Silently fail — user can retry by scrolling again
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // Helper to update like statuses from news items
  void _updateLikeStatuses(List<News> newsItems) {
    for (var news in newsItems) {
      if (news.isLiked != null) {
        _likeStatuses[news.id] = news.isLiked == 1
            ? LikeStatus.liked
            : LikeStatus.disliked;
      } else if (!_likeStatuses.containsKey(news.id)) {
        _likeStatuses[news.id] = LikeStatus.neutral;
      }
    }
  }

  // Load topics data from API
  Future<void> loadTopicsData() async {
    _isLoadingTopics = true;
    _error = null;
    notifyListeners();

    try {
      final topicsData = await _topicsRepository.getTopics();
      _allTopics = List.from(topicsData);
      _topics = topicsData;
      if (_topics.isNotEmpty) _topics.removeAt(0);
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

      // Show existing filtered data immediately
      _filterNewsForCurrentTab();
      notifyListeners();

      // Fetch fresh data from API in the background (silent = no loading spinner)
      loadNewsData(silent: true);
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

      // Fetch fresh data from API in the background (silent = no loading spinner)
      loadNewsData(silent: true);
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
        'displayName':/*  _selectedMandal?.name ?? */ 'Your Area',
      },
      // {'name': 'State Name', 'displayName': _selectedState?.name ?? 'State'},
      {'name': 'More', 'displayName': 'More'},
    ];

    // Add selected topic as dynamic tab if exists
    if (_selectedTopic != null) {
      tabs.insert(1, {
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
              if (!news.hasTopicId(_selectedTopic!.id)) return false;

              if (_selectedMandal != null) {
                return news.hasMandalId(_selectedMandal!.id);
              } else if (_selectedDistrict != null) {
                return news.hasDistrictId(_selectedDistrict!.id);
              } else if (_selectedState != null) {
                return news.hasStateId(_selectedState!.id);
              } else {
                return true;
              }
            })
            .toList();
      return;
    }

    switch (_selectedLocationTab) {
      case 'Your Area':
        // Filter by "Your Area" topic + user's location
        final yourAreaTopic = _allTopics.where(
          (t) => t.name.toLowerCase() == 'your area' || (t.slug?.toLowerCase() ?? '') == 'your-area',
        ).firstOrNull;

        if (yourAreaTopic == null) {
          _filteredNewsItems = [];
          break;
        }

        _filteredNewsItems = _allNewsItems.where((news) {
          // Must have the "Your Area" topic
          if (!news.hasTopicId(yourAreaTopic.id)) {
            return false;
          }
          // Filter by location
          if (_selectedMandal != null) {
            return news.hasMandalId(_selectedMandal!.id);
          } else if (_selectedDistrict != null) {
            return news.hasDistrictId(_selectedDistrict!.id);
          } else if (_selectedState != null) {
            return news.hasStateId(_selectedState!.id);
          }
          return false;
        }).toList();
        break;

      case 'State Name':
        // Filter by state
        if (_selectedState != null) {
          _filteredNewsItems = _allNewsItems
              .where((news) => news.hasStateId(_selectedState!.id))
              .toList();
        } else {
          _filteredNewsItems = [];
        }
        break;

      default:
        _filteredNewsItems = _allNewsItems;
    }
  }

  // Increment view count locally
  void incrementViewCount(int newsId) {
    final index = _allNewsItems.indexWhere((n) => n.id == newsId);
    if (index != -1) {
      _allNewsItems[index] = _allNewsItems[index].copyWith(
        viewsCount: _allNewsItems[index].viewsCount + 1,
      );
      _filterNewsForCurrentTab();
      notifyListeners();
    }
  }

  // Refresh all data (resets pagination)
  Future<void> refresh() async {
    _nextCursor = null;
    _hasMoreNews = true;
    await Future.wait([loadLocationData(), loadNewsData()]);
  }

  Future<void> refreshForMore() async {
    await Future.wait([loadTopicsData()]);
  }

  // Like or dislike a news item (with toggle support)
  Future<void> likeDislike({
    required int likeableId,
    required LikeableType likeableType,
    required bool isLike,
  }) async {
    final currentStatus = _likeStatuses[likeableId] ?? LikeStatus.neutral;
    final newsIndex = _allNewsItems.indexWhere((n) => n.id == likeableId);

    // Determine new status (toggle if same action repeated)
    LikeStatus newStatus;
    if (isLike && currentStatus == LikeStatus.liked) {
      newStatus = LikeStatus.neutral; // Un-like
    } else if (!isLike && currentStatus == LikeStatus.disliked) {
      newStatus = LikeStatus.neutral; // Un-dislike
    } else {
      newStatus = isLike ? LikeStatus.liked : LikeStatus.disliked;
    }

    // Optimistic count update
    if (newsIndex != -1) {
      var item = _allNewsItems[newsIndex];
      var likes = item.likesCount;
      var dislikes = item.dislikesCount;

      // Remove previous vote count
      if (currentStatus == LikeStatus.liked) likes--;
      if (currentStatus == LikeStatus.disliked) dislikes--;

      // Add new vote count
      if (newStatus == LikeStatus.liked) likes++;
      if (newStatus == LikeStatus.disliked) dislikes++;

      _allNewsItems[newsIndex] = item.copyWith(
        isLiked: newStatus == LikeStatus.liked ? 1 : (newStatus == LikeStatus.disliked ? 0 : null),
        likesCount: likes < 0 ? 0 : likes,
        dislikesCount: dislikes < 0 ? 0 : dislikes,
      );
      _filterNewsForCurrentTab();
    }

    _likeStatuses[likeableId] = newStatus;
    notifyListeners();

    // API call in background
    try {
      await _commentsRepository.likeDislike(
        likeableId: likeableId,
        likeableType: likeableType,
        isLike: isLike,
      );
    } catch (e) {
      // Revert on failure
      _likeStatuses[likeableId] = currentStatus;
      if (newsIndex != -1) {
        await loadNewsData(silent: true);
      }
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
