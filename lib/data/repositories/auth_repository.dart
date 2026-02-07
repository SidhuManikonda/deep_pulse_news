import '../models/auth_response.dart';
import '../models/user.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class AuthRepository {
  Future<AuthResponse?> register(RegisterRequest request);
  Future<AuthResponse?> login(LoginRequest request);
  Future<bool> logout();
  Future<User?> getCurrentUser();
}

class AuthRepositoryImpl implements AuthRepository {
  final ApiService _apiService;

  AuthRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<AuthResponse?> register(RegisterRequest request) async {
    try {
      final response = await _apiService.post(
        AppConstants.register,
        body: request.toJson(),
      );

      // Check if response contains access_token (success)
      if (response.containsKey('access_token')) {
        return AuthResponse.fromJson(response);
      }

      // Error already shown by API service
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<AuthResponse?> login(LoginRequest request) async {
    try {
      final response = await _apiService.post(
        AppConstants.login,
        body: request.toJson(),
      );

      // Check if response contains access_token (success)
      if (response.containsKey('access_token')) {
        return AuthResponse.fromJson(response);
      }

      // Error already shown by API service
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> logout() async {
    try {
      final response = await _apiService.post(
        '/logout',
        body: {},
        useAuth: true,
      );

      return !response.containsKey('error');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiService.get(
        AppConstants.user,
        useAuth: true,
        showErrorAlert: false,
      );

      if (response.containsKey('error')) {
        return null;
      }

      return User.fromJson(response);
    } catch (e) {
      return null;
    }
  }
}
