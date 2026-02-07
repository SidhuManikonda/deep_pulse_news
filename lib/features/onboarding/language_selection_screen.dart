import 'package:deep_pulse_news/core/constants/app_colors.dart';
import 'package:deep_pulse_news/core/routing/app_router.dart';
import 'package:deep_pulse_news/core/services/onboarding_storage.dart';
import 'package:deep_pulse_news/core/utils/onboarding_manager.dart';
import 'package:deep_pulse_news/features/onboarding/language_view_model.dart';
import 'package:deep_pulse_news/navigators/onboarding_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/shimmer_widget.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  @override
  void initState() {
    super.initState();
    // Load languages when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(languageViewModelProvider).loadLanguages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageViewModel = ref.watch(languageViewModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Language icon with translation symbol - matching the design
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'अ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: _buildLanguageList(languageViewModel: languageViewModel),
              ),
              const SizedBox(height: 20),
              Text(
                'Language not available?',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).appGrey600,
                ),
              ),
              const SizedBox(height: 40),
              if (languageViewModel.selectedLanguage != null)
                CustomButton(
                  text: 'Continue',
                  onPressed: () async {
                    try {
                      final storage = OnboardingStorage();
                      
                      // Save selected language to storage
                      final selectedLang = languageViewModel.selectedLanguage;
                      if (selectedLang != null) {
                        // Find the language object to get ID and name
                        final language = languageViewModel.languages.firstWhere(
                          (lang) => lang.slug == selectedLang,
                        );
                        await storage.saveSelectedLanguage(language.id, language.name);
                      }
                      
                      await storage.setLanguageCompleted();

                      final onboardingManager = OnboardingManager(storage);
                      final step = await onboardingManager.getCurrentStep();

                      OnboardingNavigator.navigate(
                        context,
                        step,
                        replace: false,
                      );
                    } catch (e) {
                      debugPrint('Language onboarding error: $e');
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRouter.languageSelection,
                        (_) => false,
                      );
                    }
                  },

                  backgroundColor: const Color(0xFF2196F3),
                  textColor: Colors.white,
                  width: double.infinity,
                  height: 56,
                  borderRadius: 12,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageList({required LanguageViewModel languageViewModel}) {
    if (languageViewModel.isLoading) {
      return _buildLanguageShimmerGrid();
    }

    if (languageViewModel.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load languages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).appPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).appGrey300,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                languageViewModel.retryLoadLanguages();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!languageViewModel.hasLanguages) {
      return const Center(
        child: Text(
          'No languages available',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: languageViewModel.languages.length,
      itemBuilder: (context, index) {
        final language = languageViewModel.languages[index];
        final isSelected = languageViewModel.selectedLanguage == language.slug;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              languageViewModel.setSelectedLanguage(language.slug);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).selectedLanguageColor
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? Theme.of(
                        context,
                      ).selectedLanguageColor.withValues(alpha: 0.05)
                    : Colors.grey[50],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        languageViewModel.getFlagForLanguage(language.slug),
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getLanguageDisplayName(language.name),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF2196F3)
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getLanguageSubtitle(language.name),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageShimmerGrid() {
    const shimmerItemCount = 12; // Typical number of languages

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: shimmerItemCount,
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).appGrey50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flag and language name shimmer
              Row(
                children: [
                  // Flag shimmer (smaller circle)
                  ShimmerWidget(
                    width: 20,
                    height: 20,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 8),
                  // Language name shimmer (longer rectangle)
                  Expanded(
                    child: ShimmerWidget(
                      width: double.infinity,
                      height: 18,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Subtitle shimmer (shorter)
              ShimmerWidget(
                width: 60,
                height: 14,
                borderRadius: BorderRadius.circular(7),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLanguageDisplayName(String languageName) {
    // Map to display native script names as shown in the screenshot
    const languageDisplayMap = {
      'English': 'English',
      'Hindi': 'हिंदी',
      'Gujarati': 'ગુજરાતી',
      'Kannada': 'ಕನ್ನಡ',
      'Tamil': 'தமிழ்',
      'Telugu': 'తెలుగు',
      'Bengali': 'বাংলা',
      'Oriya': 'ଓଡ଼ିଆ',
      'Marathi': 'मराठी',
      'Punjabi': 'ਪੰਜਾਬੀ',
      'Malayalam': 'മലയാളം',
    };
    return languageDisplayMap[languageName] ?? languageName;
  }

  String _getLanguageSubtitle(String languageName) {
    // Map to display English names as subtitles
    const languageSubtitleMap = {
      'English': 'English',
      'Hindi': 'Hindi',
      'Gujarati': 'Gujarati',
      'Kannada': 'Kannada',
      'Tamil': 'Tamil',
      'Telugu': 'Telugu',
      'Bengali': 'Bengali',
      'Oriya': 'Oriya',
      'Marathi': 'Marathi',
      'Punjabi': 'Punjabi',
      'Malayalam': 'Malayalam',
    };
    return languageSubtitleMap[languageName] ?? languageName;
  }
}
