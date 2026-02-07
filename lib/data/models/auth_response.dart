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
