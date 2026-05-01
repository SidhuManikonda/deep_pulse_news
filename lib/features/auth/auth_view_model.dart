import 'package:deep_pulse_news/extensions/user_extensions.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import '../../core/services/onboarding_storage.dart';
import '../../data/models/auth_response.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/repositories/state_repository.dart';
import '../../data/repositories/district_repository.dart';
import '../../data/repositories/mandal_repository.dart';
import '../../shared/widgets/alert_popup.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final AuthStorage _authStorage;
  final OnboardingStorage _onboardingStorage;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  AuthViewModel({
    AuthRepository? authRepository,
    AuthStorage? authStorage,
    OnboardingStorage? onboardingStorage,
  }) : _authRepository = authRepository ?? AuthRepositoryImpl(),
       _authStorage = authStorage ?? AuthStorage(),
       _onboardingStorage = onboardingStorage ?? OnboardingStorage();

  // ===================== GETTERS =====================
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  // ===================== INIT =====================
  Future<void> initializeAuth() async {
    try {
      final storedToken = await _authStorage.getToken();

      if (storedToken == null) {
        _resetAuthState();
        notifyListeners();
        return;
      }
  
      _token = storedToken;
      _isAuthenticated = true;

      ApiService.instance.setAuthToken(storedToken);
      await _fetchCurrentUser();

      // If user fetch fails, treat as logged out
      if (_user == null) {
        await logout();
        return;
      }

      // If user has been blocked by admin, auto-logout
      if (_user!.isBlockedByAdmin) {
        await logout();
        AlertPopupManager().showAlert(
          title: 'Account Blocked',
          message: 'Your account has been blocked by admin. Please contact support.',
          type: AlertType.error,
        );
        return;
      }

      notifyListeners();
    } catch (e) {
      _resetAuthState();
      ApiService.instance.setAuthToken(null);
      notifyListeners();
    }
  }

  // ===================== LOGIN =====================
  Future<bool> login({required String mobile, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = LoginRequest(mobile: mobile, password: password);
      final response = await _authRepository.login(request);

      if (response == null) {
        _error = 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Block login if user is blocked by admin
      if (response.user.isBlockedByAdmin) {
        _error = 'Your account has been blocked by admin. Please contact support.';
        _isLoading = false;
        notifyListeners();
        AlertPopupManager().showAlert(
          title: 'Account Blocked',
          message: 'Your account has been blocked by admin. Please contact support.',
          type: AlertType.error,
        );
        return false;
      }

      await _applyAuthSuccess(response);

      AlertPopupManager().showAlert(
        title: 'Login Successful',
        message: 'Welcome back, ${response.user.name}!',
        type: AlertType.success,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===================== REGISTER =====================
  Future<bool> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String passwordConfirmation,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Read location data from onboarding storage
      final selectedState = await _onboardingStorage.getSelectedState();
      final selectedDistrict = await _onboardingStorage.getSelectedDistrict();
      final selectedMandal = await _onboardingStorage.getSelectedMandal();

      final request = RegisterRequest(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        passwordConfirmation: passwordConfirmation,
        stateId: selectedState?.id,
        districtId: selectedDistrict?.id,
        mandalId: selectedMandal?.id,
      );

      final response = await _authRepository.register(request);

      if (response == null) {
        _error = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _applyAuthSuccess(response);

      AlertPopupManager().showAlert(
        title: 'Registration Successful',
        message: 'Your account has been created successfully!',
        type: AlertType.success,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===================== GOOGLE LOGIN =====================
  Future<bool> googleLogin({
    required String idToken,
    required int stateId,
    required int districtId,
    required int mandalId,
    String? mobile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authRepository.googleLogin(
        idToken: idToken,
        stateId: stateId,
        districtId: districtId,
        mandalId: mandalId,
        mobile: mobile,
      );

      if (response == null) {
        _error = 'Google login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (response.user.isBlockedByAdmin) {
        _error = 'Your account has been blocked by admin. Please contact support.';
        _isLoading = false;
        notifyListeners();
        AlertPopupManager().showAlert(
          title: 'Account Blocked',
          message: 'Your account has been blocked by admin. Please contact support.',
          type: AlertType.error,
        );
        return false;
      }

      await _applyAuthSuccess(response);

      AlertPopupManager().showAlert(
        title: 'Login Successful',
        message: 'Welcome, ${response.user.name}!',
        type: AlertType.success,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===================== LOGOUT =====================
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.logout();
    } catch (_) {
      // ignore API logout errors
    }

    await _authStorage.clearToken();
    ApiService.instance.setAuthToken(null);

    _resetAuthState();

    _isLoading = false;
    notifyListeners();
  }

  // ===================== HELPERS =====================
  Future<void> _fetchCurrentUser() async {
    try {
      _user = await _authRepository.getCurrentUser();

      // If user is fetched successfully, merge onboarding location data
      if (_user != null) {
        await _mergeOnboardingLocationData();
      }
    } catch (_) {
      _user = null;
    }
  }

  // Merge location data: prefer API user_detail locations, fallback to onboarding cache.
  // If a location ID is null (e.g., subadmin has no mandal), fetch the first available from the list.
  Future<void> _mergeOnboardingLocationData() async {
    if (_user == null) return;

    try {
      final hasApiLocations = _user!.stateId != null;

      if (hasApiLocations) {
        // Fetch location names in parallel for speed
        final stateRepo = StateRepositoryImpl();
        final districtRepo = DistrictRepositoryImpl();
        final mandalRepo = MandalRepositoryImpl();

        final results = await Future.wait([
          stateRepo.getStates(),
          if (_user!.stateId != null)
            districtRepo.getDistrictsByState(_user!.stateId!)
          else
            Future.value(<District>[]),
          if (_user!.districtId != null)
            mandalRepo.getMandalsByDistrict(_user!.districtId!)
          else
            Future.value(<Mandal>[]),
        ]);

        final states = results[0] as List<location_models.State>;
        final districts = results[1] as List<District>;
        final mandals = results[2] as List<Mandal>;

        final state = states.where((s) => s.id == _user!.stateId).firstOrNull;
        var district = _user!.districtId != null
            ? districts.where((d) => d.id == _user!.districtId).firstOrNull
            : null;
        district ??= districts.isNotEmpty ? districts.first : null;

        var mandal = _user!.mandalId != null
            ? mandals.where((m) => m.id == _user!.mandalId).firstOrNull
            : null;
        mandal ??= mandals.isNotEmpty ? mandals.first : null;

        // Update user model with real names
        _user = _user!.copyWith(
          stateId: state?.id,
          stateName: state?.name,
          districtId: district?.id,
          districtName: district?.name,
          mandalId: mandal?.id,
          mandalName: mandal?.name,
        );

        // Save to onboarding storage so home screen picks it up
        if (state != null) {
          await _onboardingStorage.saveSelectedLocation(state, district, mandal);
        }

        debugPrint(
          'Using API locations: ${state?.name}, ${district?.name}, ${mandal?.name}',
        );
      } else {
        // No API locations — fallback to onboarding cache
        final selectedState = await _onboardingStorage.getSelectedState();
        final selectedDistrict = await _onboardingStorage.getSelectedDistrict();
        final selectedMandal = await _onboardingStorage.getSelectedMandal();

        _user = _user!.copyWith(
          stateId: selectedState?.id,
          stateName: selectedState?.name,
          districtId: selectedDistrict?.id,
          districtName: selectedDistrict?.name,
          mandalId: selectedMandal?.id,
          mandalName: selectedMandal?.name,
        );

        debugPrint(
          'Using cached locations: ${selectedState?.name}, ${selectedDistrict?.name}, ${selectedMandal?.name}',
        );
      }
    } catch (e) {
      debugPrint('Failed to merge location data: $e');
    }
  }

  Future<void> _applyAuthSuccess(AuthResponse response) async {
    _user = response.user;
    _token = response.accessToken;
    _isAuthenticated = true;
    _isLoading = false;
    _error = null;

    await _authStorage.saveToken(response.accessToken);
    ApiService.instance.setAuthToken(response.accessToken);

    notifyListeners();
  }

  void _resetAuthState() {
    _user = null;
    _token = null;
    _isAuthenticated = false;
    _error = null;
  }

  // ===================== USER CREATION =====================
  Future<bool> createUser({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required int userRole,
    int? stateId,
    int? districtId,
    int? mandalId,
  }) async {
    if (_user == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return false;
    }

    // Validate role permissions
    if (!_canCreateUserRole(userRole)) {
      _error = 'You do not have permission to create users with role: $userRole';
      notifyListeners();
      return false;
    }

    // Validate location scope
    if (!_canAssignLocation(stateId, districtId, mandalId)) {
      _error = 'You cannot assign users to locations outside your scope';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = CreateUserRequest(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        userRole: userRole,
        stateId: stateId,
        districtId: districtId,
        mandalId: mandalId,
      );

      final createdUser = await _authRepository.createUser(request);

      if (createdUser == null) {
        _error = 'Failed to create user';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();

      AlertPopupManager().showAlert(
        title: 'User Created',
        message: '${createdUser.name} has been created successfully!',
        type: AlertType.success,
      );

      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ===================== ROLE PERMISSION VALIDATION =====================
  bool _canCreateUserRole(int targetRole) {
    if (_user == null) return false;

    final currentRole = _user!.primaryRole.value;

    // Admin can create everyone
    if (currentRole == 'admin') {
      return true;
    }

    // Sub-admin can create Dist-reporters and reporters (roles 3 and 4)
    if (currentRole == 'subadmin') {
      return targetRole == 3 || targetRole == 4; // Dist-reporter and reporter
    }

    // Dist-reporter can create reporters (role 4)
    if (currentRole == 'dist-reporter') {
      return targetRole == 4; // reporter
    }

    // Others cannot create users
    return false;
  }

  bool _canAssignLocation(int? stateId, int? districtId, int? mandalId) {
    if (_user == null) return false;

    final currentRole = _user!.primaryRole.value;

    // Admin can assign anywhere
    if (currentRole == 'admin') {
      return true;
    }

    // Sub-admin can assign within their state
    if (currentRole == 'subadmin') {
      return stateId == _user!.stateId;
    }

    // Dist-reporter can assign within their scope (state/district/mandal)
    if (currentRole == 'dist-reporter') {
      if (_user!.mandalId != null) {
        return mandalId == _user!.mandalId;
      } else if (_user!.districtId != null) {
        return districtId == _user!.districtId;
      } else if (_user!.stateId != null) {
        return stateId == _user!.stateId;
      }
    }

    return false;
  }

  // ===================== GET ALLOWED ROLES =====================
  List<int> getAllowedUserRoles() {
    if (_user == null) return [];

    final currentRole = _user!.primaryRole.value;

    switch (currentRole) {
      case 'admin':
        return [2, 3, 4]; // subAdmin, Dist-reporter, reporter
      case 'subadmin':
        return [3, 4]; // Dist-reporter, reporter
      case 'dist-reporter':
        return [4]; // reporter
      default:
        return [];
    }
  }
}
