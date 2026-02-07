import '../models/topic.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class TopicsRepository {
  Future<List<Topic>> getTopics();
  Future<Topic?> getTopicById(int id);
  Future<Topic?> createTopic(Topic topic);
  Future<Topic?> updateTopic(int id, Topic topic);
}

class TopicsRepositoryImpl implements TopicsRepository {
  final ApiService _apiService;

  TopicsRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<List<Topic>> getTopics() async {
    try {
      final response = await _apiService.get(
        AppConstants.topics,
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final topicsData = response['topics'] as List<dynamic>;
      return topicsData.map((topicJson) => Topic.fromJson(topicJson)).toList();
    } catch (e) {
      throw Exception('Failed to fetch topics: $e');
    }
  }

  @override
  Future<Topic?> getTopicById(int id) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.topics}/$id',
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final topicData = response['topic'];
      return Topic.fromJson(topicData);
    } catch (e) {
      throw Exception('Failed to fetch topic: $e');
    }
  }

  @override
  Future<Topic?> createTopic(Topic topic) async {
    try {
      // Create the request body with the exact format expected by the API
      final requestBody = {
        'name': topic.name,
        'is_active': topic.isActive ? 1 : 0,
        'is_trending': topic.isTrending ? 1 : 0,
      };

      final response = await _apiService.post(
        AppConstants.topics,
        body: requestBody,
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('topic')) {
        return Topic.fromJson(response['topic']);
      }

      // If no topic data is returned, return null (topic was created successfully)
      return null;
    } catch (e) {
      throw Exception('Failed to create topic: $e');
    }
  }

  @override
  Future<Topic?> updateTopic(int id, Topic topic) async {
    try {
      // Create the request body with the exact format expected by the API
      final requestBody = {
        'name': topic.name,
        'is_active': topic.isActive ? 1 : 0,
        'is_trending': topic.isTrending ? 1 : 0,
      };

      final response = await _apiService.put(
        '${AppConstants.topics}/$id',
        requestBody,
        useAuth: true,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      // Parse the updated topic from the response
      if (response.containsKey('topic')) {
        return Topic.fromJson(response['topic']);
      }

      // If no topic data is returned, return null
      return null;
    } catch (e) {
      throw Exception('Failed to update topic: $e');
    }
  }
}
