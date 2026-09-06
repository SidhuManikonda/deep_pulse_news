import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:deep_pulse_news/features/home/more_topics_screen.dart';
import 'package:deep_pulse_news/features/profile/profile_screen.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:deep_pulse_news/shared/widgets/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/news_view_tracker_service.dart';
import '../../core/utils/color_utils.dart';
import '../../shared/widgets/app_loader.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/services/saved_news_service.dart';
import '../../core/services/video_preloader_service.dart';
import '../../data/models/likeable_type.dart';
import '../../data/models/news.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/topic.dart';
import '../../enums/user_role.dart';
import '../../extensions/user_extensions.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../shared/widgets/news_ad_block.dart';
import '../../data/models/feed_entry.dart';
import 'widgets/full_page_ad_card.dart';
import '../../shared/widgets/report_bottom_sheet.dart';
import '../auth/auth_helper.dart';
import '../comments/comments_screen.dart';
import '../news/fullscreen_video_screen.dart';
import '../news/news_detail_screen_v2.dart';
import '../news/news_poster_screen.dart';
import '../news/news_upload_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/audio_player_widget.dart';
import 'home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _videoPreloader = VideoPreloaderService();
  final _newsViewTracker = NewsViewTrackerService();
  final NotificationRepository _notifRepo = NotificationRepositoryImpl();
  int _unreadNotifications = 0;
  final Map<int, int> _currentCarouselPages = {};

  /// Holds off media preloading until the feed stops moving — see
  /// [_onFeedPageSettled].
  Timer? _preloadDebounce;

  /// Last article index read in each tab, keyed by tab name. Each tab's pager
  /// is rebuilt from scratch on switch (it owns its own PageController), so
  /// without this every tab change dropped the reader back at the first
  /// article.
  final Map<String, int> _tabPositions = {};

  /// Who may download an article as a shareable poster: everyone with a staff
  /// role. Readers and logged-out guests don't get the option.
  bool get _canDownloadPoster {
    final user = ref.read(authViewModelProvider).user;
    if (user == null) return false;
    return user.primaryRole.level >= UserRole.reporter.level;
  }

  // No PageController here: each tab's feed owns its own inside _TabFeedPager,
  // so switching tabs can't carry a stale scroll offset across.

  @override
  void dispose() {
    // Stop any pending dwell timer so a navigated-away article isn't
    // counted as viewed.
    _newsViewTracker.cancelPendingView();
    _preloadDebounce?.cancel();
    super.dispose();
  }

  // Raw pointer tracking for the swipe-to-change-tab gesture. See the Listener
  // in build() for why this isn't a GestureDetector.
  Offset? _dragStart;
  double _dragDx = 0;
  double _dragDy = 0;

  /// Set when a descendant scrollable (the multi-image carousel) handles a
  /// horizontal scroll during the current gesture. That swipe belongs to it,
  /// not to the tab switcher.
  bool _innerHorizontalScroll = false;

  /// Decides, once the finger lifts, whether the gesture was a deliberate
  /// sideways swipe and not part of scrolling the feed. Two guards, both
  /// needed:
  ///   * it must travel far enough sideways (72px) to be intentional; and
  ///   * sideways travel must beat total vertical travel by 2×, so a scroll
  ///     that drifts a little left or right is never mistaken for a tab swipe.
  void _evaluateTabSwipe() {
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return;

    // The image carousel (or any other horizontal scrollable) already used
    // this swipe — changing tabs on top of that is the bug where paging
    // through photos jumped to All Info.
    if (_innerHorizontalScroll) return;

    const minHorizontal = 72.0;
    if (_dragDx.abs() < minHorizontal) return;
    if (_dragDx.abs() < _dragDy * 2) return;

    // Negative dx = swipe left → next tab. Positive = swipe right → previous.
    _switchTabByOffset(_dragDx < 0 ? 1 : -1);
  }

  void _switchTabByOffset(int offset) {
    final homeViewModel = ref.read(homeViewModelProvider);
    final tabs = homeViewModel.getLocationTabs();
    final currentTab = homeViewModel.selectedLocationTab;
    final currentIndex = tabs.indexWhere((t) => t['name'] == currentTab);
    if (currentIndex == -1) return;

    final newIndex = currentIndex + offset;
    if (newIndex < 0 || newIndex >= tabs.length) return;

    // No page reset needed — the new tab builds a fresh pager at page 0.
    _videoPreloader.pauseAllVideos();
    _newsViewTracker.cancelPendingView();
    homeViewModel.setSelectedLocationTab(tabs[newIndex]['name'] as String);
  }

  @override
  void initState() {
    super.initState();
    // Initialize the view model and auth state lazily when entering home screen
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Run auth and home init in parallel — home doesn't need to wait for auth.
      // After auth settles, silently reload news so per-user like status is correct.
      await Future.wait([
        ref.read(authViewModelProvider).initializeAuth(),
        ref.read(homeViewModelProvider).initialize(),
      ]);
      if (ref.read(authViewModelProvider).user != null) {
        // Auth finished after initialize() kicked off, so re-read location now
        // that the user is known — this lets the account-location fallback
        // (in loadLocationData) fill in the area when device storage is empty,
        // then reload the feed so "Your Area" filters to the right state
        // instead of briefly showing every state's news.
        await ref.read(homeViewModelProvider).loadLocationData();
        ref.read(homeViewModelProvider).loadNewsData(silent: true);
      }
      _loadUnreadCount();
    });
  }

  /// Fetches the unread notification count for the bell badge. Safe to call
  /// when logged out — the repository returns 0 on any failure.
  Future<void> _loadUnreadCount() async {
    final count = await _notifRepo.getUnreadCount();
    if (mounted && count != _unreadNotifications) {
      setState(() => _unreadNotifications = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header with logo and profile
              _buildHeader(context),

              // Location tabs - fixed position with horizontal scrolling
              _buildLocationTabs(context),

              // Main content area - News feed only.
              // Horizontal flick switches tabs. The vertical PageView inside
              // _buildNewsFeed handles vertical scrolling — Flutter's gesture
              // arena routes the two axes independently so they don't conflict.
              //
              // No AnimatedSwitcher here on purpose: cross-fading the tabs kept
              // the outgoing feed alive for 300ms, which meant the previous
              // tab's articles stayed on screen during the switch AND two
              // PageViews shared one controller. Swapping instantly avoids both.
              // Listener, not GestureDetector, on purpose. A GestureDetector's
              // horizontal drag recognizer *competes* with the feed's vertical
              // scroll in the gesture arena, and it wins whenever the vertical
              // one can't move (single-article tab, or already at the end) —
              // which is why ordinary scrolling kept flipping to another tab.
              // A Listener only observes raw pointer events, so the PageView
              // keeps every gesture; we just measure the pointer ourselves and
              // switch tabs only when the movement is clearly sideways.
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.deferToChild,
                  onPointerDown: (e) {
                    _dragStart = e.position;
                    _dragDx = 0;
                    _dragDy = 0;
                    _innerHorizontalScroll = false;
                  },
                  onPointerMove: (e) {
                    _dragDx += e.delta.dx;
                    _dragDy += e.delta.dy.abs();
                  },
                  onPointerUp: (_) => _evaluateTabSwipe(),
                  onPointerCancel: (_) => _dragStart = null,
                  // A Listener sees raw pointer events and never joins the
                  // gesture arena, so it can't tell that something inside
                  // already claimed the swipe — paging the multi-image
                  // carousel used to advance the photo AND flip the tab.
                  // Scroll notifications do bubble up, so a horizontal scroll
                  // from any descendant marks this gesture as "already spoken
                  // for". The feed's own scrolling is vertical, so it never
                  // trips this.
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.axis == Axis.horizontal) {
                        _innerHorizontalScroll = true;
                      }
                      return false; // keep letting it bubble
                    },
                    child: _buildNewsFeed(context),
                  ),
                ),
              ),

              // Bottom navigation
              _buildBottomNavigation(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              AppLogo(size: 36, borderRadius: 8),
              const SizedBox(width: 8),
              Text(
                'Deep Pulse',
                style: TextStyle(
                  fontSize: appFontSizeHeader,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
              ),
            ],
          ),

          // Profile icon
          InkWell(
            onTap: () async {
              // Pause any playing video before leaving the home screen.
              // Without this, audio kept playing in the background while the
              // user was on the profile screen.
              _videoPreloader.pauseAllVideos();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).appGrey300,
              child: Icon(
                Icons.person,
                size: 20,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pill-shaped badge overlaid on the bottom-left of the news media that
  /// shows the author's profile photo (initial-letter fallback), name, and
  /// role label (e.g. "Reporter"). Built from the nested `author` object the
  /// `/news` API now ships — see [News.fromJson].
  /// Deterministic avatar background color derived from the author name, so
  /// each author gets a stable, distinct color for their initial fallback.
  Color _avatarColor(String seed) {
    const palette = [
      Color(0xFFE0245E), // pink/red
      Color(0xFF1DA1F2), // blue
      Color(0xFF7C3AED), // purple
      Color(0xFF16A34A), // green
      Color(0xFFF59E0B), // amber
      Color(0xFF0EA5E9), // sky
    ];
    if (seed.isEmpty) return palette[0];
    final sum = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[sum % palette.length];
  }

  Widget _buildAuthorBadge(News newsItem) {
    final photo = newsItem.authorProfilePhoto;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final name = newsItem.authorName ?? '';
    final role = newsItem.authorRoleName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget avatar = Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        // Solid color circle (no translucent white fill / border) so there's
        // no whitish halo bleeding through over the image behind it.
        color: _avatarColor(name),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedImageWidget(
              imageUrl: photo,
              fit: BoxFit.cover,
              errorWidget: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
              if (role != null && role.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    role,
                    style: TextStyle(
                      fontSize: scaledFontSize(10),
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTabs(BuildContext context) {
    final homeViewModel = ref.watch(homeViewModelProvider);
    final tabs = homeViewModel.getLocationTabs();

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: tabs.map((tab) {
          final tabName = tab['name'] as String;
          final displayName = tab['displayName'] as String;
          final isSelected = homeViewModel.selectedLocationTab == tabName;

          return Expanded(
            child: InkWell(
              onTap: () async {
                // "More" opens topic browsing, which is a signed-in feature —
                // same gate the upload button uses. Asking here rather than
                // letting the tab open and failing later means the reader is
                // never shown a section they can't actually use.
                if (tabName == 'More' &&
                    !ref.read(authViewModelProvider).isAuthenticated) {
                  final loggedIn = await AuthHelper.requireAuth(
                    context,
                    ref,
                    title: 'Login to Explore',
                    message: 'Please login to browse more topics.',
                  );
                  // Cancelled, or came back from sign-in without completing it:
                  // leave the reader on the tab they were already reading.
                  if (!loggedIn || !mounted) return;
                }

                // The pager is keyed on the tab name, so switching tabs
                // rebuilds it at page 0 with a fresh controller — nothing to
                // reset by hand here.
                _videoPreloader.pauseAllVideos();
                _newsViewTracker.cancelPendingView();
                ref.read(homeViewModelProvider).setSelectedLocationTab(tabName);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: scaledFontSize(15),
                        color: isSelected
                            ? Theme.of(context).appPrimary
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        height: 2,
                        width: 35,
                        decoration: BoxDecoration(
                          color: Theme.of(context).appPrimary,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNewsFeed(BuildContext context) {
    final homeViewModel = ref.watch(homeViewModelProvider);

    // Show topics grid for More tab
    if (homeViewModel.selectedLocationTab == 'More') {
      return MoreTopicsWidget();
    }

    if (homeViewModel.isLoadingNews) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (_, __) => const NewsCardSkeleton(),
      );
    }

    if (homeViewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading news',
              style: TextStyle(
                fontSize: appFontSizeBody,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => homeViewModel.refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final newsItems = homeViewModel.newsItems;
    final entries = homeViewModel.feedEntries;

    if (newsItems.isEmpty) {
      // A tab that's still pulling articles gets the skeleton, not the empty
      // state — flashing "No news available" for a second and then filling in
      // reads as a bug even though the fetch is working normally.
      if (homeViewModel.isFillingTab) {
        return ListView.builder(
          itemCount: 3,
          itemBuilder: (_, __) => const NewsCardSkeleton(),
        );
      }
      return Center(
        child: Text(
          'No news available for ${homeViewModel.selectedLocationTab}',
          style: TextStyle(
            fontSize: appFontSizeBody,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      );
    }

    // RefreshIndicator wrapping a vertical PageView causes gesture conflicts
    // (both fight for the same vertical drag → "sometimes doesn't scroll").
    // Pull-to-refresh is handled by swiping past page 0 via onPageChanged below.
    //
    // The ValueKey rebuilds the pager from scratch on every tab change, and
    // because the pager owns its PageController that means a fresh controller
    // starting at page 0 — no scroll offset carried over from the tab you just
    // left, and never two PageViews sharing one controller.
    // Resume each tab where the reader left it. Clamped because a refresh can
    // return a shorter list than the one they were scrolled into.
    final tabKey = homeViewModel.selectedLocationTab;
    final remembered = (_tabPositions[tabKey] ?? 0).clamp(
      0,
      entries.length - 1,
    );

    return _TabFeedPager(
      key: ValueKey(tabKey),
      itemCount: entries.length,
      initialPage: remembered,
      onNearEnd: () => ref.read(homeViewModelProvider).loadMoreNews(),
      // Silent, so the articles already on screen stay put while the reload
      // runs — the pager shows its own spinner instead of blanking to a
      // skeleton and losing the reader's place.
      onRefresh: () async {
        _tabPositions[homeViewModel.selectedLocationTab] = 0;
        await ref.read(homeViewModelProvider).loadNewsData(silent: true);
      },
      onPageSettled: (index) {
        _tabPositions[tabKey] = index;
        _onFeedPageSettled(entries, index);
      },
      itemBuilder: (context, index, isActive) {
        final entry = entries[index];
        final ad = entry.ad;
        if (ad != null) {
          return FullPageAdCard(ad: ad, isActive: isActive);
        }
        return _buildNewsCard(context, entry.news!, index, isActive);
      },
    );
  }

  /// Called when the feed lands on an article — both on first build and on
  /// every page change. Preloads neighbouring videos and starts the 10s dwell
  /// timer that decides whether this counts as a view. Quick scroll-pasts
  /// don't count; the tracker also enforces a 5-minute per-article cooldown so
  /// scrolling back doesn't double-count.
  void _onFeedPageSettled(List<FeedEntry> entries, int index) {
    if (index < 0 || index >= entries.length) return;

    // An advert isn't an article: it has no id to count a view against and no
    // dwell to record. Cancel any pending view from the story just left, warm
    // the neighbours so the next story is ready, and stop there.
    final news = entries[index].news;
    if (news == null) {
      _newsViewTracker.cancelPendingView();
      _preloadDebounce?.cancel();
      _preloadDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _preloadAdjacentVideos(entries, index);
      });
      return;
    }

    // Preloading opens video controllers and decodes images — real work. Fired
    // on every page the user flicks through, it lands mid-scroll and stalls the
    // frame. Waiting for the scroll to actually settle means one preload pass
    // instead of one per page skipped past.
    _preloadDebounce?.cancel();
    _preloadDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _preloadAdjacentVideos(entries, index);
    });

    _newsViewTracker.cancelPendingView();
    final userId = ref.read(authViewModelProvider).user?.id;
    final newsId = news.id;
    _newsViewTracker.scheduleView(
      newsId,
      userId: userId,
      onCounted: () =>
          ref.read(homeViewModelProvider).incrementViewCount(newsId),
    );
  }

  Widget _buildTopicsGrid(BuildContext context) {
    final homeViewModel = ref.watch(homeViewModelProvider);

    if (homeViewModel.isLoadingTopics) {
      return const InlineLoader(message: 'Loading topics...');
    }

    if (homeViewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading topics',
              style: TextStyle(
                fontSize: appFontSizeBody,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(homeViewModelProvider).loadTopicsData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final topics = homeViewModel.topics;

    if (topics.isEmpty) {
      return Center(
        child: Text(
          'No topics available',
          style: TextStyle(
            fontSize: appFontSizeBody,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(homeViewModelProvider).loadTopicsData(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: topics.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 👈 2 columns
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, index) {
          final topic = topics[index];

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onTopicTap(context, topic),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).appCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔹 Icon (random color circle)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).appPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.category,
                      color: Theme.of(context).appPrimary,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔹 Topic Name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      topic.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: scaledFontSize(14),
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onTopicTap(BuildContext context, Topic topic) {
    // Select the topic and switch to its dynamic tab
    ref.read(homeViewModelProvider).selectTopic(topic);
  }

  Widget _buildNewsCard(
    BuildContext context,
    News newsItem,
    int index,
    bool isCurrentPage,
  ) {
    return SizedBox.expand(
      child: Container(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).appCard,
          borderRadius: AppRadius.mdAll,
          boxShadow: Theme.of(context).shadowMd,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Media section - dynamic height based on content
                _buildMediaSection(context, newsItem, isCurrentPage, index),

                // Text content section - takes remaining space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 50),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getNewsTitle(newsItem),
                          style: TextStyle(
                            fontSize: scaledFontSize(18),
                            fontWeight: FontWeight.bold,
                            // Author-picked title color, falling back to the
                            // theme color when none was set.
                            color: colorFromHex(newsItem.titleColor) ??
                                Theme.of(context).appTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: _buildDescriptionWithReadMore(
                            context,
                            _getNewsDescription(newsItem),
                            newsItem,
                          ),
                        ),
                        // Only the first ad runs in the feed. A card is exactly
                        // one screen tall, so every pixel here is taken from
                        // the story — the second creative gets its run on the
                        // detail page, where the article can scroll.
                        //
                        // Sized rather than flexible on purpose: the
                        // description above measures itself against whatever
                        // height is left, so a fixed strip makes it truncate to
                        // fit instead of overflowing the card.
                        if (newsItem.ads.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          NewsAdBlock(
                            ad: newsItem.ads.first,
                            maxHeight: 96,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Inside the card bounds — extending below would overlap the next
            // PageView page and steal touch events meant for vertical scroll.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildNewInteractionBar(context, newsItem),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(
    BuildContext context,
    News newsItem,
    bool isVisible,
    int newsItemIndex,
  ) {
    final shouldAutoPlay = ref.watch(autoPlayProvider).enabled;

    final mediaItems = newsItem.media.toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) {
      return const SizedBox.shrink();
    }

    if (mediaCount == 1) {
      // Single media item
      final media = mediaItems[0];
      final screenHeight = MediaQuery.of(context).size.height;
      final isVideo = media.type == 'video';
      final isAudio = media.type == 'audio';

      // Videos keep a fixed landscape box; audio shows a compact player;
      // images size to their original aspect ratio so screenshots/portrait
      // images show fully (no crop/stretch).
      final Widget mediaChild = isAudio
          ? SizedBox(
              width: double.infinity,
              height: screenHeight * 0.24,
              child: ClipRRect(
                borderRadius: AppRadius.smAll,
                child: AudioPlayerWidget(
                  audioUrl: media.fileUrl,
                  isVisible: isVisible,
                ),
              ),
            )
          : isVideo
          ? SizedBox(
              width: double.infinity,
              height: screenHeight * 0.28,
              child: ClipRRect(
                borderRadius: AppRadius.smAll,
                child: VideoPlayerWidget(
                  videoUrl: media.fileUrl,
                  autoPlay: shouldAutoPlay,
                  isVisible: isVisible,
                ),
              ),
            )
          : ClipRRect(
              borderRadius: AppRadius.smAll,
              child: AdaptiveCachedImage(
                imageUrl: media.fileUrl,
                backgroundColor: Theme.of(context).appGrey200,
                // Show the full original image (no crop), filling the side
                // letterbox of tall/portrait images with a blurred copy so the
                // media still reads as full-width instead of flat grey bars.
                blurredBackground: true,
                // Cap tall portrait images so they don't take over the feed;
                // the full image still shows (contained) within the cap.
                maxHeight: screenHeight * 0.32,
                errorWidget: Container(
                  color: Theme.of(context).appGrey200,
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 64,
                      color: Theme.of(context).appGrey400,
                    ),
                  ),
                ),
              ),
            );

      return SizedBox(
        width: double.infinity,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: Theme.of(context).appGrey200,
            borderRadius: AppRadius.smAll,
          ),
          child: Stack(
            children: [
              mediaChild,
              // Author overlay at bottom left — only when the author opted to
              // show their profile and a name is available. Shows their
              // profile photo (avatar fallback if missing) + name + role.
              if (newsItem.showProfile &&
                  newsItem.authorName != null &&
                  newsItem.authorName!.isNotEmpty)
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: _buildAuthorBadge(newsItem),
                ),
              // App logo/name overlay at bottom right (small and subtle)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogo(size: 16, borderRadius: 4),
                      const SizedBox(width: 4),
                      Text(
                        'Deep Pulse',
                        style: TextStyle(
                          fontSize: scaledFontSize(10),
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (media.type == 'video')
                Positioned(
                  top: 10,
                  left: 10,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FullscreenVideoScreen(
                            videoUrl: media.fileUrl,
                            title: _getNewsTitle(newsItem),
                            createdAt: newsItem.displayTime,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: AppRadius.xsAll,
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      // Multiple media items with PageView slider (up to 3)
      final currentCarouselPage = _currentCarouselPages[newsItemIndex] ?? 0;

      return SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.28,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: PageView.builder(
                itemCount: mediaCount,
                onPageChanged: (page) {
                  setState(() {
                    _currentCarouselPages[newsItemIndex] = page;
                  });
                  // Pause all videos in this carousel when switching pages
                  _videoPreloader.pauseAllVideos();
                },
                itemBuilder: (context, carouselIndex) {
                  final media = mediaItems[carouselIndex];
                  final isMediaVisible =
                      isVisible && carouselIndex == currentCarouselPage;

                  return SizedBox.expand(
                    child: media.type == 'video'
                        ? VideoPlayerWidget(
                            videoUrl: media.fileUrl,
                            autoPlay: shouldAutoPlay,
                            isVisible: isMediaVisible,
                          )
                        : media.type == 'audio'
                        ? Center(
                            child: AudioPlayerWidget(
                              audioUrl: media.fileUrl,
                              isVisible: isMediaVisible,
                            ),
                          )
                        : CachedImageWidget(
                            imageUrl: media.fileUrl,
                            fit: BoxFit.cover,
                            errorWidget: Container(
                              color: Theme.of(context).appGrey200,
                              child: Center(
                                child: Icon(
                                  Icons.image,
                                  size: 64,
                                  color: Theme.of(context).appGrey400,
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
            // Author overlay at bottom left — same rule as the single-media
            // card: only when the author opted to show their profile.
            if (newsItem.showProfile &&
                newsItem.authorName != null &&
                newsItem.authorName!.isNotEmpty)
              Positioned(
                bottom: 8,
                left: 12,
                child: _buildAuthorBadge(newsItem),
              ),
            // Page indicators (dots)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  mediaCount,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == currentCarouselPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == currentCarouselPage
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: AppRadius.xsAll,
                    ),
                  ),
                ),
              ),
            ),
            // Timestamp overlay at bottom left
            // Positioned(
            //   bottom: 12,
            //   left: 12,
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 10,
            //       vertical: 6,
            //     ),
            //     decoration: BoxDecoration(
            //       color: Colors.black.withOpacity(0.6),
            //       borderRadius: BorderRadius.circular(16),
            //     ),
            //     child: Text(
            //       _formatTimestamp(newsItem.createdAt),
            //       style: TextStyle(
            //         fontSize: scaledFontSize(12),
            //         color: Colors.white,
            //         fontWeight: FontWeight.w500,
            //       ),
            //     ),
            //   ),
            // ),
            // App logo/name overlay at bottom right (small and subtle)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: AppRadius.smAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLogo(size: 16, borderRadius: 4),
                    const SizedBox(width: 4),
                    Text(
                      'Deep Pulse',
                      style: TextStyle(
                        fontSize: scaledFontSize(10),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FULLSCREEN ICON (only for videos)
            if (mediaItems[currentCarouselPage].type == 'video')
              Positioned(
                top: 10,
                left: 10,
                child: InkWell(
                  onTap: () {
                    final currentMedia = mediaItems[currentCarouselPage];
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FullscreenVideoScreen(
                          videoUrl: currentMedia.fileUrl,
                          title: _getNewsTitle(newsItem),
                          createdAt: newsItem.displayTime,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: AppRadius.xsAll,
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildDescriptionWithReadMore(
    BuildContext context,
    String description,
    News newsItem,
  ) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: scaledFontSize(17),
      color: colorFromHex(newsItem.descriptionColor) ?? theme.appTextPrimary,
      height: 1.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const bottomRowHeight = 36.0;
        final textAreaHeight = (constraints.maxHeight - bottomRowHeight).clamp(
          0.0,
          double.infinity,
        );
        final painter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1000,
        )..layout(maxWidth: constraints.maxWidth);

        final lineMetrics = painter.computeLineMetrics();
        int fittingLines = 0;
        for (final line in lineMetrics) {
          final lineBottom = line.baseline + line.descent;
          if (lineBottom <= textAreaHeight) {
            fittingLines++;
          } else {
            break;
          }
        }
        final maxLines = fittingLines.clamp(
          1,
          lineMetrics.isEmpty ? 1 : lineMetrics.length,
        );
        final didOverflow = fittingLines < lineMetrics.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Flexible (not Expanded) so the text only takes the height it
            // needs — the timestamp / Read More row then sits right under it
            // instead of being pushed to the bottom with a gap in between.
            Flexible(
              child: Text(
                description,
                style: textStyle,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 13,
                        color: theme.appGrey600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatTimestamp(newsItem.displayTime),
                        style: TextStyle(
                          fontSize: scaledFontSize(12),
                          color: theme.appGrey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (didOverflow)
                    GestureDetector(
                      onTap: () {
                        _videoPreloader.pauseAllVideos();
                        _navigateToNewsDetail(context, newsItem);
                      },
                      child: Text(
                        'Read More',
                        style: TextStyle(
                          fontSize: appFontSizeBody,
                          color: theme.appPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToNewsDetail(BuildContext context, News newsItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreenV2(
          initialNewsItem: newsItem,
          onCommentPosted: () {
            ref.read(homeViewModelProvider).refresh();
          },
        ),
      ),
    );
  }

  Widget _buildNewInteractionBar(BuildContext context, News newsItem) {
    return Consumer(
      builder: (context, ref, child) {
        final authViewModel = ref.watch(authViewModelProvider);
        final currentUser = authViewModel.user;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).appGrey300.withOpacity(0.5),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Bottom row: Like, Dislike, Comments, Share, (Views), More —
              // spread evenly across the full width, overflow menu at the end.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like & Dislike — single Consumer for both
                      Consumer(
                        builder: (context, ref, child) {
                          final homeViewModel = ref.watch(
                            homeViewModelProvider,
                          );
                          final item = homeViewModel.newsItems.firstWhere(
                            (n) => n.id == newsItem.id,
                            orElse: () => newsItem,
                          );
                          final likeStatus =
                              homeViewModel.likeStatuses[newsItem.id] ??
                              LikeStatus.neutral;
                          final isLiked = likeStatus == LikeStatus.liked;
                          final isDisliked = likeStatus == LikeStatus.disliked;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildIconWithCount(
                                context,
                                isLiked
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                item.likesCount.toString(),
                                () async {
                                  final isAuthenticated =
                                      await AuthHelper.requireAuth(
                                        context,
                                        ref,
                                        title: 'Login to Like',
                                        message:
                                            'Please login to like this news article.',
                                      );
                                  if (isAuthenticated) {
                                    ref
                                        .read(homeViewModelProvider)
                                        .likeDislike(
                                          likeableId: newsItem.id,
                                          likeableType: LikeableType.news,
                                          isLike: true,
                                        );
                                  }
                                },
                                color: isLiked
                                    ? Colors.blue
                                    : Theme.of(context).appGrey600,
                              ),
                              _buildIconWithCount(
                                context,
                                isDisliked
                                    ? Icons.thumb_down
                                    : Icons.thumb_down_outlined,
                                item.dislikesCount.toString(),
                                () async {
                                  final isAuthenticated =
                                      await AuthHelper.requireAuth(
                                        context,
                                        ref,
                                        title: 'Login to Dislike',
                                        message:
                                            'Please login to dislike this news article.',
                                      );
                                  if (isAuthenticated) {
                                    ref
                                        .read(homeViewModelProvider)
                                        .likeDislike(
                                          likeableId: newsItem.id,
                                          likeableType: LikeableType.news,
                                          isLike: false,
                                        );
                                  }
                                },
                                color: isDisliked
                                    ? Colors.red
                                    : Theme.of(context).appGrey600,
                              ),
                            ],
                          );
                        },
                      ),
                      if (newsItem.isComment)
                        // Comments count
                        _buildIconWithCount(
                          context,
                          Icons.comment_outlined,
                          newsItem.commentsCount.toString(),
                          () async {
                            _videoPreloader.pauseAllVideos();
                            final isAuthenticated = await AuthHelper.requireAuth(
                              context,
                              ref,
                              title: 'Login to Comment',
                              message:
                                  'Please login to comment on this news article.',
                            );
                            if (isAuthenticated) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CommentsScreen(
                                    news: newsItem,
                                    onCommentPosted: () {
                                      // Refresh news data to update comment count
                                      ref.read(homeViewModelProvider).refresh();
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      // Shares count
                      _buildIconWithCount(
                        context,
                        Icons.share_outlined,
                        newsItem.sharesCount.toString(),
                        () async {
                          final isAuthenticated = await AuthHelper.requireAuth(
                            context,
                            ref,
                            title: 'Login to Share',
                            message: 'Please login to share this news article.',
                          );
                          if (!isAuthenticated) return;
                          try {
                            // Use the share_url from the news model
                            final shareUrl = newsItem.shareUrl.isNotEmpty
                                ? newsItem.shareUrl
                                : 'https://api.deeppulse.media/news/${newsItem.id}'; // fallback

                            // Open native share dialog directly
                            await Share.share(shareUrl);

                            // Call the share API after share dialog closes
                            await ref
                                .read(homeViewModelProvider)
                                .shareNews(newsItem.id, 'general');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to share: $e')),
                            );
                          }
                        },
                      ),
                      // Views count
                      if (currentUser != null &&
                          (currentUser.primaryRole.value == "admin" ||
                              currentUser.primaryRole.value == "sub_admin"))
                        _buildIconWithCount(
                          context,
                          Icons.visibility_outlined,
                          newsItem.viewsCount.toString(),
                          () {},
                        ),
                  // Popup menu — show for all users
                  PopupMenuButton<String>(
                    offset: const Offset(40, -120),
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).appGrey600,
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'download_poster':
                          // The feed's video keeps playing behind a pushed
                          // route, so it has to be stopped here like every
                          // other navigation off this screen does.
                          _videoPreloader.pauseAllVideos();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NewsPosterScreen(news: newsItem),
                            ),
                          );
                          break;
                        case 'report':
                          final isAuthenticated = await AuthHelper.requireAuth(
                            context,
                            ref,
                            title: 'Login to Report',
                            message:
                                'Please login to report this news article.',
                          );
                          if (!isAuthenticated) break;
                          ReportBottomSheet.show(
                            context,
                            type: 'news',
                            itemId: newsItem.id,
                          );
                          break;
                        case 'block_user':
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadius.lgAll,
                              ),
                              title: const Text('Block User'),
                              content: Text(
                                'Are you sure you want to block ${newsItem.authorName ?? "this user"}? You will no longer see their content.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Block'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) break;
                          debugPrint(
                            '🚫 BLOCK USER: newsId=${newsItem.id}, authorId=${newsItem.authorId}',
                          );
                          if (newsItem.authorId == 0) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot block: user id not available',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            break;
                          }
                          final success = await AuthRepositoryImpl().blockUser(
                            newsItem.authorId,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'User blocked'
                                      : 'Failed to block user',
                                ),
                                backgroundColor: success
                                    ? Colors.green[600]
                                    : Colors.red[600],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            if (success) {
                              ref
                                  .read(homeViewModelProvider)
                                  .loadNewsData(silent: true);
                            }
                          }
                          break;
                        case 'save':
                          final isAuthenticated = await AuthHelper.requireAuth(
                            context,
                            ref,
                            title: 'Login to Save',
                            message: 'Please login to save this news article.',
                          );
                          if (!isAuthenticated) break;
                          final savedNewsService = SavedNewsService(
                            userId: ref.read(authViewModelProvider).user?.id,
                          );
                          final isSaved = await savedNewsService.isNewsSaved(
                            newsItem.id,
                          );
                          if (isSaved) {
                            await savedNewsService.removeNews(newsItem.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Removed from saved'),
                                ),
                              );
                            }
                          } else {
                            await savedNewsService.saveNews(newsItem);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('News saved')),
                              );
                            }
                          }
                          break;
                      }
                    },
                    color: Colors.white,
                    itemBuilder: (BuildContext context) => [
                      // Download-as-poster is a staff tool: admins, sub-admins,
                      // News Desk and Sr Reporters get it, plain readers don't.
                      if (_canDownloadPoster)
                        const PopupMenuItem<String>(
                          value: 'download_poster',
                          child: Row(
                            children: [
                              Icon(Icons.download_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Download epaper'),
                            ],
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.report, size: 20),
                            SizedBox(width: 8),
                            Text('Report'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'save',
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_border, size: 20),
                            SizedBox(width: 8),
                            Text('Save'),
                          ],
                        ),
                      ),
                      if (newsItem.authorId != 0 &&
                          newsItem.authorId !=
                              ref.read(authViewModelProvider).user?.id)
                        const PopupMenuItem<String>(
                          value: 'block_user',
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Block User',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  Widget _buildIconWithCount(
    BuildContext context,
    IconData icon,
    String count,
    VoidCallback onTap, {
    Color? color,
  }) {
    final iconColor = color ?? Theme.of(context).appGrey600;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: scaledFontSize(14),
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for extracting data from News model
  String _getNewsTitle(News newsItem) {
    final translation = newsItem.getPrimaryTranslation();
    return translation?.title ?? 'News Article #${newsItem.id}';
  }

  String _getNewsDescription(News newsItem) {
    final translation = newsItem.getPrimaryTranslation();
    if (translation == null) return 'No description available.';

    String description = '';

    if (translation.shortDescription.isNotEmpty) {
      description += translation.shortDescription;
    }

    // Append content if it adds more info beyond the short description
    if (translation.content.isNotEmpty &&
        translation.content != translation.shortDescription) {
      if (description.isNotEmpty) description += '\n\n';
      description += translation.content;
    }

    return description.isNotEmpty ? description : 'No description available.';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _preloadAdjacentVideos(List<FeedEntry> entries, int currentIndex) {
    final videosToPreload = <String>[];
    final imagesToPreload = <String>[];

    for (int i = currentIndex - 1; i <= currentIndex + 2; i++) {
      if (i >= 0 && i < entries.length && i != currentIndex) {
        final entry = entries[i];

        // An advert is a whole page of one creative, so it benefits from the
        // warm-up at least as much as an article does — an ad that paints grey
        // for a beat is a paid impression the advertiser didn't get.
        final ad = entry.ad;
        if (ad != null) {
          (ad.isVideo ? videosToPreload : imagesToPreload).add(ad.url);
          continue;
        }

        for (final media in entry.news!.media) {
          if (media.type == 'video') {
            videosToPreload.add(media.fileUrl);
          } else if (media.type == 'image') {
            imagesToPreload.add(media.fileUrl);
          }
        }
      }
    }

    if (videosToPreload.isNotEmpty) {
      _videoPreloader.preloadVideos(videosToPreload);
    }

    if (imagesToPreload.isNotEmpty) {
      for (final imageUrl in imagesToPreload) {
        // Must be the SAME provider the cards render with. This used to be a
        // plain `NetworkImage`, which meant every preload (a) missed the
        // cached_network_image disk cache and re-downloaded the file, and
        // (b) decoded at full resolution — a 2000x3000 news photo is a ~24 MB
        // bitmap — into a cache the feed never reads. Three of those per page
        // change is what made scrolling stall. `maxWidth` matches the 1080
        // decode cap CachedImageWidget uses.
        precacheImage(
          CachedNetworkImageProvider(imageUrl, maxWidth: 1080),
          context,
        );
      }
    }
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).appCard,
        border: Border(top: BorderSide(color: Theme.of(context).appGrey300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Settings/Home
          IconButton(
            onPressed: () {
              _videoPreloader.pauseAllVideos();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: Icon(Icons.home, color: Theme.of(context).appGrey600),
          ),

          // Upload news icon — shown for all users
          InkWell(
            onTap: () async {
              _videoPreloader.pauseAllVideos();
              final isAuthenticated = await AuthHelper.requireAuth(
                context,
                ref,
                title: 'Login to Upload',
                message: 'Please login to upload news content.',
              );
              if (isAuthenticated) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewsUploadScreen(),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),

          // Notifications
          IconButton(
            onPressed: () {
              _videoPreloader.pauseAllVideos();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
                // Refresh the badge when coming back — the user may have read
                // some notifications while inside the inbox.
              ).then((_) => _loadUnreadCount());
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).appGrey600,
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0245E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).appCard,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _unreadNotifications > 99
                            ? '99+'
                            : '$_unreadNotifications',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: scaledFontSize(9),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The vertical, one-article-per-page feed for a single tab.
///
/// Exists as its own widget for one reason: it **owns its `PageController`**.
/// The controller used to live on `_HomeScreenState` and be shared by every
/// tab, which caused two problems. A tab you scrolled deep into left its
/// offset behind, so the next tab — often with far fewer articles — opened
/// past its own end and looked blank or refused to scroll. And while the tab
/// transition animated, the outgoing and incoming feeds were briefly attached
/// to that same controller at once, which Flutter does not support.
///
/// Give this widget a `ValueKey(tabName)` and both problems disappear: a tab
/// change builds a new state object with a new controller starting at page 0.
class _TabFeedPager extends StatefulWidget {
  /// Pages in this tab. A count rather than the list itself, because a page is
  /// now either an article or a standalone advert and the pager doesn't care
  /// which — [itemBuilder] decides that.
  final int itemCount;

  /// Article to open on. Lets the parent restore where the reader was in this
  /// tab last time, instead of always starting at the top.
  final int initialPage;

  /// Fired when the feed settles on [index] — on first build and on every
  /// page change. Used for video preloading and view-dwell tracking.
  final void Function(int index) onPageSettled;

  /// Fired when the user is within a few pages of the end, to fetch more.
  final VoidCallback onNearEnd;

  /// Fired when the reader drags down past the first page. Awaited, so the
  /// spinner stays up for exactly as long as the reload takes.
  final Future<void> Function() onRefresh;

  final Widget Function(BuildContext context, int index, bool isActive)
  itemBuilder;

  const _TabFeedPager({
    super.key,
    required this.itemCount,
    required this.onPageSettled,
    required this.onNearEnd,
    required this.onRefresh,
    required this.itemBuilder,
    this.initialPage = 0,
  });

  @override
  State<_TabFeedPager> createState() => _TabFeedPagerState();
}

class _TabFeedPagerState extends State<_TabFeedPager> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage,
  );
  late int _currentPage = widget.initialPage;

  @override
  void initState() {
    super.initState();
    // Report the opening article once the frame is up. Doing it here rather
    // than from itemBuilder means it fires exactly once per tab, with no "have
    // I already tracked this page?" flag to keep in sync.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.itemCount > 0) {
        widget.onPageSettled(widget.initialPage);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TabFeedPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refresh can shrink the list under us (load-more only grows it, but a
    // silent reload can replace it). Pull the view back into range rather than
    // leaving the controller parked past the last page.
    final lastPage = widget.itemCount - 1;
    if (_currentPage > lastPage && lastPage >= 0) {
      _currentPage = lastPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(lastPage);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How far the reader has dragged down past the top of the first page in the
  /// current gesture. Reset when the drag ends, so it takes one deliberate pull
  /// rather than several small tugs adding up over time.
  double _pullDown = 0;
  bool _isRefreshing = false;

  /// Pull distance that commits to a reload. Roughly the same travel a stock
  /// RefreshIndicator asks for.
  static const double _pullThreshold = 90;

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// Turns a downward overscroll on the first page into a refresh.
  ///
  /// Done by hand rather than with [RefreshIndicator]: wrapping a vertical
  /// PageView in one makes the two fight over the same vertical drag, which is
  /// what used to make the feed "sometimes not scroll". Watching the scroll
  /// notifications takes no gesture of its own, so paging is untouched.
  bool _onScrollNotification(ScrollNotification n) {
    if (n.depth > 0) return false;

    // Only from the top of the feed, and never while a reload is in flight.
    if (_currentPage != 0 || _isRefreshing) return false;

    if (n is OverscrollNotification) {
      // Android clamps, so the pull shows up as overscroll rather than as
      // negative pixels. Negative overscroll = dragging downward at the top.
      if (n.dragDetails != null && n.overscroll < 0) {
        _pullDown += -n.overscroll;
        if (_pullDown >= _pullThreshold) {
          _pullDown = 0;
          _refresh();
        }
      }
    } else if (n is ScrollUpdateNotification) {
      // iOS bounces, so there the pull shows up as the position itself going
      // past the top.
      if (n.metrics.pixels < -_pullThreshold) {
        _pullDown = 0;
        _refresh();
      }
    } else if (n is ScrollEndNotification) {
      _pullDown = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        children: [
          _buildPager(),
          if (_isRefreshing)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).appCard,
                    shape: BoxShape.circle,
                    boxShadow: Theme.of(context).shadowMd,
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPager() {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      scrollDirection: Axis.vertical,
      // pageSnapping MUST stay false. With it on, PageView wraps whatever you
      // pass as `physics` inside its own PageScrollPhysics — the stock
      // half-a-screen rule then runs as the outermost physics and the custom
      // one below never gets a say. Turning snapping off makes our physics the
      // outermost, and it does the snapping itself in
      // createBallisticSimulation.
      pageSnapping: false,
      physics: const _OneSwipePageScrollPhysics(),
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        if (index >= widget.itemCount - 3) widget.onNearEnd();
        widget.onPageSettled(index);
      },
      itemBuilder: (context, index) =>
          widget.itemBuilder(context, index, index == _currentPage),
    );
  }
}

/// Page physics tuned so one swipe reliably moves one article.
///
/// Flutter's stock [PageScrollPhysics] only commits to the next page when a
/// slow drag passes the **half-way** mark; anything shorter rubber-bands back
/// to where it started. On a full-screen article feed that's a lot of travel,
/// so unhurried swipes silently did nothing and had to be repeated. This
/// lowers the bar to a quarter of the screen, and keeps the existing "any real
/// flick advances a page" behaviour for quick swipes.
class _OneSwipePageScrollPhysics extends PageScrollPhysics {
  const _OneSwipePageScrollPhysics({super.parent});

  /// Fraction of the viewport a slow drag must cover to commit. Flutter's
  /// effective default is 0.5.
  static const double _commitFraction = 0.25;

  @override
  _OneSwipePageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _OneSwipePageScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tol = toleranceFor(position);

    // At either end of the list, hand back to the default so overscroll still
    // bounces/clamps the way the platform expects.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final page = position.pixels / position.viewportDimension;
    final currentPage = page.floorToDouble();
    final dragged = page - currentPage; // 0 → at rest, →1 → nearly next page

    final double targetPage;
    if (velocity.abs() > tol.velocity) {
      // A flick: follow the finger's direction no matter how short the drag.
      targetPage = velocity > 0 ? currentPage + 1 : currentPage;
    } else {
      // Released without momentum: commit once past the quarter mark.
      targetPage = dragged > _commitFraction ? currentPage + 1 : currentPage;
    }

    final target = (targetPage * position.viewportDimension).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tol.distance) return null;

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tol,
    );
  }
}
