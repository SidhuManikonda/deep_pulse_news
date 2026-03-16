import '../models/auth_response.dart';
import '../models/user.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class AuthRepository {
  Future<AuthResponse?> register(RegisterRequest request);
  Future<AuthResponse?> login(LoginRequest request);
  Future<bool> logout();
  Future<User?> getCurrentUser();
  Future<User?> createUser(CreateUserRequest request);
  Future<List<User>?> getUserList();
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

  @override
  Future<User?> createUser(CreateUserRequest request) async {
    try {
      final response = await _apiService.post(
        AppConstants.user,
        body: request.toJson(),
        useAuth: true,
      );

      if (response.containsKey('error')) {
        return null;
      }

      // Assuming the response contains the created user data
      if (response.containsKey('user')) {
        return User.fromJson(response['user']);
      }

      // Fallback: if the response is the user data directly
      return User.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<User>?> getUserList() async {
    try {
      final response = await _apiService.get(
        AppConstants.userList,
        useAuth: true,
      );

      // If response is a Map (error response), check for error key
      if (response is Map && response.containsKey('error')) {
        return null;
      }

      // If response is directly a List of users
      if (response is List) {
        return response.map((userJson) => User.fromJson(userJson)).toList();
      }

      // If response is wrapped in a key like 'users' or 'data'
      if (response is Map && response.containsKey('users')) {
        final usersData = response['users'];
        if (usersData is List) {
          return usersData.map((userJson) => User.fromJson(userJson)).toList();
        }
      }

      // If response is wrapped in 'data' key
      if (response is Map && response.containsKey('data')) {
        final usersData = response['data'];
        if (usersData is List) {
          return usersData.map((userJson) => User.fromJson(userJson)).toList();
        }
      }

      // If none of the above, return null
      return null;
    } catch (e) {
      return null;
    }
  }
}
