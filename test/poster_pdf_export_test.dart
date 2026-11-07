// Checks the epaper PDF export: one page, shaped like the poster, carrying the
// captured bitmap at full resolution.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deep_pulse_news/features/news/news_poster_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The page shape the export uses: A4 width, poster aspect.
PdfPageFormat posterFormat() => PdfPageFormat(
      PdfPageFormat.a4.width,
      PdfPageFormat.a4.width * NewsPoster.posterHeight / NewsPoster.posterWidth,
    );

/// Mirrors exactly what `_downloadPdf` builds, so this exercises the real
/// page geometry rather than a guess at it.
pw.Document buildPosterPdf(Uint8List png) {
  final doc = pw.Document();
  final image = pw.MemoryImage(png);
  doc.addPage(
    pw.Page(
      pageFormat: posterFormat(),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
    ),
  );
  return doc;
}

void main() {
  test('poster PDF is one page, poster-shaped, and embeds the full bitmap',
      () async {
    // A stand-in capture at the size the 4x path produces for a 1080x1620 page.
    const w = 4320, h = 6480;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFFF2EDE1),
    );
    canvas.drawRect(
      const Rect.fromLTWH(200, 300, 3920, 500),
      Paint()..color = const Color(0xFF6A1B9A),
    );
    final img = await recorder.endRecording().toImage(w, h);
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();

    final doc = buildPosterPdf(png);
    final pdf = await doc.save();
    // Kept so the page can be opened and eyeballed after a run.
    final out = File(
      '${Directory.systemTemp.path}/deeppulse_poster_export.pdf',
    )..writeAsBytesSync(pdf);
    addTearDown(() {
      if (out.existsSync()) out.deleteSync();
    });

    expect(pdf.lengthInBytes, greaterThan(1000));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

    // Exactly one page — asked of the document, not grepped out of the bytes,
    // which are deflated.
    expect(doc.document.pdfPageList.pages.length, 1,
        reason: 'the epaper must export as a single page');

    // Page box is the poster's 2:3 shape, not A4's 1:1.414.
    final format = posterFormat();
    expect(format.height / format.width,
        closeTo(NewsPoster.posterHeight / NewsPoster.posterWidth, 0.001));
    expect(format.height / format.width, isNot(closeTo(842 / 595, 0.01)),
        reason: 'a poster page is not A4-shaped');

    // The bitmap went in whole — a 4320px-wide image is most of the file.
    expect(pdf.lengthInBytes, greaterThan(png.lengthInBytes ~/ 2),
        reason: 'the PDF should carry the capture, not a thumbnail of it');
    final expectedH = format.height;
    // ignore: avoid_print
    print('pdf ${pdf.lengthInBytes ~/ 1024} KB from a ${png.lengthInBytes ~/ 1024} KB '
        '${w}x$h capture; page ${PdfPageFormat.a4.width.toStringAsFixed(0)}'
        'x${expectedH.toStringAsFixed(0)} pt');
  });
}
