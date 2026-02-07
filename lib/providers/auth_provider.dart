// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_riverpod/legacy.dart';
// import '../data/models/auth_response.dart';
// import '../data/models/user.dart';
// import '../data/repositories/auth_repository.dart';
// // Auth Provider using ChangeNotifierProvider
// final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
//   final authRepository = ref.watch(authRepositoryProvider);
//   return AuthProvider(authRepository);
// });

// // Auth Repository Provider
// final authRepositoryProvider = Provider<AuthRepository>((ref) {
//   return AuthRepositoryImpl();
// });

// // Auth Provider using ChangeNotifier
// class AuthProvider extends ChangeNotifier {
//   final AuthRepository _authRepository;

//   AuthProvider(this._authRepository);

//   // Private fields
//   User? _user;
//   String? _token;
//   bool _isLoading = false;
//   String? _error;
//   bool _isAuthenticated = false;

//   // Getters
//   User? get user => _user;
//   String? get token => _token;
//   bool get isLoading => _isLoading;
//   String? get error => _error;
//   bool get isAuthenticated => _isAuthenticated;

//   // Setters
//   set user(User? value) {
//     _user = value;
//     notifyListeners();
//   }

//   set token(String? value) {
//     _token = value;
//     notifyListeners();
//   }

//   set isLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }

//   set error(String? value) {
//     _error = value;
//     notifyListeners();
//   }

//   set isAuthenticated(bool value) {
//     _isAuthenticated = value;
//     notifyListeners();
//   }

//   Future<bool> register({
//     required String name,
//     required String email,
//     required String mobile,
//     required String password,
//     required String passwordConfirmation,
//   }) async {
//     isLoading = true;
//     error = null;

//     try {
//       final request = RegisterRequest(
//         name: name,
//         email: email,
//         mobile: mobile,
//         password: password,
//         passwordConfirmation: passwordConfirmation,
//       );

//       final response = await _authRepository.register(request);

//       if (response != null) {
//         user = response.user;
//         token = response.accessToken;
//         isAuthenticated = true;
//         isLoading = false;
//         return true;
//       } else {
//         error = 'Registration failed';
//         isLoading = false;
//         return false;
//       }
//     } catch (e) {
//       error = e.toString();
//       isLoading = false;
//       return false;
//     }
//   }

//   Future<bool> login({
//     required String email,
//     required String password,
//   }) async {
//     isLoading = true;
//     error = null;

//     try {
//       final request = LoginRequest(
//         email: email,
//         password: password,
//       );

//       final response = await _authRepository.login(request);

//       if (response != null) {
//         user = response.user;
//         token = response.accessToken;
//         isAuthenticated = true;
//         isLoading = false;
//         return true;
//       } else {
//         error = 'Login failed';
//         isLoading = false;
//         return false;
//       }
//     } catch (e) {
//       error = e.toString();
//       isLoading = false;
//       return false;
//     }
//   }

//   Future<void> logout() async {
//     isLoading = true;

//     try {
//       await _authRepository.logout();
//       // Reset to initial state
//       user = null;
//       token = null;
//       isAuthenticated = false;
//       isLoading = false;
//       error = null;
//     } catch (e) {
//       error = e.toString();
//       isLoading = false;
//     }
//   }

//   void clearError() {
//     error = null;
//   }
// }


// // Convenience providers
// final currentUserProvider = Provider<User?>((ref) {
//   return ref.watch(authProvider).user;
// });

// final isAuthenticatedProvider = Provider<bool>((ref) {
//   return ref.watch(authProvider).isAuthenticated;
// });

// final authLoadingProvider = Provider<bool>((ref) {
//   return ref.watch(authProvider).isLoading;
// });

// final authErrorProvider = Provider<String?>((ref) {
//   return ref.watch(authProvider).error;
// });
