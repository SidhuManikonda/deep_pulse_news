import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_spacing.dart';
import '../../shared/widgets/custom_button.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/onboarding_storage.dart';
import '../../core/services/push_notification_service.dart';
import '../../features/onboarding/location_view_model.dart';
import '../../providers/app_providers.dart';
import 'onboarding_widgets.dart';

class MandalSelectionScreen extends ConsumerStatefulWidget {
  const MandalSelectionScreen({super.key});

  @override
  ConsumerState<MandalSelectionScreen> createState() =>
      _MandalSelectionScreenState();
}

class _MandalSelectionScreenState extends ConsumerState<MandalSelectionScreen> {
  String _query = '';
  bool _isContinuing = false;

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(locationViewModelProvider);
    final theme = Theme.of(context);

    final filtered = _query.isEmpty
        ? vm.mandals
        : vm.mandals
            .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
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
                    'Step 3 of 3',
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
                  LocationStepIndicator(currentStep: 3),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Choose your Area',
                    style: TextStyle(
                      fontSize: scaledFontSize(22),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  // Breadcrumb: State > District
                  if (vm.selectedState != null &&
                      vm.selectedDistrict != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 14, color: theme.appPrimary),
                        const SizedBox(width: 4),
                        Text(
                          '${vm.selectedState!.name}  ›  ${vm.selectedDistrict!.name}',
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
                    hint: 'Search areas...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: vm.isLoadingMandals
                  ? buildLoadingList()
                  : vm.mandalsError != null
                  ? buildErrorWidget(
                      context, vm.mandalsError!, vm.retryLoadMandals)
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No areas found',
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
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final selected = vm.selectedMandal?.id == m.id;
                        return LocationListItem(
                          name: m.name,
                          isSelected: selected,
                          showChevron: false,
                          onTap: () => ref
                              .read(locationViewModelProvider)
                              .setSelectedMandal(m),
                        );
                      },
                    ),
            ),

            // ── Continue button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl,
              ),
              child: CustomButton(
                text: vm.selectedMandal != null
                    ? 'Continue with ${vm.selectedMandal!.name}'
                    : 'Select an area to continue',
                width: double.infinity,
                isLoading: _isContinuing,
                onPressed: vm.selectedMandal != null && !_isContinuing
                    ? () => _handleContinue(vm)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinue(LocationViewModel vm) async {
    if (!vm.isLocationComplete) return;
    setState(() => _isContinuing = true);
    try {
      final storage = OnboardingStorage();

      // Whether onboarding was already done tells us how we got here: a first
      // run (this screen sits on top of the onboarding stack) or a later
      // location change (it sits on top of the app). The two need different
      // exits — see below.
      final wasOnboarded = await storage.isOnboardingCompleted();

      await storage.saveSelectedLocation(
        vm.selectedState!,
        vm.selectedDistrict!,
        vm.selectedMandal!,
      );
      await storage.setLocationCompleted();
      // Location is the only onboarding step left, so finishing it finishes
      // onboarding outright.
      await storage.setOnboardingCompleted();

      // Push targeting is keyed on the device's registered location, so the
      // backend has to hear about this change or the device keeps receiving
      // pushes for wherever it was first registered.
      unawaited(PushNotificationService.instance.onLocationChanged());

      if (!mounted) return;

      if (wasOnboarded) {
        // Changing location from inside the app: the onboarding screens were
        // pushed on top of the running app, so unwinding them lands back on it.
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }

      // First run: the onboarding stack was pushed with removeUntil, so its own
      // intro screen ("Where are you from?") is the first route — popping to it
      // would just restart the flow. Go to home and drop onboarding entirely.
      Navigator.pushNamedAndRemoveUntil(context, AppRouter.home, (_) => false);
    } catch (_) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, AppRouter.locationSelection, (_) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _isContinuing = false);
    }
  }
}
