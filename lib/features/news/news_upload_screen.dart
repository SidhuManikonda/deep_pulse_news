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
import 'news_upload_view_model.dart';

class NewsUploadScreen extends ConsumerStatefulWidget {
  const NewsUploadScreen({super.key});

  @override
  ConsumerState<NewsUploadScreen> createState() => _NewsUploadScreenState();
}

class _NewsUploadScreenState extends ConsumerState<NewsUploadScreen> {
  final _headlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _moreController = TextEditingController();
  final _mediaPickerService = MediaPickerService();

  @override
  void initState() {
    super.initState();
    ref.read(newsUploadViewModelProvider.notifier).clearData();
    ref.read(topicViewModelProvider).loadTopics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsUploadViewModelProvider.notifier).loadStates();
    });
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

    final isFormValid =
        _headlineController.text.isNotEmpty &&
        _descriptionController.text.isNotEmpty &&
        vm.selectedCategories.isNotEmpty &&
        vm.selectedStateIds.isNotEmpty &&
        vm.acceptTerms;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaCard(vm, theme),
                  const SizedBox(height: 14),
                  _buildStoryDetailsCard(vm, theme),
                  const SizedBox(height: 14),
                  _buildTopicsCard(vm, topicViewModel.topics, theme),
                  const SizedBox(height: 14),
                  _buildLocationCard(vm, theme),
                  const SizedBox(height: 14),
                  _buildTermsRow(vm, theme),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildSendButton(vm, isFormValid, theme),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        'Upload News',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.appTextPrimary,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.appDivider),
      ),
    );
  }

  // ── Section card wrapper ────────────────────────────────────────────────────
  Widget _buildCard({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.appGrey200),
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.appPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: theme.appPrimary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
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
          if (vm.selectedMedia.isEmpty)
            _buildMediaPlaceholder(theme)
          else
            _buildMediaGrid(vm, theme),
          if (vm.selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _showMediaPicker,
              icon: Icon(
                Icons.add_circle_outline,
                size: 16,
                color: theme.appPrimary,
              ),
              label: Text(
                'Add more',
                style: TextStyle(color: theme.appPrimary, fontSize: 13),
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
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: theme.appGrey300, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
          color: theme.appGrey50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 36,
              color: theme.appGrey400,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to add Photos / Video / Audio',
              style: TextStyle(fontSize: 13, color: theme.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid(NewsUploadViewModel vm, ThemeData theme) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vm.selectedMedia.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = vm.selectedMedia[index];
          final ext = file.path.toLowerCase().split('.').last;
          final isImage = [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'bmp',
            'webp',
          ].contains(ext);
          final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(ext);

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
                      .removeMedia(index),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.red,
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
              style: TextStyle(fontSize: 12, color: theme.appTextSecondary),
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
                    activeColor: theme.appPrimary,
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
                    fontSize: 13,
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
            fontSize: 13,
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
      style: TextStyle(fontSize: 14, color: theme.appTextPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.appTextLight, fontSize: 14),
        counterText: '',
        filled: true,
        fillColor: theme.appGrey50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.appGrey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.appGrey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.appPrimary, width: 1.5),
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
    final count = vm.selectedCategories.length;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            theme,
            Icons.tag_rounded,
            'Topics',
            trailing: count > 0 ? _buildCountBadge(theme, count) : null,
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
                      onRemove: () => ref
                          .read(newsUploadViewModelProvider.notifier)
                          .toggleCategory(t),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          _MultiSelectList<Topic>(
            key: const ValueKey('topics'),
            items: topics,
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
                    theme,
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
          ),

          // Districts — only when states selected
          if (vm.selectedStateIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildLocationRow(
              theme,
              'Districts',
              vm.selectedDistricts.map((d) => d.name).toList(),
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
          ],

          // Mandals — only when districts selected
          if (vm.selectedDistrictIds.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildLocationRow(
              theme,
              'Mandals',
              vm.selectedMandals.map((m) => m.name).toList(),
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
          ],
        ],
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.appTextSecondary,
          ),
        ),
        Expanded(
          child: names.isEmpty
              ? Text(
                  'None selected',
                  style: TextStyle(fontSize: 13, color: theme.appTextLight),
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

  // ── Terms row ───────────────────────────────────────────────────────────────
  Widget _buildTermsRow(NewsUploadViewModel vm, ThemeData theme) {
    return InkWell(
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
                activeColor: theme.appPrimary,
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
              style: TextStyle(fontSize: 14, color: theme.appTextSecondary),
            ),
            Text(
              'terms and conditions',
              style: TextStyle(
                fontSize: 14,
                color: theme.appPrimary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
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
          child: ElevatedButton(
            onPressed: isFormValid && !vm.isUploading ? _handleSendNews : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              disabledBackgroundColor: theme.appGrey300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: vm.isUploading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'SEND',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
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
        color: theme.appPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.appPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.appPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: theme.appPrimary,
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
        color: theme.appSelectionBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: theme.appSelectionPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCountBadge(ThemeData theme, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.appPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
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
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: theme.appPrimary,
              ),
              title: Text(
                'Choose Photos',
                style: TextStyle(color: theme.appTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.video_library_rounded,
                color: theme.appPrimary,
              ),
              title: Text(
                'Choose Video',
                style: TextStyle(color: theme.appTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: theme.appPrimary),
              title: Text(
                'Take Photo',
                style: TextStyle(color: theme.appTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickMediaFromCamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
    final success = await vm.uploadNews(
      headline: _headlineController.text,
      description: _descriptionController.text,
      content: _moreController.text,
      categories: ref
          .read(newsUploadViewModelProvider.notifier)
          .selectedCategories,
      mediaFiles: ref.read(newsUploadViewModelProvider.notifier).selectedMedia,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('News uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigator.pop(context);
      ref.read(homeViewModelProvider.notifier).loadNewsData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error ?? 'Failed to upload news'),
          backgroundColor: Colors.red,
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
          color: selectedCount > 0
              ? theme.appPrimary.withValues(alpha: 0.4)
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
                          ? theme.appPrimary
                          : theme.appTextSecondary,
                    ),
                  if (widget.leadingIcon != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.selectorTitle ?? widget.searchHint,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedCount > 0
                            ? theme.appPrimary
                            : theme.appTextSecondary,
                      ),
                    ),
                  ),
                  if (widget.isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.appPrimary,
                        ),
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
                          color: theme.appPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$selectedCount',
                          style: const TextStyle(
                            fontSize: 11,
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
                style: TextStyle(fontSize: 13, color: theme.appTextPrimary),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(color: theme.appTextLight, fontSize: 13),
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
                    borderSide: BorderSide(color: theme.appGrey200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.appGrey200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.appPrimary, width: 1.5),
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
                    Icon(
                      Icons.error_outline,
                      color: theme.appErrorMedium,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Failed to load data',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.appErrorMedium,
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
                            color: theme.appPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              )
            // Loading state
            else if (widget.isLoading)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.appPrimary),
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
                      fontSize: 13,
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
                              activeColor: theme.appPrimary,
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
                                  fontSize: 13,
                                  color: isSelected
                                      ? theme.appPrimary
                                      : theme.appTextPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: theme.appPrimary,
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
