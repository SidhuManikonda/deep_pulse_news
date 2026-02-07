import 'package:deep_pulse_news/core/routing/app_router.dart';
import 'package:deep_pulse_news/enums/onboarding_enum.dart';
import 'package:flutter/material.dart';

class OnboardingNavigator {
  static void navigate(
    BuildContext context,
    OnboardingStep step, {
    bool replace = true,
  }) {
    final route = _routeForStep(step);
    if (replace) {
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
    }
  }

  static String _routeForStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.location:
        return AppRouter.locationSelection;
      case OnboardingStep.completed:
        return AppRouter.home;
      case OnboardingStep.language:
        return AppRouter.languageSelection;
      case OnboardingStep.topics:
        return AppRouter.topicsSelection;
    }
  }
}
