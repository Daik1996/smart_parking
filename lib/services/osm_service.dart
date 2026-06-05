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

class OsmService {
  final Map<String, OsmRestriction> _cache = {};
  DateTime _lastCacheCleanup = DateTime.now();

  Future<OsmRestriction> getRestriction(double lat, double lng) async {
    final cacheKey = '${(lat * 100).round()}_${(lng * 100).round()}';

    _cleanupCacheIfNeeded();

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

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
        _cache[cacheKey] = OsmRestriction();
        return _cache[cacheKey]!;
      }

      final data = jsonDecode(response.body);
      final elements = data['elements'] as List? ?? [];

      for (final element in elements) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final restriction = _parseRestriction(tags);
        if (!restriction.canPark) {
          _cache[cacheKey] = restriction;
          return restriction;
        }
        if (restriction.isPaid || restriction.isPermitOnly || restriction.isMaxStay) {
          _cache[cacheKey] = restriction;
          return restriction;
        }
      }

      _cache[cacheKey] = OsmRestriction();
      return OsmRestriction();
    } catch (e) {
      _cache[cacheKey] = OsmRestriction();
      return OsmRestriction();
    }
  }

  OsmRestriction _parseRestriction(Map<String, dynamic> tags) {
    final noParking = tags['no_parking'] as String?;
    final parkingCondition = tags['parking:condition:both'] as String?
      ?? tags['parking:condition:right'] as String?
      ?? tags['parking:condition:left'] as String?;

    if (noParking == 'yes') {
      return OsmRestriction(canPark: false, restrictionType: 'no_parking');
    }

    if (parkingCondition != null) {
      switch (parkingCondition) {
        case 'ticket':
          return OsmRestriction(isPaid: true, restrictionType: 'ticket');
        case 'residents':
          return OsmRestriction(isPermitOnly: true, restrictionType: 'residents');
        case 'disabled':
          return OsmRestriction(isDisabledOnly: true, restrictionType: 'disabled');
        case 'loading':
          return OsmRestriction(isLoadingZone: true, restrictionType: 'loading');
        case 'maxstay':
          final maxstay = tags['parking:condition:both:maxstay']
            ?? tags['parking:condition:right:maxstay']
            ?? tags['parking:condition:left:maxstay']
            ?? '2 hours';
          return OsmRestriction(isMaxStay: true, maxStayDuration: maxstay as String?);
        default:
          return OsmRestriction();
      }
    }

    return OsmRestriction();
  }

  void _cleanupCacheIfNeeded() {
    if (DateTime.now().difference(_lastCacheCleanup).inMinutes > 15) {
      _cache.clear();
      _lastCacheCleanup = DateTime.now();
    }
  }

  void dispose() {
    _cache.clear();
  }
}
