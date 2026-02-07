import 'package:deep_pulse_news/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../news/news_detail_screen.dart';
import 'home_view_model.dart';
import '../settings/settings_screen.dart';
import '../news/news_upload_screen.dart';
import '../notifications/notifications_screen.dart';
import '../auth/auth_helper.dart';
import '../../data/models/news.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the view model
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeViewModelProvider).initialize();
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

            // Location tabs
            _buildLocationTabs(context),

            // Main content area - News feed only
            Expanded(child: _buildNewsFeed(context)),

            // Bottom navigation
            _buildBottomNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
            child: CircleAvatar(
              radius: 18,
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
            icon: Icon(
              Icons.more_vert,
              color: Colors.grey[600],
              size: 20,
            ),
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

    // Define icons for each tab
    final tabIcons = {
      'Your Area': Icons.home_outlined,
      'State Name': Icons.location_city_outlined,
      'National': Icons.public_outlined,
      'International': Icons.language_outlined,
    };

    return Container(
      height: 65,
      margin: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = homeViewModel.selectedLocationTab == tab['name'];
            final tabName = tab['name'] as String;
            final displayName = tab['displayName'] as String;
            final icon = tabIcons[tabName] ?? Icons.category_outlined;

            return Container(
              margin: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () {
                  ref
                      .read(homeViewModelProvider)
                      .setSelectedLocationTab(tabName);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).appPrimary.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).appPrimary
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    AutoScaledText(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? Theme.of(context).appPrimary
                            : Colors.grey[600],
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNewsFeed(BuildContext context) {
    final homeViewModel = ref.watch(homeViewModelProvider);

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

    return PageView.builder(
      itemCount: newsItems.length,
      scrollDirection: Axis.vertical,
      itemBuilder: (context, index) {
        return _buildNewsCard(context, newsItems[index], index);
      },
    );
  }

  Widget _buildNewsCard(BuildContext context, News newsItem, int index) {
    return Container(
      width: double.infinity,
      height:
          (MediaQuery.of(context).size.height -
              MediaQuery.of(context).padding.top) +
          500, // Account for header, tabs and bottom nav
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User profile header
          _buildUserProfileHeader(context, newsItem),
          
          // Image section (single image or slider)
          Expanded(
            flex: 4,
            child: _buildImageSection(context, _getNewsImages(newsItem)),
          ),

          // Content section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(newsItem.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AutoScaledText(
                    newsItem.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: appFontSizeCaption,
                      color: _getStatusColor(newsItem.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Title
                AutoScaledText(
                  _getNewsTitle(newsItem),
                  style: TextStyle(
                    fontSize: appFontSizeHeader,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).appTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Timestamp
                AutoScaledText(
                  _formatTimestamp(newsItem.createdAt),
                  style: TextStyle(
                    fontSize: appFontSizeCaption,
                    color: Theme.of(context).appTextSecondary,
                  ),
                ),

                const SizedBox(height: 8),

                // Description with Read More
                _buildDescriptionWithReadMore(
                  context,
                  _getNewsDescription(newsItem),
                  newsItem,
                ),

                const SizedBox(height: 12),

                // Options (interaction buttons)
                _buildInteractionBar(context, newsItem),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, List<String> imagePaths) {
    final imageCount = imagePaths.length;

    if (imageCount == 1) {
      // Single image
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Theme.of(context).appGrey200),
          child: Image.network(
            imagePaths[0],
            fit: BoxFit.cover,
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
      // Multiple images with PageView slider
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: imageCount,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: double.infinity,
                  child: Image.network(
                    imagePaths[index],
                    fit: BoxFit.cover,
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
                );
              },
            ),

            // Image counter indicator
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AutoScaledText(
                  '1/$imageCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
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
          fontSize: appFontSizeBody,
          color: Theme.of(context).textTheme.bodyMedium?.color,
          height: 1.4,
        );

        final textSpan = TextSpan(text: description, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: 3,
        );

        textPainter.layout(maxWidth: constraints.maxWidth);
        final isTextOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoScaledText(
              description,
              style: textStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isTextOverflowing) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _navigateToNewsDetail(context, newsItem),
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
        builder: (context) => NewsDetailScreen(newsItem: newsItem),
      ),
    );
  }

  Widget _buildInteractionBar(BuildContext context, News newsItem) {
    return Row(
      children: [
        // Views count
        _buildInteractionButton(
          context,
          Icons.visibility_outlined,
          newsItem.viewsCount.toString(),
          () {},
        ),

        const SizedBox(width: 16),

        // Comment button
        _buildInteractionButton(
          context,
          Icons.comment_outlined,
          newsItem.commentsCount.toString(),
          () async {
            final isAuthenticated = await AuthHelper.requireAuth(
              context,
              ref,
              title: 'Login to Comment',
              message: 'Please login to comment on this news article.',
            );
            if (isAuthenticated) {
              // Handle comment action - could navigate to comments screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening comments...')),
              );
            }
          },
        ),

        const SizedBox(width: 16),

        // Shares count
        _buildInteractionButton(
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
            if (isAuthenticated) {
              // Handle share action
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Shared!')));
            }
          },
        ),

        const Spacer(),

        // Like button (no count shown, just action)
        IconButton(
          onPressed: () async {
            final isAuthenticated = await AuthHelper.requireAuth(
              context,
              ref,
              title: 'Login to Like',
              message: 'Please login to like this news article.',
            );
            if (isAuthenticated) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Liked!')));
            }
          },
          icon: Icon(
            Icons.favorite_border,
            color: Theme.of(context).appTextSecondary,
            size: 20,
          ),
        ),
      ],
    );
  }

  // Helper methods for extracting data from News model
  List<String> _getNewsImages(News newsItem) {
    if (newsItem.media.isNotEmpty) {
      final imageUrls = newsItem.media
          .map((media) => '${AppConstants.imageBaseUrl}/${media.url}')
          .toList();
      print('Image URLs for news ${newsItem.id}: $imageUrls');
      return imageUrls;
    }
    // Fallback to placeholder images if no media
    return ['https://picsum.photos/400/300?random=${newsItem.id}'];
  }

  String _getNewsTitle(News newsItem) {
    final translation = newsItem.getPrimaryTranslation();
    return translation?.title ?? 'News Article #${newsItem.id}';
  }

  String _getNewsDescription(News newsItem) {
    final translation = newsItem.getPrimaryTranslation();
    return translation?.shortDescription ??
        translation?.content ??
        'No description available.';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
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

  Widget _buildInteractionButton(
    BuildContext context,
    IconData icon,
    String count,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).appGrey600),
          if (count.isNotEmpty) ...[
            const SizedBox(width: 4),
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

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).appCard,
        border: Border(top: BorderSide(color: Theme.of(context).appGrey300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Settings
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: Icon(Icons.home, color: Theme.of(context).appGrey600),
          ),

          // Upload
          GestureDetector(
            onTap: () async {
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
                color: Theme.of(context).appPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),

          // Notifications
          IconButton(
            onPressed: () {
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
