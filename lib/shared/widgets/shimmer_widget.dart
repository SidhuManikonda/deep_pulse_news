import 'package:flutter/material.dart';
import 'app_loader.dart';

/// Thin wrapper kept for backward compatibility.
/// Internally uses [ShimmerBox] which applies the brand-coloured shimmer.
class ShimmerWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  // Ignored — brand shimmer colours are used; kept so call-sites don't break.
  final Color? baseColor;
  final Color? highlightColor;
  final Widget? child;

  const ShimmerWidget({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height ?? 50,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }
}

class TopicChipShimmer extends StatelessWidget {
  final bool isFullWidth;
  const TopicChipShimmer({super.key, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShimmerBox(width: 16, height: 16, borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 6),
          ShimmerBox(
            width: isFullWidth ? double.infinity : _randomWidth(),
            height: 14,
            borderRadius: BorderRadius.circular(7),
          ),
        ],
      ),
    );
  }

  double _randomWidth() {
    const widths = [60.0, 80.0, 100.0, 120.0, 90.0, 70.0];
    return widths[DateTime.now().millisecond % widths.length];
  }
}
