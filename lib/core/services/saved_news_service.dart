import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/news.dart';

class SavedNewsService {
  static const String _savedNewsPrefix = 'saved_news_';
  final int? _userId;

  SavedNewsService({int? userId}) : _userId = userId;

  String get _key => '$_savedNewsPrefix${_userId ?? 'guest'}';

  Future<List<News>> getSavedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((item) => News.fromJson(item)).toList();
  }

  Future<void> saveNews(News news) async {
    final savedNews = await getSavedNews();
    // Don't save duplicates
    if (savedNews.any((n) => n.id == news.id)) return;
    savedNews.insert(0, news);
    await _persist(savedNews);
  }

  Future<void> removeNews(int newsId) async {
    final savedNews = await getSavedNews();
    savedNews.removeWhere((n) => n.id == newsId);
    await _persist(savedNews);
  }

  Future<bool> isNewsSaved(int newsId) async {
    final savedNews = await getSavedNews();
    return savedNews.any((n) => n.id == newsId);
  }

  Future<void> _persist(List<News> newsList) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(newsList.map((n) => n.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}
