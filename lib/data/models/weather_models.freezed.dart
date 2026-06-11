// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'weather_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CurrentWeather {

/// 地點名稱
 String get locationName;/// 溫度（°C）
 double get temperature;/// 體感溫度（°C）
 double get feelsLike;/// 相對濕度（%）
 int get humidity;/// 風速（m/s）
 double get windSpeed;/// 天氣現象描述
 String get weatherDescription;/// 天氣現象碼（CWA code）
 String get weatherCode;///降雨機率（%）
 int get pop;/// 觀測時間（ISO 8601）
 String get observationTime;
/// Create a copy of CurrentWeather
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurrentWeatherCopyWith<CurrentWeather> get copyWith => _$CurrentWeatherCopyWithImpl<CurrentWeather>(this as CurrentWeather, _$identity);

  /// Serializes this CurrentWeather to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurrentWeather&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.feelsLike, feelsLike) || other.feelsLike == feelsLike)&&(identical(other.humidity, humidity) || other.humidity == humidity)&&(identical(other.windSpeed, windSpeed) || other.windSpeed == windSpeed)&&(identical(other.weatherDescription, weatherDescription) || other.weatherDescription == weatherDescription)&&(identical(other.weatherCode, weatherCode) || other.weatherCode == weatherCode)&&(identical(other.pop, pop) || other.pop == pop)&&(identical(other.observationTime, observationTime) || other.observationTime == observationTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationName,temperature,feelsLike,humidity,windSpeed,weatherDescription,weatherCode,pop,observationTime);

@override
String toString() {
  return 'CurrentWeather(locationName: $locationName, temperature: $temperature, feelsLike: $feelsLike, humidity: $humidity, windSpeed: $windSpeed, weatherDescription: $weatherDescription, weatherCode: $weatherCode, pop: $pop, observationTime: $observationTime)';
}


}

