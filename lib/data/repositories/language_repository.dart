import '../models/language.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class LanguageRepository {
  Future<List<Language>?> getLanguages();
}

class LanguageRepositoryImpl implements LanguageRepository {
  final ApiService _apiService;

  LanguageRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<List<Language>?> getLanguages() async {
    try {
      final response = await _apiService.get(
        AppConstants.languages,
        useAuth: true, // Use authentication with dynamic token
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response['languages'] != null) {
        final languages = (response['languages'] as List)
            .map((lang) => Language.fromJson(lang))
            .toList();
        return languages;
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch languages: $e');
    }
  }
}
