import 'package:flutter/material.dart';

/// Parses a hex color string ("#RRGGBB", "RRGGBB", "#AARRGGBB") into a [Color].
/// Returns null when [hex] is null/blank/invalid so callers can fall back to a
/// theme default. Safe against bad backend values — never throws.
Color? colorFromHex(String? hex) {
  if (hex == null) return null;
  var h = hex.trim().replaceFirst('#', '');
  if (h.isEmpty) return null;
  if (h.length == 6) h = 'FF$h'; // assume fully opaque when no alpha given
  if (h.length != 8) return null;
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}

/// Serializes a [Color] to a "#RRGGBB" hex string (drops alpha) for sending to
/// the backend.
String hexFromColor(Color color) {
  final argb = color.toARGB32();
  final rgb = argb & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
