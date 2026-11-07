import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:video_compress/video_compress.dart';

import '../../core/utils/color_utils.dart';
import '../../data/models/news.dart';
import '../../data/models/news_ad.dart';
import '../../shared/widgets/app_wordmark.dart';
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

  /// Where the story starts on the page currently in the boundary.
  ///
  /// The PDF export walks this forward and captures a page each time. The pages
  /// are rendered in the boundary the preview already uses rather than off
  /// screen, because a boundary that never paints hands back a blank image —
  /// the same reason the preview is shown full size in the first place. The
  /// spinner covers the flicker.
  int _exportStoryStart = 0;
  bool _exporting = false;

  /// Where the page in the boundary ran out of story, and whether that was the
  /// whole of it — both reported back by the poster after it lays out.
  int? _lastPageEnd;
  bool _lastPageComplete = false;

  @override
  void dispose() {
    _evictPrintDecodes();
    super.dispose();
  }

  /// Drops this poster's print-resolution images from Flutter's image cache on
  /// the way out.
  ///
  /// The rest of the app decodes at 1080; the poster asks for 2560 so the saved
  /// PNG isn't soft. Those decodes are several times the size of the screen
  /// ones, and without this they sit in the cache — evicting the feed's own
  /// images to make room — long after this screen is gone. Only these exact
  /// entries are evicted, so nothing else has to re-download.
  void _evictPrintDecodes() {
    final urls = <String>[
      for (final m in widget.news.media)
        if (m.type == 'image') m.fileUrl,
      for (final ad in widget.news.ads)
        if (!ad.isVideo) ad.url,
    ];

    for (final url in urls) {
      CachedNetworkImageProvider(
        url,
        maxWidth: NewsPoster._printDecodeWidth,
      ).evict();
    }
  }

  /// Rasterises the poster at the highest resolution the poster's own size
  /// allows.
  ///
  /// This used to be a flat 2×. That is fine for a short piece but it is the
  /// wrong knob to fix: a long article makes the poster taller, not wider, so
  /// at a flat multiplier the text stays the same pixel size while the file
  /// grows — and once the bitmap passes what the GPU will hand back in one
  /// texture, the whole thing comes back softened. Which is exactly the "long
  /// news is blurry" case.
  ///
  /// So: aim for 3×, then back off only as far as the limits actually require.
  /// A short poster now captures 50% sharper than before, and a long one lands
  /// just under the ceiling instead of over it.
  Future<double> _captureScale(Size size) async {
    // Widely safe single-texture bound. Plenty of Android GPUs stop at 8192,
    // and the failure is silent — a downscaled or blank image, never an error.
    const maxSide = 8192.0;
    // ~50M pixels ≈ 200 MB for the intermediate RGBA buffer. Past this, mid-
    // range phones start failing the allocation outright.
    const maxPixels = 50000000.0;

    // Aim high. A short poster can take 4× — a 4320px-wide page, which stays
    // crisp however far it's zoomed — and the guards below pull it back only
    // as far as a long one actually needs.
    var scale = 4.0;
    scale = math.min(scale, maxSide / size.width);
    scale = math.min(scale, maxSide / size.height);
    scale = math.min(scale, math.sqrt(maxPixels / (size.width * size.height)));
    // Never go under 1.5 — below that the text is unreadable zoomed in, and a
    // poster too big even for that needs its layout fixed, not its capture.
    return scale.clamp(1.5, 4.0);
  }

  /// Capture scale for a PDF page.
  ///
  /// 2.5x of the 1080pt design is 2700px across an A4-width page — about 325
  /// DPI, past what any printer resolves and far past any screen. The 4x the
  /// PNG path aims for would quadruple the bytes for nothing, and a PDF of a
  /// long story is several of these.
  static const double _pdfCaptureScale = 2.5;

  Future<Uint8List?> _capture({double? scaleOverride}) async {
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

    final scale = scaleOverride ?? await _captureScale(boundary.size);
    final image = await boundary.toImage(pixelRatio: scale);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      debugPrint(
        '[NewsPoster] captured ${image.width}x${image.height} '
        'at ${scale.toStringAsFixed(2)}× '
        '(poster ${boundary.size.width.toInt()}x${boundary.size.height.toInt()}), '
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

  /// Exports the poster as a one-page PDF and hands it to the share sheet.
  ///
  /// Worth having alongside the PNG for two reasons. A PDF opens at whatever
  /// zoom the reader wants without the viewer resampling it, and — the reason
  /// it matters here — chat apps send a PDF as a document, untouched. WhatsApp
  /// caps an *image* at about 1600px on its long side, which on a page this
  /// shape left the poster 512px wide and turned the Telugu to mush; the same
  /// page as a PDF arrives exactly as it left.
  ///
  /// The page carries the captured bitmap rather than re-typeset text, so what
  /// you get is precisely the poster on screen — one layout, not two that can
  /// drift apart.
  /// Renders and captures the whole story, one page at a time.
  ///
  /// The screen shows page one and stops — a fixed page has to. The PDF is the
  /// version that carries the article in full, so this walks the story forward:
  /// render from where the last page ended, let it lay out, capture, repeat.
  ///
  /// Stops when the story runs out, and also when a page reports no progress,
  /// which would otherwise loop for ever on text that cannot fit at any size.
  Future<List<Uint8List>> _captureAllPages() async {
    const maxPages = 20;
    final pages = <Uint8List>[];

    _exporting = true;
    _exportStoryStart = 0;
    try {
      for (var page = 0; page < maxPages; page++) {
        _lastPageEnd = null;
        _lastPageComplete = false;
        setState(() {}); // put this page in the boundary
        // Two frames: one to lay the page out and fire onStoryEnd, one to be
        // sure it has painted before the boundary is read.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) break;
        await WidgetsBinding.instance.endOfFrame;

        final bytes = await _capture(scaleOverride: _pdfCaptureScale);
        if (bytes == null) break;
        pages.add(bytes);

        final end = _lastPageEnd;
        if (end == null || _lastPageComplete || end <= _exportStoryStart) break;
        _exportStoryStart = end;
      }
      debugPrint(
        '[NewsPoster] pdf export: ${pages.length} page(s), '
        'last end=$_lastPageEnd complete=$_lastPageComplete',
      );
    } finally {
      _exporting = false;
      _exportStoryStart = 0;
      if (mounted) setState(() {});
      // Let the preview come back before the share sheet covers it.
      await WidgetsBinding.instance.endOfFrame;
    }
    return pages;
  }

  Future<void> _exportPdf() async {
    setState(() => _isWorking = true);
    try {
      // Page shaped exactly like the poster, so nothing is letterboxed or
      // cropped. A4 width keeps it a sensible size if anyone prints it.
      final format = PdfPageFormat(
        PdfPageFormat.a4.width,
        PdfPageFormat.a4.width *
            NewsPoster.posterHeight /
            NewsPoster.posterWidth,
      );

      final doc = pw.Document();
      final pages = await _captureAllPages();
      if (pages.isEmpty) throw Exception('Could not render the poster');
      for (final png in pages) {
        final image = pw.MemoryImage(png);
        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
          ),
        );
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_fileName.pdf');
      await file.writeAsBytes(await doc.save());

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
      );
    } catch (e, st) {
      debugPrint('[NewsPoster] pdf export failed: $e\n$st');
      if (!mounted) return;
      _toast('Could not make the PDF: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Asks which format, then runs it. Two formats with genuinely different
  /// uses, so the choice is spelled out rather than left to an icon.
  Future<String?> _askFormat({required String imageSubtitle}) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Image (PNG)'),
              subtitle: Text(imageSubtitle),
              onTap: () => Navigator.pop(ctx, 'png'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text(
                'Best quality — stays sharp when shared on WhatsApp',
              ),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseDownloadFormat() async {
    final choice = await _askFormat(imageSubtitle: 'Saves to your gallery');
    if (choice == null || !mounted) return;
    if (choice == 'pdf') {
      await _exportPdf();
    } else {
      await _download();
    }
  }

  /// Share asks the same question. Sharing the page as an image is what gets it
  /// recompressed on the way — offering the PDF here is the whole point, since
  /// a chat app passes a document through untouched.
  Future<void> _chooseShareFormat() async {
    final choice = await _askFormat(imageSubtitle: 'Chat apps may compress it');
    if (choice == null || !mounted) return;
    if (choice == 'pdf') {
      await _exportPdf();
    } else {
      await _share();
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
                    storyStart: _exporting ? _exportStoryStart : 0,
                    // Only the PDF walks past page one, and its pages are
                    // continued rather than cut short.
                    showContinuedTail: !_exporting,
                    onStoryEnd: _exporting
                        ? (end, isComplete) {
                            _lastPageEnd = end;
                            _lastPageComplete = isComplete;
                          }
                        : null,
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
                  onPressed: _isWorking ? null : _chooseShareFormat,
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
                  onPressed: _isWorking ? null : _chooseDownloadFormat,
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

  /// Character offset into the story this page starts at. Non-zero makes this a
  /// continuation page: no photo, no advert band, and a headline set small
  /// under a "continued" rule, the way a paper carries a story over.
  ///
  /// The screen only ever shows page one. The PDF export walks this forward to
  /// print the whole article — which is the point of the PDF, since a single
  /// page has to cut a long story short.
  final int storyStart;

  /// Reports where this page's text ran out — an absolute offset into the
  /// story — and whether that was the end of it.
  ///
  /// `isComplete` comes from the poster because only the poster knows how it
  /// joins the story together. The screen used to work that out a second time
  /// from the same fields, and a formula kept in two places is a formula that
  /// will disagree with itself: if its total came out short, the very first
  /// page looked like the last one and the PDF stopped at one page.
  final void Function(int end, bool isComplete)? onStoryEnd;

  /// Whether a story too long for the page ends on the "read it in the app"
  /// line. True on screen, where there is no next page; false for every PDF
  /// page that is about to be continued on the next one.
  final bool showContinuedTail;

  static const double posterWidth = 1080;

  /// Page height: 2:3, a printed page rather than a scroll.
  ///
  /// This is the whole reason the poster is shaped this way. WhatsApp shrinks
  /// every image it sends to about 1600px on the long side. The old poster grew
  /// with the story, ran 6–7000px tall, and came out of WhatsApp 512px wide
  /// with the text turned to mush — every "it's blurry" report traced back to
  /// that one resize, never to the capture. A 1080×1620 page loses almost
  /// nothing to it (1067 wide), which is also why the mandal papers this is
  /// modelled on are all this shape.
  static const double posterHeight = 1620;

  /// Height of the advert band along the bottom of the clipping.
  static const double _adBandHeight = 200;

  /// Body sizes tried in order when fitting the story to the page; the first
  /// that holds the whole story wins. A short piece sets large the way a lead
  /// story does, a long one steps down, and past the last size the story is
  /// cut with a pointer to the app.
  static const List<double> _bodySizes = [40, 38, 36, 34, 32, 30, 28, 26, 24];

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
  static TextStyle get _stripTextStyle =>
      display(fontSize: 26, color: Colors.white);

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

  /// Width, in pixels, to decode the poster's photographs and ad creatives at.
  ///
  /// The image widgets default to 1080 — right for a phone screen, and what the
  /// poster was silently inheriting. But the poster isn't looked at on screen,
  /// it's rasterised at up to 3×, so a 1080px decode was being enlarged
  /// threefold into the saved PNG. The text was sharp and the pictures were
  /// mush, which is what a zoom into the downloaded page showed.
  ///
  /// 3200 covers the widest a creative gets on the page (about 936pt at the 4×
  /// the capture now aims for) without decoding a huge original at full size —
  /// three of these are live at once on a poster carrying a photo and two ads,
  /// and they sit in memory alongside the capture buffer.
  static const int _printDecodeWidth = 3200;

  /// The poster's text face: **Mandali**.
  ///
  /// The app itself is set in Roboto, which carries no Telugu at all — every
  /// Telugu glyph on the poster was coming from whatever the phone happened to
  /// fall back to, so the printed page had no typeface of its own and could
  /// look different on two handsets.
  ///
  /// Mandali is the face Telugu mandal papers actually set their columns in:
  /// an even, slightly condensed sans that stays legible through the vowel
  /// marks stacking above and below the line, and holds up at the size a full
  /// story has to be squeezed to. A serif was the wrong instinct here — Telugu
  /// newsprint is set in sans, and this is modelled on the real thing.
  ///
  /// It carries Latin too, so the English footer lines don't switch face
  /// mid-page.
  static TextStyle body({
    required double fontSize,
    FontWeight? fontWeight,
    double? height,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.mandali(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// The poster's display face: **Ramabhadra**, for the headline only.
  ///
  /// Drawn as a heavy Telugu display face, which is what gives a mandal paper's
  /// headline its weight. Mandali bolded can't do this — it has one weight, and
  /// a synthesised bold on Telugu smears the conjuncts. Two families, each
  /// doing the job it was cut for, is how the printed pages do it as well.
  static TextStyle display({
    required double fontSize,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.ramabhadra(
      fontSize: fontSize,
      height: height,
      color: color,
    );
  }

  /// The body style at a given size — the one style used both to paint the
  /// story and to measure it. [_charsFitting] breaks the text around the photo
  /// and against the bottom of the page using exactly this, and a mismatch
  /// there would cut at the wrong word. Colour is applied per run at render
  /// time; it has no effect on layout.
  static TextStyle bodyAt(double size) => body(fontSize: size, height: 1.5);

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

  /// The article's adverts in slot order, so the band always reads ad 1 then
  /// ad 2 whatever order the payload arrived in.
  List<NewsAd> get _adsBySlot =>
      [...news.ads]..sort((a, b) => a.slot.compareTo(b.slot));

  /// Renders the slice `[start, end)` of the story, preserving each run's
  /// colour. The layouts split by character index, so the slice is mapped back
  /// onto the runs rather than onto a single flat string. [tail] is appended
  /// after the slice in the paper's accent — the "continued in the app" line a
  /// story too long for the page ends on.
  ///
  /// Set ragged-right, not justified. Justifying looked more like newsprint,
  /// but Flutter can't hyphenate Telugu: a line holding a few long words has
  /// nowhere to absorb the leftover measure except the word gaps, so it opens
  /// them up — the uneven spacing that shows on some lines and not others, and
  /// the rivers of white it leaves down a paragraph. Ragged-right keeps every
  /// word gap identical, which is how Telugu is normally set digitally anyway.
  Widget _bodySlice(
    int start,
    int end, {
    required TextStyle style,
    String? tail,
    TextAlign textAlign = TextAlign.start,
  }) {
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
          style: style.copyWith(color: run.color),
        ),
      );
    }

    if (tail != null) {
      spans.add(
        TextSpan(
          text: tail,
          style: style.copyWith(color: palette.accent),
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
    this.storyStart = 0,
    this.onStoryEnd,
    this.showContinuedTail = true,
  });

  bool get _isContinuation => storyStart > 0;

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
    // Adverts run on page one only. Repeating the band on every carried-over
    // page would sell the same booking three times and push the story it is
    // meant to sit beside onto yet another page.
    final ads = _isContinuation ? const <NewsAd>[] : _adsBySlot;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: posterWidth,
        height: posterHeight,
        child: Container(
          color: palette.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The banner runs once, on page one. A carried-over page keeps
              // only the thin dateline strip as a running head — that is what a
              // paper does, and it hands the ~330px the masthead would have
              // taken back to the story, so the article needs fewer pages.
              if (!_isContinuation) _buildMasthead(),
              _buildDateStrip(),
              // The clipping takes whatever the fixed page leaves after the
              // masthead, dateline and footer — and the story, in turn, takes
              // whatever the clipping leaves after the headline, byline and
              // advert band. Fixed outside-in, so the text is the one thing
              // that flexes.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 22, 40, 22),
                  child: Container(
                    // Thin rule around the clipping, the way a cut-out article
                    // sits inside its column borders on a printed page.
                    decoration: BoxDecoration(
                      color: palette.panel,
                      border: Border.all(color: palette.border),
                    ),
                    padding: const EdgeInsets.fromLTRB(32, 26, 32, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A carried-over page sets the headline small and
                        // marks it continued, the way a paper does — the full
                        // headline belongs to page one, and repeating it at
                        // full size would eat the space the rest of the story
                        // needs.
                        Text(
                          _isContinuation ? '$_title  (Continue)' : _title,
                          textAlign: TextAlign.center,
                          // Two lines at most on a fixed page. Telugu stacks
                          // vowel marks well above and below the baseline; 1.55
                          // gives the tall mātras room instead of clipping them.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: display(
                            fontSize: _isContinuation ? 30 : 46,
                            height: 1.55,
                            color: _titleColor,
                          ),
                        ),
                        SizedBox(height: _isContinuation ? 12 : 18),
                        Container(height: 2, color: palette.border),
                        SizedBox(height: _isContinuation ? 16 : 22),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _buildStoryFitted(constraints, image),
                          ),
                        ),
                        if (!_isContinuation &&
                            (news.authorName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '— ${news.authorName}'
                              '${(news.authorRoleName ?? '').isNotEmpty ? ', ${news.authorRoleName}' : ''}',
                              // Follows the chosen scheme so the byline reads
                              // as part of the paper rather than a fixed brown.
                              style: display(
                                fontSize: 30,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ],
                        if (ads.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(height: 2, color: palette.border),
                          const SizedBox(height: 12),
                          _buildAdBand(ads),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _buildFooterStrip(),
            ],
          ),
        ),
      ),
    );
  }

  /// The advert band along the bottom of the clipping — where the mandal papers
  /// this is modelled on put theirs.
  ///
  /// One creative takes the full width; two sit side by side. The fixed height
  /// is what makes the rest of the page predictable: the story gets whatever is
  /// left once this band has taken its share, so the text can be fitted
  /// against a known number.
  ///
  /// Both slots print here, whatever their place in the app (ad 1 after the
  /// description, ad 2 at the end). On a fixed page an advert breaking the
  /// text costs lines of the story the reader came for; the band gives both
  /// bookings the same exposure without taking any of them.
  ///
  /// Video creatives print too, as a still frame under a play badge — a poster
  /// can't play video, but a booking that simply vanished from the paper was
  /// worse than one that says what it is. See [_PosterVideoAd].
  Widget _buildAdBand(List<NewsAd> ads) {
    return SizedBox(
      height: _adBandHeight,
      child: Row(
        children: [
          for (var i = 0; i < ads.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: _buildAdTile(ads[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildAdTile(NewsAd ad) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ad.isVideo
          ? _PosterVideoAd(videoUrl: ad.url)
          : Container(
              // The clipping's own paper behind a contained creative, so its
              // letterbox reads as the page rather than a slab around it.
              color: palette.panel,
              child: CachedImageWidget(
                imageUrl: ad.url,
                // Contained, never cropped: an advert is laid out by whoever
                // booked it, and a cut-off phone number is a wasted booking.
                fit: BoxFit.contain,
                decodeWidth: _printDecodeWidth,
              ),
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
      // The supplied wordmark now stands in for the typeset masthead, so the
      // poster and the app show the same brand.
      child: const Center(child: AppWordmark(height: 200, borderRadius: 18)),

      // The Telugu typeset masthead it replaced — డీప్ in navy, the app mark
      // centred, పల్స్ in red, each word underscored with its tagline beneath.
      // Kept here rather than deleted so it can be restored if the printed
      // edition wants the set version back.
      //
      // child: Row(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: [
      //     Expanded(
      //       child: Align(
      //         alignment: Alignment.centerRight,
      //         child: FittedBox(
      //           fit: BoxFit.scaleDown,
      //           alignment: Alignment.centerRight,
      //           child: _mastheadHalf(
      //             word: "డీప్",
      //             tagline: "లోతైన అన్వేషణ...",
      //             color: _mastheadNavy,
      //           ),
      //         ),
      //       ),
      //     ),
      //     const SizedBox(width: _mastheadLogoGap),
      //     Padding(
      //       padding: const EdgeInsets.only(top: 8),
      //       child: AppLogo(size: _mastheadLogoSize, borderRadius: 26),
      //     ),
      //     const SizedBox(width: _mastheadLogoGap),
      //     Expanded(
      //       child: Align(
      //         alignment: Alignment.centerLeft,
      //         child: FittedBox(
      //           fit: BoxFit.scaleDown,
      //           alignment: Alignment.centerLeft,
      //           child: _mastheadHalf(
      //             word: "పల్స్",
      //             tagline: "విశ్వసనీయ సమాచారం",
      //             color: _mastheadRed,
      //           ),
      //         ),
      //       ),
      //     ),
      //   ],
      // ),
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
          Align(
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
                style: display(fontSize: 24, color: palette.footerText),
              ),
              const SizedBox(height: 4),
              Text(
                'For more details, visit $epaperUrl',
                textAlign: TextAlign.center,
                style: body(fontSize: 22, color: palette.footerText),
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

  /// The line a story too long for the page ends on.
  static const String _continuedTail =
      ' … పూర్తి వార్త డీప్ పల్స్ యాప్‌లో చదవండి';

  /// Photo and story, fitted into the exact box the page leaves them.
  ///
  /// Everything else on the page is a known size, so this is handed the space
  /// that remains and lays out within it — never past it. For the side layouts
  /// that reproduces the newspaper look: a column of text beside the photo,
  /// then the rest continuing full width underneath. Flutter has no
  /// float/wrap-around primitive, so every break is measured with a
  /// [TextPainter] — see [_fitStory].
  Widget _buildStoryFitted(BoxConstraints constraints, String? image) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    // This page shows the story from its own offset onward. Everything below
    // works in indexes relative to that; [_slicesFor] adds the offset back so
    // the colour runs still line up with the right characters.
    final body = _body.substring(math.min(storyStart, _body.length));

    // The photo ran on page one; a carried-over page is all text.
    if (_isContinuation) image = null;

    if (image == null || imageSpot == PosterImageSpot.top) {
      // Photo across the top, capped so the text keeps the larger share of the
      // page. Cover, in a fixed box: a page needs the photo's height known
      // before it loads, and a fixed 16:9-ish window is what a printed paper
      // does with a photo anyway.
      // A height budget, because the photo is drawn with `contain`: whenever
      // the cap is lower than the photo's natural height at full width, the
      // width shrinks to match and the picture ends up stranded mid-page with
      // margins either side. That is what made it look small.
      //
      // On this 2:3 page, 0.55 of the height is 0.825 of the width, which
      // clears the natural height of anything 4:3 or wider — so ordinary
      // landscape photos now run the full width, uncropped. Squarer and
      // portrait shots still hit the cap, but at a far larger size than the
      // old 34% allowed.
      //
      // The trade is real — every pixel here is a pixel the story gives up —
      // but a photo too small to read is worth less than the line of text it
      // was protecting.
      final photoH = image == null ? 0.0 : (h * 0.55).floorToDouble();
      final gap = image == null ? 0.0 : 22.0;
      final fit = _fitStory(body, [_Region(w, h - photoH - gap)]);

      return _clipToBox(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // Full-width block, uncropped photo. BoxFit.cover filled the
                // slot but cut whatever didn't match its ratio; plain contain
                // kept the photo whole but left flat bars beside a portrait.
                // blurredBackground gives both — the photo is contained, and
                // the leftover margin is filled with a blurred, zoomed copy of
                // itself, so the band still reads edge to edge.
                child: SizedBox(
                  width: double.infinity,
                  child: AdaptiveCachedImage(
                    imageUrl: image,
                    // Caps at the height the text layout reserved, so the story
                    // below still gets the space it was measured against.
                    maxHeight: photoH,
                    // Any leftover margin is filled with the page colour rather
                    // than the blurred-copy backdrop the feed uses: on screen
                    // that backdrop reads as depth, but on a light printed page
                    // it came out as a heavy dark frame around the picture.
                    backgroundColor: palette.panel,
                    fit: BoxFit.contain,
                    decodeWidth: _printDecodeWidth,
                  ),
                ),
              ),
              SizedBox(height: gap),
            ],
            ..._slicesFor(fit),
          ],
        ),
      );
    }

    // Side layouts: a column beside the photo, then full width below it.
    final imageW = (w * _insetImageFraction).floorToDouble();
    final textW = w - imageW - _insetGap;
    // 4:3, not the 1.2 portrait this used to reserve. News photos are almost
    // always landscape, so a portrait slot letterboxed nearly every one of them
    // — and with the blurred fill behind, that showed as a thick dark frame
    // around a small picture. A landscape slot is close to the shape the photo
    // actually is, so it very nearly fills it and the fill barely shows.
    final imageH = math.min((imageW * 0.75).floorToDouble(), h);
    const belowGap = 18.0;
    final fit = _fitStory(body, [
      _Region(textW, imageH),
      _Region(w, h - imageH - belowGap),
    ]);
    final slices = _slicesFor(fit);

    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      // Contained over a blurred copy of itself — see the note on the
      // top-layout photo above.
      child: SizedBox(
        width: imageW,
        child: AdaptiveCachedImage(
          imageUrl: image,
          maxHeight: imageH,
          backgroundColor: palette.panel,
          fit: BoxFit.contain,
          decodeWidth: _printDecodeWidth,
        ),
      ),
    );
    final column = SizedBox(width: textW, child: slices[0]);

    return _clipToBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: imageSpot == PosterImageSpot.left
                ? [photo, const SizedBox(width: _insetGap), column]
                : [column, const SizedBox(width: _insetGap), photo],
          ),
          if (slices.length > 1) ...[
            const SizedBox(height: belowGap),
            slices[1],
          ],
        ],
      ),
    );
  }

  /// One rendered slice per region of [fit] that holds any text, with the
  /// continuation tail — if there is one — on the last of them.
  ///
  /// Also the single place that reports how far this page got, so the exporter
  /// knows where the next one begins. Sent after the frame: a callback fired
  /// mid-build would be rebuilding the tree while it is being built.
  List<Widget> _slicesFor(_StoryFit fit) {
    if (onStoryEnd != null) {
      final total = _body.length;
      final end = math.min(storyStart + fit.ends.last, total);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onStoryEnd!(end, end >= total),
      );
    }
    final slices = <Widget>[];
    var lastFilled = -1;
    for (var i = 0; i < fit.ends.length; i++) {
      if (fit.ends[i] > fit.starts[i]) lastFilled = i;
    }
    for (var i = 0; i <= lastFilled; i++) {
      slices.add(
        _bodySlice(
          storyStart + fit.starts[i],
          storyStart + fit.ends[i],
          style: fit.style,
          tail: i == lastFilled ? fit.tail : null,
        ),
      );
    }
    // The side layout indexes slices[0] unconditionally; an empty story still
    // gets a (blank) first slice so nothing has to special-case it.
    if (slices.isEmpty) {
      slices.add(_bodySlice(storyStart, storyStart, style: fit.style));
    }
    return slices;
  }

  /// Whatever the fit gets wrong by a line — Telugu measures are not perfectly
  /// predictable across the tail swap — the page must never show a yellow
  /// overflow stripe. So the story is laid out unbounded and clipped to its
  /// box, and an overrun is a lost line rather than a broken poster.
  Widget _clipToBox(Widget child) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minHeight: 0,
        maxHeight: double.infinity,
        child: child,
      ),
    );
  }

  /// Chooses the body size and break points that fit [body] into [regions].
  ///
  /// Tries [_bodySizes] largest first and takes the first that holds the whole
  /// story. If none does, the story is cut at the smallest size: the cut is
  /// backed off a word at a time until the text plus [_continuedTail] fits, so
  /// the pointer to the app always lands on the page rather than falling off
  /// it.
  _StoryFit _fitStory(String body, List<_Region> regions) {
    for (final size in _bodySizes) {
      final fit = _layoutIn(body, regions, bodyAt(size));
      if (fit.ends.last >= body.length) return fit;
    }

    final style = bodyAt(_bodySizes.last);
    final whole = _layoutIn(body, regions, style);
    // A page that is about to be continued says nothing — the next page is the
    // rest of the sentence. Only the screen, which has no next page, points the
    // reader at the app.
    if (!showContinuedTail) return whole;
    var cut = whole.ends.last;

    for (var attempt = 0; attempt < 12; attempt++) {
      cut = _wordBoundaryBefore(body, cut - _continuedTail.length);
      if (cut <= 0) break;
      final candidate = body.substring(0, cut) + _continuedTail;
      final trial = _layoutIn(candidate, regions, style);
      if (trial.ends.last >= candidate.length) {
        // Indexes back into [body]: a region end that landed inside the tail
        // is clamped to the cut, so the tail renders whole on the last slice.
        return _StoryFit(
          style: style,
          starts: [for (final s in trial.starts) math.min(s, cut)],
          ends: [for (final e in trial.ends) math.min(e, cut)],
          tail: _continuedTail,
        );
      }
    }

    // Couldn't make room for the tail either — print what fits, uncaptioned.
    return whole;
  }

  /// Lays [text] into [regions] in order at [style], returning where each
  /// region's slice starts and ends. Whitespace at a boundary is skipped so no
  /// slice opens on a stray space or blank line.
  _StoryFit _layoutIn(String text, List<_Region> regions, TextStyle style) {
    final starts = <int>[];
    final ends = <int>[];
    var cursor = 0;
    for (final region in regions) {
      while (cursor < text.length && text[cursor].trim().isEmpty) {
        cursor++;
      }
      starts.add(cursor);
      cursor += _charsFitting(
        text.substring(cursor),
        region.width,
        region.height,
        style,
      );
      ends.add(cursor);
    }
    return _StoryFit(style: style, starts: starts, ends: ends);
  }

  static int _wordBoundaryBefore(String text, int index) {
    final at = index.clamp(0, text.length);
    final space = text.lastIndexOf(RegExp(r'\s'), at);
    return space > 0 ? space : at;
  }

  /// How much of [text] fits in a [width] × [height] box at [style], rounded
  /// back to a word boundary so a column never breaks mid-word.
  ///
  /// Deterministic: the poster is always laid out at [posterWidth] with fixed
  /// type sizes, so this measures the same on every device.
  int _charsFitting(String text, double width, double height, TextStyle style) {
    if (text.isEmpty || height <= 0 || width <= 0) return 0;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      // Matches how the slice is actually painted, so the measured break point
      // is the one the reader ends up seeing.
      textAlign: TextAlign.start,
    )..layout(maxWidth: width);

    if (painter.height <= height) return text.length;

    // Count whole lines that fit, from the line metrics. Probing
    // getPositionForOffset at y = height — what this used to do — lands
    // *inside* the first line that doesn't fit whenever height isn't an exact
    // multiple of the line height, and returns the end of that line: one line
    // too many. The unbounded scroll absorbed that silently; on a fixed page it
    // pushed the text below the photo off the bottom.
    final lines = painter.computeLineMetrics();
    var bottom = 0.0;
    var fitting = 0;
    for (final line in lines) {
      if (bottom + line.height > height + 0.01) break;
      bottom += line.height;
      fitting++;
    }

    // Take the end of the last fitting line, then verify — Telugu shaping can
    // move a break — and drop a line at a time until the slice really fits.
    for (var n = fitting; n > 0; n--) {
      var top = 0.0;
      for (var i = 0; i < n - 1; i++) {
        top += lines[i].height;
      }
      final probeY = top + lines[n - 1].height / 2;
      final cut = painter
          .getPositionForOffset(Offset(width, probeY))
          .offset
          .clamp(0, text.length);
      final wordBreak = text.lastIndexOf(RegExp(r'\s'), cut);
      final end = wordBreak > 0 ? wordBreak : cut;
      if (end <= 0) return 0;

      final check = TextPainter(
        text: TextSpan(text: text.substring(0, end), style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.start,
      )..layout(maxWidth: width);
      if (check.height <= height + 0.01) return end;
    }
    return 0;
  }
}

