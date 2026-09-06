/// Roles the app understands.
///
/// [value] is a **stable internal id** used by the app's own switches and
/// comparisons. It deliberately does NOT track the backend's slug: the backend
/// has renamed roles before (`dist-reporter` → `newsdesk`, `reporter` →
/// `sr-reporter`) and every such rename would otherwise silently demote those
/// users to Reader everywhere in the app.
///
/// [apiSlugs] is the mapping layer instead — every slug (or role name) the
/// backend has ever used for this role. Old entries stay so a cached session
/// or a half-rolled-out backend still resolves. When the backend renames a
/// role again, add its new slug here and nothing else needs to change.
///
/// [displayName] is what users see, so it tracks the backend's current name.
enum UserRole {
  reader('reader', 'Reader', 1, {'reader'}),
  reporter('reporter', 'Sr Reporter', 2, {'sr-reporter', 'reporter'}),
  distReporter('dist-reporter', 'News Desk', 3, {
    'newsdesk',
    'news-desk',
    'news desk',
    'dist-reporter',
  }),
  subAdmin('sub_admin', 'Sub Admin', 4, {'subadmin', 'sub_admin', 'sub-admin'}),
  admin('admin', 'Admin', 5, {'admin'});

  const UserRole(this.value, this.displayName, this.level, this.apiSlugs);

  final String value;
  final String displayName;
  final int level;

  /// Backend slugs/names that map to this role, lowercase.
  final Set<String> apiSlugs;

  // Get role from the app's internal value
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.reader,
    );
  }

  /// Resolve a role from whatever the backend sent (`slug` or `name`).
  /// Returns null when nothing matches, so callers can decide the fallback.
  static UserRole? fromApiSlug(String? slugOrName) {
    if (slugOrName == null || slugOrName.isEmpty) return null;
    final needle = slugOrName.toLowerCase().trim();
    for (final role in UserRole.values) {
      if (role.apiSlugs.contains(needle)) return role;
    }
    return null;
  }

  // Check if current role has permission for target role level
  bool hasPermission(UserRole targetRole) {
    return level >= targetRole.level;
  }

  // Check if current role can access admin features
  bool get canAccessAdmin => level >= UserRole.admin.level;

  // Check if current role can access sub-admin features
  bool get canAccessSubAdmin => level >= UserRole.subAdmin.level;

  // Check if current role can access dist-reporter features
  bool get canAccessDistReporter => level >= UserRole.distReporter.level;

  // Check if current role can upload content
  bool get canUploadContent => level >= UserRole.reporter.level;

  // Check if current role can moderate content
  bool get canModerateContent => level >= UserRole.distReporter.level;

  // Check if current role can manage users
  bool get canManageUsers => level >= UserRole.subAdmin.level;

  // Check if current role can create polls/surveys
  bool get canCreatePolls => level >= UserRole.admin.level;

  // Check if current role can manage locations (districts/mandals)
  bool get canManageLocations => level >= UserRole.admin.level;
}
