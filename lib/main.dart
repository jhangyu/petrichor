import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'core/logging/app_log.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  await initAppLog();
  runApp(
    const ProviderScope(
      child: PetrichorApp(),
    ),
  );
}

class PetrichorApp extends StatelessWidget {
  const PetrichorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cirrus · Wisp · Billow',
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
