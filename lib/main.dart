import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'providers/app_providers.dart';
import 'providers/font_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(themeControllerProvider).init();
      ref.read(fontControllerProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ref.watch(themeControllerProvider);
    final fontController = ref.watch(fontControllerProvider);
    final fontScale = fontController.fontScale;

    return MaterialApp(
      title: 'Deep Pulse News',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(fontScale),
      darkTheme: AppTheme.darkTheme(fontScale),
      themeMode: themeController.themeMode,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}
