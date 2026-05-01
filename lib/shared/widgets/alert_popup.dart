import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../main.dart';

enum AlertType { success, error, warning, info }

class AlertPopupManager {
  static AlertPopupManager? _instance;

  factory AlertPopupManager() {
    _instance ??= AlertPopupManager._internal();
    return _instance!;
  }

  AlertPopupManager._internal();

  static void reset() {
    _instance = null;
  }

  /// No-op now — kept for backward compatibility so callers don't break.
  void initialize(OverlayState overlayState) {}

  void showAlert({
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messengerState = scaffoldMessengerKey.currentState;
    if (messengerState == null) return;

    final cleanMsg = _cleanMessage(message);

    messengerState.hideCurrentSnackBar();
    messengerState.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_iconFor(type), color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    cleanMsg,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withAlpha(220),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _colorFor(type),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  String _cleanMessage(String message) {
    final cleaned = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length > 100) {
      final cutoff = cleaned.substring(0, 100);
      final lastSpace = cutoff.lastIndexOf(' ');
      if (lastSpace > 60) return '${cutoff.substring(0, lastSpace)}...';
      return '$cutoff...';
    }
    return cleaned;
  }

  Color _colorFor(AlertType type) {
    switch (type) {
      case AlertType.success: return appAlertSuccessColor;
      case AlertType.error:   return appAlertErrorColor;
      case AlertType.warning: return appAlertWarningColor;
      case AlertType.info:    return appAlertInfoColor;
    }
  }

  IconData _iconFor(AlertType type) {
    switch (type) {
      case AlertType.success: return Icons.check_circle_rounded;
      case AlertType.error:   return Icons.error_rounded;
      case AlertType.warning: return Icons.warning_rounded;
      case AlertType.info:    return Icons.info_rounded;
    }
  }

  void clearAllAlerts() {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }
}

/// Kept for backward compat — no-op widget now.
class AlertInitializer extends StatelessWidget {
  final Widget child;
  const AlertInitializer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

extension AlertExtension on BuildContext {
  void showAlert({
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    AlertPopupManager().showAlert(
      message: message,
      title: title,
      type: type,
      duration: duration,
    );
  }
}
