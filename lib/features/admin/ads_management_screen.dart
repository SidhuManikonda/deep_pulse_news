import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/services/media_picker_services.dart';
import '../../data/models/feed_ad.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_loader.dart';
import '../../shared/widgets/cached_image_widget.dart';
import 'ads_management_controller.dart';

/// Manages the standalone adverts that run between articles in the reader feed.
class AdsManagementScreen extends ConsumerStatefulWidget {
  const AdsManagementScreen({super.key});

  @override
  ConsumerState<AdsManagementScreen> createState() =>
      _AdsManagementScreenState();
}

class _AdsManagementScreenState extends ConsumerState<AdsManagementScreen> {
  static const _filters = <String?, String>{
    null: 'All',
    'published': 'Live',
    'unpublished': 'Paused',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adsManagementControllerProvider).loadAds();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(adsManagementControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Ads Management',
          style: TextStyle(
            fontSize: appFontSizeTitle,
            fontWeight: FontWeight.bold,
            color: theme.appTextPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.appPrimary,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(controller),
        icon: const Icon(Icons.add),
        label: const Text('New Ad'),
      ),
      body: Column(
        children: [
          _buildFilters(controller, theme),
          Expanded(child: _buildList(controller, theme)),
        ],
      ),
    );
  }

  Widget _buildFilters(AdsManagementController controller, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: _filters.entries.map((e) {
          final selected = controller.statusFilter == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: selected,
              backgroundColor: Colors.white,
              selectedColor: theme.appPrimary,
              labelStyle: TextStyle(
                fontSize: scaledFontSize(13),
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : theme.appTextSecondary,
              ),
              onSelected: (_) => controller.setStatusFilter(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(AdsManagementController controller, ThemeData theme) {
    if (controller.isLoading && controller.ads.isEmpty) {
      return const Center(child: InlineLoader());
    }
    if (controller.ads.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.loadAds,
        child: ListView(
          children: [
            const SizedBox(height: 140),
            Center(
              child: Text(
                'No ads yet.\nTap "New Ad" to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: theme.appTextLight,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadAds,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: controller.ads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) =>
            _buildAdCard(controller, controller.ads[i], theme),
      ),
    );
  }

  Widget _buildAdCard(
    AdsManagementController controller,
    FeedAd ad,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.appDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: ad.isVideo
                ? Container(
                    color: Colors.black12,
                    child: Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        size: 40,
                        color: theme.appPrimary,
                      ),
                    ),
                  )
                : CachedImageWidget(imageUrl: ad.url, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _statusPill(ad, theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _targetingSummary(ad),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: scaledFontSize(12),
                      color: theme.appTextSecondary,
                    ),
                  ),
                ),
                Text(
                  '#${ad.id}',
                  style: TextStyle(
                    fontSize: scaledFontSize(11),
                    color: theme.appTextLight,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildActions(controller, ad, theme),
        ],
      ),
    );
  }

  Widget _statusPill(FeedAd ad, ThemeData theme) {
    final (label, color) = ad.isDeleted
        ? ('Deleted', Colors.red)
        : ad.isPublished
        ? ('Live', Colors.green)
        : ('Paused', Colors.orange);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: scaledFontSize(11),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Where the ad runs. No targeting means it runs everywhere, which is worth
  /// saying explicitly — an empty string would read like missing data.
  String _targetingSummary(FeedAd ad) {
    if (ad.locations.isEmpty) return 'All areas';
    final parts = <String>[];
    if (ad.stateLocations.isNotEmpty) {
      parts.add('${ad.stateLocations.length} state(s)');
    }
    if (ad.districtLocations.isNotEmpty) {
      parts.add('${ad.districtLocations.length} district(s)');
    }
    if (ad.mandalLocations.isNotEmpty) {
      parts.add('${ad.mandalLocations.length} mandal(s)');
    }
    return parts.join(' · ');
  }

  Widget _buildActions(
    AdsManagementController controller,
    FeedAd ad,
    ThemeData theme,
  ) {
    Future<void> act(Future<bool> Function() run, String done) async {
      final ok = await run();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ok ? done : 'That did not work')));
    }

    if (ad.isDeleted) {
      return Row(
        children: [
          _action(theme, Icons.restore, 'Restore', () {
            act(() => controller.restore(ad.id), 'Ad restored');
          }),
          _action(theme, Icons.delete_forever, 'Delete forever', () {
            _confirmForceDelete(controller, ad);
          }, danger: true),
        ],
      );
    }

    return Row(
      children: [
        if (ad.isPublished)
          _action(theme, Icons.pause_circle_outline, 'Pause', () {
            act(() => controller.unpublish(ad.id), 'Ad paused');
          })
        else
          _action(theme, Icons.play_circle_outline, 'Publish', () {
            act(() => controller.publish(ad.id), 'Ad published');
          }),
        // "Bump" is publisher jargon — it says nothing to whoever is actually
        // running these ads. The label now names the outcome instead.
        _action(theme, Icons.arrow_upward_rounded, 'Move to Top', () {
          act(() => controller.republish(ad.id), 'Ad moved to the top');
        }),
        _action(theme, Icons.edit_outlined, 'Edit', () {
          _openForm(controller, ad: ad);
        }),
        _action(theme, Icons.delete_outline, 'Delete', () {
          act(() => controller.softDelete(ad.id), 'Ad deleted');
        }, danger: true),
      ],
    );
  }

  Widget _action(
    ThemeData theme,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? Colors.red : theme.appTextSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                // Four actions share the card's width, so a longer label like
                // "Move to Top" has to be allowed to trim rather than overflow
                // — especially at larger system font scales.
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: scaledFontSize(10), color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmForceDelete(AdsManagementController controller, FeedAd ad) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete permanently?'),
        content: const Text(
          'This removes the ad and its file for good. It cannot be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await controller.forceDelete(ad.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Ad deleted' : 'That did not work'),
                ),
              );
            },
            child: const Text(
              'Delete forever',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(AdsManagementController controller, {FeedAd? ad}) {
    if (ad == null) {
      controller.startCreate();
    } else {
      controller.startEdit(ad);
    }
    controller.loadStates();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AdFormSheet(),
    );
  }
}

