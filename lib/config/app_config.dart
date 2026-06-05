import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'SmartPark';
  static const String appVersion = '1.0.0';

  static const Duration reportInterval = Duration(minutes: 5);
  static const int stationaryReportsRequired = 3;
  static const double minSpeedKmh = 5.0;
  static const double spotMergeDistanceMeters = 5.0;
  static const Duration freeSpotExpiry = Duration(minutes: 30);
  static const Duration occupiedSpotExpiry = Duration(hours: 2);
  static const Duration sessionExpiry = Duration(hours: 2);
  static const double maxGpsDriftMeters = 15.0;

  static const String osmBaseUrl = 'https://overpass-api.de/api/interpreter';
  static const String madridLat = '40.4168';
  static const String madridLng = '-3.7038';

  static const Color colorFree = Color(0xFF00C853);
  static const Color colorOccupied = Color(0xFFFF1744);
  static const Color colorExpired = Color(0xFF9E9E9E);
  static const Color colorWarning = Color(0xFFFFD600);
  static const Color colorBackground = Color(0xFF1A1A2E);
  static const Color colorSurface = Color(0xFF16213E);
  static const Color colorAccent = Color(0xFF0F3460);
  static const Color colorText = Color(0xFFE8E8E8);
  static const Color colorTextSecondary = Color(0xFFB0B0B0);
}
