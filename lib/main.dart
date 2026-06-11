import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/weather/weather_screen.dart';

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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Will adapt to system mode
      home: const WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
