import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class OsmRestriction {
  final bool canPark;
  final bool isPaid;
  final bool isPermitOnly;
  final bool isDisabledOnly;
  final bool isLoadingZone;
  final bool isMaxStay;
  final String? maxStayDuration;
  final String? restrictionHours;
  final String? restrictionType;

  OsmRestriction({
    this.canPark = true,
    this.isPaid = false,
    this.isPermitOnly = false,
    this.isDisabledOnly = false,
    this.isLoadingZone = false,
    this.isMaxStay = false,
    this.maxStayDuration,
    this.restrictionHours,
    this.restrictionType,
  });

  String get displayText {
    if (!canPark) return 'Prohibido aparcar';
    if (isPermitOnly) return 'Solo residentes';
    if (isDisabledOnly) return 'Solo PMR';
    if (isLoadingZone) return 'Carga/descarga';
    if (isPaid) return 'Zona OTA (pago)';
    if (isMaxStay) return 'Máx $maxStayDuration';
    return 'Aparcamiento libre';
  }

  bool get isLegalToPark => canPark && !isPermitOnly && !isDisabledOnly && !isLoadingZone;
}

class ParkingZone {
  final double lat;
  final double lng;
  final bool canPark;
  final String condition;

  ParkingZone({required this.lat, required this.lng, required this.canPark, required this.condition});
}

class OsmService {
  final Map<String, OsmRestriction> _cache = {};
  final Map<String, List<ParkingZone>> _zoneCache = {};
  DateTime _lastCacheCleanup = DateTime.now();

  Future<OsmRestriction> getRestriction(double lat, double lng) async {
    final cacheKey = '${(lat * 100).round()}_${(lng * 100).round()}';
    _cleanupCacheIfNeeded();
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    try {
      return await _fetchFromOsm(lat, lng);
    } catch (e) {
      return OsmRestriction();
    }
  }

  Future<bool> canParkHere(double lat, double lng) async {
    final restriction = await getRestriction(lat, lng);
    return restriction.isLegalToPark;
  }

  Future<List<ParkingZone>> getParkingZones(double lat, double lng, {double radius = 0.005}) async {
    final key = '${(lat * 1000).round()}_${(lng * 1000).round()}';
    if (_zoneCache.containsKey(key)) return _zoneCache[key]!;

    try {
      final query = '''
        [out:json];
        (
          way(around:$radius,$lat,$lng)["highway"]["parking:condition:both"];
          way(around:$radius,$lat,$lng)["highway"]["parking:condition:left"];
          way(around:$radius,$lat,$lng)["highway"]["parking:condition:right"];
          way(around:$radius,$lat,$lng)["highway"]["no_parking"];
          way(around:$radius,$lat,$lng)["amenity"="parking"];
          node(around:$radius,$lat,$lng)["amenity"="parking"];
        );
        out center;
      ''';

      final response = await http.post(
        Uri.parse(AppConfig.osmBaseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List? ?? [];
      final zones = <ParkingZone>[];

      for (final el in elements) {
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final condition = tags['parking:condition:both'] as String?
          ?? tags['parking:condition:right'] as String?
          ?? tags['parking:condition:left'] as String?;
        final noParking = tags['no_parking'] as String?;
        final amenity = tags['amenity'] as String?;

        double zLat, zLng;
        if (el['center'] != null) {
          zLat = (el['center']['lat'] as num).toDouble();
          zLng = (el['center']['lon'] as num).toDouble();
        } else if (el['lat'] != null) {
          zLat = (el['lat'] as num).toDouble();
          zLng = (el['lon'] as num).toDouble();
        } else {
          continue;
        }

        if (noParking == 'yes') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: false, condition: 'no_parking'));
        } else if (condition == 'ticket') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: true, condition: 'ticket'));
        } else if (condition == 'residents') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: false, condition: 'residents'));
        } else if (condition == 'disabled') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: false, condition: 'disabled'));
        } else if (condition == 'loading') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: false, condition: 'loading'));
        } else if (condition == 'maxstay') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: true, condition: 'maxstay'));
        } else if (amenity == 'parking') {
          zones.add(ParkingZone(lat: zLat, lng: zLng, canPark: true, condition: 'parking_lot'));
        }
      }

      _zoneCache[key] = zones;
      return zones;
    } catch (e) {
      return [];
    }
  }

  Future<OsmRestriction> _fetchFromOsm(double lat, double lng) async {
    final cacheKey = '${(lat * 100).round()}_${(lng * 100).round()}';
    final query = '''
      [out:json];
      (
        way(around:15,$lat,$lng)["highway"]["parking:condition:both"];
        way(around:15,$lat,$lng)["highway"]["parking:condition:left"];
        way(around:15,$lat,$lng)["highway"]["parking:condition:right"];
        way(around:15,$lat,$lng)["highway"]["no_parking"];
        node(around:15,$lat,$lng)["amenity"="parking"];
      );
      out body;
    ''';

    try {
      final response = await http.post(
        Uri.parse(AppConfig.osmBaseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _cache[cacheKey] = OsmRestriction(); return _cache[cacheKey]!;
      }

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List? ?? [];

      for (final element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final restriction = _parseRestriction(tags);
        if (!restriction.canPark) { _cache[cacheKey] = restriction; return restriction; }
        if (restriction.isPaid || restriction.isPermitOnly || restriction.isMaxStay) {
          _cache[cacheKey] = restriction; return restriction;
        }
      }
      _cache[cacheKey] = OsmRestriction(); return OsmRestriction();
    } catch (e) {
      _cache[cacheKey] = OsmRestriction(); return OsmRestriction();
    }
  }

  OsmRestriction _parseRestriction(Map<String, dynamic> tags) {
    final noParking = tags['no_parking'] as String?;
    final parkingCondition = tags['parking:condition:both'] as String?
      ?? tags['parking:condition:right'] as String?
      ?? tags['parking:condition:left'] as String?;

    if (noParking == 'yes') return OsmRestriction(canPark: false, restrictionType: 'no_parking');
    if (parkingCondition != null) {
      switch (parkingCondition) {
        case 'ticket': return OsmRestriction(isPaid: true, restrictionType: 'ticket');
        case 'residents': return OsmRestriction(isPermitOnly: true, restrictionType: 'residents');
        case 'disabled': return OsmRestriction(isDisabledOnly: true, restrictionType: 'disabled');
        case 'loading': return OsmRestriction(isLoadingZone: true, restrictionType: 'loading');
        case 'maxstay':
          final ms = tags['parking:condition:both:maxstay']
            ?? tags['parking:condition:right:maxstay']
            ?? tags['parking:condition:left:maxstay']
            ?? '2 hours';
          return OsmRestriction(isMaxStay: true, maxStayDuration: ms as String?);
        default: return OsmRestriction();
      }
    }
    return OsmRestriction();
  }

  void _cleanupCacheIfNeeded() {
    if (DateTime.now().difference(_lastCacheCleanup).inMinutes > 15) {
      _cache.clear(); _zoneCache.clear();
      _lastCacheCleanup = DateTime.now();
    }
  }

  void dispose() { _cache.clear(); _zoneCache.clear(); }
}
