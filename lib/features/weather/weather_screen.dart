/*
---
file_summary: "天氣主畫面 UI，顯示目前天氣與一週預報"
functions:
  - name: "WeatherScreen"
    description: "天氣主畫面，消費 WeatherState 並渲染 UI"
    lines: "8-32"
  - name: "_buildContent"
    description: "根據 WeatherState 渲染主要內容（目前天氣 + 預報列表）"
    lines: "34-70"
  - name: "_buildCurrentWeather"
    description: "目前天氣 widget（溫度、體感、濕度、風速）"
    lines: "72-145"
  - name: "_buildHourlyForecast"
    description: "24小時橫向滾動預報列表"
    lines: "147-195"
  - name: "_buildWeeklyForecast"
    description: "一週預報縱向列表（每日最高/最低溫、天氣圖示）"
    lines: "197-260"
  - name: "_buildLoadingState"
    description: "Loading 狀態顯示"
    lines: "262-270"
  - name: "_buildErrorState"
    description: "Error 狀態顯示"
    lines: "272-285"
  - name: "_buildEmptyState"
    description: "Empty 狀態顯示"
    lines: "287-300"
---
*/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/glass_morphism.dart';
import '../../data/models/weather_models.dart';
import '../../data/repositories/weather_repository.dart';
import '../radar/radar_screen.dart';
import 'weather_provider.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherState = ref.watch(weatherNotifierProvider);

    // Dynamic background based on time/weather
    final bgGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: _buildStateUI(context, weatherState),
        ),
      ),
    );
  }

  Widget _buildStateUI(BuildContext context, WeatherState state) {
    if (state.isLoading) {
      return _buildLoadingState();
    }
    if (state.error != null) {
      return _buildErrorState(context, state.error!);
    }
    // 暫時轉接：UI 改版前整頁仍以逐時預報為準，改版後各卡片各自呈現成敗
    final hourly = state.hourly!;
    if (hourly is Failure<List<HourlyForecast>>) {
      return _buildErrorState(context, hourly.message);
    }
    if (hourly.data.isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildContent(context, state);
  }

  Widget _buildContent(BuildContext context, WeatherState state) {
    final loc = state.location;
    // 暫時轉接：UI 改版前沿用 WeatherCondition 版面（缺值顯示以 0／'--' 代替僅限此轉接）
    final currentTemperature = state.current?.fold(
      onSuccess: (c) => c.temperature,
      onFailure: (_, _) => null,
    );
    final forecast = state.hourly!.data
        .map((h) => WeatherCondition(
              wx: h.weather ?? '--',
              pop: h.pop ?? 0,
              t: (h.temperature ?? currentTemperature ?? 0).round(),
              startTime: h.startTime.toIso8601String(),
              endTime: h.startTime.toIso8601String(),
            ))
        .toList();
    final current = forecast.isNotEmpty ? forecast.first : null;

    return RefreshIndicator(
      onRefresh: () async {
        // Trigger refresh via provider if needed
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          // Location Header
          _buildLocationHeader(context, loc),
          const SizedBox(height: 40),
          // Current Weather Display
          if (current != null) _buildCurrentWeather(current),
          const SizedBox(height: 40),
          // 24 Hour Forecast
          _buildHourlyForecast(forecast),
          const SizedBox(height: 40),
          // Weekly Forecast
          _buildWeeklyForecast(forecast),
        ],
      ),
    );
  }

  Widget _buildLocationHeader(BuildContext context, location) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${location?.county ?? ''} ${location?.town ?? ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '當前天氣預報',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.map, color: Colors.white, size: 30),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RadarScreen()),
            );
          },
        )
      ].animate(interval: 100.ms).fade(duration: 500.ms).slideX(begin: -0.2),
    );
  }

  Widget _buildCurrentWeather(WeatherCondition current) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          // Main temperature and weather icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${current.t}°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                  Text(
                    current.wx,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.wb_sunny, color: Colors.amber, size: 80)
                  .animate()
                  .shimmer(duration: 2000.ms),
            ],
          ),
          const SizedBox(height: 24),
          // Weather details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherDetailItem(Icons.thermostat_outlined, '體感', '${current.t}°'),
              _buildWeatherDetailItem(Icons.water_drop_outlined, '降雨機率', '${current.pop}%'),
              _buildWeatherDetailItem(Icons.air, '風速', '--m/s'),
              _buildWeatherDetailItem(Icons.opacity, '濕度', '--%'),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: 300.ms).scale();
  }

  Widget _buildWeatherDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyForecast(List<WeatherCondition> forecast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '未來24小時預報',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ).animate().fade(delay: 600.ms),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: forecast.length,
            itemBuilder: (context, index) {
              final item = forecast[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GlassContainer(
                  width: 120,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        item.startTime == 'now' ? '現在' : item.startTime,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const Icon(Icons.cloud, color: Colors.white),
                      Text(
                        '${item.t}°C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '降雨 ${item.pop}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: (700 + (index * 100)).ms).slideY(begin: 0.2),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyForecast(List<WeatherCondition> forecast) {
    // Group forecast by day (simplified - take first item of each day pattern)
    final dailyForecasts = <WeatherCondition>[];
    for (var i = 0; i < forecast.length && dailyForecasts.length < 7; i += 4) {
      if (i < forecast.length) {
        dailyForecasts.add(forecast[i]);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '一週預報',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ).animate().fade(delay: 800.ms),
        const SizedBox(height: 16),
        ...dailyForecasts.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final dayNames = ['今天', '明天', '週二', '週三', '週四', '週五', '週六'];
          final dayLabel = index < dayNames.length ? dayNames[index] : '第${index + 1}天';

          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Icon(Icons.wb_cloudy, color: Colors.white70, size: 28),
                Row(
                  children: [
                    Text(
                      '${item.t - 2}°',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.t}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.pop}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: (900 + (index * 100)).ms).slideX(begin: 0.1);
        }),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            '載入天氣資料...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(
              '載入失敗',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $error',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Could trigger refresh here
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              '暫無天氣資料',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '請稍後再試，或檢查網路連線',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}
