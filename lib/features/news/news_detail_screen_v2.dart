import 'package:deep_pulse_news/core/constants/app_constants.dart';
import 'package:deep_pulse_news/shared/widgets/app_logo.dart';
import 'package:deep_pulse_news/shared/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/news.dart';
import '../../data/models/likeable_type.dart';
import '../../data/repositories/news_repository.dart';
import '../auth/auth_helper.dart';
import '../comments/comments_screen.dart';
import '../home/home_view_model.dart';
import '../../shared/widgets/video_player_widget.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../core/services/saved_news_service.dart';
import '../../core/services/video_preloader_service.dart';
import '../../providers/app_providers.dart';
import '../../data/models/news_media.dart';
import '../../core/constants/app_font_sizes.dart';

class NewsDetailScreenV2 extends ConsumerStatefulWidget {
  final News initialNewsItem;
  final VoidCallback? onCommentPosted;

  const NewsDetailScreenV2({
    super.key,
    required this.initialNewsItem,
    this.onCommentPosted,
  });

  @override
  ConsumerState<NewsDetailScreenV2> createState() => _NewsDetailScreenV2State();
}

class _NewsDetailScreenV2State extends ConsumerState<NewsDetailScreenV2> {
  late News _newsItem;
  late final NewsRepository _newsRepository;
  late final SavedNewsService _savedNewsService;
  final _videoPreloader = VideoPreloaderService();
  final Map<int, int> _currentCarouselPages = {};
  final PageController _pageController = PageController();
  bool _isSaved = false;
  @override
  void initState() {
    super.initState();
    _newsItem = widget.initialNewsItem;
    _newsRepository = NewsRepositoryImpl();
    _savedNewsService = SavedNewsService(
      userId: ref.read(authViewModelProvider).user?.id,
    );
    _checkIfSaved();

  }

