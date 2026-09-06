import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../shared/widgets/shimmer_widget.dart';

/// Step indicator row shown at the top of each location selection screen.
class LocationStepIndicator extends StatelessWidget {
  final int currentStep; // 1, 2, or 3
  const LocationStepIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(theme, 1),
        _line(theme, 1),
        _dot(theme, 2),
        _line(theme, 2),
        _dot(theme, 3),
      ],
    );
  }

  Widget _dot(ThemeData theme, int step) {
    final done = step < currentStep;
    final active = step == currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 28 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: (done || active) ? theme.appPrimary : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _line(ThemeData theme, int afterStep) {
    final filled = afterStep < currentStep;
    return Container(
      width: 32, height: 2,
      color: filled ? theme.appPrimary : const Color(0xFFE5E5EA),
    );
  }
}

/// Search bar used across all location list screens.
class LocationSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const LocationSearchBar({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: theme.appGrey100,
        borderRadius: AppRadius.smAll,
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(fontSize: scaledFontSize(14), color: theme.appTextPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: scaledFontSize(14), color: theme.appGrey400),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: theme.appGrey400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          isDense: true,
        ),
      ),
    );
  }
}

/// A single row in the location list (state/district/mandal).
class LocationListItem extends StatelessWidget {
  final String name;
  final bool isSelected;
  final bool showChevron; // false for mandal (shows check instead)
  final VoidCallback onTap;
  const LocationListItem({
    super.key,
    required this.name,
    this.isSelected = false,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 1,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.appPrimary.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: isSelected ? theme.appPrimary : theme.appDivider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: scaledFontSize(15),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.appPrimary
                          : theme.appTextPrimary,
                    ),
                  ),
                ),
                if (showChevron)
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: theme.appGrey400)
                else
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: isSelected ? theme.appPrimary : theme.appGrey300,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Engaging skeleton loader that matches the shape of real list items.
Widget buildLoadingList() {
  return ListView.builder(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
    itemCount: 10,
    itemBuilder: (_, i) => _LocationItemSkeleton(index: i),
  );
}

class _LocationItemSkeleton extends StatelessWidget {
  final int index;
  const _LocationItemSkeleton({required this.index});

  // Vary name-bar widths so it looks like real content
  static const _widths = [0.65, 0.80, 0.55, 0.72, 0.60, 0.78, 0.50, 0.68, 0.75, 0.58];

  @override
  Widget build(BuildContext context) {
    final w = _widths[index % _widths.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 1,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: const Color(0xFFF2F2F7)),
        ),
        child: Row(
          children: [
            ShimmerWidget(
              width: MediaQuery.of(context).size.width * w - 60,
              height: 14,
              borderRadius: BorderRadius.circular(7),
            ),
            const Spacer(),
            ShimmerWidget(
              width: 16, height: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry button.
Widget buildErrorWidget(
  BuildContext context,
  String message,
  VoidCallback onRetry,
) {
  final theme = Theme.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 56, color: theme.appGrey400),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Could not load data',
            style: TextStyle(
              fontSize: scaledFontSize(16),
              fontWeight: FontWeight.w600,
              color: theme.appTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: scaledFontSize(13),
              color: theme.appTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.appPrimary,
              side: BorderSide(color: theme.appPrimary),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
