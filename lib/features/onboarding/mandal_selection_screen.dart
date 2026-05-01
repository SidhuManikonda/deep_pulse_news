import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/onboarding_storage.dart';
import '../../core/utils/onboarding_manager.dart';
import '../../enums/onboarding_enum.dart';
import '../../data/models/mandal.dart';
import '../../navigators/onboarding_navigator.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/shimmer_widget.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../features/onboarding/location_view_model.dart';

class MandalSelectionScreen extends ConsumerWidget {
  const MandalSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationViewModel = ref.watch(locationViewModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Select Mandal (Your Area)',
          style: TextStyle(
            fontSize: appFontSizeTitle,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.headlineLarge?.color,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header section
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.place, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose your Mandal(Your Area)',
                    style: TextStyle(
                      fontSize: appFontSizeHeader,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (locationViewModel.selectedState != null &&
                      locationViewModel.selectedDistrict != null) ...[
                    Text(
                      'in ${locationViewModel.selectedDistrict!.name}, ${locationViewModel.selectedState!.name}',
                      style: TextStyle(
                        fontSize: appFontSizeBody,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // Mandals list
            Expanded(child: _buildMandalsList(context, locationViewModel, ref)),

            // Continue button (shown when mandal is selected)
            if (locationViewModel.selectedMandal != null) ...[
              Padding(
                padding: const EdgeInsets.all(24),
                child: CustomButton(
                  text: 'Continue',
                  onPressed: () => _handleContinue(context, locationViewModel),
                  backgroundColor: const Color(0xFF2196F3),
                  textColor: Colors.white,
                  width: double.infinity,
                  height: 56,
                  borderRadius: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMandalsList(
    BuildContext context,
    LocationViewModel locationViewModel,
    WidgetRef ref,
  ) {
    if (locationViewModel.isLoadingMandals) {
      return _buildLoadingList();
    }

    if (locationViewModel.mandalsError != null) {
      return _buildErrorWidget(
        context,
        'Failed to load mandals',
        locationViewModel.mandalsError!,
        () => locationViewModel.retryLoadMandals(),
      );
    }

    if (locationViewModel.mandals.isEmpty) {
      return Center(
        child: Text(
          'No mandals available',
          style: TextStyle(fontSize: appFontSizeSubHeader, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: locationViewModel.mandals.length,
      itemBuilder: (context, index) {
        final mandal = locationViewModel.mandals[index];
        final isSelected = locationViewModel.selectedMandal?.id == mandal.id;
        return _buildMandalItem(
          context,
          mandal,
          locationViewModel,
          isSelected,
          ref,
        );
      },
    );
  }

  Widget _buildMandalItem(
    BuildContext context,
    Mandal mandal,
    LocationViewModel locationViewModel,
    bool isSelected,
    WidgetRef ref,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).appSelectionBackground
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).appSelectionPrimary
              : Theme.of(context).appGrey300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          mandal.name,
          style: TextStyle(
            fontSize: appFontSizeSubHeader,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).appSelectionPrimary
                : Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: Theme.of(context).appSelectionPrimary,
                size: 24,
              )
            : Icon(
                Icons.radio_button_unchecked,
                size: 24,
                color: Colors.grey[400],
              ),
        onTap: () => _onMandalSelected(mandal, ref),
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: ShimmerWidget(
            width: double.infinity,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(
    BuildContext context,
    String title,
    String error,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).appErrorLight),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: appFontSizeHeader,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).appErrorMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                fontSize: appFontSizeBody,
                color: Theme.of(context).appErrorMedium,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).appErrorMedium,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _onMandalSelected(Mandal mandal, WidgetRef ref) {
    // Set selected mandal in view model
    ref.read(locationViewModelProvider).setSelectedMandal(mandal);
  }

  void _handleContinue(
    BuildContext context,
    LocationViewModel locationViewModel,
  ) async {
    // Only allow continuation if location is fully complete
    if (!locationViewModel.isLocationComplete) {
      return;
    }

    try {
      final storage = OnboardingStorage();

      // Save the selected location
      await storage.saveSelectedLocation(
        locationViewModel.selectedState!,
        locationViewModel.selectedDistrict!,
        locationViewModel.selectedMandal!,
      );

      await storage.setLocationCompleted();

      final onboardingManager = OnboardingManager(storage);
      final step = await onboardingManager.getCurrentStep();

      // If onboarding is already complete, user is just changing location — pop back
      if (step == OnboardingStep.completed && context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      OnboardingNavigator.navigate(context, step, replace: false);
    } catch (e) {
      debugPrint('Location onboarding error: $e');
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRouter.languageSelection,
        (_) => false,
      );
    }
  }
}
