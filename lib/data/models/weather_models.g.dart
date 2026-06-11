// GENERATED CODE - DO NOT MODIFY BY HAND
// This file was manually updated to match the expanded model set.
// In a proper environment, run `dart run build_runner build` to regenerate.

part of 'weather_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

// ─── CurrentWeather ────────────────────────────────────────────────────────

CurrentWeather _$CurrentWeatherFromJson(Map<String, dynamic> json) =>
    _CurrentWeather(
      locationName: json['locationName'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feelsLike'] as num).toDouble(),
      humidity: (json['humidity'] as num).toInt(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      weatherDescription: json['weatherDescription'] as String,
      weatherCode: json['weatherCode'] as String,
      pop: (json['pop'] as num).toInt(),
      observationTime: json['observationTime'] as String,
    );

Map<String, dynamic> _$CurrentWeatherToJson(CurrentWeather instance) =>
    <String, dynamic>{
      'locationName': instance.locationName,
      'temperature': instance.temperature,
      'feelsLike': instance.feelsLike,
      'humidity': instance.humidity,
      'windSpeed': instance.windSpeed,
      'weatherDescription': instance.weatherDescription,
      'weatherCode': instance.weatherCode,
      'pop': instance.pop,
      'observationTime': instance.observationTime,
    };

// ─── WeeklyForecast ──────────────────────────────────────────────────────

WeeklyForecast _$WeeklyForecastFromJson(Map<String, dynamic> json) =>
    _WeeklyForecast(
      locationName: json['locationName'] as String,
      days: (json['days'] as List<dynamic>)
          .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$WeeklyForecastToJson(WeeklyForecast instance) =>
    <String, dynamic>{
      'locationName': instance.locationName,
      'days': instance.days.map((e) => e.toJson()).toList(),
    };

// ─── DailyForecast ────────────────────────────────────────────────────────

DailyForecast _$DailyForecastFromJson(Map<String, dynamic> json) =>
    _DailyForecast(
      date: json['date'] as String,
      weatherDescription: json['weatherDescription'] as String,
      weatherCode: json['weatherCode'] as String,
      pop: (json['pop'] as num).toInt(),
      maxTemperature: (json['maxTemperature'] as num).toDouble(),
      minTemperature: (json['minTemperature'] as num).toDouble(),
    );

Map<String, dynamic> _$DailyForecastToJson(DailyForecast instance) =>
    <String, dynamic>{
      'date': instance.date,
      'weatherDescription': instance.weatherDescription,
      'weatherCode': instance.weatherCode,
      'pop': instance.pop,
      'maxTemperature': instance.maxTemperature,
      'minTemperature': instance.minTemperature,
    };

// ─── WeatherCondition (backward-compatible) ──────────────────────────────

_WeatherCondition _$WeatherConditionFromJson(Map<String, dynamic> json) =>
    _WeatherCondition(
      wx: json['wx'] as String,
      pop: (json['pop'] as num).toInt(),
      t: (json['t'] as num).toInt(),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );

Map<String, dynamic> _$WeatherConditionToJson(_WeatherCondition instance) =>
    <String, dynamic>{
      'wx': instance.wx,
      'pop': instance.pop,
      't': instance.t,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
    };

// ─── RadarImage (backward-compatible) ────────────────────────────────────

_RadarImage _$RadarImageFromJson(Map<String, dynamic> json) =>
    _RadarImage(url: json['url'] as String, time: json['time'] as String);

Map<String, dynamic> _$RadarImageToJson(_RadarImage instance) =>
    <String, dynamic>{'url': instance.url, 'time': instance.time};
