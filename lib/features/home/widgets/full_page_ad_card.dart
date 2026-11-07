import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_font_sizes.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../data/models/feed_ad.dart';
import '../../../shared/widgets/app_wordmark.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/cached_image_widget.dart';
import '../../../shared/widgets/report_bottom_sheet.dart';
import '../../../shared/widgets/news_ad_block.dart';
import '../../../shared/widgets/video_fullscreen_button.dart';
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
/// **It reads as bought space.** The card sits on its own dark ground instead
/// of the feed's white card, and keeps the Deep Pulse mark at the bottom, so it
/// is visibly not one of the editorial cards around it.
///
/// **Its controls are the ones the ad actually allows.** Like, share and
/// report are each switched on per ad by whoever sold it, so a button only
/// appears when that ad permits it — a disabled control on bought space just
/// invites taps that do nothing. There is still no landing-page button,
/// because the payload carries no landing page. What it does carry is a "keep
/// scrolling" hint, so a full-bleed page never reads as the end of the feed —
/// the one real risk of a full-screen interruption.
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
            // A video creative gets the same full-screen chip the feed's news
            // videos have — the card is page-sized but still portrait and
            // letterboxed, so a landscape advert is only really watchable
            // turned sideways. It sits opposite the disclosure so neither
            // covers the other.
            if (ad.isVideo)
              Positioned(
                top: 14,
                right: 14,
                child: VideoFullscreenButton(
                  videoUrl: ad.url,
                  title: 'Advertisement',
                  // Only pick playback back up if this is still the page the
                  // reader is on.
                  resumeOnReturn: isActive,
                ),
              ),
            // The headline, when the ad has one, sits above the actions so
            // neither covers the creative's own artwork.
            if (ad.title.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 96,
                child: Text(
                  ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: scaledFontSize(17),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
              ),
            if (ad.isLikeable || ad.isShareable || ad.isReportable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 56,
                child: AdActionBar(ad: ad),
              ),
            Positioned(left: 0, right: 0, bottom: 16, child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  /// The blurred backdrop plus the creative sitting on top of it, both drawn
  /// from the same file so the page picks up the advert's own colours.
  Widget _buildCreative(ThemeData theme) {
    // A YouTube ad is a poster frame that opens the YouTube app — nothing
    // plays in the pager, so there's no autoplay to tie to [isActive].
    if (ad.isYoutube) {
      return YoutubeAdThumbnail(url: ad.url, fit: BoxFit.contain);
    }

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
            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
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
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
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
        // The wordmark spells the name itself, so this no longer pairs the
        // square mark with a "Deep Pulse" label.
        const Center(child: AppWordmark(height: 18, borderRadius: 4)),
      ],
    );
  }
}

/// Like, share and report for a standalone ad.
///
/// Each control is present only when that ad allows it (`is_likeable`,
/// `is_shareable`, `is_reportable`), so the bar is as narrow as one button or
/// absent entirely. Stateful because the like has to light up on tap: waiting
/// for the round trip on a feed page reads as a dead button.
class AdActionBar extends ConsumerStatefulWidget {
  final FeedAd ad;

  const AdActionBar({super.key, required this.ad});

  @override
  ConsumerState<AdActionBar> createState() => _AdActionBarState();
}

class _AdActionBarState extends ConsumerState<AdActionBar> {
  late bool _liked = widget.ad.isLiked;
  late int _likes = widget.ad.likesCount;
  late int _shares = widget.ad.sharesCount;
  bool _busy = false;
  bool _sharing = false;

  Future<void> _toggleLike() async {
    if (_busy) return;
    final wasLiked = _liked;
    final wasLikes = _likes;
    setState(() {
      _busy = true;
      _liked = !wasLiked;
      _likes = wasLikes + (wasLiked ? -1 : 1);
    });

    final result = await ref
        .read(adsRepositoryProvider)
        .toggleLike(widget.ad.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == null) {
        // The call failed, so put back exactly what was on screen before —
        // leaving the optimistic state would tell the reader their like was
        // recorded when it wasn't.
        _liked = wasLiked;
        _likes = wasLikes;
      } else {
        _liked = result.liked;
        // Trust the server's count only when it sent one; some replies carry
        // the state without the total.
        if (result.count > 0 || !result.liked) _likes = result.count;
      }
    });
  }

  Future<void> _share() async {
    if (_sharing) return;
    _sharing = true;
    final ad = widget.ad;
    try {
      // Recorded before the sheet opens so the count updates with it. The
      // link is always the app-link URL rather than the reply's `share_url`,
      // which points at deeppulse.media — a host with no assetlinks.json, so
      // tapping it never opened the app.
      final result = await ref.read(adsRepositoryProvider).recordShare(ad.id);
      if (!mounted) return;
      if (result != null && result.count > 0) {
        setState(() => _shares = result.count);
      }
      final link = ad.shareLink;
      await Share.share(ad.title.isNotEmpty ? '${ad.title}\n$link' : link);
    } finally {
      _sharing = false;
    }
  }

  void _report() {
    ReportBottomSheet.show(context, type: 'ad', itemId: widget.ad.id);
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (ad.isLikeable)
          _action(
            icon: _liked ? Icons.favorite : Icons.favorite_border,
            label: _likes > 0 ? '$_likes' : 'Like',
            tint: _liked ? const Color(0xFFFF4D6D) : Colors.white,
            onTap: _toggleLike,
          ),
        if (ad.isShareable)
          _action(
            icon: Icons.share_outlined,
            label: _shares > 0 ? '$_shares' : 'Share',
            tint: Colors.white,
            onTap: _share,
          ),
        if (ad.isReportable)
          _action(
            icon: Icons.flag_outlined,
            label: 'Report',
            tint: Colors.white,
            onTap: _report,
          ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            // Dark pill so the controls stay legible over any creative,
            // light or dark, without dimming the artwork underneath.
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: scaledFontSize(13),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
