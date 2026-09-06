import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:video_compress/video_compress.dart';

import 'package:deep_pulse_news/data/models/district.dart';
import 'package:deep_pulse_news/data/models/mandal.dart';
import 'package:deep_pulse_news/data/models/state.dart' as location_models;
import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/features/home/home_view_model.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' hide colorFromHex;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/media_picker_services.dart';
import '../../core/services/onboarding_storage.dart';
import '../../core/services/video_preloader_service.dart';
import '../../core/utils/color_utils.dart';
import '../../data/models/news.dart';
import '../../data/models/user.dart';
import '../../data/repositories/notification_repository.dart';
import '../../extensions/user_extensions.dart';
import '../../shared/widgets/cached_image_widget.dart';
import 'news_upload_view_model.dart';
import '../../core/constants/app_font_sizes.dart';

const _kAccent = Color(0xFF2563EB);
const _kAccentLight = Color(0xFFDBEAFE);
const _kSuccess = Color(0xFF16A34A);

/// Curated, legible title-color choices offered in the upload screen. Kept to a
/// vetted palette so titles stay readable against the card background.
const List<Color> _kTitleColorSwatches = [
  Color(0xFF111827), // near-black
  Color(0xFFE0245E), // red/pink
  Color(0xFF2563EB), // blue
  Color(0xFF16A34A), // green
  Color(0xFFF59E0B), // amber
  Color(0xFF7C3AED), // purple
  Color(0xFF0EA5E9), // sky
  Color(0xFFDB2777), // magenta
];

class UploadPermissions {
  final bool showTopics;
  final bool showLocations;
  final bool canSelectStates;
  final bool canSelectDistricts;
  final bool canSelectMandals;

  /// Locks the Topics card to "Your Area" and auto-assigns it. No role sets
  /// this today — dist-reporters used to, until they were given full topic
  /// access. Kept so the restriction can be re-applied to a role in one line.
  final bool limitTopicToYourArea;

  const UploadPermissions._({
    required this.showTopics,
    required this.showLocations,
    required this.canSelectStates,
    required this.canSelectDistricts,
    required this.canSelectMandals,
    required this.limitTopicToYourArea,
  });

  factory UploadPermissions.forRole(String role) {
    switch (role) {
      case 'admin':
        return const UploadPermissions._(
          showTopics: true,
          showLocations: true,
          canSelectStates: true,
          canSelectDistricts: true,
          canSelectMandals: true,
          limitTopicToYourArea: false,
        );
      // Dist-reporters publish with the same reach as sub-admins: any
      // district and mandal inside their state (single, multiple, or "Select
      // All"), and any topic — "All Info" plus everything under the home
      // "More" tab — not just "Your Area". Their state stays admin-assigned.
      case 'sub_admin':
      case 'dist-reporter':
        return const UploadPermissions._(
          showTopics: true,
          showLocations: true,
          canSelectStates: false,
          canSelectDistricts: true,
          canSelectMandals: true,
          limitTopicToYourArea: false,
        );
      // reader & reporter: no topics/locations UI, auto-assigned
      default:
        return const UploadPermissions._(
          showTopics: false,
          showLocations: false,
          canSelectStates: false,
          canSelectDistricts: false,
          canSelectMandals: false,
          limitTopicToYourArea: false,
        );
    }
  }
}

class NewsUploadScreen extends ConsumerStatefulWidget {
  final News? prefillNews;

  const NewsUploadScreen({super.key, this.prefillNews});

  @override
  ConsumerState<NewsUploadScreen> createState() => _NewsUploadScreenState();
}

