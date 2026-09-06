import 'package:flutter/foundation.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String mobile;
  final String? otpCode;
  final DateTime? otpExpiresAt;
  final bool isActive;
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? roleName;
  final int? userId;
  final String? rememberToken;
  final List<Role>? roles;
  final int? stateId;
  final int? districtId;
  final int? mandalId;
  final String? stateName;
  final String? districtName;
  final String? mandalName;
  final bool? isBlocked;
  final bool isBlockedByAdmin;
  final String? profilePhoto;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.otpCode,
    this.otpExpiresAt,
    required this.isActive,
    this.emailVerifiedAt,
    this.createdAt,
    this.updatedAt,
    this.rememberToken,
    this.roleName,
    this.userId,
    this.roles,
    this.stateId,
    this.districtId,
    this.mandalId,
    this.stateName,
    this.districtName,
    this.mandalName,
    this.isBlocked,
    this.isBlockedByAdmin = false,
    this.profilePhoto,
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
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      rememberToken: json['remember_token'],
      roleName: json['role_name'],
      userId: json['user_id'],
      roles: json['roles'] != null 
          ? (json['roles'] as List).map((role) => Role.fromJson(role)).toList()
          : null,
      stateId: json['state_id'] ?? (json['user_detail'] != null ? json['user_detail']['state_id'] : null),
      districtId: json['district_id'] ?? (json['user_detail'] != null ? json['user_detail']['district_id'] : null),
      mandalId: json['mandal_id'] ?? (json['user_detail'] != null ? json['user_detail']['mandal_id'] : null),
      stateName: json['state_name'],
      districtName: json['district_name'],
      mandalName: json['mandal_name'],
      isBlocked: json['is_blocked'] == null
          ? null
          : (json['is_blocked'] is int
              ? json['is_blocked'] == 1
              : json['is_blocked'] == true),
      isBlockedByAdmin: json['is_blocked_by_admin'] is int
          ? json['is_blocked_by_admin'] == 1
          : json['is_blocked_by_admin'] == true,
      profilePhoto: _extractProfilePhoto(json),
    );
  }

  /// Pulls the profile_photo URL from wherever the backend put it: top level
  /// (`json['profile_photo']`) or nested under `user_detail`. Logs both
  /// candidate spots so we can confirm what the backend actually returned —
  /// remove the debugPrint lines once we know the field is wired correctly.
  static String? _extractProfilePhoto(Map<String, dynamic> json) {
    final topLevel = json['profile_photo'];
    final detailMap = json['user_detail'] is Map
        ? json['user_detail'] as Map
        : null;
    final detail = detailMap?['profile_photo'];
    debugPrint('[User.fromJson] profile_photo lookup');
    debugPrint('  top-level profile_photo = $topLevel');
    debugPrint('  user keys               = ${json.keys.toList()}');
    debugPrint('  user_detail keys        = ${detailMap?.keys.toList()}');
    debugPrint('  user_detail.profile_photo = $detail');
    // Also flag anything photo-ish in case the backend used a different key
    final photoLike = <String>[
      ...json.keys.where((k) => k.toString().toLowerCase().contains('photo')
          || k.toString().toLowerCase().contains('picture')
          || k.toString().toLowerCase().contains('avatar')
          || k.toString().toLowerCase().contains('image')),
      if (detailMap != null)
        ...detailMap.keys.where((k) => k.toString().toLowerCase().contains('photo')
            || k.toString().toLowerCase().contains('picture')
            || k.toString().toLowerCase().contains('avatar')
            || k.toString().toLowerCase().contains('image'))
          .map((k) => 'user_detail.$k'),
    ];
    debugPrint('  photo-ish keys found    = $photoLike');
    return (topLevel as String?) ?? (detail as String?);
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'remember_token': rememberToken,
      'role_name': roleName,
      'user_id': userId,
      'roles': roles?.map((role) => role.toJson()).toList(),
      'state_id': stateId,
      'district_id': districtId,
      'mandal_id': mandalId,
      'state_name': stateName,
      'district_name': districtName,
      'mandal_name': mandalName,
      'is_blocked': isBlocked,
      'is_blocked_by_admin': isBlockedByAdmin,
      'profile_photo': profilePhoto,
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
    String? roleName,
    int? userId,
    List<Role>? roles,
    int? stateId,
    int? districtId,
    int? mandalId,
    String? stateName,
    String? districtName,
    String? mandalName,
    bool? isBlocked,
    bool? isBlockedByAdmin,
    String? profilePhoto,
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
      roleName: roleName ?? this.roleName,
      userId: userId ?? this.userId,
      roles: roles ?? this.roles,
      stateId: stateId ?? this.stateId,
      districtId: districtId ?? this.districtId,
      mandalId: mandalId ?? this.mandalId,
      stateName: stateName ?? this.stateName,
      districtName: districtName ?? this.districtName,
      mandalName: mandalName ?? this.mandalName,
      isBlocked: isBlocked ?? this.isBlocked,
      isBlockedByAdmin: isBlockedByAdmin ?? this.isBlockedByAdmin,
      profilePhoto: profilePhoto ?? this.profilePhoto,
    );
  }
}

class Role {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final RolePivot? pivot;
  final List<Permission>? permissions;

  Role({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.pivot,
    this.permissions,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
  final String? slug;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PermissionPivot? pivot;

  Permission({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.pivot,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      pivot: json['pivot'] != null ? PermissionPivot.fromJson(json['pivot']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
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
