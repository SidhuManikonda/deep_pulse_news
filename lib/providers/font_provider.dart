import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/font_service.dart';

class FontController extends ChangeNotifier {
  final FontService _fontService;
  FontSize _currentFontSize = FontSize.medium;

  FontController(this._fontService);

  FontSize get currentFontSize => _currentFontSize;
  double get fontScale => _currentFontSize.scale;

  Future<void> initialize() async {
    _currentFontSize = await _fontService.getFontSize();
    notifyListeners();
  }

  Future<void> setFontSize(FontSize fontSize) async {
    debugPrint('🔤 FontController: Setting font size from ${_currentFontSize.displayName} to ${fontSize.displayName}');
    _currentFontSize = fontSize;
    await _fontService.saveFontSize(fontSize);
    debugPrint('🔤 FontController: Font scale is now ${fontSize.scale}');
    notifyListeners();
    debugPrint('🔤 FontController: Notified listeners');
  }

  // Helper methods to get scaled font sizes
  double getScaledFontSize(double baseSize) {
    return baseSize * fontScale;
  }

  TextStyle getScaledTextStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * fontScale,
    );
  }
}

// Provider for font controller
final fontControllerProvider = ChangeNotifierProvider<FontController>((ref) {
  return FontController(FontService());
});

// Provider for current font size
final currentFontSizeProvider = StateProvider<FontSize>((ref) {
  return ref.watch(fontControllerProvider).currentFontSize;
});

// Provider for font scale
final fontScaleProvider = StateProvider<double>((ref) {
  return ref.watch(fontControllerProvider).fontScale;
});

// Provider for scaled text styles
final scaledHeadlineLargeProvider = Provider<TextStyle>((ref) {
  final fontScale = ref.watch(fontScaleProvider);
  return GoogleFonts.roboto(
    fontSize: 24 * fontScale,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
});

final scaledHeadlineMediumProvider = Provider<TextStyle>((ref) {
  final fontScale = ref.watch(fontScaleProvider);
  return GoogleFonts.roboto(
    fontSize: 20 * fontScale,
    fontWeight: FontWeight.w600,
    color: Colors.black,
  );
});

final scaledBodyLargeProvider = Provider<TextStyle>((ref) {
  final fontScale = ref.watch(fontScaleProvider);
  return GoogleFonts.roboto(
    fontSize: 16 * fontScale,
    fontWeight: FontWeight.normal,
    color: Colors.black87,
  );
});

final scaledBodyMediumProvider = Provider<TextStyle>((ref) {
  final fontScale = ref.watch(fontScaleProvider);
  return GoogleFonts.roboto(
    fontSize: 14 * fontScale,
    fontWeight: FontWeight.normal,
    color: Colors.black87,
  );
});

// Helper function to get scaled text style
TextStyle getScaledTextStyle({
  double baseSize = 14,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black87,
  required double scale,
}) {
  return GoogleFonts.roboto(
    fontSize: baseSize * scale,
    fontWeight: fontWeight,
    color: color,
  );
}
