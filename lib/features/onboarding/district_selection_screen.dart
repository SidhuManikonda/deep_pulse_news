import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_spacing.dart';
import '../../data/models/district.dart';
import '../../features/onboarding/location_view_model.dart';
import '../../providers/app_providers.dart';
import 'mandal_selection_screen.dart';
import 'onboarding_widgets.dart';

class DistrictSelectionScreen extends ConsumerStatefulWidget {
  const DistrictSelectionScreen({super.key});

  @override
  ConsumerState<DistrictSelectionScreen> createState() =>
      _DistrictSelectionScreenState();
}

class _DistrictSelectionScreenState
    extends ConsumerState<DistrictSelectionScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(locationViewModelProvider);
    final theme = Theme.of(context);

    final filtered = _query.isEmpty
        ? vm.districts
        : vm.districts
            .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, 0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: const Color(0xFF1C1C1E),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    'Step 2 of 3',
                    style: TextStyle(
                      fontSize: scaledFontSize(13),
                      color: theme.appTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocationStepIndicator(currentStep: 2),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Choose your District',
                    style: TextStyle(
                      fontSize: scaledFontSize(22),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (vm.selectedState != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: theme.appPrimary),
                        const SizedBox(width: 4),
                        Text(
                          vm.selectedState!.name,
                          style: TextStyle(
                            fontSize: scaledFontSize(13),
                            color: theme.appPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  LocationSearchBar(
                    hint: 'Search districts...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: vm.isLoadingDistricts
                  ? buildLoadingList()
                  : vm.districtsError != null
                  ? buildErrorWidget(
                      context, vm.districtsError!, vm.retryLoadDistricts)
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No districts found',
                        style: TextStyle(
                          fontSize: scaledFontSize(14),
                          color: theme.appTextSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => LocationListItem(
                        name: filtered[i].name,
                        onTap: () => _onTap(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(District district) {
    ref.read(locationViewModelProvider).setSelectedDistrict(district);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MandalSelectionScreen()),
    );
  }
}
