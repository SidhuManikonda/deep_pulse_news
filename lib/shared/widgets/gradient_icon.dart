import 'package:flutter/material.dart';

/// The two-stop gradient every coloured control in the app is painted with,
/// derived from one base colour.
///
/// Taking a single colour and deriving the pair keeps the family consistent:
/// every icon leans the same way and by the same amount, so they read as one
/// set rather than six unrelated gradients. It also means a colour can be
/// changed in one place without anyone having to pick a matching second stop.
///
/// Top-left light, bottom-right dark — the same direction as the raised `+`
/// button on the bottom bar, so a flat icon and a filled disc look lit from the
/// same place.
LinearGradient brandGradient(Color base) {
  final hsl = HSLColor.fromColor(base);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor(),
    ],
  );
}

/// Paints [child] with [brandGradient] of [color].
///
/// A `ShaderMask` costs a `saveLayer`, and that cost scales with the area it
/// covers — which is why this is used on icons and short labels and never on
/// anything full-width. At icon size it is a few hundred pixels; the card-sized
/// blur this app removed for the same reason was a thousand times that.
///
/// [BlendMode.srcIn] keeps the child's shape and takes its colour entirely from
/// the shader, so the child is drawn opaque white and the gradient supplies
/// everything visible.
class GradientPaint extends StatelessWidget {
  final Color color;
  final Widget child;

  const GradientPaint({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => brandGradient(color).createShader(bounds),
      child: child,
    );
  }
}

/// An [Icon] filled with [brandGradient] of [color].
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const GradientIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return GradientPaint(
      color: color,
      // White, because srcIn replaces the colour outright — any other value
      // here would change nothing except the anti-aliased edges.
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