/// A box the story has to fit into, in poster units.
class _Region {
  final double width;
  final double height;
  const _Region(this.width, this.height);
}

/// The result of fitting a story: the size it's set at and, per region, the
/// `[start, end)` of [NewsPoster._body] that region shows. [tail] is set when
/// the story was cut and ends on the continuation line.
class _StoryFit {
  final TextStyle style;
  final List<int> starts;
  final List<int> ends;
  final String? tail;
  const _StoryFit({
    required this.style,
    required this.starts,
    required this.ends,
    this.tail,
  });
}

/// A video advert as it prints in the epaper.
///
/// The poster is rasterised to a still PNG, so the video itself can never be in
/// it — and a platform video texture doesn't survive a [RepaintBoundary]
/// capture even when one is on screen. What can be printed is a frame pulled
/// out of the file, which is what this does: a still under a play badge, with a
/// line telling the reader the paper can't play it and where it can be watched.
///
/// The frame is fetched with `video_compress`, already a dependency for upload
/// compression. It reads remote URLs on Android; anywhere it can't, the tile
/// falls back to a plain play panel, which still says "there is a video advert
/// here" — the outcome that matters, since the alternative was the booking
/// silently disappearing from the printed page.
class _PosterVideoAd extends StatefulWidget {
  final String videoUrl;

