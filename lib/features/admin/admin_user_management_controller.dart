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

  /// Static role IDs
  static const int roleIdSubAdmin = 2;
  static const int roleIdEditor = 3;
  static const int roleIdReporter = 4;

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
  List<UserCommentEntry> get userComments => _userComments;
  bool get isLoadingComments => _isLoadingComments;
  String? get commentsError => _commentsError;

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
    } catch (e) {
      _usersError = e.toString();
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
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
    switch (roleId) {
      case roleIdSubAdmin:
        return 'Sub-Admin';
      case roleIdEditor:
        return 'Editor';
      case roleIdReporter:
        return 'Reporter';
      default:
        return 'Unknown Role';
    }
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

    if (currentRole == 'subAdmin') {
      stateId = currentUser.stateId;
      districtId = _selectedDistrict?.id;
      mandalId = _selectedMandal?.id;
    }

    if (currentRole == 'editor') {
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

  void resetSelections() {
    _selectedRoleId = null;
    _selectedState = null;
    _selectedDistrict = null;
    _selectedMandal = null;
    notifyListeners();
  }
}