class _NewsUploadScreenState extends ConsumerState<NewsUploadScreen>
    with WidgetsBindingObserver {
  final _headlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _moreController = TextEditingController();
  final _mediaPickerService = MediaPickerService();
  late final UploadPermissions _permissions;

  /// Selected title color as a hex string ("#RRGGBB"); null = default theme
  /// color. Sent to the backend as `title_color` and applied to the headline.
  String? _titleColor;

  /// Selected description color. Sent to the backend as `content_color` and
  /// applied to the description text. Null = default theme color.
  String? _descriptionColor;

  /// Selected full-article color. Sent to the backend as `full_text_color` and
  /// applied to the full article text. Null = default theme color.
  String? _fullTextColor;

  @override
  void initState() {
    super.initState();

    // Silence any feed video still playing in the background. The video_player
    // controllers live in a singleton preloader and the home feed stays mounted
    // behind this route, so without this you'd keep hearing a feed video's
    // audio while on the upload screen. We also re-pause on app resume to catch
    // the case where returning from the system media picker auto-resumes them.
    WidgetsBinding.instance.addObserver(this);
    VideoPreloaderService().pauseAllVideos();

    final user = ref.read(authViewModelProvider).user;
    final role = user?.primaryRole.value ?? 'reader';
    _permissions = UploadPermissions.forRole(role);

    ref.read(newsUploadViewModelProvider.notifier).clearData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load topics first and wait for them
      await ref.read(topicViewModelProvider).loadTopics();

      final vm = ref.read(newsUploadViewModelProvider.notifier);
      await vm.loadStates();

      if (user != null && widget.prefillNews == null) {
        await _autoSelectUserLocations(vm, user, role);
        if (_permissions.limitTopicToYourArea) {
          _autoSelectYourAreaTopic(vm);
        }
      }

      final news = widget.prefillNews;
      if (news != null) {
        await _prefillFromExistingNews(vm, news);
      }
    });
  }

  /// Auto-select locations based on what the user is assigned to.
  Future<void> _autoSelectUserLocations(
    NewsUploadViewModel vm,
    User user,
    String role,
  ) async {
    if (role == 'admin') return;
    if (role == 'reader') {
      final usedSelected = await _autoSelectReaderSelectedLocation(vm);
      if (usedSelected) {
        if (mounted) setState(() {});
        return;
      }
    }
    if (user.stateId != null && !vm.selectedStateIds.contains(user.stateId)) {
      final state = vm.availableStates
          .where((s) => s.id == user.stateId)
          .firstOrNull;
      if (state != null) await vm.toggleState(state);
    }
    if (user.districtId != null &&
        !vm.selectedDistrictIds.contains(user.districtId)) {
      final district = vm.availableDistricts
          .where((d) => d.id == user.districtId)
          .firstOrNull;
      if (district != null) await vm.toggleDistrict(district);
    }

    // Auto-select their mandal
    if (user.mandalId != null &&
        !vm.selectedMandalIds.contains(user.mandalId)) {
      final mandal = vm.availableMandals
          .where((m) => m.id == user.mandalId)
          .firstOrNull;
      if (mandal != null) vm.toggleMandal(mandal);
    }

    if (mounted) setState(() {});
  }

  Future<bool> _autoSelectReaderSelectedLocation(NewsUploadViewModel vm) async {
    final storage = OnboardingStorage();
    final state = await storage.getSelectedState();
    final district = await storage.getSelectedDistrict();
    final mandal = await storage.getSelectedMandal();
    if (state == null || district == null || mandal == null) return false;

    final s = vm.availableStates.where((x) => x.id == state.id).firstOrNull;
    if (s == null) return false;
    if (!vm.selectedStateIds.contains(s.id)) await vm.toggleState(s);

    final d = vm.availableDistricts
        .where((x) => x.id == district.id)
        .firstOrNull;
    if (d == null) return false;
    if (!vm.selectedDistrictIds.contains(d.id)) await vm.toggleDistrict(d);

    // toggleDistrict loads this district's mandals asynchronously above.
    final m = vm.availableMandals.where((x) => x.id == mandal.id).firstOrNull;
    if (m == null) return false;
    if (!vm.selectedMandalIds.contains(m.id)) vm.toggleMandal(m);

    return true;
  }

  /// For dist-reporters: auto-select "Your Area" topic.
  void _autoSelectYourAreaTopic(NewsUploadViewModel vm) {
    final topics = ref.read(topicViewModelProvider).topics;
    final yourArea = topics
        .where(
          (t) =>
              t.name.toLowerCase() == 'your area' ||
              (t.slug?.toLowerCase() ?? '') == 'your-area',
        )
        .firstOrNull;
    if (yourArea != null &&
        !vm.selectedCategories.any((c) => c.id == yourArea.id)) {
      ref.read(newsUploadViewModelProvider.notifier).toggleCategory(yourArea);
    }
  }

  /// Prefill form from existing news (editing flow).
  Future<void> _prefillFromExistingNews(
    NewsUploadViewModel vm,
    News news,
  ) async {
    final translation = news.getPrimaryTranslation();
    if (translation != null) {
      _headlineController.text = translation.title;
      _descriptionController.text = translation.shortDescription;
      // Only treat `content` as "full article" if it's actually different
      // from the short description. Some backends mirror the description
      // into the content field when the author didn't add extra body —
      // keeping that would auto-tick "add full article content" on edit
      // and show the same text duplicated in both inputs.
      final content = translation.content.trim();
      final shortDesc = translation.shortDescription.trim();
      if (content.isNotEmpty && content != shortDesc) {
        _moreController.text = translation.content;
      }
    }
    _titleColor = news.titleColor;
    _descriptionColor = news.descriptionColor;
    _fullTextColor = news.fullTextColor;

    final allTopics = ref.read(topicViewModelProvider).topics;
    await vm.prefillFromNews(
      allTopics: allTopics,
      topicIds: news.topicLocations.map((l) => l.id).toList(),
      stateIds: news.stateLocations.map((l) => l.id).toList(),
      districtIds: news.districtLocations.map((l) => l.id).toList(),
      mandalIds: news.mandalLocations.map((l) => l.id).toList(),
      existingMedia: news.media,
    );

    if (_moreController.text.isNotEmpty) {
      vm.setIsMoreChecked(true);
    }
    vm.setAcceptTerms(true);

    _isImportant = news.isImportant;
    _isComment = news.isComment;
    _showProfile = news.showProfile;

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _headlineController.dispose();
    _descriptionController.dispose();
    _moreController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Returning from the media picker resumes the app — re-pause any feed
    // video the plugin may have auto-resumed so its audio doesn't leak here.
    if (state == AppLifecycleState.resumed && mounted) {
      VideoPreloaderService().pauseAllVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(newsUploadViewModelProvider);
    final topicViewModel = ref.watch(topicViewModelProvider);
    final theme = Theme.of(context);

    // Topics: required only if showTopics is true AND not auto-assigned (limitTopicToYourArea)
    // Locations: required only if showLocations is true
    final isFormValid =
        _headlineController.text.isNotEmpty &&
        _descriptionController.text.isNotEmpty &&
        (_permissions.showTopics && !_permissions.limitTopicToYourArea
            ? vm.selectedCategories.isNotEmpty
            : true) &&
        (_permissions.showLocations ? vm.selectedStateIds.isNotEmpty : true) &&
        vm.acceptTerms;

    return PopScope(
      // Block back navigation (gesture, button, hardware back) while an upload
      // is in flight so the user can't abandon it half-way.
      canPop: !vm.isUploading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && vm.isUploading) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  widget.prefillNews != null
                      ? 'Please wait — still saving your changes…'
                      : 'Please wait — your news is still uploading…',
                ),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
        }
      },
      child: Stack(
        children: [
          SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Scaffold(
              backgroundColor: theme.appBackground,
              appBar: _buildAppBar(theme),
              body: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMediaCard(vm, theme),
                          const SizedBox(height: 16),
                          _buildStoryDetailsCard(vm, theme),
                          if (_permissions.showTopics) ...[
                            const SizedBox(height: 16),
                            _buildTopicsCard(vm, topicViewModel.topics, theme),
                          ],
                          if (_permissions.showLocations) ...[
                            const SizedBox(height: 16),
                            _buildLocationCard(vm, theme),
                          ],
                          if (_permissions.showTopics) ...[
                            const SizedBox(height: 12),
                            _buildImportantCheckbox(vm, theme),
                            const SizedBox(height: 8),
                            _buildCommentCheckbox(vm, theme),
                            const SizedBox(height: 8),
                            _buildShowProfileCheckbox(vm, theme),
                          ],
                          if (_publishesDirectly) ...[
                            const SizedBox(height: 12),
                            _buildNotificationChoice(theme),
                            const SizedBox(height: 16),
                            _buildAdsCard(vm, theme),
                          ],
                          const SizedBox(height: 16),
                          _buildTermsRow(vm, theme),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  _buildSendButton(vm, isFormValid, theme),
                ],
              ),
            ),
          ),
          // Engaging loader overlay shown while the upload is in flight. It
          // sits above the whole screen (incl. the app bar) and blocks input.
          if (vm.isUploading)
            Positioned.fill(
              child: _UploadingOverlay(isEdit: widget.prefillNews != null),
            ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.appBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: theme.appTextPrimary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.prefillNews != null ? 'Edit News' : 'Upload News',
        style: TextStyle(
          fontSize: scaledFontSize(18),
          fontWeight: FontWeight.w700,
          color: theme.appTextPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.5, color: theme.appDivider),
      ),
    );
  }

  // ── Section card wrapper ────────────────────────────────────────────────────
  // ── Advertisements ──────────────────────────────────────────────────────────
  /// Two optional sponsor slots, sent as `ad_1` / `ad_2`.
  ///
  /// Deliberately its own card, below the story and marked "optional": an
  /// advert is commercial inventory, not part of the article, and keeping it
  /// visually separate here mirrors how it reads to the user later — a labelled
  /// block, never mixed into the story's own media carousel.
  Widget _buildAdsCard(NewsUploadViewModel vm, ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            Icons.campaign_outlined,
            'Advertisements',
            trailing: Text(
              'Optional',
              style: TextStyle(
                fontSize: scaledFontSize(12),
                color: theme.appTextLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Up to two sponsor creatives. They appear inside the article, '
            'clearly marked "Ad" — never as part of the news media.',
            style: TextStyle(
              fontSize: scaledFontSize(12),
              color: theme.appTextSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _buildAdSlot(vm, theme, slot: 1),
          const SizedBox(height: 10),
          _buildAdSlot(vm, theme, slot: 2),
        ],
      ),
    );
  }

  Widget _buildAdSlot(
    NewsUploadViewModel vm,
    ThemeData theme, {
    required int slot,
  }) {
    final file = slot == 1 ? vm.ad1 : vm.ad2;
    final notifier = ref.read(newsUploadViewModelProvider.notifier);

    if (file == null) {
      return InkWell(
        onTap: () => _pickAd(slot),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.appDivider),
            color: theme.appGrey100,
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 20,
                color: theme.appTextLight,
              ),
              const SizedBox(width: 10),
              Text(
                'Add ad $slot  ·  image or video',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: theme.appTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isVideo = _isVideoPath(file.path);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.appPrimary.withValues(alpha: 0.4)),
        color: theme.appPrimary.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 54,
              height: 54,
              child: isVideo
                  ? Container(
                      color: Colors.black12,
                      child: Icon(
                        Icons.videocam_rounded,
                        color: theme.appPrimary,
                      ),
                    )
                  : Image.file(file, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ad $slot',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    fontWeight: FontWeight.w700,
                    color: theme.appTextPrimary,
                  ),
                ),
                Text(
                  isVideo ? 'Video' : 'Image',
                  style: TextStyle(
                    fontSize: scaledFontSize(12),
                    color: theme.appTextLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Replace',
            onPressed: () => _pickAd(slot),
            icon: Icon(
              Icons.swap_horiz_rounded,
              size: 20,
              color: theme.appPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => notifier.setAd(slot, null),
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.red),
          ),
        ],
      ),
    );
  }

  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm');
  }

  /// Asks whether this slot is an image or a video, then picks one.
  Future<void> _pickAd(int slot) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Image'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final notifier = ref.read(newsUploadViewModelProvider.notifier);
    if (choice == 'video') {
      final video = await _mediaPickerService.pickVideo();
      if (video != null) notifier.setAd(slot, video);
      return;
    }

    // pickImages is multi-select; an ad slot holds exactly one, so take the
    // first and ignore the rest rather than silently dropping the slot.
    final images = await _mediaPickerService.pickImages();
    if (images.isNotEmpty) notifier.setAd(slot, images.first);
  }

  Widget _buildCard({required Widget child}) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.appCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? Colors.black.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String title, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kAccentLight.withValues(
              alpha: theme.brightness == Brightness.light ? 1.0 : 0.15,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _kAccent, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: scaledFontSize(15),
            fontWeight: FontWeight.w700,
            color: theme.appTextPrimary,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  // ── Media card ──────────────────────────────────────────────────────────────
  Widget _buildMediaCard(NewsUploadViewModel vm, ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(theme, Icons.perm_media_rounded, 'Media'),
          const SizedBox(height: 14),
          if (vm.selectedMedia.isEmpty && vm.existingMedia.isEmpty)
            _buildMediaPlaceholder(theme)
          else
            _buildMediaGrid(vm, theme),
          if (vm.selectedMedia.isNotEmpty || vm.existingMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _showMediaPicker,
              icon: const Icon(
                Icons.add_circle_outline,
                size: 16,
                color: _kAccent,
              ),
              label: Text(
                'Add more',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder(ThemeData theme) {
    return InkWell(
      onTap: _showMediaPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.appGrey50,
          border: Border.all(color: theme.appGrey200, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kAccentLight.withValues(
                  alpha: theme.brightness == Brightness.light ? 1.0 : 0.15,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 28,
                color: _kAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to add Photos, Video or Audio',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                fontWeight: FontWeight.w500,
                color: theme.appTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Supports JPG, PNG, MP4, MP3',
              style: TextStyle(
                fontSize: scaledFontSize(11),
                color: theme.appTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(NewsUploadViewModel vm, ThemeData theme) {
    final existingCount = vm.existingMedia.length;
    final totalCount = existingCount + vm.selectedMedia.length;

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Existing network media first, then local files
          if (index < existingCount) {
            final media = vm.existingMedia[index];
            final isImage = media.type == 'image';
            final isVideo = media.type == 'video';

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    height: 110,
                    child: isImage
                        ? CachedImageWidget(
                            imageUrl: media.fileUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: theme.appGrey100,
                            child: Icon(
                              isVideo
                                  ? Icons.video_file_rounded
                                  : Icons.audio_file_rounded,
                              size: 40,
                              color: theme.appGrey400,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => ref
                        .read(newsUploadViewModelProvider.notifier)
                        .removeExistingMedia(index),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Local file media
          final fileIndex = index - existingCount;
          final file = vm.selectedMedia[fileIndex];
          final pathLower = file.path.toLowerCase();
          final ext = pathLower.contains('.') ? pathLower.split('.').last : '';
          const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'wmv', 'webm'];
          const audioExts = ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'opus'];
          final isVideo = videoExts.contains(ext);
          final isAudio = audioExts.contains(ext);
          // Default to image if not a known video/audio extension
          // (handles image_picker cache files with no extension)
          final isImage = !isVideo && !isAudio;

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 110,
                  child: isImage
                      ? Image.file(file, fit: BoxFit.cover)
                      : isVideo
                      ? _VideoThumbnail(file: file, theme: theme)
                      : Container(
                          color: theme.appGrey100,
                          child: Icon(
                            Icons.audio_file_rounded,
                            size: 40,
                            color: theme.appGrey400,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => ref
                      .read(newsUploadViewModelProvider.notifier)
                      .removeMedia(fileIndex),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Reusable color picker row ───────────────────────────────────────────────
  /// A labelled row of color swatches (Default + curated + custom picker).
  /// The chosen color is applied directly to the matching text field — there's
  /// no separate preview line. Used for both the title and the description.
  Widget _buildColorPickerRow({
    required ThemeData theme,
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final selected = colorFromHex(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(theme, label),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Default (theme color) — clears the custom color.
              _buildColorDot(
                theme: theme,
                color: theme.appTextPrimary,
                isSelected: value == null,
                onTap: () => onChanged(null),
                label: 'Aa',
              ),
              ..._kTitleColorSwatches.map(
                (c) => _buildColorDot(
                  theme: theme,
                  color: c,
                  isSelected:
                      selected != null && selected.toARGB32() == c.toARGB32(),
                  onTap: () => onChanged(hexFromColor(c)),
                ),
              ),
              // Full visual picker — covers "any color".
              _buildCustomColorDot(
                theme,
                onTap: () => _openCustomColorDialog(value, onChanged),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorDot({
    required ThemeData theme,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    String? label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? _kAccent : theme.appGrey300,
              width: isSelected ? 3 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    color:
                        ThemeData.estimateBrightnessForColor(color) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    fontSize: scaledFontSize(13),
                    fontWeight: FontWeight.w800,
                  ),
                )
              : (isSelected
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color:
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : null),
        ),
      ),
    );
  }

  Widget _buildCustomColorDot(ThemeData theme, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.appGrey300),
          gradient: const SweepGradient(
            colors: [
              Color(0xFFE0245E),
              Color(0xFFF59E0B),
              Color(0xFF16A34A),
              Color(0xFF0EA5E9),
              Color(0xFF7C3AED),
              Color(0xFFE0245E),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
      ),
    );
  }

  Future<void> _openCustomColorDialog(
    String? current,
    ValueChanged<String?> onChanged,
  ) async {
    // Full visual picker — wheel + saturation/value area + RGB sliders — so the
    // author can pick ANY color, not just type a hex code.
    Color picked = colorFromHex(current) ?? _kAccent;
    final hex = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          title: const Text('Pick title color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: picked,
              onColorChanged: (c) => picked = c,
              enableAlpha: false,
              displayThumbColor: true,
              portraitOnly: true,
              pickerAreaHeightPercent: 0.7,
              labelTypes: const [],
              hexInputBar: true, // still lets them paste a hex if they want
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, hexFromColor(picked)),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (hex != null && mounted) {
      onChanged(hex);
    }
  }

  // ── Story details card ──────────────────────────────────────────────────────
  Widget _buildStoryDetailsCard(NewsUploadViewModel vm, ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(theme, Icons.article_rounded, 'Story Details'),
          const SizedBox(height: 14),

          // Headline
          _buildFieldLabel(
            theme,
            'Headline',
            trailing: Text(
              '${_headlineController.text.length}/100',
              style: TextStyle(
                fontSize: scaledFontSize(12),
                color: theme.appTextLight,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _headlineController,
            theme: theme,
            hint: 'Enter your headline...',
            maxLines: 2,
            // 100, not 150 — the backend's title column caps there, so a longer
            // headline was accepted by the form and then rejected on upload.
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            textColor: colorFromHex(_titleColor),
          ),
          const SizedBox(height: 14),

          // Title color picker
          _buildColorPickerRow(
            theme: theme,
            label: 'Title Color',
            value: _titleColor,
            onChanged: (hex) => setState(() => _titleColor = hex),
          ),
          const SizedBox(height: 14),

          // Description
          _buildFieldLabel(
            theme,
            'Description',
            trailing: Text(
              '${_descriptionController.text.length}/500',
              style: TextStyle(
                fontSize: scaledFontSize(12),
                color: theme.appTextLight,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _descriptionController,
            theme: theme,
            hint: 'Write a short description...',
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            textColor: colorFromHex(_descriptionColor),
          ),
          const SizedBox(height: 14),

          // Description color picker
          _buildColorPickerRow(
            theme: theme,
            label: 'Description Color',
            value: _descriptionColor,
            onChanged: (hex) => setState(() => _descriptionColor = hex),
          ),
          const SizedBox(height: 14),

          // More content toggle
          InkWell(
            onTap: () => ref
                .read(newsUploadViewModelProvider.notifier)
                .setIsMoreChecked(!(vm.isMoreChecked ?? false)),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: vm.isMoreChecked ?? false,
                    onChanged: (v) => ref
                        .read(newsUploadViewModelProvider.notifier)
                        .setIsMoreChecked(v),
                    activeColor: _kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add full article content',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    fontWeight: FontWeight.w600,
                    color: theme.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (vm.isMoreChecked == true) ...[
            const SizedBox(height: 10),
            _buildTextField(
              controller: _moreController,
              theme: theme,
              hint: 'Write the full article...',
              maxLines: 6,
              textColor: colorFromHex(_fullTextColor),
            ),
            const SizedBox(height: 14),

            // Full article color picker
            _buildColorPickerRow(
              theme: theme,
              label: 'Full Article Color',
              value: _fullTextColor,
              onChanged: (hex) => setState(() => _fullTextColor = hex),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: scaledFontSize(13),
            fontWeight: FontWeight.w600,
            color: theme.appTextSecondary,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required ThemeData theme,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    void Function(String)? onChanged,
    Color? textColor,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: scaledFontSize(14),
        // Show the chosen color live in the field itself (no separate preview).
        color: textColor ?? theme.appTextPrimary,
        fontWeight: textColor != null ? FontWeight.w700 : FontWeight.normal,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.appTextLight,
          fontSize: scaledFontSize(14),
        ),
        counterText: '',
        filled: true,
        fillColor: theme.appGrey50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.appGrey300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.appGrey300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAccent, width: 1.5),
        ),
      ),
    );
  }

  // ── Topics card ─────────────────────────────────────────────────────────────
  Widget _buildTopicsCard(
    NewsUploadViewModel vm,
    List<Topic> topics,
    ThemeData theme,
  ) {
    // For dist-reporters: only show "Your Area" topic
    final availableTopics = _permissions.limitTopicToYourArea
        ? topics
              .where(
                (t) =>
                    t.name.toLowerCase() == 'your area' ||
                    (t.slug?.toLowerCase() ?? '') == 'your-area',
              )
              .toList()
        : topics;

    final count = vm.selectedCategories.length;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            Icons.tag_rounded,
            'Topics',
            trailing: count > 0 ? _buildCountBadge(count) : null,
          ),
          if (vm.selectedCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: vm.selectedCategories
                  .map(
                    (t) => _buildSelectedChip(
                      theme,
                      t.name,
                      onRemove: _permissions.limitTopicToYourArea
                          ? null // Can't remove the only allowed topic
                          : () => ref
                                .read(newsUploadViewModelProvider.notifier)
                                .toggleCategory(t),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (!_permissions.limitTopicToYourArea) ...[
            const SizedBox(height: 12),
            _MultiSelectList<Topic>(
              key: const ValueKey('topics'),
              items: availableTopics,
              selectedIds: vm.selectedCategories.map((t) => t.id).toList(),
              getName: (t) => t.name,
              getId: (t) => t.id,
              onToggle: (t) async => ref
                  .read(newsUploadViewModelProvider.notifier)
                  .toggleCategory(t),
              searchHint: 'Search topics...',
              emptyText: 'No topics available',
              theme: theme,
            ),
          ] else if (vm.selectedCategories.isEmpty) ...[
            const SizedBox(height: 10),
            _buildLockedLocationInfo(
              theme,
              '"Your Area" will be auto-assigned',
            ),
          ],
        ],
      ),
    );
  }

  // ── Location card ───────────────────────────────────────────────────────────
  Widget _buildLocationCard(NewsUploadViewModel vm, ThemeData theme) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            Icons.location_on_rounded,
            'Location',
            trailing:
                (vm.selectedStateIds.isNotEmpty ||
                    vm.selectedDistrictIds.isNotEmpty ||
                    vm.selectedMandalIds.isNotEmpty)
                ? _buildCountBadge(
                    vm.selectedStateIds.length +
                        vm.selectedDistrictIds.length +
                        vm.selectedMandalIds.length,
                  )
                : null,
          ),
          const SizedBox(height: 14),

          // States
          _buildLocationRow(
            theme,
            'States',
            vm.selectedStates.map((s) => s.name).toList(),
            totalAvailable: vm.availableStates.length,
          ),
          const SizedBox(height: 8),
          if (_permissions.canSelectStates)
            _buildLocationSelector<location_models.State>(
              key: const ValueKey('states'),
              theme: theme,
              icon: Icons.map_rounded,
              title: 'Select States',
              items: vm.availableStates,
              selectedIds: vm.selectedStateIds,
              isLoading: vm.isLoadingStates,
              error: vm.statesError,
              onRetry: () => ref
                  .read(newsUploadViewModelProvider.notifier)
                  .retryLoadStates(),
              onToggle: (s) =>
                  ref.read(newsUploadViewModelProvider.notifier).toggleState(s),
              getName: (s) => s.name,
              getId: (s) => s.id,
              searchHint: 'Search states...',
              disabledMessage: null,
            )
          else
            _buildLockedLocationInfo(theme, 'State assigned by admin'),

          // Districts
          if (vm.selectedStateIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildLocationRow(
              theme,
              'Districts',
              vm.selectedDistricts.map((d) => d.name).toList(),
              totalAvailable: vm.availableDistricts.length,
            ),
            const SizedBox(height: 8),
            if (_permissions.canSelectDistricts) ...[
              _buildSelectAllButton(
                theme: theme,
                label: 'Select All Districts',
                isAllSelected:
                    vm.availableDistricts.isNotEmpty &&
                    vm.availableDistricts.every(
                      (d) => vm.selectedDistrictIds.contains(d.id),
                    ),
                onPressed: () {
                  final notifier = ref.read(
                    newsUploadViewModelProvider.notifier,
                  );
                  final allSelected = vm.availableDistricts.every(
                    (d) => vm.selectedDistrictIds.contains(d.id),
                  );
                  if (allSelected) {
                    notifier.deselectAllDistricts(vm.availableDistricts);
                  } else {
                    notifier.selectAllDistricts(vm.availableDistricts);
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildLocationSelector<District>(
                key: const ValueKey('districts'),
                theme: theme,
                icon: Icons.location_city_rounded,
                title: 'Select Districts',
                items: vm.availableDistricts,
                selectedIds: vm.selectedDistrictIds,
                isLoading: vm.isLoadingAnyDistricts,
                error: null,
                onRetry: null,
                onToggle: (d) => ref
                    .read(newsUploadViewModelProvider.notifier)
                    .toggleDistrict(d),
                getName: (d) => d.name,
                getId: (d) => d.id,
                searchHint: 'Search districts...',
                disabledMessage: null,
              ),
            ] else
              _buildLockedLocationInfo(theme, 'District assigned by admin'),
          ],

          // Mandals
          if (vm.selectedDistrictIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildLocationRow(
              theme,
              'Mandals',
              vm.selectedMandals.map((m) => m.name).toList(),
              totalAvailable: vm.availableMandals.length,
            ),
            const SizedBox(height: 8),
            if (_permissions.canSelectMandals) ...[
              _buildSelectAllButton(
                theme: theme,
                label: 'Select All Mandals',
                isAllSelected:
                    vm.availableMandals.isNotEmpty &&
                    vm.availableMandals.every(
                      (m) => vm.selectedMandalIds.contains(m.id),
                    ),
                onPressed: () {
                  final notifier = ref.read(
                    newsUploadViewModelProvider.notifier,
                  );
                  final allSelected = vm.availableMandals.every(
                    (m) => vm.selectedMandalIds.contains(m.id),
                  );
                  for (final m in vm.availableMandals) {
                    if (allSelected && vm.selectedMandalIds.contains(m.id)) {
                      notifier.toggleMandal(m);
                    } else if (!allSelected &&
                        !vm.selectedMandalIds.contains(m.id)) {
                      notifier.toggleMandal(m);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildLocationSelector<Mandal>(
                key: const ValueKey('mandals'),
                theme: theme,
                icon: Icons.holiday_village_rounded,
                title: 'Select Mandals',
                items: vm.availableMandals,
                selectedIds: vm.selectedMandalIds,
                isLoading: vm.isLoadingAnyMandals,
                error: null,
                onRetry: null,
                onToggle: (m) async => ref
                    .read(newsUploadViewModelProvider.notifier)
                    .toggleMandal(m),
                getName: (m) => m.name,
                getId: (m) => m.id,
                searchHint: 'Search mandals...',
                disabledMessage: null,
              ),
            ] else
              _buildLockedLocationInfo(theme, 'Mandal assigned by admin'),
          ],
        ],
      ),
    );
  }

  Widget _buildLockedLocationInfo(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.appGrey100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: theme.appTextLight),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: scaledFontSize(12),
              color: theme.appTextLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllButton({
    required ThemeData theme,
    required String label,
    required bool isAllSelected,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAllSelected ? _kAccentLight : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAllSelected ? _kAccent : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAllSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: isAllSelected ? _kAccent : theme.appTextLight,
            ),
            const SizedBox(width: 8),
            Text(
              isAllSelected ? 'Deselect All' : label,
              style: TextStyle(
                fontSize: scaledFontSize(12),
                fontWeight: FontWeight.w600,
                color: isAllSelected ? _kAccent : theme.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
    ThemeData theme,
    String label,
    List<String> names, {
    int? totalAvailable,
  }) {
    // When the user has selected every available option (e.g. tapped
    // "Select All Mandals"), suppress the long chip list — the Select All
    // button itself already signals that state. The summary row only adds
    // value when there's a manual, partial selection worth reviewing.
    final allSelected =
        totalAvailable != null &&
        totalAvailable > 0 &&
        names.length >= totalAvailable;
    if (allSelected) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: scaledFontSize(13),
            fontWeight: FontWeight.w600,
            color: theme.appTextSecondary,
          ),
        ),
        Expanded(
          child: names.isEmpty
              ? Text(
                  'None selected',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    color: theme.appTextLight,
                  ),
                )
              : Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: names.map((n) => _buildInfoChip(theme, n)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildLocationSelector<T>({
    required Key key,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required List<T> items,
    required List<int> selectedIds,
    required bool isLoading,
    required String? error,
    required VoidCallback? onRetry,
    required Future<void> Function(T) onToggle,
    required String Function(T) getName,
    required int Function(T) getId,
    required String searchHint,
    required String? disabledMessage,
  }) {
    return _MultiSelectList<T>(
      key: key,
      items: items,
      selectedIds: selectedIds,
      getName: getName,
      getId: getId,
      onToggle: onToggle,
      searchHint: searchHint,
      emptyText: isLoading
          ? ''
          : (error != null ? 'Failed to load' : 'No items'),
      theme: theme,
      isLoading: isLoading,
      error: error,
      onRetry: onRetry,
      leadingIcon: icon,
      selectorTitle: title,
    );
  }

  bool _isImportant = false;
  bool _isComment = true;
  bool _showProfile = true;

  /// Whether publishing should push a notification to readers. Sent to the
  /// backend as `is_send_notification`; the backend fires the push when the
  /// article goes live. Defaults to true.
  bool _isSendNotification = true;

  /// True for the roles whose uploads publish immediately. Only they get the
  /// notification choice — a reporter's upload sits in `pending` and can't
  /// notify anyone until an editor approves it.
  bool get _publishesDirectly {
    final role = ref.read(authViewModelProvider).user?.primaryRole.value;
    return role == 'admin' || role == 'sub_admin' || role == 'dist-reporter';
  }

  Widget _buildNotificationChoice(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: theme.appPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Push notification',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildRadioOption(
                  theme,
                  label: 'With notification',
                  selected: _isSendNotification,
                  onTap: () => setState(() => _isSendNotification = true),
                ),
              ),
              Expanded(
                child: _buildRadioOption(
                  theme,
                  label: 'Without notification',
                  selected: !_isSendNotification,
                  onTap: () => setState(() => _isSendNotification = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(
    ThemeData theme, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? theme.appPrimary : const Color(0xFFCCCCCC),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: selected
                      ? const Color(0xFF333333)
                      : const Color(0xFF999999),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportantCheckbox(NewsUploadViewModel vm, ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _isImportant = !_isImportant),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _isImportant,
                onChanged: (v) => setState(() => _isImportant = v ?? false),
                activeColor: const Color(0xFFE8A000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.star_rounded,
              size: 18,
              color: _isImportant
                  ? const Color(0xFFE8A000)
                  : const Color(0xFFCCCCCC),
            ),
            const SizedBox(width: 6),
            Text(
              'Mark as Important News',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: _isImportant
                    ? const Color(0xFF333333)
                    : const Color(0xFF999999),
                fontWeight: _isImportant ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCheckbox(NewsUploadViewModel vm, ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _isComment = !_isComment),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _isComment,
                onChanged: (v) => setState(() => _isComment = v ?? true),
                activeColor: _kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.comment_outlined,
              size: 18,
              color: _isComment ? _kAccent : const Color(0xFFCCCCCC),
            ),
            const SizedBox(width: 6),
            Text(
              'Allow Comments',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: _isComment
                    ? const Color(0xFF333333)
                    : const Color(0xFF999999),
                fontWeight: _isComment ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowProfileCheckbox(NewsUploadViewModel vm, ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _showProfile = !_showProfile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _showProfile,
                onChanged: (v) => setState(() => _showProfile = v ?? true),
                activeColor: _kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.person_outline,
              size: 18,
              color: _showProfile ? _kAccent : const Color(0xFFCCCCCC),
            ),
            const SizedBox(width: 6),
            Text(
              'Show Author Profile',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: _showProfile
                    ? const Color(0xFF333333)
                    : const Color(0xFF999999),
                fontWeight: _showProfile ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Terms row ───────────────────────────────────────────────────────────────
  Widget _buildTermsRow(NewsUploadViewModel vm, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => ref
            .read(newsUploadViewModelProvider.notifier)
            .setAcceptTerms(!vm.acceptTerms),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: vm.acceptTerms,
                  onChanged: (v) => ref
                      .read(newsUploadViewModelProvider.notifier)
                      .setAcceptTerms(v ?? false),
                  activeColor: _kAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'I accept the ',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: theme.appTextSecondary,
                ),
              ),
              Text(
                'terms and conditions',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: _kAccent,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: _kAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Send button ─────────────────────────────────────────────────────────────
  Widget _buildSendButton(
    NewsUploadViewModel vm,
    bool isFormValid,
    ThemeData theme,
  ) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isFormValid && !vm.isUploading ? _handleSendNews : null,
            icon: vm.isUploading
                ? const SizedBox.shrink()
                : const Icon(Icons.send_rounded, size: 18),
            label: vm.isUploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Publish Story',
                    style: TextStyle(
                      fontSize: scaledFontSize(15),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              disabledBackgroundColor: theme.appGrey300,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white60,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared chip widgets ─────────────────────────────────────────────────────
  Widget _buildSelectedChip(
    ThemeData theme,
    String label, {
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kAccentLight.withValues(
          alpha: theme.brightness == Brightness.light ? 1.0 : 0.15,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: scaledFontSize(12),
              color: _kAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 14, color: _kAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccentLight.withValues(
          alpha: theme.brightness == Brightness.light ? 1.0 : 0.15,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: scaledFontSize(11),
          color: _kAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: scaledFontSize(12),
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Media picker ────────────────────────────────────────────────────────────
  void _showMediaPicker() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.appGrey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Add Media',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w700,
                  color: theme.appTextPrimary,
                ),
              ),
            ),
            _buildMediaOption(
              theme,
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Choose Photos',
              subtitle: 'Select from gallery',
              onTap: () {
                Navigator.pop(context);
                _pickPhotos();
              },
            ),
            _buildMediaOption(
              theme,
              icon: Icons.video_library_rounded,
              color: const Color(0xFFEC4899),
              title: 'Choose Video',
              subtitle: 'Select a video clip',
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            _buildMediaOption(
              theme,
              icon: Icons.audio_file_rounded,
              color: const Color(0xFFF59E0B),
              title: 'Choose Audio',
              subtitle: 'Select an audio file',
              onTap: () {
                Navigator.pop(context);
                _pickAudio();
              },
            ),
            _buildMediaOption(
              theme,
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF0EA5E9),
              title: 'Take Photo',
              subtitle: 'Use your camera',
              onTap: () {
                Navigator.pop(context);
                _pickMediaFromCamera();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaOption(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.appTextPrimary,
          fontWeight: FontWeight.w600,
          fontSize: scaledFontSize(14),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: theme.appTextLight,
          fontSize: scaledFontSize(12),
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickPhotos() async {
    try {
      final images = await _mediaPickerService.pickImages();
      if (images.isNotEmpty) {
        ref.read(newsUploadViewModelProvider.notifier).addMultipleMedia(images);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _mediaPickerService.pickVideo();
      if (video != null) {
        ref.read(newsUploadViewModelProvider.notifier).addMedia(video);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      final audio = await _mediaPickerService.pickAudio();
      if (audio != null) {
        ref.read(newsUploadViewModelProvider.notifier).addMedia(audio);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _pickMediaFromCamera() async {
    try {
      final photo = await _mediaPickerService.capturePhoto();
      if (photo != null) {
        ref.read(newsUploadViewModelProvider.notifier).addMedia(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _handleSendNews() async {
    final vm = ref.read(newsUploadViewModelProvider);
    final notifier = ref.read(newsUploadViewModelProvider.notifier);

    // For dist-reporters: ensure "Your Area" topic is selected before uploading
    if (_permissions.limitTopicToYourArea &&
        notifier.selectedCategories.isEmpty) {
      _autoSelectYourAreaTopic(notifier);
    }

    final user = ref.read(authViewModelProvider).user;
    final role = user?.primaryRole.value ?? 'reader';

    // For reader/reporter: ensure all locations are set from their assigned location
    if (!_permissions.showLocations && user != null) {
      if (notifier.selectedStateIds.isEmpty ||
          notifier.selectedDistrictIds.isEmpty ||
          notifier.selectedMandalIds.isEmpty) {
        await _autoSelectUserLocations(notifier, user, role);
      }
    }

    // Admin, sub_admin, dist-reporter publish directly; others go to pending
    final uploadStatus =
        (role == 'admin' || role == 'sub_admin' || role == 'dist-reporter')
        ? 'published'
        : 'pending';

    final success = await vm.uploadNews(
      headline: _headlineController.text,
      description: _descriptionController.text,
      content: _moreController.text,
      categories: notifier.selectedCategories,
      mediaFiles: notifier.selectedMedia,
      editNewsId: widget.prefillNews?.id,
      status: uploadStatus,
      skipLocationValidation: !_permissions.showLocations,
      isImportant: _isImportant,
      isComment: _isComment,
      showProfile: _showProfile,
      // Pending uploads can't notify anyone until approved, so the flag only
      // carries the user's choice on the roles that publish straight away.
      isSendNotification: _publishesDirectly ? _isSendNotification : true,
      titleColor: _titleColor,
      descriptionColor: _descriptionColor,
      fullTextColor: _fullTextColor,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.prefillNews != null
                ? 'News updated successfully!'
                : 'News uploaded successfully!',
          ),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      ref.read(homeViewModelProvider.notifier).loadNewsData();

      // DISABLED 2026-08-01 at backend's request — they are moving the push
      // trigger server-side (fires automatically when status becomes
      // `published`), so the app must not call /api/send-notification.
      // Kept, not deleted: re-enable only if that plan is dropped.
      //
      // Pending uploads (reporter/reader) were skipped because they
      // shouldn't notify anyone until an editor approves them.
      //
      // if (uploadStatus == 'published') {
      //   unawaited(_fireNewsPushNotification(notifier));
      // } else {
      //   debugPrint(
      //     '[NewsUpload] Skipping notification — status=$uploadStatus '
      //     '(pending uploads do not push until approved)',
      //   );
      // }

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Failed to upload news'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  /// scoping, etc.) on their side — we just hand them the news context.
  ///
  /// Currently unused — the call site in [_handleSendNews] is commented out
  /// because the backend now owns the publish trigger.
  // ignore: unused_element
  Future<void> _fireNewsPushNotification(NewsUploadViewModel notifier) async {
    final title = _headlineController.text.trim();
    final body = _descriptionController.text.trim();
    final user = ref.read(authViewModelProvider).user;

    debugPrint('═════════════════════════════════════════════════════');
    debugPrint('[NewsUpload] 🔔 Firing push notification trigger');
    debugPrint('[NewsUpload]   title       = $title');
    debugPrint('[NewsUpload]   body length = ${body.length}');
    debugPrint(
      '[NewsUpload]   uploader    = ${user?.name} '
      '(role=${user?.primaryRole.value}, id=${user?.id})',
    );
    final newsId = notifier.lastUploadedNewsId;

    debugPrint('[NewsUpload]   news_id     = $newsId');
    debugPrint('[NewsUpload]   state_ids   = ${notifier.selectedStateIds}');
    debugPrint('[NewsUpload]   district_ids= ${notifier.selectedDistrictIds}');
    debugPrint('[NewsUpload]   mandal_ids  = ${notifier.selectedMandalIds}');
    debugPrint('[NewsUpload]   target      = all');
    debugPrint('═════════════════════════════════════════════════════');

    try {
      final result = await NotificationRepositoryImpl().sendNotification(
        title: title.isEmpty ? 'New News Posted' : title,
        body: body.isEmpty ? 'Check out the latest update' : body,
        target: NotificationTarget.all,
        // Audience filters — top level, not inside `data`.
        stateIds: notifier.selectedStateIds,
        districtIds: notifier.selectedDistrictIds,
        mandalIds: notifier.selectedMandalIds,
        data: {
          'type': 'news_published',
          // Omitted when the create response carried no parsable id — better
          // a push with no deeplink than one that opens news id "null".
          if (newsId != null) 'news_id': newsId.toString(),
        },
      );

      if (result == null) {
        debugPrint(
          '[NewsUpload] ❌ sendNotification returned null '
          '(likely 4xx/5xx from backend — check API logs)',
        );
      } else {
        debugPrint(
          '[NewsUpload] ✅ sendNotification result: '
          'success=${result.successCount}, '
          'failure=${result.failureCount}',
        );
      }
    } catch (e, st) {
      // Never let a notification error rollback the upload UX.
      debugPrint('[NewsUpload] ❌ sendNotification threw: $e\n$st');
    }
    debugPrint('═════════════════════════════════════════════════════');
  }
}

// ── Generic multi-select list widget ─────────────────────────────────────────
class _MultiSelectList<T> extends StatefulWidget {
  const _MultiSelectList({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.getName,
    required this.getId,
    required this.onToggle,
    required this.searchHint,
    required this.emptyText,
    required this.theme,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.leadingIcon,
    this.selectorTitle,
  });

  final List<T> items;
  final List<int> selectedIds;
  final String Function(T) getName;
  final int Function(T) getId;
  final Future<void> Function(T) onToggle;
  final String searchHint;
  final String emptyText;
  final ThemeData theme;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final IconData? leadingIcon;
  final String? selectorTitle;

  @override
  State<_MultiSelectList<T>> createState() => _MultiSelectListState<T>();
}

class _MultiSelectListState<T> extends State<_MultiSelectList<T>> {
  bool _expanded = false;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final filtered = widget.items
        .where(
          (item) => widget
              .getName(item)
              .toLowerCase()
              .contains(_search.toLowerCase()),
        )
        .toList();
    final selectedCount = widget.selectedIds.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: theme.appGrey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? _kAccent.withValues(alpha: 0.3) : theme.appGrey200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / toggle row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  if (widget.leadingIcon != null)
                    Icon(
                      widget.leadingIcon,
                      size: 17,
                      color: selectedCount > 0
                          ? _kAccent
                          : theme.appTextSecondary,
                    ),
                  if (widget.leadingIcon != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.selectorTitle ?? widget.searchHint,
                      style: TextStyle(
                        fontSize: scaledFontSize(13),
                        fontWeight: FontWeight.w600,
                        color: selectedCount > 0
                            ? _kAccent
                            : theme.appTextSecondary,
                      ),
                    ),
                  ),
                  if (widget.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                      ),
                    )
                  else ...[
                    if (selectedCount > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _kAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$selectedCount',
                          style: TextStyle(
                            fontSize: scaledFontSize(11),
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: theme.appTextSecondary,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            Divider(height: 1, color: theme.appDivider),

            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: theme.appTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(
                    color: theme.appTextLight,
                    fontSize: scaledFontSize(13),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: theme.appTextSecondary,
                  ),
                  filled: true,
                  fillColor: theme.appBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.appGrey300, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.appGrey300, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kAccent, width: 1.5),
                  ),
                  isDense: true,
                ),
              ),
            ),

            // Error state
            if (widget.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Failed to load data',
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    if (widget.onRetry != null)
                      TextButton(
                        onPressed: widget.onRetry,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(60, 30),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            color: _kAccent,
                            fontSize: scaledFontSize(13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            // Loading state
            else if (widget.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
                  ),
                ),
              )
            // Empty state
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    _search.isNotEmpty
                        ? 'No results for "$_search"'
                        : widget.emptyText,
                    style: TextStyle(
                      fontSize: scaledFontSize(13),
                      color: theme.appTextSecondary,
                    ),
                  ),
                ),
              )
            // Item list
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: filtered.length <= 4
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final id = widget.getId(item);
                    final name = widget.getName(item);
                    final isSelected = widget.selectedIds.contains(id);

                    return InkWell(
                      onTap: () => widget.onToggle(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => widget.onToggle(item),
                              activeColor: _kAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: scaledFontSize(13),
                                  color: isSelected
                                      ? _kAccent
                                      : theme.appTextPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: _kAccent,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _UploadingOverlay extends StatefulWidget {
  final bool isEdit;
  const _UploadingOverlay({required this.isEdit});

  @override
  State<_UploadingOverlay> createState() => _UploadingOverlayState();
}

class _UploadingOverlayState extends State<_UploadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;
  Timer? _msgTimer;
  int _msgIndex = 0;
  late final List<String> _messages;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _messages = widget.isEdit
        ? const [
            'Saving your changes…',
            'Updating the story…',
            'Polishing the details…',
            'Almost done…',
          ]
        : const [
            'Publishing your story…',
            'Uploading your media…',
            'Beaming it to your area…',
            'Reaching readers nearby…',
            'Almost there…',
          ];

    _msgTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Scrim that also swallows all taps so nothing behind it is reachable.
        const ModalBarrier(dismissible: false, color: Color(0xCC0B1220)),
        Center(
          // Material ancestor — required so the nested Text widgets get a
          // default text style. Without it Flutter renders that yellow
          // "no default style" underline you'd see on every line in the box.
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 290,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Spinning gradient ring with a pulsing upload icon inside.
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _spin,
                          child: CustomPaint(
                            size: const Size(92, 92),
                            painter: _RingPainter(),
                          ),
                        ),
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.85, end: 1.12).animate(
                            CurvedAnimation(
                              parent: _pulse,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: _kAccentLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_rounded,
                              color: _kAccent,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    widget.isEdit ? 'Updating…' : 'Uploading…',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0B1220),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Rotating status line, cross-fades between messages.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _messages[_msgIndex],
                      key: ValueKey<int>(_msgIndex),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _BouncingDots(),
                  const SizedBox(height: 16),
                  Text(
                    'Please keep this screen open',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Draws the faint base ring plus a sweep-gradient arc (the moving highlight).
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = _kAccent.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, base);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [_kAccent.withValues(alpha: 0.0), _kAccent],
      ).createShader(rect);
    // ~240° sweep so there's a visible gap that reads as motion when spun.
    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.35, false, arc);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Three dots that bounce in sequence — cheap, lively "still working" cue.
class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            // Stagger each dot's phase so they bounce one after another.
            final phase = (_c.value - i * 0.18) % 1.0;
            final lift = -7.0 * math.max(0.0, math.sin(phase * math.pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(offset: Offset(0, lift), child: child),
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _kAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

/// Renders a real video preview thumbnail inside the media grid. Uses
/// `VideoCompress.getFileThumbnail` (already a transitive dep via the
/// upload compression) so we don't pull in a separate `video_thumbnail`
/// package. Shows a spinner while the thumbnail extracts and a fallback
/// icon if extraction fails on a particularly weird codec.
class _VideoThumbnail extends StatefulWidget {
  final File file;
  final ThemeData theme;
  const _VideoThumbnail({required this.file, required this.theme});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  File? _thumb;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final thumb = await VideoCompress.getFileThumbnail(
        widget.file.path,
        quality: 50,
        position: -1, // let the plugin pick a good frame (default)
      );
      if (!mounted) return;
      setState(() => _thumb = thumb);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_thumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_thumb!, fit: BoxFit.cover),
          // Play icon overlay so the user can tell at a glance this is a video.
          Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      );
    }
    if (_failed) {
      return Container(
        color: theme.appGrey100,
        child: Icon(
          Icons.video_file_rounded,
          size: 40,
          color: theme.appGrey400,
        ),
      );
    }
    // Still extracting — show a subtle loader.
    return Container(
      color: theme.appGrey100,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: _kAccent),
      ),
    );
  }
}
