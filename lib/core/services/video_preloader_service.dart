import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

class VideoPreloaderService {
  static final VideoPreloaderService _instance = VideoPreloaderService._internal();
  factory VideoPreloaderService() => _instance;
  VideoPreloaderService._internal();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializationStatus = {};
  final Set<String> _activeUrls = {}; // Track actively used controllers
  final int _maxCachedControllers = 6;

  /// Mark a controller as actively in use (prevents eviction)
  void markActive(String videoUrl) {
    _activeUrls.add(videoUrl);
  }

  /// Mark a controller as no longer actively in use
  void markInactive(String videoUrl) {
    _activeUrls.remove(videoUrl);
  }

  Future<VideoPlayerController?> getOrCreateController(String videoUrl) async {
    if (_controllers.containsKey(videoUrl)) {
      final controller = _controllers[videoUrl]!;
      // Re-initialize if the controller was disposed or errored
      if (!controller.value.isInitialized || controller.value.hasError) {
        _controllers.remove(videoUrl);
        _initializationStatus.remove(videoUrl);
        try {
          controller.dispose();
        } catch (_) {}
        return _createAndInitController(videoUrl);
      }
      return controller;
    }

    _evictIfNeeded();
    return _createAndInitController(videoUrl);
  }

  Future<VideoPlayerController?> _createAndInitController(String videoUrl) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
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
      try {
        controller.dispose();
      } catch (_) {}
      return null;
    }
  }

  Future<void> preloadVideo(String videoUrl) async {
    if (_controllers.containsKey(videoUrl) && _initializationStatus[videoUrl] == true) {
      return;
    }

    _evictIfNeeded();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: const {'Connection': 'keep-alive'},
    );
    _controllers[videoUrl] = controller;
    _initializationStatus[videoUrl] = false;

    try {
      await controller.initialize();
      _initializationStatus[videoUrl] = true;
    } catch (e) {
      debugPrint('Error preloading video: $e');
      _controllers.remove(videoUrl);
      _initializationStatus.remove(videoUrl);
      try {
        controller.dispose();
      } catch (_) {}
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

  /// Evict oldest non-active, non-playing controller if at capacity
  void _evictIfNeeded() {
    if (_controllers.length < _maxCachedControllers) return;

    // Find the first controller that is not active and not playing
    String? keyToRemove;
    for (final entry in _controllers.entries) {
      if (!_activeUrls.contains(entry.key) && !entry.value.value.isPlaying) {
        keyToRemove = entry.key;
        break;
      }
    }

    if (keyToRemove != null) {
      final controller = _controllers.remove(keyToRemove);
      _initializationStatus.remove(keyToRemove);
      controller?.dispose();
    }
  }

  void removeController(String videoUrl) {
    _activeUrls.remove(videoUrl);
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
    _activeUrls.clear();
  }

  void disposeController(String videoUrl) {
    _activeUrls.remove(videoUrl);
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
