import 'package:flutter/material.dart';

/// 8pt grid spacing tokens. Use these instead of raw EdgeInsets numbers.
class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // Common EdgeInsets presets
  static const EdgeInsets paddingXS  = EdgeInsets.all(xs);
  static const EdgeInsets paddingSM  = EdgeInsets.all(sm);
  static const EdgeInsets paddingMD  = EdgeInsets.all(md);
  static const EdgeInsets paddingLG  = EdgeInsets.all(lg);

  static const EdgeInsets horizontalSM  = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalLG  = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXL  = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXS = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSM = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMD = EdgeInsets.symmetric(vertical: md);

  static const EdgeInsets cardPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: lg);
}
