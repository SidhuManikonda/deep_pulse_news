import 'package:deep_pulse_news/core/routing/app_router.dart';
import 'package:deep_pulse_news/core/services/onboarding_storage.dart';
import 'package:deep_pulse_news/navigators/onboarding_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/onboarding_manager.dart';
import '../../shared/widgets/alert_popup.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize AlertPopupManager with overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final overlay = Overlay.of(context);
          AlertPopupManager().initialize(overlay);
        } catch (e) {
          debugPrint(
            'SplashScreen: Failed to initialize AlertPopupManager: $e',
          );
        }
      }
    });

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      // Skip authentication - go directly to onboarding flow
      final onboardingManager = OnboardingManager(OnboardingStorage());
      final step = await onboardingManager.getCurrentStep();
      OnboardingNavigator.navigate(context, step);
    
    } catch (e) {
      print('Error during onboarding check: $e');
      // Fallback to location selection if anything fails
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.locationSelection);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).appPrimary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).appPrimary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.newspaper,
                        size: 60,
                        color: Theme.of(context).appTextWhite,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Deep Pulse News',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.headlineLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay Updated with Latest News',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
