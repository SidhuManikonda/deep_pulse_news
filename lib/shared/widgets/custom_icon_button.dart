import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  const CustomIconButton({
    super.key,
    required this.text,
    required this.onTap,
    this.svgPath,
    this.isOutlined = false,
    this.width,
    this.fontSize = 14,
    this.contentColor,
    this.icon,
    this.textStyle,
    this.outlineColor,
    this.buttonColor,
    this.borderRadius,
    this.isLoading = false,
  });

  final String text;
  final String? svgPath;
  final Function() onTap;
  final bool isOutlined;
  final double? width;
  final double fontSize;
  final Color? contentColor;
  final Color? outlineColor;
  final Color? buttonColor;
  final IconData? icon;
  final TextStyle? textStyle;
  final BorderRadiusGeometry? borderRadius;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: contentColor?.withOpacity(0.25),
      onTap: isLoading ? null : onTap,
      child: SizedBox(
        width: width,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: buttonColor ?? (isOutlined ? null : const Color(0xFF202829)),
            border: isOutlined
                ? Border.all(color: outlineColor ?? const Color(0xFF202829))
                : null,
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (svgPath != null && !isLoading)
                  Image.asset(
                    svgPath!,
                    height: 20,
                    width: 20,
                    color: contentColor ?? Colors.white,
                  ),

                if (icon != null && !isLoading)
                  Icon(icon, color: contentColor ?? Colors.white, size: 20),

                if ((icon != null || svgPath != null) && !isLoading)
                  const SizedBox(width: 8),

                // 🔥 TEXT + LOADER
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style:
                          textStyle ??
                          TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: fontSize,
                            color: contentColor ?? Colors.white,
                          ),
                    ),

                    if (isLoading) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: contentColor ?? Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
