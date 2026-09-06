import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/district.dart';
import '../../data/models/state.dart' as location_models;
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_loader.dart';
import 'location_management_controller.dart';

class LocationManagementScreen extends ConsumerStatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  ConsumerState<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState
    extends ConsumerState<LocationManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final controller = ref.read(locationManagementControllerProvider);
        controller.setCurrentType(LocationType.values[_tabController.index]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationManagementControllerProvider).fetchStates();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(
            'Location Management',
            style: TextStyle(
              fontSize: scaledFontSize(20),
              fontWeight: FontWeight.bold,
              color: theme.appTextPrimary,
            ),
          ),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: theme.appPrimary,
            unselectedLabelColor: theme.appTextSecondary,
            indicatorColor: theme.appPrimary,
            tabs: const [
              Tab(text: 'States'),
              Tab(text: 'Districts'),
              Tab(text: 'Mandals'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_StatesTab(), _DistrictsTab(), _MandalsTab()],
        ),
      ),
    );
  }
}

// ─── States Tab ────────────────────────────────────────────────────────────

class _StatesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(locationManagementControllerProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        _CreateBar(
          hint: 'Enter state name',
          isCreating:
              controller.isCreating &&
              controller.currentType == LocationType.state,
          onSubmit: (name) async {
            final success = await controller.createState(name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'State created successfully'
                        : controller.createError ?? 'Failed to create state',
                  ),
                ),
              );
            }
            return success;
          },
        ),
        Expanded(
          child: _buildListContent(
            isLoading: controller.isLoadingStates,
            error: controller.statesError,
            isEmpty: controller.states.isEmpty,
            emptyMessage: 'No states found',
            onRefresh: () => controller.fetchStates(forceRefresh: true),
            itemCount: controller.states.length,
            itemBuilder: (index) {
              final state = controller.states[index];
              return _LocationTile(
                name: state.name,
                isActive: state.isActive,
                subtitle: 'ID: ${state.id}',
                theme: theme,
                onRename: (newName) async {
                  final success = await controller.renameState(state, newName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Renamed to "$newName"'
                              : controller.updateError ??
                                    'Failed to rename state',
                        ),
                      ),
                    );
                  }
                  return success;
                },
                onDelete: () async {
                  final success = await controller.deleteState(state);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '${state.name} deleted'
                              : 'Failed to delete',
                        ),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Districts Tab ──────────────────────────────────────────────────────────

class _DistrictsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(locationManagementControllerProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // State selector dropdown
        _ParentSelector<location_models.State>(
          label: 'Select State',
          isLoading: controller.isLoadingStates,
          items: controller.states,
          selectedItem: controller.selectedState,
          itemName: (item) => item.name,
          onChanged: (state) => controller.selectState(state),
          theme: theme,
        ),
        if (controller.selectedState != null)
          _CreateBar(
            hint: 'Enter district name',
            isCreating:
                controller.isCreating &&
                controller.currentType == LocationType.district,
            onSubmit: (name) async {
              final success = await controller.createDistrict(name);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'District created successfully'
                          : controller.createError ??
                                'Failed to create district',
                    ),
                  ),
                );
              }
              return success;
            },
          ),
        Expanded(
          child: controller.selectedState == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 48,
                        color: theme.appTextLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select a state to view districts',
                        style: TextStyle(
                          color: theme.appTextSecondary,
                          fontSize: scaledFontSize(15),
                        ),
                      ),
                    ],
                  ),
                )
              : _buildListContent(
                  isLoading: controller.isLoadingDistricts,
                  error: controller.districtsError,
                  isEmpty: controller.districts.isEmpty,
                  emptyMessage: 'No districts found for this state',
                  onRefresh: () =>
                      controller.fetchDistricts(controller.selectedState!.id),
                  itemCount: controller.districts.length,
                  itemBuilder: (index) {
                    final district = controller.districts[index];
                    return _LocationTile(
                      name: district.name,
                      isActive: district.isActive,
                      subtitle: 'ID: ${district.id}',
                      theme: theme,
                      onRename: (newName) async {
                        final success = await controller.renameDistrict(
                          district,
                          newName,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Renamed to "$newName"'
                                    : controller.updateError ??
                                          'Failed to rename district',
                              ),
                            ),
                          );
                        }
                        return success;
                      },
                      onDelete: () async {
                        final success = await controller.deleteDistrict(
                          district,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? '${district.name} deleted'
                                    : 'Failed to delete',
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Mandals Tab ────────────────────────────────────────────────────────────

class _MandalsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(locationManagementControllerProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // State selector
        _ParentSelector<location_models.State>(
          label: 'Select State',
          isLoading: controller.isLoadingStates,
          items: controller.states,
          selectedItem: controller.selectedState,
          itemName: (item) => item.name,
          onChanged: (state) => controller.selectState(state),
          theme: theme,
        ),
        // District selector (only when state is selected)
        if (controller.selectedState != null)
          _ParentSelector<District>(
            label: 'Select District',
            isLoading: controller.isLoadingDistricts,
            items: controller.districts,
            selectedItem: controller.selectedDistrict,
            itemName: (item) => item.name,
            onChanged: (district) => controller.selectDistrict(district),
            theme: theme,
          ),
        if (controller.selectedDistrict != null)
          _CreateBar(
            hint: 'Enter mandal name',
            isCreating:
                controller.isCreating &&
                controller.currentType == LocationType.mandal,
            onSubmit: (name) async {
              final success = await controller.createMandal(name);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Mandal created successfully'
                          : controller.createError ?? 'Failed to create mandal',
                    ),
                  ),
                );
              }
              return success;
            },
          ),
        Expanded(child: _buildMandalsContent(context, controller, theme)),
      ],
    );
  }

  Widget _buildMandalsContent(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
  ) {
    if (controller.selectedState == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward, size: 48, color: theme.appTextLight),
            const SizedBox(height: 12),
            Text(
              'Select a state first',
              style: TextStyle(
                color: theme.appTextSecondary,
                fontSize: scaledFontSize(15),
              ),
            ),
          ],
        ),
      );
    }
    if (controller.selectedDistrict == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_upward, size: 48, color: theme.appTextLight),
            const SizedBox(height: 12),
            Text(
              'Select a district to view mandals',
              style: TextStyle(
                color: theme.appTextSecondary,
                fontSize: scaledFontSize(15),
              ),
            ),
          ],
        ),
      );
    }
    return _buildListContent(
      isLoading: controller.isLoadingMandals,
      error: controller.mandalsError,
      isEmpty: controller.mandals.isEmpty,
      emptyMessage: 'No mandals found for this district',
      onRefresh: () => controller.fetchMandals(controller.selectedDistrict!.id),
      itemCount: controller.mandals.length,
      itemBuilder: (index) {
        final mandal = controller.mandals[index];
        return _LocationTile(
          name: mandal.name,
          isActive: mandal.isActive,
          subtitle: 'ID: ${mandal.id}',
          theme: theme,
          onRename: (newName) async {
            final success = await controller.renameMandal(mandal, newName);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Renamed to "$newName"'
                        : controller.updateError ?? 'Failed to rename mandal',
                  ),
                ),
              );
            }
            return success;
          },
          onDelete: () async {
            final success = await controller.deleteMandal(mandal);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? '${mandal.name} deleted' : 'Failed to delete',
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────────

Widget _buildListContent({
  required bool isLoading,
  required String? error,
  required bool isEmpty,
  required String emptyMessage,
  required Future<void> Function() onRefresh,
  required int itemCount,
  required Widget Function(int index) itemBuilder,
}) {
  return RefreshIndicator(
    onRefresh: onRefresh,
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);

        if (isLoading) {
          return ListView(
            children: const [
              SizedBox(height: 120),
              InlineLoader(),
            ],
          );
        }

        if (error != null) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Failed to load data',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: onRefresh,
                  child: const Text('Retry'),
                ),
              ),
            ],
          );
        }

        if (isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text(emptyMessage, style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: itemCount,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 76,
            endIndent: 16,
            color: theme.appDivider,
          ),
          itemBuilder: (context, index) => itemBuilder(index),
        );
      },
    ),
  );
}