/// @nodoc
abstract mixin class $CurrentWeatherCopyWith<$Res>  {
  factory $CurrentWeatherCopyWith(CurrentWeather value, $Res Function(CurrentWeather) _then) = _$CurrentWeatherCopyWithImpl;
@useResult
$Res call({
 String locationName, double temperature, double feelsLike, int humidity, double windSpeed, String weatherDescription, String weatherCode, int pop, String observationTime
});




}
/// @nodoc
class _$CurrentWeatherCopyWithImpl<$Res>
    implements $CurrentWeatherCopyWith<$Res> {
  _$CurrentWeatherCopyWithImpl(this._self, this._then);

  final CurrentWeather _self;
  final $Res Function(CurrentWeather) _then;

/// Create a copy of CurrentWeather
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationName = null,Object? temperature = null,Object? feelsLike = null,Object? humidity = null,Object? windSpeed = null,Object? weatherDescription = null,Object? weatherCode = null,Object? pop = null,Object? observationTime = null,}) {
  return _then(_self.copyWith(
locationName: null == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,feelsLike: null == feelsLike ? _self.feelsLike : feelsLike // ignore: cast_nullable_to_non_nullable
as double,humidity: null == humidity ? _self.humidity : humidity // ignore: cast_nullable_to_non_nullable
as int,windSpeed: null == windSpeed ? _self.windSpeed : windSpeed // ignore: cast_nullable_to_non_nullable
as double,weatherDescription: null == weatherDescription ? _self.weatherDescription : weatherDescription // ignore: cast_nullable_to_non_nullable
as String,weatherCode: null == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as String,pop: null == pop ? _self.pop : pop // ignore: cast_nullable_to_non_nullable
as int,observationTime: null == observationTime ? _self.observationTime : observationTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CurrentWeather].
extension CurrentWeatherPatterns on CurrentWeather {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurrentWeather value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurrentWeather() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurrentWeather value)  $default,){
final _that = this;
switch (_that) {
case _CurrentWeather():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurrentWeather value)?  $default,){
final _that = this;
switch (_that) {
case _CurrentWeather() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String locationName,  double temperature,  double feelsLike,  int humidity,  double windSpeed,  String weatherDescription,  String weatherCode,  int pop,  String observationTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurrentWeather() when $default != null:
return $default(_that.locationName,_that.temperature,_that.feelsLike,_that.humidity,_that.windSpeed,_that.weatherDescription,_that.weatherCode,_that.pop,_that.observationTime);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String locationName,  double temperature,  double feelsLike,  int humidity,  double windSpeed,  String weatherDescription,  String weatherCode,  int pop,  String observationTime)  $default,) {final _that = this;
switch (_that) {
case _CurrentWeather():
return $default(_that.locationName,_that.temperature,_that.feelsLike,_that.humidity,_that.windSpeed,_that.weatherDescription,_that.weatherCode,_that.pop,_that.observationTime);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String locationName,  double temperature,  double feelsLike,  int humidity,  double windSpeed,  String weatherDescription,  String weatherCode,  int pop,  String observationTime)?  $default,) {final _that = this;
switch (_that) {
case _CurrentWeather() when $default != null:
return $default(_that.locationName,_that.temperature,_that.feelsLike,_that.humidity,_that.windSpeed,_that.weatherDescription,_that.weatherCode,_that.pop,_that.observationTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CurrentWeather extends CurrentWeather {
  const _CurrentWeather({required this.locationName, required this.temperature, required this.feelsLike, required this.humidity, required this.windSpeed, required this.weatherDescription, required this.weatherCode, required this.pop, required this.observationTime}): super._();
  factory _CurrentWeather.fromJson(Map<String, dynamic> json) => _$CurrentWeatherFromJson(json);

/// 地點名稱
@override final  String locationName;
/// 溫度（°C）
@override final  double temperature;
/// 體感溫度（°C）
@override final  double feelsLike;
/// 相對濕度（%）
@override final  int humidity;
/// 風速（m/s）
@override final  double windSpeed;
/// 天氣現象描述
@override final  String weatherDescription;
/// 天氣現象碼（CWA code）
@override final  String weatherCode;
///降雨機率（%）
@override final  int pop;
/// 觀測時間（ISO 8601）
@override final  String observationTime;

/// Create a copy of CurrentWeather
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurrentWeatherCopyWith<_CurrentWeather> get copyWith => __$CurrentWeatherCopyWithImpl<_CurrentWeather>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CurrentWeatherToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurrentWeather&&(identical(other.locationName, locationName) || other.locationName == locationName)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.feelsLike, feelsLike) || other.feelsLike == feelsLike)&&(identical(other.humidity, humidity) || other.humidity == humidity)&&(identical(other.windSpeed, windSpeed) || other.windSpeed == windSpeed)&&(identical(other.weatherDescription, weatherDescription) || other.weatherDescription == weatherDescription)&&(identical(other.weatherCode, weatherCode) || other.weatherCode == weatherCode)&&(identical(other.pop, pop) || other.pop == pop)&&(identical(other.observationTime, observationTime) || other.observationTime == observationTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationName,temperature,feelsLike,humidity,windSpeed,weatherDescription,weatherCode,pop,observationTime);

@override
String toString() {
  return 'CurrentWeather(locationName: $locationName, temperature: $temperature, feelsLike: $feelsLike, humidity: $humidity, windSpeed: $windSpeed, weatherDescription: $weatherDescription, weatherCode: $weatherCode, pop: $pop, observationTime: $observationTime)';
}


}

/// @nodoc
abstract mixin class _$CurrentWeatherCopyWith<$Res> implements $CurrentWeatherCopyWith<$Res> {
  factory _$CurrentWeatherCopyWith(_CurrentWeather value, $Res Function(_CurrentWeather) _then) = __$CurrentWeatherCopyWithImpl;
@override @useResult
$Res call({
 String locationName, double temperature, double feelsLike, int humidity, double windSpeed, String weatherDescription, String weatherCode, int pop, String observationTime
});




}
/// @nodoc
class __$CurrentWeatherCopyWithImpl<$Res>
    implements _$CurrentWeatherCopyWith<$Res> {
  __$CurrentWeatherCopyWithImpl(this._self, this._then);

  final _CurrentWeather _self;
  final $Res Function(_CurrentWeather) _then;

/// Create a copy of CurrentWeather
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationName = null,Object? temperature = null,Object? feelsLike = null,Object? humidity = null,Object? windSpeed = null,Object? weatherDescription = null,Object? weatherCode = null,Object? pop = null,Object? observationTime = null,}) {
  return _then(_CurrentWeather(
locationName: null == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,feelsLike: null == feelsLike ? _self.feelsLike : feelsLike // ignore: cast_nullable_to_non_nullable
as double,humidity: null == humidity ? _self.humidity : humidity // ignore: cast_nullable_to_non_nullable
as int,windSpeed: null == windSpeed ? _self.windSpeed : windSpeed // ignore: cast_nullable_to_non_nullable
as double,weatherDescription: null == weatherDescription ? _self.weatherDescription : weatherDescription // ignore: cast_nullable_to_non_nullable
as String,weatherCode: null == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as String,pop: null == pop ? _self.pop : pop // ignore: cast_nullable_to_non_nullable
as int,observationTime: null == observationTime ? _self.observationTime : observationTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$WeeklyForecast {

/// 地點名稱
 String get locationName;/// 每日預報列表
 List<DailyForecast> get days;
/// Create a copy of WeeklyForecast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeeklyForecastCopyWith<WeeklyForecast> get copyWith => _$WeeklyForecastCopyWithImpl<WeeklyForecast>(this as WeeklyForecast, _$identity);

  /// Serializes this WeeklyForecast to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeeklyForecast&&(identical(other.locationName, locationName) || other.locationName == locationName)&&const DeepCollectionEquality().equals(other.days, days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationName,const DeepCollectionEquality().hash(days));

@override
String toString() {
  return 'WeeklyForecast(locationName: $locationName, days: $days)';
}


}

/// @nodoc
abstract mixin class $WeeklyForecastCopyWith<$Res>  {
  factory $WeeklyForecastCopyWith(WeeklyForecast value, $Res Function(WeeklyForecast) _then) = _$WeeklyForecastCopyWithImpl;
@useResult
$Res call({
 String locationName, List<DailyForecast> days
});




}
/// @nodoc
class _$WeeklyForecastCopyWithImpl<$Res>
    implements $WeeklyForecastCopyWith<$Res> {
  _$WeeklyForecastCopyWithImpl(this._self, this._then);

  final WeeklyForecast _self;
  final $Res Function(WeeklyForecast) _then;

/// Create a copy of WeeklyForecast
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locationName = null,Object? days = null,}) {
  return _then(_self.copyWith(
locationName: null == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as List<DailyForecast>,
  ));
}

}


/// Adds pattern-matching-related methods to [WeeklyForecast].
extension WeeklyForecastPatterns on WeeklyForecast {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeeklyForecast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeeklyForecast() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeeklyForecast value)  $default,){
final _that = this;
switch (_that) {
case _WeeklyForecast():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeeklyForecast value)?  $default,){
final _that = this;
switch (_that) {
case _WeeklyForecast() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String locationName,  List<DailyForecast> days)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeeklyForecast() when $default != null:
return $default(_that.locationName,_that.days);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String locationName,  List<DailyForecast> days)  $default,) {final _that = this;
switch (_that) {
case _WeeklyForecast():
return $default(_that.locationName,_that.days);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String locationName,  List<DailyForecast> days)?  $default,) {final _that = this;
switch (_that) {
case _WeeklyForecast() when $default != null:
return $default(_that.locationName,_that.days);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeeklyForecast extends WeeklyForecast {
  const _WeeklyForecast({required this.locationName, required final  List<DailyForecast> days}): _days = days,super._();
  factory _WeeklyForecast.fromJson(Map<String, dynamic> json) => _$WeeklyForecastFromJson(json);

/// 地點名稱
@override final  String locationName;
/// 每日預報列表
 final  List<DailyForecast> _days;
/// 每日預報列表
@override List<DailyForecast> get days {
  if (_days is EqualUnmodifiableListView) return _days;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_days);
}


/// Create a copy of WeeklyForecast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeeklyForecastCopyWith<_WeeklyForecast> get copyWith => __$WeeklyForecastCopyWithImpl<_WeeklyForecast>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeeklyForecastToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeeklyForecast&&(identical(other.locationName, locationName) || other.locationName == locationName)&&const DeepCollectionEquality().equals(other._days, _days));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,locationName,const DeepCollectionEquality().hash(_days));

@override
String toString() {
  return 'WeeklyForecast(locationName: $locationName, days: $days)';
}


}

/// @nodoc
abstract mixin class _$WeeklyForecastCopyWith<$Res> implements $WeeklyForecastCopyWith<$Res> {
  factory _$WeeklyForecastCopyWith(_WeeklyForecast value, $Res Function(_WeeklyForecast) _then) = __$WeeklyForecastCopyWithImpl;
@override @useResult
$Res call({
 String locationName, List<DailyForecast> days
});




}
/// @nodoc
class __$WeeklyForecastCopyWithImpl<$Res>
    implements _$WeeklyForecastCopyWith<$Res> {
  __$WeeklyForecastCopyWithImpl(this._self, this._then);

  final _WeeklyForecast _self;
  final $Res Function(_WeeklyForecast) _then;

/// Create a copy of WeeklyForecast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locationName = null,Object? days = null,}) {
  return _then(_WeeklyForecast(
locationName: null == locationName ? _self.locationName : locationName // ignore: cast_nullable_to_non_nullable
as String,days: null == days ? _self._days : days // ignore: cast_nullable_to_non_nullable
as List<DailyForecast>,
  ));
}


}


