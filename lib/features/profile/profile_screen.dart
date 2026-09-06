import 'dart:async';

import 'package:deep_pulse_news/core/constants/app_constants.dart';
import 'package:deep_pulse_news/core/services/media_picker_services.dart';
import 'package:deep_pulse_news/features/admin/location_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/user.dart';
import '../../providers/app_providers.dart';
import 'saved_news_screen.dart';
import '../../shared/widgets/cached_image_widget.dart';
import '../../core/services/onboarding_storage.dart';
import '../../core/services/push_notification_service.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../extensions/user_extensions.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/auth_helper.dart';
import '../../features/admin/admin_user_management_hub_screen.dart';
import '../../features/admin/ads_management_screen.dart';
import '../../features/admin/news_management_screen.dart';
import '../../core/constants/app_font_sizes.dart';
import '../home/home_view_model.dart';

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
  bool _isUploadingPhoto = false;

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

    // ── New UI ─────────────────────────────────────────────────────────
    return _buildNewScreen(context, user, theme, isAuthenticated);
  }

  Widget _buildNewScreen(
    BuildContext context,
    User? user,
    ThemeData theme,
    bool isAuthenticated,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildNewHeader(context, user, theme, isAuthenticated),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Account
                _buildNewSectionHeader('Account'),
                _buildNewProfileCard([
                  if (!isAuthenticated)
                    _buildNewTile(
                      context: context,
                      icon: Icons.login_rounded,
                      iconBg: theme.appPrimary,
                      title: 'Login',
                      subtitle: 'Sign in to access all features',
                      onTap: () => Navigator.pushNamed(context, '/gmail-sso'),
                    ),
                  if (isAuthenticated)
                    _buildNewTile(
                      context: context,
                      icon: Icons.person_outline_rounded,
                      iconBg: const Color(0xFF4A80F0),
                      title: 'Personal Information',
                      subtitle: 'View your account details',
                      showDivider: true,
                      onTap: () => _showPersonalInfoSheet(context, user),
                    ),
                  _buildNewTile(
                    context: context,
                    icon: Icons.bookmark_outline,
                    iconBg: const Color(0xFF7B61FF),
                    title: 'Saved News',
                    subtitle: 'View your saved articles',
                    onTap: () async {
                      final isAuthenticated = await AuthHelper.requireAuth(
                        context,
                        ref,
                        title: 'Login to View Saved News',
                        message: 'Please login to view your saved articles.',
                      );
                      if (!isAuthenticated || !mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SavedNewsScreen(),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // Management — admins/subadmins/dist-reporters only
                if (isAuthenticated &&
                    (user!.primaryRole.value == 'admin' ||
                        user.primaryRole.value == 'sub_admin' ||
                        user.primaryRole.value == 'dist-reporter')) ...[
                  _buildNewSectionHeader('Management'),
                  _buildNewProfileCard([
                    if (user.primaryRole.value == 'admin' ||
                        user.primaryRole.value == 'sub_admin') ...[
                      _buildNewTile(
                        context: context,
                        icon: Icons.people_alt_outlined,
                        iconBg: const Color(0xFF4A80F0),
                        title: 'User Management',
                        subtitle: 'View users and create new users',
                        showDivider: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AdminUserManagementHubScreen(),
                          ),
                        ),
                      ),
                    ],
                    _buildNewTile(
                      context: context,
                      icon: Icons.newspaper_outlined,
                      iconBg: const Color(0xFF28C76F),
                      title: 'News Management',
                      subtitle: 'Manage pending, published & rejected news',
                      // Ads Management follows for every role that reaches
                      // this card, so the divider is unconditional now.
                      showDivider: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NewsManagementScreen(),
                        ),
                      ),
                    ),
                    // Ads Management — admin, sub-admin and News Desk. Same
                    // audience as News Management, since ad inventory is run
                    // by whoever runs the desk.
                    _buildNewTile(
                      context: context,
                      icon: Icons.campaign_outlined,
                      iconBg: const Color(0xFF7B61FF),
                      title: 'Ads Management',
                      subtitle: 'Create & schedule adverts shown in the feed',
                      showDivider:
                          user.primaryRole.value == 'admin' ||
                          user.primaryRole.value == 'sub_admin',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdsManagementScreen(),
                        ),
                      ),
                    ),
                    if (user.primaryRole.value == 'admin' ||
                        user.primaryRole.value == 'sub_admin')
                      _buildNewTile(
                        context: context,
                        icon: Icons.location_city_outlined,
                        iconBg: const Color(0xFFFF9F43),
                        title: 'Location Management',
                        subtitle: 'Manage states, districts & mandals',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LocationManagementScreen(),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 20),
                ],

                // Preferences
                _buildNewSectionHeader('Preferences'),
                _buildNewProfileCard([
                  Builder(
                    builder: (ctx) {
                      final role = user?.primaryRole.value ?? 'reader';
                      final isLocked = role == 'reporter';
                      final isSubAdmin = role == 'sub_admin';
                      final isDistrictReporter = role == 'dist-reporter';
                      return _buildNewTile(
                        context: ctx,
                        icon: Icons.location_on_outlined,
                        iconBg: const Color(0xFF7B61FF),
                        title: 'Location',
                        subtitle: _isLoadingLocation
                            ? 'Loading...'
                            : isLocked
                            ? '${_getLocationDisplayText()} (Assigned)'
                            : isSubAdmin
                            ? '${_getLocationDisplayText()} (Change District/Mandal)'
                            : isDistrictReporter
                            ? '${_getLocationDisplayText()} (Change Mandal)'
                            : _getLocationDisplayText(),
                        trailing: isLocked
                            ? Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: theme.appGrey400,
                              )
                            : null,
                        onTap: isLocked
                            ? () => ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Location is assigned by admin and cannot be changed',
                                  ),
                                ),
                              )
                            : isSubAdmin
                            ? () => _showDistrictMandalPicker(ctx, user)
                            : isDistrictReporter
                            ? () => _showMandalPicker(ctx, user)
                            : () => _showFullLocationPicker(ctx),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // Support
                _buildNewSectionHeader('Support'),
                _buildNewProfileCard([
                  _buildNewTile(
                    context: context,
                    icon: Icons.info_outline,
                    iconBg: Colors.blueGrey,
                    title: 'About',
                    subtitle: 'Version ${AppConstants.appVersion}',
                    onTap: () => _showAboutDialog(context),
                  ),
                ]),
                const SizedBox(height: 24),

                if (isAuthenticated) _buildNewLogoutButton(context),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewHeader(
    BuildContext context,
    User? user,
    ThemeData theme,
    bool isAuthenticated,
  ) {
    return Container(
      decoration: BoxDecoration(gradient: theme.heroGradient),
      child: Stack(
        children: [
          // Decorative circles — translucent white orbs on the dark gradient
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 55,
            left: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 70,
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 28),
              child: Column(
                children: [
                  // Back button row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Avatar with edit badge
                  Stack(
                    children: [
                      GestureDetector(
                        onTap:
                            isAuthenticated &&
                                (user?.profilePhoto?.isNotEmpty ?? false)
                            ? () => _openProfilePhotoFullScreen(
                                _sizedGooglePhoto(
                                  user!.profilePhoto!,
                                  1080,
                                  cropToSquare: false,
                                ),
                              )
                            : null,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              isAuthenticated &&
                                  (user?.profilePhoto?.isNotEmpty ?? false)
                              ? CachedImageWidget(
                                  // Use ~400px source so the 88-pt circle
                                  // stays crisp at 3x device pixel ratio
                                  // (264 actual px) — Google's default
                                  // `=s96-c` was upscaling and blurring.
                                  imageUrl: _sizedGooglePhoto(
                                    user!.profilePhoto!,
                                    400,
                                  ),
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  errorWidget: Center(
                                    child: Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    isAuthenticated && user!.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'G',
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: isAuthenticated && !_isUploadingPhoto
                              ? () => _showPhotoPickerSheet(context)
                              : null,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            child: _isUploadingPhoto
                                ? Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.appPrimaryDark,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt_rounded,
                                    color: theme.appPrimaryDark,
                                    size: 14,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isAuthenticated
                        ? (user!.name.isNotEmpty ? user.name : 'User')
                        : 'Guest User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAuthenticated
                        ? (user!.email.isNotEmpty ? user.email : 'No email set')
                        : _getLocationDisplayText(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: scaledFontSize(15),
          fontWeight: FontWeight.bold,
          color: Theme.of(context).appTextPrimary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildNewProfileCard(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNewTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? trailing,
    bool showDivider = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconBg, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: scaledFontSize(14),
                          fontWeight: FontWeight.w600,
                          color: theme.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: scaledFontSize(12),
                          color: theme.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: theme.appGrey400,
                      size: 20,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: theme.appDivider,
          ),
      ],
    );
  }

  Widget _buildNewLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLogoutConfirmation(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: scaledFontSize(14),
                fontWeight: FontWeight.w600,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
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
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red.shade700,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Delete account?',
                  style: TextStyle(
                    fontSize: scaledFontSize(20),
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineSmall?.color,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'This will permanently:',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 6),
              _deleteBulletPoint(ctx, 'Deactivate your account on the server'),
              _deleteBulletPoint(
                ctx,
                'Stop all push notifications to your devices',
              ),
              _deleteBulletPoint(ctx, 'Log you out everywhere'),
              const SizedBox(height: 10),
              Text(
                'You cannot recover this account afterwards.',
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  color: theme.textTheme.bodyMedium?.color,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 22),
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
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _handleDeleteAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
        );
      },
    );
  }

  Widget _deleteBulletPoint(BuildContext ctx, String text) {
    final theme = Theme.of(ctx);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: scaledFontSize(13),
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rewrites a Google profile photo URL to request a specific pixel size.
  /// `cropToSquare: true` keeps Google's `-c` suffix (square center-crop) —
  /// good for the circular avatar. `cropToSquare: false` drops the `-c` so
  /// the full-screen viewer gets the photo at its native aspect ratio
  /// instead of a square crop letterboxed inside a portrait viewport.
  String _sizedGooglePhoto(String url, int size, {bool cropToSquare = true}) {
    if (!url.contains('googleusercontent.com')) return url;
    final suffix = cropToSquare ? '=s$size-c' : '=s$size';
    final sizeMatch = RegExp(r'=s\d+(-c)?$');
    if (sizeMatch.hasMatch(url)) {
      return url.replaceFirst(sizeMatch, suffix);
    }
    return '$url$suffix';
  }

  void _openProfilePhotoFullScreen(String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _FullScreenPhotoViewer(imageUrl: url),
      ),
    );
  }

  void _showPhotoPickerSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Update profile photo',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.appPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: theme.appPrimary,
                  size: 22,
                ),
              ),
              title: Text(
                'Choose from gallery',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(fromCamera: false);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 22,
                ),
              ),
              title: Text(
                'Take a photo',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(fromCamera: true);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto({required bool fromCamera}) async {
    final picker = MediaPickerService();
    try {
      final file = fromCamera
          ? await picker.capturePhoto()
          : (await picker.pickImages()).firstOrNull;
      if (file == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);
      final authViewModel = ref.read(authViewModelProvider);
      final success = await authViewModel.updateProfileImage(file);

      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile photo updated'
                : (authViewModel.error ?? 'Failed to upload profile photo'),
          ),
          backgroundColor: success
              ? const Color(0xFF16A34A)
              : Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleDeleteAccount() async {
    // Block UI with a loading indicator while the request is in flight.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final authViewModel = ref.read(authViewModelProvider);
    final success = await authViewModel.deleteAccount();

    if (!mounted) return;
    // Dismiss the loading dialog.
    Navigator.of(context).pop();

    if (success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/gmail-sso',
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not delete account. Please try again.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════
  // OLD UI METHODS (kept for reference — unused)
  // ════════════════════════════════════════════════════════

  // ignore: unused_element
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: scaledFontSize(16),
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.headlineSmall?.color,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProfileCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(
            context,
          ).dividerColor.withOpacity(0.1), // very light border
          width: 1,
        ),
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

  // ignore: unused_element
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
      title: Text(
        title,
        style: TextStyle(
          fontSize: scaledFontSize(13),
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: scaledFontSize(12),
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

  // ignore: unused_element
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
              children: [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
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
            Text(
              'Logout',
              style: TextStyle(
                fontSize: scaledFontSize(20),
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                fontSize: scaledFontSize(14),
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
                    child: Text(
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
                    child: const Text(
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
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/gmail-sso',
        (route) => false,
      );
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
          color: Colors.white,
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
            Text(
              'Personal Information',
              style: TextStyle(
                fontSize: scaledFontSize(20),
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow('Name', user?.name ?? 'Not set'),
            _buildInfoRow('Email', user?.email ?? 'Not set'),
            // _buildInfoRow('Mobile', user?.mobile ?? 'Not set'),
            _buildInfoRow(
              'Role',
              user?.roles?.isNotEmpty == true ? user!.roles![0].name : 'User',
            ),
            // _buildInfoRow(
            //   'Permissions',
            //   user?.roles?.isNotEmpty == true
            //       ? '${user!.roles![0].permissions?.length ?? 0} permissions'
            //       : 'Standard permissions',
            // ),
            // _buildInfoRow(
            //   'Account Status',
            //   user?.isActive == true ? 'Active' : 'Inactive',
            // ),
            // _buildInfoRow(
            //   'Member Since',
            //   user?.createdAt != null
            //       ? '${user!.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'
            //       : 'Unknown',
            // ),
            const SizedBox(height: 8),
            // Visual + semantic separation: regular account info above,
            // destructive action below. Placed inside this sheet so it's only
            // reached via the deliberate "edit profile" gesture, not from the
            // main screen where an accidental tap could happen.
            Divider(color: Theme.of(context).dividerColor.withOpacity(0.4)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                // Close this sheet first, then open the confirmation
                // — stacking two modal sheets feels janky.
                Navigator.pop(context);
                _showDeleteAccountConfirmation(this.context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete account',
                            style: TextStyle(
                              fontSize: scaledFontSize(14),
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Permanently remove your account and data',
                            style: TextStyle(
                              fontSize: scaledFontSize(11),
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.red.shade300,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
          Text(
            label,
            style: TextStyle(
              fontSize: scaledFontSize(14),
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: scaledFontSize(14),
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
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

  // ignore: unused_element
  String _getLanguageDisplayText() {
    if (_selectedLanguage != null) {
      return _selectedLanguage!['name'] ?? 'Language not set';
    }
    return 'Language not set';
  }

  // ignore: unused_element
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

  bool _isLocationPickerOpen = false;

  void _showFullLocationPicker(BuildContext context) async {
    if (_isLocationPickerOpen) return;
    _isLocationPickerOpen = true;

    final theme = Theme.of(context);
    final locationVM = ref.read(locationViewModelProvider);

    if (locationVM.states.isEmpty && !locationVM.isLoadingStates) {
      await locationVM.loadStates();
    }

    if (!mounted) {
      _isLocationPickerOpen = false;
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: _FullLocationPickerContent(
            theme: theme,
            states: locationVM.states,
            locationVM: locationVM,
            currentStateId: _selectedState?.id,
            currentDistrictId: _selectedDistrict?.id,
            currentMandalId: _selectedMandal?.id,
            onSave: (state, district, mandal) async {
              Navigator.pop(ctx);
              await ref
                  .read(authViewModelProvider)
                  .applyManualLocation(state, district, mandal);
              // Re-register the device so push targeting follows the new
              // location instead of the one picked at onboarding.
              unawaited(PushNotificationService.instance.onLocationChanged());
              _loadLocationData();
              final homeVM = ref.read(homeViewModelProvider);
              homeVM.loadLocationData().then((_) => homeVM.loadNewsData());
            },
          ),
        );
      },
    ).then((_) => _isLocationPickerOpen = false);
  }

  void _showDistrictMandalPicker(BuildContext context, User? user) async {
    if (user == null || user.stateId == null) return;
    if (_isLocationPickerOpen) return;
    _isLocationPickerOpen = true;

    final theme = Theme.of(context);
    final locationVM = ref.read(locationViewModelProvider);

    await locationVM.loadDistricts(user.stateId!);

    if (!mounted) {
      _isLocationPickerOpen = false;
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: _DistrictMandalPickerContent(
            theme: theme,
            districts: locationVM.districts,
            currentDistrictId: user.districtId,
            currentMandalId: user.mandalId,
            locationVM: locationVM,
            onSave: (District district, Mandal mandal) async {
              Navigator.pop(ctx);

              final storage = OnboardingStorage();
              final state = await storage.getSelectedState();
              if (state != null) {
                await ref
                    .read(authViewModelProvider)
                    .applyManualLocation(state, district, mandal);
                unawaited(PushNotificationService.instance.onLocationChanged());
              }

              _loadLocationData();
              final homeVM = ref.read(homeViewModelProvider);
              homeVM.loadLocationData().then((_) => homeVM.loadNewsData());
            },
          ),
        );
      },
    ).then((_) => _isLocationPickerOpen = false);
  }

  void _showMandalPicker(BuildContext context, User? user) async {
    if (user == null || user.districtId == null) return;
    if (_isLocationPickerOpen) return;
    _isLocationPickerOpen = true;

    final theme = Theme.of(context);
    final locationVM = ref.read(locationViewModelProvider);

    // Load mandals for the dist-reporter's district
    await locationVM.loadMandals(user.districtId!);

    if (!mounted) return;

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: _SearchableListPicker<Mandal>(
            theme: theme,
            title: 'Select Mandal',
            subtitle:
                'Your state & district stay the same. Pick a mandal to browse its news.',
            icon: Icons.place_outlined,
            items: locationVM.mandals,
            getName: (m) => m.name,
            selectedId: user.mandalId,
            getId: (m) => m.id,
            onSelected: (mandal) async {
              Navigator.pop(ctx);
              final storage = OnboardingStorage();
              final state = await storage.getSelectedState();
              final district = await storage.getSelectedDistrict();
              if (state != null) {
                await ref
                    .read(authViewModelProvider)
                    .applyManualLocation(state, district, mandal);
                unawaited(PushNotificationService.instance.onLocationChanged());
              }
              _loadLocationData();
              final homeVM = ref.read(homeViewModelProvider);
              homeVM.loadLocationData().then((_) => homeVM.loadNewsData());
            },
          ),
        );
      },
    ).then((_) => _isLocationPickerOpen = false);
  }

  // ignore: unused_element
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
              Text(
                'Notification Settings',
                style: TextStyle(
                  fontSize: scaledFontSize(20),
                  fontWeight: FontWeight.bold,
                  color: theme.appTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Breaking News'),
                subtitle: const Text('Get notified for breaking news'),
                value: true,
                activeColor: theme.appPrimary,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('Daily Digest'),
                subtitle: const Text('Receive daily news summary'),
                value: true,
                activeColor: theme.appPrimary,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('Sports Updates'),
                subtitle: const Text('Get live sports updates'),
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

  // ignore: unused_element
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final theme = Theme.of(context);

    InputDecoration buildInputDecoration({
      required String label,
      required String hint,
      required IconData icon,
      required bool obscure,
      required VoidCallback onToggle,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: scaledFontSize(13),
          color: Colors.grey[600],
        ),
        hintStyle: TextStyle(
          fontSize: scaledFontSize(13),
          color: Colors.grey[400],
        ),
        prefixIcon: Icon(icon, size: 20, color: theme.appPrimary),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: Colors.grey[500],
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.appPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: TextStyle(fontSize: scaledFontSize(11)),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.appPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: theme.appPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: scaledFontSize(18),
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    style: TextStyle(fontSize: scaledFontSize(14)),
                    decoration: buildInputDecoration(
                      label: 'Current Password',
                      hint: 'Enter current password',
                      icon: Icons.lock_outline,
                      obscure: obscureCurrent,
                      onToggle: () => setDialogState(
                        () => obscureCurrent = !obscureCurrent,
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    style: TextStyle(fontSize: scaledFontSize(14)),
                    decoration: buildInputDecoration(
                      label: 'New Password',
                      hint: 'Enter new password',
                      icon: Icons.lock_reset,
                      obscure: obscureNew,
                      onToggle: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    style: TextStyle(fontSize: scaledFontSize(14)),
                    decoration: buildInputDecoration(
                      label: 'Confirm New Password',
                      hint: 'Re-enter new password',
                      icon: Icons.lock_reset,
                      obscure: obscureConfirm,
                      onToggle: () => setDialogState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v != newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: scaledFontSize(14),
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setDialogState(() => isLoading = true);

                              final authRepo = AuthRepositoryImpl();
                              final success = await authRepo.changePassword(
                                currentPassword: currentPasswordController.text,
                                newPassword: newPasswordController.text,
                                newPasswordConfirmation:
                                    confirmPasswordController.text,
                              );

                              setDialogState(() => isLoading = false);

                              if (context.mounted) {
                                if (success) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Password changed successfully',
                                      ),
                                      backgroundColor: Colors.green[600],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Failed to change password. Check your current password.',
                                      ),
                                      backgroundColor: Colors.red[600],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.appPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
                          : Text(
                              'Change',
                              style: TextStyle(
                                fontSize: scaledFontSize(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
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
              const Text('Deep Pulse News'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${AppConstants.appVersion}'),
              const SizedBox(height: 8),
              Text(
                'Stay updated with the latest news from around the world. Deep Pulse News brings you breaking news, trending stories, and personalized content.',
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  color: theme.appTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '© 2026 Deep Pulse News',
                style: TextStyle(
                  fontSize: scaledFontSize(12),
                  color: theme.appTextLight,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 76,
      endIndent: 16,
      color: Theme.of(context).appDivider,
    );
  }
}

class _DistrictMandalPickerContent extends StatefulWidget {
  final ThemeData theme;
  final List<District> districts;
  final int? currentDistrictId;
  final int? currentMandalId;
  final dynamic locationVM;
  final void Function(District district, Mandal mandal) onSave;

  const _DistrictMandalPickerContent({
    required this.theme,
    required this.districts,
    required this.currentDistrictId,
    required this.currentMandalId,
    required this.locationVM,
    required this.onSave,
  });

  @override
  State<_DistrictMandalPickerContent> createState() =>
      _DistrictMandalPickerContentState();
}

class _DistrictMandalPickerContentState
    extends State<_DistrictMandalPickerContent> {
  District? _pickedDistrict;
  Mandal? _pickedMandal;
  List<Mandal> _mandals = [];
  bool _isLoadingMandals = false;
  String _districtQuery = '';
  String _mandalQuery = '';

  @override
  void initState() {
    super.initState();
    // Pre-select current district
    if (widget.currentDistrictId != null && widget.districts.isNotEmpty) {
      _pickedDistrict = widget.districts
          .where((d) => d.id == widget.currentDistrictId)
          .firstOrNull;
      if (_pickedDistrict != null) {
        _loadMandals(_pickedDistrict!.id);
      }
    }
  }

  Future<void> _loadMandals(int districtId) async {
    setState(() => _isLoadingMandals = true);
    await widget.locationVM.loadMandals(districtId);
    if (mounted) {
      setState(() {
        _mandals = List.from(widget.locationVM.mandals);
        _isLoadingMandals = false;
        // Pre-select current mandal if in this district
        if (widget.currentMandalId != null) {
          _pickedMandal = _mandals
              .where((m) => m.id == widget.currentMandalId)
              .firstOrNull;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.location_city_outlined,
                size: 20,
                color: theme.appPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Change Location',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Your state stays the same. Pick a district and mandal.',
            style: TextStyle(
              fontSize: scaledFontSize(12),
              color: theme.appTextSecondary,
            ),
          ),
        ),
        const Divider(),

        // District search + list
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'District',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                fontWeight: FontWeight.w600,
                color: theme.appTextSecondary,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _districtQuery = v),
            style: TextStyle(fontSize: scaledFontSize(13)),
            decoration: InputDecoration(
              hintText: 'Search districts...',
              hintStyle: TextStyle(
                color: theme.appTextLight,
                fontSize: scaledFontSize(13),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: theme.appTextLight,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: Builder(
            builder: (_) {
              final filtered = _districtQuery.isEmpty
                  ? widget.districts
                  : widget.districts
                        .where(
                          (d) => d.name.toLowerCase().contains(
                            _districtQuery.toLowerCase(),
                          ),
                        )
                        .toList();
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final d = filtered[i];
                  final isSelected = _pickedDistrict?.id == d.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _pickedDistrict = d;
                          _pickedMandal = null;
                          _mandalQuery = '';
                        });
                        _loadMandals(d.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.appPrimary
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.appPrimary
                                : theme.dividerColor,
                          ),
                        ),
                        child: Text(
                          d.name,
                          style: TextStyle(
                            fontSize: scaledFontSize(12),
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : theme.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Mandal search + list
        if (_pickedDistrict != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mandal',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: theme.appTextSecondary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _mandalQuery = v),
              style: TextStyle(fontSize: scaledFontSize(13)),
              decoration: InputDecoration(
                hintText: 'Search mandals...',
                hintStyle: TextStyle(
                  color: theme.appTextLight,
                  fontSize: scaledFontSize(13),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: theme.appTextLight,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
            ),
          ),
          if (_isLoadingMandals)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: Builder(
                builder: (_) {
                  final filtered = _mandalQuery.isEmpty
                      ? _mandals
                      : _mandals
                            .where(
                              (m) => m.name.toLowerCase().contains(
                                _mandalQuery.toLowerCase(),
                              ),
                            )
                            .toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final isSelected = _pickedMandal?.id == m.id;
                      return ListTile(
                        dense: true,
                        title: Text(
                          m.name,
                          style: TextStyle(
                            fontSize: scaledFontSize(14),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected ? theme.appPrimary : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: theme.appPrimary,
                              )
                            : null,
                        onTap: () => setState(() => _pickedMandal = m),
                      );
                    },
                  );
                },
              ),
            ),
        ],

        // Save button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pickedDistrict != null && _pickedMandal != null
                  ? () => widget.onSave(_pickedDistrict!, _pickedMandal!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.appPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save Location',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchableListPicker<T> extends StatefulWidget {
  final ThemeData theme;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<T> items;
  final String Function(T) getName;
  final int Function(T) getId;
  final int? selectedId;
  final void Function(T) onSelected;

  const _SearchableListPicker({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.getName,
    required this.getId,
    required this.onSelected,
    this.selectedId,
  });

  @override
  State<_SearchableListPicker<T>> createState() =>
      _SearchableListPickerState<T>();
}

class _SearchableListPickerState<T> extends State<_SearchableListPicker<T>> {
  String _query = '';

  List<T> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((item) => widget.getName(item).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: theme.appPrimary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: scaledFontSize(16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: scaledFontSize(12),
                color: theme.appTextSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(fontSize: scaledFontSize(14)),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: theme.appTextLight,
                  fontSize: scaledFontSize(14),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.appTextLight,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No results found',
                      style: TextStyle(
                        fontSize: scaledFontSize(14),
                        color: theme.appTextLight,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      final isSelected =
                          widget.selectedId == widget.getId(item);
                      return ListTile(
                        dense: true,
                        title: Text(
                          widget.getName(item),
                          style: TextStyle(
                            fontSize: scaledFontSize(14),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected ? theme.appPrimary : null,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: theme.appPrimary,
                              )
                            : null,
                        onTap: () => widget.onSelected(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FullLocationPickerContent extends StatefulWidget {
  final ThemeData theme;
  final List<location_models.State> states;
  final dynamic locationVM;
  final int? currentStateId;
  final int? currentDistrictId;
  final int? currentMandalId;
  final void Function(
    location_models.State state,
    District district,
    Mandal mandal,
  )
  onSave;

  const _FullLocationPickerContent({
    required this.theme,
    required this.states,
    required this.locationVM,
    required this.onSave,
    this.currentStateId,
    this.currentDistrictId,
    this.currentMandalId,
  });

  @override
  State<_FullLocationPickerContent> createState() =>
      _FullLocationPickerContentState();
}

class _FullLocationPickerContentState
    extends State<_FullLocationPickerContent> {
  location_models.State? _pickedState;
  District? _pickedDistrict;
  Mandal? _pickedMandal;
  List<District> _districts = [];
  List<Mandal> _mandals = [];
  bool _isLoadingDistricts = false;
  bool _isLoadingMandals = false;
  String _stateQuery = '';
  String _districtQuery = '';
  String _mandalQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.currentStateId != null && widget.states.isNotEmpty) {
      _pickedState = widget.states
          .where((s) => s.id == widget.currentStateId)
          .firstOrNull;
      if (_pickedState != null) {
        _loadDistricts(_pickedState!.id);
      }
    }
  }

  Future<void> _loadDistricts(int stateId) async {
    setState(() => _isLoadingDistricts = true);
    await widget.locationVM.loadDistricts(stateId);
    if (mounted) {
      setState(() {
        _districts = List.from(widget.locationVM.districts);
        _isLoadingDistricts = false;
        if (widget.currentDistrictId != null) {
          _pickedDistrict = _districts
              .where((d) => d.id == widget.currentDistrictId)
              .firstOrNull;
          if (_pickedDistrict != null) {
            _loadMandals(_pickedDistrict!.id);
          }
        }
      });
    }
  }

  Future<void> _loadMandals(int districtId) async {
    setState(() => _isLoadingMandals = true);
    await widget.locationVM.loadMandals(districtId);
    if (mounted) {
      setState(() {
        _mandals = List.from(widget.locationVM.mandals);
        _isLoadingMandals = false;
        if (widget.currentMandalId != null) {
          _pickedMandal = _mandals
              .where((m) => m.id == widget.currentMandalId)
              .firstOrNull;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: theme.appPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'Change Location',
                style: TextStyle(
                  fontSize: scaledFontSize(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // ── State ──
              Text(
                'State',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: theme.appTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                onChanged: (v) => setState(() => _stateQuery = v),
                style: TextStyle(fontSize: scaledFontSize(13)),
                decoration: InputDecoration(
                  hintText: 'Search states...',
                  hintStyle: TextStyle(
                    color: theme.appTextLight,
                    fontSize: scaledFontSize(13),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: theme.appTextLight,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              SizedBox(height: 5),
              SizedBox(
                height: 42,
                child: Builder(
                  builder: (_) {
                    final filtered = _stateQuery.isEmpty
                        ? widget.states
                        : widget.states
                              .where(
                                (s) => s.name.toLowerCase().contains(
                                  _stateQuery.toLowerCase(),
                                ),
                              )
                              .toList();
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        final isSelected = _pickedState?.id == s.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _pickedState = s;
                                _pickedDistrict = null;
                                _pickedMandal = null;
                                _districts = [];
                                _mandals = [];
                                _districtQuery = '';
                                _mandalQuery = '';
                              });
                              _loadDistricts(s.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.appPrimary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      0.08,
                                    ), // light shadow
                                    blurRadius: 6,
                                    offset: const Offset(
                                      0,
                                      2,
                                    ), // downward shadow
                                  ),
                                ],
                                border: Border.all(
                                  color: theme.dividerColor.withOpacity(
                                    0.2,
                                  ), // very light border
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: scaledFontSize(12),
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : theme.appTextSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),

              // ── District ──
              if (_pickedState != null) ...[
                Text(
                  'District',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    fontWeight: FontWeight.w600,
                    color: theme.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  onChanged: (v) => setState(() => _districtQuery = v),
                  style: TextStyle(fontSize: scaledFontSize(13)),
                  decoration: InputDecoration(
                    hintText: 'Search districts...',
                    hintStyle: TextStyle(
                      color: theme.appTextLight,
                      fontSize: scaledFontSize(13),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: theme.appTextLight,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                if (_isLoadingDistricts)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SizedBox(
                    height: 42,
                    child: Builder(
                      builder: (_) {
                        final filtered = _districtQuery.isEmpty
                            ? _districts
                            : _districts
                                  .where(
                                    (d) => d.name.toLowerCase().contains(
                                      _districtQuery.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final d = filtered[i];
                            final isSelected = _pickedDistrict?.id == d.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _pickedDistrict = d;
                                    _pickedMandal = null;
                                    _mandals = [];
                                    _mandalQuery = '';
                                  });
                                  _loadMandals(d.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.appPrimary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          0.08,
                                        ), // light shadow
                                        blurRadius: 6,
                                        offset: const Offset(
                                          0,
                                          2,
                                        ), // downward shadow
                                      ),
                                    ],
                                    border: Border.all(
                                      color: theme.dividerColor.withOpacity(
                                        0.2,
                                      ), // very light border
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      d.name,
                                      style: TextStyle(
                                        fontSize: scaledFontSize(12),
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : theme.appTextSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // ── Mandal ──
              if (_pickedDistrict != null) ...[
                Text(
                  'Mandal',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    fontWeight: FontWeight.w600,
                    color: theme.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  onChanged: (v) => setState(() => _mandalQuery = v),
                  style: TextStyle(fontSize: scaledFontSize(13)),
                  decoration: InputDecoration(
                    hintText: 'Search mandals...',
                    hintStyle: TextStyle(
                      color: theme.appTextLight,
                      fontSize: scaledFontSize(13),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: theme.appTextLight,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                if (_isLoadingMandals)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Builder(
                    builder: (_) {
                      final filtered = _mandalQuery.isEmpty
                          ? _mandals
                          : _mandals
                                .where(
                                  (m) => m.name.toLowerCase().contains(
                                    _mandalQuery.toLowerCase(),
                                  ),
                                )
                                .toList();
                      return Column(
                        children: filtered.map((m) {
                          final isSelected = _pickedMandal?.id == m.id;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              m.name,
                              style: TextStyle(
                                fontSize: scaledFontSize(14),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isSelected ? theme.appPrimary : null,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 18,
                                    color: theme.appPrimary,
                                  )
                                : null,
                            onTap: () => setState(() => _pickedMandal = m),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _pickedState != null &&
                      _pickedDistrict != null &&
                      _pickedMandal != null
                  ? () => widget.onSave(
                      _pickedState!,
                      _pickedDistrict!,
                      _pickedMandal!,
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.appPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save Location',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen pinch-zoomable viewer for the profile photo. Tap the X to
/// dismiss; pinch to zoom; drag to pan when zoomed in. We deliberately do
/// NOT use Hero here — animating a circular-clipped 1:1 avatar into a 9:16
/// portrait was producing a mid-flight layout glitch (the image landed at
/// the bottom half of the screen).
class _FullScreenPhotoViewer extends StatelessWidget {
  final String imageUrl;
  const _FullScreenPhotoViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: SizedBox.expand(
          child: CachedImageWidget(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            errorWidget: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
