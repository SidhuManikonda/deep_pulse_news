import 'package:deep_pulse_news/features/profile/profile_screen.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:deep_pulse_news/shared/widgets/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/services/video_preloader_service.dart';
import '../../data/models/likeable_type.dart';
import '../../data/models/news.dart';
import '../../data/models/topic.dart';
import '../../extensions/user_extensions.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../auth/auth_helper.dart';
import '../comments/comments_screen.dart';
import '../news/fullscreen_video_screen.dart';
import '../news/news_detail_screen_v2.dart';
import '../news/news_upload_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'home_view_model.dart';

class HomeScreenV2 extends ConsumerStatefulWidget {
  const HomeScreenV2({super.key});

  @override
  ConsumerState<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends ConsumerState<HomeScreenV2> {
  final _videoPreloader = VideoPreloaderService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, int> _currentCarouselPages = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authViewModelProvider).initializeAuth();
      await ref.read(homeViewModelProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme, isLight),
            _buildLocationTabs(context, theme),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
                child: _buildNewsFeed(context, theme),
              ),
            ),
            _buildBottomNavigation(context, theme, isLight),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, ThemeData theme, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Logo
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.appPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.newspaper, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Deep Pulse News',
              style: TextStyle(
                fontSize: appFontSizeHeader,
                fontWeight: FontWeight.w800,
                color: theme.appTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.appGrey100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.appGrey200,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 20,
                color: theme.appGrey400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Location tabs ─────────────────────────────────────────────────────────
  Widget _buildLocationTabs(BuildContext context, ThemeData theme) {
    final homeViewModel = ref.watch(homeViewModelProvider);
    final tabs = homeViewModel.getLocationTabs();

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: tabs.map((tab) {
          final tabName = tab['name'] as String;
          final displayName = tab['displayName'] as String;
          final isSelected = homeViewModel.selectedLocationTab == tabName;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                _videoPreloader.pauseAllVideos();
                ref.read(homeViewModelProvider).setSelectedLocationTab(tabName);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.appPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    color: isSelected
                        ? Colors.white
                        : theme.appTextSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── News feed ─────────────────────────────────────────────────────────────
  Widget _buildNewsFeed(BuildContext context, ThemeData theme) {
    final homeViewModel = ref.watch(homeViewModelProvider);

    if (homeViewModel.selectedLocationTab == 'More') {
      return _buildTopicsGrid(context, theme);
    }

    if (homeViewModel.isLoadingNews) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(theme.appPrimary),
        ),
      );
    }

    if (homeViewModel.error != null) {
      return _buildErrorState(theme, homeViewModel);
    }

    final newsItems = homeViewModel.newsItems;

    if (newsItems.isEmpty) {
      return _buildEmptyState(theme, homeViewModel);
    }

    return RefreshIndicator(
      onRefresh: () async {
        _videoPreloader.pauseAllVideos();
        await homeViewModel.refresh();
      },
      color: theme.appPrimary,
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
            theme,
            newsItems[index],
            index,
            index == _currentPage,
          );
        },
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, HomeViewModel homeViewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.appGrey300),
          const SizedBox(height: 12),
          Text(
            'Unable to load news',
            style: TextStyle(
              fontSize: appFontSizeBody,
              fontWeight: FontWeight.w600,
              color: theme.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and try again',
            style: TextStyle(fontSize: scaledFontSize(13), color: theme.appTextLight),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => homeViewModel.refresh(),
            icon: Icon(Icons.refresh_rounded, size: 18, color: theme.appPrimary),
            label: Text(
              'Retry',
              style: TextStyle(
                color: theme.appPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, HomeViewModel homeViewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 48, color: theme.appGrey300),
          const SizedBox(height: 12),
          Text(
            'No news available',
            style: TextStyle(
              fontSize: appFontSizeBody,
              fontWeight: FontWeight.w600,
              color: theme.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'for ${homeViewModel.selectedLocationTab}',
            style: TextStyle(fontSize: scaledFontSize(13), color: theme.appTextLight),
          ),
        ],
      ),
    );
  }

  // ── Topics grid (More tab) ────────────────────────────────────────────────
  Widget _buildTopicsGrid(BuildContext context, ThemeData theme) {
    final homeViewModel = ref.watch(homeViewModelProvider);

    if (homeViewModel.isLoadingTopics) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(theme.appPrimary),
        ),
      );
    }

    if (homeViewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading topics',
              style: TextStyle(fontSize: appFontSizeBody, color: theme.appTextPrimary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.read(topicViewModelProvider).loadTopics(),
              icon: Icon(Icons.refresh_rounded, size: 18, color: theme.appPrimary),
              label: Text('Retry', style: TextStyle(color: theme.appPrimary)),
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
          style: TextStyle(fontSize: appFontSizeBody, color: theme.appTextPrimary),
        ),
      );
    }

    final isLight = theme.brightness == Brightness.light;

    return RefreshIndicator(
      onRefresh: () => ref.read(homeViewModelProvider).loadTopicsData(),
      color: theme.appPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: topics.length,
        itemBuilder: (context, index) {
          final topic = topics[index];

          return GestureDetector(
            onTap: () => _onTopicTap(context, topic),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.appCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.appPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.tag_rounded, size: 18, color: theme.appPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      topic.name,
                      style: TextStyle(
                        fontSize: scaledFontSize(15),
                        fontWeight: FontWeight.w600,
                        color: theme.appTextPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: theme.appGrey400),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onTopicTap(BuildContext context, Topic topic) {
    ref.read(homeViewModelProvider).selectTopic(topic);
  }

  // ── News card ─────────────────────────────────────────────────────────────
  Widget _buildNewsCard(
    BuildContext context,
    ThemeData theme,
    News newsItem,
    int index,
    bool isCurrentPage,
  ) {
    final isLight = theme.brightness == Brightness.light;

    return SizedBox.expand(
      child: Container(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.appCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Media section
              _buildMediaSection(context, theme, newsItem, isCurrentPage, index),

              // Text + interaction bar section
              Expanded(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Text content - clipped to prevent any overflow
                    Positioned.fill(
                      bottom: 48,
                      child: ClipRect(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getNewsTitle(newsItem),
                                style: TextStyle(
                                  fontSize: scaledFontSize(23),
                                  fontWeight: FontWeight.w800,
                                  color: theme.appTextPrimary,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: _buildDescriptionWithReadMore(
                                  context,
                                  theme,
                                  _getNewsDescription(newsItem),
                                  newsItem,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Interaction bar pinned at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildInteractionBar(context, theme, newsItem, isLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Media section ─────────────────────────────────────────────────────────
  Widget _buildMediaSection(
    BuildContext context,
    ThemeData theme,
    News newsItem,
    bool isVisible,
    int newsItemIndex,
  ) {
    final mediaItems = newsItem.media.take(3).toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) return const SizedBox.shrink();

    // Use the same fixed height for both single and multi media
    // This prevents the video player controls from overflowing into the text area
    final hasVideo = mediaItems.any((m) => m.type == 'video');
    final double? mediaHeight;
    if (mediaCount == 1 && !hasVideo) {
      mediaHeight = null; // single image uses aspect ratio
    } else if (hasVideo) {
      mediaHeight = 300.0; // videos need more height for controls
    } else {
      mediaHeight = 220.0; // image carousels
    }

    if (mediaCount == 1) {
      final media = mediaItems[0];
      final child = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          SizedBox.expand(
            child: media.type == 'video'
                ? VideoPlayerWidget(
                    videoUrl: media.fileUrl,
                    autoPlay: false,
                    isVisible: isVisible,
                  )
                : CachedImageWidget(
                    imageUrl: media.fileUrl,
                    fit: BoxFit.contain,
                    errorWidget: _buildMediaError(theme),
                  ),
          ),
          _buildMediaOverlays(theme, newsItem, mediaItems, 0, isVideo: media.type == 'video'),
        ],
      );

      if (mediaHeight != null) {
        return SizedBox(
          width: double.infinity,
          height: mediaHeight,
          child: child,
        );
      }
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: child,
      );
    } else {
      final currentCarouselPage = _currentCarouselPages[newsItemIndex] ?? 0;

      return SizedBox(
        width: double.infinity,
        height: mediaHeight,
        child: Stack(
          clipBehavior: Clip.hardEdge,
            children: [
              PageView.builder(
                itemCount: mediaCount,
                onPageChanged: (page) {
                  setState(() {
                    _currentCarouselPages[newsItemIndex] = page;
                  });
                  _videoPreloader.pauseAllVideos();
                },
                itemBuilder: (context, carouselIndex) {
                  final media = mediaItems[carouselIndex];
                  final isMediaVisible = isVisible && carouselIndex == currentCarouselPage;

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
                            errorWidget: _buildMediaError(theme),
                          ),
                  );
                },
              ),
              // Page indicators
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${currentCarouselPage + 1}/$mediaCount',
                    style:  TextStyle(
                      fontSize: scaledFontSize(11),
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _buildMediaOverlays(
                theme,
                newsItem,
                mediaItems,
                currentCarouselPage,
                isVideo: mediaItems[currentCarouselPage].type == 'video',
              ),
            ],
          ),
      );
    }
  }

  Widget _buildMediaOverlays(
    ThemeData theme,
    News newsItem,
    List mediaItems,
    int currentPage, {
    required bool isVideo,
  }) {
    // For videos, the VideoPlayerWidget already renders its own bottom controls
    // (gradient, time labels, slider). Only show the fullscreen button.
    return Stack(
      children: [
        if (!isVideo) ...[
          // Bottom gradient - only for images
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
          // Timestamp - only for images
          Positioned(
            bottom: 10,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatTimestamp(newsItem.createdAt),
                style:  TextStyle(
                  fontSize: scaledFontSize(11),
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Deep Pulse badge - only for images
          Positioned(
            bottom: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.appPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Icon(Icons.newspaper, size: 8, color: Colors.white),
                  ),
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
        ],
        // Fullscreen button
        Positioned(
          top: 10,
          left: 10,
          child: GestureDetector(
            onTap: isVideo
                ? () {
                    final media = mediaItems[currentPage];
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
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close_fullscreen,
                color: isVideo
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaError(ThemeData theme) {
    return Container(
      color: theme.appGrey200,
      child: Center(
        child: Icon(Icons.image, size: 64, color: theme.appGrey400),
      ),
    );
  }

  // ── Description with Read More ────────────────────────────────────────────
  Widget _buildDescriptionWithReadMore(
    BuildContext context,
    ThemeData theme,
    String description,
    News newsItem,
  ) {
    const baseFontSize = 22.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        const scaledFontSize = baseFontSize;
        final availableHeight = constraints.maxHeight;
        final readMoreBtnHeight = appFontSizeBody * 1.4 + 12;

        final textStyle = TextStyle(
          fontSize: scaledFontSize,
          fontFamily: GoogleFonts.roboto().fontFamily,
          color: theme.appTextPrimary,
          height: 1.4,
        );

        final singleLinePainter = TextPainter(
          text: TextSpan(text: 'A', style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);
        final actualLineHeight = singleLinePainter.height;

        final fullTextPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = fullTextPainter.height > availableHeight;

        // Calculate max lines that fit in the space
        // When overflowing, reserve space for the "Read More" button
        final spaceForText = isOverflowing
            ? availableHeight - readMoreBtnHeight
            : availableHeight;
        final effectiveMaxLines = (spaceForText / actualLineHeight).floor().clamp(1, 999);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text constrained to calculated lines
            Text(
              description,
              style: TextStyle(
                fontSize: baseFontSize,
                color: theme.appTextPrimary,
                height: 1.4,
              ),
              maxLines: effectiveMaxLines,
              overflow: TextOverflow.ellipsis,
            ),
            if (isOverflowing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () {
                    _videoPreloader.pauseAllVideos();
                    _navigateToNewsDetail(context, newsItem);
                  },
                  child: Text(
                    'Read More',
                    style: TextStyle(
                      fontSize: appFontSizeBody,
                      color: theme.appPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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

  // ── Interaction bar ───────────────────────────────────────────────────────
  Widget _buildInteractionBar(
    BuildContext context,
    ThemeData theme,
    News newsItem,
    bool isLight,
  ) {
    return Consumer(
      builder: (context, ref, child) {
        final authViewModel = ref.watch(authViewModelProvider);
        final currentUser = authViewModel.user;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isLight
                ? theme.appCard.withValues(alpha: 0.95)
                : theme.appCard.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: theme.appDivider,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like
              Consumer(
                builder: (context, ref, child) {
                  final isLiked = newsItem.isLiked == 1;
                  final likeColor = isLiked
                      ? const Color(0xFF2563EB)
                      : theme.appGrey500;
                  return _buildActionButton(
                    icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                    color: likeColor,
                    onTap: () async {
                      final isAuthenticated = await AuthHelper.requireAuth(
                        context,
                        ref,
                        title: 'Login to Like',
                        message: 'Please login to like this news article.',
                      );
                      if (!isAuthenticated) return;
                      try {
                        await ref.read(homeViewModelProvider).likeDislike(
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
                  );
                },
              ),
              // Dislike
              Consumer(
                builder: (context, ref, child) {
                  final homeViewModel = ref.watch(homeViewModelProvider);
                  final likeStatus =
                      homeViewModel.likeStatuses[newsItem.id] ?? LikeStatus.neutral;
                  final isDisliked = likeStatus == LikeStatus.disliked;
                  final dislikeColor = isDisliked
                      ? theme.appPrimary
                      : theme.appGrey500;
                  return _buildActionButton(
                    icon: isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                    color: dislikeColor,
                    onTap: () async {
                      final isAuthenticated = await AuthHelper.requireAuth(
                        context,
                        ref,
                        title: 'Login to Dislike',
                        message: 'Please login to dislike this news article.',
                      );
                      if (!isAuthenticated) return;
                      try {
                        await ref.read(homeViewModelProvider).likeDislike(
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
                  );
                },
              ),
              // Comments
              _buildActionButtonWithCount(
                theme: theme,
                icon: Icons.chat_bubble_outline_rounded,
                count: newsItem.commentsCount.toString(),
                onTap: () async {
                  _videoPreloader.pauseAllVideos();
                  final isAuthenticated = await AuthHelper.requireAuth(
                    context,
                    ref,
                    title: 'Login to Comment',
                    message: 'Please login to comment on this news article.',
                  );
                  if (isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(
                          news: newsItem,
                          onCommentPosted: () {
                            ref.read(homeViewModelProvider).refresh();
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
              // Share
              _buildActionButtonWithCount(
                theme: theme,
                icon: Icons.share_outlined,
                count: newsItem.sharesCount.toString(),
                onTap: () async {
                  try {
                    final shareUrl = newsItem.shareUrl.isNotEmpty
                        ? newsItem.shareUrl
                        : 'https://deeppulse.co.in/news/${newsItem.id}';
                    await Share.share(shareUrl);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                },
              ),
              // Views (admin only)
              if (currentUser != null &&
                  (currentUser.primaryRole.value == "admin" ||
                      currentUser.primaryRole.value == "sub_admin"))
                _buildActionButtonWithCount(
                  theme: theme,
                  icon: Icons.visibility_outlined,
                  count: newsItem.viewsCount.toString(),
                  onTap: () {},
                ),
              // More menu (non-admin)
              if (currentUser != null &&
                  currentUser.primaryRole.value != "admin")
                PopupMenuButton<String>(
                  offset: const Offset(40, -120),
                  icon: Icon(Icons.more_vert_rounded, color: theme.appGrey500, size: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'report':
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report feature coming soon!')),
                        );
                        break;
                      case 'save':
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Save feature coming soon!')),
                        );
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report_outlined, size: 20, color: theme.appTextSecondary),
                          const SizedBox(width: 10),
                          const Text('Report'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'save',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_border_rounded, size: 20, color: theme.appTextSecondary),
                          const SizedBox(width: 10),
                          const Text('Save'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  Widget _buildActionButtonWithCount({
    required ThemeData theme,
    required IconData icon,
    required String count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: theme.appGrey500),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: scaledFontSize(13),
                fontWeight: FontWeight.w600,
                color: theme.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom navigation ─────────────────────────────────────────────────────
  Widget _buildBottomNavigation(BuildContext context, ThemeData theme, bool isLight) {
    final authViewModel = ref.watch(authViewModelProvider);
    final currentUser = authViewModel.user;
    final isAdmin = currentUser?.primaryRole.canAccessAdmin ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: theme.appCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            theme: theme,
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: true,
            onTap: () {
              _videoPreloader.pauseAllVideos();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),

          if (isAdmin) ...[
            // Admin: Upload button
            GestureDetector(
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
                  gradient: LinearGradient(
                    colors: [theme.appPrimary, theme.appPrimaryDark],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.appPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ] else ...[
            _buildNavItem(
              theme: theme,
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                _videoPreloader.pauseAllVideos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('WhatsApp feature coming soon!')),
                );
              },
            ),
          ],

          _buildNavItem(
            theme: theme,
            icon: Icons.notifications_none_rounded,
            label: 'Alerts',
            onTap: () {
              _videoPreloader.pauseAllVideos();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? theme.appPrimary : theme.appGrey500,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(10),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.appPrimary : theme.appGrey500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper methods ────────────────────────────────────────────────────────
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
}
