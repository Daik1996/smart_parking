import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';
import '../services/location_service.dart';
import '../services/osm_service.dart';
import '../services/parking_logic_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/legend_widget.dart';

class MapScreen extends StatefulWidget {
  final LocationService locationService;
  final ParkingLogicService parkingLogic;
  final LocalStorageService storageService;
  final OsmService osmService;

  const MapScreen({
    super.key,
    required this.locationService,
    required this.parkingLogic,
    required this.storageService,
    required this.osmService,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  static const _madrid = LatLng(40.4168, -3.7038);
  LocationResult? _currentLocation;
  List<Marker> _markers = [];
  List<Polygon> _parkingPolygons = [];
  List<Polyline> _streetParkingLines = [];
  int _freeCount = 0;
  int _occupiedCount = 0;
  bool _isMonitoring = false;
  bool _showLegend = false;
  String _sessionMsg = 'Esperando GPS...';

  @override
  void initState() {
    super.initState();
    _startServices();
  }

  Future<void> _startServices() async {
    await widget.locationService.startMonitoring();
    widget.locationService.locationStream!.listen((loc) {
      setState(() => _currentLocation = loc);
      if (_isMonitoring) {
        widget.parkingLogic.processLocation(loc);
      }
      _updateMarkers();
      _loadParkingZones();
      _sessionMsg = 'GPS: ${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}';
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadParkingZones() async {
    if (_currentLocation == null) return;
    final lat = _currentLocation!.lat;
    final lng = _currentLocation!.lng;
    final polygons = await widget.osmService.getParkingPolygons(lat, lng, radiusMeters: 500);
    final streets = await widget.osmService.getStreetParking(lat, lng, radiusMeters: 300);
    setState(() {
      _parkingPolygons = polygons.map((p) {
        final isPaid = p.condition == 'paid';
        final isStructure = p.type == 'parking_structure';
        Color fillColor;
        if (isPaid) {
          fillColor = AppConfig.colorWarning.withValues(alpha: 0.25);
        } else if (isStructure) {
          fillColor = Colors.blue.withValues(alpha: 0.25);
        } else {
          fillColor = AppConfig.colorFree.withValues(alpha: 0.25);
        }
        Color borderColor;
        if (isPaid) {
          borderColor = AppConfig.colorWarning.withValues(alpha: 0.6);
        } else if (isStructure) {
          borderColor = Colors.blue.withValues(alpha: 0.6);
        } else {
          borderColor = AppConfig.colorFree.withValues(alpha: 0.6);
        }
        return Polygon(
          points: p.points,
          color: fillColor,
          borderColor: borderColor,
          borderStrokeWidth: 2,
        );
      }).toList();
      _streetParkingLines = streets.map((s) {
        Color color;
        double width;
        if (s.isNoParking) {
          color = AppConfig.colorOccupied;
          width = 3;
        } else if (s.isPaid) {
          color = AppConfig.colorWarning;
          width = 4;
        } else if (s.isPermitOnly || s.isDisabled || s.isLoadingZone) {
          color = Colors.orange.withValues(alpha: 0.8);
          width = 3;
        } else if (s.maxStay != null) {
          color = Colors.teal;
          width = 4;
        } else {
          color = AppConfig.colorFree;
          width = 5;
        }
        return Polyline(
          points: s.points,
          color: color,
          strokeWidth: width,
        );
      }).toList();
    });
  }

  Future<void> _updateMarkers() async {
    if (_currentLocation == null) return;
    final spots = await widget.storageService.getNearbySpots(_currentLocation!.lat, _currentLocation!.lng, radiusKm: 2);
    final markers = <Marker>[];
    for (final spot in spots) {
      markers.add(Marker(
        point: LatLng(spot.lat, spot.lng),
        width: 20,
        height: 20,
        child: _spotMarker(spot),
      ));
    }
    setState(() {
      _markers = markers;
      _freeCount = spots.where((s) => s.isFree).length;
      _occupiedCount = spots.where((s) => s.isOccupied).length;
    });
  }

  Widget _spotMarker(ParkingSpot spot) {
    final color = spot.isOccupied ? AppConfig.colorOccupied : AppConfig.colorFree;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: spot.isOccupied ? BorderRadius.circular(4) : const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
      ),
    );
  }

  Widget _currentLocationMarker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.blue, blurRadius: 8)],
      ),
      child: const Icon(Icons.my_location, color: Colors.white, size: 14),
    );
  }

  void _toggleMonitoring() {
    setState(() {
      _isMonitoring = !_isMonitoring;
      _showLegend = _isMonitoring;
    });
    if (_isMonitoring) {
      widget.parkingLogic.startSession();
    } else {
      widget.parkingLogic.endSession();
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    await widget.storageService.reportSpotFree(point.latitude, point.longitude);
    _updateMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _madrid,
            initialZoom: 14,
            maxZoom: 18,
            minZoom: 10,
            onTap: (_, point) => _onMapTap(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              maxZoom: 18,
            ),
            if (_parkingPolygons.isNotEmpty)
              PolygonLayer(polygons: _parkingPolygons),
            if (_streetParkingLines.isNotEmpty)
              PolylineLayer(polylines: _streetParkingLines),
            MarkerLayer(markers: _markers),
            if (_currentLocation != null)
              MarkerLayer(markers: [
                Marker(point: LatLng(_currentLocation!.lat, _currentLocation!.lng), width: 28, height: 28, child: _currentLocationMarker()),
              ]),
          ],
        ),
        _topBar(),
        if (_showLegend) const Positioned(top: 110, left: 14, child: LegendWidget()),
        _bottomPanel(),
      ]),
    );
  }

  Widget _topBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConfig.colorBackground.withValues(alpha: 0.95), AppConfig.colorBackground.withValues(alpha: 0)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Row(children: [
          const Text('SmartPark', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConfig.colorText)),
          const Spacer(),
          _pill(_freeCount.toString(), 'Libres', AppConfig.colorFree),
          const SizedBox(width: 8),
          _pill(_occupiedCount.toString(), 'Ocupados', AppConfig.colorOccupied),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _pill(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$count $label', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _bottomPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppConfig.colorBackground.withValues(alpha: 0), AppConfig.colorBackground.withValues(alpha: 0.95)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_isMonitoring)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isMonitoring ? Colors.white12 : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: AppConfig.colorFree,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppConfig.colorFree, blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(_sessionMsg, style: const TextStyle(color: AppConfig.colorText, fontSize: 14)),
              ]),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
              label: Text(_isMonitoring ? 'Detener monitoreo' : 'Iniciar monitoreo',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? AppConfig.colorOccupied : AppConfig.colorFree,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 8,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    widget.locationService.stopMonitoring();
    widget.parkingLogic.dispose();
    super.dispose();
  }
}
