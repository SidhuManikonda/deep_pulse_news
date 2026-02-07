import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';
import '../../providers/app_providers.dart';

class AuthHelper {
  /// Shows login dialog when authentication is required for specific actions
  /// Returns true if user successfully logged in, false if cancelled
  static Future<bool> requireAuth(
    BuildContext context,
    WidgetRef ref, {
    String? message,
    String? title,
  }) async {
    // Initialize auth state to check for stored tokens
    final authViewModel = ref.read(authViewModelProvider);
    await authViewModel.initializeAuth();

    // Check current authentication state after initialization
    final authState = ref.read(authViewModelProvider);

    // If already authenticated, return true
    if (authState.isAuthenticated) {
      return true;
    }

    // Show dialog explaining why login is needed
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Login Required'),
        content: Text(
          message ??
              'You need to login to perform this action. Would you like to login now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Login'),
          ),
        ],
      ),
    );

    if (shouldLogin == true) {
      // Navigate to login screen
      await Navigator.pushNamed(context, AppRouter.login);

      // Check if login was successful
      final newAuthState = ref.read(authViewModelProvider);
      return newAuthState.isAuthenticated;
    }

    return false;
  }

  /// Check if user is authenticated without showing dialogs
  static Future<bool> isAuthenticated(WidgetRef ref) async {
    // Initialize auth state to check for stored tokens
    final authViewModel = ref.read(authViewModelProvider);
    await authViewModel.initializeAuth();
    
    final authState = ref.read(authViewModelProvider);
    return authState.isAuthenticated;
  }

  /// Get current user token if available
  static String? getAuthToken(WidgetRef ref) {
    final authState = ref.read(authViewModelProvider);
    return authState.token;
  }
}
