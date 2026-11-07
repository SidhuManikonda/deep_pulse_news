import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/services/video_preloader_service.dart';
import '../../features/news/fullscreen_video_screen.dart';

/// The corner chip that opens a video creative in the landscape full-screen
/// player.
///
/// News videos in the feed already carry this affordance, drawn inline at their
/// call site. Ads reuse the same chip and the same screen so a reader learns one
/// gesture for every video in the app, whatever it is showing.
///
/// It also cleans up after the trip. The full-screen player shares the
/// preloader's controller with the card underneath it, and on close it pauses
/// the video and drops the URL's "active" mark — which would otherwise leave the
/// ad frozen behind a play button and its controller eligible for eviction while
/// the card is still on screen. Coming back re-marks the URL and, when the card
/// is still the one the reader is looking at, picks playback up again.
class VideoFullscreenButton extends StatelessWidget {
  final String videoUrl;

  /// Shown in the full-screen player's top bar.
  final String? title;

  /// Whether the card behind should carry on playing once the reader returns.
  /// False for a video that wasn't playing in the first place — an ad sitting
  /// inside an article, say, which only plays when tapped.
  final bool resumeOnReturn;

  const VideoFullscreenButton({
    super.key,
    required this.videoUrl,
    this.title,
    this.resumeOnReturn = true,
  });

  Future<void> _open(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenVideoScreen(videoUrl: videoUrl, title: title),
      ),
    );

    final preloader = VideoPreloaderService();
    preloader.markActive(videoUrl);

    if (!resumeOnReturn) return;
    final controller = preloader.getCachedController(videoUrl);
    if (controller != null && controller.value.isInitialized) {
      controller.setLooping(true);
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: AppRadius.xsAll,
        ),
        child: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
      ),
    );
  }
}