/// @nodoc
mixin _$DailyForecast {

/// 日期（YYYY-MM-DD）
 String get date;/// 天氣現象描述
 String get weatherDescription;/// 天氣現象碼（CWA code）
 String get weatherCode;/// 降雨機率（%）
 int get pop;/// 最高溫度（°C）
 double get maxTemperature;/// 最低溫度（°C）
 double get minTemperature;
/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyForecastCopyWith<DailyForecast> get copyWith => _$DailyForecastCopyWithImpl<DailyForecast>(this as DailyForecast, _$identity);

  /// Serializes this DailyForecast to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyForecast&&(identical(other.date, date) || other.date == date)&&(identical(other.weatherDescription, weatherDescription) || other.weatherDescription == weatherDescription)&&(identical(other.weatherCode, weatherCode) || other.weatherCode == weatherCode)&&(identical(other.pop, pop) || other.pop == pop)&&(identical(other.maxTemperature, maxTemperature) || other.maxTemperature == maxTemperature)&&(identical(other.minTemperature, minTemperature) || other.minTemperature == minTemperature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,weatherDescription,weatherCode,pop,maxTemperature,minTemperature);

@override
String toString() {
  return 'DailyForecast(date: $date, weatherDescription: $weatherDescription, weatherCode: $weatherCode, pop: $pop, maxTemperature: $maxTemperature, minTemperature: $minTemperature)';
}


}

