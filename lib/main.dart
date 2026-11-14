import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
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
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
