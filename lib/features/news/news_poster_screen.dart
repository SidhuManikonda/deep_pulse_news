import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/color_utils.dart';
import '../../data/models/news.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/cached_image_widget.dart';

/// Preview + download screen for a news article rendered as a shareable
/// newspaper-style poster.
///
/// The poster is a real widget rather than a server-rendered image, so it
/// always reflects the article as published and needs no backend work. It's
/// captured straight off the screen with [RepaintBoundary], which is why the
/// preview is shown at full size rather than generated invisibly — an
/// off-screen boundary that never paints produces a blank PNG on some devices.
class NewsPosterScreen extends StatefulWidget {
  final News news;

  const NewsPosterScreen({super.key, required this.news});

  @override
  State<NewsPosterScreen> createState() => _NewsPosterScreenState();
}

class _NewsPosterScreenState extends State<NewsPosterScreen> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isWorking = false;
  PosterImageSpot _imageSpot = PosterImageSpot.top;
  PosterPalette _palette = PosterPalette.newsprint;

  /// Rasterises the poster. 2× the 1080px design width gives a 2160px-wide
  /// PNG — sharp when opened full-screen, without the ~90 MB intermediate
  /// bitmap a 3× capture of a tall poster would need.
  Future<Uint8List?> _capture() async {
    // Let any in-flight layout/paint finish first. Grabbing a boundary that
    // still needs paint is the usual cause of an intermittent blank or failed
    // capture — most likely right after switching the photo position, when the
    // poster has just been rebuilt.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;

    final boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      debugPrint('[NewsPoster] capture failed: no RepaintBoundary found');
      return null;
    }

    final image = await boundary.toImage(pixelRatio: 2.0);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      debugPrint(
        '[NewsPoster] captured ${image.width}x${image.height}, '
        '${byteData?.lengthInBytes ?? 0} bytes',
      );
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  String get _fileName =>
      'deeppulse_news_${widget.news.id}_${widget.news.displayTime.millisecondsSinceEpoch}';

  Future<void> _download() async {
    setState(() => _isWorking = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception('Could not render the poster');

      // Writing to a custom album is what needs permission on Android; saving
      // to the default gallery location doesn't on API 29+. So ask, and if the
      // user says no, still save — just without the album.
      var useAlbum = true;
      try {
        if (!await Gal.hasAccess(toAlbum: true)) {
          useAlbum = await Gal.requestAccess(toAlbum: true);
        }
      } catch (e) {
        debugPrint('[NewsPoster] album access check failed: $e');
        useAlbum = false;
      }

      await Gal.putImageBytes(
        bytes,
        name: _fileName,
        album: useAlbum ? 'Deep Pulse' : null,
      );

      if (!mounted) return;
      _toast(
        useAlbum
            ? 'Saved to your gallery — Deep Pulse album'
            : 'Saved to your gallery',
      );
    } on GalException catch (e, s) {
      debugPrint(
        '[NewsPoster] GalException ${e.type}: ${e.platformException}\n$s',
      );
      if (!mounted) return;
      _toast('Could not save (${e.type.name}). Try Share instead.');
    } catch (e, s) {
      debugPrint('[NewsPoster] save failed: $e\n$s');
      if (!mounted) return;
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _share() async {
    setState(() => _isWorking = true);
    try {
      final bytes = await _capture();
      if (bytes == null) throw Exception('Could not render the poster');

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: '$_fileName.png',
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _toast('Could not share: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Photo placement picker. Hidden when the article has no photo — there'd be
  /// nothing to position.
  Widget _buildSpotPicker() {
    final hasImage = widget.news.media.any((m) => m.type == 'image');
    if (!hasImage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          const Text(
            'Photo',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: PosterImageSpot.values.map((spot) {
                return ChoiceChip(
                  label: Text(spot.label),
                  selected: _imageSpot == spot,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _imageSpot == spot ? Colors.white : Colors.black87,
                  ),
                  selectedColor: const Color(0xFF6A1B9A),
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => _imageSpot = spot),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Paper-colour picker. Each chip is a swatch of the actual page colour with
  /// a ring in that scheme's accent, so the choice is visible without having to
  /// apply it and look.
  Widget _buildPalettePicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          const Text(
            'Colour',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: PosterPalette.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final palette = PosterPalette.values[i];
                  final selected = _palette == palette;
                  return GestureDetector(
                    onTap: () => setState(() => _palette = palette),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: palette.page,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: selected ? palette.accent : palette.border,
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            palette.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: const Text('Download epaper'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSpotPicker(),
          _buildPalettePicker(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              // FittedBox OUTSIDE the boundary is load-bearing. With it inside
              // NewsPoster, the boundary's layout size was the shrunk-to-screen
              // size (~340px), so the "2×" capture produced a ~680px image.
              // Out here, the boundary still measures the true 1080px design
              // width and only its painting is scaled down for preview.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _posterKey,
                  child: NewsPoster(
                    news: widget.news,
                    imageSpot: _imageSpot,
                    palette: _palette,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isWorking ? null : _share,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isWorking ? null : _download,
                  icon: _isWorking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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

/// The printable layout: branded header band, headline, photo, body, byline.
///
/// Fixed 1080px width so every generated poster is identical regardless of the
/// phone it was made on — otherwise a small screen would produce a narrow,
/// cramped image and a tablet a wide one.
/// A light, print-friendly colour scheme for the poster.
///
/// All kept pale on purpose: the story text and the article's own headline
/// colour have to stay legible on top, and a saturated page would fight the
/// photo. Only the page, panel, rules and strips are themed — body text stays
/// near-black and the headline keeps whatever colour the publisher chose.
class PosterPalette {
  final String label;

  /// Outer page.
  final Color page;

  /// The clipping panel the story sits in.
  final Color panel;
  final Color border;

  /// Dateline strip under the masthead, plus the rules.
  final Color accent;

  /// Bottom strip.
  final Color footer;
  final Color footerText;

  const PosterPalette({
    required this.label,
    required this.page,
    required this.panel,
    required this.border,
    required this.accent,
    required this.footer,
    required this.footerText,
  });

  static const newsprint = PosterPalette(
    label: 'Newsprint',
    page: Color(0xFFF2EDE1),
    panel: Color(0xFFFBF8F1),
    border: Color(0xFFBDB6A6),
    accent: Color(0xFF6A1B9A),
    footer: Color(0xFFF9A825),
    footerText: Color(0xFF3A2E00),
  );

  static const classic = PosterPalette(
    label: 'Classic',
    page: Color(0xFFF5F5F5),
    panel: Color(0xFFFFFFFF),
    border: Color(0xFFC9C9C9),
    accent: Color(0xFF1A237E),
    footer: Color(0xFFE3E7F5),
    footerText: Color(0xFF1A237E),
  );

  static const sky = PosterPalette(
    label: 'Sky',
    page: Color(0xFFE9F2FB),
    panel: Color(0xFFF9FCFF),
    border: Color(0xFFAFC9E3),
    accent: Color(0xFF1565C0),
    footer: Color(0xFFD3E5F7),
    footerText: Color(0xFF0D3C73),
  );

  static const mint = PosterPalette(
    label: 'Mint',
    page: Color(0xFFEAF6EF),
    panel: Color(0xFFF8FCFA),
    border: Color(0xFFAFD4C0),
    accent: Color(0xFF1B7A4B),
    footer: Color(0xFFD4EDE0),
    footerText: Color(0xFF0E4A2C),
  );

  static const rose = PosterPalette(
    label: 'Rose',
    page: Color(0xFFFBEEF1),
    panel: Color(0xFFFEF9FA),
    border: Color(0xFFE2B8C3),
    accent: Color(0xFFA3264A),
    footer: Color(0xFFF5DCE3),
    footerText: Color(0xFF6B1730),
  );

  static const sand = PosterPalette(
    label: 'Sand',
    page: Color(0xFFF7F1E6),
    panel: Color(0xFFFDFBF6),
    border: Color(0xFFD6C3A5),
    accent: Color(0xFF8A5A2B),
    footer: Color(0xFFEDDFC7),
    footerText: Color(0xFF5A3A18),
  );

  static const values = <PosterPalette>[
    newsprint,
    classic,
    sky,
    mint,
    rose,
    sand,
  ];
}

/// A run of story text plus the colour it was published with.
class _BodyRun {
  final String text;
  final Color color;
  const _BodyRun(this.text, this.color);
}

/// Where the photo sits relative to the story text.
enum PosterImageSpot {
  top('Top'),
  left('Left'),
  right('Right');

  const PosterImageSpot(this.label);
  final String label;
}

class NewsPoster extends StatelessWidget {
  final News news;
  final PosterImageSpot imageSpot;
  final PosterPalette palette;

  static const double posterWidth = 1080;

  /// Geometry for the side-by-side layouts, as a share of whatever width the
  /// clipping panel actually offers. The photo needs a known height before it
  /// has loaded, since the text split is measured against it.
  static const double _insetImageFraction = 0.46;
  static const double _insetGap = 26;

  static const String epaperUrl = 'epaper.deeppulse.media';

  /// Opens every story, ahead of the city dateline — the printed paper's
  /// convention: "డీప్‌పల్స్ న్యూస్ : హైదరాబాద్ …".
  ///
  /// డీప్ and పల్స్ are joined by a zero-width non-joiner (U+200C), not by
  /// simply deleting the space. Butting them up directly would put ప్ next to ప,
  /// which Telugu shaping renders as the conjunct ప్ప — a subscripted second
  /// letter, spelling something else entirely. The ZWNJ closes the gap while
  /// keeping both letters upright and separate, which is how the wordmark reads.
  static const String newsCredit = 'డీప్‌పల్స్ న్యూస్ :';

  /// Shared by the three slots in the dateline strip so they stay identical.
  static const TextStyle _stripTextStyle = TextStyle(
    fontSize: 26,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  /// Masthead mark size and the space either side of it. Shared by the
  /// wordmark row and the tagline rules below, so the rules always stop level
  /// with the logo's edges.
  static const double _mastheadLogoSize = 94;
  static const double _mastheadLogoGap = 14;
  static const double _mastheadWordSize = 94;

  /// Wordmark colours, taken from the printed logo.
  static const Color _mastheadNavy = Color(0xFF16307C);
  static const Color _mastheadRed = Color(0xFFCC1F1F);

  /// Used only when the article carries no colour of its own.
  static const Color _defaultHeadline = Color(0xFF1B5E20);
  static const Color _defaultBody = Color(0xFF1A1A1A);

  /// Metrics-defining body style. Colour is applied per-article at render
  /// time; it's left out here because [_charsFitting] measures against this
  /// style and colour has no effect on layout.
  static const TextStyle _bodyStyle = TextStyle(fontSize: 34, height: 1.6);

  /// The article's own headline colour, as chosen by whoever published it
  /// (`title_color`). The poster has to reproduce it — downloading a story and
  /// getting different colours from the ones on screen makes it look like a
  /// different article.
  Color get _titleColor => colorFromHex(news.titleColor) ?? _defaultHeadline;

  /// `full_text_color` when the poster is printing the full article body,
  /// `content_color` when it's falling back to the summary — matching which
  /// field [_body] actually returned.

  /// The story broken into runs that each carry their own colour.
  ///
  /// The description (`content_color`) and the full article (`full_text_color`)
  /// are separate fields and can be set to different colours. Painting the
  /// joined string in a single colour meant whichever field lost the tie-break
  /// was silently ignored — usually the description, since content wins when
  /// both exist. Runs let each half keep the colour it was published with.
  /// The masthead credit that opens every story, as its own run so it can carry
  /// the paper's accent colour instead of the body colour — it's the paper
  /// speaking, not the article, and it should read that way at a glance.
  ///
  /// The trailing gap is three spaces rather than one. A single space set the
  /// credit flush against the first word, so it looked like part of the opening
  /// sentence; the wider gap separates them the way a printed byline does.
  /// It lives in the run text (not as padding) because the side-by-side layouts
  /// split the story by character index, and only text in a run is counted.
  _BodyRun get _creditRun => _BodyRun('$newsCredit   ', palette.accent);

  List<_BodyRun> get _bodyRuns {
    if (news.translations.isEmpty) return const [];
    final t = news.translations.first;
    final summary = t.shortDescription.trim();
    final content = t.content.trim();

    final summaryColor = colorFromHex(news.descriptionColor) ?? _defaultBody;
    final contentColor = colorFromHex(news.fullTextColor) ?? summaryColor;

    final runs = <_BodyRun>[];
    if (summary.isNotEmpty) {
      runs.add(_creditRun);
      runs.add(_BodyRun(summary, summaryColor));
      if (content.isNotEmpty && content != summary) {
        runs.add(_BodyRun('\n\n$content', contentColor));
      }
    } else if (content.isNotEmpty) {
      runs.add(_creditRun);
      runs.add(_BodyRun(content, contentColor));
    }
    return runs;
  }

  /// Renders the slice `[start, end)` of the story, preserving each run's
  /// colour. The side-by-side layouts split by character index, so the slice
  /// is mapped back onto the runs rather than onto a single flat string.
  /// [textAlign] is a parameter rather than a constant because justification
  /// only works over a wide measure. In the narrow column beside a Left/Right
  /// photo just three or four Telugu words fit per line, so justifying spreads
  /// the leftover width across very few gaps and the words drift apart. Flutter
  /// can't hyphenate Telugu to relieve it, so those slices are set ragged-right
  /// instead; the full-width slices still justify, keeping the printed look.
  Widget _bodySlice(int start, int end, {TextAlign textAlign = TextAlign.justify}) {
    final spans = <TextSpan>[];
    var cursor = 0;

    for (final run in _bodyRuns) {
      final runStart = cursor;
      final runEnd = cursor + run.text.length;
      cursor = runEnd;

      final from = start > runStart ? start : runStart;
      final to = end < runEnd ? end : runEnd;
      if (from >= to) continue;

      spans.add(
        TextSpan(
          text: run.text.substring(from - runStart, to - runStart),
          style: _bodyStyle.copyWith(color: run.color),
        ),
      );
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }

  const NewsPoster({
    super.key,
    required this.news,
    this.imageSpot = PosterImageSpot.top,
    this.palette = PosterPalette.newsprint,
  });

  String get _title =>
      news.translations.isNotEmpty ? news.translations.first.title.trim() : '';

  /// The whole story: `short_description` followed by `content`.
  ///
  /// These are two halves of the article on this backend, not a summary and a
  /// duplicate of it — the detail screen renders both, one after the other.
  /// Using `content` alone (as this did) silently dropped the opening
  /// paragraphs from every downloaded poster.
  ///
  /// They're only joined when they actually differ, because some articles do
  /// mirror the description into `content`, and printing it twice would look
  /// just as broken.
  /// Flat text of the whole story — what the layout measurements work against.
  /// The coloured rendering comes from [_bodyRuns] / [_bodySlice]; this is the
  /// same characters in the same order, so indexes line up between the two.
  String get _body => _bodyRuns.map((r) => r.text).join();

  String? get _imageUrl {
    for (final m in news.media) {
      if (m.type == 'image') return m.fileUrl;
    }
    return null;
  }

  /// Dateline: the full place the article was posted to, as deep as the
  /// tagging allows — `Telangana › Hyderabad › Amberpet`.
  ///
  /// Walks state → district → mandal and stops at the first level with more
  /// than one option, because past that point there is no single honest
  /// answer. A story tagged to all 33 districts of Telangana prints
  /// "Telangana"; one tagged to a single mandal prints the whole path.
  ///
  /// Naming the first entry of a multi-entry level would be a fabrication —
  /// article 1528, a Kistareddypet story published state-wide, came out
  /// captioned "Ameenpur" purely because that was index 0.
  /// Dateline: the place the story came from, most specific first.
  ///
  /// Never a count. "33 districts" described where the article was *published
  /// to*, which is not a dateline — a reporter files from one place and an
  /// editor may push it state-wide. So this only names a location when the
  /// tagging pins one down:
  ///
  ///   * one mandal      → `District › Mandal`
  ///   * one district    → `State › District`
  ///   * anything wider  → the state alone
  ///
  /// For a broad publish there is genuinely nothing here to identify the
  /// reporter's own area — `/news` sends `author` as name, photo and role
  /// only, with no location. Showing the state is the most specific honest
  /// answer until the backend adds the author's district/mandal.
  String get _location {
    // Preferred source: the reporter's own district/mandal. This is the true
    // dateline and is right even when an editor pushed the story state-wide.
    // Arrives only once the backend adds them to the `author` object.
    final filedDistrict = news.authorDistrictName;
    final filedMandal = news.authorMandalName;
    if (filedDistrict != null || filedMandal != null) {
      return [filedDistrict, filedMandal].whereType<String>().join(' › ');
    }

    final states = news.stateLocations;
    final districts = news.districtLocations;
    final mandals = news.mandalLocations;

    if (mandals.length == 1) {
      return districts.length == 1
          ? '${districts.first.value} › ${mandals.first.value}'
          : mandals.first.value;
    }

    if (districts.length == 1) {
      return states.length == 1
          ? '${states.first.value} › ${districts.first.value}'
          : districts.first.value;
    }

    return states.length == 1 ? states.first.value : '';
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageUrl;

    // Always laid out at the true design width; the preview screen scales it
    // down for display with a FittedBox placed outside the RepaintBoundary,
    // so the captured PNG keeps full resolution.
    // Ignore the device's font-scale setting for the whole poster. Two reasons:
    // the output is a fixed 1080px design that must come out identical on every
    // phone, and the TextPainter measurements used for the masthead rule and
    // the story column both assume 1.0 — with scaling on, real text renders
    // wider than measured and wraps out of its box.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: posterWidth,
        child: Container(
          color: palette.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMasthead(),
              _buildDateStrip(),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 34, 40, 34),
                child: Container(
                  // Thin rule around the clipping, the way a cut-out article
                  // sits inside its column borders on a printed page.
                  decoration: BoxDecoration(
                    color: palette.panel,
                    border: Border.all(color: palette.border),
                  ),
                  padding: const EdgeInsets.fromLTRB(32, 46, 32, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        // Telugu stacks vowel marks well above and below the
                        // baseline; at 1.35 line height the tall mātras on the
                        // first line were being clipped. 1.55 gives them room,
                        // and the smaller size keeps a long headline from
                        // dominating the clipping.
                        style: TextStyle(
                          fontSize: 46,
                          height: 1.55,
                          fontWeight: FontWeight.w800,
                          color: _titleColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(height: 2, color: palette.border),
                      const SizedBox(height: 28),
                      ..._buildStory(image),
                      const SizedBox(height: 28),
                      if ((news.authorName ?? '').isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '— ${news.authorName}'
                            '${(news.authorRoleName ?? '').isNotEmpty ? ', ${news.authorRoleName}' : ''}',
                            // Follows the chosen scheme so the byline reads
                            // as part of the paper rather than a fixed brown.
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _buildAdStrip(),
              _buildFooterStrip(),
            ],
          ),
        ),
      ),
    );
  }

  /// Sponsor creatives printed above the footer.
  ///
  /// Kept outside the clipping panel on purpose: inside it, an advert would
  /// read as part of the article. Out here, under its own rule and label, it
  /// sits where a printed paper puts a strip ad — clearly bought space.
  ///
  /// Only image ads are printed. The poster is rasterised to a still PNG, so a
  /// video creative has no frame to show; it's skipped rather than drawn as a
  /// black box. A story whose ads are all video prints exactly as before.
  Widget _buildAdStrip() {
    final printable = news.ads.where((ad) => !ad.isVideo).toList();
    if (printable.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: palette.page,
      // The clipping above already leaves 34 below itself, so this only needs
      // its own bottom gap before the footer rule.
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 2, color: palette.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'ప్రకటన  ·  ADVERTISEMENT',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: palette.accent,
                  ),
                ),
              ),
              Expanded(child: Container(height: 2, color: palette.border)),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < printable.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              // Capped so a tall creative can't out-run the story it's
              // attached to, but free to keep its own aspect ratio.
              child: AdaptiveCachedImage(
                imageUrl: printable[i].url,
                maxHeight: 520,
                backgroundColor: const Color(0xFFEEEEEE),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Typeset masthead, laid out to match the printed banner: **డీప్** in navy,
  /// the app mark dead centre, **పల్స్** in red, each word underscored by a
  /// rule its own width with the tagline centred beneath.
  ///
  /// Built from text rather than artwork on purpose: an image would bake in
  /// whatever date and editor were printed on it, couldn't re-colour with the
  /// chosen palette, and would soften at capture resolution.
  ///
  /// The wordmark colours are fixed rather than palette-driven — a masthead is
  /// the brand, so it shouldn't turn green when someone picks Mint paper.
  Widget _buildMasthead() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(40, 22, 40, 24),
      // Equal Expanded halves put the mark on the poster's exact centre line.
      // Centring the Row instead only looks centred when both words happen to
      // be the same width, and "పల్స్" is wider than "డీప్".
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FittedBox guards the layout: if the wordmark is ever sized larger
          // than half the poster, it scales down instead of overflowing.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _mastheadHalf(
                  word: "డీప్",
                  tagline: "లోతైన అన్వేషణ...",
                  color: _mastheadNavy,
                ),
              ),
            ),
          ),
          const SizedBox(width: _mastheadLogoGap),
          // Nudged down so the mark's centre lines up with the word rather
          // than with the word-plus-tagline block.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppLogo(size: _mastheadLogoSize, borderRadius: 26),
          ),
          const SizedBox(width: _mastheadLogoGap),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _mastheadHalf(
                  word: "పల్స్",
                  tagline: "విశ్వసనీయ సమాచారం",
                  color: _mastheadRed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One side of the masthead: word, a rule exactly as wide as it, and the
  /// tagline centred under both.
  ///
  /// `CrossAxisAlignment.stretch` inside a min-width Column is what sizes the
  /// rule to the text. Laying the rules out in a separate full-width Row (the
  /// previous approach) made them span the whole half, far wider than the
  /// words they belong to.
  Widget _mastheadHalf({
    required String word,
    required String tagline,
    required Color color,
  }) {
    final wordStyle = TextStyle(
      fontSize: _mastheadWordSize,
      // Telugu hangs vottulu (ప్, స్) below the baseline and mātras above it.
      // At 1.05 the line box was tighter than the glyphs, so the wordmark was
      // being clipped top and bottom.
      height: 1.3,
      fontWeight: FontWeight.w900,
      color: color,
      // Faint drop shadow standing in for the printed logo's 3-D bevel.
      shadows: const [
        Shadow(offset: Offset(2, 3), blurRadius: 2, color: Color(0x33000000)),
      ],
    );

    // The block is pinned to the WORD's measured width. Letting the Column
    // size itself instead made the tagline the widest child — "విశ్వసనీయ
    // సమాచారం" is longer than "పల్స్" — so the rule stretched to the tagline
    // and the word floated in the middle of it, away from the logo.
    final wordWidth = _textWidth(word, wordStyle);

    return SizedBox(
      width: wordWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            word,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            style: wordStyle,
          ),
          const SizedBox(height: 4),
          Container(height: 4, color: color),
          const SizedBox(height: 8),
          // Shrinks to the word's width when the tagline is longer, which is
          // how it reads on the printed banner.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tagline,
              style: const TextStyle(
                fontSize: 30,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _textWidth(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  /// Dateline bar under the masthead — the e-paper URL, the article's date and
  /// the place it's from, mirroring a printed edition's strip.
  Widget _buildDateStrip() {
    final location = _location;
    return Container(
      color: palette.accent,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      // Stack, not a Row: the date is centred on the strip itself rather than
      // in whatever space is left over after the URL. In a Row its position
      // would shift with the length of the URL and the dateline.
      // Three independent slots — URL left, date centred, place right. A Stack
      // rather than a Row so the date is centred on the strip itself and
      // doesn't shift as the URL or the place name change length.
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(epaperUrl, style: _stripTextStyle),
          ),
          // scaleDown rather than ellipsis: long text shrinks slightly instead
          // of being cut off mid-word.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formattedDate,
              maxLines: 1,
              softWrap: false,
              style: _stripTextStyle,
            ),
          ),
          if (location.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  location,
                  maxLines: 1,
                  softWrap: false,
                  style: _stripTextStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterStrip() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 3, color: palette.accent),
        Container(
          width: double.infinity,
          color: palette.footer,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          child: Column(
            children: [
              Text(
                '$epaperUrl   |   $_formattedDate   |   News ID: ${news.id}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: palette.footerText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'For more details, visit $epaperUrl',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, color: palette.footerText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _formattedDate {
    final d = news.displayTime.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// Headline-to-byline body of the poster, laid out per [imageSpot].
  ///
  /// For the side layouts this reproduces the newspaper look: a narrow column
  /// of text running alongside the photo, then the rest of the story
  /// continuing full width underneath. Flutter has no float/wrap-around
  /// primitive, so the break point is measured with a [TextPainter] — see
  /// [_charsFitting].
  List<Widget> _buildStory(String? image) {
    final body = _body;

    if (image == null || imageSpot == PosterImageSpot.top) {
      return [
        if (image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // Full-width photo keeps its own aspect ratio — news photos come
            // in portrait and landscape and a fixed box would crop the subject.
            child: AdaptiveCachedImage(
              imageUrl: image,
              maxHeight: 900,
              backgroundColor: const Color(0xFFEEEEEE),
            ),
          ),
          const SizedBox(height: 32),
        ],
        _bodySlice(0, body.length),
      ];
    }

    // Widths are measured from the actual space the panel gives us, not from a
    // constant. Hard-coding them against the old padding is what made the Row
    // overflow once the clipping panel added its own inset — and an overflowing
    // Row clips its children, which is why the story looked truncated.
    return [
      LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          final imageWidth = (available * _insetImageFraction).floorToDouble();
          final textWidth = available - imageWidth - _insetGap;
          final imageHeight = (imageWidth * 1.2).floorToDouble();

          final splitAt = _charsFitting(body, textWidth, imageHeight);
          // Skip the whitespace at the break so the lower block does not open
          // with a stray space or blank line. Working in indexes rather than
          // trimmed substrings keeps the slice aligned with the colour runs.
          var belowStart = splitAt;
          while (belowStart < body.length && body[belowStart].trim().isEmpty) {
            belowStart++;
          }

          final photo = ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: CachedImageWidget(imageUrl: image, fit: BoxFit.cover),
            ),
          );

          final column = SizedBox(
            width: textWidth,
            child: _bodySlice(0, splitAt, textAlign: TextAlign.start),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: imageSpot == PosterImageSpot.left
                    ? [photo, const SizedBox(width: _insetGap), column]
                    : [column, const SizedBox(width: _insetGap), photo],
              ),
              if (belowStart < body.length) ...[
                const SizedBox(height: 18),
                _bodySlice(belowStart, body.length),
              ],
            ],
          );
        },
      ),
    ];
  }

  /// How much of [text] fits in a [width] × [height] box, rounded back to a
  /// word boundary so the column never breaks mid-word.
  ///
  /// Deterministic: the poster is always laid out at [posterWidth] with fixed
  /// type sizes, so this measures the same on every device.
  int _charsFitting(String text, double width, double height) {
    if (text.isEmpty) return 0;

    final painter = TextPainter(
      text: TextSpan(text: text, style: _bodyStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    )..layout(maxWidth: width);

    // Short story — all of it sits beside the photo, nothing spills below.
    if (painter.height <= height) return text.length;

    final cut = painter
        .getPositionForOffset(Offset(width, height))
        .offset
        .clamp(0, text.length);

    final wordBreak = text.lastIndexOf(RegExp(r'\s'), cut);
    return wordBreak > 0 ? wordBreak : cut;
  }
}
