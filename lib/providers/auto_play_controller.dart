import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoPlayController extends ChangeNotifier {
  static const String _key = 'settings_autoplay_videos';

  bool _enabled = true; // default: autoplay on (matches existing default)
  bool _isInitialized = false;

  bool get enabled => _enabled;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    notifyListeners();
  }
}
