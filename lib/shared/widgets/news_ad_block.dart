import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/youtube_url.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/news_ad.dart';
import 'cached_image_widget.dart';
import 'video_fullscreen_button.dart';
import 'video_player_widget.dart';

/// A sponsor creative, rendered wherever an article shows its ads — the feed
/// card and the detail page both use this so an advert looks the same in both
/// places and only has to be changed once.
///
/// The creative runs edge-to-edge with no label over it: the corner "Ad" tag
/// this used to carry was dropped by request. Nothing else in the block draws
/// over the artwork except the full-screen chip on a video.
class NewsAdBlock extends StatelessWidget {
  final NewsAd ad;

  /// Caps a tall creative so it can't push the story off screen. Feed cards
  /// pass something shorter than the detail page.
  final double maxHeight;

  const NewsAdBlock({super.key, required this.ad, this.maxHeight = 260});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          if (ad.isYoutube)
            YoutubeAdThumbnail(url: ad.url, height: 200)
          else if (ad.isVideo)
            SizedBox(
              height: 200,
              width: double.infinity,
              child: VideoPlayerWidget(
                videoUrl: ad.url,
                autoPlay: false,
                isVisible: false,
              ),
            )
          else
            AdaptiveCachedImage(
              imageUrl: ad.url,
              backgroundColor: theme.appGrey200,
              maxHeight: maxHeight,
            ),

          // Video creatives get the full-screen chip. The block is only 200px
          // tall inside an article, so anything with detail in it — a phone
          // number, a price list — needs the bigger canvas to be readable at
          // all.
          if (ad.isVideo)
            Positioned(
              top: 6,
              right: 6,
              child: VideoFullscreenButton(
                videoUrl: ad.url,
                title: 'Advertisement',
                // This one never auto-plays in place, so coming back shouldn't
                // start it playing behind the article either.
                resumeOnReturn: false,
              ),
            ),
        ],
      ),
    );
  }
}

/// A YouTube ad: the video's poster frame with a play badge, opening the
/// YouTube app when tapped.
///
/// Nothing plays inside this app by design. `video_player` can't read a
/// YouTube URL at all, and embedding a WebView player would put one in every
/// feed card; sending the viewer to YouTube also means the advertiser gets a
/// view counted where they're measuring it.
class YoutubeAdThumbnail extends StatelessWidget {
  final String url;
  final double? height;
  final BoxFit fit;

  const YoutubeAdThumbnail({
    super.key,
    required this.url,
    this.height,
    this.fit = BoxFit.cover,
  });

  Future<void> _open() async {
    final watch = YoutubeUrl.watchUrl(url) ?? url;
    final uri = Uri.tryParse(watch);
    if (uri == null) return;
    // externalApplication so the YouTube app takes it when installed, rather
    // than opening a logged-out web player in an in-app browser.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = YoutubeUrl.thumbnail(url);

    return GestureDetector(
      onTap: _open,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null)
              CachedImageWidget(
                imageUrl: thumb,
                fit: fit,
                // A private or deleted video keeps a valid URL but loses its
                // poster frame. The ad stays tappable — the video may simply
                // be age-restricted rather than gone.
                errorWidget: Container(color: theme.appGrey200),
              )
            else
              Container(color: theme.appGrey200),
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xCCFF0000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