  const _PosterVideoAd({required this.videoUrl});

  @override
  State<_PosterVideoAd> createState() => _PosterVideoAdState();
}

class _PosterVideoAdState extends State<_PosterVideoAd> {
  Uint8List? _frame;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _loadFrame();
  }

  @override
  void didUpdateWidget(_PosterVideoAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The palette picker rebuilds the poster; only a different creative needs
    // the frame fetching again.
    if (oldWidget.videoUrl != widget.videoUrl) {
      _frame = null;
      _tried = false;
      _loadFrame();
    }
  }

  Future<void> _loadFrame() async {
    try {
      final bytes = await VideoCompress.getByteThumbnail(
        widget.videoUrl,
        quality: 90,
      );
      if (mounted) {
        setState(() {
          _frame = bytes;
          _tried = true;
        });
      }
    } catch (e) {
      debugPrint('[Poster] video ad thumbnail failed: $e');
      if (mounted) setState(() => _tried = true);
    }
  }

  /// Fills whatever box the advert band gives it: the frame behind a play
  /// badge, with the "watch it in the app" line as a strip along the bottom
  /// edge rather than a caption underneath — the band has a fixed height and a
  /// caption outside the tile would have to come out of it.
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101216),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_frame != null)
            // Cover, not contain: the still is a pointer to something watched
            // elsewhere, not the creative itself, so filling the tile beats
            // letterboxing it.
            Image.memory(_frame!, fit: BoxFit.cover)
          else if (!_tried)
            // Still fetching. Printed, a spinner would be a frozen artefact, so
            // the panel just stays plain.
            const SizedBox.shrink(),
          // A light scrim so a bright frame doesn't swallow the badge.
          Container(color: Colors.black.withValues(alpha: 0.18)),
          // The Center is load-bearing, not decoration: this Stack is
          // StackFit.expand, which hands every non-positioned child tight
          // constraints the size of the tile. Without it the badge's own size is
          // ignored and the circle paints across the whole frame.
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: Colors.black.withValues(alpha: 0.6),
              child: Text(
                // A colon, not a middle dot: Ramabhadra has no `·` and the
                // fallback printed it as a box.
                'వీడియో ప్రకటన: డీప్ పల్స్ యాప్‌లో చూడండి',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: NewsPoster.display(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
