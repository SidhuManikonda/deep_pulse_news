import 'package:flutter_riverpod/legacy.dart';

import '../features/auth/auth_view_model.dart';
import '../features/onboarding/language_view_model.dart';
import '../features/onboarding/location_view_model.dart';
import '../features/onboarding/topic_viewmodel.dart';
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
final locationViewModelProvider = ChangeNotifierProvider<LocationViewModel>((ref) {
  return LocationViewModel();
});

// Auth ViewModel Provider
final authViewModelProvider = ChangeNotifierProvider<AuthViewModel>((ref) {
  return AuthViewModel();
});

// Theme Provider
final themeControllerProvider = ChangeNotifierProvider<ThemeController>((ref) {
  return ThemeController();
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
