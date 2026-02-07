import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/state.dart' as location_models;
import '../../providers/app_providers.dart';
import '../../shared/widgets/shimmer_widget.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../features/onboarding/location_view_model.dart';
import 'district_selection_screen.dart';

class StateSelectionScreen extends ConsumerStatefulWidget {
  const StateSelectionScreen({super.key});

  @override
  ConsumerState<StateSelectionScreen> createState() =>
      _StateSelectionScreenState();
}

class _StateSelectionScreenState extends ConsumerState<StateSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationViewModelProvider).loadStates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationViewModel = ref.watch(locationViewModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AutoScaledText(
          'Select State',
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
                        Icons.location_on,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AutoScaledText(
                    'Choose your State',
                    style: TextStyle(
                      fontSize: appFontSizeHeader,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  AutoScaledText(
                    'Select your state to get localized news content',
                    style: TextStyle(
                      fontSize: appFontSizeBody,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // States list
            Expanded(child: _buildStatesList(locationViewModel)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatesList(LocationViewModel locationViewModel) {
    if (locationViewModel.isLoadingStates) {
      return _buildLoadingList();
    }

    if (locationViewModel.statesError != null) {
      return _buildErrorWidget(
        'Failed to load states',
        locationViewModel.statesError!,
        () => locationViewModel.retryLoadStates(),
      );
    }

    if (locationViewModel.states.isEmpty) {
      return Center(
        child: AutoScaledText(
          'No states available',
          style: TextStyle(fontSize: appFontSizeSubHeader, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: locationViewModel.states.length,
      itemBuilder: (context, index) {
        final state = locationViewModel.states[index];
        return _buildStateItem(state);
      },
    );
  }

  Widget _buildStateItem(location_models.State state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).appGrey300, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        title: AutoScaledText(
          state.name,
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
        onTap: () => _onStateSelected(state),
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
            height: 40,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String title, String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).appErrorLight),
            const SizedBox(height: 16),
            AutoScaledText(
              title,
              style: TextStyle(
                fontSize: appFontSizeHeader,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
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

  void _onStateSelected(location_models.State state) {
    // Set selected state in view model
    ref.read(locationViewModelProvider).setSelectedState(state);

    // Navigate to district selection screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DistrictSelectionScreen()),
    );
  }
}
