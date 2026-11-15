import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'core/logging/logging.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  await initAppLog();
  runApp(
    const ProviderScope(
      child: CwaWeatherApp(),
    ),
  );
}

class CwaWeatherApp extends StatelessWidget {
  const CwaWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CWA Weather',
      theme: AppTheme.light,
      builder: (context, child) => DefaultTextHeightBehavior(
        textHeightBehavior: const TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even),
        child: child!,
      ),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
