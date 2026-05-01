import 'package:deep_pulse_news/features/home/more_topics_screen.dart';
import 'package:deep_pulse_news/features/profile/profile_screen.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:deep_pulse_news/shared/widgets/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/news_view_tracker_service.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/services/saved_news_service.dart';
import '../../core/services/video_preloader_service.dart';
import '../../data/models/likeable_type.dart';
import '../../data/models/news.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/topic.dart';
import '../../extensions/user_extensions.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../shared/widgets/report_bottom_sheet.dart';
import '../auth/auth_helper.dart';
import '../comments/comments_screen.dart';
import '../news/fullscreen_video_screen.dart';
import '../news/news_detail_screen_v2.dart';
import '../news/news_upload_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/app_logo.dart';
import 'home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _videoPreloader = VideoPreloaderService();
  final _newsViewTracker = NewsViewTrackerService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _firstPageTracked = false;
  final Map<int, int> _currentCarouselPages =
      {}; // Track carousel page per news item
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
        ref.read(homeViewModelProvider).loadNewsData(silent: true);
      }
    });
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

              // Main content area - News feed only
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final slideAnimation =
                            Tween<Offset>(
                              begin: const Offset(0.1, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              ),
                            );

                        return SlideTransition(
                          position: slideAnimation,
                          child: child,
                        );
                      },
                  child: _buildNewsFeed(context),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
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
              // final isAuthenticated = await AuthHelper.requireAuth(
              //   context,
              //   ref,
              //   title: 'Login to Comment',
              //   message: 'Please login to comment on this news article.',
              // );
              // if (isAuthenticated) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
              // }
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
              onTap: () {
                // Pause all videos when switching tabs
                _videoPreloader.pauseAllVideos();
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
      return const Center(child: CircularProgressIndicator());
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

    if (newsItems.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: () async {
        // Pause all videos before refreshing
        _videoPreloader.pauseAllVideos();
        await homeViewModel.refresh();
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: newsItems.length,
        scrollDirection: Axis.vertical,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
          // Load more news when near the end
          if (index >= newsItems.length - 3) {
            ref.read(homeViewModelProvider).loadMoreNews();
          }
          _preloadAdjacentVideos(newsItems, index);
          // Track news view and increment count locally
          // if (index < newsItems.length) {
          //   final userId = ref.read(authViewModelProvider).user?.id;
          //   if (userId != null) {
          //     _newsViewTracker.recordView(newsItems[index].id, userId: userId);
          //   }
          //   ref.read(homeViewModelProvider).incrementViewCount(newsItems[index].id);
          // }
        },
        itemBuilder: (context, index) {
          if (index == 0 && !_firstPageTracked) {
            _firstPageTracked = true;
            _preloadAdjacentVideos(newsItems, index);
            // final userId = ref.read(authViewModelProvider).user?.id;
            // if (userId != null) {
            //   _newsViewTracker.recordView(newsItems[0].id, userId: userId);
            // }
            // ref.read(homeViewModelProvider).incrementViewCount(newsItems[0].id);
          }
          return _buildNewsCard(
            context,
            newsItems[index],
            index,
            index == _currentPage,
          );
        },
      ),
    );
  }

  Widget _buildTopicsGrid(BuildContext context) {
    final homeViewModel = ref.watch(homeViewModelProvider);

    if (homeViewModel.isLoadingTopics) {
      return const Center(child: CircularProgressIndicator());
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
                            fontSize: scaledFontSize(20),
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).appTextPrimary,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: -12,
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
    final mediaItems = newsItem.media.toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) {
      return const SizedBox.shrink();
    }

    if (mediaCount == 1) {
      // Single media item
      final media = mediaItems[0];
      final screenHeight = MediaQuery.of(context).size.height;
      return SizedBox(
        width: double.infinity,
        height: screenHeight * 0.28,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: Theme.of(context).appGrey200,
            borderRadius: AppRadius.smAll,
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox.expand(
                  child: media.type == 'video'
                      ? VideoPlayerWidget(
                          videoUrl: media.fileUrl,
                          autoPlay: false,
                          isVisible: isVisible,
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
                ),
              ),
              // Timestamp overlay at bottom left
              Positioned(
                bottom: 8,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Text(
                    newsItem.authorName!=null?'${newsItem.authorName}':'',
                    style: TextStyle(
                      fontSize: scaledFontSize(12),
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
                            createdAt: newsItem.createdAt,
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
                            autoPlay: false,
                            isVisible: isMediaVisible,
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
                          createdAt: newsItem.createdAt,
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
    final baseFontSize = scaledFontSize(18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final readMoreBtnHeight = appFontSizeBody * 1.4 + 12;

        final textStyle = TextStyle(
          fontSize: baseFontSize,
          fontFamily: GoogleFonts.roboto().fontFamily,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          height: 1.4,
        );

        // Measure with unlimited lines to get actual line height
        final singleLinePainter = TextPainter(
          text: TextSpan(text: 'A', style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);
        final actualLineHeight = singleLinePainter.height;

        // How many lines fit without / with "Read More"
        final maxLinesFull = (availableHeight / actualLineHeight).floor().clamp(
          1,
          999,
        );
        final maxLinesWithBtn =
            ((availableHeight - readMoreBtnHeight) / actualLineHeight)
                .floor()
                .clamp(1, 999);

        // Check if text overflows the available space
        final fullTextPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = fullTextPainter.height > availableHeight;
        final effectiveMaxLines = isOverflowing
            ? maxLinesWithBtn
            : maxLinesFull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRect(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: baseFontSize,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    height: 1.4,
                  ),
                  maxLines: effectiveMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top:8.0,bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        size: 14,
                        color: Theme.of(context).appGrey600,
                      ),
                      Text(
                        _formatTimestamp(newsItem.createdAt),
                        style: TextStyle(
                          fontSize: scaledFontSize(12),
                          color: Theme.of(context).appGrey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              
                  if (isOverflowing)
                    InkWell(
                      onTap: () {
                        _videoPreloader.pauseAllVideos();
                        _navigateToNewsDetail(context, newsItem);
                      },
                      child: Text(
                        'Read More',
                        style: TextStyle(
                          fontSize: appFontSizeBody,
                          color: Theme.of(context).appPrimary,
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
              // Bottom row: Like, Dislike, Comments, Share
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like & Dislike — single Consumer for both
                  Consumer(
                    builder: (context, ref, child) {
                      final homeViewModel = ref.watch(homeViewModelProvider);
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
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
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
                              final isAuthenticated = await AuthHelper.requireAuth(
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
                      try {
                        // Use the share_url from the news model
                        final shareUrl = newsItem.shareUrl.isNotEmpty
                            ? newsItem.shareUrl
                            : 'https://deeppulse.co.in/news/${newsItem.id}'; // fallback

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
                        case 'report':
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

  void _preloadAdjacentVideos(List<News> newsItems, int currentIndex) {
    final videosToPreload = <String>[];
    final imagesToPreload = <String>[];

    for (int i = currentIndex - 1; i <= currentIndex + 2; i++) {
      if (i >= 0 && i < newsItems.length && i != currentIndex) {
        final newsItem = newsItems[i];
        for (final media in newsItem.media) {
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
        precacheImage(NetworkImage(imageUrl), context);
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
              );
            },
            icon: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).appGrey600,
            ),
          ),
        ],
      ),
    );
  }
}
