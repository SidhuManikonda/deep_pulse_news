import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import 'app_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ShimmerBox — branded animated shimmer rectangle
// Colors: light blue-tinted sweep instead of plain grey
// ─────────────────────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool dark;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = AppRadius.xsAll,
    this.dark = false,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: widget.dark
                ? const [
                    Color(0xFF1e293b),
                    Color(0xFF2d3f60),
                    Color(0xFF1e293b),
                  ]
                : const [
                    Color(0xFFECF0FA), // faint blue-tinted base
                    Color(0xFFD4E0F8), // highlight — blue tint peak
                    Color(0xFFECF0FA),
                  ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NewsCardSkeleton — matches the exact shape of home-feed cards
// Shows 3 of these instead of a spinner while news loads
// ─────────────────────────────────────────────────────────────────────────────
class NewsCardSkeleton extends StatelessWidget {
  const NewsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.appCard,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Media area
          ShimmerBox(
            width: double.infinity,
            height: h * 0.28,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.md),
              topRight: Radius.circular(AppRadius.md),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                ShimmerBox(width: w * 0.62, height: 18, borderRadius: AppRadius.xsAll),
                const SizedBox(height: AppSpacing.sm),
                // Description line 1
                ShimmerBox(width: double.infinity, height: 13, borderRadius: AppRadius.xsAll),
                const SizedBox(height: 5),
                // Description line 2
                ShimmerBox(width: w * 0.52, height: 13, borderRadius: AppRadius.xsAll),
                const SizedBox(height: AppSpacing.md),
                // Action bar
                Row(
                  children: [
                    ShimmerBox(width: 52, height: 12, borderRadius: AppRadius.xsAll),
                    const SizedBox(width: AppSpacing.lg),
                    ShimmerBox(width: 46, height: 12, borderRadius: AppRadius.xsAll),
                    const SizedBox(width: AppSpacing.lg),
                    ShimmerBox(width: 46, height: 12, borderRadius: AppRadius.xsAll),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoLoadingPlaceholder — dark gradient + pulsing ring + play icon
// Replaces the grey box shown while a video initialises
// ─────────────────────────────────────────────────────────────────────────────
class VideoLoadingPlaceholder extends StatefulWidget {
  const VideoLoadingPlaceholder({super.key});

  @override
  State<VideoLoadingPlaceholder> createState() =>
      _VideoLoadingPlaceholderState();
}

class _VideoLoadingPlaceholderState extends State<VideoLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(gradient: theme.heroGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulse,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54, height: 54,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 26,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loading video',
              style: TextStyle(
                fontSize: scaledFontSize(11),
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// InlineLoader — small branded spinner with optional label
// Replaces plain CircularProgressIndicator throughout the app
// ─────────────────────────────────────────────────────────────────────────────
class InlineLoader extends StatelessWidget {
  final String? message;
  const InlineLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34, height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(theme.appPrimary),
              backgroundColor: theme.appPrimary.withValues(alpha: 0.10),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: TextStyle(
                fontSize: scaledFontSize(13),
                color: theme.appTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppPageLoader — full-screen branded loader
// Use for initial page loads, splash transitions, heavy async operations
// ─────────────────────────────────────────────────────────────────────────────
class AppPageLoader extends StatefulWidget {
  final String? message;
  const AppPageLoader({super.key, this.message});

  @override
  State<AppPageLoader> createState() => _AppPageLoaderState();
}

class _AppPageLoaderState extends State<AppPageLoader>
    with TickerProviderStateMixin {
  late AnimationController _barCtrl;
  late AnimationController _dotCtrl;
  late Animation<double> _bar;
  late Animation<int> _dots;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _bar = Tween<double>(begin: -1.5, end: 2.5).animate(_barCtrl);

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
    _dots = IntTween(begin: 0, end: 3).animate(_dotCtrl);
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(gradient: theme.heroGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App logo in frosted circle
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: ClipOval(child: AppLogo(size: 80, borderRadius: 0)),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Sweeping progress bar
            ClipRRect(
              borderRadius: AppRadius.xsAll,
              child: SizedBox(
                width: 140, height: 3,
                child: AnimatedBuilder(
                  animation: _bar,
                  builder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(_bar.value - 1, 0),
                        end: Alignment(_bar.value + 1, 0),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Animated dots
            AnimatedBuilder(
              animation: _dots,
              builder: (_, __) => Text(
                '${widget.message ?? 'Loading'}${'.' * (_dots.value + 1)}',
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
