import 'package:flutter/material.dart';

import '../../features/auth/gmail_sso_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/phone_hint_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/language_selection_screen.dart';
import '../../features/onboarding/location_selection_screen.dart';
import '../../features/onboarding/topics_selection_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/splash/splash_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String phoneHint = '/phone-hint';
  static const String login = '/login';
  static const String gmailSso = '/gmail-sso';
  static const String register = '/register';
  static const String locationSelection = '/location-selection';
  static const String languageSelection = '/language-selection';
  static const String topicsSelection = '/topics-selection';
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
      case languageSelection:
        return MaterialPageRoute(builder: (_) => const LanguageSelectionScreen());
      case topicsSelection:
        return MaterialPageRoute(builder: (_) => const TopicsSelectionScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
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
