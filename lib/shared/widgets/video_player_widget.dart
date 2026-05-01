import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/video_preloader_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool usePreloader;
  final bool isVisible;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.usePreloader = true,
    this.isVisible = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isRetrying = false;
  final _preloader = VideoPreloaderService();

  // Progress bar state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;

  // Suppress buffering indicator after seek to avoid flashing spinner
  bool _suppressBuffering = false;
  Timer? _suppressTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle URL change
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeCurrentController();
      _initializeVideo();
      return;
    }

    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        if (_controller != null && _isInitialized) {
          if (_controller!.value.hasError) {
            _retryInitialization();
            return;
          }
          if (widget.autoPlay && !(_controller!.value.isPlaying)) {
            _controller!.play();
          }
        }
      } else {
        if (_controller != null && _isInitialized) {
          _controller!.pause();
        }
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.usePreloader) {
        _preloader.markActive(widget.videoUrl);
        _controller = await _preloader.getOrCreateController(widget.videoUrl);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          httpHeaders: const {'Connection': 'keep-alive'},
        );
        await _controller!.initialize();
      }

      if (mounted && _controller != null && _controller!.value.isInitialized) {
        _controller!.addListener(_onVideoStateChanged);

        setState(() {
          _isInitialized = true;
          _hasError = false;
          _totalDuration = _controller!.value.duration;
        });

        if (widget.autoPlay && widget.isVisible) {
          _controller!.play();
          _controller!.setLooping(true);
        }
      } else if (mounted) {
        setState(() => _hasError = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  Future<void> _retryInitialization() async {
    if (_isRetrying) return;
    _isRetrying = true;

    setState(() {
      _hasError = false;
      _isInitialized = false;
    });

    _disposeCurrentController();
    await _initializeVideo();
    _isRetrying = false;
  }

  void _disposeCurrentController() {
    if (_controller != null) {
      _controller!.removeListener(_onVideoStateChanged);
    }
    if (widget.usePreloader) {
      _preloader.markInactive(widget.videoUrl);
    } else if (_controller != null) {
      _controller!.dispose();
    }
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _suppressTimer?.cancel();
    _disposeCurrentController();
    super.dispose();
  }

  void _onVideoStateChanged() {
    if (!mounted || _controller == null || !_isInitialized) return;

    try {
      final value = _controller!.value;

      if (value.hasError) {
        setState(() => _hasError = true);
        return;
      }

      // Update position for progress bar (only when not dragging)
      if (!_isDragging) {
        final position = value.position;
        final duration = value.duration;

        if (duration.inMilliseconds > 0 &&
            position.inMilliseconds <= duration.inMilliseconds) {
          setState(() {
            _currentPosition = position;
            _totalDuration = duration;
          });
        }
      }
    } catch (e) {
      // Controller might be disposed, ignore
    }
  }

  void _seekToPosition(Duration position, {bool resumePlaying = false}) {
    if (_controller == null || !mounted || !_isInitialized) return;
    try {
      // Suppress the buffering indicator for 1.5s after seek so rapid
      // forward/backward dragging doesn't flash the spinner.
      _suppressTimer?.cancel();
      _suppressBuffering = true;

      _controller!.seekTo(position);
      if (resumePlaying) {
        _controller!.play();
        _controller!.setLooping(true);
      }

      _suppressTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _suppressBuffering = false);
        }
      });
    } catch (e) {
      // Controller might be disposed, ignore
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget(context);
    }

    if (!_isInitialized || _controller == null) {
      return _buildLoadingWidget();
    }

    // Never show buffering spinner during drag, seek cooldown, or suppression
    final isBuffering = _controller!.value.isBuffering &&
        !_isDragging &&
        !_suppressBuffering;
    final isPlaying = _controller!.value.isPlaying;

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          if (_controller != null && mounted && _isInitialized) {
            setState(() {
              try {
                if (isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.setLooping(true);
                  _controller!.play();
                }
              } catch (e) {
                // Controller might be disposed
              }
            });
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),

            // Buffering indicator
            if (isBuffering)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),

            // Play button overlay (when paused and not buffering)
            if (!isPlaying && !isBuffering && !_isDragging && !_suppressBuffering)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),

            // Progress bar at bottom
            if (_totalDuration.inMilliseconds > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {}, // Absorb taps so they don't toggle play/pause
                  child: RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Time display row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Progress slider — GestureDetector absorbs horizontal drags
                          // so the parent InkWell doesn't steal the gesture
                          GestureDetector(
                            onHorizontalDragStart: (_) {},
                            onHorizontalDragUpdate: (_) {},
                            onHorizontalDragEnd: (_) {},
                            child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                                disabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                              activeTrackColor: Theme.of(context).primaryColor,
                              inactiveTrackColor:
                                  Colors.white.withOpacity(0.3),
                              thumbColor: Theme.of(context).primaryColor,
                              overlayColor: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _currentPosition.inMilliseconds
                                  .toDouble()
                                  .clamp(
                                    0.0,
                                    _totalDuration.inMilliseconds.toDouble(),
                                  ),
                              min: 0,
                              max: _totalDuration.inMilliseconds.toDouble(),
                              onChangeStart: (value) {
                                if (mounted && _controller != null) {
                                  _wasPlayingBeforeDrag =
                                      _controller!.value.isPlaying;
                                  if (_wasPlayingBeforeDrag) {
                                    _controller!.pause();
                                  }
                                  setState(() => _isDragging = true);
                                }
                              },
                              onChanged: (value) {
                                if (mounted) {
                                  // Only update the slider UI position —
                                  // do NOT call seekTo here. Rapid seeks
                                  // overwhelm the player and cause it to
                                  // get stuck buffering.
                                  setState(() {
                                    _currentPosition = Duration(
                                      milliseconds: value.toInt(),
                                    );
                                  });
                                }
                              },
                              onChangeEnd: (value) {
                                if (mounted && _controller != null) {
                                  setState(() => _isDragging = false);
                                  // Single seek on release
                                  _seekToPosition(
                                    Duration(milliseconds: value.toInt()),
                                    resumePlaying: _wasPlayingBeforeDrag,
                                  );
                                }
                              },
                            ),
                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Failed to load video',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _retryInitialization,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
