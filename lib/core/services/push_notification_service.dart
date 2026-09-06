import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/notification_repository.dart';
import '../../features/news/news_detail_screen_v2.dart';
import '../../main.dart' show navigatorKey;
import 'auth_storage.dart';
import 'onboarding_storage.dart';

class PushNotificationService {
  PushNotificationService._({
    NotificationRepository? notificationRepository,
    OnboardingStorage? onboardingStorage,
    AuthStorage? authStorage,
  }) : _repo = notificationRepository ?? NotificationRepositoryImpl(),
       _onboardingStorage = onboardingStorage ?? OnboardingStorage(),
       _authStorage = authStorage ?? AuthStorage();

  static final PushNotificationService instance = PushNotificationService._();

  static const _kDeviceIdKey = 'device_id';
  static const _kFcmTokenKey = 'fcm_token_cache';
  static const _kRegisteredAsUserIdKey = 'fcm_registered_as_user_id';

  /// Heads-up channel for article pushes. Max importance is what makes Android
  /// float the notification over the top of the screen instead of dropping it
  /// silently into the shade. AndroidManifest points
  /// `default_notification_channel_id` at this same id so a push that arrives
  /// while the app is backgrounded behaves identically.
  static const _kChannelId = 'deep_pulse_news_alerts';
  static const _kChannelName = 'News alerts';

  final NotificationRepository _repo;
  final OnboardingStorage _onboardingStorage;
  final AuthStorage _authStorage;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsReady = false;

  // ── DEVICE ID — fully working ────────────────────────────────────────────

