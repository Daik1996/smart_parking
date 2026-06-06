import 'dart:async';
import '../config/app_config.dart';
import '../models/anonymous_session.dart';
import 'location_service.dart';
import 'local_storage_service.dart';
import 'osm_service.dart';

enum StateTransitionResult {
  none,
  spotFreed,
  spotOccupied,
  spotExpired,
  error,
}

class ParkingLogicService {
  final LocalStorageService _storage;
  final OsmService _osm;

  AnonymousSession? _session;
  final List<LocationResult> _recentLocations = [];
  final List<bool> _stationaryWindow = [];
  Timer? _cleanupTimer;

  StreamController<ParkingEvent>? _eventController;
  Stream<ParkingEvent>? get events => _eventController?.stream;

  ParkingLogicService({
    required LocalStorageService storage,
    required OsmService osm,
  }) : _storage = storage, _osm = osm;

  Future<void> startSession() async {
    _session = AnonymousSession.create();
    _recentLocations.clear();
    _stationaryWindow.clear();
    _eventController = StreamController<ParkingEvent>.broadcast();
    _startCleanupTimer();
  }

  Future<StateTransitionResult> processLocation(LocationResult location) async {
    if (_session == null) return StateTransitionResult.error;

    _recentLocations.add(location);
    if (_recentLocations.length > 10) _recentLocations.removeAt(0);

    _stationaryWindow.add(location.speed < 0.5 && location.activity == DriverActivity.still);
    if (_stationaryWindow.length > AppConfig.stationaryReportsRequired + 1) {
      _stationaryWindow.removeAt(0);
    }

    _session!.lastLat = location.lat;
    _session!.lastLng = location.lng;
    _session!.lastSpeed = location.speed;

    final result = await _evaluateState(location);
    return result;
  }

  Future<StateTransitionResult> _evaluateState(LocationResult location) async {
    if (_session == null) return StateTransitionResult.none;

    final previousState = _session!.currentState;
    final isNowStationary = location.speed < 0.5 && location.activity == DriverActivity.still;
    final isNowDriving = location.speed >= AppConfig.minSpeedKmh;
    final isNowWalking = location.activity == DriverActivity.walking
      || location.activity == DriverActivity.onFoot;

    if (isNowDriving && previousState == DriverState.parked) {
      return await _handleDriverLeft(location);
    }

    if (isNowStationary) {
      return await _handleStationary(location);
    }

    if (isNowWalking && previousState == DriverState.driving && location.speed < AppConfig.minSpeedKmh) {
      return await _handleDriverParked(location);
    }

    if (isNowWalking && previousState != DriverState.parked) {
      _session!.currentState = DriverState.walking;
      _publishEvent(ParkingEvent(DriverState.walking, 'Conductor andando', location));
    }

    if (isNowDriving && previousState == DriverState.walking) {
      _session!.currentState = DriverState.driving;
      _publishEvent(ParkingEvent(DriverState.driving, 'Conductor conduciendo', location));
    }

    if (isNowDriving && previousState == DriverState.unknown) {
      _session!.currentState = DriverState.driving;
      _publishEvent(ParkingEvent(DriverState.driving, 'Viaje iniciado', location));
    }

    return StateTransitionResult.none;
  }

  Future<StateTransitionResult> _handleStationary(LocationResult location) async {
    if (_session == null) return StateTransitionResult.none;

    _session!.stationaryReports++;

    if (_session!.stationaryReports >= AppConfig.stationaryReportsRequired) {
      if (_session!.currentState == DriverState.driving || _session!.currentState == DriverState.unknown) {
        final canPark = await _osm.canParkHere(location.lat, location.lng);
        if (!canPark) {
          _session!.stationaryReports = 0;
          return StateTransitionResult.none;
        }

        final existingSpot = await _storage.findSpotNear(location.lat, location.lng);
        if (existingSpot != null && existingSpot.isOccupied) {
          _session!.stationaryReports = 0;
          return StateTransitionResult.none;
        }

        return await _handleDriverParked(location);
      }
    }

    return StateTransitionResult.none;
  }

  Future<StateTransitionResult> _handleDriverParked(LocationResult location) async {
    if (_session == null) return StateTransitionResult.none;

    _session!.currentState = DriverState.parked;
    _session!.parkedSince = DateTime.now();
    _session!.stationaryReports = 0;

    final spotId = _generateSpotId(location.lat, location.lng);
    _session!.currentSpotId = spotId;

    await _storage.reportSpotOccupied(location.lat, location.lng);
    _publishEvent(ParkingEvent(DriverState.parked, 'Coche aparcado aquí', location, spotId: spotId));

    return StateTransitionResult.spotOccupied;
  }

  Future<StateTransitionResult> _handleDriverLeft(LocationResult location) async {
    if (_session == null) return StateTransitionResult.none;
    if (_session!.currentSpotId == null) return StateTransitionResult.none;

    final oldSpotId = _session!.currentSpotId;

    await _storage.reportSpotFree(location.lat, location.lng);
    await _storage.removeSpot(oldSpotId!);

    _session!.currentState = DriverState.left;
    _session!.currentSpotId = null;
    _session!.parkedSince = null;
    _session!.stationaryReports = 0;

    _publishEvent(ParkingEvent(DriverState.left, 'Plaza libre disponible', location, spotId: _generateSpotId(location.lat, location.lng)));

    return StateTransitionResult.spotFreed;
  }

  String _generateSpotId(double lat, double lng) {
    final roundedLat = (lat * 1000).round().toString();
    final roundedLng = (lng * 1000).round().toString();
    return '${roundedLat}_$roundedLng';
  }

  void _publishEvent(ParkingEvent event) {
    _eventController?.add(event);
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        await _storage.cleanupExpiredSpots();
      } catch (_) {}
    });
  }

  void endSession() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _recentLocations.clear();
    _stationaryWindow.clear();

    if (_session?.currentSpotId != null) {
      _storage.removeSpot(_session!.currentSpotId!);
    }

    _session = null;
    _eventController?.close();
  }

  void dispose() {
    endSession();
  }
}

class ParkingEvent {
  final DriverState state;
  final String message;
  final LocationResult location;
  final String? spotId;

  ParkingEvent(this.state, this.message, this.location, {this.spotId});
}
