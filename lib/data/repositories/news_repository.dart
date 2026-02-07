import '../models/news.dart';
import '../models/create_news_request.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class NewsRepository {
  Future<List<News>> getNews();
  Future<News?> getNewsById(int id);
  Future<News?> createNews(CreateNewsRequest request);
  Future<News?> updateNews(int id, CreateNewsRequest request);
  Future<bool> deleteNews(int id);
}

class NewsRepositoryImpl implements NewsRepository {
  final ApiService _apiService;

  NewsRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;
  @override
  Future<List<News>> getNews() async {
    try {
      final response = await _apiService.get(AppConstants.news, useAuth: false);

      List<dynamic> newsData;

      // 🔹 CASE 1: Response is a List (your current API)
      if (response is List) {
        newsData = response;
      }
      // 🔹 CASE 2: Response is a Map
      else if (response is Map<String, dynamic>) {
        // Handle error key safely
        if (response.containsKey('error')) {
          throw Exception(response['error']);
        }

        if (response.containsKey('data')) {
          newsData = response['data'] as List<dynamic>;
        } else if (response.containsKey('news')) {
          newsData = response['news'] as List<dynamic>;
        } else {
          throw Exception('Unexpected response structure');
        }
      }
      // 🔹 CASE 3: Completely invalid response
      else {
        throw Exception('Invalid API response type');
      }

      return newsData.map((json) => News.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch news: $e');
    }
  }

  @override
  Future<News?> getNewsById(int id) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.news}/$id',
        useAuth: false, // Allow unauthenticated access to read news
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final newsData = response['news'] ?? response;
      return News.fromJson(newsData);
    } catch (e) {
      throw Exception('Failed to fetch news: $e');
    }
  }

  @override
  Future<News?> createNews(CreateNewsRequest request) async {
    try {
      final response = await _apiService.postMultipart(
        AppConstants.news,
        fields: request.toFormData(),
        files: request.files,
        fileFieldName: 'files[]',
        useAuth: true, // Require authentication for creating news
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('news')) {
        return News.fromJson(response['news']);
      } else if (response.containsKey('data')) {
        return News.fromJson(response['data']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to create news: $e');
    }
  }

  @override
  Future<News?> updateNews(int id, CreateNewsRequest request) async {
    try {
      // For updates, we might need to use PUT with multipart
      // This depends on your API implementation
      final response = await _apiService.postMultipart(
        '${AppConstants.news}/$id',
        fields: {
          ...request.toFormData(),
          '_method': 'PUT', // Laravel method spoofing for multipart PUT
        },
        files: request.files,
        fileFieldName: 'files[]',
        useAuth: true, // Require authentication for updating news
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('news')) {
        return News.fromJson(response['news']);
      } else if (response.containsKey('data')) {
        return News.fromJson(response['data']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to update news: $e');
    }
  }

  @override
  Future<bool> deleteNews(int id) async {
    try {
      final response = await _apiService.delete(
        '${AppConstants.news}/$id',
        useAuth: true, // Require authentication for deleting news
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      return response.containsKey('success') || response['success'] == true;
    } catch (e) {
      throw Exception('Failed to delete news: $e');
    }
  }
}
