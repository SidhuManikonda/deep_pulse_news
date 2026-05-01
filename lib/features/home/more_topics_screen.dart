import 'package:deep_pulse_news/features/home/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/constants/app_spacing.dart';

class MoreTopicsWidget extends ConsumerWidget {
  const MoreTopicsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeViewModel = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);

    if (homeViewModel.isLoadingTopics) {
      return Center(child: CircularProgressIndicator(color: theme.appPrimary));
    }

    final topics = homeViewModel.topics;

    if (topics.isEmpty) {
      return Center(
        child: Text(
          'No topics available',
          style: TextStyle(
            fontSize: scaledFontSize(15),
            color: theme.appTextSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      itemCount: topics.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final topic = topics[index];
        final iconData = _iconFor(topic.name);
        final iconColor = _paletteColor(index);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => ref.read(homeViewModelProvider).selectTopic(topic),
            child: Ink(
              decoration: BoxDecoration(
                color: theme.appCard,
                borderRadius: AppRadius.mdAll,
                boxShadow: theme.shadowSm,
                border: Border.all(color: theme.appDivider),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        topic.name,
                        style: TextStyle(
                          fontSize: scaledFontSize(15),
                          fontWeight: FontWeight.w600,
                          color: theme.appTextPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.appGrey400,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(String name) {
    switch (name.toLowerCase().trim()) {
      case 'all info':    return Icons.public_rounded;
      case 'your area':   return Icons.location_on_rounded;
      case 'special':     return Icons.star_rounded;
      case 'electronics': return Icons.devices_rounded;
      case 'sports':      return Icons.sports_cricket_rounded;
      case 'cinema':      return Icons.movie_rounded;
      case 'jobs':        return Icons.work_rounded;
      case 'education':   return Icons.school_rounded;
      case 'politics':    return Icons.account_balance_rounded;
      case 'business':    return Icons.trending_up_rounded;
      case 'health':      return Icons.favorite_rounded;
      case 'technology':  return Icons.memory_rounded;
      default:            return Icons.category_rounded;
    }
  }

  // Distinct, accessible icon colours — not too saturated, works on both themes
  Color _paletteColor(int index) {
    const palette = [
      Color(0xFF1E88E5), // blue
      Color(0xFF43A047), // green
      Color(0xFFE53935), // red
      Color(0xFF8E24AA), // purple
      Color(0xFF00897B), // teal
      Color(0xFFFB8C00), // orange
      Color(0xFF3949AB), // indigo
      Color(0xFF00ACC1), // cyan
    ];
    return palette[index % palette.length];
  }
}
