import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/news.dart';
import '../../data/models/paginated_response.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/user.dart';
import '../../data/repositories/news_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../shared/widgets/app_loader.dart';
import '../news/news_detail_screen_v2.dart';
import '../news/news_upload_screen.dart';

class NewsManagementScreen extends ConsumerStatefulWidget {
  const NewsManagementScreen({super.key});

  @override
  ConsumerState<NewsManagementScreen> createState() =>
      _NewsManagementScreenState();
}

class _NewsManagementScreenState extends ConsumerState<NewsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final _NewsScope _scope;
  final NewsRepository _newsRepo = NewsRepositoryImpl();

  List<News> _allNews = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Whole-dataset totals from the backend. Null until the API starts sending
  /// the `counts` block, at which point the tab badges switch over on their
  /// own — no release coordination needed.
  NewsStatusCounts? _counts;

  /// Debounce for server-side search, so typing doesn't fire a request per
  /// keystroke.
  Timer? _searchDebounce;
  DateTimeRange? _dateRange;
  int? _selectedStateId;
  location_models.State? _selectedStateObj;

  // Districts and mandals are multi-select: an admin or sub-admin managing a
  // whole state usually wants several districts at once, not one at a time.
  // Empty set == no filter ("All Districts" / "All Mandals").
  final Set<int> _selectedDistrictIds = {};
  final Set<int> _selectedMandalIds = {};

  // Topic ("type") filter — multi-select like the location filters, since a
  // news item can be tagged to several topics at once.
  final Set<int> _selectedTopicIds = {};

  /// Author filter. The name drives the chip label; the id is what the server
  /// filters on. Both move together — see [_selectAuthor].
  String? _selectedAuthor;
  int? _selectedAuthorId;

  static const _statuses = [
    'all',
    'important',
    'pending',
    'published',
    'rejected',
  ];
  static const _statusLabels = [
    'All',
    'Important',
    'Pending',
    'Published',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _scope = _NewsScope.forUser(ref.read(authViewModelProvider).user);
    // No location prefetch needed: every filter list is derived from the loaded
    // news itself, which already carries each article's state/district/mandal
    // names. That also means the district filter is never empty just because a
    // separate location fetch hadn't finished.
    _loadNews();
    // The Author filter is the exception — it lists every user, not just the
    // authors of the news pages loaded so far, so its options don't keep
    // growing as you scroll. getUserList() is unpaginated, so one call covers
    // it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userCtrl = ref.read(adminUserManagementControllerProvider);
      if (userCtrl.users.isEmpty && !userCtrl.isLoadingUsers) {
        userCtrl.fetchUsers(authRepository: ref.read(authRepositoryProvider));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _nextCursor = null;
      _hasMore = true;
    });

    try {
      final userId = ref.read(authViewModelProvider).user?.id.toString();
      final response = await _newsRepo.getNews(
        userId: userId,
        authorId: _selectedAuthorId,
      );
      final scopedNews = _scope.applyScope(response.data);
      scopedNews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _allNews = scopedNews;
          _nextCursor = response.nextCursor;
          _hasMore = response.hasMore;
          _counts = response.counts ?? _counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreNews() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final userId = ref.read(authViewModelProvider).user?.id.toString();
      final response = await _newsRepo.getNews(
        userId: userId,
        cursor: _nextCursor,
        authorId: _selectedAuthorId,
      );
      final scopedNews = _scope.applyScope(response.data);

      if (mounted) {
        final existingIds = _allNews.map((n) => n.id).toSet();
        final uniqueNews = scopedNews
            .where((n) => !existingIds.contains(n.id))
            .toList();

        setState(() {
          _allNews.addAll(uniqueNews);
          _allNews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _nextCursor = response.nextCursor;
          _hasMore = response.hasMore;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Applies (or clears) the author filter and refetches.
  ///
  /// This one goes to the server rather than filtering locally: the dropdown
  /// lists every user, but the app only holds a few pages of news, so a local
  /// match would show "no results" for any reporter whose articles hadn't been
  /// scrolled to yet. `?author_id=` narrows across the whole dataset.
  void _selectAuthor({int? id, String? name}) {
    setState(() {
      _selectedAuthorId = id;
      _selectedAuthor = name;
    });
    _loadNews();
  }

  /// Filters the loaded list immediately so typing stays responsive, then
  /// asks the server for more matches once typing pauses.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _runServerSearch(value);
    });
  }

  /// Pulls server-side matches for [query] and **merges** them into the pool.
  ///
  /// Merging rather than replacing is the important part. The backend's search
  /// may well only look at titles, so replacing the list would make searching
  /// by reporter name return nothing — the local filter matches title OR
  /// author, but only over articles it actually has. Adding to the pool means
  /// the server broadens the search without ever taking away a match the app
  /// could already see.
  ///
  /// Keeps off `_nextCursor`, which belongs to the unfiltered listing; a
  /// search-scoped cursor would corrupt normal scroll pagination.
  Future<void> _runServerSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final userId = ref.read(authViewModelProvider).user?.id.toString();
      final response = await _newsRepo.getNews(userId: userId, search: query);
      if (!mounted || _searchQuery != query) return; // typing moved on

      final scoped = _scope.applyScope(response.data);
      final existingIds = _allNews.map((n) => n.id).toSet();
      final fresh = scoped.where((n) => !existingIds.contains(n.id)).toList();
      if (fresh.isEmpty) return;

      setState(() {
        _allNews.addAll(fresh);
        _allNews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    } catch (_) {
      // Silent: the local filter still shows whatever already matched.
    }
  }

  /// Badge number for a status tab.
  ///
  /// Prefers the backend's whole-dataset totals when the response carries them
  /// — the local count only ever reflects the pages downloaded so far, so it
  /// read "20" against 1,484 real articles. Falls back to the local count on
  /// the older response shape, and whenever a filter is active, since the
  /// server totals don't know about the district/topic/date narrowing applied
  /// on top.
  int _tabCount(String status) {
    final serverCount = _hasLocalFilters ? null : _counts?.forStatus(status);
    return serverCount ?? _filteredNews(status).length;
  }

  /// True when something is narrowing the list beyond plain status, which
  /// makes the server's overall totals the wrong number to show.
  bool get _hasLocalFilters =>
      _searchQuery.trim().isNotEmpty ||
      _dateRange != null ||
      _selectedStateId != null ||
      _selectedDistrictIds.isNotEmpty ||
      _selectedMandalIds.isNotEmpty ||
      _selectedTopicIds.isNotEmpty ||
      _selectedAuthor != null;

  List<News> _filteredNews(String status) {
    var list = status == 'all'
        ? _allNews
        : status == 'important'
        ? _allNews.where((n) => n.isImportant).toList()
        : _allNews.where((n) => n.status == status).toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) {
        final title = n.translations.isNotEmpty
            ? n.translations.first.title.toLowerCase()
            : '';
        final author = (n.authorName ?? '').toLowerCase();
        return title.contains(q) || author.contains(q);
      }).toList();
    }
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
      );
      list = list
          .where((n) => n.createdAt.isAfter(start) && n.createdAt.isBefore(end))
          .toList();
    }
    if (_selectedStateId != null) {
      list = list.where((n) => n.hasStateId(_selectedStateId!)).toList();
    }
    // Multi-select: an article matches if it's tagged to ANY selected district
    // (or mandal), so picking three districts widens the view rather than
    // narrowing it to their intersection.
    if (_selectedDistrictIds.isNotEmpty) {
      list = list
          .where((n) => _selectedDistrictIds.any(n.hasDistrictId))
          .toList();
    }
    if (_selectedMandalIds.isNotEmpty) {
      list = list.where((n) => _selectedMandalIds.any(n.hasMandalId)).toList();
    }
    if (_selectedTopicIds.isNotEmpty) {
      list = list.where((n) => _selectedTopicIds.any(n.hasTopicId)).toList();
    }
    // No author filtering here: the server already returned only this
    // reporter's articles via ?author_id=. Re-filtering locally on the display
    // name would just risk dropping rows whose name spacing differs.
    return list;
  }

  void _navigateToEdit(News news) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsUploadScreen(prefillNews: news),
      ),
    ).then((_) => _loadNews());
  }

  void _clearLocationFilters() {
    setState(() {
      _selectedStateId = null;
      _selectedStateObj = null;
      _selectedDistrictIds.clear();
      _selectedMandalIds.clear();
      _selectedTopicIds.clear();
      _selectedAuthor = null;
      _selectedAuthorId = null;
    });
    _loadNews();
  }

  Future<void> _pickDateRange(ThemeData theme) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: theme.appPrimary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<void> _updateStatus(News news, String newStatus) async {
    try {
      final success = await _newsRepo.updateNewsStatus(news.id, newStatus);
      if (success) {
        // DISABLED 2026-08-01 at backend's request — they are moving the push
        // trigger server-side (fires automatically when status becomes
        // `published`), so the app must not call /api/send-notification.
        // Kept, not deleted: re-enable only if that plan is dropped.
        //
        // Readers are only notified when an article actually goes live.
        // Reject / Unpublish / Restore move it *away* from published, so
        // pushing there would advertise content nobody can open — and the
        // reporter-facing `news_approved` / `news_rejected` waves are the
        // backend's job (see docs/PUSH_NOTIFICATIONS_BACKEND.md §3 Step 4).
        //
        // if (newStatus == 'published' && news.status != 'published') {
        //   unawaited(_fireNewsPushNotification(news));
        // } else {
        //   debugPrint(
        //     '[NewsMgmt] Skipping reader push — ${news.status} → $newStatus '
        //     '(not a publish transition)',
        //   );
        // }
        await _loadNews();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'News ${newStatus == 'published' ? 'approved' : newStatus}',
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  /// Fires `/api/send-notification` when an admin flips a news article to
  /// `published` from the management screen (Approve / Restore flow). Mirrors
  /// the trigger in news_upload_screen so backend logs look identical
  /// regardless of which entry point published the article.
  ///
  /// Currently unused — the call site in [_updateStatus] is commented out
  /// because the backend now owns the publish trigger.
  // ignore: unused_element
  Future<void> _fireNewsPushNotification(News news) async {
    final title = news.translations.isNotEmpty
        ? news.translations.first.title.trim()
        : '';
    final body = news.translations.isNotEmpty
        ? news.translations.first.shortDescription.trim()
        : '';
    final user = ref.read(authViewModelProvider).user;
    final stateIds = news.stateLocations.map((l) => l.id).toList();
    final districtIds = news.districtLocations.map((l) => l.id).toList();
    final mandalIds = news.mandalLocations.map((l) => l.id).toList();

    debugPrint('═════════════════════════════════════════════════════');
    debugPrint(
      '[NewsMgmt] 🔔 Firing push notification trigger (status change)',
    );
    debugPrint('[NewsMgmt]   news_id     = ${news.id}');
    debugPrint('[NewsMgmt]   title       = $title');
    debugPrint('[NewsMgmt]   body length = ${body.length}');
    debugPrint(
      '[NewsMgmt]   approver    = ${user?.name} '
      '(role=${user?.primaryRole.value}, id=${user?.id})',
    );
    debugPrint('[NewsMgmt]   state_ids   = $stateIds');
    debugPrint('[NewsMgmt]   district_ids= $districtIds');
    debugPrint('[NewsMgmt]   mandal_ids  = $mandalIds');
    debugPrint('[NewsMgmt]   target      = all');
    debugPrint('═════════════════════════════════════════════════════');

    try {
      final result = await NotificationRepositoryImpl().sendNotification(
        title: title.isEmpty ? 'New News Posted' : title,
        body: body.isEmpty ? 'Check out the latest update' : body,
        target: NotificationTarget.all,
        // Audience filters — top level, not inside `data`.
        stateIds: stateIds,
        districtIds: districtIds,
        mandalIds: mandalIds,
        // Payload the device receives; `news_id` is what lets a tap open
        // the article.
        data: {'type': 'news_published', 'news_id': news.id.toString()},
      );

      if (result == null) {
        debugPrint(
          '[NewsMgmt] ❌ sendNotification returned null '
          '(likely 4xx/5xx from backend — check API logs)',
        );
      } else {
        debugPrint(
          '[NewsMgmt] ✅ sendNotification result: '
          'success=${result.successCount}, '
          'failure=${result.failureCount}',
        );
      }
    } catch (e, st) {
      debugPrint('[NewsMgmt] ❌ sendNotification threw: $e\n$st');
    }
    debugPrint('═════════════════════════════════════════════════════');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFE07575);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'published':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'News Management',
          style: TextStyle(
            fontSize: scaledFontSize(18),
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: theme.appPrimary,
          unselectedLabelColor: theme.appTextLight,
          indicatorColor: theme.appPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontSize: scaledFontSize(13),
            fontWeight: FontWeight.w600,
          ),
          tabs: List.generate(_statuses.length, (i) {
            final count = _tabCount(_statuses[i]);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_statusLabels[i]),
                  if (!_isLoading && count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.appPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: scaledFontSize(11),
                          fontWeight: FontWeight.w700,
                          color: theme.appPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
      ),
      body: Column(
        children: [
          // Search bar + date filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(fontSize: scaledFontSize(14)),
                    decoration: InputDecoration(
                      hintText: 'Search by title or author...',
                      hintStyle: TextStyle(
                        color: theme.appTextLight,
                        fontSize: scaledFontSize(14),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.appTextLight,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                color: theme.appTextLight,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _pickDateRange(theme),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _dateRange != null
                          ? theme.appPrimary.withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),

                      border: Border.all(
                        color: theme.dividerColor.withOpacity(
                          0.2,
                        ), // very light border
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08), // light shadow
                          blurRadius: 6,
                          offset: const Offset(0, 2), // downward shadow
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.date_range,
                      size: 20,
                      color: _dateRange != null
                          ? theme.appPrimary
                          : theme.appTextLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Date range label
          if (_dateRange != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: theme.appPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year}'
                    ' – '
                    '${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
                    style: TextStyle(
                      fontSize: scaledFontSize(12),
                      color: theme.appPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _dateRange = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE07575).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: scaledFontSize(11),
                          color: const Color(0xFFE07575),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Location + Author filters
          if (!_isLoading)
            Builder(
              builder: (context) {
                // Derive available filter options from the actual news data
                final newsForFiltering = _allNews;

                // States available in news
                final availableStates = <_FilterItem>[];
                final stateIdsSeen = <int>{};
                for (final n in newsForFiltering) {
                  for (final loc in n.stateLocations) {
                    if (stateIdsSeen.add(loc.id)) {
                      availableStates.add(_FilterItem(loc.id, loc.value));
                    }
                  }
                }
                availableStates.sort((a, b) => a.name.compareTo(b.name));

                // Districts and mandals come straight off the news items, which
                // already carry `{id, value}` for every location they're tagged
                // to. Deriving them here (rather than from the location VM,
                // which only ever holds ONE district's mandals) is what lets
                // several districts be selected at once and still show the
                // union of their mandals.
                final newsAfterState = _selectedStateId != null
                    ? newsForFiltering
                          .where((n) => n.hasStateId(_selectedStateId!))
                          .toList()
                    : newsForFiltering;

                final availableDistricts = <_FilterItem>[];
                final districtIdsSeen = <int>{};
                for (final n in newsAfterState) {
                  for (final loc in n.districtLocations) {
                    if (districtIdsSeen.add(loc.id)) {
                      availableDistricts.add(_FilterItem(loc.id, loc.value));
                    }
                  }
                }
                availableDistricts.sort((a, b) => a.name.compareTo(b.name));

                // Mandals: union across every selected district.
                final newsAfterDistrict = _selectedDistrictIds.isNotEmpty
                    ? newsAfterState
                          .where(
                            (n) => _selectedDistrictIds.any(n.hasDistrictId),
                          )
                          .toList()
                    : newsAfterState;

                final availableMandals = <_FilterItem>[];
                final mandalIdsSeen = <int>{};
                for (final n in newsAfterDistrict) {
                  for (final loc in n.mandalLocations) {
                    if (mandalIdsSeen.add(loc.id)) {
                      availableMandals.add(_FilterItem(loc.id, loc.value));
                    }
                  }
                }
                availableMandals.sort((a, b) => a.name.compareTo(b.name));

                // Topics ("type") available in the loaded news. Derived the
                // same way as the location filters, since news items carry
                // their topics in the very same `locations` list.
                final availableTopics = <_FilterItem>[];
                final topicIdsSeen = <int>{};
                for (final n in newsForFiltering) {
                  for (final loc in n.topicLocations) {
                    if (topicIdsSeen.add(loc.id)) {
                      availableTopics.add(_FilterItem(loc.id, loc.value));
                    }
                  }
                }
                availableTopics.sort((a, b) => a.name.compareTo(b.name));

                // Author options come from the full user list, so every user is
                // selectable regardless of how many news pages have loaded.
                // Sub-admins / dist-reporters only see users in their own
                // state, matching how the rest of this screen is scoped.
                final userCtrl = ref.watch(
                  adminUserManagementControllerProvider,
                );
                final scopedUsers = _scope.showStateFilter
                    ? userCtrl.users
                    : userCtrl.users
                          .where(
                            (u) =>
                                _scope.scopeStateId == null ||
                                u.stateId == _scope.scopeStateId,
                          )
                          .toList();
                final userNames =
                    scopedUsers
                        .where((u) => u.name.trim().isNotEmpty)
                        .map((u) => _FilterItem(u.id, u.name.trim()))
                        .toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                // Fall back to authors of loaded news until the user list
                // arrives, so the chip is never empty on first paint.
                // Until the user list arrives there are no ids to filter by,
                // so the chip stays empty rather than offering names that
                // would send author_id: null and quietly filter nothing.
                final authors = userNames;

                final hasLocationFilter =
                    _selectedStateId != null ||
                    _selectedDistrictIds.isNotEmpty ||
                    _selectedMandalIds.isNotEmpty ||
                    _selectedTopicIds.isNotEmpty ||
                    _selectedAuthor != null;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (_scope.showStateFilter)
                          _buildLocationChip<_FilterItem>(
                            label: _selectedStateObj?.name ?? 'All States',
                            icon: Icons.map_outlined,
                            isSelected: _selectedStateId != null,
                            items: availableStates,
                            getName: (s) => s.name,
                            onSelected: (s) {
                              setState(() {
                                _selectedStateId = s.id;
                                _selectedStateObj = location_models.State(
                                  id: s.id,
                                  name: s.name,
                                  slug: '',
                                  isActive: true,
                                  createdAt: DateTime.now(),
                                );
                                _selectedDistrictIds.clear();
                                _selectedMandalIds.clear();
                                _selectedAuthor = null;
                              });
                            },
                            onClear: _clearLocationFilters,
                            theme: theme,
                          ),
                        if (_scope.showDistrictFilter &&
                            (_selectedStateId != null ||
                                _scope.scopeStateId != null)) ...[
                          const SizedBox(width: 8),
                          _buildMultiLocationChip(
                            label: _multiLabel(
                              selectedIds: _selectedDistrictIds,
                              items: availableDistricts,
                              emptyLabel: 'All Districts',
                              plural: 'districts',
                            ),
                            icon: Icons.location_city_outlined,
                            items: availableDistricts,
                            selectedIds: _selectedDistrictIds,
                            sheetTitle: 'Districts',
                            onChanged: (ids) {
                              setState(() {
                                _selectedDistrictIds
                                  ..clear()
                                  ..addAll(ids);
                                // Mandals belong to districts, so a district
                                // change invalidates any mandal narrowing.
                                _selectedMandalIds.clear();
                                _selectedAuthor = null;
                              });
                            },
                            theme: theme,
                          ),
                        ],
                        if (_scope.showMandalFilter &&
                            _selectedDistrictIds.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildMultiLocationChip(
                            label: _multiLabel(
                              selectedIds: _selectedMandalIds,
                              items: availableMandals,
                              emptyLabel: 'All Mandals',
                              plural: 'mandals',
                            ),
                            icon: Icons.place_outlined,
                            items: availableMandals,
                            selectedIds: _selectedMandalIds,
                            sheetTitle: 'Mandals',
                            onChanged: (ids) {
                              setState(() {
                                _selectedMandalIds
                                  ..clear()
                                  ..addAll(ids);
                                _selectedAuthor = null;
                              });
                            },
                            theme: theme,
                          ),
                        ],
                        // Topic ("type") filter.
                        if (availableTopics.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildMultiLocationChip(
                            label: _multiLabel(
                              selectedIds: _selectedTopicIds,
                              items: availableTopics,
                              emptyLabel: 'All Topics',
                              plural: 'topics',
                            ),
                            icon: Icons.tag_outlined,
                            items: availableTopics,
                            selectedIds: _selectedTopicIds,
                            sheetTitle: 'Topics',
                            onChanged: (ids) {
                              setState(() {
                                _selectedTopicIds
                                  ..clear()
                                  ..addAll(ids);
                              });
                            },
                            theme: theme,
                          ),
                        ],
                        // Author filter — lists all users (state-scoped for
                        // sub-admin / dist-reporter), not just loaded authors.
                        const SizedBox(width: 8),
                        _buildLocationChip<_FilterItem>(
                          label: _selectedAuthor ?? 'Author',
                          icon: Icons.person_outline,
                          isSelected: _selectedAuthor != null,
                          items: authors,
                          getName: (a) => a.name,
                          onSelected: (a) =>
                              _selectAuthor(id: a.id, name: a.name),
                          onClear: () => _selectAuthor(),
                          theme: theme,
                        ),
                        if (hasLocationFilter) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _clearLocationFilters,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE07575,
                                ).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFFE07575,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: const Color(0xFFE07575),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Clear',
                                    style: TextStyle(
                                      fontSize: scaledFontSize(11),
                                      color: const Color(0xFFE07575),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          // Content
          Expanded(
            child: _isLoading
                ? const InlineLoader(message: 'Loading news...')
                : _error != null
                ? _buildErrorView(theme)
                : TabBarView(
                    controller: _tabController,
                    children: _statuses
                        .map((status) => _buildNewsList(status, theme))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: theme.appTextLight),
          const SizedBox(height: 16),
          Text(
            'Failed to load news',
            style: TextStyle(
              fontSize: scaledFontSize(16),
              fontWeight: FontWeight.w600,
              color: theme.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadNews,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList(String status, ThemeData theme) {
    final news = _filteredNews(status);

    if (news.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 48, color: theme.appTextLight),
            const SizedBox(height: 12),
            Text(
              status == 'all' ? 'No news found' : 'No $status news',
              style: TextStyle(
                fontSize: scaledFontSize(15),
                color: theme.appTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 300) {
          _loadMoreNews();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _loadNews,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: news.length + (_hasMore && _isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= news.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: InlineLoader(),
              );
            }
            return _buildNewsCard(news[index], theme);
          },
        ),
      ),
    );
  }

  Widget _buildNewsCard(News news, ThemeData theme) {
    final title = news.translations.isNotEmpty
        ? news.translations.first.title
        : 'Untitled';
    final description = news.translations.isNotEmpty
        ? news.translations.first.shortDescription
        : '';
    final imageUrl = news.media
        .where((m) => m.type == 'image')
        .map((m) => m.fileUrl)
        .firstOrNull;
    final statusColor = _statusColor(news.status);
    final authorName = news.authorName ?? 'Unknown';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreenV2(initialNewsItem: news),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.2), // very light border
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // light shadow
              blurRadius: 6,
              offset: const Offset(0, 2), // downward shadow
            ),
          ],
        ),
        child: Column(
          children: [
            // Top: thumbnail + info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: imageUrl != null
                          ? CachedImageWidget(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: theme.appGrey200,
                              child: Icon(Icons.image, color: theme.appGrey400),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: scaledFontSize(14),
                            fontWeight: FontWeight.w600,
                            color: theme.appTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: scaledFontSize(12),
                            color: theme.appTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Location info
            if (news.locations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: GestureDetector(
                  onTap: () => _showLocationDetails(news, theme),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.appTextLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _buildLocationSummary(news),
                          style: TextStyle(
                            fontSize: scaledFontSize(11),
                            color: theme.appTextLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.appPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${news.locations.length} locations',
                          style: TextStyle(
                            fontSize: scaledFontSize(10),
                            fontWeight: FontWeight.w600,
                            color: theme.appPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Bottom: status + author + actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon(news.status),
                          size: 12,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          news.status.isNotEmpty
                              ? news.status[0].toUpperCase() +
                                    news.status.substring(1)
                              : 'Unknown',
                          style: TextStyle(
                            fontSize: scaledFontSize(11),
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Author
                  Expanded(
                    child: Text(
                      'by $authorName',
                      style: TextStyle(
                        fontSize: scaledFontSize(11),
                        color: theme.appTextLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Action buttons based on status and permissions
                  if (_scope.canApproveReject) ...[
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      color: const Color(0xFF2563EB),
                      onTap: () => _navigateToEdit(news),
                    ),
                    const SizedBox(width: 6),
                    if (news.status == 'pending')
                      _buildActionButton(
                        icon: Icons.close,
                        label: 'Reject',
                        color: const Color(0xFFE07575),
                        onTap: () => _updateStatus(news, 'rejected'),
                      ),
                    if (news.status == 'rejected')
                      _buildActionButton(
                        icon: Icons.restore,
                        label: 'Restore',
                        color: const Color(0xFF16A34A),
                        onTap: () => _updateStatus(news, 'pending'),
                      ),
                    if (news.status == 'published')
                      _buildActionButton(
                        icon: Icons.unpublished_outlined,
                        label: 'Unpublish',
                        color: const Color(0xFFF59E0B),
                        onTap: () => _updateStatus(news, 'pending'),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildLocationSummary(News news) {
    final states = news.stateLocations.map((l) => l.value).toList();
    final districts = news.districtLocations.map((l) => l.value).toList();
    final mandals = news.mandalLocations.map((l) => l.value).toList();
    final parts = <String>[];
    if (states.isNotEmpty) parts.add(states.join(', '));
    if (districts.isNotEmpty) parts.add(districts.join(', '));
    if (mandals.isNotEmpty) parts.add(mandals.join(', '));
    return parts.join(' > ');
  }

  void _showLocationDetails(News news, ThemeData theme) {
    final states = news.stateLocations;
    final districts = news.districtLocations;
    final mandals = news.mandalLocations;
    final topics = news.topicLocations;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Published Locations',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (topics.isNotEmpty) ...[
                _buildLocationDetailRow(
                  theme,
                  Icons.tag,
                  'Topics',
                  topics.map((l) => l.value).toList(),
                ),
                const SizedBox(height: 10),
              ],
              if (states.isNotEmpty) ...[
                _buildLocationDetailRow(
                  theme,
                  Icons.map_outlined,
                  'States',
                  states.map((l) => l.value).toList(),
                ),
                const SizedBox(height: 10),
              ],
              if (districts.isNotEmpty) ...[
                _buildLocationDetailRow(
                  theme,
                  Icons.location_city_outlined,
                  'Districts',
                  districts.map((l) => l.value).toList(),
                ),
                const SizedBox(height: 10),
              ],
              if (mandals.isNotEmpty)
                _buildLocationDetailRow(
                  theme,
                  Icons.place_outlined,
                  'Mandals',
                  mandals.map((l) => l.value).toList(),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationDetailRow(
    ThemeData theme,
    IconData icon,
    String label,
    List<String> values,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.appPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  fontWeight: FontWeight.w600,
                  color: theme.appTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: values
                    .map(
                      (v) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.appPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          v,
                          style: TextStyle(
                            fontSize: scaledFontSize(11),
                            color: theme.appPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationChip<T>({
    required String label,
    required IconData icon,
    required bool isSelected,
    required List<T> items,
    required String Function(T) getName,
    required void Function(T) onSelected,
    required VoidCallback onClear,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          onClear();
          return;
        }
        if (items.isEmpty) return;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          builder: (ctx) {
            return _LocationSearchSheet<T>(
              label: label,
              icon: icon,
              items: items,
              getName: getName,
              onSelected: (item) {
                onSelected(item);
                Navigator.pop(ctx);
              },
              theme: theme,
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.appPrimary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.2), // very light border
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // light shadow
              blurRadius: 6,
              offset: const Offset(0, 2), // downward shadow
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? theme.appPrimary : theme.appTextLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(12),
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.appPrimary : theme.appTextSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.close : Icons.keyboard_arrow_down,
              size: 16,
              color: isSelected ? theme.appPrimary : theme.appTextLight,
            ),
          ],
        ),
      ),
    );
  }

  /// Chip label for a multi-select filter: the name when exactly one thing is
  /// picked, a count when several are, and the "all" placeholder when none are.
  String _multiLabel({
    required Set<int> selectedIds,
    required List<_FilterItem> items,
    required String emptyLabel,
    required String plural,
  }) {
    if (selectedIds.isEmpty) return emptyLabel;
    if (selectedIds.length == 1) {
      final match = items.where((i) => i.id == selectedIds.first);
      if (match.isNotEmpty) return match.first.name;
    }
    return '${selectedIds.length} $plural';
  }

  /// Multi-select sibling of [_buildLocationChip]. Tapping the chip body opens
  /// a checkbox sheet; the trailing ✕ (shown only while something is picked)
  /// clears the filter without opening anything.
  Widget _buildMultiLocationChip({
    required String label,
    required IconData icon,
    required List<_FilterItem> items,
    required Set<int> selectedIds,
    required String sheetTitle,
    required ValueChanged<Set<int>> onChanged,
    required ThemeData theme,
  }) {
    final hasSelection = selectedIds.isNotEmpty;

    void openSheet() {
      if (items.isEmpty) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        builder: (ctx) => _MultiSelectSheet(
          title: sheetTitle,
          icon: icon,
          items: items,
          initialSelectedIds: selectedIds,
          onChanged: onChanged,
          theme: theme,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: hasSelection ? theme.appPrimary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: openSheet,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 4,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: hasSelection ? theme.appPrimary : theme.appTextLight,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: scaledFontSize(12),
                      fontWeight: FontWeight.w600,
                      color: hasSelection
                          ? theme.appPrimary
                          : theme.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: hasSelection ? () => onChanged(const {}) : openSheet,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 2,
                right: 10,
                top: 8,
                bottom: 8,
              ),
              child: Icon(
                hasSelection ? Icons.close : Icons.keyboard_arrow_down,
                size: 16,
                color: hasSelection ? theme.appPrimary : theme.appTextLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterItem {
  final int id;
  final String name;
  const _FilterItem(this.id, this.name);
}

class _LocationSearchSheet<T> extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<T> items;
  final String Function(T) getName;
  final void Function(T) onSelected;
  final ThemeData theme;

  const _LocationSearchSheet({
    required this.label,
    required this.icon,
    required this.items,
    required this.getName,
    required this.onSelected,
    required this.theme,
  });

  @override
  State<_LocationSearchSheet<T>> createState() =>
      _LocationSearchSheetState<T>();
}

class _LocationSearchSheetState<T> extends State<_LocationSearchSheet<T>> {
  String _query = '';

  List<T> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((item) => widget.getName(item).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: theme.appPrimary),
                const SizedBox(width: 8),
                Text(
                  'Select ${widget.label}',
                  style: TextStyle(
                    fontSize: scaledFontSize(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: scaledFontSize(14)),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: theme.appTextLight,
                  fontSize: scaledFontSize(14),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.appTextLight,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: scaledFontSize(14),
                        color: theme.appTextLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          widget.getName(item),
                          style: TextStyle(fontSize: scaledFontSize(14)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: theme.appTextLight,
                        ),
                        onTap: () => widget.onSelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Checkbox picker for the multi-select location filters. Applies each toggle
/// immediately via [onChanged] so the list behind the sheet updates live, and
/// offers a select-all/clear shortcut scoped to whatever the search matches —
/// searching "God" then tapping Select all picks only the Godavari districts.
class _MultiSelectSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<_FilterItem> items;
  final Set<int> initialSelectedIds;
  final ValueChanged<Set<int>> onChanged;
  final ThemeData theme;

  const _MultiSelectSheet({
    required this.title,
    required this.icon,
    required this.items,
    required this.initialSelectedIds,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<int> _selected = {...widget.initialSelectedIds};
  String _query = '';

  List<_FilterItem> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();
  }

  void _apply() => widget.onChanged({..._selected});

  void _toggle(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
    _apply();
  }

  void _toggleAllFiltered() {
    final filteredIds = _filtered.map((i) => i.id).toList();
    final allPicked = filteredIds.every(_selected.contains);
    setState(() {
      if (allPicked) {
        _selected.removeAll(filteredIds);
      } else {
        _selected.addAll(filteredIds);
      }
    });
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final filtered = _filtered;
    final allPicked =
        filtered.isNotEmpty && filtered.every((i) => _selected.contains(i.id));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: theme.appPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select ${widget.title}',
                    style: TextStyle(
                      fontSize: scaledFontSize(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (filtered.isNotEmpty)
                  TextButton(
                    onPressed: _toggleAllFiltered,
                    child: Text(
                      allPicked ? 'Clear all' : 'Select all',
                      style: TextStyle(
                        fontSize: scaledFontSize(13),
                        fontWeight: FontWeight.w600,
                        color: theme.appPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: scaledFontSize(14)),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: theme.appTextLight,
                  fontSize: scaledFontSize(14),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.appTextLight,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: scaledFontSize(14),
                        color: theme.appTextLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      final picked = _selected.contains(item.id);
                      return CheckboxListTile(
                        dense: true,
                        value: picked,
                        activeColor: theme.appPrimary,
                        controlAffinity: ListTileControlAffinity.trailing,
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: scaledFontSize(14),
                            fontWeight: picked
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onChanged: (_) => _toggle(item.id),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.appPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Done'
                        : 'Done · ${_selected.length} selected',
                    style: TextStyle(
                      fontSize: scaledFontSize(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Determines what news the current user can see & manage.
class _NewsScope {
  final bool canApproveReject;
  final bool showStateFilter;
  final bool showDistrictFilter;
  final bool showMandalFilter;
  final int? scopeStateId;

  const _NewsScope({
    required this.canApproveReject,
    this.showStateFilter = false,
    this.showDistrictFilter = false,
    this.showMandalFilter = false,
    this.scopeStateId,
  });

  factory _NewsScope.forUser(User? user) {
    if (user == null) {
      return const _NewsScope(canApproveReject: false);
    }

    final role = user.primaryRole.value;
    switch (role) {
      case 'admin':
        return const _NewsScope(
          canApproveReject: true,
          showStateFilter: true,
          showDistrictFilter: true,
          showMandalFilter: true,
        );
      // Dist-reporters manage the same pool as sub-admins — every district
      // and mandal in their state, not just their own district. The two roles
      // only diverge outside this screen: sub-admins additionally get User
      // Management, which dist-reporters don't see (see profile_screen).
      case 'sub_admin':
      case 'dist-reporter':
        return _NewsScope(
          canApproveReject: true,
          showDistrictFilter: true,
          showMandalFilter: true,
          scopeStateId: user.stateId,
        );
      default:
        return const _NewsScope(canApproveReject: false);
    }
  }

  /// Filter news list to only include news within this scope.
  List<News> applyScope(List<News> news) {
    var list = news;

    if (scopeStateId != null) {
      list = list.where((n) => n.hasStateId(scopeStateId!)).toList();
    }

    return list;
  }
}
