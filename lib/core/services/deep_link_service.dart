import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/home/ad_detail_screen.dart';
import '../../features/news/news_detail_screen_v2.dart';
import '../../main.dart' show navigatorKey;

/// Listens for Android App Links / iOS Universal Links and routes them.
///
/// Handles news and shared-ad deeplinks:
///   https://api.deeppulse.media/news/{id}
///   https://api.deeppulse.media/ads/{id}
///
/// Two entry points exist intentionally:
///   • Cold start  — app launched by tapping a link (no prior process)
///   • Warm start  — app was already running when the link was tapped
/// `app_links` exposes both via `getInitialLink()` and `uriLinkStream`.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Holds the news id extracted from the launching URL on cold start until
  /// the splash screen finishes its own navigation. Splash calls
  /// [consumePendingNewsId] right after `OnboardingNavigator.navigate`, and
  /// uses the value to push `NewsDetailScreenV2` on top of `HomeScreen` —
  /// otherwise splash's `pushReplacementNamed` would overwrite anything we
  /// pushed earlier and the user would end up on Home instead of the news.
  int? _pendingNewsId;

  /// Same as [_pendingNewsId], for a shared ad link.
  int? _pendingAdId;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLink] Cold start URI: $initialUri');
        // Don't push here — store the id and let SplashScreen drain it after
        // its onboarding-aware navigation completes. Pushing now would race
        // with splash's `pushReplacementNamed(/home)` (fires after a 3-second
        // delay) which would replace the news detail with Home.
        _pendingNewsId = _extractId(initialUri, 'news');
        _pendingAdId = _extractId(initialUri, 'ads');
      }
    } catch (e) {
      debugPrint('[DeepLink] Failed to read initial link: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLink] Warm-start URI: $uri');
        _handleUri(uri);
      },
      onError: (Object e) {
        debugPrint('[DeepLink] Stream error: $e');
      },
    );
  }

  /// Returns the cold-start news id once (and clears it). Called by
  /// SplashScreen after it finishes its routing decision, so the splash can
  /// push `Home` first and then `NewsDetail` on top — preserving a working
  /// back stack instead of overwriting the deep-link destination.
  int? consumePendingNewsId() {
    final id = _pendingNewsId;
    _pendingNewsId = null;
    return id;
  }

  /// Same as [consumePendingNewsId], for a shared ad link.
  int? consumePendingAdId() {
    final id = _pendingAdId;
    _pendingAdId = null;
    return id;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }

  void _handleUri(Uri uri) {
    final newsId = _extractId(uri, 'news');
    if (newsId != null) {
      _open('/news/$newsId', (_) => NewsDetailScreenV2(initialNewsId: newsId));
      return;
    }
    final adId = _extractId(uri, 'ads');
    if (adId != null) {
      _open('/ads/$adId', (_) => AdDetailScreen(adId: adId));
      return;
    }
    debugPrint('[DeepLink] Not a news or ad URL, ignoring: $uri');
  }

  /// Pulls the numeric id from `/{kind}/{id}` (also tolerates an extra
  /// trailing path segment or query string — `/news/195?utm=...` works).
  int? _extractId(Uri uri, String kind) {
    if (uri.host != 'api.deeppulse.media') return null;
    final segments = uri.pathSegments;
    if (segments.length < 2) return null;
    if (segments[0] != kind) return null;
    return int.tryParse(segments[1]);
  }

  /// Pushes the linked screen onto the global navigator. On cold start
  /// the URI arrives before the navigator is mounted (the splash screen is
  /// still initializing), so we retry a few times with short delays until the
  /// navigator becomes available. Once the splash → home transition lands,
  /// `navigatorKey.currentState` resolves and the deep-link destination is
  /// pushed on top — giving the user a working back stack (NewsDetail → Home).
  ///
  /// Skips the push if `AppRouter.generateRoute` already routed the cold-start
  /// URL to the same screen (avoids a duplicate screen on the stack when both
  /// the initial-route path AND `app_links.getInitialLink()` fire the same
  /// deep link).
  Future<void> _open(String routeName, WidgetBuilder builder) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        if (_topRouteName(navigator) == routeName) {
          debugPrint(
            '[DeepLink] $routeName already on top — skipping duplicate push',
          );
          return;
        }
        navigator.push(
          MaterialPageRoute(
            builder: builder,
            settings: RouteSettings(name: routeName),
          ),
        );
        debugPrint('[DeepLink] Opened $routeName (attempt $attempt)');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    debugPrint(
      '[DeepLink] Gave up after 20 attempts — navigator never became ready '
      'for $routeName',
    );
  }

  String _topRouteName(NavigatorState navigator) {
    Route<dynamic>? topRoute;
    navigator.popUntil((route) {
      topRoute = route;
      return true;
    });
    return topRoute?.settings.name ?? '';
  }
}
