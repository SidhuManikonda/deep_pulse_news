import 'package:flutter/material.dart';

import 'app_logo.dart';

/// The full "DEEP PULSE" wordmark — the app mark and lettering together, as one
/// supplied image.
///
/// Use this wherever the brand is shown at more than icon size (the header, the
/// splash, an article's publisher line, the e-paper masthead). [AppLogo] stays
/// the right choice for the square mark on its own.
///
/// Kept as one widget so the asset path, the rounded crop and the fallback are
/// defined once: the same wordmark appears on several screens and they must not
/// drift apart when the artwork is next replaced.
class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    this.height = 42,
    this.width,
    this.fit = BoxFit.contain,
    this.borderRadius = 10,
  });

  /// Height of the wordmark. Width follows the artwork's ~3:1 ratio unless
  /// [width] is given.
  final double height;

  /// Forces a width. Combined with `fit: BoxFit.fill` this stretches the
  /// artwork, so only set it where that is intended.
  final double? width;

  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/images/dp_banner.jpeg',
        height: height,
        width: width,
        fit: fit,
        // Falls back to the icon-plus-text lockup the app used before the
        // artwork existed, so a missing asset never leaves a screen brandless.
        errorBuilder: (_, __, ___) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: height, borderRadius: borderRadius),
            SizedBox(width: height * 0.2),
            Text(
              'Deep Pulse',
              style: TextStyle(
                fontSize: height * 0.45,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.headlineLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
