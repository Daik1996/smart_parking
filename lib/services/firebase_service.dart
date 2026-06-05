import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/parking_spot.dart';
import '../config/app_config.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _anonymousUid;

  Future<void> initializeAnonymousSession() async {
    try {
      await _auth.signInAnonymously();
      _anonymousUid = _auth.currentUser?.uid;
    } catch (e) {
      _anonymousUid = 'anon_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  String? get currentUserId => _anonymousUid;

  Future<List<ParkingSpot>> getNearbySpots(double lat, double lng, {double radiusKm = 0.5}) async {
    try {
      final latDelta = radiusKm / 111.0;

      final snapshot = await _db
        .collection('spots')
        .where('lat', isGreaterThanOrEqualTo: lat - latDelta)
        .where('lat', isLessThanOrEqualTo: lat + latDelta)
        .where('status', whereIn: ['free', 'occupied'])
        .get();

      final spots = <ParkingSpot>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final spot = ParkingSpot.fromJson(data);
        if (!spot.isExpired) {
          final spotLngDelta = radiusKm / (111.0 * _cosDegrees(spot.lat));
          if ((spot.lng - lng).abs() <= spotLngDelta) {
            spots.add(spot);
          }
        }
      }
      return spots;
    } catch (e) {
      return [];
    }
  }

  Future<ParkingSpot?> findSpotNear(double lat, double lng) async {
    try {
      final spots = await getNearbySpots(lat, lng, radiusKm: 0.01);
      for (final spot in spots) {
        final distance = _calculateDistance(lat, lng, spot.lat, spot.lng);
        if (distance < AppConfig.spotMergeDistanceMeters) {
          return spot;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSpot(ParkingSpot spot) async {
    try {
      await _db.collection('spots').doc(spot.id).set(spot.toJson());
    } catch (e) {
      // Silently retry once
      try {
        await _db.collection('spots').doc(spot.id).set(spot.toJson());
      } catch (_) {}
    }
  }

  Future<void> removeSpot(String spotId) async {
    try {
      await _db.collection('spots').doc(spotId).delete();
    } catch (_) {}
  }

  Future<void> cleanupExpiredSpots() async {
    try {
      final now = DateTime.now().toIso8601String();
      final expired = await _db
        .collection('spots')
        .where('expiresAt', isLessThan: now)
        .get();

      final batch = _db.batch();
      for (final doc in expired.docs) { batch.delete(doc.reference); }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> reportSpotFree(double lat, double lng) async {
    final now = DateTime.now();
    final existing = await findSpotNear(lat, lng);
    if (existing != null && existing.isFree) return;

    final spot = ParkingSpot(
      id: _generateSpotId(lat, lng),
      lat: lat,
      lng: lng,
      status: SpotStatus.free,
      detectedFreeAt: now,
      detectedOccupiedAt: now,
      expiresAt: now.add(AppConfig.freeSpotExpiry),
      streetName: '',
    );
    await saveSpot(spot);
  }

  String _generateSpotId(double lat, double lng) {
    final roundedLat = (lat * 1000).round().toString();
    final roundedLng = (lng * 1000).round().toString();
    return '${roundedLat}_$roundedLng';
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
      _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
      _sin(dLng / 2) * _sin(dLng / 2);
    return R * 2 * _atan2(_sqrt(a), _sqrt(1 - a));
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  double _cosDegrees(double deg) => _cos(_toRadians(deg));
  double _sin(double x) => x - (x * x * x) / 6;
  double _cos(double x) => 1 - (x * x) / 2;
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double z = x;
    for (int i = 0; i < 10; i++) { z = (z + x / z) / 2; }
    return z;
  }
  double _atan2(double y, double x) {
    if (x == 0) return y > 0 ? 1.5707963267948966 : -1.5707963267948966;
    final z = y / x;
    if (z.abs() < 1) return z - (z * z * z) / 3;
    return 1.5707963267948966 - z / (z * z + 1);
  }

  void dispose() {}
}
