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
  final _preloader = VideoPreloaderService();

  // Progress bar state
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        if (widget.autoPlay &&
            _controller != null &&
            mounted &&
            _isInitialized &&
            !(_controller?.value.isPlaying ?? false)) {
          _controller?.play();
        }
      } else {
        if (_controller != null && mounted && _isInitialized) {
          _controller?.pause();
        }
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.usePreloader) {
        _controller = await _preloader.getOrCreateController(widget.videoUrl);
      } else {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
        await _controller?.initialize();
      }

      if (mounted && _controller != null) {
        // Add position listener for progress bar
        _controller!.addListener(_onVideoPositionChanged);

        setState(() {
          _isInitialized = true;
          _totalDuration = _controller!.value.duration;
        });

        if (widget.autoPlay) {
          _controller?.play();
          _controller?.setLooping(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    // Always remove listener if controller exists
    if (_controller != null) {
      _controller?.removeListener(_onVideoPositionChanged);
    }
    // Only dispose if not using preloader
    if (!widget.usePreloader && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
    super.dispose();
  }

  void _onVideoPositionChanged() {
    if (mounted && !_isDragging && _controller != null && _isInitialized) {
      try {
        final position = _controller?.value.position ?? Duration.zero;
        final duration = _controller?.value.duration ?? Duration.zero;
        
        // Only update if position is valid and within duration
        if (duration.inMilliseconds > 0 && 
            position.inMilliseconds <= duration.inMilliseconds) {
          setState(() {
            _currentPosition = position;
            _totalDuration = duration;
          });
        }
      } catch (e) {
        // Controller might be disposed, ignore
      }
    }
  }

  void _seekToPosition(Duration position) {
    if (_controller != null && mounted && _isInitialized) {
      try {
        _controller?.seekTo(position);
      } catch (e) {
        // Controller might be disposed, ignore
      }
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
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return RepaintBoundary(
      child: InkWell(
      onTap: () {
        if (_controller != null && mounted && _isInitialized) {
          setState(() {
            try {
              if (_controller?.value.isPlaying ?? false) {
                _controller?.pause();
              } else {
                _controller?.play();
              }
            } catch (e) {
              // Controller might be disposed, ignore
            }
          });
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller != null)
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
          if (_controller != null && !(_controller!.value.isPlaying))
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
          if (_controller != null && _isInitialized && _totalDuration.inMilliseconds > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
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
                    // Progress slider
                    SliderTheme(
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
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbColor: Theme.of(context).primaryColor,
                        overlayColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _currentPosition.inMilliseconds
                            .toDouble()
                            .clamp(0.0, _totalDuration.inMilliseconds.toDouble()),
                        min: 0,
                        max: _totalDuration.inMilliseconds.toDouble(),
                        onChanged: (value) {
                          if (mounted && _controller != null) {
                            setState(() {
                              _isDragging = true;
                              _currentPosition = Duration(
                                milliseconds: value.toInt(),
                              );
                            });
                          }
                        },
                        onChangeEnd: (value) {
                          if (mounted && _controller != null) {
                            setState(() {
                              _isDragging = false;
                            });
                            _seekToPosition(Duration(milliseconds: value.toInt()));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
