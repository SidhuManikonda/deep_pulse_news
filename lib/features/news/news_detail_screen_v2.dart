import 'package:deep_pulse_news/shared/widgets/app_logo.dart';
import 'package:deep_pulse_news/shared/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/utils/color_utils.dart';
import '../../core/services/saved_news_service.dart';
import '../../core/services/video_preloader_service.dart';
import '../../data/models/likeable_type.dart';
import '../../data/models/news.dart';
import '../../data/models/news_media.dart';
import '../../data/repositories/news_repository.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/audio_player_widget.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../shared/widgets/news_ad_block.dart';
import '../../shared/widgets/video_player_widget.dart';
import '../auth/auth_helper.dart';
import '../comments/comments_screen.dart';
import '../home/home_view_model.dart';

class NewsDetailScreenV2 extends ConsumerStatefulWidget {
  final News? initialNewsItem;
  final int? initialNewsId;
  final VoidCallback? onCommentPosted;

  const NewsDetailScreenV2({
    super.key,
    this.initialNewsItem,
    this.initialNewsId,
    this.onCommentPosted,
  }) : assert(
         initialNewsItem != null || initialNewsId != null,
         'Pass either initialNewsItem or initialNewsId',
       );

  @override
  ConsumerState<NewsDetailScreenV2> createState() => _NewsDetailScreenV2State();
}

class _NewsDetailScreenV2State extends ConsumerState<NewsDetailScreenV2> {
  late News _newsItem;
  bool _isLoadingDeeplink = false;
  String? _deeplinkError;
  late final NewsRepository _newsRepository;
  late final SavedNewsService _savedNewsService;
  final _videoPreloader = VideoPreloaderService();
  final Map<int, int> _currentCarouselPages = {};
  final PageController _pageController = PageController();
  bool _isSaved = false;
  @override
  void initState() {
    super.initState();
    _newsRepository = NewsRepositoryImpl();
    _savedNewsService = SavedNewsService(
      userId: ref.read(authViewModelProvider).user?.id,
    );

    if (widget.initialNewsItem != null) {
      _newsItem = widget.initialNewsItem!;
      _checkIfSaved();
    } else {
      // Deeplink path: we only have the id, fetch the full article. Set the
      // loading flag synchronously so build() renders the loader on first
      // frame instead of trying to access the uninitialized `_newsItem`.
      _isLoadingDeeplink = true;
      _loadFromId(widget.initialNewsId!);
    }
  }

