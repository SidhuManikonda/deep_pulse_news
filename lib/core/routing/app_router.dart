import 'package:flutter/material.dart';

import '../../features/auth/gmail_sso_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/phone_hint_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/news/news_detail_screen_v2.dart';
import '../../features/onboarding/location_selection_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/splash/splash_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String phoneHint = '/phone-hint';
  static const String login = '/login';
  static const String gmailSso = '/gmail-sso';
  static const String register = '/register';
  static const String locationSelection = '/location-selection';
  static const String home = '/home';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      // case phoneHint:
      //   return MaterialPageRoute(builder: (_) => const PhoneHintScreen());
      // case login:
      //   return MaterialPageRoute(builder: (_) => const LoginScreen());
      case gmailSso:
        return MaterialPageRoute(builder: (_) => const GmailSsoScreen());
      // case register:
      //   return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case locationSelection:
        return MaterialPageRoute(builder: (_) => const LocationSelectionScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
        // Android App Link deep link: when the app is launched via a URL
        // like https://api.deeppulse.media/news/195, Flutter passes the URL
        // path ("/news/195") to onGenerateRoute as the initial route. Catch
        // that pattern here and open the news detail screen directly so the
        // user lands on the article instead of seeing a generic 404.
        final name = settings.name ?? '';
        if (name.startsWith('/news/')) {
          final id = int.tryParse(name.substring('/news/'.length));
          if (id != null) {
            return MaterialPageRoute(
              builder: (_) => NewsDetailScreenV2(initialNewsId: id),
              settings: settings,
            );
          }
        }
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
