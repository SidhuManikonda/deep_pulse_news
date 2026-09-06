import 'package:deep_pulse_news/data/models/likeable_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/services/onboarding_storage.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/feed_ad.dart';
import '../../data/models/feed_entry.dart';
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

  /// Standalone adverts the feed endpoint mixes in with the articles. Held
  /// apart from the news rather than in one list because every existing path —
  /// likes, views, shares, video preloading — is written against [News], and an
  /// advert has none of those. They're woven back in by [feedEntries] at the
  /// point the pager actually needs a single ordered list.
  List<FeedAd> _allAds = [];


  /// True while a just-opened tab is still pulling articles. Lets the feed
  /// show a skeleton rather than its "No news available" empty state.
  bool _isFillingTab = false;
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
  bool get isFillingTab => _isFillingTab;
  String? get error => _error;
  List<News> get newsItems => _filteredNewsItems;

  /// The feed the pager renders: the tab's articles and the standalone adverts,
  /// in the order the backend sent them.
  ///
  /// An advert sits wherever its `updated_at` places it among the articles —
  /// the same key the feed endpoint orders by — so it lands in the slot the
  /// backend chose and appears exactly once, like any other post. The app adds
  /// no cadence of its own: an earlier version re-spaced ads every few articles,
  /// which meant one delivered advert was rendered several times over and its
  /// position had nothing to do with what the server sent.
  List<FeedEntry> get feedEntries {
    final articles = _filteredNewsItems;
    final ads = _adsForCurrentLocation;
    if (ads.isEmpty) {
      return articles.map(FeedEntry.article).toList();
    }

    final entries = <FeedEntry>[
      ...articles.map(FeedEntry.article),
      ...ads.map(FeedEntry.advert),
    ];

    // Newest first, matching how the articles are already ordered. Ads without
    // a timestamp sort last rather than jumping to the top of the feed.
    DateTime keyOf(FeedEntry e) =>
        e.ad?.updatedAt ??
        e.news?.displayTime ??
        DateTime.fromMillisecondsSinceEpoch(0);

    entries.sort((a, b) => keyOf(b).compareTo(keyOf(a)));
    return entries;
  }

  /// Adverts that were bought for where the reader is.
  ///
  /// Uses the same rule as [_matchesUserLocation] does for articles: match on
  /// the narrowest level the ad was targeted at. An ad with no targeting at all
  /// is national and runs everywhere.
  List<FeedAd> get _adsForCurrentLocation {
    return _allAds.where((ad) {
      if (ad.locations.isEmpty) return true;
      if (ad.mandalLocations.isNotEmpty) {
        return _selectedMandal != null && ad.hasMandalId(_selectedMandal!.id);
      }
      if (ad.districtLocations.isNotEmpty) {
        return _selectedDistrict != null &&
            ad.hasDistrictId(_selectedDistrict!.id);
      }
      if (ad.stateLocations.isNotEmpty) {
        return _selectedState != null && ad.hasStateId(_selectedState!.id);
      }
      return true;
    }).toList();
  }

  /// Adds newly fetched adverts, skipping ones already held. Later pages repeat
  /// ads the backend has already sent, and running the same creative twice in
  /// one scroll looks like a bug.
  void _mergeAds(List<FeedAd> incoming) {
    final seen = _allAds.map((a) => a.id).toSet();
    _allAds.addAll(incoming.where((a) => !seen.contains(a.id)));
  }
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

      // Fallback to the logged-in user's account location when device storage
      // has no saved location yet (e.g. the first open right after login on a
      // device — the account already knows the user's area but onboarding
      // storage is still empty). Without this, _matchesUserLocation() treats a
      // null location as "match everything", so "Your Area" shows news from
      // every state (e.g. Telangana) until the user manually re-picks their
      // location. We only fill gaps here — a location the user explicitly saved
      // is never overridden, so changing location from the picker still works.
      _applyAccountLocationFallback();

      _error = null;
    } catch (e) {
      _error = 'Failed to load location data: $e';
    }
    _isLoadingLocation = false;
    // No notifyListeners here — caller (initialize) will notify when everything is ready.
  }

  /// Seeds any missing location level from the logged-in user's account so the
  /// "Your Area" feed filters correctly even when device storage is empty.
  /// Only fills nulls — never overrides a user-saved location. No-op for users
  /// without an account location (e.g. admins who browse all areas) and when
  /// no one is logged in yet.
  void _applyAccountLocationFallback() {
    final user = _authViewModel.user;
    if (user == null) return;

    if (_selectedState == null && user.stateId != null) {
      _selectedState = location_models.State(
        id: user.stateId!,
        name: '',
        slug: '',
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
    if (_selectedDistrict == null && user.districtId != null) {
      _selectedDistrict = District(
        id: user.districtId!,
        stateId: user.stateId ?? 0,
        name: '',
        slug: '',
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
    if (_selectedMandal == null && user.mandalId != null) {
      _selectedMandal = Mandal(
        id: user.mandalId!,
        districtId: user.districtId ?? 0,
        name: '',
        slug: '',
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
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
      final paginatedResponse = await _newsRepository.getFeed(
        status: 'published',
        userId: userId,
      );

      final newsData = paginatedResponse.news;
      _allAds = paginatedResponse.ads;
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
      // Sort by displayTime (updatedAt ?? createdAt) so freshly edited
      // articles surface at the top — matches the "Xm ago" label the
      // home card shows. Sorting by createdAt would leave an edit stuck
      // in its original feed position even though it's labelled "Just now".
      _allNewsItems.sort((a, b) => b.displayTime.compareTo(a.displayTime));
      _filterNewsForCurrentTab();
      _error = null;

      // Populate like statuses from API data
      _updateLikeStatuses(_allNewsItems);

      // _debugPrintTabCounts();

      // If the current tab has very few results, auto-fetch more pages so the
      // user doesn't see a near-empty feed just because the first page didn't
      // happen to include many items in their mandal/district/state.
      _autoFillCurrentTab();
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
      final paginatedResponse = await _newsRepository.getFeed(
        status: 'published',
        userId: userId,
        cursor: _nextCursor,
      );

      final newNews = paginatedResponse.news;
      _mergeAds(paginatedResponse.ads);
      _nextCursor = paginatedResponse.nextCursor;
      _hasMoreNews = paginatedResponse.hasMore;

      // Avoid duplicates
      final existingIds = _allNewsItems.map((n) => n.id).toSet();
      final uniqueNews = newNews.where((n) => !existingIds.contains(n.id)).toList();

      _allNewsItems.addAll(uniqueNews);
      // Sort by displayTime (updatedAt ?? createdAt) so freshly edited
      // articles surface at the top — matches the "Xm ago" label the
      // home card shows. Sorting by createdAt would leave an edit stuck
      // in its original feed position even though it's labelled "Just now".
      _allNewsItems.sort((a, b) => b.displayTime.compareTo(a.displayTime));
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
      debugPrint('▶ Tab switched → "$tabName"  (${_filteredNewsItems.length} items)');
      notifyListeners();

      // Top the tab up if it's thin — but never re-fetch page 1 here.
      // `loadNewsData` assigns `_allNewsItems = newsData`, so calling it on a
      // tab switch threw away every extra page already fetched and shrank the
      // pool back to 20 articles. A topic tab then matched one item (nothing
      // to scroll) or none at all ("No news available"), seconds after having
      // shown content. `_autoFillCurrentTab` appends instead of replacing.
      _autoFillCurrentTab();
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

      // Append more pages if this topic is thin — same reasoning as
      // setSelectedLocationTab: re-fetching page 1 here would discard the
      // pages already loaded and leave the topic with one item or none.
      _autoFillCurrentTab();
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

  /// Auto-paginate when the visible tab has very few items.
  /// Keeps fetching pages until either we have a reasonable number of matches
  /// or the server has no more news. Caps to prevent runaway loops.
  Future<void> _autoFillCurrentTab() async {
    const minDesired = 10;
    const maxExtraPages = 4;

    // Flag so the UI can show a skeleton instead of "No news available" while
    // a freshly-opened tab is still being filled. Without it the tab renders
    // its empty state for the second or two the fetch takes, which reads as
    // "this tab is broken" right before the articles appear.
    _isFillingTab = true;
    notifyListeners();

    try {
      // Topic tabs fetch straight from the server with `topic_id`. Scanning the
      // undifferentiated feed for them is hopeless: Jobs is about 1 article in
      // 40, so four extra pages of 20 turn up one or two matches and the tab
      // looks broken (single article, nothing to scroll).
      final topicId = _currentTabTopicId();
      if (topicId != null) {
        await _fillFromTopicEndpoint(topicId, minDesired);
        return;
      }

      var pages = 0;
      while (_filteredNewsItems.length < minDesired &&
          _hasMoreNews &&
          _nextCursor != null &&
          pages < maxExtraPages) {
        pages++;
        await loadMoreNews();
      }
    } finally {
      _isFillingTab = false;
      notifyListeners();
    }
  }

  /// The topic behind the current tab, or null for "Your Area" / plain tabs
  /// that aren't backed by a single topic.
  int? _currentTabTopicId() {
    if (_selectedTopic != null && _selectedLocationTab == _selectedTopic!.name) {
      return _selectedTopic!.id;
    }
    return null;
  }

  /// Pages `/news?topic_id=…` and merges what comes back into the shared pool.
  /// Deliberately keeps its own cursor: `_nextCursor` belongs to the unfiltered
  /// feed, and overwriting it with a topic-scoped cursor would corrupt normal
  /// scroll pagination.
  Future<void> _fillFromTopicEndpoint(int topicId, int minDesired) async {
    const maxPages = 5;
    String? cursor;
    final userId = _authViewModel.user?.id.toString();

    for (var page = 0; page < maxPages; page++) {
      if (_filteredNewsItems.length >= minDesired) return;
      try {
        final response = await _newsRepository.getNews(
          status: 'published',
          userId: userId,
          cursor: cursor,
          topicId: topicId,
        );

        final existingIds = _allNewsItems.map((n) => n.id).toSet();
        final fresh = response.data
            .where((n) => !existingIds.contains(n.id))
            .toList();

        if (fresh.isNotEmpty) {
          _allNewsItems.addAll(fresh);
          _allNewsItems.sort((a, b) => b.displayTime.compareTo(a.displayTime));
          _updateLikeStatuses(fresh);
          _filterNewsForCurrentTab();
          notifyListeners();
        }

        // Bail out when the tab the user is looking at has moved on, so a slow
        // fetch can't keep loading for a tab they already left.
        if (_currentTabTopicId() != topicId) return;

        cursor = response.nextCursor;
        if (!response.hasMore || cursor == null) return;
      } catch (_) {
        return; // Silent — the tab still shows whatever already matched.
      }
    }
  }

  bool _matchesUserLocation(News news) {
    // No user location at all → no filter
    if (_selectedState == null &&
        _selectedDistrict == null &&
        _selectedMandal == null) {
      return true;
    }

    if (news.mandalLocations.isNotEmpty) {
      return _selectedMandal != null && news.hasMandalId(_selectedMandal!.id);
    }
    if (news.districtLocations.isNotEmpty) {
      return _selectedDistrict != null && news.hasDistrictId(_selectedDistrict!.id);
    }
    if (news.stateLocations.isNotEmpty) {
      return _selectedState != null && news.hasStateId(_selectedState!.id);
    }
    return true;
  }

  void _filterNewsForCurrentTab() {
    // Topic tab (selected from More) — has the topic AND matches user location
    if (_selectedTopic != null &&
        _selectedLocationTab == _selectedTopic!.name) {
      _filteredNewsItems = _allNewsItems.where((news) {
        if (!news.hasTopicId(_selectedTopic!.id)) return false;
        return _matchesUserLocation(news);
      }).toList();
      return;
    }

    switch (_selectedLocationTab) {
      case 'Your Area':
        // Has the "Your Area" topic AND is tagged in user's mandal/district/state
        final yourAreaTopic = _allTopics.where(
          (t) => t.name.toLowerCase() == 'your area' ||
              (t.slug?.toLowerCase() ?? '') == 'your-area',
        ).firstOrNull;

        if (yourAreaTopic == null) {
          _filteredNewsItems = [];
          break;
        }

        _filteredNewsItems = _allNewsItems.where((news) {
          if (!news.hasTopicId(yourAreaTopic.id)) return false;
          return _matchesUserLocation(news);
        }).toList();
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

  // ───────────────────────────────────────────────────────────────────────
  // DEBUG — prints how news items are distributed across tabs / filters.
  // Call after _allNewsItems is populated.
  // ───────────────────────────────────────────────────────────────────────
  // void _debugPrintTabCounts() {
  //   final total = _allNewsItems.length;
  //   final stateId    = _selectedState?.id;
  //   final districtId = _selectedDistrict?.id;
  //   final mandalId   = _selectedMandal?.id;

  //   debugPrint('═══════════════ NEWS DISTRIBUTION ═══════════════');
  //   debugPrint('Total news loaded         : $total');
  //   debugPrint('Selected state            : ${_selectedState?.name} (id=$stateId)');
  //   debugPrint('Selected district         : ${_selectedDistrict?.name} (id=$districtId)');
  //   debugPrint('Selected mandal           : ${_selectedMandal?.name} (id=$mandalId)');
  //   debugPrint('────────────────── BY TOPIC ─────────────────────');
  //   for (final topic in _allTopics) {
  //     final count = _allNewsItems.where((n) => n.hasTopicId(topic.id)).length;
  //     debugPrint('  ${topic.name.padRight(20)}: $count');
  //   }
  //   debugPrint('───────────────── YOUR AREA FILTER ──────────────');
  //   final yourAreaTopic = _allTopics.where(
  //     (t) => t.name.toLowerCase() == 'your area' ||
  //            (t.slug?.toLowerCase() ?? '') == 'your-area',
  //   ).firstOrNull;

  //   if (yourAreaTopic == null) {
  //     debugPrint('  ⚠ "Your Area" topic NOT FOUND in topics list');
  //   } else {
  //     final withTopic = _allNewsItems
  //         .where((n) => n.hasTopicId(yourAreaTopic.id))
  //         .toList();
  //     debugPrint('  has "Your Area" topic     : ${withTopic.length}');

  //     if (stateId != null) {
  //       final byState = withTopic.where((n) => n.hasStateId(stateId)).length;
  //       debugPrint('  + state match             : $byState');
  //     }
  //     if (districtId != null) {
  //       final byDistrict = withTopic
  //           .where((n) => n.hasDistrictId(districtId))
  //           .length;
  //       debugPrint('  + district match          : $byDistrict');
  //     }
  //     if (mandalId != null) {
  //       final byMandal = withTopic
  //           .where((n) => n.hasMandalId(mandalId))
  //           .length;
  //       debugPrint('  + mandal match            : $byMandal');
  //     }
  //     // New cascading match — mandal OR district OR state
  //     final cascading = withTopic.where(_matchesUserLocation).length;
  //     debugPrint('  ★ cascading match (NEW)   : $cascading  ← what you now see');
  //   }
  //   debugPrint('───────── CURRENTLY VISIBLE ($_selectedLocationTab) ─────────');
  //   debugPrint('  After active tab filter   : ${_filteredNewsItems.length}');
  //   debugPrint('───────── PER-NEWS LOCATION TAGS ─────────────────');
  //   for (var i = 0; i < _filteredNewsItems.length; i++) {
  //     final n = _filteredNewsItems[i];
  //     final translation = n.getPrimaryTranslation();
  //     final title = translation?.title ?? '(no title)';
  //     final shortTitle = title.length > 40 ? '${title.substring(0, 40)}…' : title;
  //     final states    = n.stateLocations.map((l) => '${l.value}#${l.id}').join(', ');
  //     final districts = n.districtLocations.map((l) => '${l.value}#${l.id}').join(', ');
  //     final mandals   = n.mandalLocations.map((l) => '${l.value}#${l.id}').join(', ');

  //     // Mark how each news matched the user's location (most-specific scope)
  //     String matchReason = '?';
  //     if (n.mandalLocations.isNotEmpty) {
  //       matchReason = (mandalId != null && n.hasMandalId(mandalId))
  //           ? 'MANDAL ✓'
  //           : 'MANDAL-scoped, not your mandal ✗';
  //     } else if (n.districtLocations.isNotEmpty) {
  //       matchReason = (districtId != null && n.hasDistrictId(districtId))
  //           ? 'DISTRICT ✓'
  //           : 'DISTRICT-scoped, not your district ✗';
  //     } else if (n.stateLocations.isNotEmpty) {
  //       matchReason = (stateId != null && n.hasStateId(stateId))
  //           ? 'STATE ✓'
  //           : 'STATE-scoped, not your state ✗';
  //     } else {
  //       matchReason = 'general (no location)';
  //     }
  //     debugPrint('  [${i.toString().padLeft(2)}] $shortTitle  ← $matchReason');
  //     if (states.isNotEmpty)    debugPrint('       states   : $states');
  //     if (districts.isNotEmpty) debugPrint('       districts: $districts');
  //     if (mandals.isNotEmpty)   debugPrint('       mandals  : $mandals');
  //   }
  //   debugPrint('═════════════════════════════════════════════════');
  // }
}
