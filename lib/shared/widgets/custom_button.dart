import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_radius.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final IconData? icon;
  /// Use a diagonal gradient instead of a flat background.
  /// Ignored when [isOutlined] is true or [backgroundColor] is explicitly set.
  final bool useGradient;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 52,
    this.borderRadius = AppRadius.md,
    this.icon,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(borderRadius);

    if (isOutlined) {
      final color = backgroundColor ?? theme.appPrimary;
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: _content(context, color),
        ),
      );
    }

    // Flat fill when a custom color is given; gradient for the default primary
    final useGrad = useGradient && backgroundColor == null;

    if (useGrad) {
      // Wrap with gradient container — ElevatedButton handles ripple on top
      return SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onPressed != null
                ? theme.primaryGradient
                : null,
            color: onPressed == null ? theme.appGrey200 : null,
            borderRadius: radius,
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: theme.appGrey400,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            child: _content(context, Colors.white),
          ),
        ),
      );
    }

    final bg = backgroundColor ?? theme.appPrimary;
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: theme.appGrey200,
          foregroundColor: textColor ?? Colors.white,
          disabledForegroundColor: theme.appGrey400,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
        child: _content(context, textColor ?? Colors.white),
      ),
    );
  }

  Widget _content(BuildContext context, Color iconColor) {
    if (isLoading) {
      return SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: scaledFontSize(15),
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: scaledFontSize(15),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
