import 'package:flutter/foundation.dart';

import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import '../../core/services/onboarding_storage.dart';
import '../../data/models/auth_response.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
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
  })  : _authRepository = authRepository ?? AuthRepositoryImpl(),
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

      notifyListeners();
    } catch (e) {
      _resetAuthState();
      ApiService.instance.setAuthToken(null);
      notifyListeners();
    }
  }

  // ===================== LOGIN =====================
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = LoginRequest(email: email, password: password);
      final response = await _authRepository.login(request);

      if (response == null) {
        _error = 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _applyAuthSuccess(response);

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
      final request = RegisterRequest(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      final response = await _authRepository.register(request);

      if (response == null) {
        _error = 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _applyAuthSuccess(response);

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

  // Merge onboarding location data into the user model
  Future<void> _mergeOnboardingLocationData() async {
    if (_user == null) return;

    try {
      // Load onboarding location data
      final selectedState = await _onboardingStorage.getSelectedState();
      final selectedDistrict = await _onboardingStorage.getSelectedDistrict();
      final selectedMandal = await _onboardingStorage.getSelectedMandal();

      // Update user model with onboarding location data if available
      _user = _user!.copyWith(
        stateId: selectedState?.id,
        stateName: selectedState?.name,
        districtId: selectedDistrict?.id,
        districtName: selectedDistrict?.name,
        mandalId: selectedMandal?.id,
        mandalName: selectedMandal?.name,
      );

      debugPrint('📍 Merged onboarding location: ${selectedState?.name}, ${selectedDistrict?.name}, ${selectedMandal?.name}');
    } catch (e) {
      debugPrint('❌ Failed to merge onboarding location data: $e');
    }
  }

  Future<void> _applyAuthSuccess(AuthResponse response) async {
    _user = response.user;
    _isLoading = false;
    _error = null;

    // Store token for persistence
    _authStorage.saveToken(response.accessToken);
    ApiService.instance.setAuthToken(response.accessToken);

    notifyListeners();
  }

  void _resetAuthState() {
    _user = null;
    _token = null;
    _isAuthenticated = false;
    _error = null;
  }
}
