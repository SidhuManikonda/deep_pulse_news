import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/utils/youtube_url.dart';
import '../../shared/widgets/youtube_link_dialog.dart';
import '../../core/services/media_picker_services.dart';
import '../../data/models/feed_ad.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_loader.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../shared/widgets/news_ad_block.dart';
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
      final controller = ref.read(adsManagementControllerProvider);
      controller.loadAds();
      // The filters need these too, so they're loaded with the screen rather
      // than only when the create/edit form is opened.
      controller.loadStates();
      controller.loadTopics();
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
          _buildFilterBar(controller, theme),
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

  /// Opens the same searchable multi-select the targeting form uses. Defined
  /// here as well because that one belongs to the form sheet's state, and a
  /// filter must never reach into the form's selections.
  void _openPicker(
    ThemeData theme,
    String label,
    List<(int, String)> options,
    Set<int> selected,
    void Function(int id) onToggle,
  ) {
    if (options.isEmpty) return;
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

  // ── Filters: topic, location, date ────────────────────────────────────────
  Widget _buildFilterBar(AdsManagementController controller, ThemeData theme) {
    final topicCount = controller.filterTopicIds.length;
    final placeCount =
        controller.filterStateIds.length +
        controller.filterDistrictIds.length +
        controller.filterMandalIds.length;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          _filterButton(
            theme,
            Icons.sell_outlined,
            topicCount == 0
                ? 'Topic'
                : topicCount == 1
                ? _topicName(controller, controller.filterTopicIds.first)
                : '$topicCount topics',
            active: topicCount > 0,
            onTap: () => _openPicker(
              theme,
              'Topic',
              controller.topics.map((t) => (t.id, t.name)).toList(),
              controller.filterTopicIds,
              controller.toggleFilterTopic,
            ),
          ),
          _filterButton(
            theme,
            Icons.place_outlined,
            placeCount == 0 ? 'Location' : '$placeCount selected',
            active: placeCount > 0,
            onTap: () => _openLocationFilter(controller, theme),
          ),
          _filterButton(
            theme,
            Icons.date_range_outlined,
            _dateFilterLabel(controller),
            active:
                controller.filterFrom != null || controller.filterTo != null,
            onTap: () => _pickDateFilter(controller),
          ),
          if (controller.hasActiveFilters)
            _filterButton(
              theme,
              Icons.close_rounded,
              'Clear',
              active: false,
              onTap: controller.clearFilters,
            ),
        ],
      ),
    );
  }

  Widget _filterButton(
    ThemeData theme,
    IconData icon,
    String label, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? theme.appPrimary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? theme.appPrimary : theme.appDivider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? Colors.white : theme.appTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : theme.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _topicName(AdsManagementController controller, int id) {
    for (final t in controller.topics) {
      if (t.id == id) return t.name;
    }
    return '1 topic';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  String _dateFilterLabel(AdsManagementController controller) {
    final from = controller.filterFrom;
    final to = controller.filterTo;
    if (from == null && to == null) return 'Date';
    if (from != null && to != null) {
      // One day picked twice reads as that day, not as a range of no width.
      if (from.year == to.year &&
          from.month == to.month &&
          from.day == to.day) {
        return _shortDate(from);
      }
      return '${_shortDate(from)} – ${_shortDate(to)}';
    }
    return from != null ? 'From ${_shortDate(from)}' : 'To ${_shortDate(to!)}';
  }

  /// Offers the answers people actually want before offering a calendar.
  ///
  /// This used to open a range picker straight away, which made the commonest
  /// case — one day — the most awkward: you had to tap the same date twice to
  /// satisfy a start and an end you never wanted. Today and Yesterday are now
  /// one tap, a single date is two, and a range is still there for the rare
  /// time it's wanted.
  Future<void> _pickDateFilter(AdsManagementController controller) async {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        Widget option(IconData icon, String label, VoidCallback onTap) {
          return ListTile(
            leading: Icon(icon, size: 20, color: theme.appTextSecondary),
            title: Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(14),
                color: theme.appTextPrimary,
              ),
            ),
            onTap: onTap,
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.appDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              option(Icons.today_outlined, 'Today', () {
                controller.setDateFilter(today, today);
                Navigator.pop(sheetContext);
              }),
              option(Icons.history_rounded, 'Yesterday', () {
                final d = today.subtract(const Duration(days: 1));
                controller.setDateFilter(d, d);
                Navigator.pop(sheetContext);
              }),
              option(Icons.date_range_outlined, 'Last 7 days', () {
                controller.setDateFilter(
                  today.subtract(const Duration(days: 6)),
                  today,
                );
                Navigator.pop(sheetContext);
              }),
              const Divider(height: 8),
              option(Icons.event_outlined, 'Pick a date', () async {
                Navigator.pop(sheetContext);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: controller.filterFrom ?? today,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 1, 12, 31),
                  helpText: 'Filter by last updated',
                );
                // One date means that whole day — the controller widens the
                // end to 23:59, so there is no second tap to make.
                if (picked != null) controller.setDateFilter(picked, picked);
              }),
              option(Icons.swap_horiz_rounded, 'Pick a range', () async {
                Navigator.pop(sheetContext);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 1, 12, 31),
                  initialDateRange: controller.filterFrom != null
                      ? DateTimeRange(
                          start: controller.filterFrom!,
                          end: controller.filterTo ?? controller.filterFrom!,
                        )
                      : null,
                  helpText: 'Filter by last updated',
                );
                if (picked != null) {
                  controller.setDateFilter(picked.start, picked.end);
                }
              }),
              if (controller.filterFrom != null || controller.filterTo != null)
                option(Icons.close_rounded, 'Clear date filter', () {
                  controller.setDateFilter(null, null);
                  Navigator.pop(sheetContext);
                }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// One sheet for all three levels — see [_showLocationPicker].
  void _openLocationFilter(
    AdsManagementController controller,
    ThemeData theme,
  ) {
    _showLocationPicker(
      context: context,
      theme: theme,
      title: 'Filter by location',
      listenable: controller,
      levels: () => [
        _LocationLevel(
          label: 'States',
          options: controller.states.map((s) => (s.id, s.name)).toList(),
          selected: controller.filterStateIds,
          onToggle: controller.toggleFilterState,
          emptyHint: 'No states loaded yet.',
        ),
        _LocationLevel(
          label: 'Districts',
          options: controller.filterDistricts
              .map((d) => (d.id, d.name))
              .toList(),
          selected: controller.filterDistrictIds,
          onToggle: controller.toggleFilterDistrict,
          emptyHint: 'Pick a state first to see its districts.',
        ),
        _LocationLevel(
          label: 'Mandals',
          options: controller.filterMandals.map((m) => (m.id, m.name)).toList(),
          selected: controller.filterMandalIds,
          onToggle: controller.toggleFilterMandal,
          emptyHint: 'Pick a district first to see its mandals.',
        ),
      ],
    );
  }

  Widget _buildList(AdsManagementController controller, ThemeData theme) {
    if (controller.isLoading && controller.ads.isEmpty) {
      return const Center(child: InlineLoader());
    }

    final ads = controller.visibleAds;
    if (ads.isEmpty) {
      // Two different empty states: there are no ads at all, or the filters
      // hid them. Telling them apart is the difference between "make one" and
      // "widen your filter".
      final filtered = controller.ads.isNotEmpty;
      return RefreshIndicator(
        onRefresh: controller.loadAds,
        child: ListView(
          children: [
            const SizedBox(height: 140),
            Center(
              child: Text(
                filtered
                    ? 'No ads match these filters.'
                    : 'No ads yet.\nTap "New Ad" to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: theme.appTextLight,
                  height: 1.5,
                ),
              ),
            ),
            if (filtered) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: controller.clearFilters,
                  child: const Text('Clear filters'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadAds,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: ads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildAdCard(controller, ads[i], theme),
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
            child: ad.isYoutube
                ? CachedImageWidget(
                    imageUrl: ad.youtubeThumbnail ?? '',
                    fit: BoxFit.cover,
                  )
                : ad.isVideo
                ? _AdVideoThumbnail(source: ad.url)
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
    controller.loadTopics();

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

  /// Admin, Sub Admin and News Desk may put a YouTube link on an ad; Sr
  /// Reporters upload files only. They can't open this screen today, so this
  /// is belt-and-braces — the rule stays true if access ever widens.
  bool get _canPostYoutube =>
      ref.read(authViewModelProvider).user?.primaryRole.canPostYoutubeAds ??
      false;

  Future<void> _pasteYoutubeUrl(
    AdsManagementController controller, {
    String? initial,
  }) async {
    final result = await YoutubeLinkDialog.show(context, initial: initial);
    if (result != null) controller.setYoutubeUrl(result);
  }

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
                _buildTitleField(controller, theme),
                const SizedBox(height: 20),
                _buildStatusPicker(controller, theme),
                const SizedBox(height: 20),
                _buildInteractionToggles(controller, theme),
                const SizedBox(height: 20),
                _sectionTitle('Topics', theme),
                Text(
                  'Pick at least one — an ad has to belong to a topic.',
                  style: TextStyle(
                    fontSize: scaledFontSize(12),
                    color: theme.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTopics(controller, theme),
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
          // The server's reason, shown in the sheet rather than a snackbar: a
          // snackbar is drawn behind the sheet, so the one message that says
          // what to fix was the one thing the admin couldn't see.
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.error!,
                        style: TextStyle(
                          fontSize: scaledFontSize(12.5),
                          color: Colors.red[700],
                          height: 1.35,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: controller.clearError,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
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
                          // Only a saved ad closes the sheet. A rejected one
                          // keeps everything the admin typed — creative,
                          // title, topics, targeting — so the fix is one edit
                          // and another tap, not the whole form again. The
                          // reason is shown in the banner above the button.
                          if (!ok) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ad saved'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 3),
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
    final youtube = controller.youtubeUrl;

    // A link ad has no file to show, so it replaces the picker rather than
    // sitting beside it — one creative per ad, and the panel says which.
    if (youtube != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Creative', theme),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: YoutubeAdThumbnail(url: youtube),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'YouTube · ${YoutubeUrl.videoId(youtube) ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: scaledFontSize(12),
                    color: theme.appTextSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pasteYoutubeUrl(controller, initial: youtube),
                child: const Text('Change'),
              ),
              TextButton(
                onPressed: () => controller.setYoutubeUrl(null),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          // Swapping a link for a file was only possible by first tapping
          // Remove — the picker is hidden while a link is set, so there was
          // nothing on screen that said "use a file instead". Picking one
          // clears the link, so this is a single tap rather than two steps.
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _pickMedia,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              'Use an image or video instead',
              style: TextStyle(fontSize: scaledFontSize(13)),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              foregroundColor: theme.appPrimary,
              side: BorderSide(color: theme.appPrimary.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      );
    }

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
                // produced the "Invalid image data" box. Videos are rendered by
                // the video decoder instead, which paints their first frame.
                ? (_isVideoFile(picked.path)
                      ? _AdVideoThumbnail(source: picked.path)
                      : Image.file(picked, fit: BoxFit.cover))
                : (existing != null && existing.isYoutube)
                ? CachedImageWidget(
                    imageUrl: existing.youtubeThumbnail ?? '',
                    fit: BoxFit.cover,
                  )
                : (existing != null && existing.isVideo)
                ? _AdVideoThumbnail(source: existing.url)
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
        if (_canPostYoutube)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pasteYoutubeUrl(controller),
              icon: Icon(
                Icons.play_circle_outline_rounded,
                size: 18,
                color: theme.appPrimary,
              ),
              label: Text(
                'or paste a YouTube link',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: theme.appPrimary,
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

  Widget _buildTitleField(AdsManagementController controller, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Title', theme),
        const SizedBox(height: 8),
        TextFormField(
          // initialValue, not a controller: the sheet is rebuilt on every
          // controller change and a fresh TextEditingController each time
          // would reset the cursor mid-typing.
          initialValue: controller.title,
          onChanged: controller.setTitle,
          style: TextStyle(fontSize: scaledFontSize(14)),
          decoration: InputDecoration(
            hintText: 'Optional — shown over the creative',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  /// What a reader may do with this ad. Each switch removes the matching
  /// control from the feed card rather than disabling it.
  Widget _buildInteractionToggles(
    AdsManagementController controller,
    ThemeData theme,
  ) {
    Widget row(String label, bool value, ValueChanged<bool> onChanged) {
      return SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeThumbColor: theme.appPrimary,
        title: Text(
          label,
          style: TextStyle(
            fontSize: scaledFontSize(14),
            color: theme.appTextPrimary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Reader actions', theme),
        row('Allow likes', controller.isLikeable, controller.setLikeable),
        row('Allow sharing', controller.isShareable, controller.setShareable),
        row(
          'Allow reporting',
          controller.isReportable,
          controller.setReportable,
        ),
      ],
    );
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

  Widget _buildTopics(AdsManagementController controller, ThemeData theme) {
    if (controller.isLoadingTopics) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: InlineLoader(),
      );
    }

    return _selectorRow(
      theme,
      'Topics',
      controller.topics.map((t) => (t.id, t.name)).toList(),
      controller.selectedTopicIds,
      (id) => controller.toggleTopic(
        controller.topics.firstWhere((t) => t.id == id),
      ),
      emptyLabel: 'Select topics',
    );
  }

  Widget _buildTargeting(AdsManagementController controller, ThemeData theme) {
    if (controller.isLoadingStates) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: InlineLoader(),
      );
    }

    final states = controller.selectedStateIds.length;
    final districts = controller.selectedDistrictIds.length;
    final mandals = controller.selectedMandalIds.length;
    final parts = [
      if (states > 0) '$states state${states == 1 ? '' : 's'}',
      if (districts > 0) '$districts district${districts == 1 ? '' : 's'}',
      if (mandals > 0) '$mandals mandal${mandals == 1 ? '' : 's'}',
    ];
    final chosen = parts.isNotEmpty;

    // One row, one tap, all three levels. Setting a state, a district and a
    // mandal used to mean opening and dismissing three separate sheets.
    return InkWell(
      onTap: () => _showLocationPicker(
        context: context,
        theme: theme,
        title: 'Where it runs',
        listenable: controller,
        levels: () => [
          _LocationLevel(
            label: 'States',
            options: controller.states.map((s) => (s.id, s.name)).toList(),
            selected: controller.selectedStateIds,
            onToggle: (id) => controller.toggleState(
              controller.states.firstWhere((s) => s.id == id),
            ),
            emptyHint: 'No states loaded yet.',
          ),
          _LocationLevel(
            label: 'Districts',
            options: controller.availableDistricts
                .map((d) => (d.id, d.name))
                .toList(),
            selected: controller.selectedDistrictIds,
            onToggle: (id) => controller.toggleDistrict(
              controller.availableDistricts.firstWhere((d) => d.id == id),
            ),
            emptyHint: 'Pick a state first to see its districts.',
          ),
          _LocationLevel(
            label: 'Mandals',
            options: controller.availableMandals
                .map((m) => (m.id, m.name))
                .toList(),
            selected: controller.selectedMandalIds,
            onToggle: (id) => controller.toggleMandal(
              controller.availableMandals.firstWhere((m) => m.id == id),
            ),
            emptyHint: 'Pick a district first to see its mandals.',
          ),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chosen ? theme.appPrimary : theme.appDivider,
          ),
          color: chosen ? theme.appPrimary.withValues(alpha: 0.04) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 20,
              color: chosen ? theme.appPrimary : theme.appTextSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                chosen ? parts.join(' · ') : 'Runs everywhere',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  fontWeight: FontWeight.w600,
                  color: theme.appTextPrimary,
                ),
              ),
            ),
            Text(
              chosen ? 'Change' : 'Target',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                fontWeight: FontWeight.w600,
                color: theme.appPrimary,
              ),
            ),
          ],
        ),
      ),
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
    void Function(int id) onToggle, {

    /// Shown when nothing is picked. Defaults to the "runs everywhere" reading
    /// that suits optional location targeting; a required field passes its own
    /// so an empty selection doesn't read as an allowed state.
    String? emptyLabel,
  }) {
    final chosen = options.where((o) => selected.contains(o.$1)).toList();
    final summary = chosen.isEmpty
        ? (emptyLabel ?? 'Any $label')
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

/// Paints a still frame of a video as its thumbnail.
///
/// `video_player` is the only decoder the project carries, so there is no
/// thumbnail API to call: the frame is obtained by initialising a muted
/// controller and seeking a little way in. The controller is never played — it
/// exists solely to paint one frame — and is disposed with the widget.
///
/// [source] is either a remote URL or a local file path; the picker hands over
/// the latter before an ad is uploaded.
class _AdVideoThumbnail extends StatefulWidget {
  const _AdVideoThumbnail({required this.source});

  final String source;

  @override
  State<_AdVideoThumbnail> createState() => _AdVideoThumbnailState();
}

class _AdVideoThumbnailState extends State<_AdVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AdVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The form swaps creatives in place, so the same widget can be handed a
    // different file without being rebuilt from scratch.
    if (oldWidget.source != widget.source) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final source = widget.source;
    final controller = source.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.file(File(source));

    try {
      await controller.initialize();
      await controller.setVolume(0);
      // The opening frame of an encoded video is frequently black; a short seek
      // lands on actual content.
      await controller.seekTo(const Duration(milliseconds: 200));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;

    if (controller == null) {
      return Container(
        color: Colors.black12,
        child: Center(
          child: _failed
              ? Icon(
                  Icons.videocam_off_rounded,
                  size: 34,
                  color: theme.appTextLight,
                )
              : SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.appPrimary,
                  ),
                ),
        ),
      );
    }

    // A controller can report a zero size for a stream whose dimensions never
    // arrived; falling back to 16:9 keeps FittedBox from dividing by zero.
    final size = controller.value.size;
    final width = size.width > 0 ? size.width : 16.0;
    final height = size.height > 0 ? size.height : 9.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: width,
            height: height,
            child: VideoPlayer(controller),
          ),
        ),
        // Without this the still reads as a plain image, losing the one cue
        // that tells an admin which creatives are video.
        Center(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 26,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// One level of a location picker — the options at that level, what's chosen,
/// and how to toggle one.
class _LocationLevel {
  final String label;
  final List<(int, String)> options;
  final Set<int> selected;
  final void Function(int id) onToggle;

  /// Shown instead of the list when [options] is empty, explaining what the
  /// user has to pick first rather than leaving them at a blank panel.
  final String emptyHint;

  const _LocationLevel({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.emptyHint,
  });
}

/// Picks states, districts and mandals in **one** sheet.
///
/// Replaces the previous arrangement, where each level was a summary row that
/// opened a sheet of its own — setting a state, a district and a mandal meant
/// opening and dismissing three sheets, and from the filter a fourth on top of
/// them. Here the levels are tabs: switching is a tap, the running selection
/// stays visible as removable chips, and nothing is nested.
///
/// Toggles are applied to the controller as they happen, so a swipe-dismiss
/// keeps the work rather than discarding it.
void _showLocationPicker({
  required BuildContext context,
  required ThemeData theme,
  required String title,
  required Listenable listenable,
  required List<_LocationLevel> Function() levels,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AnimatedBuilder(
      animation: listenable,
      builder: (_, __) =>
          _LocationPickerSheet(title: title, theme: theme, levels: levels()),
    ),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  final String title;
  final ThemeData theme;
  final List<_LocationLevel> levels;

  const _LocationPickerSheet({
    required this.title,
    required this.theme,
    required this.levels,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    // A level whose parent hasn't been chosen has no options yet; clamping
    // keeps the tab valid if the user clears a state while deeper in.
    final tab = _tab.clamp(0, widget.levels.length - 1);
    final level = widget.levels[tab];

    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? level.options
        : level.options.where((o) => o.$2.toLowerCase().contains(q)).toList();
    final allShown =
        visible.isNotEmpty &&
        visible.every((o) => level.selected.contains(o.$1));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.appDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: scaledFontSize(16),
                        fontWeight: FontWeight.w700,
                        color: theme.appTextPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: scaledFontSize(14),
                        fontWeight: FontWeight.w700,
                        color: theme.appPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Level tabs. Each carries its own count, so the whole selection
            // is legible without leaving the panel you're on.
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.levels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final l = widget.levels[i];
                  final on = i == tab;
                  final count = l.selected.length;
                  return InkWell(
                    onTap: () => setState(() {
                      _tab = i;
                      _query = '';
                    }),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? theme.appPrimary : theme.appGrey100,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        count == 0 ? l.label : '${l.label} · $count',
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          fontWeight: FontWeight.w600,
                          color: on ? Colors.white : theme.appTextSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (level.options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(fontSize: scaledFontSize(14)),
                          decoration: InputDecoration(
                            hintText: 'Search ${level.label.toLowerCase()}',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (visible.isNotEmpty)
                      TextButton(
                        // Acts on what the search is showing, so typing a
                        // prefix and tapping this picks just that group.
                        onPressed: () => setState(() {
                          for (final o in visible) {
                            if (level.selected.contains(o.$1) == allShown) {
                              level.onToggle(o.$1);
                            }
                          }
                        }),
                        child: Text(allShown ? 'Clear' : 'All'),
                      ),
                  ],
                ),
              ),

            // Everything chosen so far, at every level, removable in one tap.
            if (widget.levels.any((l) => l.selected.isNotEmpty))
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final l in widget.levels)
                      for (final o in l.options.where(
                        (o) => l.selected.contains(o.$1),
                      ))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InputChip(
                            label: Text(
                              o.$2,
                              style: TextStyle(fontSize: scaledFontSize(12)),
                            ),
                            onDeleted: () => setState(() => l.onToggle(o.$1)),
                            backgroundColor: theme.appGrey100,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                  ],
                ),
              ),

            const SizedBox(height: 4),
            Expanded(
              child: level.options.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          level.emptyHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: scaledFontSize(13),
                            color: theme.appTextLight,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final o = visible[i];
                        final on = level.selected.contains(o.$1);
                        return CheckboxListTile(
                          value: on,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: theme.appPrimary,
                          title: Text(
                            o.$2,
                            style: TextStyle(fontSize: scaledFontSize(14)),
                          ),
                          onChanged: (_) =>
                              setState(() => level.onToggle(o.$1)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