/// Create / edit form. Lives in a sheet so the list stays behind it — an ad is
/// a short form and doesn't warrant a whole route.
class _AdFormSheet extends ConsumerStatefulWidget {
  const _AdFormSheet();

  @override
  ConsumerState<_AdFormSheet> createState() => _AdFormSheetState();
}

class _AdFormSheetState extends ConsumerState<_AdFormSheet> {
  final _picker = MediaPickerService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(adsManagementControllerProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  controller.isEditing ? 'Edit Ad' : 'New Ad',
                  style: TextStyle(
                    fontSize: scaledFontSize(17),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildMediaPicker(controller, theme),
                const SizedBox(height: 20),
                _buildStatusPicker(controller, theme),
                const SizedBox(height: 20),
                _sectionTitle('Where it runs', theme),
                Text(
                  'Leave everything unticked to run this ad everywhere.',
                  style: TextStyle(
                    fontSize: scaledFontSize(12),
                    color: theme.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTargeting(controller, theme),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.appPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: controller.isSaving || !controller.canSubmit
                      ? null
                      : () async {
                          final ok = await controller.submit();
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              // On failure show what the server said — the
                              // reason is usually something the admin can fix
                              // right away (file type, size, targeting).
                              content: Text(
                                ok
                                    ? 'Ad saved'
                                    : controller.error ??
                                          'Could not save the ad',
                              ),
                              backgroundColor: ok ? null : Colors.red[700],
                              behavior: SnackBarBehavior.floating,
                              // A validation message runs longer than the stock
                              // 4s, and it's the whole point of the snackbar.
                              duration: Duration(seconds: ok ? 3 : 8),
                            ),
                          );
                        },
                  child: controller.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          controller.isEditing ? 'Save changes' : 'Create ad',
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: scaledFontSize(14),
        fontWeight: FontWeight.w700,
        color: theme.appTextPrimary,
      ),
    ),
  );

  Widget _buildMediaPicker(
    AdsManagementController controller,
    ThemeData theme,
  ) {
    final existing = controller.editing;
    final picked = controller.media;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Creative', theme),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickMedia,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.appDivider),
              color: theme.appGrey100,
            ),
            clipBehavior: Clip.antiAlias,
            child: picked != null
                // A video file can't be decoded as an image — doing so is what
                // produced the "Invalid image data" box. Videos get a
                // placeholder instead of a thumbnail.
                ? (_isVideoFile(picked.path)
                      ? _videoPlaceholder(theme, picked.path)
                      : Image.file(picked, fit: BoxFit.cover))
                : (existing != null && existing.isVideo)
                ? _videoPlaceholder(theme, existing.url)
                : (existing != null)
                ? CachedImageWidget(imageUrl: existing.url, fit: BoxFit.cover)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 30,
                          color: theme.appTextLight,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          existing == null
                              ? 'Pick image or video'
                              : 'Tap to replace the creative',
                          style: TextStyle(
                            fontSize: scaledFontSize(13),
                            color: theme.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (controller.isEditing && picked == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Keeping the current creative.',
              style: TextStyle(
                fontSize: scaledFontSize(11),
                color: theme.appTextLight,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
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
    if (choice == null) return;

    final controller = ref.read(adsManagementControllerProvider);
    if (choice == 'video') {
      final video = await _picker.pickVideo();
      if (video != null) controller.setMedia(video);
      return;
    }
    final images = await _picker.pickImages();
    if (images.isNotEmpty) controller.setMedia(images.first);
  }

  Widget _buildStatusPicker(
    AdsManagementController controller,
    ThemeData theme,
  ) {
    return Row(
      children: [
        _sectionTitle('Status', theme),
        const SizedBox(width: 16),
        for (final option in const ['published', 'unpublished'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option == 'published' ? 'Live' : 'Paused'),
              selected: controller.formStatus == option,
              backgroundColor: Colors.white,
              selectedColor: theme.appPrimary,
              labelStyle: TextStyle(
                fontSize: scaledFontSize(12),
                fontWeight: FontWeight.w600,
                color: controller.formStatus == option
                    ? Colors.white
                    : Colors.black87,
              ),
              onSelected: (_) => controller.setFormStatus(option),
            ),
          ),
      ],
    );
  }

  Widget _buildTargeting(AdsManagementController controller, ThemeData theme) {
    if (controller.isLoadingStates) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: InlineLoader(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _selectorRow(
          theme,
          'States',
          controller.states.map((s) => (s.id, s.name)).toList(),
          controller.selectedStateIds,
          (id) => controller.toggleState(
            controller.states.firstWhere((s) => s.id == id),
          ),
        ),
        if (controller.availableDistricts.isNotEmpty) ...[
          const SizedBox(height: 14),
          _selectorRow(
            theme,
            'Districts',
            controller.availableDistricts.map((d) => (d.id, d.name)).toList(),
            controller.selectedDistrictIds,
            (id) => controller.toggleDistrict(
              controller.availableDistricts.firstWhere((d) => d.id == id),
            ),
          ),
        ],
        if (controller.availableMandals.isNotEmpty) ...[
          const SizedBox(height: 14),
          _selectorRow(
            theme,
            'Mandals',
            controller.availableMandals.map((m) => (m.id, m.name)).toList(),
            controller.selectedMandalIds,
            (id) => controller.toggleMandal(
              controller.availableMandals.firstWhere((m) => m.id == id),
            ),
          ),
        ],
      ],
    );
  }

  bool _isVideoFile(String path) {
    final p = path.toLowerCase().split('?').first;
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv') ||
        p.endsWith('.webm');
  }

  Widget _videoPlaceholder(ThemeData theme, String path) {
    return Container(
      color: Colors.black12,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_rounded, size: 34, color: theme.appPrimary),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              path.split(RegExp(r'[\\/]')).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: scaledFontSize(12),
                color: theme.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A tappable summary row that opens a searchable picker.
  ///
  /// Replaces the old wrap of chips: a state has 30+ districts and hundreds of
  /// mandals, so laying them all out inline meant scrolling the whole list to
  /// find one name. A sheet with a search box finds it in two keystrokes.
  Widget _selectorRow(
    ThemeData theme,
    String label,
    List<(int, String)> options,
    Set<int> selected,
    void Function(int id) onToggle,
  ) {
    final chosen = options.where((o) => selected.contains(o.$1)).toList();
    final summary = chosen.isEmpty
        ? 'Any $label'
        : chosen.length <= 2
        ? chosen.map((o) => o.$2).join(', ')
        : '${chosen.length} selected';

    return InkWell(
      onTap: options.isEmpty
          ? null
          : () => _openPicker(theme, label, options, selected, onToggle),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: chosen.isEmpty ? theme.appDivider : theme.appPrimary,
          ),
          color: chosen.isEmpty
              ? theme.appGrey100
              : theme.appPrimary.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: scaledFontSize(11),
                      color: theme.appTextLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: scaledFontSize(13),
                      fontWeight: FontWeight.w600,
                      color: theme.appTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.search, size: 18, color: theme.appTextLight),
          ],
        ),
      ),
    );
  }

  void _openPicker(
    ThemeData theme,
    String label,
    List<(int, String)> options,
    Set<int> selected,
    void Function(int id) onToggle,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SearchablePicker(
        title: label,
        options: options,
        selected: selected,
        onToggle: onToggle,
        theme: theme,
      ),
    );
  }
}

