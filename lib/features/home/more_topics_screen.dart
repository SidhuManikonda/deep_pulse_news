import 'package:deep_pulse_news/features/home/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/models/topic.dart';

class MoreTopicsWidget extends ConsumerWidget {
  const MoreTopicsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeViewModel = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);

    if (homeViewModel.isLoadingTopics) {
      return Center(child: CircularProgressIndicator(color: theme.appPrimary));
    }

    // Entertainment is reached from the bottom bar's video button instead,
    // so it is left out of this list rather than offered in two places.
    final topics = homeViewModel.moreTabTopics;

    if (topics.isEmpty) {
      return Center(
        child: Text(
          'No topics available',
          style: TextStyle(
            fontSize: scaledFontSize(14),
            color: theme.appTextSecondary,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: topics.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final topic = topics[index];
        return _TopicCard(
          topic: topic,
          style: _TopicStyle.forTopic(topic.name, index),
          onTap: () => ref.read(homeViewModelProvider).selectTopic(topic),
        );
      },
    );
  }
}

/// One topic as a full-width pastel card: icon badge on the left, title and
/// tagline in the middle, the topic's illustration towards the right edge,
/// and a chevron. Sizes and colours are taken from the More screen design.
class _TopicCard extends StatelessWidget {
  final Topic topic;
  final _TopicStyle style;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.style,
    required this.onTap,
  });

  static const _radius = BorderRadius.all(Radius.circular(16));
  static const _badgeSize = 58.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Pastels glare on a dark background, so dark mode tints the card with
    // the topic colour instead and keeps the text light.
    final gradient = isDark
        ? [
            style.accent.withValues(alpha: 0.30),
            style.accent.withValues(alpha: 0.20),
            style.accent.withValues(alpha: 0.12),
          ]
        : style.gradient;
    final titleColor = isDark ? Colors.white : style.titleColor;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF3D4250);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: _radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0, 0.55, 1],
              colors: gradient,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: style.accent.withValues(alpha: isDark ? 0.0 : 0.16),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: _radius,
            child: Stack(
              children: [
                Positioned(
                  right: 26,
                  top: 1,
                  bottom: 1,
                  width: style.artWidth,
                  child: _art(isDark),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 8, 8),
                  child: Row(
                    children: [
                      _badge(isDark),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              topic.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: scaledFontSize(15),
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                color: titleColor,
                              ),
                            ),
                            if (style.tagline != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                style.tagline!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: scaledFontSize(11),
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: titleColor.withValues(alpha: 0.75),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The illustration behind the right of the card. The artwork is cut from
  /// the design with the card's own gradient behind it, so its left edge is
  /// faded out to sit on the card without a visible seam. Topics with no
  /// artwork get a large faded glyph instead.
  Widget _art(bool isDark) {
    final glyph = Align(
      alignment: Alignment.centerRight,
      child: Icon(
        style.icon,
        size: 84,
        color: style.accent.withValues(alpha: isDark ? 0.18 : 0.16),
      ),
    );
    final asset = style.artAsset;
    if (asset == null) return glyph;

    return Opacity(
      // On dark cards the pastel artwork would read as a bright patch.
      opacity: isDark ? 0.35 : 1,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, 0.3, 0.9, 1],
        ).createShader(rect),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => glyph,
        ),
      ),
    );
  }

  Widget _badge(bool isDark) {
    final glyph = Icon(style.icon, color: style.accent, size: 32);
    final photo = style.badgeImage;

    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.9 : 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: photo == null ? 0 : 2),
        boxShadow: [
          BoxShadow(
            color: style.accent.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: photo == null
          ? glyph
          // Full-colour artwork fills the circle edge to edge, like a
          // profile picture, rather than sitting inset like the glyphs.
          : ClipOval(
              child: Image.asset(
                photo,
                width: _badgeSize,
                height: _badgeSize,
                fit: BoxFit.cover,
                // The source art is ~1250px square; decode near display size
                // so a 58px circle doesn't park a multi-MB bitmap in cache.
                cacheWidth: 174,
                errorBuilder: (_, __, ___) => glyph,
              ),
            ),
    );
  }
}

/// Colours, icons, tagline and artwork for a topic card. Known topics get the
/// look from the design; anything new from the backend falls back to a
/// rotating palette so it still renders as a styled card.
class _TopicStyle {
  /// Left, middle and right of the card background.
  final List<Color> gradient;
  final Color accent;
  final Color titleColor;
  final IconData icon;
  final String? tagline;
  final String? badgeImage;
  final String? artAsset;

  /// Display width of [artAsset], matching its width in the design.
  final double artWidth;

  const _TopicStyle({
    required this.gradient,
    required this.accent,
    required this.titleColor,
    required this.icon,
    this.tagline,
    this.badgeImage,
    this.artAsset,
    this.artWidth = 125,
  });

  static const _art = 'assets/images/topics';

