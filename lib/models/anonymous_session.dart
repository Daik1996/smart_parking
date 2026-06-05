import 'dart:math';

enum DriverState {
  unknown,
  driving,
  parked,
  walking,
  left,
}

class AnonymousSession {
  final String token;
  final DateTime startTime;
  DriverState currentState;
  double lastLat;
  double lastLng;
  double lastSpeed;
  DateTime? parkedSince;
  String? currentSpotId;
  int stationaryReports;
  DateTime lastActivityTime;

  AnonymousSession({
    required this.token,
    required this.startTime,
    this.currentState = DriverState.unknown,
    this.lastLat = 0.0,
    this.lastLng = 0.0,
    this.lastSpeed = 0.0,
    this.parkedSince,
    this.currentSpotId,
    this.stationaryReports = 0,
    DateTime? lastActivityTime,
  }) : lastActivityTime = lastActivityTime ?? startTime;

  factory AnonymousSession.create() {
    final random = Random.secure();
    final token = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return AnonymousSession(token: token, startTime: DateTime.now());
  }

  Duration get sessionDuration => DateTime.now().difference(startTime);

  bool get hasParked => currentSpotId != null && parkedSince != null;

  Duration? get parkedDuration {
    if (parkedSince == null) return null;
    return DateTime.now().difference(parkedSince!);
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'startTime': startTime.toIso8601String(),
    'currentState': currentState.name,
    'lastLat': lastLat,
    'lastLng': lastLng,
    'lastSpeed': lastSpeed,
    'parkedSince': parkedSince?.toIso8601String(),
    'currentSpotId': currentSpotId,
    'stationaryReports': stationaryReports,
    'lastActivityTime': lastActivityTime.toIso8601String(),
  };
}
