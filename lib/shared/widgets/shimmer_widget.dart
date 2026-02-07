import 'package:deep_pulse_news/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ShimmerWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
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
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.ease),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override


  
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? Theme.of(context).appGrey300;
    final highlightColor =
        widget.highlightColor ?? Theme.of(context).appGrey100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height??50,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [0.0, 0.5, 1.0],
              transform: GradientRotation(_animation.value),
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

class TopicChipShimmer extends StatelessWidget {
  final bool isFullWidth;

  const TopicChipShimmer({super.key, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji shimmer
          ShimmerWidget(
            width: 16,
            height: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 6),
          // Text shimmer - different widths based on isFullWidth
          Flexible(
            child: ShimmerWidget(
              width: isFullWidth ? double.infinity : null,
              height: 14,
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: isFullWidth ? double.infinity : _getShimmerTextWidth(),
                height: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getShimmerTextWidth() {
    // Simulate different text lengths for variety
    final widths = [60.0, 80.0, 100.0, 120.0, 90.0, 70.0];
    return widths[DateTime.now().millisecond % widths.length];
  }
}
