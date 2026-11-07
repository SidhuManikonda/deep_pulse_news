import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/utils/youtube_url.dart';

/// Asks for the YouTube link behind an ad.
///
/// Shared by the article ad slots and the full-screen ads form so the two
/// can't drift apart.
///
/// Two things it does that a bare text prompt doesn't:
///
/// **It shows the video as you type.** A pasted URL is 11 opaque characters
/// of id surrounded by noise — the only way to know it's the right video is to
/// see it. The poster frame appears the moment the link parses.
///
/// **Save is disabled until the link is valid**, rather than accepting a tap
/// and then refusing it. The error only appears once something unusable has
/// actually been typed, so the dialog doesn't open shouting.
class YoutubeLinkDialog extends StatefulWidget {
  final String? initial;

  const YoutubeLinkDialog({super.key, this.initial});

  /// Returns the URL, or null if dismissed.
  static Future<String?> show(BuildContext context, {String? initial}) {
    return showDialog<String>(
      context: context,
      builder: (_) => YoutubeLinkDialog(initial: initial),
    );
  }

  @override
  State<YoutubeLinkDialog> createState() => _YoutubeLinkDialogState();
}

class _YoutubeLinkDialogState extends State<YoutubeLinkDialog> {
  late String _text = widget.initial ?? '';

  String? get _videoId => YoutubeUrl.videoId(_text);
  bool get _isValid => _videoId != null;

  /// Only complain once there's something to complain about — an empty field
  /// is the starting state, not a mistake.
  bool get _showError => _text.trim().isNotEmpty && !_isValid;

  /// Opens the pasted video in YouTube so the link can be checked before it
  /// is committed to an ad — a thumbnail proves the id resolves, not that the
  /// video is the right one.
  Future<void> _openInYoutube() async {
    final watch = YoutubeUrl.watchUrl(_text);
    if (watch == null) return;
    final uri = Uri.tryParse(watch);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _text = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const youtubeRed = Color(0xFFFF0000);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: youtubeRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: youtubeRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YouTube link',
                          style: TextStyle(
                            fontSize: scaledFontSize(17),
                            fontWeight: FontWeight.w700,
                            color: theme.appTextPrimary,
                          ),
                        ),
                        Text(
                          'Readers tap the thumbnail to open YouTube',
                          style: TextStyle(
                            fontSize: scaledFontSize(12),
                            color: theme.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              TextFormField(
                initialValue: widget.initial ?? '',
                autofocus: true,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: (value) => setState(() => _text = value),
                onFieldSubmitted: (_) {
                  if (_isValid) Navigator.pop(context, _text.trim());
                },
                style: TextStyle(fontSize: scaledFontSize(14)),
                decoration: InputDecoration(
                  hintText: 'https://youtu.be/...',
                  filled: true,
                  fillColor: theme.appGrey100,
                  errorText: _showError
                      ? "That doesn't look like a YouTube link"
                      : null,
                  suffixIcon: IconButton(
                    tooltip: 'Paste',
                    onPressed: _pasteFromClipboard,
                    icon: Icon(
                      Icons.content_paste_rounded,
                      size: 19,
                      color: theme.appTextSecondary,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.appDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.appDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.appPrimary, width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),

              // Proof that the link points at the video they meant. Held at a
              // fixed height so the dialog doesn't jump as it appears.
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: _isValid
                    ? Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: GestureDetector(
                          onTap: _openInYoutube,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    YoutubeUrl.thumbnail(_text)!,
                                    fit: BoxFit.cover,
                                    // A private or deleted video keeps a valid
                                    // id but has no poster frame. The link may
                                    // still be the one they want, so this
                                    // explains rather than blocks.
                                    errorBuilder: (_, __, ___) => Container(
                                      color: theme.appGrey200,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'No preview available',
                                        style: TextStyle(
                                          fontSize: scaledFontSize(12),
                                          color: theme.appTextLight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white70,
                                      size: 42,
                                    ),
                                  ),
                                  // Says the picture is a control, not decoration.
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.open_in_new_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tap to check',
                                            style: TextStyle(
                                              fontSize: scaledFontSize(10.5),
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: theme.appTextSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    // Disabled rather than refusing the tap afterwards.
                    onPressed: _isValid
                        ? () => Navigator.pop(context, _text.trim())
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.appPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
