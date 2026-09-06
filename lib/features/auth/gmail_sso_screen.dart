import 'package:deep_pulse_news/shared/widgets/app_logo.dart';
import 'package:deep_pulse_news/shared/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/onboarding_storage.dart';
import '../../core/utils/onboarding_manager.dart';
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/repositories/district_repository.dart';
import '../../data/repositories/mandal_repository.dart';
import '../../data/repositories/state_repository.dart';
import '../../navigators/onboarding_navigator.dart';
import '../../providers/app_providers.dart';

class GmailSsoScreen extends ConsumerStatefulWidget {
  const GmailSsoScreen({super.key});

  @override
  ConsumerState<GmailSsoScreen> createState() => _GmailSsoScreenState();
}

class _GmailSsoScreenState extends ConsumerState<GmailSsoScreen> {
  final _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  GoogleSignInAccount? _googleUser;
  String? _idToken;
  bool _isSigningIn = false;
  bool _isSubmitting = false;
  String? _error;

  // Locally cached mobile — loaded from storage before the user signs in
  String? _savedMobile;
  // When true, show the text field so the user can change the saved number
  bool _editingMobile = false;

  // Location
  location_models.State? _selectedState;
  District? _selectedDistrict;
  Mandal? _selectedMandal;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '668367572887-s59rn9mbsn9i8vljtguja8uhj9fj34rr.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final storage = OnboardingStorage();
    final results = await Future.wait([
      storage.getSelectedState(),
      storage.getSelectedDistrict(),
      storage.getSelectedMandal(),
      storage.getSavedMobile(),
    ]);
    if (!mounted) return;
    setState(() {
      _selectedState    = results[0] as location_models.State?;
      _selectedDistrict = results[1] as District?;
      _selectedMandal   = results[2] as Mandal?;
      _savedMobile      = results[3] as String?;
      // Pre-fill the controller in case the user taps "Change"
      if (_savedMobile != null) {
        _mobileController.text = _savedMobile!;
      }
    });
  }

  // ── Google Sign-In ────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() => _isSigningIn = false);
        return;
      }

      final auth = await account.authentication;

      if (auth.idToken == null) {
        setState(() {
          _error =
              'Failed to get ID token from Google. '
              'Make sure the Android OAuth client is set up in Google Cloud Console.';
          _isSigningIn = false;
        });
        return;
      }

      setState(() {
        _googleUser = account;
        _idToken = auth.idToken;
        _isSigningIn = false;
      });
    } on PlatformException catch (e) {
      // Log the FULL exception so we can debug. Don't rely on the friendly
      // message — it hides the underlying cause.
      debugPrint('========== GOOGLE SIGN-IN FAILED ==========');
      debugPrint('PlatformException.code:    ${e.code}');
      debugPrint('PlatformException.message: ${e.message}');
      debugPrint('PlatformException.details: ${e.details}');
      debugPrint('===========================================');

      String friendlyMessage;
      if (e.message?.contains('ApiException: 10') == true ||
          e.code == 'sign_in_failed') {
        friendlyMessage =
            'Google Sign-In setup error. Ensure both Android and Web OAuth '
            'client IDs are created in Google Cloud Console with the correct '
            'SHA-1 fingerprint and package name.\n\n'
            'Debug: ${e.code} / ${e.message}';
      } else if (e.message?.contains('ApiException: 12501') == true) {
        friendlyMessage = 'Sign-in cancelled';
      } else if (e.message?.contains('ApiException: 7') == true) {
        friendlyMessage = 'Network error. Check your internet connection.';
      } else {
        friendlyMessage = 'Sign-in failed: ${e.message ?? e.code}';
      }
      setState(() {
        _error = friendlyMessage;
        _isSigningIn = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Google sign-in failed: $e';
        _isSigningIn = false;
      });
    }
  }

  // ── Submit ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_googleUser == null || _idToken == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedState == null ||
        _selectedDistrict == null ||
        _selectedMandal == null) {
      setState(() => _error = 'Please select your State, District, and Mandal');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    // Resolve which mobile to send:
    //  - If user was editing, use the text field value
    //  - If not editing, use the previously saved number (may be null)
    final mobileToSend = _editingMobile
        ? _mobileController.text.trim()
        : (_savedMobile ?? _mobileController.text.trim());

    try {
      final authViewModel = ref.read(authViewModelProvider);

      final success = await authViewModel.googleLogin(
        idToken: _idToken!,
        stateId: _selectedState!.id,
        districtId: _selectedDistrict!.id,
        mandalId: _selectedMandal!.id,
        mobile: mobileToSend,
        profilePhoto: _googleUser!.photoUrl,
      );

      if (!success || !mounted) {
        setState(() {
          _error = authViewModel.error ?? 'Google login failed';
          _isSubmitting = false;
        });
        return;
      }

      // Persist the mobile locally so we skip the field next time
      if (mobileToSend.isNotEmpty) {
        await OnboardingStorage().saveMobile(mobileToSend);
      }

      // Navigate to onboarding or home
      final onboardingStorage = OnboardingStorage();
      try {
        final onboardingManager = OnboardingManager(onboardingStorage);
        final step = await onboardingManager.getCurrentStep();
        if (mounted) OnboardingNavigator.navigate(context, step, replace: false);
      } catch (_) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.locationSelection,
            (_) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit: $e';
        _isSubmitting = false;
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xxxl),

                  // Logo + title
                  Column(
                    children: [
                      AppLogo(size: 100, borderRadius: AppSpacing.sm),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Welcome to Deep Pulse',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: scaledFontSize(20),
                          fontWeight: FontWeight.bold,
                          color: theme.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Stay updated with latest news',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: scaledFontSize(13),
                          color: theme.appTextSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  if (_googleUser == null)
                    CustomIconButton(
                      onTap: _signInWithGoogle,
                      text: 'Continue with Google',
                      icon: Icons.login,
                      buttonColor: theme.appPrimary,
                      isLoading: _isSigningIn,
                    )
                  else ...[
                    _buildUserCard(theme),
                    const SizedBox(height: AppSpacing.lg),

                    // Always show the location card after sign-in. If a
                    // location is set (same-device relogin / completed
                    // onboarding) it's pre-filled and the user can tap
                    // "Change" to override. If nothing is set yet, the
                    // card shows a "Set location" prompt so the user is
                    // never stranded without a way to pick.
                    _buildLocationCard(theme),
                    const SizedBox(height: AppSpacing.lg),

                    // Mobile field — only shown when no saved number, or user taps Change
                    _buildMobileSection(theme),

                    const SizedBox(height: AppSpacing.xxxl),
                    CustomIconButton(
                      text: 'Continue',
                      onTap: _submit,
                      buttonColor: theme.appPrimary,
                      isLoading: _isSubmitting,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: theme.appErrorMedium,
                        fontSize: scaledFontSize(13),
                      ),
                      textAlign: TextAlign.center,
                    ),

                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Subwidgets ───────────────────────────────────────────────────

  Widget _buildUserCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.appGrey100,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: _googleUser!.photoUrl != null
                ? NetworkImage(_googleUser!.photoUrl!)
                : null,
            child: _googleUser!.photoUrl == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _googleUser!.displayName ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.appTextPrimary,
                  ),
                ),
                Text(
                  _googleUser!.email,
                  style: TextStyle(
                    fontSize: scaledFontSize(12),
                    color: theme.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _signInWithGoogle,
            icon: Icon(Icons.swap_horiz, color: theme.appGrey600),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(ThemeData theme) {
    final hasLocation = _selectedState != null;
    final locationText = hasLocation
        ? [
            _selectedState?.name,
            _selectedDistrict?.name,
            _selectedMandal?.name,
          ].where((n) => n != null && n.isNotEmpty).join(', ')
        : 'No location set';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.appSelectionBackground,
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: theme.appSelectionPrimary),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              locationText,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: hasLocation
                    ? theme.appTextPrimary
                    : theme.appTextSecondary,
                fontSize: scaledFontSize(13),
                fontStyle: hasLocation ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // "Change" / "Set" link — the location is pre-filled from the
          // previous session for fast same-user relogin. A different user
          // signing in on the same device taps here to pick their own
          // state / district / mandal without killing the app.
          GestureDetector(
            onTap: _openLocationPicker,
            child: Text(
              hasLocation ? 'Change' : 'Set',
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: theme.appSelectionPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Inline location picker ───────────────────────────────────────
  /// Runs three sequential bottom-sheet pickers (state → district → mandal),
  /// each loading its list from the appropriate repository. Cancelling at
  /// any step leaves the existing selection untouched; completing all three
  /// persists the new selection to OnboardingStorage so it survives reloads.
  Future<void> _openLocationPicker() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // State
      final states = await StateRepositoryImpl().getStates();
      if (!mounted) return;
      final state = await _showPickerSheet<location_models.State>(
        title: 'Select State',
        items: states,
        itemLabel: (s) => s.name,
        selectedId: _selectedState?.id,
        idOf: (s) => s.id,
      );
      if (state == null || !mounted) return;

      // District (filtered by state)
      final districts = await DistrictRepositoryImpl().getDistrictsByState(state.id);
      if (!mounted) return;
      if (districts.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No districts available for this state')),
        );
        return;
      }
      final district = await _showPickerSheet<District>(
        title: 'Select District',
        items: districts,
        itemLabel: (d) => d.name,
        // Only pre-select the prior district if the state didn't change
        selectedId: state.id == _selectedState?.id ? _selectedDistrict?.id : null,
        idOf: (d) => d.id,
      );
      if (district == null || !mounted) return;

      // Mandal (filtered by district)
      final mandals = await MandalRepositoryImpl().getMandalsByDistrict(district.id);
      if (!mounted) return;
      if (mandals.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No mandals available for this district')),
        );
        return;
      }
      final mandal = await _showPickerSheet<Mandal>(
        title: 'Select Mandal',
        items: mandals,
        itemLabel: (m) => m.name,
        selectedId: district.id == _selectedDistrict?.id ? _selectedMandal?.id : null,
        idOf: (m) => m.id,
      );
      if (mandal == null || !mounted) return;

      // Persist + update form state
      await OnboardingStorage().saveSelectedLocation(state, district, mandal);
      if (!mounted) return;
      setState(() {
        _selectedState = state;
        _selectedDistrict = district;
        _selectedMandal = mandal;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to load location options: $e')),
      );
    }
  }

  /// Generic bottom-sheet list picker. Returns the chosen item or `null` if
  /// the user dismissed the sheet. Highlights the current selection.
  Future<T?> _showPickerSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) itemLabel,
    required int Function(T) idOf,
    int? selectedId,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: scaledFontSize(16),
                          fontWeight: FontWeight.w700,
                          color: theme.appTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final isSelected = selectedId != null && idOf(item) == selectedId;
                    return ListTile(
                      title: Text(itemLabel(item)),
                      trailing: isSelected
                          ? Icon(Icons.check, color: theme.appSelectionPrimary)
                          : null,
                      onTap: () => Navigator.pop(ctx, item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileSection(ThemeData theme) {
    // User has a saved number and is NOT editing → show compact saved-number pill
    if (_savedMobile != null && !_editingMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: theme.appGrey100,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.appDivider),
        ),
        child: Row(
          children: [
            Icon(Icons.phone_rounded, size: 18, color: theme.appGrey600),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _savedMobile!,
                style: TextStyle(
                  fontSize: scaledFontSize(14),
                  fontWeight: FontWeight.w500,
                  color: theme.appTextPrimary,
                ),
              ),
            ),
            // Change button
            GestureDetector(
              onTap: () => setState(() => _editingMobile = true),
              child: Text(
                'Change',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: theme.appSelectionPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No saved number, or user tapped Change → show the input field
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      autofocus: _editingMobile,
      decoration: InputDecoration(
        hintText: 'Mobile number (optional)',
        prefixIcon: const Icon(Icons.phone),
        filled: true,
        fillColor: theme.appGrey100,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        // If the user was editing (had a saved number), show a Cancel option
        suffixIcon: _editingMobile
            ? GestureDetector(
                onTap: () => setState(() {
                  _editingMobile = false;
                  _mobileController.text = _savedMobile!;
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: theme.appTextSecondary,
                      fontSize: scaledFontSize(13),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
