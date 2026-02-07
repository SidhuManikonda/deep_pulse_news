import 'package:flutter/foundation.dart';
import '../../data/models/language.dart';
import '../../data/repositories/language_repository.dart';

class LanguageViewModel extends ChangeNotifier {
  final LanguageRepository _languageRepository;
  
  List<Language> _languages = [];
  String? _selectedLanguage;
  bool _isLoading = false;
  String? _error;

  LanguageViewModel({LanguageRepository? languageRepository})
      : _languageRepository = languageRepository ?? LanguageRepositoryImpl();

  // Getters
  List<Language> get languages => _languages;
  String? get selectedLanguage => _selectedLanguage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLanguages => _languages.isNotEmpty;

  // Setters
  void setSelectedLanguage(String? language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Load languages from repository
  Future<void> loadLanguages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final languages = await _languageRepository.getLanguages();
      _languages = languages ?? [];
      _error = null;
    } catch (e) {
      _error = e.toString();
      _languages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Retry loading languages
  Future<void> retryLoadLanguages() async {
    await loadLanguages();
  }

  // Get flag for language
  String getFlagForLanguage(String slug) {
    const flagMap = {
      'en': '🇺🇸',
      'hi': '🇮🇳',
      'gu': '🇮🇳',
      'kn': '🇮🇳',
      'ta': '🇮🇳',
      'te': '🇮🇳',
      'bn': '🇮🇳',
      'mr': '🇮🇳',
      'pa': '🇮🇳',
      'ml': '🇮🇳',
    };
    return flagMap[slug] ?? '🌍';
  }
}
