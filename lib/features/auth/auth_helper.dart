import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';
import '../../providers/app_providers.dart';

class AuthHelper {
  static Future<bool> requireAuth(
    BuildContext context,
    WidgetRef ref, {
    String? message,
    String? title,
  }) async {
    final authState = ref.read(authViewModelProvider);

    // Check cached auth state first (fast check)
    if (authState.isAuthenticated) {
      return true;
    }

    // If not authenticated, show login prompt
    final shouldLogin = await showDialog<bool>(
      
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
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
      await Navigator.pushNamed(context, AppRouter.login);

      final newAuthState = ref.read(authViewModelProvider);
      return newAuthState.isAuthenticated;
    }

    return false;
  }

  static Future<bool> isAuthenticated(WidgetRef ref) async {
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
