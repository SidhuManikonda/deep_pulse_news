import 'package:deep_pulse_news/features/admin/admin_user_management_controller.dart';
import 'package:deep_pulse_news/features/admin/ads_management_controller.dart';
import 'package:deep_pulse_news/features/admin/location_management_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/comments_repository.dart';
import '../features/auth/auth_view_model.dart';
import '../features/onboarding/language_view_model.dart';
import '../features/onboarding/location_view_model.dart';
import '../features/onboarding/topic_viewmodel.dart';
import 'auto_play_controller.dart';
import 'theme_controller.dart';

// Language ViewModel Provider
final languageViewModelProvider = ChangeNotifierProvider<LanguageViewModel>((
  ref,
) {
  return LanguageViewModel();
});
// Topic ViewModel Provider
final topicViewModelProvider = ChangeNotifierProvider<TopicViewmodel>((ref) {
  return TopicViewmodel();
});

// Location ViewModel Provider
final locationViewModelProvider = ChangeNotifierProvider<LocationViewModel>((
  ref,
) {
  return LocationViewModel();
});

// Auth ViewModel Provider
final authViewModelProvider = ChangeNotifierProvider<AuthViewModel>((ref) {
  return AuthViewModel();
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// Comments Repository Provider
final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  return CommentsRepositoryImpl();
});

// Comments ViewModel Provider - removed family, will create directly in widget

// Theme Provider
final themeControllerProvider = ChangeNotifierProvider<ThemeController>((ref) {
  return ThemeController();
});

// Auto-play Provider — whether news videos play automatically in the feed.
final autoPlayProvider = ChangeNotifierProvider<AutoPlayController>((ref) {
  return AutoPlayController();
});

// Selected Topics Provider
final selectedTopicsProvider = StateProvider<List<String>>((ref) => []);

// Current Tab Provider
final currentTabProvider = StateProvider<int>((ref) => 0);

// Search Query Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

// Loading State Provider
final loadingProvider = StateProvider<bool>((ref) => false);

// Error State Provider
final errorProvider = StateProvider<String?>((ref) => null);

final adminUserManagementControllerProvider =
    ChangeNotifierProvider<AdminUserManagementController>((ref) {
      return AdminUserManagementController();
    });

final locationManagementControllerProvider =
    ChangeNotifierProvider<LocationManagementController>((ref) {
      return LocationManagementController();
    });

final adsManagementControllerProvider =
    ChangeNotifierProvider<AdsManagementController>((ref) {
      return AdsManagementController();
    });
