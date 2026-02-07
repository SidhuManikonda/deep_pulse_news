import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/district.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/shimmer_widget.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../features/onboarding/location_view_model.dart';
import 'mandal_selection_screen.dart';

class DistrictSelectionScreen extends ConsumerWidget {
  const DistrictSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationViewModel = ref.watch(locationViewModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AutoScaledText(
          'Select District',
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
                      child: Icon(
                        Icons.location_city,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AutoScaledText(
                    'Choose your District',
                    style: TextStyle(
                      fontSize: appFontSizeHeader,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (locationViewModel.selectedState != null) ...[
                    AutoScaledText(
                      'in ${locationViewModel.selectedState!.name}',
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

            // Districts list
            Expanded(
              child: _buildDistrictsList(context, locationViewModel, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList(
    BuildContext context,
    LocationViewModel locationViewModel,
    WidgetRef ref,
  ) {
    if (locationViewModel.isLoadingDistricts) {
      return _buildLoadingList();
    }

    if (locationViewModel.districtsError != null) {
      return _buildErrorWidget(
        context,
        'Failed to load districts',
        locationViewModel.districtsError!,
        () => locationViewModel.retryLoadDistricts(),
      );
    }

    if (locationViewModel.districts.isEmpty) {
      return Center(
        child: AutoScaledText(
          'No districts available',
          style: TextStyle(fontSize: appFontSizeSubHeader, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: locationViewModel.districts.length,
      itemBuilder: (context, index) {
        final district = locationViewModel.districts[index];
        return _buildDistrictItem(context, district, ref);
      },
    );
  }

  Widget _buildDistrictItem(
    BuildContext context,
    District district,
    WidgetRef ref,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).appGrey300, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        title: AutoScaledText(
          district.name,
          style: TextStyle(
            fontSize: appFontSizeSubHeader,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[600],
        ),
        onTap: () => _onDistrictSelected(context, district, ref),
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).appErrorLight,
            ),
            const SizedBox(height: 16),
            AutoScaledText(
              title,
              style: TextStyle(
                fontSize: appFontSizeHeader,
                fontWeight: FontWeight.w600,
                color: appErrorColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AutoScaledText(
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
              child: const AutoScaledText('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _onDistrictSelected(
    BuildContext context,
    District district,
    WidgetRef ref,
  ) {
    // Set selected district in view model
    ref.read(locationViewModelProvider).setSelectedDistrict(district);

    // Navigate to mandal selection screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MandalSelectionScreen()),
    );
  }
}
