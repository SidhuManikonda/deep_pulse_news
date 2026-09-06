import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/news_ad.dart';
import 'cached_image_widget.dart';
import 'video_player_widget.dart';

/// A sponsor creative, rendered wherever an article shows its ads — the feed
/// card and the detail page both use this so an advert looks the same in both
/// places and only has to be relabelled once.
///
/// The disclosure is a tag laid over the creative's top-left corner rather than
/// a header strip above it. A strip cost a row of vertical space in the feed,
/// where the ad competes with the story for the fold; the corner tag keeps the
/// creative edge-to-edge while still marking it, which is how print and the
/// major news apps do it.
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
          if (ad.isVideo)
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

          // Sits on a solid dark chip rather than tinting the creative, so the
          // label stays readable whatever the advert's own artwork is behind
          // it — a white ad would swallow a translucent tag.
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: Color(0xCC000000),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                'Ad',
                style: TextStyle(
                  fontSize: scaledFontSize(10),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
