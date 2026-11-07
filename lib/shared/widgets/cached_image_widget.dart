import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CachedImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// Width, in device pixels, to decode the image at. 1080 is right for a
  /// phone screen and keeps the image cache small.
  ///
  /// Raise it where the result is captured rather than looked at — the epaper
  /// poster rasterises itself at up to 3×, so an image decoded for the screen
  /// gets enlarged threefold in the saved PNG and turns to mush the moment
  /// anyone zooms in. Null decodes at the source's own resolution.
  final int? decodeWidth;

  const CachedImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.decodeWidth = 1080,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      // Only constrain the decode width. Setting BOTH memCacheWidth and
      // memCacheHeight makes ResizeImage (policy: exact) force the image into
      // those exact dimensions, distorting/stretching the aspect ratio.
      // Constraining width alone keeps the original aspect ratio intact.
      memCacheWidth: decodeWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          this.errorWidget ??
          Container(
            color: Colors.grey[300],
            child: Center(
              child: Icon(Icons.image, size: 64, color: Colors.grey[600]),
            ),
          ),
    );
  }
}

/// Shows an image at its true (original) aspect ratio so screenshots and
/// portrait images are displayed fully without stretching or harsh cropping.
///
/// The intrinsic aspect ratio is resolved at runtime (the model carries no
/// dimensions) and clamped between [minAspectRatio] and [maxAspectRatio] so a
/// very tall image cannot take over the whole screen. The image is painted with
/// [BoxFit.contain] on a dark backdrop, guaranteeing the complete original is
/// always visible.
class AdaptiveCachedImage extends StatefulWidget {
  final String imageUrl;

  /// width / height. Most-portrait shape allowed (smaller = taller).
  final double minAspectRatio;

  /// width / height. Most-landscape shape allowed.
  final double maxAspectRatio;

  /// Aspect ratio used before the real dimensions are known.
  final double initialAspectRatio;

  final Color backgroundColor;
  final Widget? errorWidget;

  /// When true, the empty space around a contained image (the letterbox when
  /// the image's shape doesn't match the box) is filled with a blurred,
  /// zoomed copy of the same image — so a tall portrait/screenshot still fills
  /// the full width nicely instead of showing flat side bars.
  final bool blurredBackground;

  /// Optional ceiling on the rendered height. When the natural height
  /// (width / aspectRatio) would exceed this, the image is shown fully
  /// (contained) inside a box capped at [maxHeight] instead of growing to fill
  /// the screen — useful for tall portrait images in a scrolling feed.
  final double? maxHeight;

  /// Width, in device pixels, to decode at. See
  /// [CachedImageWidget.decodeWidth] — the poster raises it because it captures
  /// itself at up to 3× and a screen-sized decode is soft at that scale.
  final int? decodeWidth;

  /// How the (sharp foreground) image is fit inside its box.
  /// [BoxFit.contain] shows the whole image (may letterbox / look thin for a
  /// portrait in a short box); [BoxFit.cover] fills the box width fully but
  /// crops the overflowing top/bottom.
  final BoxFit fit;

  const AdaptiveCachedImage({
    super.key,
    required this.imageUrl,
    this.minAspectRatio = 0.62, // ~ portrait phone screenshot
    this.maxAspectRatio = 1.91,
    this.initialAspectRatio = 16 / 9,
    this.backgroundColor = Colors.black,
    this.errorWidget,
    this.maxHeight,
    this.blurredBackground = false,
    this.fit = BoxFit.contain,
    this.decodeWidth = 1080,
  });

  @override
  State<AdaptiveCachedImage> createState() => _AdaptiveCachedImageState();
}

class _AdaptiveCachedImageState extends State<AdaptiveCachedImage> {
  /// Decode width for the blurred letterbox copy.
  ///
  /// The backdrop only ever reads as a wash of colour, so it's decoded at
  /// thumbnail size and stretched to fill. Bilinear upscaling from 48px *is*
  /// the blur — and it costs nothing, where the `ImageFiltered` gaussian this
  /// replaces ran a full-size blur over the whole card on every single frame.
  /// With two cards live during a feed swipe that was two per-frame blurs, and
  /// it is the most expensive thing the feed drew.
  static const int _backdropDecodeWidth = 48;

  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  late CachedNetworkImageProvider _provider;
  CachedNetworkImageProvider? _backdropProvider;

  @override
  void initState() {
    super.initState();
    _buildProviders();
  }

  void _buildProviders() {
    _provider = CachedNetworkImageProvider(
      widget.imageUrl,
      maxWidth: widget.decodeWidth,
    );
    _backdropProvider = widget.blurredBackground
        ? CachedNetworkImageProvider(
            widget.imageUrl,
            maxWidth: _backdropDecodeWidth,
          )
        : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant AdaptiveCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.blurredBackground != widget.blurredBackground) {
      _aspectRatio = null;
      _buildProviders();
      _resolveAspectRatio();
    }
  }

  void _resolveAspectRatio() {
    _removeListener();
    final stream = _provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      if (mounted && _aspectRatio != ratio) {
        setState(() => _aspectRatio = ratio);
      }
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _removeListener() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = _aspectRatio ?? widget.initialAspectRatio;
    final ratio = raw.clamp(widget.minAspectRatio, widget.maxAspectRatio);

    final foreground = Image(
      image: _provider,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          widget.errorWidget ??
          Center(child: Icon(Icons.image, size: 64, color: Colors.grey[600])),
    );

    final image = widget.blurredBackground
        ? Stack(
            fit: StackFit.expand,
            children: [
              // Solid dark base — guarantees the letterbox is never the flat
              // light-grey of the parent while the blur layer is decoding.
              const ColoredBox(color: Color(0xFF1A1A1A)),
              // Blurred, zoomed copy of the same image fills the letterbox.
              // The blur is the 48px decode being stretched to fill, not a
              // filter — see [_backdropDecodeWidth]. Same look, and the feed
              // stops paying for a gaussian on every frame it scrolls.
              Image(
                image: _backdropProvider ?? _provider,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                // Bilinear on the upscale is what smooths the thumbnail into a
                // wash; `none` would show it as visible blocks.
                filterQuality: FilterQuality.low,
                // No error widget here — the foreground already handles it.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              // Slight dim so the sharp foreground image stays the focus.
              Container(color: Colors.black.withValues(alpha: 0.15)),
              foreground,
            ],
          )
        : Container(color: widget.backgroundColor, child: foreground);

    // With a height cap, fall to a fixed box only when the natural height would
    // overflow it; the contained image then shows in full within the cap.
    if (widget.maxHeight != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final naturalHeight = width / ratio;
          final height = naturalHeight > widget.maxHeight!
              ? widget.maxHeight!
              : naturalHeight;
          return SizedBox(width: double.infinity, height: height, child: image);
        },
      );
    }

    return AspectRatio(aspectRatio: ratio, child: image);
  }
}
