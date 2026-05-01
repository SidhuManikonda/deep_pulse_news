enum UserRole {
  reader('reader', 'Reader', 1),
  reporter('reporter', 'Reporter', 2),
  distReporter('dist-reporter', 'Dist Reporter', 3),
  subAdmin('sub_admin', 'Sub Admin', 4),
  admin('admin', 'Admin', 5);

  const UserRole(this.value, this.displayName, this.level);

  final String value;
  final String displayName;
  final int level;

  // Get role from string value
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.reader,
    );
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
