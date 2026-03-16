import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class VideoPreloaderService {
  static final VideoPreloaderService _instance = VideoPreloaderService._internal();
  factory VideoPreloaderService() => _instance;
  VideoPreloaderService._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializationStatus = {};
  final int _maxCachedControllers = 8;

  Future<VideoPlayerController?> getOrCreateController(String videoUrl) async {
    if (_controllers.containsKey(videoUrl)) {
      return _controllers[videoUrl];
    }

    if (_controllers.length >= _maxCachedControllers) {
      _clearOldestController();
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controllers[videoUrl] = controller;
    _initializationStatus[videoUrl] = false;

    try {
      await controller.initialize();
      _initializationStatus[videoUrl] = true;
      return controller;
    } catch (e) {
      debugPrint('Error initializing video: $e');
      _controllers.remove(videoUrl);
      _initializationStatus.remove(videoUrl);
      return null;
    }
  }

  Future<void> preloadVideo(String videoUrl) async {
    if (_controllers.containsKey(videoUrl) && _initializationStatus[videoUrl] == true) {
      return;
    }

    if (_controllers.length >= _maxCachedControllers) {
      _clearOldestController();
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controllers[videoUrl] = controller;
    _initializationStatus[videoUrl] = false;

    try {
      await controller.initialize();
      _initializationStatus[videoUrl] = true;
      debugPrint('Preloaded video: $videoUrl');
    } catch (e) {
      debugPrint('Error preloading video: $e');
      _controllers.remove(videoUrl);
      _initializationStatus.remove(videoUrl);
    }
  }

  Future<void> preloadVideos(List<String> videoUrls) async {
    for (final url in videoUrls) {
      if (!_controllers.containsKey(url)) {
        await preloadVideo(url);
      }
    }
  }

  VideoPlayerController? getCachedController(String videoUrl) {
    return _controllers[videoUrl];
  }

  bool isVideoInitialized(String videoUrl) {
    return _initializationStatus[videoUrl] ?? false;
  }

  void _clearOldestController() {
    if (_controllers.isEmpty) return;
    
    final oldestKey = _controllers.keys.first;
    final controller = _controllers.remove(oldestKey);
    _initializationStatus.remove(oldestKey);
    controller?.dispose();
    debugPrint('Cleared oldest controller: $oldestKey');
  }

  void removeController(String videoUrl) {
    final controller = _controllers.remove(videoUrl);
    _initializationStatus.remove(videoUrl);
    controller?.dispose();
  }

  void clearAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializationStatus.clear();
  }

  void disposeController(String videoUrl) {
    final controller = _controllers.remove(videoUrl);
    _initializationStatus.remove(videoUrl);
    controller?.dispose();
  }

  void pauseAllVideos() {
    for (final controller in _controllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void pauseVideo(String videoUrl) {
    final controller = _controllers[videoUrl];
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
  }

  void pauseAllExcept(String videoUrl) {
    for (final entry in _controllers.entries) {
      if (entry.key != videoUrl && entry.value.value.isPlaying) {
        entry.value.pause();
      }
    }
  }
}