  Future<void> _loadFromId(int id) async {
    try {
      final news = await _newsRepository.getNewsById(id);
      if (!mounted) return;
      if (news == null) {
        setState(() {
          _isLoadingDeeplink = false;
          _deeplinkError = 'Could not load article.';
        });
        return;
      }
      setState(() {
        _newsItem = news;
        _isLoadingDeeplink = false;
      });
      _checkIfSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDeeplink = false;
        _deeplinkError = 'Failed to load article: $e';
      });
    }
  }

  Future<void> _checkIfSaved() async {
    final saved = await _savedNewsService.isNewsSaved(_newsItem.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    final isAuthenticated = await AuthHelper.requireAuth(
      context,
      ref,
      title: 'Login to Save',
      message: 'Please login to save this news article.',
    );
    if (!isAuthenticated || !mounted) return;

    // Rebuild the SavedNewsService now that user_id is known (in case the
    // user wasn't logged in when this screen was first opened).
    final savedService = SavedNewsService(
      userId: ref.read(authViewModelProvider).user?.id,
    );

    if (_isSaved) {
      await savedService.removeNews(_newsItem.id);
    } else {
      await savedService.saveNews(_newsItem);
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
    final isAuthenticated = ref.watch(authViewModelProvider).isAuthenticated;

    // Deeplink loading state — caller passed only an id, fetch in progress.
    if (_isLoadingDeeplink) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_deeplinkError != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _deeplinkError!,
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  if (widget.initialNewsId != null) {
                    setState(() {
                      _deeplinkError = null;
                      _isLoadingDeeplink = true;
                    });
                    _loadFromId(widget.initialNewsId!);
                  }
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Thin top bar holding the save action. The media used to live here as
          // a fixed-height collapsing header, which forced every image into a
          // 320px box and cropped/stretched portrait screenshots. The media now
          // lives in the scroll body below so it can show at its true size.
          SliverAppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 56,
            pinned: true,
            titleSpacing: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            // Left: a real back button (the only other way back was the bottom
            // "Back To Home" button). Fills the previously-empty left side.
            leading: _buildCircularButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
              theme: theme,
              isLight: isLight,
            ),
            // Center-left: app branding so the bar isn't a blank strip.
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(size: 26, borderRadius: 6),
                const SizedBox(width: 8),
                Text(
                  'Deep Pulse',
                  style: TextStyle(
                    fontSize: scaledFontSize(16),
                    fontWeight: FontWeight.w800,
                    color: theme.appTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              // Guests get a login CTA right where the empty space was — turns
              // dead space into an invitation to join.
              if (!isAuthenticated) _buildLoginPill(theme),
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
          ),

          // Media first — at its original aspect ratio (no crop or stretch).
          if (_newsItem.media.isNotEmpty)
            SliverToBoxAdapter(child: _buildMediaSection(context, theme)),

          // Title + accent divider BELOW the media.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getNewsTitle(),
                    style: TextStyle(
                      fontSize: scaledFontSize(18),
                      fontWeight: FontWeight.w800,
                      color:
                          colorFromHex(_newsItem.titleColor) ??
                          theme.appTextPrimary,
                      height: 1.3,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 3,
                    width: 40,
                    decoration: BoxDecoration(
                      color: theme.appPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Byline: reporter, time, views. The reporter chip is only
                  // repeated here when the media overlay isn't carrying it
                  // (no media, or the author opted out of showing a profile).
                  _buildSourceRow(theme, showAuthor: !_isAuthorOverlayVisible),
                ],
              ),
            ),
          ),

          // Body content (short description, full content, back button).
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Short description
                  if (_getNewsShortDescription().isNotEmpty) ...[
                    Text(
                      _getNewsShortDescription(),
                      style: TextStyle(
                        fontSize: scaledFontSize(17.0),
                        color:
                            colorFromHex(_newsItem.descriptionColor) ??
                            theme.appTextPrimary,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // First ad sits between the summary and the full article —
                  // the natural pause in the read, and the placement every
                  // major news app uses. Never above the headline, and never
                  // mid-sentence.
                  if (_newsItem.ads.isNotEmpty) ...[
                    NewsAdBlock(ad:_newsItem.ads.first),
                    const SizedBox(height: 20),
                  ],

                  // Full content
                  if (_getNewsContent().isNotEmpty &&
                      _getNewsContent() != _getNewsShortDescription()) ...[
                    Text(
                      _getNewsContent(),
                      style: TextStyle(
                        fontSize: scaledFontSize(17.0),
                        color:
                            colorFromHex(_newsItem.fullTextColor) ??
                            theme.appTextPrimary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Second ad closes the article, after the reader has the
                  // whole story.
                  if (_newsItem.ads.length > 1) ...[
                    NewsAdBlock(ad:_newsItem.ads[1]),
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
  /// Compact "Login" pill shown to guests in the top bar — turns the empty
  /// header space into a gentle sign-in invitation.
  Widget _buildLoginPill(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: GestureDetector(
        onTap: () async {
          await AuthHelper.requireAuth(
            context,
            ref,
            title: 'Join Deep Pulse',
            message:
                'Login to like, comment, save articles and personalize your feed.',
          );
          if (mounted) setState(() {}); // refresh bar if they signed in
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: theme.appPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.login_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: scaledFontSize(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            color: theme.appGrey100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: theme.appTextPrimary),
        ),
      ),
    );
  }

  // ── Author identity ───────────────────────────────────────────────────────
  /// True when the reporter badge is already painted over the media, so the
  /// byline row below the title can skip repeating the name.
  bool get _isAuthorOverlayVisible =>
      _newsItem.media.isNotEmpty &&
      _newsItem.showProfile &&
      (_newsItem.authorName?.isNotEmpty ?? false);

  /// Deterministic avatar background derived from the author name — same
  /// palette as the home feed so a reporter keeps one color app-wide.
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

  Widget _buildAuthorAvatar(String name, {double size = 22}) {
    final photo = _newsItem.authorProfilePhoto;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final fallback = Center(
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _avatarColor(name),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedImageWidget(
              imageUrl: photo,
              fit: BoxFit.cover,
              errorWidget: fallback,
            )
          : fallback,
    );
  }

  /// Pill badge overlaid on the bottom-left of the media — photo (initial
  /// fallback) + reporter name + role, mirroring the home feed card.
  Widget _buildAuthorBadge() {
    final name = _newsItem.authorName ?? '';
    final role = _newsItem.authorRoleName;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAuthorAvatar(name),
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

  // ── Source & time row ─────────────────────────────────────────────────────
  Widget _buildSourceRow(ThemeData theme, {bool showAuthor = true}) {
    final name = _newsItem.authorName?.isNotEmpty == true
        ? _newsItem.authorName!
        : 'Deep Pulse';
    final role = _newsItem.authorRoleName;
    // The reporter's own photo when they publish under their profile;
    // otherwise the article is credited to the desk, so use the app logo.
    final useReporterIdentity =
        _newsItem.showProfile && (_newsItem.authorName?.isNotEmpty ?? false);

    return Row(
      children: [
        // Author badge
        if (showAuthor) ...[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: theme.appPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  useReporterIdentity
                      ? _buildAuthorAvatar(name, size: 18)
                      : AppLogo(size: 16, borderRadius: 4),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      useReporterIdentity && role != null && role.isNotEmpty
                          ? '$name · $role'
                          : name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: scaledFontSize(12),
                        fontWeight: FontWeight.w600,
                        color: theme.appPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Time
        Icon(Icons.schedule_rounded, size: 14, color: theme.appTextLight),
        const SizedBox(width: 4),
        Text(
          _formatTimestamp(_newsItem.displayTime),
          style: TextStyle(
            fontSize: scaledFontSize(13),
            color: theme.appTextLight,
          ),
        ),
        // Views — an editorial metric, so it's only for the people who manage
        // news (dist-reporter and up). Readers, reporters and guests don't see
        // it.
        if (_canSeeViewCount) ...[
          const Spacer(),
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
      ],
    );
  }

  /// Roles allowed to see the view counter on an article. Guests (no user) and
  /// the reader/reporter roles are excluded.
  bool get _canSeeViewCount {
    final user = ref.read(authViewModelProvider).user;
    if (user == null) return false;
    const allowed = {'dist-reporter', 'sub_admin', 'admin'};
    return allowed.contains(user.primaryRole.value);
  }

  // ── Media section ─────────────────────────────────────────────────────────
  Widget _buildMediaSection(BuildContext context, ThemeData theme) {
    final mediaItems = _newsItem.media.toList();
    final mediaCount = mediaItems.length;

    if (mediaCount == 0) return const SizedBox.shrink();

    final currentPage = _currentCarouselPages[_newsItem.id] ?? 0;

    return Stack(
      children: [
        // Media content
        if (mediaCount == 1)
          _buildSingleMedia(context, mediaItems[0], theme)
        else
          // Mixed-aspect-ratio media in a carousel need a uniform bounded
          // height; BoxFit.contain on a dark backdrop keeps each item fully
          // visible without cropping or stretching.
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child: PageView.builder(
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
                    : media.type == 'audio'
                    ? Container(
                        color: theme.appGrey200,
                        alignment: Alignment.center,
                        child: AudioPlayerWidget(
                          audioUrl: media.fileUrl,
                          isVisible: isVisible,
                        ),
                      )
                    : Container(
                        color: theme.appGrey200,
                        child: CachedImageWidget(
                          imageUrl: media.fileUrl,
                          fit: BoxFit.contain,
                          errorWidget: _buildMediaError(theme),
                        ),
                      );
              },
            ),
          ),

        // Gradient + page indicators only when there are multiple items —
        // on a single image/video the strip just darkens the bottom edge
        // for no reason (no indicators to contrast against).
        if (mediaCount > 1) ...[
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
        ],

        // Reporter overlay at bottom left — same rule as the home feed card:
        // only when the author opted to show their profile and has a name.
        if (_isAuthorOverlayVisible)
          Positioned(
            bottom: 8,
            left: 12,
            child: IgnorePointer(child: _buildAuthorBadge()),
          ),

        // Deep Pulse watermark — matches the bottom-right badge on the home
        // feed news cards so the brand stays attached to shared screenshots.
        Positioned(
          bottom: 8,
          right: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
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
        ),
      ],
    );
  }

  Widget _buildSingleMedia(
    BuildContext context,
    NewsMedia media,
    ThemeData theme,
  ) {
    // Videos keep a fixed landscape box; audio shows a compact player; images
    // render at their true aspect ratio so portrait screenshots show fully
    // without cropping or stretching.
    if (media.type == 'audio') {
      return Container(
        width: double.infinity,
        color: theme.appGrey200,
        alignment: Alignment.center,
        child: AudioPlayerWidget(audioUrl: media.fileUrl, isVisible: true),
      );
    }
    return media.type == 'video'
        ? ClipRect(
            // ClipRect is load-bearing: VideoPlayerWidget uses
            // FittedBox(BoxFit.cover) which scales the source up to fill
            // and then OVERFLOWS the parent because FittedBox doesn't
            // clip by default. Without this clip, the scrubber (Positioned
            // bottom:0 of the player's Stack) ends up mid-frame visually
            // while the upscaled video bleeds below the box. With the
            // ClipRect the player sits exactly within 180dp and the
            // scrubber lands at the actual bottom edge.
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: ColoredBox(
                color: Colors.black,
                child: VideoPlayerWidget(
                  videoUrl: media.fileUrl,
                  autoPlay: false,
                  isVisible: true,
                ),
              ),
            ),
          )
        : AdaptiveCachedImage(
            imageUrl: media.fileUrl,
            backgroundColor: theme.appGrey200,
            // Match the feed: cap tall portrait images so they don't take over
            // the screen; the full image still shows (contained) within the cap.
            maxHeight: MediaQuery.of(context).size.height * 0.45,
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
            if (_newsItem.isComment)
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
                final isAuthenticated = await AuthHelper.requireAuth(
                  context,
                  ref,
                  title: 'Login to Share',
                  message: 'Please login to share this news article.',
                );
                if (!isAuthenticated || !mounted) return;
                try {
                  final shareUrl = _newsItem.shareUrl.isNotEmpty
                      ? _newsItem.shareUrl
                      : 'https://api.deeppulse.media/news/${_newsItem.id}';
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

/// A sponsor creative shown inside an article.
///
/// Three rules, all deliberate and all standard for news apps:
///  * it is always labelled **Ad**, so a reader can never mistake paid
///    placement for editorial content (also what Play policy expects);
///  * it is visually fenced off — its own bordered block, never blended into
///    the story's media carousel; and
///  * video ads never autoplay and start muted, because a story page that
///    suddenly makes noise is the fastest way to lose a reader.
