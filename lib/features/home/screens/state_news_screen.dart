import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_font_sizes.dart';
import '../../../shared/widgets/auto_scaled_text.dart';

class StateNewsScreen extends ConsumerWidget {
  const StateNewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: AutoScaledText(
          'State News',
          style: TextStyle(
            fontSize: appFontSizeHeader,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.headlineLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: AutoScaledText(
          'State News Screen',
          style: TextStyle(
            fontSize: appFontSizeTitle,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.headlineLarge?.color,
          ),
        ),
      ),
    );
  }
}
