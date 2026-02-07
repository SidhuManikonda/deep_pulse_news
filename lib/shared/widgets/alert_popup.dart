import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wrapper widget to initialize AlertPopupManager with overlay
/// Use this to wrap your main screen content
class AlertInitializer extends StatefulWidget {
  final Widget child;

  const AlertInitializer({super.key, required this.child});

  @override
  State<AlertInitializer> createState() => _AlertInitializerState();
}

class _AlertInitializerState extends State<AlertInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final overlay = Overlay.of(context);
          AlertPopupManager().initialize(overlay);
        } catch (e) {
          debugPrint('AlertInitializer: Failed to initialize overlay: $e');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AlertPopupManager {
  static AlertPopupManager? _instance;

  factory AlertPopupManager() {
    _instance ??= AlertPopupManager._internal();
    return _instance!;
  }

  AlertPopupManager._internal();

  // Add a reset method to clear singleton state
  static void reset() {
    _instance?._activeAlerts.clear();
    _instance?._overlayState = null;
    _instance = null;
  }

  final List<AlertData> _activeAlerts = [];
  OverlayState? _overlayState;

  void initialize(OverlayState overlayState) {
    _overlayState = overlayState;
  }

  void showAlert({
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (_overlayState == null) return;

    final positionNotifier = ValueNotifier<int>(_activeAlerts.length);
    late OverlayEntry alertEntry;
    late AlertData alertData;

    alertEntry = OverlayEntry(
      builder:
          (context) => AlertPopup(
            message: message,
            title: title,
            type: type,
            duration: duration,
            onDismiss: () => _removeAlert(alertData),
            positionNotifier: positionNotifier,
          ),
    );

    alertData = AlertData(
      entry: alertEntry,
      message: message,
      title: title,
      type: type,
      duration: duration,
      positionNotifier: positionNotifier,
    );

    _activeAlerts.add(alertData);
    _overlayState!.insert(alertEntry);
  }

  void _removeAlert(AlertData alertData) {
    alertData.entry.remove();
    _activeAlerts.remove(alertData);
    _updatePositions();
  }

  void _updatePositions() {
    // Simply update the position notifiers without rebuilding
    for (int i = 0; i < _activeAlerts.length; i++) {
      _activeAlerts[i].positionNotifier.value = i;
    }
  }

  void clearAllAlerts() {
    for (final alertData in _activeAlerts) {
      alertData.entry.remove();
    }
    _activeAlerts.clear();
  }
}

class AlertData {
  OverlayEntry entry;
  final String message;
  final String? title;
  final AlertType type;
  final Duration duration;
  final ValueNotifier<int> positionNotifier;

  AlertData({
    required this.entry,
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.positionNotifier,
  });
}

enum AlertType { success, error, warning, info }

class AlertPopup extends StatefulWidget {
  final String message;
  final String? title;
  final AlertType type;
  final Duration duration;
  final VoidCallback onDismiss;
  final ValueNotifier<int> positionNotifier;

  const AlertPopup({
    super.key,
    required this.message,
    this.title,
    required this.type,
    required this.duration,
    required this.onDismiss,
    required this.positionNotifier,
  });

  @override
  State<AlertPopup> createState() => _AlertPopupState();
}

class _AlertPopupState extends State<AlertPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAutoClose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  void _startAutoClose() {
    Future.delayed(widget.duration, () {
      if (mounted) {
        _closeAlert();
      }
    });
  }

  void _closeAlert() {
    _animationController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  Color _getAlertColor() {
    switch (widget.type) {
      case AlertType.success:
        return Colors.green;
      case AlertType.error:
        return Colors.red;
      case AlertType.warning:
        return Colors.orange;
      case AlertType.info:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon() {
    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle;
      case AlertType.error:
        return Icons.cancel;
      case AlertType.warning:
        return Icons.warning;
      case AlertType.info:
        return Icons.info;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double alertHeight = 70, alertSpacing = 10, bottomMargin = 20;

    return ValueListenableBuilder<int>(
      valueListenable: widget.positionNotifier,
      builder: (context, position, child) {
        return Positioned(
          right: 5,
          bottom: bottomMargin + (position * (alertHeight + alertSpacing)),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),

                child: Container(
                  width: 350,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minHeight: alertHeight,
                    maxHeight: alertHeight,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getAlertColor().withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Colored left border
                      Container(
                        width: 5,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: _getAlertColor(),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                      ),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Icon
                              Icon(
                                _getAlertIcon(),
                                color: _getAlertColor(),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              // Text content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.title != null) ...[
                                      Text(
                                        widget.title!,
                                        style: const TextStyle(
                                          fontSize: kIsWeb ? 12 : 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      widget.message,
                                      style: const TextStyle(
                                        fontSize: kIsWeb ? 11 : 13,
                                        color: Colors.black54,
                                      ),
                                      maxLines:
                                          kIsWeb
                                              ? 2
                                              : widget.title != null
                                              ? 2
                                              : 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Close button
                              InkWell(
                                onTap: _closeAlert,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.black45,
                                  ),
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
          ),
        );
      },
    );
  }
}

// Extension to easily show alerts from anywhere
extension AlertExtension on BuildContext {
  void showAlert({
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 5),
  }) {
    AlertPopupManager().showAlert(
      message: message,
      title: title,
      type: type,
      duration: duration,
    );
  }
}
