import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../config/app_config.dart';

class LocationResult {
  final double lat;
  final double lng;
  final double speed;
  final DriverActivity activity;
  final bool isAccurate;
  final DateTime timestamp;

  LocationResult({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.activity,
    required this.isAccurate,
    required this.timestamp,
  });
}

enum DriverActivity {
  unknown,
  inVehicle,
  onFoot,
  walking,
  still,
}

class LocationService {
  StreamSubscription<Position>? _subscription;
  bool _isRunning = false;
  double? _previousLat;
  double? _previousLng;
  DateTime? _lastReportTime;
  int _consecutiveErrors = 0;
  LocationResult? _lastAccurateLocation;

  StreamController<LocationResult>? _controller;
  Stream<LocationResult>? get locationStream => _controller?.stream;

  Future<bool> requestPermissions() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> startMonitoring() async {
    if (_isRunning) return;
    _isRunning = true;
    _controller = StreamController<LocationResult>.broadcast();
    _consecutiveErrors = 0;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (e) => _handleError('GPS error: $e'),
    );
  }

  void _onPosition(Position pos) {
    final lat = pos.latitude;
    final lng = pos.longitude;
    final speed = pos.speed * 3.6;
    final accuracy = pos.accuracy;
    final isAccurate = accuracy < AppConfig.maxGpsDriftMeters;
    final now = DateTime.now();

    _consecutiveErrors = 0;

    final result = LocationResult(
      lat: lat,
      lng: lng,
      speed: speed,
      activity: _inferActivity(speed, lat, lng),
      isAccurate: isAccurate,
      timestamp: now,
    );

    if (isAccurate) {
      _lastAccurateLocation = result;
    }

    _controller?.add(result);

    _previousLat = lat;
    _previousLng = lng;
    _lastReportTime = now;
  }

  DriverActivity _inferActivity(double speedKmh, double lat, double lng) {
    if (speedKmh > AppConfig.minSpeedKmh) {
      if (speedKmh > 15.0) return DriverActivity.inVehicle;
      return DriverActivity.walking;
    }

    if (_previousLat != null && _previousLng != null) {
      final distance = _calculateDistance(
        _previousLat!, _previousLng!, lat, lng,
      );
      final elapsedMinutes = _lastReportTime != null
        ? DateTime.now().difference(_lastReportTime!).inMinutes
        : 5;
      if (elapsedMinutes > 0 && distance / elapsedMinutes > 10) {
        if (speedKmh > 2.0) return DriverActivity.walking;
        return DriverActivity.onFoot;
      }
    }

    if (speedKmh < 0.5) return DriverActivity.still;
    if (speedKmh < AppConfig.minSpeedKmh) return DriverActivity.walking;
    return DriverActivity.unknown;
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRadians(double degree) => degree * pi / 180;

  void _handleError(String msg) {
    _consecutiveErrors++;
    if (_consecutiveErrors >= 5 && _lastAccurateLocation != null) {
      _controller?.add(_lastAccurateLocation!);
    }
  }

  void stopMonitoring() {
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
  }

  void dispose() {
    stopMonitoring();
  }
}
