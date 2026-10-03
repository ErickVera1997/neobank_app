import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/config/application/bootstrap_controller.dart';
import 'routing/app_router.dart';

/// Widget raíz: tema dinámico + enrutado.
class NeobankApp extends ConsumerWidget {
  const NeobankApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(themeConfigProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: themeConfig.brandName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        config: themeConfig,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.build(
        config: themeConfig,
        brightness: Brightness.dark,
      ),
      themeMode: switch (themeConfig.mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: router,
    );
  }
}