/// @nodoc
abstract mixin class $DailyForecastCopyWith<$Res>  {
  factory $DailyForecastCopyWith(DailyForecast value, $Res Function(DailyForecast) _then) = _$DailyForecastCopyWithImpl;
@useResult
$Res call({
 String date, String weatherDescription, String weatherCode, int pop, double maxTemperature, double minTemperature
});




}
/// @nodoc
class _$DailyForecastCopyWithImpl<$Res>
    implements $DailyForecastCopyWith<$Res> {
  _$DailyForecastCopyWithImpl(this._self, this._then);

  final DailyForecast _self;
  final $Res Function(DailyForecast) _then;

/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? weatherDescription = null,Object? weatherCode = null,Object? pop = null,Object? maxTemperature = null,Object? minTemperature = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,weatherDescription: null == weatherDescription ? _self.weatherDescription : weatherDescription // ignore: cast_nullable_to_non_nullable
as String,weatherCode: null == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as String,pop: null == pop ? _self.pop : pop // ignore: cast_nullable_to_non_nullable
as int,maxTemperature: null == maxTemperature ? _self.maxTemperature : maxTemperature // ignore: cast_nullable_to_non_nullable
as double,minTemperature: null == minTemperature ? _self.minTemperature : minTemperature // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyForecast].
extension DailyForecastPatterns on DailyForecast {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyForecast value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyForecast value)  $default,){
final _that = this;
switch (_that) {
case _DailyForecast():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyForecast value)?  $default,){
final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  String weatherDescription,  String weatherCode,  int pop,  double maxTemperature,  double minTemperature)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that.date,_that.weatherDescription,_that.weatherCode,_that.pop,_that.maxTemperature,_that.minTemperature);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  String weatherDescription,  String weatherCode,  int pop,  double maxTemperature,  double minTemperature)  $default,) {final _that = this;
switch (_that) {
case _DailyForecast():
return $default(_that.date,_that.weatherDescription,_that.weatherCode,_that.pop,_that.maxTemperature,_that.minTemperature);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  String weatherDescription,  String weatherCode,  int pop,  double maxTemperature,  double minTemperature)?  $default,) {final _that = this;
switch (_that) {
case _DailyForecast() when $default != null:
return $default(_that.date,_that.weatherDescription,_that.weatherCode,_that.pop,_that.maxTemperature,_that.minTemperature);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DailyForecast extends DailyForecast {
  const _DailyForecast({required this.date, required this.weatherDescription, required this.weatherCode, required this.pop, required this.maxTemperature, required this.minTemperature}): super._();
  factory _DailyForecast.fromJson(Map<String, dynamic> json) => _$DailyForecastFromJson(json);

/// 日期（YYYY-MM-DD）
@override final  String date;
/// 天氣現象描述
@override final  String weatherDescription;
/// 天氣現象碼（CWA code）
@override final  String weatherCode;
/// 降雨機率（%）
@override final  int pop;
/// 最高溫度（°C）
@override final  double maxTemperature;
/// 最低溫度（°C）
@override final  double minTemperature;

/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyForecastCopyWith<_DailyForecast> get copyWith => __$DailyForecastCopyWithImpl<_DailyForecast>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DailyForecastToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyForecast&&(identical(other.date, date) || other.date == date)&&(identical(other.weatherDescription, weatherDescription) || other.weatherDescription == weatherDescription)&&(identical(other.weatherCode, weatherCode) || other.weatherCode == weatherCode)&&(identical(other.pop, pop) || other.pop == pop)&&(identical(other.maxTemperature, maxTemperature) || other.maxTemperature == maxTemperature)&&(identical(other.minTemperature, minTemperature) || other.minTemperature == minTemperature));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,weatherDescription,weatherCode,pop,maxTemperature,minTemperature);

@override
String toString() {
  return 'DailyForecast(date: $date, weatherDescription: $weatherDescription, weatherCode: $weatherCode, pop: $pop, maxTemperature: $maxTemperature, minTemperature: $minTemperature)';
}


}

