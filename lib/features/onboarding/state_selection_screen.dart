import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_radius.dart';
import '../../data/models/state.dart' as location_models;
import '../../features/onboarding/location_view_model.dart';
import '../../providers/app_providers.dart';
import 'district_selection_screen.dart';
import 'onboarding_widgets.dart';

class StateSelectionScreen extends ConsumerStatefulWidget {
  const StateSelectionScreen({super.key});

  @override
  ConsumerState<StateSelectionScreen> createState() => _StateSelectionScreenState();
}

class _StateSelectionScreenState extends ConsumerState<StateSelectionScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationViewModelProvider).loadStates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(locationViewModelProvider);
    final theme = Theme.of(context);

    final filtered = _query.isEmpty
        ? vm.states
        : vm.states
            .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
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
                    'Step 1 of 3',
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
                  LocationStepIndicator(currentStep: 1),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Choose your State',
                    style: TextStyle(
                      fontSize: scaledFontSize(22),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'We\'ll use this to show you local news',
                    style: TextStyle(
                      fontSize: scaledFontSize(14),
                      color: theme.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LocationSearchBar(
                    hint: 'Search states...',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: vm.isLoadingStates
                  ? buildLoadingList()
                  : vm.statesError != null
                  ? buildErrorWidget(context, vm.statesError!, vm.retryLoadStates)
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No states found',
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

  void _onTap(location_models.State state) {
    ref.read(locationViewModelProvider).setSelectedState(state);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DistrictSelectionScreen()),
    );
  }
}