  static _TopicStyle forTopic(String name, int index) {
    switch (name.toLowerCase().trim()) {
      case 'all info':
        return const _TopicStyle(
          gradient: [Color(0xFFDAF0FF), Color(0xFFCFECFE), Color(0xFF98DAFD)],
          accent: Color(0xFF1E88E5),
          titleColor: Color(0xFF0B1660),
          icon: Icons.public_rounded,
          tagline: 'Latest News from Everywhere',
          artAsset: '$_art/all_info_art.png',
          artWidth: 99,
        );
      case 'your area':
        return const _TopicStyle(
          gradient: [Color(0xFFE8EAF6), Color(0xFFDDE1F7), Color(0xFFC5CAE9)],
          accent: Color(0xFF3949AB),
          titleColor: Color(0xFF1A237E),
          icon: Icons.location_on_rounded,
          tagline: 'News Around You',
        );
      case 'special':
        return const _TopicStyle(
          gradient: [Color(0xFFE3FAE8), Color(0xFFD3F7DD), Color(0xFFAEEEB9)],
          accent: Color(0xFF2E9E3A),
          titleColor: Color(0xFF0D3B12),
          icon: Icons.star_rounded,
          tagline: 'Featured Stories & Highlights',
          artAsset: '$_art/special_art.png',
          artWidth: 99,
        );
      // "Former" is how the backend spells the agriculture topic today; the
      // other spellings keep the look if that gets fixed on their side.
      case 'former':
      case 'farmer':
      case 'farmers':
      case 'agriculture':
      case 'farming':
        return const _TopicStyle(
          gradient: [Color(0xFFFBEFE1), Color(0xFFFAEBD6), Color(0xFFE2E78D)],
          accent: Color(0xFFE08A1E),
          titleColor: Color(0xFF6A260A),
          icon: Icons.agriculture_rounded,
          tagline: 'For Our Farmers',
          badgeImage: 'assets/images/topic_farmer.jpg',
          artAsset: '$_art/farmer_art.png',
        );
      case 'sports':
        return const _TopicStyle(
          gradient: [Color(0xFFF7E4FA), Color(0xFFF8D6F9), Color(0xFFFCB9EE)],
          accent: Color(0xFFB0128A),
          titleColor: Color(0xFF5C0D44),
          icon: Icons.sports_cricket_rounded,
          tagline: 'Scores, News & Updates',
          artAsset: '$_art/sports_art.png',
        );
      case 'entertainment':
      case 'cinema':
        return const _TopicStyle(
          gradient: [Color(0xFFD2FBF5), Color(0xFFC3F6ED), Color(0xFF9BEFDD)],
          accent: Color(0xFF0F7F75),
          titleColor: Color(0xFF0A3D38),
          icon: Icons.videocam_rounded,
          tagline: 'Movies, Celebrities & More',
          artAsset: '$_art/entertainment_art.png',
          artWidth: 109,
        );
      case 'jobs':
        return const _TopicStyle(
          gradient: [Color(0xFFFDF9CC), Color(0xFFFEEBC0), Color(0xFFFEDF85)],
          accent: Color(0xFFF28C0F),
          titleColor: Color(0xFF5A2208),
          icon: Icons.work_rounded,
          tagline: 'Latest Job Alerts',
          artAsset: '$_art/jobs_art.png',
        );
      case 'education':
        return const _TopicStyle(
          gradient: [Color(0xFFE8E4FD), Color(0xFFDFD9FD), Color(0xFFC5B5FE)],
          accent: Color(0xFF3F33A8),
          titleColor: Color(0xFF1C1A70),
          icon: Icons.school_rounded,
          tagline: 'Learn • Grow • Succeed',
          artAsset: '$_art/education_art.png',
        );
      case 'politics':
        return _fallback(
          index,
          icon: Icons.account_balance_rounded,
          tagline: 'Leaders, Policies & Elections',
        );
      case 'business':
        return _fallback(
          index,
          icon: Icons.trending_up_rounded,
          tagline: 'Markets & Money',
        );
      case 'health':
        return _fallback(
          index,
          icon: Icons.favorite_rounded,
          tagline: 'Stay Fit & Healthy',
        );
      case 'technology':
      case 'electronics':
        return _fallback(
          index,
          icon: Icons.memory_rounded,
          tagline: 'Gadgets & Tech News',
        );
      default:
        return _fallback(index, icon: Icons.category_rounded);
    }
  }

  /// The design's card colours, reused in turn for topics it doesn't cover.
  static _TopicStyle _fallback(
    int index, {
    required IconData icon,
    String? tagline,
  }) {
    const palette = [
      (
        [Color(0xFFDAF0FF), Color(0xFFCFECFE), Color(0xFF98DAFD)],
        Color(0xFF1E88E5),
        Color(0xFF0B1660),
      ),
      (
        [Color(0xFFE3FAE8), Color(0xFFD3F7DD), Color(0xFFAEEEB9)],
        Color(0xFF2E9E3A),
        Color(0xFF0D3B12),
      ),
      (
        [Color(0xFFF7E4FA), Color(0xFFF8D6F9), Color(0xFFFCB9EE)],
        Color(0xFFB0128A),
        Color(0xFF5C0D44),
      ),
      (
        [Color(0xFFD2FBF5), Color(0xFFC3F6ED), Color(0xFF9BEFDD)],
        Color(0xFF0F7F75),
        Color(0xFF0A3D38),
      ),
      (
        [Color(0xFFFDF9CC), Color(0xFFFEEBC0), Color(0xFFFEDF85)],
        Color(0xFFF28C0F),
        Color(0xFF5A2208),
      ),
      (
        [Color(0xFFE8E4FD), Color(0xFFDFD9FD), Color(0xFFC5B5FE)],
        Color(0xFF3F33A8),
        Color(0xFF1C1A70),
      ),
    ];
    final (gradient, accent, title) = palette[index % palette.length];
    return _TopicStyle(
      gradient: gradient,
      accent: accent,
      titleColor: title,
      icon: icon,
      tagline: tagline,
    );
  }
}
