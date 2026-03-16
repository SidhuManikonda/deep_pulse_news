import 'package:shared_preferences/shared_preferences.dart';

enum FontSize {
  small('Small', 0.6),
  medium('Medium', 0.8),
  large('Large', 1.0);

  const FontSize(this.displayName, this.scale);
  
  final String displayName;
  final double scale;

  static FontSize fromString(String value) {
    return FontSize.values.firstWhere(
      (size) => size.name == value,
      orElse: () => FontSize.medium,
    );
  }
}

class FontService {
  static const String _fontSizeKey = 'app_font_size';
  
  // Get saved font size
  Future<FontSize> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final fontSizeString = prefs.getString(_fontSizeKey);
    if (fontSizeString != null) {
      return FontSize.fromString(fontSizeString);
    }
    return FontSize.medium; // Default
  }

  // Save font size
  Future<void> saveFontSize(FontSize fontSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, fontSize.name);
  }

  // Clear font size (reset to default)
  Future<void> clearFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fontSizeKey);
  }
}
