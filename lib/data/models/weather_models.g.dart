// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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

_RadarImage _$RadarImageFromJson(Map<String, dynamic> json) =>
    _RadarImage(url: json['url'] as String, time: json['time'] as String);

Map<String, dynamic> _$RadarImageToJson(_RadarImage instance) =>
    <String, dynamic>{'url': instance.url, 'time': instance.time};
