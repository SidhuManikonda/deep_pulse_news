import 'package:deep_pulse_news/core/constants/app_constants.dart';
import 'package:deep_pulse_news/shared/widgets/auto_scaled_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/font_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/font_provider.dart';
import '../../core/services/onboarding_storage.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../extensions/user_extensions.dart';
import '../../features/admin/admin_user_management_hub_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final OnboardingStorage _storage = OnboardingStorage();

  location_models.State? _selectedState;
  District? _selectedDistrict;
  Mandal? _selectedMandal;
  Map<String, dynamic>? _selectedLanguage;
  List<Map<String, dynamic>> _selectedTopics = [];
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
  }

  Future<void> _loadLocationData() async {
    setState(() => _isLoadingLocation = true);
    try {
      final state = await _storage.getSelectedState();
      final district = await _storage.getSelectedDistrict();
      final mandal = await _storage.getSelectedMandal();
      final language = await _storage.getSelectedLanguage();
      final topics = await _storage.getSelectedTopics();

      setState(() {
        _selectedState = state;
        _selectedDistrict = district;
        _selectedMandal = mandal;
        _selectedLanguage = language;
        _selectedTopics = topics;
      });
    } catch (e) {
      // Handle error silently
    }
    setState(() => _isLoadingLocation = false);
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = ref.watch(authViewModelProvider);
    final user = authViewModel.user;
    final theme = Theme.of(context);
    final isAuthenticated = user != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: theme.appPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.appPrimary,
                      theme.appPrimary.withOpacity(0.8),
                      theme.appPrimaryDark,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Profile Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AutoScaledText(
                            isAuthenticated && user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'G', // G for Guest
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: theme.appPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // User Name or Guest
                      AutoScaledText(
                        isAuthenticated
                            ? (user.name.isNotEmpty ? user.name : 'User')
                            : 'Guest User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Location or Login prompt
                      AutoScaledText(
                        isAuthenticated
                            ? (user.email.isNotEmpty
                                  ? user.email
                                  : 'No email set')
                            : _getLocationDisplayText(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      // const Divider(),
                      // Center(
                      //   child: Row(
                      //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      //     children: [
                      //       AutoScaledText(
                      //         "Followers 150",
                      //         style: TextStyle(
                      //           fontSize: 14,
                      //           color: Colors.white.withOpacity(0.9),
                      //         ),
                      //       ),
                      //       Container(
                      //         color: Theme.of(context).appDivider,
                      //         width: 1,
                      //         height: 20,
                      //       ),
                      //       AutoScaledText(
                      //         "Following 150",
                      //         style: TextStyle(
                      //           fontSize: 14,
                      //           color: Colors.white.withOpacity(0.9),
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profile Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Section - conditional based on authentication
                  _buildSectionHeader('Account'),
                  const SizedBox(height: 12),
                  if (isAuthenticated)
                    _buildProfileCard([
                      _buildProfileTile(
                        icon: Icons.person_outline,
                        iconColor: theme.appPrimary,
                        title: 'Personal Information',
                        subtitle: user.name.isNotEmpty
                            ? user.name
                            : 'Update your details',
                        onTap: () => _showPersonalInfoSheet(context, user),
                      ),
                      _buildDivider(),
                      _buildProfileTile(
                        icon: Icons.phone_outlined,
                        iconColor: Colors.green,
                        title: 'Mobile Number',
                        subtitle: user.mobile.isNotEmpty
                            ? user.mobile
                            : 'Not set',
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildProfileTile(
                        icon: Icons.email_outlined,
                        iconColor: Colors.orange,
                        title: 'Email',
                        subtitle: user.email.isNotEmpty
                            ? user.email
                            : 'Not set',
                        trailing: user.emailVerifiedAt != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const AutoScaledText(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {},
                      ),
                    ])
                  else
                    _buildProfileCard([
                      _buildProfileTile(
                        icon: Icons.login,
                        iconColor: theme.appPrimary,
                        title: 'Login',
                        subtitle: 'Sign in to access all features',
                        onTap: () => Navigator.pushNamed(context, '/login'),
                      ),
                    ]),
                  const SizedBox(height: 24),

                  // Management Section - Only show for admin and sub-admin roles
                  if (isAuthenticated &&
                      (user.primaryRole.value == 'admin' ||
                          user.primaryRole.value == 'sub_admin')) ...[
                    _buildSectionHeader('Management'),
                    const SizedBox(height: 12),
                    _buildProfileCard([
                      _buildProfileTile(
                        icon: Icons.people_alt_outlined,
                        iconColor: theme.appPrimary,
                        title: 'User Management',
                        subtitle: 'View users and create new users',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminUserManagementHubScreen(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // Preferences Section
                  _buildSectionHeader('Preferences'),
                  const SizedBox(height: 12),
                  _buildProfileCard([
                    _buildProfileTile(
                      icon: Icons.language,
                      iconColor: Colors.blue,
                      title: 'Language',
                      subtitle: _getLanguageDisplayText(),
                      onTap: () => _navigateToLanguageSelection(context),
                    ),
                    _buildDivider(),
                    _buildProfileTile(
                      icon: Icons.location_on_outlined,
                      iconColor: Colors.red,
                      title: 'Location',
                      subtitle: _isLoadingLocation
                          ? 'Loading...'
                          : _getLocationDisplayText(),
                      onTap: () => _navigateToLocationChange(context),
                    ),
                    _buildDivider(),
                    _buildProfileTile(
                      icon: Icons.category_outlined,
                      iconColor: Colors.purple,
                      title: 'Topics',
                      subtitle: _getTopicsDisplayText(),
                      onTap: () => _navigateToTopicsSelection(context),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Settings Section
                  _buildSectionHeader('Settings'),
                  const SizedBox(height: 12),
                  _buildProfileCard([
                    _buildProfileTile(
                      icon: Icons.notifications_outlined,
                      iconColor: Colors.amber,
                      title: 'Notifications',
                      subtitle: 'Manage notifications',
                      onTap: () => _showNotificationSettings(context),
                    ),
                    _buildDivider(),
                    Builder(
                      builder: (context) {
                        final themeController = ref.watch(
                          themeControllerProvider,
                        );
                        return _buildProfileTile(
                          icon: Icons.dark_mode_outlined,
                          iconColor: Colors.indigo,
                          title: 'Dark Mode',
                          subtitle: themeController.isDarkMode ? 'On' : 'Off',
                          trailing: Switch(
                            value: themeController.isDarkMode,
                            onChanged: (value) {
                              ref
                                  .read(themeControllerProvider)
                                  .setDarkMode(value);
                            },
                            activeColor: theme.appPrimary,
                          ),
                          onTap: () {
                            ref.read(themeControllerProvider).toggleTheme();
                          },
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildProfileTile(
                      icon: Icons.text_fields,
                      iconColor: Colors.teal,
                      title: 'Font Size',
                      subtitle: ref
                          .watch(fontControllerProvider)
                          .currentFontSize
                          .displayName,
                      onTap: () => _showFontSizeSheet(context),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Support Section
                  _buildSectionHeader('Support'),
                  const SizedBox(height: 12),
                  _buildProfileCard([
                    _buildProfileTile(
                      icon: Icons.help_outline,
                      iconColor: Colors.cyan,
                      title: 'Help & Support',
                      subtitle: 'Get help with the app',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildProfileTile(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: Colors.grey,
                      title: 'Privacy Policy',
                      subtitle: 'Read our privacy policy',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildProfileTile(
                      icon: Icons.description_outlined,
                      iconColor: Colors.brown,
                      title: 'Terms of Service',
                      subtitle: 'Read our terms',
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildProfileTile(
                      icon: Icons.info_outline,
                      iconColor: Colors.blueGrey,
                      title: 'About',
                      subtitle: 'Version ${AppConstants.appVersion}',
                      onTap: () => _showAboutDialog(context),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Logout Button - Only show if authenticated
                  if (isAuthenticated) _buildLogoutButton(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return AutoScaledText(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headlineSmall?.color,
      ),
    );
  }

  Widget _buildProfileCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: AutoScaledText(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: AutoScaledText(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLogoutConfirmation(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 12),
                AutoScaledText(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 32),
            ),
            const SizedBox(height: 16),
            AutoScaledText(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            AutoScaledText(
              'Are you sure you want to logout?',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(ctx).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Theme.of(ctx).dividerColor),
                    ),
                    child: AutoScaledText(
                      'Cancel',
                      style: TextStyle(
                        color: Theme.of(ctx).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _handleLogout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const AutoScaledText(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final authViewModel = ref.read(authViewModelProvider);

    await authViewModel.logout();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showPersonalInfoSheet(BuildContext context, user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            AutoScaledText(
              'Personal Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow('Name', user?.name ?? 'Not set'),
            _buildInfoRow('Email', user?.email ?? 'Not set'),
            _buildInfoRow('Mobile', user?.mobile ?? 'Not set'),
            _buildInfoRow(
              'Role',
              user?.roles?.isNotEmpty == true ? user!.roles![0].name : 'User',
            ),
            _buildInfoRow(
              'Permissions',
              user?.roles?.isNotEmpty == true
                  ? '${user!.roles![0].permissions?.length ?? 0} permissions'
                  : 'Standard permissions',
            ),
            _buildInfoRow(
              'Account Status',
              user?.isActive == true ? 'Active' : 'Inactive',
            ),
            _buildInfoRow(
              'Member Since',
              user?.createdAt != null
                  ? '${user!.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'
                  : 'Unknown',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AutoScaledText(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          AutoScaledText(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLanguageSelection(BuildContext context) {
    Navigator.pushNamed(context, '/language-selection').then((_) {
      // Reload data when returning from language screen
      _loadLocationData();
    });
  }

  void _navigateToTopicsSelection(BuildContext context) {
    Navigator.pushNamed(context, '/topics-selection').then((_) {
      // Reload data when returning from topics screen
      _loadLocationData();
    });
  }

  String _getLocationDisplayText() {
    if (_isLoadingLocation) return 'Loading...';

    if (_selectedMandal != null &&
        _selectedDistrict != null &&
        _selectedState != null) {
      return '${_selectedMandal!.name}, ${_selectedDistrict!.name}, ${_selectedState!.name}';
    } else if (_selectedDistrict != null && _selectedState != null) {
      return '${_selectedDistrict!.name}, ${_selectedState!.name}';
    } else if (_selectedState != null) {
      return _selectedState!.name;
    }

    return 'Location not set';
  }

  String _getLanguageDisplayText() {
    if (_selectedLanguage != null) {
      return _selectedLanguage!['name'] ?? 'Language not set';
    }
    return 'Language not set';
  }

  String _getTopicsDisplayText() {
    if (_selectedTopics.isNotEmpty) {
      if (_selectedTopics.length == 1) {
        return _selectedTopics.first['name'] ?? '1 topic selected';
      } else {
        return '${_selectedTopics.length} topics selected';
      }
    }
    return 'No topics selected';
  }

  void _navigateToLocationChange(BuildContext context) {
    Navigator.pushNamed(context, '/location-selection').then((_) {
      // Reload location data when returning from location screen
      _loadLocationData();
    });
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: theme.appGrey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AutoScaledText(
                'Notification Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.appTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const AutoScaledText('Breaking News'),
                subtitle: const AutoScaledText(
                  'Get notified for breaking news',
                ),
                value: true,
                activeColor: theme.appPrimary,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const AutoScaledText('Daily Digest'),
                subtitle: const AutoScaledText('Receive daily news summary'),
                value: true,
                activeColor: theme.appPrimary,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const AutoScaledText('Sports Updates'),
                subtitle: const AutoScaledText('Get live sports updates'),
                value: false,
                activeColor: theme.appPrimary,
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Consumer(
          builder: (context, ref, child) {
            final fontController = ref.watch(fontControllerProvider);
            final currentFontSize = fontController.currentFontSize;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
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
                  const SizedBox(height: 24),
                  AutoScaledText(
                    'Font Size',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.headlineSmall?.color,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: FontSize.values.map((fontSize) {
                      return _buildFontSizeOption(
                        ctx,
                        fontSize.displayName,
                        fontSize.scale,
                        currentFontSize == fontSize,
                        () async {
                          await ref
                              .read(fontControllerProvider)
                              .setFontSize(fontSize);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFontSizeOption(
    BuildContext ctx,
    String label,
    double scale,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(ctx);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
          ),
        ),
        child: Column(
          children: [
            AutoScaledText(
              'Aa',
              style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            AutoScaledText(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Colors.white
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.appPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.newspaper,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const AutoScaledText('Deep Pulse News'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AutoScaledText('Version 1.0.0'),
              const SizedBox(height: 8),
              AutoScaledText(
                'Stay updated with the latest news from around the world. Deep Pulse News brings you breaking news, trending stories, and personalized content.',
                style: TextStyle(fontSize: 14, color: theme.appTextSecondary),
              ),
              const SizedBox(height: 16),
              AutoScaledText(
                '© 2026 Deep Pulse News',
                style: TextStyle(fontSize: 12, color: theme.appTextLight),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AutoScaledText('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 76,
      endIndent: 16,
      color: Theme.of(context).appDivider,
    );
  }
}
