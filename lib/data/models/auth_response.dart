import 'user.dart';

class AuthResponse {
  final User user;
  final String accessToken;
  final String tokenType;
  final String? message;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.tokenType,
    this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user']),
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'Bearer',
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'access_token': accessToken,
      'token_type': tokenType,
      'message': message,
    };
  }
}

class RegisterRequest {
  final String name;
  final String email;
  final String mobile;
  final String password;
  final String passwordConfirmation;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.mobile,
    required this.password,
    required this.passwordConfirmation,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'mobile': mobile,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
  }
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}

class CreateUserRequest {
  final String name;
  final String email;
  final String mobile;
  final String password;
  final int userRole;
  final int? stateId;
  final int? districtId;
  final int? mandalId;

  CreateUserRequest({
    required this.name,
    required this.email,
    required this.mobile,
    required this.password,
    required this.userRole,
    this.stateId,
    this.districtId,
    this.mandalId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'mobile': mobile,
      'password': password,
      'user_role': userRole,
      if (stateId != null) 'state_id': stateId,
      if (districtId != null) 'district_id': districtId,
      if (mandalId != null) 'mandal_id': mandalId,
    };
  }
}
