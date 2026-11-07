// The gradient family: derived from one base colour, and applied without
// wrecking the contrast of anything drawn on top of a solid chip.
import 'package:deep_pulse_news/shared/widgets/gradient_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the gradient is derived from the base, light to dark', () {
    const base = Color(0xFF1E88E5);
    final g = brandGradient(base);

    expect(g.colors.length, 2);
    final light = HSLColor.fromColor(g.colors.first).lightness;
    final dark = HSLColor.fromColor(g.colors.last).lightness;
    final baseL = HSLColor.fromColor(base).lightness;

    expect(light, greaterThan(baseL), reason: 'first stop lifts the base');
    expect(dark, lessThan(baseL), reason: 'second stop deepens it');
    // Same hue throughout — a gradient, not a colour change.
    expect(HSLColor.fromColor(g.colors.first).hue,
        closeTo(HSLColor.fromColor(base).hue, 0.5));
  });

  test('every stop stays inside the legal lightness range', () {
    for (final base in const [
      Color(0xFF000000), // already at the floor
      Color(0xFFFFFFFF), // already at the ceiling
      Color(0xFFE53935),
    ]) {
      for (final c in brandGradient(base).colors) {
        final l = HSLColor.fromColor(c).lightness;
        expect(l, inInclusiveRange(0.0, 1.0),
            reason: 'clamping must hold for $base');
      }
    }
  });

  testWidgets('GradientIcon paints the glyph, not a blank mask',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: GradientIcon(icon: Icons.thumb_up, color: Color(0xFF1E88E5)),
        ),
      ),
    ));
    // srcIn takes its shape from the child, so the child must be opaque white;
    // a transparent child would mask everything away.
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, Colors.white);
    expect(find.byType(ShaderMask), findsOneWidget);
  });
}
