enum SpotStatus { unknown, free, occupied, expired }

class ParkingSpot {
  final String id;
  final double lat;
  final double lng;
  final SpotStatus status;
  final DateTime detectedFreeAt;
  final DateTime detectedOccupiedAt;
  final DateTime expiresAt;
  final String streetName;
  final double? confidence;

  ParkingSpot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.status,
    required this.detectedFreeAt,
    required this.detectedOccupiedAt,
    required this.expiresAt,
    required this.streetName,
    this.confidence,
  });

  bool get isFree => status == SpotStatus.free;
  bool get isOccupied => status == SpotStatus.occupied;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lng': lng,
    'status': status.name,
    'detectedFreeAt': detectedFreeAt.toIso8601String(),
    'detectedOccupiedAt': detectedOccupiedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'streetName': streetName,
    'confidence': confidence,
  };

  factory ParkingSpot.fromJson(Map<String, dynamic> json) => ParkingSpot(
    id: json['id'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    status: SpotStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => SpotStatus.unknown,
    ),
    detectedFreeAt: DateTime.parse(json['detectedFreeAt'] as String),
    detectedOccupiedAt: DateTime.parse(json['detectedOccupiedAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    streetName: json['streetName'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble(),
  );
}
