import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/user.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import 'admin_user_management_screen.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(adminUserManagementControllerProvider);
      controller.fetchUsers(authRepository: ref.read(authRepositoryProvider));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = ref.watch(adminUserManagementControllerProvider);

    final users = controller.users;
    final filteredUsers = _searchQuery.trim().isEmpty
        ? users
        : users.where((u) {
            final q = _searchQuery.toLowerCase();
            return u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.mobile.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: AutoScaledText(
          'User Management',
          style: TextStyle(
            fontSize: appFontSizeTitle,
            fontWeight: FontWeight.bold,
            color: theme.appTextPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: _UsersTab(
        searchController: _searchController,
        searchQuery: _searchQuery,
        onSearchChanged: (v) => setState(() => _searchQuery = v),
        isLoading: controller.isLoadingUsers,
        error: controller.usersError,
        users: filteredUsers,
        onRefresh: () => controller.fetchUsers(
          authRepository: ref.read(authRepositoryProvider),
          forceRefresh: true,
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
        tooltip: 'Add New User',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool isLoading;
  final String? error;
  final List<User> users;
  final Future<void> Function() onRefresh;

  const _UsersTab({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.isLoading,
    required this.error,
    required this.users,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search users by name, email, or mobile',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: theme.cardColor,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: Builder(
              builder: (context) {
                if (isLoading) {
                  return ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  );
                }

                if (error != null) {
                  return ListView(
                    children: [
                      const SizedBox(height: 80),
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Center(
                        child: AutoScaledText(
                          'Failed to load users',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: onRefresh,
                          child: const AutoScaledText('Retry'),
                        ),
                      ),
                    ],
                  );
                }

                if (users.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: AutoScaledText(
                          'No users found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: users.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 16,
                    color: theme.appDivider,
                  ),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final primaryRole = user.roles?.isNotEmpty == true
                        ? user.roles![0]
                        : null;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.appPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: AutoScaledText(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.appPrimary,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: AutoScaledText(
                              user.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.appTextPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: user.isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AutoScaledText(
                              user.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: user.isActive
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoScaledText(
                            user.mobile,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.appTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AutoScaledText(
                            'Role: ${primaryRole?.name ?? 'User'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.appTextLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
