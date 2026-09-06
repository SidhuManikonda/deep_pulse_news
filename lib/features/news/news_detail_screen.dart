import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/news.dart';
import '../../data/repositories/news_repository.dart';
import '../comments/comments_screen.dart';
import '../../shared/widgets/video_player_widget.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../core/services/video_preloader_service.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  final News initialNewsItem;
  final VoidCallback? onCommentPosted;

  const NewsDetailScreen({
    super.key,
    required this.initialNewsItem,
    this.onCommentPosted,
  });

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  late News _newsItem;
  late final NewsRepository _newsRepository;
  final _videoPreloader = VideoPreloaderService();
  final Map<int, int> _currentCarouselPages = {}; // Track carousel page per news item

  @override
  void initState() {
    super.initState();
    _newsItem = widget.initialNewsItem;
    _newsRepository = NewsRepositoryImpl();
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
      // Handle error silently or show snackbar
      print('Failed to refresh news item: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () {
            // Pause all videos before navigating back
            _videoPreloader.pauseAllVideos();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onPressed: () {
              // TODO: Share functionality
            },
          ),
          IconButton(
            icon: Icon(
              Icons.bookmark_border,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            onPressed: () {
              // TODO: Bookmark functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media section
            if (_newsItem.media.isNotEmpty) _buildMediaSection(context),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _getNewsTitle(),
                    style: TextStyle(
                      fontSize: scaledFontSize(21),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Meta info
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).appGrey600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(_newsItem.displayTime),
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: Theme.of(context).appGrey600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: Theme.of(context).appGrey600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_newsItem.viewsCount} views',
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: Theme.of(context).appGrey600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Short description
                  if (_getNewsShortDescription().isNotEmpty) ...[
                    Text(
                      _getNewsShortDescription(),
                      style: TextStyle(
                        fontSize: scaledFontSize(22.0),
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Full content
                  if (_getNewsContent().isNotEmpty &&
                      _getNewsContent() != _getNewsShortDescription())
                    Text(
                      _getNewsContent(),
                      style: TextStyle(
                        fontSize: scaledFontSize(22.0),
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.5,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Interaction section
                  _buildInteractionSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context) {
    final mediaItems = _newsItem.media.take(3).toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) {
      return const SizedBox.shrink();
    }

    if (mediaCount == 1) {
      // Single media item - use 4:3 aspect ratio like home screen
      final media = mediaItems[0];
      return SizedBox(
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).appGrey200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.expand(
                    child: media.type == 'video'
                        ? VideoPlayerWidget(
                            videoUrl: media.fileUrl,
                            autoPlay: false,
                            isVisible: true,
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
                    child: Text(
                      _formatTimestamp(_newsItem.displayTime),
                      style:  TextStyle(
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
                        Text(
                          'Deep Pulse',
                          style:  TextStyle(
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
            ),
          ),
        ),
      );
    } else {
      // Multiple media items with PageView slider (up to 3) - use 16:9 aspect ratio like home screen
      final currentCarouselPage = _currentCarouselPages[_newsItem.id] ?? 0;

      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PageView.builder(
                  itemCount: mediaCount,
                  onPageChanged: (page) {
                    setState(() {
                      _currentCarouselPages[_newsItem.id] = page;
                    });
                    // Pause all videos in this carousel when switching pages
                    _videoPreloader.pauseAllVideos();
                  },
                  itemBuilder: (context, carouselIndex) {
                    final media = mediaItems[carouselIndex];
                    final isMediaVisible = carouselIndex == currentCarouselPage;

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
                  child: Text(
                    '${currentCarouselPage + 1}/$mediaCount',
                    style:  TextStyle(
                      fontSize: scaledFontSize(12),
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
                  child: Text(
                    _formatTimestamp(_newsItem.displayTime),
                    style:  TextStyle(
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
                      Text(
                        'Deep Pulse',
                        style:  TextStyle(
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
          ),
        ),
      );
    }
  }

  Widget _buildInteractionSection(BuildContext context) {
    // Determine like status colors
    final likeColor = _newsItem.isLiked == 1
        ? Colors.blue
        : Theme.of(context).appGrey600;
    final dislikeColor = _newsItem.isLiked == 0
        ? Colors.red
        : Theme.of(context).appGrey600;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).appGrey300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInteractionButton(
            context,
            Icons.thumb_up_outlined,
            _newsItem.likesCount.toString(),
            likeColor,
            () {},
          ),
          _buildInteractionButton(
            context,
            Icons.thumb_down_outlined,
            '0', // No dislikes count available
            dislikeColor,
            () {},
          ),
          _buildInteractionButton(
            context,
            Icons.comment_outlined,
            _newsItem.commentsCount.toString(),
            Theme.of(context).appGrey600,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CommentsScreen(
                    news: _newsItem,
                    onCommentPosted: () async {
                      // Refresh local news item
                      await _refreshNewsItem();
                      // Also call parent callback to refresh home screen
                      widget.onCommentPosted?.call();
                    },
                  ),
                ),
              );
            },
          ),
          _buildInteractionButton(
            context,
            Icons.share_outlined,
            _newsItem.sharesCount.toString(),
            Theme.of(context).appGrey600,
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton(
    BuildContext context,
    IconData icon,
    String count,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24, color: iconColor),
          if (count.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: appFontSizeCaption,
                color: Theme.of(context).appGrey600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRelatedNewsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related News',
          style: TextStyle(
            fontSize: appFontSizeHeader,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.headlineLarge?.color,
          ),
        ),
        const SizedBox(height: 12),

        // Related news items
        ...List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).appCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).appGrey300),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).appGrey200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, color: Theme.of(context).appGrey400),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Related News Title ${index + 1}',
                        style: TextStyle(
                          fontSize: appFontSizeBody,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 hour ago',
                        style: TextStyle(
                          fontSize: appFontSizeCaption,
                          color: Theme.of(context).appGrey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper methods to extract data from News object
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
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
