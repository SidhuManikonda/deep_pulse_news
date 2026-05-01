import 'package:flutter/material.dart';

/// Named border-radius tokens. Use these instead of raw BorderRadius.circular().
class AppRadius {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double pill = 100;

  // Const BorderRadius presets (use for containers, cards, chips, etc.)
  static const BorderRadius xsAll   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  // Specific shapes used in comment bubbles / overlays
  static const BorderRadius commentBubble = BorderRadius.only(
    topLeft:     Radius.circular(xs),
    topRight:    Radius.circular(md),
    bottomLeft:  Radius.circular(md),
    bottomRight: Radius.circular(md),
  );
}
