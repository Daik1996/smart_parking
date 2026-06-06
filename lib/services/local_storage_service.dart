import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';

class LocalStorageService {
  static const String _spotsKey = 'parking_spots';

  Future<List<ParkingSpot>> getNearbySpots(double lat, double lng, {double radiusKm = 0.5}) async {
    final spots = await _getAllSpots();

    return spots.where((spot) {
      if (spot.isExpired) return false;
      final distance = _calculateDistance(lat, lng, spot.lat, spot.lng);
      return distance <= radiusKm * 1000;
    }).toList();
  }

  Future<ParkingSpot?> findSpotNear(double lat, double lng) async {
    final spots = await getNearbySpots(lat, lng, radiusKm: 0.01);
    for (final spot in spots) {
      final distance = _calculateDistance(lat, lng, spot.lat, spot.lng);
      if (distance < AppConfig.spotMergeDistanceMeters) {
        return spot;
      }
    }
    return null;
  }

  Future<void> saveSpot(ParkingSpot spot) async {
    final allSpots = await _getAllSpots();
    allSpots.removeWhere((s) => s.id == spot.id);
    allSpots.add(spot);
    await _saveAllSpots(allSpots);
  }

  Future<void> removeSpot(String spotId) async {
    final allSpots = await _getAllSpots();
    allSpots.removeWhere((s) => s.id == spotId);
    await _saveAllSpots(allSpots);
  }

  Future<void> cleanupExpiredSpots() async {
    final allSpots = await _getAllSpots();
    allSpots.removeWhere((s) => s.isExpired);
    await _saveAllSpots(allSpots);
  }

  Future<void> reportSpotFree(double lat, double lng) async {
    final existing = await findSpotNear(lat, lng);
    if (existing != null && existing.isFree) return;

    final now = DateTime.now();
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

  Future<void> reportSpotOccupied(double lat, double lng) async {
    final now = DateTime.now();
    final spot = ParkingSpot(
      id: _generateSpotId(lat, lng),
      lat: lat,
      lng: lng,
      status: SpotStatus.occupied,
      detectedFreeAt: now,
      detectedOccupiedAt: now,
      expiresAt: now.add(AppConfig.occupiedSpotExpiry),
      streetName: '',
    );
    await saveSpot(spot);
  }

  Future<List<ParkingSpot>> _getAllSpots() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_spotsKey);
    if (jsonStr == null) return [];

    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => ParkingSpot.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveAllSpots(List<ParkingSpot> spots) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(spots.map((s) => s.toJson()).toList());
    await prefs.setString(_spotsKey, jsonStr);
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
    final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
}