/// @nodoc
abstract mixin class _$DailyForecastCopyWith<$Res> implements $DailyForecastCopyWith<$Res> {
  factory _$DailyForecastCopyWith(_DailyForecast value, $Res Function(_DailyForecast) _then) = __$DailyForecastCopyWithImpl;
@override @useResult
$Res call({
 String date, String weatherDescription, String weatherCode, int pop, double maxTemperature, double minTemperature
});




}
/// @nodoc
class __$DailyForecastCopyWithImpl<$Res>
    implements _$DailyForecastCopyWith<$Res> {
  __$DailyForecastCopyWithImpl(this._self, this._then);

  final _DailyForecast _self;
  final $Res Function(_DailyForecast) _then;

/// Create a copy of DailyForecast
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? weatherDescription = null,Object? weatherCode = null,Object? pop = null,Object? maxTemperature = null,Object? minTemperature = null,}) {
  return _then(_DailyForecast(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,weatherDescription: null == weatherDescription ? _self.weatherDescription : weatherDescription // ignore: cast_nullable_to_non_nullable
as String,weatherCode: null == weatherCode ? _self.weatherCode : weatherCode // ignore: cast_nullable_to_non_nullable
as String,pop: null == pop ? _self.pop : pop // ignore: cast_nullable_to_non_nullable
as int,maxTemperature: null == maxTemperature ? _self.maxTemperature : maxTemperature // ignore: cast_nullable_to_non_nullable
as double,minTemperature: null == minTemperature ? _self.minTemperature : minTemperature // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$WeatherCondition {

 String get wx; int get pop; int get t; String get startTime; String get endTime;
/// Create a copy of WeatherCondition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeatherConditionCopyWith<WeatherCondition> get copyWith => _$WeatherConditionCopyWithImpl<WeatherCondition>(this as WeatherCondition, _$identity);

  /// Serializes this WeatherCondition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeatherCondition&&(identical(other.wx, wx) || other.wx == wx)&&(identical(other.pop, pop) || other.pop == pop)&&(identical(other.t, t) || other.t == t)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,wx,pop,t,startTime,endTime);

@override
String toString() {
  return 'WeatherCondition(wx: $wx, pop: $pop, t: $t, startTime: $startTime, endTime: $endTime)';
}


}

/// @nodoc
abstract mixin class $WeatherConditionCopyWith<$Res>  {
  factory $WeatherConditionCopyWith(WeatherCondition value, $Res Function(WeatherCondition) _then) = _$WeatherConditionCopyWithImpl;
@useResult
$Res call({
 String wx, int pop, int t, String startTime, String endTime
});




}
/// @nodoc
class _$WeatherConditionCopyWithImpl<$Res>
    implements $WeatherConditionCopyWith<$Res> {
  _$WeatherConditionCopyWithImpl(this._self, this._then);

  final WeatherCondition _self;
  final $Res Function(WeatherCondition) _then;

/// Create a copy of WeatherCondition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? wx = null,Object? pop = null,Object? t = null,Object? startTime = null,Object? endTime = null,}) {
  return _then(_self.copyWith(
wx: null == wx ? _self.wx : wx // ignore: cast_nullable_to_non_nullable
as String,pop: null == pop ? _self.pop : pop // ignore: cast_nullable_to_non_nullable
as int,t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as int,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WeatherCondition].
extension WeatherConditionPatterns on WeatherCondition {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeatherCondition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeatherCondition() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeatherCondition value)  $default,){
final _that = this;
switch (_that) {
case _WeatherCondition():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeatherCondition value)?  $default,){
final _that = this;
switch (_that) {
case _WeatherCondition() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String wx,  int pop,  int t,  String startTime,  String endTime)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeatherCondition() when $default != null:
return $default(_that.wx,_that.pop,_that.t,_that.startTime,_that.endTime);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String wx,  int pop,  int t,  String startTime,  String endTime)  $default,) {final _that = this;
switch (_that) {
case _WeatherCondition():
return $default(_that.wx,_that.pop,_that.t,_that.startTime,_that.endTime);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String wx,  int pop,  int t,  String startTime,  String endTime)?  $default,) {final _that = this;
switch (_that) {
case _WeatherCondition() when $default != null:
return $default(_that.wx,_that.pop,_that.t,_that.startTime,_that.endTime);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WeatherCondition implements WeatherCondition {
  const _WeatherCondition({required this.wx, required this.pop, required this.t, required this.startTime, required this.endTime});
  factory _WeatherCondition.fromJson(Map<String, dynamic> json) => _$WeatherConditionFromJson(json);

@override final  String wx;
@override final  int pop;
@override final  int t;
@override final  String startTime;
@override final  String endTime;

/// Create a copy of WeatherCondition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeatherConditionCopyWith<_WeatherCondition> get copyWith => __$WeatherConditionCopyWithImpl<_WeatherCondition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WeatherConditionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeatherCondition&&(identical(other.wx, wx) || other.wx == wx)&&(identical(other.pop, pop) || other.pop == pop)&&(identical(other.t, t) || other.t == t)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,wx,pop,t,startTime,endTime);

@override
String toString() {
  return 'WeatherCondition(wx: $wx, pop: $pop, t: $t, startTime: $startTime, endTime: $endTime)';
}


}

/// @nodoc
abstract mixin class _$WeatherConditionCopyWith<$Res> implements $WeatherConditionCopyWith<$Res> {
  factory _$WeatherConditionCopyWith(_WeatherCondition value, $Res Function(_WeatherCondition) _then) = __$WeatherConditionCopyWithImpl;
@override @useResult
$Res call({
 String wx, int pop, int t, String startTime, String endTime
});




}
/// @nodoc
class __$WeatherConditionCopyWithImpl<$Res>
    implements _$WeatherConditionCopyWith<$Res> {
  __$WeatherConditionCopyWithImpl(this._self, this._then);

  final _WeatherCondition _self;
  final $Res Function(_WeatherCondition) _then;

/// Create a copy of WeatherCondition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? wx = null,Object? pop = null,Object? t = null,Object? startTime = null,Object? endTime = null,}) {
  return _then(_WeatherCondition(
wx: null == wx ? _self.wx : wx // ignore: cast_nullable_to_non_nullable
as String,pop: null == pop ? _self.pop : pop // ignore: cast_nullable_to_non_nullable
as int,t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as int,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RadarImage {

 String get url; String get time;
/// Create a copy of RadarImage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RadarImageCopyWith<RadarImage> get copyWith => _$RadarImageCopyWithImpl<RadarImage>(this as RadarImage, _$identity);

  /// Serializes this RadarImage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RadarImage&&(identical(other.url, url) || other.url == url)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,time);

@override
String toString() {
  return 'RadarImage(url: $url, time: $time)';
}


}

/// @nodoc
abstract mixin class $RadarImageCopyWith<$Res>  {
  factory $RadarImageCopyWith(RadarImage value, $Res Function(RadarImage) _then) = _$RadarImageCopyWithImpl;
@useResult
$Res call({
 String url, String time
});




}
/// @nodoc
class _$RadarImageCopyWithImpl<$Res>
    implements $RadarImageCopyWith<$Res> {
  _$RadarImageCopyWithImpl(this._self, this._then);

  final RadarImage _self;
  final $Res Function(RadarImage) _then;

/// Create a copy of RadarImage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? url = null,Object? time = null,}) {
  return _then(_self.copyWith(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RadarImage].
extension RadarImagePatterns on RadarImage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RadarImage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RadarImage() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RadarImage value)  $default,){
final _that = this;
switch (_that) {
case _RadarImage():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RadarImage value)?  $default,){
final _that = this;
switch (_that) {
case _RadarImage() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String url,  String time)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RadarImage() when $default != null:
return $default(_that.url,_that.time);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String url,  String time)  $default,) {final _that = this;
switch (_that) {
case _RadarImage():
return $default(_that.url,_that.time);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String url,  String time)?  $default,) {final _that = this;
switch (_that) {
case _RadarImage() when $default != null:
return $default(_that.url,_that.time);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RadarImage implements RadarImage {
  const _RadarImage({required this.url, required this.time});
  factory _RadarImage.fromJson(Map<String, dynamic> json) => _$RadarImageFromJson(json);

@override final  String url;
@override final  String time;

/// Create a copy of RadarImage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RadarImageCopyWith<_RadarImage> get copyWith => __$RadarImageCopyWithImpl<_RadarImage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RadarImageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RadarImage&&(identical(other.url, url) || other.url == url)&&(identical(other.time, time) || other.time == time));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,url,time);

@override
String toString() {
  return 'RadarImage(url: $url, time: $time)';
}


}

/// @nodoc
abstract mixin class _$RadarImageCopyWith<$Res> implements $RadarImageCopyWith<$Res> {
  factory _$RadarImageCopyWith(_RadarImage value, $Res Function(_RadarImage) _then) = __$RadarImageCopyWithImpl;
@override @useResult
$Res call({
 String url, String time
});




}
/// @nodoc
class __$RadarImageCopyWithImpl<$Res>
    implements _$RadarImageCopyWith<$Res> {
  __$RadarImageCopyWithImpl(this._self, this._then);

  final _RadarImage _self;
  final $Res Function(_RadarImage) _then;

/// Create a copy of RadarImage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? url = null,Object? time = null,}) {
  return _then(_RadarImage(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