  /// Returns a stable UUID v4 for this install.
  /// Generated on first call, then cached forever in SharedPreferences.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_kDeviceIdKey, id);
      debugPrint('[PushNotificationService] Generated new device_id: $id');
    }
    return id;
  }

  // ── FCM TOKEN ────────────────────────────────────────────────────────────

  /// Asks the OS for permission (no-op on Android < 13) and returns the
  /// device's current FCM token. Cached locally for diagnostics.
  Future<String?> getFcmToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[PushNotificationService] Notification permission: '
        '${settings.authorizationStatus}',
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _cacheFcmToken(token);
        debugPrint('[PushNotificationService] FCM token: ${_maskToken(token)}');
        return token;
      }
      debugPrint('[PushNotificationService] FCM returned null token');
      return null;
    } catch (e) {
      debugPrint('[PushNotificationService] getFcmToken error: $e');
      return null;
    }
  }

  /// Subscribes to FCM token rotation events and re-registers with backend
  /// using the current auth state — to the logged-in user when a session
  /// exists, otherwise as a guest.
  void listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      debugPrint(
        '[PushNotificationService] onTokenRefresh fired: '
        '${_maskToken(token)}',
      );
      await _cacheFcmToken(token);
      await _reRegisterCurrentToken(token);
    });
  }

  /// Re-binds [token] to whoever owns this device right now: the logged-in
  /// user (authed `/fcm-token`) if a session token exists, else the guest
  /// channel. Used by token-refresh so a rotated token never silently
  /// detaches a logged-in user from notifications.
  Future<void> _reRegisterCurrentToken(String token) async {
    if (await _authStorage.hasToken()) {
      final ok = await _repo.saveUserToken(fcmToken: token);
      debugPrint(
        '[PushNotificationService] re-registered token for logged-in user '
        '(ok=$ok)',
      );
    } else {
      await registerAsGuest(fcmToken: token);
    }
  }

  Future<void> _cacheFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFcmTokenKey, token);
  }

  // ── PUBLIC API ───────────────────────────────────────────────────────────

  /// Call once after splash. Idempotent — safe to call on every app launch.
  ///
  /// Behavior:
  ///   - ensures device_id exists
  ///   - obtains FCM token (currently stub → null, so no network call yet)
  ///   - registers the device with backend as a guest using the user's
  ///     currently-selected location from OnboardingStorage
  Future<void> init() async {
    try {
      final deviceId = await getDeviceId();
      debugPrint('[PushNotificationService] init — device_id=$deviceId');

      // Wait briefly so we don't collide with the splash's permission burst
      // (camera/photos/videos/storage). Android only allows one set of
      // permission requests at a time — running ours concurrently throws
      // "Can request only one set of permissions at a time".
      await Future.delayed(const Duration(seconds: 4));

      // Cap the whole token-fetch + registration sequence so a flaky FCM
      // server or unreachable backend can never hang the app.
      final token = await getFcmToken().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[PushNotificationService] getFcmToken timed out');
          return null;
        },
      );
      if (token == null) return;

      // Only (re)register as guest when there is no logged-in session. A
      // logged-in user's token is bound to their account by the auth flow
      // (`saveTokenForLoggedInUser` on login and on session-restore), so
      // registering as guest here would detach them from their notifications.
      if (!await _authStorage.hasToken()) {
        await registerAsGuest(fcmToken: token).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('[PushNotificationService] registerAsGuest timed out');
            return false;
          },
        );
      } else {
        debugPrint(
          '[PushNotificationService] init — logged-in session present, '
          'skipping guest registration (auth flow owns the token).',
        );
      }
      listenForTokenRefresh();
      // Create the heads-up channel up front so backgrounded pushes (routed
      // there by the manifest's default_notification_channel_id) also float
      // at the top instead of landing silently in the shade.
      await _initLocalNotifications();
      _registerForegroundListener();

      _registerBackgroundTapListener();

      _checkInitialMessage();
    } catch (e, st) {
      debugPrint('[PushNotificationService] init failed (ignored): $e\n$st');
    }
  }

  Future<bool> registerAsGuest({String? fcmToken}) async {
    final token = fcmToken ?? await getFcmToken();
    if (token == null) return false;

    final deviceId = await getDeviceId();
    final state = await _onboardingStorage.getSelectedState();
    final district = await _onboardingStorage.getSelectedDistrict();
    final mandal = await _onboardingStorage.getSelectedMandal();

    final ok = await _repo.registerGuestToken(
      deviceId: deviceId,
      fcmToken: token,
      stateId: state?.id,
      districtId: district?.id,
      mandalId: mandal?.id,
    );

    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kRegisteredAsUserIdKey);
      debugPrint(
        '[PushNotificationService] Registered as guest. '
        'state=${state?.id} district=${district?.id} mandal=${mandal?.id}',
      );
    }
    return ok;
  }

  Future<bool> saveTokenForLoggedInUser({
    required int userId,
    String? fcmToken,
  }) async {
    final token = fcmToken ?? await getFcmToken();
    if (token == null) return false;

    final ok = await _repo.saveUserToken(fcmToken: token);
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kRegisteredAsUserIdKey, userId);
      debugPrint('[PushNotificationService] Token saved for user_id=$userId');
    }
    return ok;
  }

  Future<void> onLogout() async {
    debugPrint('[PushNotificationService] onLogout — re-registering as guest');
    await registerAsGuest();
  }

  Future<void> onLocationChanged() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.containsKey(_kRegisteredAsUserIdKey);
    if (isLoggedIn) return;
    await registerAsGuest();
  }

  /// Prepares the local-notification plugin and its heads-up channel. Safe to
  /// call repeatedly — only the first call does work.
  Future<void> _initLocalNotifications() async {
    if (_localNotificationsReady) return;

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // FirebaseMessaging.requestPermission() already asked for alert/badge/
        // sound, so don't prompt a second time from here.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) _routeFromPayload(data);
        } catch (e) {
          debugPrint('[PushNotificationService] bad tap payload: $e');
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            description: 'New articles and updates from Deep Pulse',
            importance: Importance.max,
          ),
        );

    _localNotificationsReady = true;
  }

  /// Posts a system notification for a push that arrived while the app is in
  /// the foreground. Android suppresses FCM's own notification in that case,
  /// so without this the message would either be invisible or (as before) get
  /// shown as an in-app SnackBar pinned to the bottom of the screen.
  Future<void> _showHeadsUpNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    int? newsId,
  }) async {
    try {
      await _initLocalNotifications();

      // Re-using the article id means a second push about the same article
      // replaces the first instead of stacking a duplicate.
      final id =
          newsId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7FFFFFFF;
      final shownTitle = title.isNotEmpty ? title : 'Deep Pulse';

      await _localNotifications.show(
        id,
        shownTitle,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _kChannelId,
            _kChannelName,
            channelDescription: 'New articles and updates from Deep Pulse',
            importance: Importance.max,
            priority: Priority.high,
            ticker: shownTitle,
            // Telugu headlines routinely run past one line; BigText lets the
            // expanded notification show the whole thing.
            styleInformation: BigTextStyleInformation(
              body,
              contentTitle: shownTitle,
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(data),
      );
    } catch (e) {
      debugPrint('[PushNotificationService] failed to show heads-up: $e');
    }
  }

  void _registerForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[PushNotificationService] onMessage (foreground): '
        'data=${message.data}',
      );

      final data = message.data;
      final notification = message.notification;

      final title = (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : (notification?.title ?? '');
      final body = (data['message'] as String?)?.trim().isNotEmpty == true
          ? data['message'] as String
          : ((data['body'] as String?) ??
                (data['description'] as String?) ??
                notification?.body ??
                '');
      final newsIdStr = data['news_id']?.toString();
      final newsId = newsIdStr != null ? int.tryParse(newsIdStr) : null;

      if (title.isEmpty && body.isEmpty) {
        debugPrint(
          '[PushNotificationService] Foreground push had no '
          'title/body — nothing to show.',
        );
        return;
      }

      _showHeadsUpNotification(
        title: title,
        body: body,
        data: data,
        newsId: newsId,
      );
    });
  }

  void _registerBackgroundTapListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[PushNotificationService] onMessageOpenedApp: '
        'data=${message.data}',
      );
      _routeFromPayload(message.data);
    });
  }

  Future<void> _checkInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;
    debugPrint(
      '[PushNotificationService] getInitialMessage: '
      'data=${initial.data}',
    );
    // Small delay so the app finishes booting (splash → home transition).
    await Future.delayed(const Duration(milliseconds: 600));
    await _routeFromPayload(initial.data);
  }

  /// Pulls a route target out of an FCM data block. Prefers `news_id`
  /// (current Laravel notification shape) and falls back to a legacy
  /// `deeplink` URI for older payloads.
  Future<void> _routeFromPayload(Map<String, dynamic> data) async {
    final newsIdStr = data['news_id']?.toString();
    final newsId = newsIdStr != null ? int.tryParse(newsIdStr) : null;
    if (newsId != null) {
      await _openNewsDetail(newsId);
      return;
    }
    final deeplink = data['deeplink'] as String?;
    if (deeplink != null && deeplink.isNotEmpty) {
      await _handleDeeplink(deeplink);
    }
  }

  /// Parses a `deeppulse://...` deeplink and routes accordingly.
  ///
  /// Supported today:
  ///   - `deeppulse://news/{id}` — opens the news detail screen.
  ///
  /// More routes (comments, admin/review, announcements) can be added by
  /// extending the switch below. Unknown deeplinks are logged and ignored.
  Future<void> _handleDeeplink(String deeplink) async {
    debugPrint('[PushNotificationService] _handleDeeplink: $deeplink');
    final uri = Uri.tryParse(deeplink);
    if (uri == null || uri.scheme != 'deeppulse') {
      debugPrint('[PushNotificationService] Unsupported deeplink scheme');
      return;
    }

    switch (uri.host) {
      case 'news':
        final idStr = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.first
            : null;
        final id = idStr != null ? int.tryParse(idStr) : null;
        if (id != null) await _openNewsDetail(id);
        break;
      default:
        debugPrint(
          '[PushNotificationService] Unknown deeplink host: '
          '${uri.host}',
        );
    }
  }

  Future<void> _openNewsDetail(int newsId) async {
    final state = navigatorKey.currentState;
    if (state == null) {
      debugPrint(
        '[PushNotificationService] Could not open news $newsId — navigator '
        'not ready.',
      );
      return;
    }
    // Hand off the id; the detail screen fetches the article itself with
    // its own loader/error UI. Saves us a redundant getNewsById round-trip
    // and gives users immediate visual feedback that something is loading.
    state.push(
      MaterialPageRoute(
        builder: (_) => NewsDetailScreenV2(initialNewsId: newsId),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  String _maskToken(String token) {
    if (token.length <= 12) return token;
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
  }
}
