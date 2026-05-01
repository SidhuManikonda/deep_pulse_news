import 'dart:ui';

const double _referenceWidth = 375.0;

double _scale() {
  final width = PlatformDispatcher.instance.views.first.physicalSize.width /
      PlatformDispatcher.instance.views.first.devicePixelRatio;
  return (width / _referenceWidth).clamp(0.85, 1.15);
}

final double appFontSizeCaption = 12.0 * _scale();
final double appFontSizeBody = 14.0 * _scale();
final double appFontSizeSubHeader = 16.0 * _scale();
final double appFontSizeHeader = 18.0 * _scale();
final double appFontSizeTitle = 22.0 * _scale();
final double appFontSizeLargeTitle = 32.0 * _scale();

/// For one-off sizes not covered by the constants above.
double scaledFontSize(double base) => base * _scale();
