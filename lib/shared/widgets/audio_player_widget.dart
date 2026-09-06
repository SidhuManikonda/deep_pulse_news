import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Compact audio player for news media of type `audio`.
///
/// Reuses the already-bundled `video_player` plugin (its native player handles
/// mp3/m4a/aac/etc.) so no extra dependency is needed — we just render an
/// audio-style UI (play/pause + scrubber + time) instead of a video surface.
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;

  /// Pause playback when the item scrolls out of view.
  final bool isVisible;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.isVisible = true,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _dispose();
      _initialize();
      return;
    }
    // Pause when scrolled away.
    if (oldWidget.isVisible && !widget.isVisible) {
      _controller?.pause();
    }
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.audioUrl),
        httpHeaders: const {'Connection': 'keep-alive'},
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_onStateChanged);
      setState(() {
        _isInitialized = true;
        _hasError = false;
        _duration = controller.value.duration;
      });
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onStateChanged() {
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
    } else {
      setState(() {}); // keep play/pause icon in sync
    }
  }

  void _dispose() {
    _controller?.removeListener(_onStateChanged);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_isInitialized) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        // Restart from the beginning if it finished.
        if (_position >= _duration && _duration > Duration.zero) {
          c.seekTo(Duration.zero);
        }
        c.play();
      }
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    if (_hasError) {
      return Container(
        color: theme.colorScheme.surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_rounded, size: 36, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Failed to load audio',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () {
                _dispose();
                setState(() {
                  _hasError = false;
                  _position = Duration.zero;
                  _duration = Duration.zero;
                });
                _initialize();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final isPlaying = _controller?.value.isPlaying ?? false;
    final maxMs = _duration.inMilliseconds.toDouble();
    final valueMs = _position.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs <= 0 ? 1.0 : maxMs,
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      // Center the controls so the player sits nicely when its box is taller
      // than the row (e.g. the feed gives audio a fixed min-height block).
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Row(
        children: [
          // Play / pause button
          GestureDetector(
            onTap: _isInitialized ? _togglePlay : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
              child: !_isInitialized
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Scrubber + time + label
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.audiotrack_rounded, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      'Audio',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: primary,
                    inactiveTrackColor: primary.withValues(alpha: 0.2),
                    thumbColor: primary,
                    overlayColor: primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: valueMs,
                    min: 0,
                    max: maxMs <= 0 ? 1.0 : maxMs,
                    onChanged: !_isInitialized || maxMs <= 0
                        ? null
                        : (v) {
                            setState(() {
                              _isDragging = true;
                              _position = Duration(milliseconds: v.toInt());
                            });
                          },
                    onChangeEnd: !_isInitialized || maxMs <= 0
                        ? null
                        : (v) {
                            _controller
                                ?.seekTo(Duration(milliseconds: v.toInt()));
                            setState(() => _isDragging = false);
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(_position),
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                      Text(
                        _fmt(_duration),
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
