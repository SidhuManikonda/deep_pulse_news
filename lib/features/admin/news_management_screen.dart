import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/news.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/user.dart';
import '../../data/repositories/news_repository.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/cached_image_widget.dart';
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
  DateTimeRange? _dateRange;
  int? _selectedStateId;
  int? _selectedDistrictId;
  int? _selectedMandalId;
  location_models.State? _selectedStateObj;
  District? _selectedDistrictObj;
  Mandal? _selectedMandalObj;
  String? _selectedAuthor;

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
    _loadNews();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationVM = ref.read(locationViewModelProvider);
      if (_scope.showStateFilter &&
          locationVM.states.isEmpty &&
          !locationVM.isLoadingStates) {
        locationVM.loadStates();
      }
      // Sub-admin: auto-load districts for their state
      if (_scope.showDistrictFilter &&
          _scope.scopeStateId != null &&
          !_scope.showStateFilter) {
        locationVM.loadDistricts(_scope.scopeStateId!);
      }
      // Dist-reporter: auto-load mandals for their district
      if (_scope.showMandalFilter &&
          _scope.scopeDistrictId != null &&
          !_scope.showDistrictFilter) {
        locationVM.loadMandals(_scope.scopeDistrictId!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
      final response = await _newsRepo.getNews(userId: userId);
      final scopedNews = _scope.applyScope(response.data);
      scopedNews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _allNews = scopedNews;
          _nextCursor = response.nextCursor;
          _hasMore = response.hasMore;
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
    if (_selectedDistrictId != null) {
      list = list.where((n) => n.hasDistrictId(_selectedDistrictId!)).toList();
    }
    if (_selectedMandalId != null) {
      list = list.where((n) => n.hasMandalId(_selectedMandalId!)).toList();
    }
    if (_selectedAuthor != null) {
      list = list.where((n) => n.authorName == _selectedAuthor).toList();
    }
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
      _selectedDistrictId = null;
      _selectedDistrictObj = null;
      _selectedMandalId = null;
      _selectedMandalObj = null;
      _selectedAuthor = null;
    });
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
            final count = _filteredNews(_statuses[i]).length;
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
                    onChanged: (v) => setState(() => _searchQuery = v),
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
                                setState(() => _searchQuery = '');
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

                // Districts: use location VM (already loaded for the selected state)
                // and intersect with districts that appear in the news
                final locationVM = ref.watch(locationViewModelProvider);
                final newsAfterState = _selectedStateId != null
                    ? newsForFiltering
                          .where((n) => n.hasStateId(_selectedStateId!))
                          .toList()
                    : newsForFiltering;

                // Get district IDs that actually appear in filtered news
                final newsDistrictIds = <int>{};
                for (final n in newsAfterState) {
                  for (final loc in n.districtLocations) {
                    newsDistrictIds.add(loc.id);
                  }
                }
                // Only show districts from the VM that are in the news
                final availableDistricts = locationVM.districts
                    .where((d) => newsDistrictIds.contains(d.id))
                    .map((d) => _FilterItem(d.id, d.name))
                    .toList();

                // Mandals: same approach
                final newsAfterDistrict = _selectedDistrictId != null
                    ? newsAfterState
                          .where((n) => n.hasDistrictId(_selectedDistrictId!))
                          .toList()
                    : newsAfterState;
                final newsMandalIds = <int>{};
                for (final n in newsAfterDistrict) {
                  for (final loc in n.mandalLocations) {
                    newsMandalIds.add(loc.id);
                  }
                }
                final availableMandals = locationVM.mandals
                    .where((m) => newsMandalIds.contains(m.id))
                    .map((m) => _FilterItem(m.id, m.name))
                    .toList();

                // Authors available based on current location filters
                final newsAfterMandal = _selectedMandalId != null
                    ? newsAfterDistrict
                          .where((n) => n.hasMandalId(_selectedMandalId!))
                          .toList()
                    : newsAfterDistrict;
                final authors =
                    newsAfterMandal
                        .map((n) => n.authorName)
                        .where((a) => a != null && a.isNotEmpty)
                        .cast<String>()
                        .toSet()
                        .toList()
                      ..sort();

                // Role names from news authors
                final authorRoles = newsAfterMandal
                    .map((n) => n.authorName)
                    .where((a) => a != null)
                    .cast<String>()
                    .toSet()
                    .toList();

                final hasLocationFilter =
                    _selectedStateId != null ||
                    _selectedDistrictId != null ||
                    _selectedMandalId != null ||
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
                                _selectedDistrictId = null;
                                _selectedDistrictObj = null;
                                _selectedMandalId = null;
                                _selectedMandalObj = null;
                                _selectedAuthor = null;
                              });
                              ref
                                  .read(locationViewModelProvider)
                                  .loadDistricts(s.id);
                            },
                            onClear: _clearLocationFilters,
                            theme: theme,
                          ),
                        if (_scope.showDistrictFilter &&
                            (_selectedStateId != null ||
                                _scope.scopeStateId != null)) ...[
                          const SizedBox(width: 8),
                          _buildLocationChip<_FilterItem>(
                            label:
                                _selectedDistrictObj?.name ?? 'All Districts',
                            icon: Icons.location_city_outlined,
                            isSelected: _selectedDistrictId != null,
                            items: availableDistricts,
                            getName: (d) => d.name,
                            onSelected: (d) {
                              setState(() {
                                _selectedDistrictId = d.id;
                                _selectedDistrictObj = District(
                                  id: d.id,
                                  stateId: _selectedStateId ?? 0,
                                  name: d.name,
                                  slug: '',
                                  isActive: true,
                                  createdAt: DateTime.now(),
                                );
                                _selectedMandalId = null;
                                _selectedMandalObj = null;
                                _selectedAuthor = null;
                              });
                              ref
                                  .read(locationViewModelProvider)
                                  .loadMandals(d.id);
                            },
                            onClear: () {
                              setState(() {
                                _selectedDistrictId = null;
                                _selectedDistrictObj = null;
                                _selectedMandalId = null;
                                _selectedMandalObj = null;
                                _selectedAuthor = null;
                              });
                            },
                            theme: theme,
                          ),
                        ],
                        if (_scope.showMandalFilter &&
                            (_selectedDistrictId != null ||
                                _scope.scopeDistrictId != null)) ...[
                          const SizedBox(width: 8),
                          _buildLocationChip<_FilterItem>(
                            label: _selectedMandalObj?.name ?? 'All Mandals',
                            icon: Icons.place_outlined,
                            isSelected: _selectedMandalId != null,
                            items: availableMandals,
                            getName: (m) => m.name,
                            onSelected: (m) {
                              setState(() {
                                _selectedMandalId = m.id;
                                _selectedMandalObj = Mandal(
                                  id: m.id,
                                  districtId: _selectedDistrictId ?? 0,
                                  name: m.name,
                                  slug: '',
                                  isActive: true,
                                  createdAt: DateTime.now(),
                                );
                                _selectedAuthor = null;
                              });
                            },
                            onClear: () {
                              setState(() {
                                _selectedMandalId = null;
                                _selectedMandalObj = null;
                                _selectedAuthor = null;
                              });
                            },
                            theme: theme,
                          ),
                        ],
                        // Author filter — only shows authors with news in current location
                        const SizedBox(width: 8),
                        _buildLocationChip<String>(
                          label: _selectedAuthor ?? 'Author',
                          icon: Icons.person_outline,
                          isSelected: _selectedAuthor != null,
                          items: authors,
                          getName: (a) => a,
                          onSelected: (a) =>
                              setState(() => _selectedAuthor = a),
                          onClear: () => setState(() => _selectedAuthor = null),
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
                ? const Center(child: CircularProgressIndicator())
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
                child: Center(child: CircularProgressIndicator()),
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

/// Determines what news the current user can see & manage.
class _NewsScope {
  final bool canApproveReject;
  final bool showStateFilter;
  final bool showDistrictFilter;
  final bool showMandalFilter;
  final int? scopeStateId;
  final int? scopeDistrictId;
  final int? scopeMandalId;

  const _NewsScope({
    required this.canApproveReject,
    this.showStateFilter = false,
    this.showDistrictFilter = false,
    this.showMandalFilter = false,
    this.scopeStateId,
    this.scopeDistrictId,
    this.scopeMandalId,
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
      case 'sub_admin':
        return _NewsScope(
          canApproveReject: true,
          showDistrictFilter: true,
          showMandalFilter: true,
          scopeStateId: user.stateId,
        );
      case 'dist-reporter':
        return _NewsScope(
          canApproveReject: true,
          showMandalFilter: true,
          scopeStateId: user.stateId,
          scopeDistrictId: user.districtId,
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
    if (scopeDistrictId != null) {
      list = list.where((n) => n.hasDistrictId(scopeDistrictId!)).toList();
    }
    if (scopeMandalId != null) {
      list = list.where((n) => n.hasMandalId(scopeMandalId!)).toList();
    }

    return list;
  }
}
