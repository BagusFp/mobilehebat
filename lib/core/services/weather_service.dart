import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Data model cuaca & suhu destinasi lereng Merapi
class DestinationWeather {
  final double currentTemp;
  final double minTemp;
  final double maxTemp;
  final int humidity;
  final String condition;
  final bool isLive;

  const DestinationWeather({
    required this.currentTemp,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.condition,
    this.isLive = true,
  });

  /// Rentang suhu (misal 17°C - 25°C)
  String get rangeString => '${minTemp.round()}°C - ${maxTemp.round()}°C';

  /// Suhu saat ini terformat (misal 23.4°C)
  String get displayTemp => '${currentTemp.toStringAsFixed(1)}°C';

  /// Keterangan status cuaca
  String get subValue => isLive ? 'Live • $condition' : 'Elevasi mdpl • $condition';
}

/// Service cuaca & suhu real-time untuk destinasi lereng Merapi
/// Menggunakan Open-Meteo API (Free, tanpa API key, akurat berbasis koordinat & elevasi)
/// Dilengkapi kalkulasi lapse rate elevasi otomatis jika perangkat sedang offline
class WeatherService {
  static final Map<String, DestinationWeather> _cache = {};

  /// Mengambil data suhu & cuaca live untuk koordinat dan elevasi destinasi tertentu
  static Future<DestinationWeather> getWeatherForDestination({
    required double latitude,
    required double longitude,
    required int elevationMdpl,
    String? fallbackRange,
  }) async {
    final cacheKey = '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,weather_code'
        '&daily=temperature_2m_max,temperature_2m_min&timezone=Asia%2FJakarta',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>;
        final daily = data['daily'] as Map<String, dynamic>;

        final currentTemp = (current['temperature_2m'] as num).toDouble();
        final humidity = (current['relative_humidity_2m'] as num).toInt();
        final code = (current['weather_code'] as num).toInt();

        final minList = daily['temperature_2m_min'] as List;
        final maxList = daily['temperature_2m_max'] as List;
        final minTemp = minList.isNotEmpty ? (minList[0] as num).toDouble() : (currentTemp - 4.0);
        final maxTemp = maxList.isNotEmpty ? (maxList[0] as num).toDouble() : (currentTemp + 4.0);

        final condition = _getWeatherCondition(code);

        final weather = DestinationWeather(
          currentTemp: currentTemp,
          minTemp: minTemp,
          maxTemp: maxTemp,
          humidity: humidity,
          condition: condition,
          isLive: true,
        );

        _cache[cacheKey] = weather;
        return weather;
      }
    } catch (e) {
      debugPrint('WeatherService fetch live error (using elevation lapse fallback): $e');
    }

    // Fallback ilmiah berbasis lapse rate ketinggian mdpl Gunung Merapi
    // Suhu permukaan laut tropis ~29.5°C, berkurang ~0.65°C per 100 mdpl
    final effectiveElevation = elevationMdpl > 0 ? elevationMdpl : 800;
    final lapse = (effectiveElevation / 100.0) * 0.65;
    final estimatedAvg = (29.5 - lapse).clamp(13.0, 31.0);
    final minT = (estimatedAvg - 3.5).roundToDouble();
    final maxT = (estimatedAvg + 3.5).roundToDouble();

    final fallback = DestinationWeather(
      currentTemp: estimatedAvg,
      minTemp: minT,
      maxTemp: maxT,
      humidity: 78,
      condition: effectiveElevation >= 1000 ? 'Sejuk berkabut' : 'Sejuk lereng',
      isLive: false,
    );

    _cache[cacheKey] = fallback;
    return fallback;
  }

  static String _getWeatherCondition(int code) {
    if (code == 0) return 'Cerah';
    if (code == 1 || code == 2) return 'Cerah berawan';
    if (code == 3) return 'Berawan';
    if (code == 45 || code == 48) return 'Berkabut';
    if (code >= 51 && code <= 67) return 'Gerimis';
    if (code >= 80 && code <= 82) return 'Hujan';
    if (code >= 95) return 'Hujan petir';
    return 'Sejuk';
  }
}
