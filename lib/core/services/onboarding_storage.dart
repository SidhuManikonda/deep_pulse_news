import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../data/models/state.dart';
import '../../../data/models/district.dart';
import '../../../data/models/mandal.dart';

class OnboardingStorage {
  static const String _locationCompletedKey = 'location_completed';
  static const String _languageCompletedKey = 'language_completed';
  static const String _topicsCompletedKey = 'topics_completed';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _selectedStateKey = 'selected_state';
  static const String _selectedDistrictKey = 'selected_district';
  static const String _selectedMandalKey = 'selected_mandal';
  static const String _selectedLanguageKey = 'selected_language';
  static const String _selectedTopicsKey = 'selected_topics';
  static const String _savedMobileKey = 'saved_mobile';

  Future<void> saveMobile(String mobile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedMobileKey, mobile);
  }

  Future<String?> getSavedMobile() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_savedMobileKey);
    return (value != null && value.isNotEmpty) ? value : null;
  }

  Future<void> clearMobile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedMobileKey);
  }

  Future<bool> isLocationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationCompletedKey) ?? false;
  }

  Future<bool> isLanguageCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_languageCompletedKey) ?? false;
  }

  Future<bool> isTopicsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_topicsCompletedKey) ?? false;
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setLocationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationCompletedKey, true);
  }

  Future<void> setLanguageCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageCompletedKey, true);
  }

  Future<void> setTopicsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_topicsCompletedKey, true);
  }

  Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }

  Future<void> saveSelectedLocation(State state, District? district, Mandal? mandal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedStateKey, jsonEncode(state.toJson()));
    
    if (district != null) {
      await prefs.setString(_selectedDistrictKey, jsonEncode(district.toJson()));
    } else {
      await prefs.remove(_selectedDistrictKey);
    }
    
    if (mandal != null) {
      await prefs.setString(_selectedMandalKey, jsonEncode(mandal.toJson()));
    } else {
      await prefs.remove(_selectedMandalKey);
    }
  }

  Future<State?> getSelectedState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_selectedStateKey);
    if (stateJson != null) {
      return State.fromJson(jsonDecode(stateJson));
    }
    return null;
  }

  Future<District?> getSelectedDistrict() async {
    final prefs = await SharedPreferences.getInstance();
    final districtJson = prefs.getString(_selectedDistrictKey);
    if (districtJson != null) {
      return District.fromJson(jsonDecode(districtJson));
    }
    return null;
  }

  Future<Mandal?> getSelectedMandal() async {
    final prefs = await SharedPreferences.getInstance();
    final mandalJson = prefs.getString(_selectedMandalKey);
    if (mandalJson != null) {
      return Mandal.fromJson(jsonDecode(mandalJson));
    }
    return null;
  }

  // Language storage methods
  Future<void> saveSelectedLanguage(int languageId, String languageName) async {
    final prefs = await SharedPreferences.getInstance();
    final languageData = {
      'id': languageId,
      'name': languageName,
    };
    await prefs.setString(_selectedLanguageKey, jsonEncode(languageData));
  }

  Future<Map<String, dynamic>?> getSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageJson = prefs.getString(_selectedLanguageKey);
    if (languageJson != null) {
      return jsonDecode(languageJson);
    }
    return null;
  }

  // Topics storage methods
  Future<void> saveSelectedTopics(List<Map<String, dynamic>> topics) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedTopicsKey, jsonEncode(topics));
  }

  Future<List<Map<String, dynamic>>> getSelectedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final topicsJson = prefs.getString(_selectedTopicsKey);
    if (topicsJson != null) {
      final List<dynamic> topicsList = jsonDecode(topicsJson);
      return topicsList.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationCompletedKey);
    await prefs.remove(_languageCompletedKey);
    await prefs.remove(_topicsCompletedKey);
    await prefs.remove(_onboardingCompletedKey);
    await prefs.remove(_selectedStateKey);
    await prefs.remove(_selectedDistrictKey);
    await prefs.remove(_selectedMandalKey);
    await prefs.remove(_selectedLanguageKey);
    await prefs.remove(_selectedTopicsKey);
  }
}
