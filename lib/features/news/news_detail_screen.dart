import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../data/models/news.dart';

class NewsDetailScreen extends ConsumerWidget {
  final News newsItem;

  const NewsDetailScreen({
    super.key,
    required this.newsItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onPressed: () => Navigator.pop(context),
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
            // Images section
            if (_getNewsImages().isNotEmpty) _buildImagesSection(context),

            // Content section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  AutoScaledText(
                    _getNewsTitle(),
                    style: TextStyle(
                      fontSize: appFontSizeTitle,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.headlineLarge?.color,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Meta info
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Theme.of(context).appGrey600,
                      ),
                      const SizedBox(width: 4),
                      AutoScaledText(
                        _formatTimestamp(newsItem.createdAt),
                        style: TextStyle(
                          fontSize: appFontSizeCaption,
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
                      AutoScaledText(
                        '${newsItem.viewsCount} views',
                        style: TextStyle(
                          fontSize: appFontSizeCaption,
                          color: Theme.of(context).appGrey600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Full content
                  AutoScaledText(
                    _getNewsContent(),
                    style: TextStyle(
                      fontSize: appFontSizeBody,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Interaction section
                  _buildInteractionSection(context),

                  const SizedBox(height: 24),

                  // Related news section
                  _buildRelatedNewsSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context) {
    final images = _getNewsImages();
    if (images.length == 1) {
      return Container(
        height: 250,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).appGrey200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            images[0],
            fit: BoxFit.cover,
            width: double.infinity,
            height: 250,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Theme.of(context).appGrey200,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).appGrey200,
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 64,
                    color: Theme.of(context).appGrey400,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      return Container(
        height: 250,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: PageView.builder(
          itemCount: images.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 250,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Theme.of(context).appGrey200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Theme.of(context).appGrey200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 64,
                              color: Theme.of(context).appGrey400,
                            ),
                            const SizedBox(height: 8),
                            AutoScaledText(
                              'Image ${index + 1}',
                              style: TextStyle(
                                fontSize: appFontSizeCaption,
                                color: Theme.of(context).appGrey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildInteractionSection(BuildContext context) {
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
            '0', // API doesn't provide like count
            () {},
          ),
          _buildInteractionButton(
            context,
            Icons.thumb_down_outlined,
            '0', // API doesn't provide dislike count
            () {},
          ),
          _buildInteractionButton(
            context,
            Icons.comment_outlined,
            newsItem.commentsCount.toString(),
            () {},
          ),
          _buildInteractionButton(context, Icons.share_outlined, '', () {}),
        ],
      ),
    );
  }

  Widget _buildInteractionButton(
    BuildContext context,
    IconData icon,
    String count,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).appGrey600),
          if (count.isNotEmpty) ...[
            const SizedBox(height: 4),
            AutoScaledText(
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
        AutoScaledText(
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
                      AutoScaledText(
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
                      AutoScaledText(
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
    if (newsItem.translations.isNotEmpty) {
      return newsItem.translations.first.title;
    }
    return 'No title available';
  }

  String _getNewsContent() {
    if (newsItem.translations.isNotEmpty) {
      return newsItem.translations.first.content;
    }
    return 'No content available';
  }

  List<String> _getNewsImages() {
    return newsItem.media.map((media) => media.url).toList();
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
