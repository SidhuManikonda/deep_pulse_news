class User {
  final int id;
  final String name;
  final String email;
  final String mobile;
  final String? otpCode;
  final DateTime? otpExpiresAt;
  final bool isActive;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rememberToken;
  final List<Role>? roles;
  final int? stateId;
  final int? districtId;
  final int? mandalId;
  final String? stateName;
  final String? districtName;
  final String? mandalName;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.otpCode,
    this.otpExpiresAt,
    required this.isActive,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
    this.rememberToken,
    this.roles,
    this.stateId,
    this.districtId,
    this.mandalId,
    this.stateName,
    this.districtName,
    this.mandalName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      mobile: json['mobile'] ?? '',
      otpCode: json['otp_code'],
      otpExpiresAt: json['otp_expires_at'] != null 
          ? DateTime.parse(json['otp_expires_at']) 
          : null,
      isActive: json['is_active'] is int
          ? json['is_active'] == 1
          : json['is_active'] ?? true,
      emailVerifiedAt: json['email_verified_at'] != null 
          ? DateTime.parse(json['email_verified_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      rememberToken: json['remember_token'],
      roles: json['roles'] != null 
          ? (json['roles'] as List).map((role) => Role.fromJson(role)).toList()
          : null,
      stateId: json['state_id'],
      districtId: json['district_id'],
      mandalId: json['mandal_id'],
      stateName: json['state_name'],
      districtName: json['district_name'],
      mandalName: json['mandal_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'otp_code': otpCode,
      'otp_expires_at': otpExpiresAt?.toIso8601String(),
      'is_active': isActive,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'remember_token': rememberToken,
      'roles': roles?.map((role) => role.toJson()).toList(),
      'state_id': stateId,
      'district_id': districtId,
      'mandal_id': mandalId,
      'state_name': stateName,
      'district_name': districtName,
      'mandal_name': mandalName,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? mobile,
    String? otpCode,
    DateTime? otpExpiresAt,
    bool? isActive,
    DateTime? emailVerifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rememberToken,
    List<Role>? roles,
    int? stateId,
    int? districtId,
    int? mandalId,
    String? stateName,
    String? districtName,
    String? mandalName,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      otpCode: otpCode ?? this.otpCode,
      otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
      isActive: isActive ?? this.isActive,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rememberToken: rememberToken ?? this.rememberToken,
      roles: roles ?? this.roles,
      stateId: stateId ?? this.stateId,
      districtId: districtId ?? this.districtId,
      mandalId: mandalId ?? this.mandalId,
      stateName: stateName ?? this.stateName,
      districtName: districtName ?? this.districtName,
      mandalName: mandalName ?? this.mandalName,
    );
  }
}

class Role {
  final int id;
  final String name;
  final String slug;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RolePivot? pivot;
  final List<Permission>? permissions;

  Role({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.pivot,
    this.permissions,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      pivot: json['pivot'] != null ? RolePivot.fromJson(json['pivot']) : null,
      permissions: json['permissions'] != null
          ? (json['permissions'] as List).map((permission) => Permission.fromJson(permission)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'pivot': pivot?.toJson(),
      'permissions': permissions?.map((permission) => permission.toJson()).toList(),
    };
  }
}

class RolePivot {
  final int userId;
  final int roleId;

  RolePivot({
    required this.userId,
    required this.roleId,
  });

  factory RolePivot.fromJson(Map<String, dynamic> json) {
    return RolePivot(
      userId: json['user_id'] ?? 0,
      roleId: json['role_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role_id': roleId,
    };
  }
}

class Permission {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PermissionPivot? pivot;

  Permission({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.pivot,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      pivot: json['pivot'] != null ? PermissionPivot.fromJson(json['pivot']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'pivot': pivot?.toJson(),
    };
  }
}

class PermissionPivot {
  final int roleId;
  final int permissionId;

  PermissionPivot({
    required this.roleId,
    required this.permissionId,
  });

  factory PermissionPivot.fromJson(Map<String, dynamic> json) {
    return PermissionPivot(
      roleId: json['role_id'] ?? 0,
      permissionId: json['permission_id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'permission_id': permissionId,
    };
  }
}

class Language {
  final String code;
  final String name;
  final String flag;

  Language({
    required this.code,
    required this.name,
    required this.flag,
  });

  static List<Language> get supportedLanguages => [
    Language(code: 'en', name: 'English', flag: '🇺🇸'),
    Language(code: 'hi', name: 'हिंदी', flag: '🇮🇳'),
    Language(code: 'gu', name: 'ગુજરાતી', flag: '🇮🇳'),
    Language(code: 'mr', name: 'मराठी', flag: '🇮🇳'),
  ];
}

class UITopic {
  final String id;
  final String name;
  final String icon;
  final String color;

  UITopic({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static List<UITopic> get availableTopics => [
    UITopic(id: 'trending', name: 'Trending', icon: '🔥', color: 'E53E3E'),
    UITopic(id: 'politics', name: 'Politics', icon: '🏛️', color: '3182CE'),
    UITopic(id: 'sports', name: 'Sports', icon: '⚽', color: '38A169'),
    UITopic(id: 'entertainment', name: 'Entertainment', icon: '🎬', color: '9F7AEA'),
    UITopic(id: 'business', name: 'Business', icon: '💼', color: 'D69E2E'),
    UITopic(id: 'technology', name: 'Technology', icon: '💻', color: '00B5D8'),
    UITopic(id: 'health', name: 'Health', icon: '🏥', color: 'FF6B6B'),
    UITopic(id: 'lifestyle', name: 'Lifestyle', icon: '🌟', color: 'ED8936'),
  ];
}
