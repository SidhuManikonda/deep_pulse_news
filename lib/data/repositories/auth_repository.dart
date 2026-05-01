import 'package:flutter/foundation.dart';

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
  Future<bool> deleteUser(int id);
  Future<List<Role>?> getRoles();
  Future<bool> updatePassword(int userId, String newPassword);
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  });
  Future<bool> blockUser(int userId);
  Future<bool> toggleBlockUser(int userId, {required bool block});
  Future<AuthResponse?> googleLogin({
    required String idToken,
    required int stateId,
    required int districtId,
    required int mandalId,
    String? mobile,
  });
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
        useAuth: true,
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

      debugPrint(
        '🔍 USER LIST RAW: type=${response.runtimeType}, response=$response',
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

  @override
  Future<List<Role>?> getRoles() async {
    try {
      final response = await _apiService.get(
        AppConstants.userRoles,
        useAuth: true,
      );

      if (response is List) {
        return response.map((json) => Role.fromJson(json)).toList();
      }

      if (response is Map && response.containsKey('error')) {
        return null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> deleteUser(int id) async {
    try {
      final response = await _apiService.delete(
        '${AppConstants.user}/$id',
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await _apiService.patch(AppConstants.changePassword, {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }, useAuth: true);

      if (response.containsKey('error')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> updatePassword(int userId, String newPassword) async {
    try {
      final response = await _apiService.patch(AppConstants.updatePassword, {
        'user_id': userId.toString(),
        'new_password': newPassword,
      }, useAuth: true);

      if (response.containsKey('error')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> blockUser(int userId) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.blockUser}/$userId/block',
        body: {},
        useAuth: true,
      );

      if (response.containsKey('error')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResponse?> googleLogin({
    required String idToken,
    required int stateId,
    required int districtId,
    required int mandalId,
    String? mobile,
  }) async {
    try {
      final body = <String, dynamic>{
        'id_token': idToken,
        'state_id': stateId,
        'district_id': districtId,
        'mandal_id': mandalId,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      };

      final response = await _apiService.post(
        AppConstants.googleLogin,
        body: body,
      );

      if (response.containsKey('access_token')) {
        return AuthResponse.fromJson(response);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> toggleBlockUser(int userId, {required bool block}) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.toggleBlockUser}/$userId/toggle-block',
        body: {'is_blocked_by_admin': block ? 1 : 0},
        useAuth: true,
      );

      if (response.containsKey('error')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
