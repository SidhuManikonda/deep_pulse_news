import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/data/repositories/topics_repository.dart';
import 'package:flutter/material.dart';

class TopicViewmodel extends ChangeNotifier {
  final TopicsRepository _topicsRepository;
  List<Topic> _topics = [];
  List<String> _selectedTopics = [];
  bool _isLoading = false;

  TopicViewmodel({TopicsRepository? topicsRepository})
    : _topicsRepository = topicsRepository ?? TopicsRepositoryImpl();

  List<Topic> get topics => _topics;
  List<String> get selectedTopics => _selectedTopics;
  bool get isLoading => _isLoading;

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
    notifyListeners();
    try {
      final topics = await _topicsRepository.getTopics();
      _topics = topics;
      _isLoading = false;
      notifyListeners();
      return topics;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
