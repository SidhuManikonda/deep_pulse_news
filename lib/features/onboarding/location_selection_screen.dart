import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../core/constants/app_font_sizes.dart';
import 'state_selection_screen.dart';

class LocationSelectionScreen extends ConsumerStatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  ConsumerState<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState
    extends ConsumerState<LocationSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Location icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.location_on, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 40),

              // Title and description
              AutoScaledText(
                'Select Location',
                style: TextStyle(
                  fontSize: appFontSizeTitle,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.headlineLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AutoScaledText(
                'Choose your State, District, and Mandal to get localized news content',
                style: TextStyle(
                  fontSize: appFontSizeSubHeader,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),

              // Get Started Button
              CustomButton(
                text: 'Get Started',
                onPressed: () => _navigateToStateSelection(),
                backgroundColor: const Color(0xFF2196F3),
                textColor: Colors.white,
                width: double.infinity,
                height: 56,
                borderRadius: 12,
              ),
              const SizedBox(height: 16),

              // Info text
              AutoScaledText(
                'You will select your location in 3 simple steps',
                style: TextStyle(fontSize: appFontSizeBody, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToStateSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const StateSelectionScreen()),
    );
  }
}
