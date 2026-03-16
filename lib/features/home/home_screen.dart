import '../news/fullscreen_video_screen.dart';
import 'package:deep_pulse_news/features/profile/profile_screen.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:deep_pulse_news/shared/widgets/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/video_preloader_service.dart';
import '../../shared/widgets/cached_image_widget.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/likeable_type.dart';
import '../../data/models/news.dart';
import '../../data/models/topic.dart';
import '../../extensions/user_extensions.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../auth/auth_helper.dart';
import '../comments/comments_screen.dart';
import '../news/news_detail_screen.dart';
import '../news/news_upload_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _videoPreloader = VideoPreloaderService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
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
      await ref.read(authViewModelProvider).initializeAuth();
      await ref.read(homeViewModelProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                transitionBuilder: (Widget child, Animation<double> animation) {
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).appPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.newspaper, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 8),
              AutoScaledText(
                'Deep Pulse News',
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

  Widget _buildUserProfileHeader(BuildContext context, News newsItem) {
    // Format the timestamp
    final timeAgo = _getTimeAgo(newsItem.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Profile avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).appPrimary.withOpacity(0.1),
            child: Icon(
              Icons.person,
              color: Theme.of(context).appPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Name and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'News Reporter', // You can replace this with actual author name from newsItem
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Deep Pulse News • $timeAgo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // More options button
          IconButton(
            onPressed: () {
              // Add more options functionality
            },
            icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
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
                    AutoScaledText(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: appFontSizeSubHeader,
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
      return _buildTopicsGrid(context);
    }

    if (homeViewModel.isLoadingNews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (homeViewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AutoScaledText(
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
        child: AutoScaledText(
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
          _preloadAdjacentVideos(newsItems, index);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            _preloadAdjacentVideos(newsItems, index);
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
            AutoScaledText(
              'Error loading topics',
              style: TextStyle(
                fontSize: appFontSizeBody,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.read(topicViewModelProvider).loadTopics(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final topics = homeViewModel.topics;

    if (topics.isEmpty) {
      return Center(
        child: AutoScaledText(
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: topics.length,
        itemBuilder: (context, index) {
          final topic = topics[index];

          return InkWell(
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () => _onTopicTap(context, topic),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).appCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AutoScaledText(
                topic.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).appTextPrimary,
                ),
                textAlign: TextAlign.center,
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
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 72),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoScaledText(
                          _getNewsTitle(newsItem),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).appTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildDescriptionWithReadMore(
                          context,
                          _getNewsDescription(newsItem),
                          newsItem,
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
    final mediaItems = newsItem.media.take(3).toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) {
      return const SizedBox.shrink();
    }

    if (mediaCount == 1) {
      // Single media item
      final media = mediaItems[0];
      return SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: Theme.of(context).appGrey200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.expand(
                    child: media.type == 'video'
                        ? VideoPlayerWidget(
                            videoUrl: media.fileUrl,
                            autoPlay: false,
                            isVisible: isVisible,
                          )
                        : CachedImageWidget(
                            imageUrl: media.fileUrl,
                            fit: BoxFit.contain,
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
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AutoScaledText(
                      _formatTimestamp(newsItem.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Theme.of(context).appPrimary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Icon(
                            Icons.newspaper,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AutoScaledText(
                          'Deep Pulse',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: InkWell(
                    onTap: media.type == 'video'
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FullscreenVideoScreen(
                                  videoUrl: media.fileUrl,
                                  title: _getNewsTitle(newsItem),
                                  createdAt: newsItem.createdAt,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close_fullscreen,
                        color: media.type == 'video' ? Colors.white : Colors.white.withOpacity(0.3),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Multiple media items with PageView slider (up to 3)
      final currentCarouselPage = _currentCarouselPages[newsItemIndex] ?? 0;

      return SizedBox(
        width: double.infinity,
        height: 200, // Fixed height for carousel instead of aspect ratio
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
                            fit: BoxFit.contain,
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
            // Media counter indicator
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AutoScaledText(
                  '${currentCarouselPage + 1}/$mediaCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Timestamp overlay at bottom left
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AutoScaledText(
                  _formatTimestamp(newsItem.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).appPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Icon(
                        Icons.newspaper,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AutoScaledText(
                      'Deep Pulse',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // FULLSCREEN ICON
            Positioned(
              top: 10,
              left: 10,
              child: InkWell(
                onTap: () {
                  final currentMedia = mediaItems[currentCarouselPage];
                  if (currentMedia.type == 'video') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FullscreenVideoScreen(
                          videoUrl: currentMedia.fileUrl,
                          title: _getNewsTitle(newsItem),
                          createdAt: newsItem.createdAt,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.close_fullscreen,
                    color: mediaItems.isNotEmpty && mediaItems[currentCarouselPage].type == 'video'
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = TextStyle(
          fontSize: 18.0,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          height: 1.4,
        );

        final textSpan = TextSpan(text: description, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 8,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);
        final isTextOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoScaledText(
              description,
              style: textStyle,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
            if (isTextOverflowing) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  // Pause all videos before navigating
                  _videoPreloader.pauseAllVideos();
                  _navigateToNewsDetail(context, newsItem);
                },
                child: AutoScaledText(
                  'Read More',
                  style: TextStyle(
                    fontSize: appFontSizeBody,
                    color: Theme.of(context).appPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _navigateToNewsDetail(BuildContext context, News newsItem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(
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
                  // Like symbol
                  Consumer(
                    builder: (context, ref, child) {
                      final isLiked = newsItem.isLiked == 1;
                      final likeColor = isLiked
                          ? Colors.blue
                          : Theme.of(context).appGrey600;
                      return _buildIconButton(
                        context,
                        Icons.thumb_up_outlined,
                        () async {
                          try {
                            await ref
                                .read(homeViewModelProvider)
                                .likeDislike(
                                  likeableId: newsItem.id,
                                  likeableType: LikeableType.news,
                                  isLike: true,
                                );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to like: $e')),
                            );
                          }
                        },
                        likeColor,
                      );
                    },
                  ),
                  // Dislike symbol
                  Consumer(
                    builder: (context, ref, child) {
                      final homeViewModel = ref.watch(homeViewModelProvider);
                      final likeStatus =
                          homeViewModel.likeStatuses[newsItem.id] ??
                          LikeStatus.neutral;
                      final dislikeColor = likeStatus == LikeStatus.disliked
                          ? Colors.red
                          : Theme.of(context).appGrey600;
                      return _buildIconButton(
                        context,
                        Icons.thumb_down_outlined,
                        () async {
                          try {
                            await ref
                                .read(homeViewModelProvider)
                                .likeDislike(
                                  likeableId: newsItem.id,
                                  likeableType: LikeableType.news,
                                  isLike: false,
                                );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to dislike: $e')),
                            );
                          }
                        },
                        dislikeColor,
                      );
                    },
                  ),
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
                        // await ref.read(homeViewModelProvider).shareNews(newsItem.id, 'general');
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
                  // Popup menu for non-admin users
                  if (currentUser != null &&
                      (currentUser.primaryRole.value != "admin"))
                    PopupMenuButton<String>(
                      offset: const Offset(40, -120),
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context).appGrey600,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'report':
                            // TODO: Implement report functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report feature coming soon!'),
                              ),
                            );
                            break;
                          case 'save':
                            // TODO: Implement save functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Save feature coming soon!'),
                              ),
                            );
                            break;
                        }
                      },
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
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Theme.of(context).appGrey600),
            const SizedBox(width: 4),
            AutoScaledText(
              count,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).appTextPrimary,
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

    // Add short description if available
    if (translation.shortDescription.isNotEmpty) {
      description += translation.shortDescription;
    }

    // Add content if available and different from short description
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
    final authViewModel = ref.watch(authViewModelProvider);
    final currentUser = authViewModel.user;
    final isAdmin = currentUser?.primaryRole.canAccessAdmin ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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

          // Upload (Admin) or WhatsApp (Regular User)
          if (isAdmin) ...[
            // Admin: Show upload news icon
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
          ] else ...[
            // Regular User: Show WhatsApp icon
            IconButton(
              onPressed: () {
                _videoPreloader.pauseAllVideos();
                // Open WhatsApp or WhatsApp Web
                // You can implement WhatsApp sharing functionality here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('WhatsApp feature coming soon!'),
                  ),
                );
              },
              icon: Icon(
                Icons.share, // WhatsApp-like share icon
                color: Theme.of(context).appGrey600,
                size: 24,
              ),
            ),
          ],

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
