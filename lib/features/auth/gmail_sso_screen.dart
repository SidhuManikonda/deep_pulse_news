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
        '703254694314-oiulcsg77m85arnib2s5hlpr0978qcvh.apps.googleusercontent.com',
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
      String friendlyMessage;
      if (e.message?.contains('ApiException: 10') == true ||
          e.code == 'sign_in_failed') {
        friendlyMessage =
            'Google Sign-In setup error. Ensure both Android and Web OAuth '
            'client IDs are created in Google Cloud Console with the correct '
            'SHA-1 fingerprint and package name.';
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
            AppRouter.languageSelection,
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

                    if (_selectedState != null) ...[
                      _buildLocationCard(theme),
                      const SizedBox(height: AppSpacing.lg),
                    ],

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
              '${_selectedState?.name}, ${_selectedDistrict?.name}, ${_selectedMandal?.name}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.appTextPrimary,
                fontSize: scaledFontSize(13),
              ),
            ),
          ),
        ],
      ),
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
