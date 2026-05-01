import 'package:deep_pulse_news/extensions/user_extensions.dart';
import 'package:flutter/material.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/user.dart';
import '../../data/models/user_comment.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/comments_repository.dart';
import '../../features/auth/auth_view_model.dart';

class AdminUserManagementController extends ChangeNotifier {
  /// Selected values
  int? _selectedRoleId;
  location_models.State? _selectedState;
  District? _selectedDistrict;
  Mandal? _selectedMandal;
  bool? _isPasswordVisible = false;

  /// Roles from API
  List<Role> _roles = [];
  bool _isLoadingRoles = false;
  String? _rolesError;

  /// Users list state
  List<User> _users = [];
  bool _isLoadingUsers = false;
  String? _usersError;

  /// User comments state
  final CommentsRepository _commentsRepository = CommentsRepositoryImpl();
  List<UserCommentEntry> _userComments = [];
  bool _isLoadingComments = false;
  String? _commentsError;

  /// Getters
  int? get selectedRoleId => _selectedRoleId;
  location_models.State? get selectedState => _selectedState;
  District? get selectedDistrict => _selectedDistrict;
  Mandal? get selectedMandal => _selectedMandal;
  List<User> get users => _users;
  bool get isLoadingUsers => _isLoadingUsers;
  String? get usersError => _usersError;
  List<Role> get roles => _roles;
  bool get isLoadingRoles => _isLoadingRoles;
  String? get rolesError => _rolesError;
  List<UserCommentEntry> get userComments => _userComments;
  bool get isLoadingComments => _isLoadingComments;
  String? get commentsError => _commentsError;
  bool get isPasswordVisible => _isPasswordVisible ?? false;

  Future<void> fetchRoles({
    required AuthRepository authRepository,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingRoles) return;
    if (!forceRefresh && _roles.isNotEmpty) return;

    _isLoadingRoles = true;
    _rolesError = null;
    notifyListeners();

    try {
      final result = await authRepository.getRoles();
      _roles = result ?? [];
    } catch (e) {
      _rolesError = e.toString();
    } finally {
      _isLoadingRoles = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserComments(int userId) async {
    _isLoadingComments = true;
    _commentsError = null;
    _userComments = [];
    notifyListeners();

    try {
      _userComments = await _commentsRepository.getUserComments(userId: userId);
    } catch (e) {
      _commentsError = e.toString();
    } finally {
      _isLoadingComments = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser({
    required AuthRepository authRepository,
    required int userId,
  }) async {
    try {
      final success = await authRepository.deleteUser(userId);
      if (success) {
        _users.removeWhere((u) => u.id == userId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchUsers({
    required AuthRepository authRepository,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingUsers) return;
    if (!forceRefresh && _users.isNotEmpty) return;

    _isLoadingUsers = true;
    _usersError = null;
    notifyListeners();

    try {
      final result = await authRepository.getUserList();
      _users = result ?? [];
      debugPrint('🔍 FETCH USERS: loaded ${_users.length} users');
    } catch (e) {
      debugPrint('🔍 FETCH USERS ERROR: $e');
      _usersError = e.toString();
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  /// Get selected role's slug
  String? get selectedRoleSlug {
    if (_selectedRoleId == null) return null;
    final role = _roles.where((r) => r.id == _selectedRoleId).firstOrNull;
    return role?.slug;
  }

  /// Get selected role's name
  String? get selectedRoleName {
    if (_selectedRoleId == null) return null;
    final role = _roles.where((r) => r.id == _selectedRoleId).firstOrNull;
    return role?.name.toLowerCase();
  }

  /// change role
  void setRole(int? roleId) {
    _selectedRoleId = roleId;

    /// reset locations
    _selectedState = null;
    _selectedDistrict = null;
    _selectedMandal = null;

    notifyListeners();
  }

  /// change state
  void setState(location_models.State? state) {
    _selectedState = state;
    _selectedDistrict = null;
    _selectedMandal = null;
    notifyListeners();
  }

  /// change district
  void setDistrict(District? district) {
    _selectedDistrict = district;
    _selectedMandal = null;
    notifyListeners();
  }

  /// change mandal
  void setMandal(Mandal? mandal) {
    _selectedMandal = mandal;
    notifyListeners();
  }

  /// Role display
  String getRoleDisplayNameFromId(int roleId) {
    final role = _roles.where((r) => r.id == roleId).firstOrNull;
    return role?.name ?? 'Unknown Role';
  }

  /// Create user
  Future<bool> createUser({
    required AuthViewModel authViewModel,
    required User currentUser,
    required String name,
    required String email,
    required String mobile,
    required String password,
  }) async {
    int? stateId;
    int? districtId;
    int? mandalId;

    final currentRole = currentUser.primaryRole.value;

    if (currentRole == 'admin') {
      stateId = _selectedState?.id;
      districtId = _selectedDistrict?.id;
      mandalId = _selectedMandal?.id;
    }

    if (currentRole == 'subadmin') {
      stateId = currentUser.stateId;
      districtId = _selectedDistrict?.id;
      mandalId = _selectedMandal?.id;
    }

    if (currentRole == 'dist-reporter') {
      stateId = currentUser.stateId;
      districtId = currentUser.districtId;
      mandalId = _selectedMandal?.id;
    }

    final success = await authViewModel.createUser(
      name: name,
      email: email,
      mobile: mobile,
      password: password,
      userRole: _selectedRoleId!,
      stateId: stateId,
      districtId: districtId,
      mandalId: mandalId,
    );

    if (success) {
      resetSelections();
      
    }

    return success;
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !(_isPasswordVisible ?? false);
    notifyListeners();
  }

  void resetSelections() {
    _selectedRoleId = null;
    _selectedState = null;
    _selectedDistrict = null;
    _selectedMandal = null;
    notifyListeners();
  }
}
