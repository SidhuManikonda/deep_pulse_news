import 'package:deep_pulse_news/data/models/district.dart';
import 'package:deep_pulse_news/data/models/mandal.dart';
import 'package:deep_pulse_news/data/models/state.dart' as location_models;
import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/features/home/home_view_model.dart';
import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/media_picker_services.dart';
import '../../data/models/news.dart';
import '../../data/models/user.dart';
import '../../extensions/user_extensions.dart';
import '../../shared/widgets/cached_image_widget.dart';
import 'news_upload_view_model.dart';
import '../../core/constants/app_font_sizes.dart';

// Clean accent color used throughout the form instead of the brand red
const _kAccent = Color(0xFF2563EB); // A calm, professional blue
const _kAccentLight = Color(0xFFDBEAFE); // Very light blue for backgrounds
const _kSuccess = Color(0xFF16A34A); // Green for the send button

/// Determines what the upload screen shows based on user role.
class UploadPermissions {
  final bool showTopics;
  final bool showLocations;
  final bool canSelectStates;
  final bool canSelectDistricts;
  final bool canSelectMandals;
  final bool limitTopicToYourArea; // dist-reporter can only pick "Your Area"

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
      case 'subadmin':
        return const UploadPermissions._(
          showTopics: true,
          showLocations: true,
          canSelectStates: false,
          canSelectDistricts: true,
          canSelectMandals: true,
          limitTopicToYourArea: false,
        );
      case 'dist-reporter':
        return const UploadPermissions._(
          showTopics: true,
          showLocations: true,
          canSelectStates: false,
          canSelectDistricts: false,
          canSelectMandals: true,
          limitTopicToYourArea: true,
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

class _NewsUploadScreenState extends ConsumerState<NewsUploadScreen> {
  final _headlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _moreController = TextEditingController();
  final _mediaPickerService = MediaPickerService();
  late final UploadPermissions _permissions;

  @override
  void initState() {
    super.initState();
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

    // All non-admin roles: auto-select their state (toggleState loads districts)
    if (user.stateId != null && !vm.selectedStateIds.contains(user.stateId)) {
      final state = vm.availableStates.where((s) => s.id == user.stateId).firstOrNull;
      if (state != null) await vm.toggleState(state);
    }

    // Auto-select their district (toggleDistrict loads mandals)
    if (user.districtId != null && !vm.selectedDistrictIds.contains(user.districtId)) {
      final district = vm.availableDistricts.where((d) => d.id == user.districtId).firstOrNull;
      if (district != null) await vm.toggleDistrict(district);
    }

    // Auto-select their mandal
    if (user.mandalId != null && !vm.selectedMandalIds.contains(user.mandalId)) {
      final mandal = vm.availableMandals.where((m) => m.id == user.mandalId).firstOrNull;
      if (mandal != null) vm.toggleMandal(mandal);
    }

    if (mounted) setState(() {});
  }

  /// For dist-reporters: auto-select "Your Area" topic.
  void _autoSelectYourAreaTopic(NewsUploadViewModel vm) {
    final topics = ref.read(topicViewModelProvider).topics;
    final yourArea = topics.where(
      (t) => t.name.toLowerCase() == 'your area' || (t.slug?.toLowerCase() ?? '') == 'your-area',
    ).firstOrNull;
    if (yourArea != null && !vm.selectedCategories.any((c) => c.id == yourArea.id)) {
      ref.read(newsUploadViewModelProvider.notifier).toggleCategory(yourArea);
    }
  }

  /// Prefill form from existing news (editing flow).
  Future<void> _prefillFromExistingNews(NewsUploadViewModel vm, News news) async {
    final translation = news.getPrimaryTranslation();
    if (translation != null) {
      _headlineController.text = translation.title;
      _descriptionController.text = translation.shortDescription;
      _moreController.text = translation.content;
    }

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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _descriptionController.dispose();
    _moreController.dispose();
    super.dispose();
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

    return SafeArea(
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
            color: _kAccentLight.withValues(alpha: theme.brightness == Brightness.light ? 1.0 : 0.15),
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
              icon: const Icon(Icons.add_circle_outline, size: 16, color: _kAccent),
              label:  Text(
                'Add more',
                style: TextStyle(color: _kAccent, fontSize: scaledFontSize(13), fontWeight: FontWeight.w600),
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
          border: Border.all(
            color: theme.appGrey200,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kAccentLight.withValues(alpha: theme.brightness == Brightness.light ? 1.0 : 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_photo_alternate_outlined, size: 28, color: _kAccent),
            ),
            const SizedBox(height: 10),
            Text(
              'Tap to add Photos, Video or Audio',
              style: TextStyle(fontSize: scaledFontSize(13), fontWeight: FontWeight.w500, color: theme.appTextSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Supports JPG, PNG, MP4, MP3',
              style: TextStyle(fontSize: scaledFontSize(11), color: theme.appTextLight),
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
          final isVideo = videoExts.contains(ext);
          // Default to image if not a known video extension
          // (handles image_picker cache files with no extension)
          final isImage = !isVideo;

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 110,
                  child: isImage
                      ? Image.file(file, fit: BoxFit.cover)
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
              style: TextStyle(fontSize: scaledFontSize(12), color: theme.appTextLight),
            ),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _headlineController,
            theme: theme,
            hint: 'Enter your headline...',
            maxLines: 2,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Description
          _buildFieldLabel(theme, 'Description'),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _descriptionController,
            theme: theme,
            hint: 'Write a short description...',
            maxLines: 4,
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
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: TextStyle(fontSize: scaledFontSize(14), color: theme.appTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.appTextLight, fontSize: scaledFontSize(14)),
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
        ? topics.where((t) =>
            t.name.toLowerCase() == 'your area' ||
            (t.slug?.toLowerCase() ?? '') == 'your-area').toList()
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
            _buildLockedLocationInfo(theme, '"Your Area" will be auto-assigned'),
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
            ),
            const SizedBox(height: 8),
            if (_permissions.canSelectDistricts) ...[
              _buildSelectAllButton(
                theme: theme,
                label: 'Select All Districts',
                isAllSelected: vm.availableDistricts.isNotEmpty &&
                    vm.availableDistricts.every((d) => vm.selectedDistrictIds.contains(d.id)),
                onPressed: () {
                  final notifier = ref.read(newsUploadViewModelProvider.notifier);
                  final allSelected = vm.availableDistricts.every(
                      (d) => vm.selectedDistrictIds.contains(d.id));
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
            ),
            const SizedBox(height: 8),
            if (_permissions.canSelectMandals) ...[
              _buildSelectAllButton(
                theme: theme,
                label: 'Select All Mandals',
                isAllSelected: vm.availableMandals.isNotEmpty &&
                    vm.availableMandals.every((m) => vm.selectedMandalIds.contains(m.id)),
                onPressed: () {
                  final notifier = ref.read(newsUploadViewModelProvider.notifier);
                  final allSelected = vm.availableMandals.every(
                      (m) => vm.selectedMandalIds.contains(m.id));
                  for (final m in vm.availableMandals) {
                    if (allSelected && vm.selectedMandalIds.contains(m.id)) {
                      notifier.toggleMandal(m);
                    } else if (!allSelected && !vm.selectedMandalIds.contains(m.id)) {
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

  Widget _buildLocationRow(ThemeData theme, String label, List<String> names) {
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
                  style: TextStyle(fontSize: scaledFontSize(13), color: theme.appTextLight),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.star_rounded, size: 18, color: _isImportant ? const Color(0xFFE8A000) : const Color(0xFFCCCCCC)),
            const SizedBox(width: 6),
            Text(
              'Mark as Important News',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: _isImportant ? const Color(0xFF333333) : const Color(0xFF999999),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.comment_outlined, size: 18, color: _isComment ? _kAccent : const Color(0xFFCCCCCC)),
            const SizedBox(width: 6),
            Text(
              'Allow Comments',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: _isComment ? const Color(0xFF333333) : const Color(0xFF999999),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.person_outline, size: 18, color: _showProfile ? _kAccent : const Color(0xFFCCCCCC)),
            const SizedBox(width: 6),
            Text(
              'Show Author Profile',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: _showProfile ? const Color(0xFF333333) : const Color(0xFF999999),
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
                style: TextStyle(fontSize: scaledFontSize(14), color: theme.appTextSecondary),
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
                :  Text(
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
        color: _kAccentLight.withValues(alpha: theme.brightness == Brightness.light ? 1.0 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style:  TextStyle(
              fontSize: scaledFontSize(12),
              color: _kAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: _kAccent,
              ),
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
        color: _kAccentLight.withValues(alpha: theme.brightness == Brightness.light ? 1.0 : 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:  TextStyle(
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
        style:  TextStyle(
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
        style: TextStyle(color: theme.appTextLight, fontSize: scaledFontSize(12)),
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
    if (_permissions.limitTopicToYourArea && notifier.selectedCategories.isEmpty) {
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
    final uploadStatus = (role == 'admin' || role == 'subadmin' || role == 'dist-reporter')
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
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.prefillNews != null
              ? 'News updated successfully!'
              : 'News uploaded successfully!'),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      ref.read(homeViewModelProvider.notifier).loadNewsData();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Failed to upload news'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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
          color: _expanded
              ? _kAccent.withValues(alpha: 0.3)
              : theme.appGrey200,
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
                          style:  TextStyle(
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
                style: TextStyle(fontSize: scaledFontSize(13), color: theme.appTextPrimary),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(color: theme.appTextLight, fontSize: scaledFontSize(13)),
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
                        child:  Text(
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
