import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_spacing.dart';
import '../../shared/widgets/custom_button.dart';
import 'state_selection_screen.dart';

class LocationSelectionScreen extends ConsumerWidget {
  const LocationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Icon
              Center(
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: theme.appPrimary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 50,
                    color: theme.appPrimary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              Text(
                'Where are you from?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaledFontSize(26),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Get news that matters to your community.\nJust 3 quick steps.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: scaledFontSize(15),
                  color: const Color(0xFF8E8E93),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Step preview
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepBadge(theme, Icons.map_outlined, 'State'),
                  _connector(),
                  _stepBadge(theme, Icons.location_city_outlined, 'District'),
                  _connector(),
                  _stepBadge(theme, Icons.place_outlined, 'Area'),
                ],
              ),

              const Spacer(flex: 3),

              CustomButton(
                text: 'Get Started',
                width: double.infinity,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StateSelectionScreen()),
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBadge(ThemeData theme, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52, height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 24, color: const Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8E8E93),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _connector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        width: 30, height: 2,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