class _CreateBar extends StatefulWidget {
  final String hint;
  final bool isCreating;
  final Future<bool> Function(String name) onSubmit;

  const _CreateBar({
    required this.hint,
    required this.isCreating,
    required this.onSubmit,
  });

  @override
  State<_CreateBar> createState() => _CreateBarState();
}

class _CreateBarState extends State<_CreateBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    final success = await widget.onSubmit(name);
    if (success) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.1), // very light border
            width: 1
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !widget.isCreating,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSubmit(),
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: theme.appTextPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontSize: scaledFontSize(13),
                    color: theme.appTextLight,
                  ),
                  prefixIcon: Icon(
                    Icons.add_location_alt_outlined,
                    size: 20,
                    color: theme.appPrimary.withOpacity(0.7),
                  ),
                  // border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                height: 38,
                width: 38,
                child: Material(
                  color: theme.appPrimary,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: widget.isCreating ? null : _handleSubmit,
                    borderRadius: BorderRadius.circular(10),
                    child: Center(
                      child: widget.isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
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

class _ParentSelector<T> extends StatelessWidget {
  final String label;
  final bool isLoading;
  final List<T> items;
  final T? selectedItem;
  final String Function(T item) itemName;
  final ValueChanged<T?> onChanged;
  final ThemeData theme;

  const _ParentSelector({
    required this.label,
    required this.isLoading,
    required this.items,
    required this.selectedItem,
    required this.itemName,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<T>(
        value: selectedItem,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        items: isLoading
            ? []
            : items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemName(item)),
                );
              }).toList(),
        onChanged: onChanged,
        hint: isLoading
            ? const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Loading...'),
                ],
              )
            : Text(label),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final String name;
  final bool isActive;
  final String subtitle;
  final ThemeData theme;
  final VoidCallback? onDelete;

  /// Renames this location. Receives the new name and reports whether the
  /// server accepted it, so the dialog can stay open on failure.
  final Future<bool> Function(String newName)? onRename;

  const _LocationTile({
    required this.name,
    required this.isActive,
    required this.subtitle,
    required this.theme,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.2), // very light border
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08), // light shadow
              blurRadius: 2,
              offset: const Offset(0, 2), // downward shadow
            ),
          ],
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: scaledFontSize(18),
              fontWeight: FontWeight.bold,
              color: theme.appPrimary,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: scaledFontSize(15),
                fontWeight: FontWeight.w600,
                color: theme.appTextPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: scaledFontSize(12),
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: scaledFontSize(13),
          color: theme.appTextSecondary,
        ),
      ),
      trailing: (onRename == null && onDelete == null)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRename != null)
                  IconButton(
                    tooltip: 'Rename',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.appPrimary.withOpacity(0.8),
                    ),
                    onPressed: () => _promptRename(context),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red.withOpacity(0.7),
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
    );
  }

  void _promptRename(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _RenameDialog(
        currentName: name,
        onSubmit: onRename!,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete "$name"?'),
        content: Text(
          'This will deactivate "$name". It can be reactivated later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Rename prompt for a state / district / mandal. Keeps itself open (with the
/// error inline) when the server rejects the change, so a typo or a network
/// blip doesn't lose what the admin typed.
class _RenameDialog extends StatefulWidget {
  final String currentName;
  final Future<bool> Function(String newName) onSubmit;

  const _RenameDialog({required this.currentName, required this.onSubmit});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentName,
  );
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newName = _controller.text.trim();
    if (newName.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    if (newName == widget.currentName) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final ok = await widget.onSubmit(newName);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isSaving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Rename location'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSaving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(
              fontSize: scaledFontSize(15),
              color: theme.appTextPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
