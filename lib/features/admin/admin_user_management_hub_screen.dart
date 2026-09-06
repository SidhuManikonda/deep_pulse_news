import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/user.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/repositories/state_repository.dart';
import '../../data/repositories/district_repository.dart';
import '../../data/repositories/mandal_repository.dart';
import '../../enums/user_role.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';
import 'admin_user_management_screen.dart';
import 'user_comments_screen.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../shared/widgets/app_loader.dart';

class AdminUserManagementHubScreen extends ConsumerStatefulWidget {
  const AdminUserManagementHubScreen({super.key});

  @override
  ConsumerState<AdminUserManagementHubScreen> createState() =>
      _AdminUserManagementHubScreenState();
}

class _AdminUserManagementHubScreenState
    extends ConsumerState<AdminUserManagementHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRoleFilter;
  int? _selectedStateFilter;
  int? _selectedDistrictFilter;
  int? _selectedMandalFilter;

  location_models.State? _selectedStateObj;
  District? _selectedDistrictObj;
  Mandal? _selectedMandalObj;

  // Location name lookup maps for user cards
  Map<int, String> _districtNameMap = {};
  Map<int, String> _mandalNameMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(adminUserManagementControllerProvider);
      controller.fetchUsers(authRepository: ref.read(authRepositoryProvider), forceRefresh: true);
      controller.fetchRoles(authRepository: ref.read(authRepositoryProvider));
      final locationVM = ref.read(locationViewModelProvider);
      if (locationVM.states.isEmpty && !locationVM.isLoadingStates) {
        locationVM.loadStates();
      }
      // Sub-admin: auto-set state filter and load districts
      final user = ref.read(authViewModelProvider).user;
      debugPrint('🔍 HUB INIT: role=${user?.primaryRole.value}, stateId=${user?.stateId}, roles=${user?.roles?.map((r) => "${r.name}(${r.slug})").toList()}');
      if (user != null && user.primaryRole.value == 'sub_admin' && user.stateId != null) {
        setState(() {
          _selectedStateFilter = user.stateId;
        });
        locationVM.loadDistricts(user.stateId!);
      }
      _loadAllLocationNames();
    });
  }

  Future<void> _loadAllLocationNames() async {
    try {
      final stateRepo = StateRepositoryImpl();
      final districtRepo = DistrictRepositoryImpl();
      final mandalRepo = MandalRepositoryImpl();

      final states = await stateRepo.getStates();

      // Fetch districts in batches of 5 to avoid server overload
      final districtMap = <int, String>{};
      final allDistricts = <District>[];
      for (var i = 0; i < states.length; i += 5) {
        final batch = states.skip(i).take(5);
        final results = await Future.wait(
          batch.map((s) => districtRepo.getDistrictsByState(s.id)),
        );
        for (final list in results) {
          for (final d in list) {
            districtMap[d.id] = d.name;
            allDistricts.add(d);
          }
        }
      }

      if (mounted) setState(() => _districtNameMap = districtMap);

      // Fetch mandals in batches of 5
      final mandalMap = <int, String>{};
      for (var i = 0; i < allDistricts.length; i += 5) {
        final batch = allDistricts.skip(i).take(5);
        final results = await Future.wait(
          batch.map((d) => mandalRepo.getMandalsByDistrict(d.id)),
        );
        for (final list in results) {
          for (final m in list) {
            mandalMap[m.id] = m.name;
          }
        }
      }

      if (mounted) setState(() => _mandalNameMap = mandalMap);
    } catch (e) {
      debugPrint('Failed to load location names: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Both of these receive the backend's role name/slug, so they resolve it
  // through UserRole.fromApiSlug rather than matching raw strings — that's the
  // one place that knows "News Desk"/"newsdesk" is the role formerly slugged
  // `dist-reporter`.
  Color _getRoleColor(String? roleName) {
    switch (UserRole.fromApiSlug(roleName)) {
      case UserRole.admin:
        return const Color(0xFF6C5CE7);
      case UserRole.subAdmin:
        return const Color(0xFF0984E3);
      case UserRole.distReporter:
        return const Color(0xFF00B894);
      case UserRole.reporter:
        return const Color(0xFFF39C12);
      case UserRole.reader:
      case null:
        return const Color(0xFF636E72);
    }
  }

  IconData _getRoleIcon(String? roleName) {
    switch (UserRole.fromApiSlug(roleName)) {
      case UserRole.admin:
        return Icons.shield_outlined;
      case UserRole.subAdmin:
        return Icons.supervisor_account_outlined;
      case UserRole.distReporter:
        return Icons.edit_note_outlined;
      case UserRole.reporter:
        return Icons.campaign_outlined;
      case UserRole.reader:
      case null:
        return Icons.person_outline;
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedRoleFilter = null;
      _selectedStateFilter = null;
      _selectedStateObj = null;
      _selectedDistrictFilter = null;
      _selectedDistrictObj = null;
      _selectedMandalFilter = null;
      _selectedMandalObj = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(adminUserManagementControllerProvider);
    final currentUser = ref.read(authViewModelProvider).user;
    final currentRole = currentUser?.primaryRole.value ?? 'reader';
    final isAdmin = currentRole == 'admin';
    // Sub-admins manage users within their own state, so they get the same
    // change-role and block actions. They cannot hand out admin / sub_admin
    // roles — that list is filtered in [_showChangeRoleSheet].
    final canManageUsers = isAdmin || currentRole == 'sub_admin';
    final users = controller.users;
    final roleNames =
        users
            .map((u) => u.roleName)
            .where((r) => r != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

    // Exclude current user from the list
    final currentUserId = currentUser?.id;
    var filteredUsers = users.where((u) => u.userId != currentUserId && u.id != currentUserId).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredUsers = filteredUsers
          .where(
            (u) =>
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.mobile.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_selectedRoleFilter == 'staff') {
      filteredUsers = filteredUsers
          .where((u) => u.roleName?.toLowerCase() != 'reader')
          .toList();
    } else if (_selectedRoleFilter == 'readers') {
      filteredUsers = filteredUsers
          .where((u) => u.roleName?.toLowerCase() == 'reader')
          .toList();
    } else if (_selectedRoleFilter != null) {
      filteredUsers = filteredUsers
          .where((u) => u.roleName == _selectedRoleFilter)
          .toList();
    }

    if (_selectedStateFilter != null) {
      debugPrint('🔍 STATE FILTER: stateFilter=$_selectedStateFilter, before=${filteredUsers.length}, stateIds=${filteredUsers.map((u) => u.stateId).toSet().toList()}');
      filteredUsers = filteredUsers
          .where((u) => u.stateId == _selectedStateFilter)
          .toList();
      debugPrint('🔍 STATE FILTER: after=${filteredUsers.length}');
    }
    if (_selectedDistrictFilter != null) {
      filteredUsers = filteredUsers
          .where((u) => u.districtId == _selectedDistrictFilter)
          .toList();
    }
    if (_selectedMandalFilter != null) {
      filteredUsers = filteredUsers
          .where((u) => u.mandalId == _selectedMandalFilter)
          .toList();
    }

    // Counts based on role scope (excluding current user), not affected by search/filter chips
    var scopedUsers = users.where((u) => u.userId != currentUserId && u.id != currentUserId).toList();
    // Sub-admin: only count users in their state
    if (!isAdmin && currentUser?.stateId != null) {
      scopedUsers = scopedUsers.where((u) => u.stateId == currentUser!.stateId).toList();
    }
    final totalCount = scopedUsers.length;
    final staffCount = scopedUsers
        .where((u) => u.roleName?.toLowerCase() != 'reader')
        .length;
    final readerCount = scopedUsers
        .where((u) => u.roleName?.toLowerCase() == 'reader')
        .length;
    final hasActiveFilters =
        _selectedRoleFilter != null ||
        _selectedStateFilter != null ||
        _selectedDistrictFilter != null ||
        _selectedMandalFilter != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => controller.fetchUsers(
          authRepository: ref.read(authRepositoryProvider),
          forceRefresh: true,
        ),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: theme.appPrimary,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [theme.appPrimary, theme.appPrimaryDark],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(56, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'User Management',
                            style: TextStyle(
                              fontSize: scaledFontSize(22),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatPill(
                                '$totalCount',
                                'Total',
                                Colors.white,
                              ),
                              const SizedBox(width: 8),
                              _buildStatPill(
                                '$staffCount',
                                'Staff',
                                Colors.greenAccent,
                              ),
                              const SizedBox(width: 8),
                              _buildStatPill(
                                '$readerCount',
                                'Readers',
                                Colors.amber.shade200,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Search + Filters ──
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(fontSize: scaledFontSize(14)),
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        hintStyle: TextStyle(
                          color: theme.appTextLight,
                          fontSize: scaledFontSize(14),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.appTextLight,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: theme.appTextLight,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // Role filter chips
                  if (!controller.isLoadingUsers &&
                      controller.usersError == null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildChip('All', _selectedRoleFilter == null, () {
                            setState(() => _selectedRoleFilter = null);
                          }, theme),
                          _buildChip(
                            'Staff',
                            _selectedRoleFilter == 'staff',
                            () {
                              setState(
                                () => _selectedRoleFilter =
                                    _selectedRoleFilter == 'staff'
                                    ? null
                                    : 'staff',
                              );
                            },
                            theme,
                          ),
                          // _buildChip(
                          //     'Readers', _selectedRoleFilter == 'readers', () {
                          //   setState(() => _selectedRoleFilter =
                          //       _selectedRoleFilter == 'readers'
                          //           ? null
                          //           : 'readers');
                          // }, theme),
                          ...roleNames.map(
                            (role) => _buildChip(
                              role,
                              _selectedRoleFilter == role,
                              () {
                                setState(
                                  () => _selectedRoleFilter =
                                      _selectedRoleFilter == role ? null : role,
                                );
                              },
                              theme,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Location filter chips
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final locationVM = ref.watch(locationViewModelProvider);
                        return SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (isAdmin)
                              _buildLocationChip<location_models.State>(
                                label: _selectedStateObj?.name ?? 'All States',
                                icon: Icons.map_outlined,
                                isSelected: _selectedStateFilter != null,
                                items: locationVM.states,
                                getName: (s) => s.name,
                                onSelected: (s) {
                                  setState(() {
                                    _selectedStateFilter = s.id;
                                    _selectedStateObj = s;
                                    _selectedDistrictFilter = null;
                                    _selectedDistrictObj = null;
                                    _selectedMandalFilter = null;
                                    _selectedMandalObj = null;
                                  });
                                  ref
                                      .read(locationViewModelProvider)
                                      .loadDistricts(s.id);
                                },
                                onClear: () {
                                  setState(() {
                                    _selectedStateFilter = null;
                                    _selectedStateObj = null;
                                    _selectedDistrictFilter = null;
                                    _selectedDistrictObj = null;
                                    _selectedMandalFilter = null;
                                    _selectedMandalObj = null;
                                  });
                                },
                                theme: theme,
                              ),
                              if (_selectedStateFilter != null)
                                _buildLocationChip<District>(
                                  label:
                                      _selectedDistrictObj?.name ??
                                      'All Districts',
                                  icon: Icons.location_city_outlined,
                                  isSelected: _selectedDistrictFilter != null,
                                  items: locationVM.districts,
                                  getName: (d) => d.name,
                                  onSelected: (d) {
                                    setState(() {
                                      _selectedDistrictFilter = d.id;
                                      _selectedDistrictObj = d;
                                      _selectedMandalFilter = null;
                                      _selectedMandalObj = null;
                                    });
                                    ref
                                        .read(locationViewModelProvider)
                                        .loadMandals(d.id);
                                  },
                                  onClear: () {
                                    setState(() {
                                      _selectedDistrictFilter = null;
                                      _selectedDistrictObj = null;
                                      _selectedMandalFilter = null;
                                      _selectedMandalObj = null;
                                    });
                                  },
                                  theme: theme,
                                ),
                              if (_selectedDistrictFilter != null)
                                _buildLocationChip<Mandal>(
                                  label:
                                      _selectedMandalObj?.name ?? 'All Mandals',
                                  icon: Icons.place_outlined,
                                  isSelected: _selectedMandalFilter != null,
                                  items: locationVM.mandals,
                                  getName: (m) => m.name,
                                  onSelected: (m) {
                                    setState(() {
                                      _selectedMandalFilter = m.id;
                                      _selectedMandalObj = m;
                                    });
                                  },
                                  onClear: () {
                                    setState(() {
                                      _selectedMandalFilter = null;
                                      _selectedMandalObj = null;
                                    });
                                  },
                                  theme: theme,
                                ),
                              if (hasActiveFilters)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: GestureDetector(
                                    onTap: _clearAllFilters,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.2),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Reset',
                                            style: TextStyle(
                                              fontSize: scaledFontSize(12),
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Results count
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        hasActiveFilters || _searchQuery.isNotEmpty
                            ? 'Showing ${filteredUsers.length} of ${scopedUsers.length} users'
                            : '${filteredUsers.length} users',
                        style: TextStyle(
                          fontSize: scaledFontSize(12),
                          color: theme.appTextLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── User List ──
            _buildUserList(
              context,
              controller,
              filteredUsers,
              theme,
              isAdmin: isAdmin,
              canManageUsers: canManageUsers,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminUserManagementScreen(),
          ),
        ),
        backgroundColor: theme.appPrimary,
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
    );
  }

  // ── Stat Pill ──
  Widget _buildStatPill(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: scaledFontSize(14),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: scaledFontSize(11),
              color: color.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ── Role Filter Chip ──
  Widget _buildChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.appPrimary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.2), // very light border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // light shadow
                blurRadius: 6,
                offset: const Offset(0, 2), // downward shadow
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(12),
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : theme.appTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Location Filter Chip ──
  Widget _buildLocationChip<T>({
    required String label,
    required IconData icon,
    required bool isSelected,
    required List<T> items,
    required String Function(T) getName,
    required void Function(T) onSelected,
    required VoidCallback onClear,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          if (isSelected) {
            onClear();
            return;
          }
          if (items.isEmpty) return;
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            isScrollControlled: true,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            builder: (ctx) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: theme.appPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Select $label',
                          style: TextStyle(
                            fontSize: scaledFontSize(16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            getName(item),
                            style: TextStyle(fontSize: scaledFontSize(14)),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.appTextLight,
                          ),
                          onTap: () {
                            onSelected(item);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.appPrimary.withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.2), // very light border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // light shadow
                blurRadius: 6,
                offset: const Offset(0, 2), // downward shadow
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? theme.appPrimary : theme.appTextLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  fontWeight: FontWeight.w600,
                  color: isSelected ? theme.appPrimary : theme.appTextSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected ? Icons.close : Icons.keyboard_arrow_down,
                size: 16,
                color: isSelected ? theme.appPrimary : theme.appTextLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _buildLocationText(User user) {
    if (user.stateId == null) return null;
    final locationVM = ref.read(locationViewModelProvider);
    final parts = <String>[];

    final state = locationVM.states
        .where((s) => s.id == user.stateId)
        .firstOrNull;
    if (state != null) parts.add(state.name);

    if (user.districtId != null) {
      final districtName = _districtNameMap[user.districtId!];
      if (districtName != null) parts.add(districtName);
    }

    if (user.mandalId != null) {
      final mandalName = _mandalNameMap[user.mandalId!];
      if (mandalName != null) parts.add(mandalName);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  // ── User List ──
  Widget _buildUserList(
    BuildContext context,
    dynamic controller,
    List<User> filteredUsers,
    ThemeData theme, {
    bool isAdmin = false,
    bool canManageUsers = false,
  }) {
    if (controller.isLoadingUsers) {
      return const SliverFillRemaining(
        child: InlineLoader(message: 'Loading users...'),
      );
    }

    if (controller.usersError != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, color: theme.appTextLight, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load users',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w600,
                  color: theme.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pull down to try again',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: theme.appTextLight,
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => controller.fetchUsers(
                  authRepository: ref.read(authRepositoryProvider),
                  forceRefresh: true,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredUsers.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, color: theme.appTextLight, size: 48),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty ? 'No users yet' : 'No users found',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w600,
                  color: theme.appTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isEmpty
                    ? 'Tap + to add a new user'
                    : 'Try a different search or filter',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: theme.appTextLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final user = filteredUsers[index];
          final roleName = user.roleName?.toLowerCase();
          return _UserCard(
            user: user,
            roleColor: _getRoleColor(roleName),
            roleIcon: _getRoleIcon(roleName),
            locationText: _buildLocationText(user),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserCommentsScreen(user: user)),
            ),
            onDelete: () => _confirmDelete(user),
            onUpdatePassword: roleName != 'reader'
                ? () => _showUpdatePasswordSheet(user)
                : null,
            onToggleBlock: canManageUsers
                ? () => _confirmToggleBlock(user)
                : null,
            onChangeRole: canManageUsers
                ? () => _showChangeRoleSheet(user)
                : null,
            showMobile: isAdmin,
          );
        }, childCount: filteredUsers.length),
      ),
    );
  }

  // ── Update Password ──
  void _showUpdatePasswordSheet(User user) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.dividerColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Update Password',
                        style: TextStyle(
                          fontSize: scaledFontSize(18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set a new password for ${user.name}',
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: theme.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Please enter a password';
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: confirmController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) {
                          if (v != passwordController.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isLoading = true);

                                  final authRepo = ref.read(
                                    authRepositoryProvider,
                                  );
                                  final success = await authRepo.updatePassword(
                                    user.userId ?? user.id,
                                    passwordController.text,
                                  );

                                  setSheetState(() => isLoading = false);

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Password updated for ${user.name}'
                                              : 'Failed to update password',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Update Password',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Change Role (admin only) ──
  Future<void> _showChangeRoleSheet(User user) async {
    final controller = ref.read(adminUserManagementControllerProvider);
    final authRepo = ref.read(authRepositoryProvider);

    // Ensure roles are loaded before opening the sheet.
    if (controller.roles.isEmpty && !controller.isLoadingRoles) {
      await controller.fetchRoles(authRepository: authRepo);
    }
    if (!mounted) return;

    final theme = Theme.of(context);
    final currentRoleId = user.roles?.isNotEmpty == true
        ? user.roles!.first.id
        : null;

    // A sub-admin may reassign users below them, but must never be able to
    // create an admin or another sub-admin. Same rule as the role dropdown in
    // admin_user_management_screen.
    final actingRole =
        ref.read(authViewModelProvider).user?.primaryRole.value ?? 'reader';
    final assignableRoles = actingRole == 'sub_admin'
        ? controller.roles.where((role) {
            final slug =
                role.slug?.toLowerCase() ??
                role.name.toLowerCase().replaceAll(' ', '_');
            return slug != 'admin' && slug != 'sub_admin' && slug != 'sub-admin';
          }).toList()
        : controller.roles;

    final pickedRoleId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Change role',
                    style: TextStyle(
                      fontSize: scaledFontSize(18),
                      fontWeight: FontWeight.w700,
                      color: theme.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Select a new role for ${user.name}',
                    style: TextStyle(
                      fontSize: scaledFontSize(13),
                      color: theme.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (controller.isLoadingRoles)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (assignableRoles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No roles available',
                          style: TextStyle(
                            color: theme.appTextLight,
                            fontSize: scaledFontSize(13),
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: assignableRoles.length,
                        itemBuilder: (_, i) {
                          final role = assignableRoles[i];
                          final isCurrent = role.id == currentRoleId;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _getRoleIcon(role.name),
                              size: 20,
                              color: _getRoleColor(role.name),
                            ),
                            title: Text(
                              role.name,
                              style: TextStyle(
                                fontSize: scaledFontSize(14),
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: theme.appTextPrimary,
                              ),
                            ),
                            trailing: isCurrent
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.appPrimary,
                                    size: 20,
                                  )
                                : null,
                            onTap: isCurrent
                                ? null
                                : () => Navigator.pop(ctx, role.id),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    if (pickedRoleId == null || !mounted) return;
    if (pickedRoleId == currentRoleId) return;

    final newRole = controller.roles.firstWhere((r) => r.id == pickedRoleId);

    // Backend requires state_id/district_id/mandal_id on PUT /user/{id}
    // regardless of role. So always ask the admin to pick a full location
    // when changing role — defaults to the target user's current values
    // (which may be null for sub-admins or readers).
    final picked = await _showAssignLocationSheet(user, newRole);
    if (picked == null || !mounted) return;

    final success = await authRepo.updateUserRole(
      existingUser: user,
      newRoleId: pickedRoleId,
      overrideStateId: picked.stateId,
      overrideDistrictId: picked.districtId,
      overrideMandalId: picked.mandalId,
    );

    if (success) {
      await controller.fetchUsers(
        authRepository: authRepo,
        forceRefresh: true,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${user.name}\'s role updated'
                : 'Failed to update role',
          ),
          backgroundColor: success ? Colors.green[600] : Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  /// Bottom sheet: pick state / district / mandal for a role change. Returns
  /// null if the admin cancels. State/district/mandal are all required —
  /// the backend's PUT /user/{id} rejects partial location data.
  Future<({int stateId, int districtId, int mandalId})?>
      _showAssignLocationSheet(User user, Role newRole) async {
    final locationVM = ref.read(locationViewModelProvider);

    // Preload states. Districts/mandals come later based on the picked state.
    if (locationVM.states.isEmpty && !locationVM.isLoadingStates) {
      await locationVM.loadStates();
    }

    int? pickedStateId = user.stateId;
    int? pickedDistrictId = user.districtId;
    int? pickedMandalId = user.mandalId;

    // Pre-load child lists if we already know the parent IDs.
    if (pickedStateId != null) {
      await locationVM.loadDistricts(pickedStateId);
    }
    if (pickedDistrictId != null) {
      await locationVM.loadMandals(pickedDistrictId);
    }

    if (!mounted) return null;
    final theme = Theme.of(context);

    return showModalBottomSheet<({int stateId, int districtId, int mandalId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final vm = ref.read(locationViewModelProvider);
            final pickedState = vm.states
                .where((s) => s.id == pickedStateId)
                .firstOrNull;
            final pickedDistrict = vm.districts
                .where((d) => d.id == pickedDistrictId)
                .firstOrNull;
            final pickedMandal = vm.mandals
                .where((m) => m.id == pickedMandalId)
                .firstOrNull;

            final canSubmit = pickedStateId != null &&
                pickedDistrictId != null &&
                pickedMandalId != null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Assign location',
                      style: TextStyle(
                        fontSize: scaledFontSize(18),
                        fontWeight: FontWeight.w700,
                        color: theme.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Setting ${user.name} as "${newRole.name}". Pick a '
                      'state, district and mandal.',
                      style: TextStyle(
                        fontSize: scaledFontSize(12),
                        color: theme.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LocationField(
                      label: 'State',
                      icon: Icons.map_outlined,
                      valueText: pickedState?.name ?? 'Choose state',
                      theme: theme,
                      onTap: () async {
                        final s = await _pickFromList<location_models.State>(
                          title: 'Select State',
                          items: vm.states,
                          getName: (s) => s.name,
                          theme: theme,
                        );
                        if (s == null) return;
                        await locationVM.loadDistricts(s.id);
                        setSheetState(() {
                          pickedStateId = s.id;
                          pickedDistrictId = null;
                          pickedMandalId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _LocationField(
                      label: 'District',
                      icon: Icons.location_city_outlined,
                      valueText: pickedDistrict?.name ??
                          (pickedStateId == null
                              ? 'Pick state first'
                              : 'Choose district'),
                      enabled: pickedStateId != null,
                      theme: theme,
                      onTap: () async {
                        final d = await _pickFromList<District>(
                          title: 'Select District',
                          items: vm.districts,
                          getName: (d) => d.name,
                          theme: theme,
                        );
                        if (d == null) return;
                        await locationVM.loadMandals(d.id);
                        setSheetState(() {
                          pickedDistrictId = d.id;
                          pickedMandalId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _LocationField(
                      label: 'Mandal',
                      icon: Icons.place_outlined,
                      valueText: pickedMandal?.name ??
                          (pickedDistrictId == null
                              ? 'Pick district first'
                              : 'Choose mandal'),
                      enabled: pickedDistrictId != null,
                      theme: theme,
                      onTap: () async {
                        final m = await _pickFromList<Mandal>(
                          title: 'Select Mandal',
                          items: vm.mandals,
                          getName: (m) => m.name,
                          theme: theme,
                        );
                        if (m == null) return;
                        setSheetState(() => pickedMandalId = m.id);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () => Navigator.pop(
                                  ctx,
                                  (
                                    stateId: pickedStateId!,
                                    districtId: pickedDistrictId!,
                                    mandalId: pickedMandalId!,
                                  ),
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.appPrimary,
                          disabledBackgroundColor: theme.dividerColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Apply change',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Reusable searchable list picker for state / district / mandal selection.
  ///
  /// The search box isn't decoration: Andhra Pradesh alone has 28 districts and
  /// a district carries 25-odd mandals, so finding one by scrolling a flat list
  /// meant hunting through a half-screen sheet. Typing two or three letters is
  /// the difference between a moment and a scroll hunt, and every other place
  /// the app picks a location (onboarding, profile, news upload) already lets
  /// you search — this sheet was the odd one out.
  Future<T?> _pickFromList<T>({
    required String title,
    required List<T> items,
    required String Function(T) getName,
    required ThemeData theme,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final trimmed = query.trim().toLowerCase();
            final visible = trimmed.isEmpty
                ? items
                : items
                      .where(
                        (item) => getName(item).toLowerCase().contains(trimmed),
                      )
                      .toList();

            return Padding(
              // Lifts the sheet above the keyboard, so the list the admin is
              // filtering doesn't end up behind it.
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: scaledFontSize(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        onChanged: (v) => setSheetState(() => query = v),
                        style: TextStyle(fontSize: scaledFontSize(14)),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(
                            color: theme.appTextLight,
                            fontSize: scaledFontSize(14),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20,
                            color: theme.appTextLight,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  const Divider(height: 1),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No items available',
                        style: TextStyle(
                          color: theme.appTextLight,
                          fontSize: scaledFontSize(13),
                        ),
                      ),
                    )
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nothing matches "${query.trim()}"',
                        style: TextStyle(
                          color: theme.appTextLight,
                          fontSize: scaledFontSize(13),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        // Lets a drag on the list dismiss the keyboard instead
                        // of the admin having to reach for Back first.
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: visible.length,
                        itemBuilder: (_, i) {
                          final item = visible[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                              getName(item),
                              style: TextStyle(fontSize: scaledFontSize(14)),
                            ),
                            onTap: () => Navigator.pop(ctx, item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Delete Confirmation ──
  Future<void> _confirmDelete(User user) async {
    final theme = Theme.of(context);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_remove_outlined,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete "${user.name}"?',
              style: TextStyle(
                fontSize: scaledFontSize(18),
                fontWeight: FontWeight.w700,
                color: theme.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: scaledFontSize(14),
                color: theme.appTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(adminUserManagementControllerProvider);
      final success = await controller.deleteUser(
        authRepository: ref.read(authRepositoryProvider),
        userId: user.id ,
      );
      if (success) {
        controller.fetchUsers(
          authRepository: ref.read(authRepositoryProvider),
          forceRefresh: true,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? '${user.name} deleted' : 'Failed to delete user',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── Toggle Block (admin only) ──
  Future<void> _confirmToggleBlock(User user) async {
    final isBlocked = user.isBlockedByAdmin;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isBlocked ? 'Unblock User' : 'Block User'),
        content: Text(
          isBlocked
              ? 'Are you sure you want to unblock ${user.name}? They will regain access.'
              : 'Are you sure you want to block ${user.name}? They will lose access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final authRepo = ref.read(authRepositoryProvider);
    final success = await authRepo.toggleBlockUser(
      user.userId ?? user.id,
      block: !isBlocked,
    );

    if (success) {
      final controller = ref.read(adminUserManagementControllerProvider);
      await controller.fetchUsers(
        authRepository: authRepo,
        forceRefresh: true,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isBlocked ? '${user.name} unblocked' : '${user.name} blocked')
                : 'Failed to update block status',
          ),
          backgroundColor: success ? Colors.green[600] : Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}

// ─── User Card ──────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final User user;
  final Color roleColor;
  final IconData roleIcon;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onUpdatePassword;
  final VoidCallback? onToggleBlock;
  final VoidCallback? onChangeRole;
  final String? locationText;
  final bool showMobile;

  const _UserCard({
    required this.user,
    required this.roleColor,
    required this.roleIcon,
    required this.onTap,
    required this.onDelete,
    this.onUpdatePassword,
    this.onToggleBlock,
    this.onChangeRole,
    this.locationText,
    this.showMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        shadowColor: Colors.black.withOpacity(0.05),
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.1), // very light border
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Top section: Avatar + Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: scaledFontSize(18),
                              fontWeight: FontWeight.w700,
                              color: roleColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.name,
                                    style: TextStyle(
                                      fontSize: scaledFontSize(14),
                                      fontWeight: FontWeight.w600,
                                      color: theme.appTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        roleIcon,
                                        size: 12,
                                        color: roleColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.roleName ?? 'User',
                                        style: TextStyle(
                                          fontSize: scaledFontSize(11),
                                          fontWeight: FontWeight.w600,
                                          color: roleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (showMobile) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 13,
                                    color: theme.appTextLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.mobile,
                                    style: TextStyle(
                                      fontSize: scaledFontSize(12),
                                      color: theme.appTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (locationText != null &&
                                locationText!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: theme.appTextLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      locationText!,
                                      style: TextStyle(
                                        fontSize: scaledFontSize(11),
                                        color: theme.appTextLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom action bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  // Wrap (not Row) so chips flow to a second line on narrow
                  // screens — with four actions (Update Password, Change Role,
                  // Block, Delete) Row was overflowing horizontally.
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // if (onUpdatePassword != null)
                      //   _buildActionChip(
                      //     icon: Icons.key_outlined,
                      //     label: 'Password',
                      //     color: Colors.deepPurple,
                      //     onTap: onUpdatePassword!,
                      //   ),
                      if (onChangeRole != null)
                        _buildActionChip(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Change Role',
                          color: const Color(0xFF0984E3),
                          onTap: onChangeRole!,
                        ),
                      if (onToggleBlock != null)
                        _buildActionChip(
                          icon: user.isBlockedByAdmin
                              ? Icons.lock_open
                              : Icons.block,
                          label: user.isBlockedByAdmin ? 'Unblock' : 'Block',
                          color: user.isBlockedByAdmin ? Colors.green : Colors.orange,
                          onTap: onToggleBlock!,
                        ),
                      _buildActionChip(
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: Colors.red,
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: scaledFontSize(11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form-row used in the change-role location sheet. Shows a labelled,
/// tappable field with the currently-picked value (or a placeholder when
/// nothing is set yet, or a "Pick parent first" hint when disabled).
class _LocationField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String valueText;
  final bool enabled;
  final ThemeData theme;
  final VoidCallback onTap;

  const _LocationField({
    required this.label,
    required this.icon,
    required this.valueText,
    required this.theme,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? theme.scaffoldBackgroundColor
              : theme.dividerColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled ? theme.appPrimary : theme.appTextLight,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: scaledFontSize(11),
                      color: theme.appTextLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valueText,
                    style: TextStyle(
                      fontSize: scaledFontSize(14),
                      color: enabled
                          ? theme.appTextPrimary
                          : theme.appTextLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: enabled ? theme.appTextSecondary : theme.appTextLight,
            ),
          ],
        ),
      ),
    );
  }
}
