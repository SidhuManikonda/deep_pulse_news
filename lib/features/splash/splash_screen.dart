import 'dart:async';

import 'package:deep_pulse_news/core/routing/app_router.dart';
import 'package:deep_pulse_news/core/services/deep_link_service.dart';
import 'package:deep_pulse_news/core/services/onboarding_storage.dart';
import 'package:deep_pulse_news/core/services/push_notification_service.dart';
import 'package:deep_pulse_news/features/home/ad_detail_screen.dart';
import 'package:deep_pulse_news/features/news/news_detail_screen_v2.dart';
import 'package:deep_pulse_news/main.dart' show navigatorKey;
import 'package:deep_pulse_news/navigators/onboarding_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_font_sizes.dart';
import '../../core/utils/onboarding_manager.dart';
import '../../shared/widgets/app_wordmark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _checkAuthAndNavigate();
  }

  // No permissions are requested here on purpose.
  //
  // Camera/photos/videos/storage used to be requested up front on every launch.
  // That asked for camera before the app had any reason to use it, and because
  // Android's "Only this time" grant is revoked once the app stops, the dialog
  // came back on every single launch.
  //
  // MediaPickerService already asks for each permission at the point of use —
  // and checks the current status first, so it prompts only when it actually
  // needs to. That is both the Android-recommended pattern and the one Play
  // expects for a justification-free camera request.

  Future<void> _checkAuthAndNavigate() async {
    debugPrint('[Splash] _checkAuthAndNavigate START');

    // Fire-and-forget — push registration must NEVER block the splash.
    // Any hang in FCM / backend should not delay app startup.
    unawaited(PushNotificationService.instance.init());

    // Hold the splash long enough for the logo animation to read.
    await Future.delayed(const Duration(seconds: 3));
    debugPrint('[Splash] timer done');

    if (!mounted) {
      debugPrint('[Splash] not mounted, aborting navigation');
      return;
    }

    try {
      debugPrint('[Splash] resolving onboarding step');
      final onboardingManager = OnboardingManager(OnboardingStorage());
      final step = await onboardingManager.getCurrentStep();
      if (!mounted) return;
      debugPrint('[Splash] step=$step, calling OnboardingNavigator.navigate');

      // If the app was cold-started via an Android App Link (e.g. WhatsApp
      // tap on https://api.deeppulse.media/news/195), DeepLinkService stored
      // the news id without pushing — splash's pushReplacementNamed would
      // otherwise stomp on it. Now that splash is done, swap splash for Home
      // (so the back stack works) and then push NewsDetail on top.
      //
      // We use the GLOBAL navigatorKey for the post-swap push: once
      // pushNamedAndRemoveUntil removes splash from the tree the SplashScreen
      // state is unmounted, so `Navigator.of(context)` (or any `mounted`
      // guard) no longer works. The global key still points at the surviving
      // root navigator, which is exactly where we want NewsDetail to land.
      final pendingNewsId = DeepLinkService.instance.consumePendingNewsId();
      if (pendingNewsId != null) {
        debugPrint('[Splash] Resuming deep link → news $pendingNewsId');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRouter.home, (_) => false);
        // Defer to next frame so Home is on top before we push on it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => NewsDetailScreenV2(initialNewsId: pendingNewsId),
              settings: RouteSettings(name: '/news/$pendingNewsId'),
            ),
          );
        });
        return;
      }

      // Same for a shared ad link: Home first, the ad on top of it.
      final pendingAdId = DeepLinkService.instance.consumePendingAdId();
      if (pendingAdId != null) {
        debugPrint('[Splash] Resuming deep link → ad $pendingAdId');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRouter.home, (_) => false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AdDetailScreen(adId: pendingAdId),
              settings: RouteSettings(name: '/ads/$pendingAdId'),
            ),
          );
        });
        return;
      }

      OnboardingNavigator.navigate(context, step);
    } catch (e, st) {
      debugPrint('[Splash] onboarding/navigate error: $e\n$st');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.locationSelection);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The wordmark carries the name in the brand's own type, so
                    // the "Deep Pulse News" text that used to sit under the
                    // mark would only repeat it.
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: AppWordmark(height: 88, borderRadius: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stay Updated with Latest News',
                      style: TextStyle(
                        fontSize: scaledFontSize(16),
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
