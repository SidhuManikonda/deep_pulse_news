import 'package:deep_pulse_news/core/services/onboarding_storage.dart';
import 'package:deep_pulse_news/enums/onboarding_enum.dart';

class OnboardingManager {
  final OnboardingStorage _onboardingStorage;
  OnboardingManager(this._onboardingStorage);
  
  /// Gets the current onboarding step
  /// Flow: Location → Completed (Home)
  ///
  /// Language and topics selection were dropped from onboarding; picking a
  /// location is the only step left. `isLocationCompleted` is also accepted as
  /// "done" so existing installs that were parked mid-flow (location saved,
  /// language/topics never answered) land on home instead of a dead route.
  Future<OnboardingStep> getCurrentStep() async {
    if (await _onboardingStorage.isOnboardingCompleted() ||
        await _onboardingStorage.isLocationCompleted()) {
      return OnboardingStep.completed;
    }

    return OnboardingStep.location;
  }
  
  /// Mark onboarding as completed and navigate to home
  Future<void> completeOnboarding() async {
    await _onboardingStorage.setOnboardingCompleted();
  }
}
