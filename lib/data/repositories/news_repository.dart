import '../models/news.dart';
import '../models/create_news_request.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class NewsRepository {
  Future<List<News>> getNews({String? status, String? userId});
  Future<News?> getNewsById(int id);
  Future<News?> createNews(CreateNewsRequest request);
  Future<News?> updateNews(int id, CreateNewsRequest request);
  Future<bool> deleteNews(int id);
  Future<bool> updateNewsStatus(int newsId, String status);
  Future<Map<String, dynamic>> shareNews(int newsId, String platform);
}

class NewsRepositoryImpl implements NewsRepository {
  final ApiService _apiService;

  NewsRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;
  @override
  Future<List<News>> getNews({String? status, String? userId}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) {
        queryParams['status'] = status;
      }
      if (userId != null) {
        queryParams['user_id'] = userId;
      }

      final response = await _apiService.get(
        AppConstants.news,
        queryParameters: queryParams,
        useAuth: userId != null,
      );

      List<Map<String, dynamic>> newsData = [];
      if (response != null) {
        newsData = List<Map<String, dynamic>>.from(response);
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

  @override
  Future<bool> updateNewsStatus(int newsId, String status) async {
    try {
      final response = await _apiService.put(
        '${AppConstants.newsStatus}/$newsId',
        {'status': status},
        useAuth: true, // Require authentication for status updates
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      // Check for success by looking for message or news data
      return response.containsKey('message') || response.containsKey('news');
    } catch (e) {
      throw Exception('Failed to update news status: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> shareNews(int newsId, String platform) async {
    try {
      final response = await _apiService.post(
        '${AppConstants.news}/shared',
        body: {'news_id': newsId, 'platform': platform},
        useAuth: true, // Require authentication for sharing
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      return response;
    } catch (e) {
      throw Exception('Failed to share news: $e');
    }
  }
}
