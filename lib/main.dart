import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/deep_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Global navigator key — lets services (e.g. push notification tap handler)
/// push routes without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(themeControllerProvider).init();
      ref.read(autoPlayProvider).init();
      // Start listening for Android App Links (api.deeppulse.media/news/{id}).
      // Must run after the navigator is mounted so cold-start pushes land.
      DeepLinkService.instance.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ref.watch(themeControllerProvider);

    return MaterialApp(
      title: 'Deep Pulse News',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeController.themeMode,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
      // Always start the app at the splash screen, regardless of how it was
      // launched (e.g. an Android App Link like /news/195). Without this,
      // Flutter passes the URL's path straight to onGenerateRoute, which has
      // no `/news/{id}` route and shows "No route defined for /news/...".
      // Deep links are still handled — DeepLinkService (app_links) reads the
      // launching URL after MaterialApp builds and pushes NewsDetailScreenV2
      // on top of the normal navigation stack.
      onGenerateInitialRoutes: (initialRouteName) {
        return [
          AppRouter.generateRoute(
            const RouteSettings(name: AppRouter.splash),
          ),
        ];
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