  Future<void> _checkIfSaved() async {
    final saved = await _savedNewsService.isNewsSaved(_newsItem.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await _savedNewsService.removeNews(_newsItem.id);
    } else {
      await _savedNewsService.saveNews(_newsItem);
    }
    if (mounted) {
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isSaved ? 'News saved' : 'Removed from saved')),
      );
    }
  }

  @override
  void dispose() {
    _videoPreloader.pauseAllVideos();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshNewsItem() async {
    try {
      final updatedNews = await _newsRepository.getNewsById(_newsItem.id);
      if (updatedNews != null && mounted) {
        setState(() {
          _newsItem = updatedNews;
        });
      }
    } catch (e) {
      print('Failed to refresh news item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Collapsible media app bar
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: _newsItem.media.isNotEmpty ? 320 : 0,
            pinned: true,
            stretch: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            // leading: _buildCircularButton(
            //   icon: Icons.arrow_back_ios_new_rounded,
            //   onTap: () {
            //     _videoPreloader.pauseAllVideos();
            //     Navigator.pop(context);
            //   },
            //   theme: theme,
            //   isLight: isLight,
            // ),
            actions: [
              // _buildCircularButton(
              //   icon: Icons.share_outlined,
              //   onTap: () {},
              //   theme: theme,
              //   isLight: isLight,
              // ),
              // const SizedBox(width: 4),
              _buildCircularButton(
                icon: _isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: _toggleSave,
                theme: theme,
                isLight: isLight,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: _newsItem.media.isNotEmpty
                ? FlexibleSpaceBar(
                    background: _buildMediaSection(context, theme),
                  )
                : null,
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source & time row
                  // _buildSourceRow(theme),
                  // const SizedBox(height: 14),

                  // Title
                  Text(
                    _getNewsTitle(),
                    style: TextStyle(
                      fontSize: scaledFontSize(20),
                      fontWeight: FontWeight.w800,
                      color: theme.appTextPrimary,
                      height: 1.3,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Container(
                    height: 3,
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.appPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Short description
                  if (_getNewsShortDescription().isNotEmpty) ...[
                    Text(
                      _getNewsShortDescription(),
                      style: TextStyle(
                        fontSize: scaledFontSize(19.0),
                        color: theme.appTextPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Full content
                  if (_getNewsContent().isNotEmpty &&
                      _getNewsContent() != _getNewsShortDescription()) ...[
                    Text(
                      _getNewsContent(),
                      style: TextStyle(
                        fontSize: scaledFontSize(19.0),
                        color:  theme.appTextPrimary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Center(
                    child: CustomButton(
                      backgroundColor: isLight
                          ? appBackgroundDarkColor
                          : const Color(0xFF1E1E1E),
                      height: 39,
                      text: "Back To Home",
                      onPressed: () {
                        _videoPreloader.pauseAllVideos();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),

      // Floating interaction bar at bottom
      bottomNavigationBar: _buildFloatingInteractionBar(theme, isLight),
    );
  }

  // ── Circular icon button for app bar ──────────────────────────────────────
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isLight,
  }) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _newsItem.media.isNotEmpty
                ? Colors.black.withValues(alpha: 0.35)
                : theme.appGrey100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: _newsItem.media.isNotEmpty
                ? Colors.white
                : theme.appTextPrimary,
          ),
        ),
      ),
    );
  }

  // ── Source & time row ─────────────────────────────────────────────────────
  Widget _buildSourceRow(ThemeData theme) {
    return Row(
      children: [
        // Author badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.appPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: 16, borderRadius: 4),
              const SizedBox(width: 4),
              Text(
                _newsItem.authorName?.isNotEmpty == true
                    ? _newsItem.authorName!
                    : 'Deep Pulse',
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  fontWeight: FontWeight.w600,
                  color: theme.appPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Time
        Icon(Icons.schedule_rounded, size: 14, color: theme.appTextLight),
        const SizedBox(width: 4),
        Text(
          _formatTimestamp(_newsItem.createdAt),
          style: TextStyle(
            fontSize: scaledFontSize(13),
            color: theme.appTextLight,
          ),
        ),
        const Spacer(),
        // Views
        Icon(Icons.visibility_outlined, size: 14, color: theme.appTextLight),
        const SizedBox(width: 4),
        Text(
          '${_newsItem.viewsCount}',
          style: TextStyle(
            fontSize: scaledFontSize(13),
            color: theme.appTextLight,
          ),
        ),
      ],
    );
  }

  // ── Media section ─────────────────────────────────────────────────────────
  Widget _buildMediaSection(BuildContext context, ThemeData theme) {
    final mediaItems = _newsItem.media.toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) return const SizedBox.shrink();

    final currentPage = _currentCarouselPages[_newsItem.id] ?? 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Media content
        if (mediaCount == 1)
          _buildSingleMedia(mediaItems[0], theme)
        else
          PageView.builder(
            controller: _pageController,
            itemCount: mediaCount,
            onPageChanged: (page) {
              setState(() {
                _currentCarouselPages[_newsItem.id] = page;
              });
              _videoPreloader.pauseAllVideos();
            },
            itemBuilder: (context, index) {
              final media = mediaItems[index];
              final isVisible = index == currentPage;
              return media.type == 'video'
                  ? VideoPlayerWidget(
                      videoUrl: media.fileUrl,
                      autoPlay: false,
                      isVisible: isVisible,
                    )
                  : CachedImageWidget(
                      imageUrl: media.fileUrl,
                      fit: BoxFit.cover,
                      errorWidget: _buildMediaError(theme),
                    );
            },
          ),

        // Gradient overlay at bottom for readability
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),

        // Page indicators for multiple media
        if (mediaCount > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                mediaCount,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == currentPage
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

        // Deep Pulse branding
        Positioned(
          bottom: 12,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(size: 16, borderRadius: 4),
                const SizedBox(width: 5),
                Text(
                  'Deep Pulse',
                  style: TextStyle(
                    fontSize: scaledFontSize(11),
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMedia(NewsMedia media, ThemeData theme) {
    return media.type == 'video'
        ? VideoPlayerWidget(
            videoUrl: media.fileUrl,
            autoPlay: false,
            isVisible: true,
          )
        : CachedImageWidget(
            imageUrl: media.fileUrl,
            fit: BoxFit.cover,
            errorWidget: _buildMediaError(theme),
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

  // ── Floating interaction bar ──────────────────────────────────────────────
  Widget _buildFloatingInteractionBar(ThemeData theme, bool isLight) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Like
            Consumer(
              builder: (context, ref, child) {
                final isLiked = _newsItem.isLiked == 1;
                final likeColor = isLiked
                    ? const Color(0xFF2563EB)
                    : theme.appTextSecondary;
                return _buildInteractionChip(
                  theme,
                  icon: Icons.thumb_up_rounded,
                  label: _newsItem.likesCount.toString(),
                  color: likeColor,
                  isActive: isLiked,
                  onTap: () async {
                    final isAuthenticated = await AuthHelper.requireAuth(
                      context,
                      ref,
                      title: 'Login to Like',
                      message: 'Please login to like this news article.',
                    );
                    if (!isAuthenticated) return;
                    // Update UI instantly, API call in background
                    setState(() {
                      _newsItem = _newsItem.copyWith(
                        isLiked: 1,
                        likesCount: _newsItem.isLiked == 1
                            ? _newsItem.likesCount
                            : _newsItem.likesCount + 1,
                      );
                    });
                    ref
                        .read(homeViewModelProvider)
                        .likeDislike(
                          likeableId: _newsItem.id,
                          likeableType: LikeableType.news,
                          isLike: true,
                        );
                  },
                );
              },
            ),
            // Dislike
            Consumer(
              builder: (context, ref, child) {
                final isDisliked = _newsItem.isLiked == 0;
                final dislikeColor = isDisliked
                    ? theme.appPrimary
                    : theme.appTextSecondary;
                return _buildInteractionChip(
                  theme,
                  icon: Icons.thumb_down_rounded,
                  label: '0',
                  color: dislikeColor,
                  isActive: isDisliked,
                  onTap: () async {
                    final isAuthenticated = await AuthHelper.requireAuth(
                      context,
                      ref,
                      title: 'Login to Dislike',
                      message: 'Please login to dislike this news article.',
                    );
                    if (!isAuthenticated) return;
                    // Update UI instantly, API call in background
                    setState(() {
                      _newsItem = _newsItem.copyWith(
                        isLiked: 0,
                        likesCount: _newsItem.isLiked == 1
                            ? _newsItem.likesCount - 1
                            : _newsItem.likesCount,
                      );
                    });
                    ref
                        .read(homeViewModelProvider)
                        .likeDislike(
                          likeableId: _newsItem.id,
                          likeableType: LikeableType.news,
                          isLike: false,
                        );
                  },
                );
              },
            ),
            // Comments
            if (widget.initialNewsItem.isComment)
              _buildInteractionChip(
                theme,
                icon: Icons.chat_bubble_rounded,
                label: _newsItem.commentsCount.toString(),
                color: theme.appTextSecondary,
                onTap: () async {
                  final isAuthenticated = await AuthHelper.requireAuth(
                    context,
                    ref,
                    title: 'Login to Comment',
                    message: 'Please login to comment on this news article.',
                  );
                  if (isAuthenticated && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(
                          news: _newsItem,
                          onCommentPosted: () async {
                            await _refreshNewsItem();
                            widget.onCommentPosted?.call();
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            // Share
            _buildInteractionChip(
              theme,
              icon: Icons.share_rounded,
              label: _newsItem.sharesCount.toString(),
              color: theme.appTextSecondary,
              onTap: () async {
                try {
                  final shareUrl = _newsItem.shareUrl.isNotEmpty
                      ? _newsItem.shareUrl
                      : 'https://deeppulse.co.in/news/${_newsItem.id}';
                  await Share.share(shareUrl);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(13),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper methods ────────────────────────────────────────────────────────
  String _getNewsTitle() {
    if (_newsItem.translations.isNotEmpty) {
      return _newsItem.translations.first.title;
    }
    return 'No title available';
  }

  String _getNewsShortDescription() {
    if (_newsItem.translations.isNotEmpty) {
      return _newsItem.translations.first.shortDescription;
    }
    return '';
  }

  String _getNewsContent() {
    if (_newsItem.translations.isNotEmpty) {
      return _newsItem.translations.first.content;
    }
    return '';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
