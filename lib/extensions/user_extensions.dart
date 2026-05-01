import '../data/models/user.dart';
import '../enums/user_role.dart';
import '../core/constants/permissions.dart';

extension UserRoleExtension on User {
  /// Get the user's primary role based on role hierarchy
  UserRole get primaryRole {
    if (roles == null || roles!.isEmpty) {
      return UserRole.reader;
    }

    // Check for admin role first (highest priority)
    if (hasRoleSlug('admin')) {
      return UserRole.admin;
    }

    // Check for sub-admin role
    if (hasRoleSlug('sub_admin') ||
        hasRoleSlug('sub-admin') ||
        hasRoleSlug('subadmin')) {
      return UserRole.subAdmin;
    }

    // Check for dist-reporter role
    if (hasRoleSlug('dist-reporter')) {
      return UserRole.distReporter;
    }

    // Check for reporter role
    if (hasRoleSlug('reporter')) {
      return UserRole.reporter;
    }

    // Default to reader
    return UserRole.reader;
  }

  /// Check if user has a specific role slug or name
  bool hasRoleSlug(String slug) {
    return roles?.any(
          (role) =>
              role.slug?.toLowerCase() == slug.toLowerCase() ||
              role.name.toLowerCase() == slug.toLowerCase(),
        ) ??
        false;
  }

  /// Check if user has permission for a specific action
  bool hasPermission(String permission) {
    if (roles == null || roles!.isEmpty) {
      return false;
    }

    for (final role in roles!) {
      if (role.permissions?.any((p) => p.slug == permission) ?? false) {
        return true;
      }
    }

    return false;
  }

  // Dynamic API-based permission methods using actual API permissions

  /// Can upload news content - uses API permissions
  bool get canUploadContent =>
      hasPermission(Permissions.createNews) ||
      hasPermission(Permissions.uploadMedia) ||
      hasPermission(Permissions.editNews) ||
      hasPermission(Permissions.publishNews);

  /// Can moderate/approve content - uses API permissions
  bool get canModerateContent =>
      hasPermission(Permissions.editNews) ||
      hasPermission(Permissions.publishNews);

  /// Can manage users and profiles - uses API permissions
  bool get canManageUsers => hasPermission(Permissions.manageUsers);

  /// Can create polls/surveys - uses API permissions (fallback to manage topics for now)
  bool get canCreatePolls => hasPermission(Permissions.manageTopics);

  /// Can manage locations - uses API permissions (fallback to manage settings for now)
  bool get canManageLocations => hasPermission(Permissions.manageSettings);

  /// Can access admin panel - uses API permissions
  bool get canAccessAdmin =>
      hasPermission(Permissions.manageUsers) ||
      hasPermission(Permissions.manageRoles);

  /// Can access sub-admin features - uses API permissions
  bool get canAccessSubAdmin =>
      hasPermission(Permissions.manageTopics) || canAccessAdmin;

  /// Can access dist-reporter features - uses API permissions
  bool get canAccessDistReporter =>
      hasPermission(Permissions.editNews) || canAccessSubAdmin;

  /// Can post ads - uses API permissions (fallback to create news for now)
  bool get canPostAds => hasPermission(Permissions.createNews);

  /// Can approve ads - uses API permissions (fallback to publish news for now)
  bool get canApproveAds => hasPermission(Permissions.publishNews);

  /// Can delete content - uses API permissions
  bool get canDeleteContent => hasPermission(Permissions.deleteNews);

  /// Can view analytics/statistics - uses API permissions (fallback to manage settings for now)
  bool get canViewAnalytics => hasPermission(Permissions.manageSettings);

  /// Can manage content categories - uses API permissions
  bool get canManageCategories => hasPermission(Permissions.manageTopics);

  /// Get user's location display string
  String get locationDisplay {
    if (mandalName != null && districtName != null && stateName != null) {
      return '$mandalName, $districtName, $stateName';
    } else if (districtName != null && stateName != null) {
      return '$districtName, $stateName';
    } else if (stateName != null) {
      return stateName!;
    }
    return 'Location not set';
  }

  /// Check if user has complete location data
  bool get hasCompleteLocation =>
      stateId != null && districtId != null && mandalId != null;

  /// Get role display name with location
  String get roleWithLocation {
    return '${primaryRole.displayName} - $locationDisplay';
  }

  /// Get role-specific home route
  String get homeRoute {
    switch (primaryRole) {
      case UserRole.admin:
        return '/admin-dashboard';
      case UserRole.subAdmin:
        return '/sub-admin-dashboard';
      case UserRole.distReporter:
        return '/dist-reporter-dashboard';
      case UserRole.reporter:
        return '/reporter-dashboard';
      case UserRole.reader:
        return '/home';
    }
  }

  /// Get available navigation items based on role
  List<NavigationItem> get availableNavigation {
    final items = <NavigationItem>[
      NavigationItem(
        icon: 'home',
        label: 'Home',
        route: '/home',
        isVisible: true,
      ),
      NavigationItem(
        icon: 'newspaper',
        label: 'News',
        route: '/news',
        isVisible: true,
      ),
    ];

    // Add role-specific navigation items
    if (canUploadContent) {
      items.add(
        NavigationItem(
          icon: 'upload',
          label: 'Upload',
          route: '/upload',
          isVisible: true,
        ),
      );
    }

    if (canModerateContent) {
      items.add(
        NavigationItem(
          icon: 'moderate',
          label: 'Moderate',
          route: '/moderate',
          isVisible: true,
        ),
      );
    }

    if (canManageUsers) {
      items.add(
        NavigationItem(
          icon: 'users',
          label: 'Users',
          route: '/users',
          isVisible: true,
        ),
      );
    }

    if (canAccessAdmin) {
      items.add(
        NavigationItem(
          icon: 'admin',
          label: 'Admin',
          route: '/admin',
          isVisible: true,
        ),
      );
    }

    items.add(
      NavigationItem(
        icon: 'profile',
        label: 'Profile',
        route: '/profile',
        isVisible: true,
      ),
    );

    return items;
  }
}

class NavigationItem {
  final String icon;
  final String label;
  final String route;
  final bool isVisible;

  NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isVisible,
  });
}
