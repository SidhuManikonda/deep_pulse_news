import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/data/repositories/topics_repository.dart';
import 'package:flutter/material.dart';

class TopicViewmodel extends ChangeNotifier {
  final TopicsRepository _topicsRepository;
  List<Topic> _topics = [];
  List<String> _selectedTopics = [];
  bool _isLoading = false;
  String? _error;

  TopicViewmodel({TopicsRepository? topicsRepository})
    : _topicsRepository = topicsRepository ?? TopicsRepositoryImpl();

  List<Topic> get topics => _topics;
  List<String> get selectedTopics => _selectedTopics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setTopics(List<Topic> topics) {
    _topics = topics;
    notifyListeners();
  }

  void setSelectedTopics(List<String> selectedTopics) {
    _selectedTopics = selectedTopics;
    notifyListeners();
  }

  Future<List<Topic>> loadTopics() async {
    _isLoading = true;
    _error=null;
    notifyListeners();
    try {
      final topics = await _topicsRepository.getTopics();
      _topics = topics;
      _isLoading = false;
      _error=null;
      notifyListeners();
      return topics;
    } catch (e) {
      _isLoading = false;
      _error=e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
