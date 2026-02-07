import 'package:deep_pulse_news/core/services/onboarding_storage.dart';
import 'package:deep_pulse_news/enums/onboarding_enum.dart';

class OnboardingManager {
  final OnboardingStorage _onboardingStorage;
  OnboardingManager(this._onboardingStorage);
  
  /// Gets the current onboarding step
  /// Flow: Location → Language → Topics → Completed (Home)
  Future<OnboardingStep> getCurrentStep() async {
    // Check if all onboarding steps are completed
    if (await _onboardingStorage.isOnboardingCompleted()) {
      return OnboardingStep.completed;
    }
    
    // Check if location and language are done, but topics is not
    if (await _onboardingStorage.isLocationCompleted() &&
        await _onboardingStorage.isLanguageCompleted() &&
        !await _onboardingStorage.isTopicsCompleted()) {
      return OnboardingStep.topics;
    }
    
    // Check if location is done but language is not
    if (await _onboardingStorage.isLocationCompleted() &&
        !await _onboardingStorage.isLanguageCompleted()) {
      return OnboardingStep.language;
    }
    
    // Default: start with location selection
    return OnboardingStep.location;
  }
  
  /// Mark onboarding as completed and navigate to home
  Future<void> completeOnboarding() async {
    await _onboardingStorage.setOnboardingCompleted();
  }
}