/// Searchable, multi-select list used for the ad's targeting.
///
/// Toggles apply straight to the controller as they're tapped, so the summary
/// row behind the sheet stays in step and nothing is lost if the sheet is
/// dismissed by swiping rather than by the Done button.
class _SearchablePicker extends StatefulWidget {
  final String title;
  final List<(int, String)> options;
  final Set<int> selected;
  final void Function(int id) onToggle;
  final ThemeData theme;

  const _SearchablePicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.theme,
  });

  @override
  State<_SearchablePicker> createState() => _SearchablePickerState();
}

class _SearchablePickerState extends State<_SearchablePicker> {
  String _query = '';

  List<(int, String)> get _filtered {
    if (_query.trim().isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options.where((o) => o.$2.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final filtered = _filtered;
    // "Select all" acts on what the search is showing, so typing a prefix and
    // tapping it picks just that group rather than the whole state.
    final allShown =
        filtered.isNotEmpty &&
        filtered.every((o) => widget.selected.contains(o.$1));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title}  ·  ${widget.selected.length} selected',
                      style: TextStyle(
                        fontSize: scaledFontSize(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (filtered.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        for (final o in filtered) {
                          final isOn = widget.selected.contains(o.$1);
                          if (allShown == isOn) widget.onToggle(o.$1);
                        }
                        setState(() {});
                      },
                      child: Text(allShown ? 'Clear' : 'Select all'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: scaledFontSize(14)),
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing matches "$_query"',
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: theme.appTextLight,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final o = filtered[i];
                        final isOn = widget.selected.contains(o.$1);
                        return CheckboxListTile(
                          dense: true,
                          value: isOn,
                          activeColor: theme.appPrimary,
                          controlAffinity: ListTileControlAffinity.trailing,
                          title: Text(
                            o.$2,
                            style: TextStyle(fontSize: scaledFontSize(14)),
                          ),
                          onChanged: (_) {
                            widget.onToggle(o.$1);
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.appPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
