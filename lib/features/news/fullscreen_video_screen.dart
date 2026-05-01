import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/video_preloader_service.dart';
import '../../core/constants/app_font_sizes.dart';

class FullscreenVideoScreen extends ConsumerStatefulWidget {
  final String videoUrl;
  final String? title;
  final DateTime? createdAt;

  const FullscreenVideoScreen({
    Key? key,
    required this.videoUrl,
    this.title,
    this.createdAt,
  }) : super(key: key);

  @override
  ConsumerState<FullscreenVideoScreen> createState() =>
      _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState extends ConsumerState<FullscreenVideoScreen> {
  final _preloader = VideoPreloaderService();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  // Slider state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;
  bool _suppressBuffering = false;
  Timer? _suppressTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _preloader.markActive(widget.videoUrl);
      _controller = await _preloader.getOrCreateController(widget.videoUrl);

      if (mounted && _controller != null && _controller!.value.isInitialized) {
        _controller!.addListener(_onVideoChanged);
        setState(() {
          _isInitialized = true;
          _duration = _controller!.value.duration;
        });
        _controller!.setLooping(true);
        _controller!.play();
        _startHideTimer();
      } else if (mounted) {
        setState(() => _hasError = true);
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoChanged() {
    if (!mounted || _controller == null || !_isInitialized) return;
    final value = _controller!.value;
    if (value.hasError) {
      setState(() => _hasError = true);
      return;
    }
    if (!_isDragging) {
      setState(() {
        _position = value.position;
        _duration = value.duration;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _hideTimer?.cancel();
        _controlsVisible = true;
      } else {
        _controller!.play();
        _startHideTimer();
      }
    });
  }

  void _seekRelative(Duration offset) {
    if (_controller == null) return;
    final newPos = _position + offset;
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    _suppressTimer?.cancel();
    _suppressBuffering = true;
    _controller!.seekTo(clamped);
    if (!_controller!.value.isPlaying) _controller!.play();
    _suppressTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _suppressBuffering = false);
    });
    _startHideTimer();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTimestamp(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _suppressTimer?.cancel();
    if (_controller != null) {
      _controller!.removeListener(_onVideoChanged);
      _controller!.pause();
    }
    _preloader.markInactive(widget.videoUrl);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video layer
          Positioned.fill(child: _buildVideoLayer()),

          // Tap area for toggling controls (excludes bottom bar)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              child: const SizedBox.expand(),
            ),
          ),

          // Controls overlay
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Stack(
                children: [
                  _buildTopBar(),
                  _buildCenterControls(),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Video ──────────────────────────────────────────────────────────────────

  Widget _buildVideoLayer() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text('Failed to load video',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializeVideo();
              },
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              label:
                  const Text('Retry', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final isBuffering =
        _controller!.value.isBuffering && !_suppressBuffering && !_isDragging;

    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        if (isBuffering)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.title != null)
                    Text(
                      widget.title!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: scaledFontSize(15),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (widget.createdAt != null)
                    Text(
                      _formatTimestamp(widget.createdAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: scaledFontSize(12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Center play/pause & skip controls ──────────────────────────────────────

  Widget _buildCenterControls() {
    if (!_isInitialized || _controller == null) return const SizedBox.shrink();
    final isPlaying = _controller!.value.isPlaying;

    return Positioned.fill(
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rewind 10s
            _buildCircleButton(
              icon: Icons.replay_10,
              size: 32,
              bgOpacity: 0.4,
              onTap: () => _seekRelative(const Duration(seconds: -10)),
            ),
            const SizedBox(width: 32),
            // Play / Pause
            _buildCircleButton(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              size: 48,
              bgOpacity: 0.5,
              padding: 16,
              onTap: _togglePlayPause,
            ),
            const SizedBox(width: 32),
            // Forward 10s
            _buildCircleButton(
              icon: Icons.forward_10,
              size: 32,
              bgOpacity: 0.4,
              onTap: () => _seekRelative(const Duration(seconds: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required double size,
    required double bgOpacity,
    double padding = 12,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(bgOpacity),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  // ── Bottom bar with slider ─────────────────────────────────────────────────

  Widget _buildBottomBar() {
    if (!_isInitialized || _duration.inMilliseconds == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        // Absorb taps so they don't toggle controls
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Current time
              SizedBox(
                width: 42,
                child: Text(
                  _fmt(_position),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: scaledFontSize(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.15),
                  ),
                  child: Slider(
                    value: _position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, _duration.inMilliseconds.toDouble()),
                    min: 0,
                    max: _duration.inMilliseconds.toDouble(),
                    onChangeStart: (v) {
                      _hideTimer?.cancel();
                      _wasPlayingBeforeDrag = _controller!.value.isPlaying;
                      if (_wasPlayingBeforeDrag) _controller!.pause();
                      setState(() => _isDragging = true);
                    },
                    onChanged: (v) {
                      setState(() {
                        _position = Duration(milliseconds: v.toInt());
                      });
                    },
                    onChangeEnd: (v) {
                      setState(() => _isDragging = false);
                      _suppressTimer?.cancel();
                      _suppressBuffering = true;
                      _controller!
                          .seekTo(Duration(milliseconds: v.toInt()));
                      if (_wasPlayingBeforeDrag) {
                        _controller!.play();
                      }
                      _suppressTimer =
                          Timer(const Duration(milliseconds: 1500), () {
                        if (mounted) {
                          setState(() => _suppressBuffering = false);
                        }
                      });
                      _startHideTimer();
                    },
                  ),
                ),
              ),

              // Total time
              SizedBox(
                width: 42,
                child: Text(
                  _fmt(_duration),
                  textAlign: TextAlign.end,
                  style:  TextStyle(
                    color: Colors.white,
                    fontSize: scaledFontSize(12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
