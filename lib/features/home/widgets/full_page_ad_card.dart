import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../data/models/feed_ad.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/cached_image_widget.dart';
import '../../../shared/widgets/video_player_widget.dart';

/// A standalone advertisement occupying a whole feed page.
///
/// Design notes, since this is the one card in the feed that isn't editorial:
///
/// **The creative is never cropped.** Adverts are laid out by whoever made
/// them — a cropped logo or a cut-off phone number is a wasted booking. So the
/// artwork is contained, and the leftover space is filled with a heavily
/// blurred, darkened copy of the creative itself. That's the same trick the
/// news cards already use for portrait photos, so a full-page ad still looks
/// like it belongs to this app rather than a web banner dropped in.
///
/// **It reads as bought space, immediately.** The card sits on its own dark
/// ground instead of the feed's white card, carries an "ADVERTISEMENT" label at
/// the top, and keeps the Deep Pulse mark at the bottom. A reader should never
/// have to wonder for even a moment whether this is a story.
///
/// **It doesn't pretend to be interactive.** The payload carries no landing
/// page, so there is no button that would do nothing when tapped. What it does
/// carry is a "keep scrolling" hint, so a full-bleed page never reads as the
/// end of the feed — the one real risk of a full-screen interruption.
class FullPageAdCard extends StatelessWidget {
  final FeedAd ad;

  /// Whether this is the page the reader is actually on. Video creatives only
  /// play on the visible page — several decoders running behind the scroll is
  /// what makes a feed stutter.
  final bool isActive;

  const FullPageAdCard({super.key, required this.ad, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF101216),
          borderRadius: AppRadius.mdAll,
          boxShadow: theme.shadowMd,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCreative(theme),
            _buildTopScrim(),
            _buildBottomScrim(),
            Positioned(top: 14, left: 14, child: _buildLabel()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: _buildFooter(),
            ),
          ],
        ),
      ),
    );
  }

  /// The blurred backdrop plus the creative sitting on top of it, both drawn
  /// from the same file so the page picks up the advert's own colours.
  Widget _buildCreative(ThemeData theme) {
    if (ad.isVideo) {
      return VideoPlayerWidget(
        videoUrl: ad.url,
        autoPlay: isActive,
        isVisible: isActive,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedImageWidget(
          imageUrl: ad.url,
          fit: BoxFit.cover,
          errorWidget: const SizedBox.shrink(),
        ),
        // Blur + dim the cover copy hard enough that it reads as a backdrop and
        // never competes with the real creative laid over it.
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Center(
          child: CachedImageWidget(
            imageUrl: ad.url,
            fit: BoxFit.contain,
            errorWidget: Center(
              child: Icon(
                Icons.campaign_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Keeps the label legible over a creative that happens to be light at the
  /// top, without dimming the artwork across the whole page.
  Widget _buildTopScrim() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomScrim() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  /// The disclosure. A ruled label rather than a chip — it borrows the
  /// typographic language of the poster's "ADVERTISEMENT" rule, so the app says
  /// the same thing the same way wherever an advert appears.
  Widget _buildLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(
            color: Color(0xFFFFC107),
            shape: BoxShape.circle,
          )),
          const SizedBox(width: 7),
          Text(
            'ADVERTISEMENT',
            style: TextStyle(
              fontSize: scaledFontSize(10),
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tells the reader the page ends here and the stories continue. Without
        // it a full-bleed creative can read as the bottom of the feed.
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 4),
            Text(
              'Swipe for the next story',
              style: TextStyle(
                fontSize: scaledFontSize(12),
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(size: 16, borderRadius: 4),
            const SizedBox(width: 6),
            Text(
              'Deep Pulse',
              style: TextStyle(
                fontSize: scaledFontSize(11),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
