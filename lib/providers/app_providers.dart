import '../data/repositories/ads_repository.dart';
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

/// Ad routes used by the reader feed — like, share, report — as opposed to the
/// management controller above, which is the admin's create/edit/list surface.
final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepositoryImpl();
});

final adsManagementControllerProvider =
    ChangeNotifierProvider<AdsManagementController>((ref) {
      return AdsManagementController();
    });

/// The article a feed tab has settled on, keyed by tab.
///
/// A provider rather than widget state because of who reads it: every card on
/// screen, only to answer "am I the active page?". Held in the pager's own
/// `setState` it marked the whole `PageView` dirty on every swipe, so both
/// full-screen cards — image, video, overlays — rebuilt in the middle of the
/// page animation. Measured on device that cost 3–4 dropped frames per page
/// change, the one hitch in an otherwise steady 90fps feed.
///
/// Cards now `select` the single boolean they care about, so a swipe rebuilds
/// only the two whose active-ness actually flipped and leaves the rest — and
/// the pager itself — untouched.
///
/// Keyed by tab, and deliberately not auto-disposed: a tab keeps its place
/// while the reader is away in another one, which is the same thing
/// `_tabPositions` remembers for the initial page.
final feedPageProvider = StateProvider.family<int, String>((ref, tabKey) => 0);

/// Whether a pull-to-refresh is in flight, keyed by tab. Same reasoning: only
/// the spinner cares, so only the spinner should rebuild.
final feedRefreshingProvider = StateProvider.family<bool, String>(
  (ref, tabKey) => false,
);

/// Which photo a card's media carousel is showing, keyed by the card's index
/// in the feed.
///
/// Was a `Map` on the home screen's own state, written through `setState` — so
/// swiping the photos inside one card rebuilt the entire home screen, tabs and
/// every other card included. Only the carousel's own dots need to know.
final carouselPageProvider = StateProvider.family<int, int>(
  (ref, cardIndex) => 0,
);

/// Unread notification count behind the bell badge.
///
/// Only the badge reads it, so only the badge should rebuild when it changes —
/// through `setState` on the home screen it redrew the feed, the tabs and every
/// card to change a number in the corner.
final unreadNotificationsProvider = StateProvider<int>((ref) => 0);
