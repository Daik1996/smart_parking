import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';
import '../services/location_service.dart';
import '../services/parking_logic_service.dart';
import '../services/local_storage_service.dart';
import '../services/osm_service.dart';
import '../widgets/parking_marker.dart';
import '../widgets/legend_widget.dart';
import '../widgets/info_panel.dart';

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
  final List<Marker> _markers = [];
  final List<Marker> _zoneMarkers = [];
  final LatLng _madrid = const LatLng(40.4168, -3.7038);

  bool _isMonitoring = false;
  String _sessionMsg = 'Coche detenido';
  bool _showLegend = false;
  LatLng? _currentPosition;
  int _freeCount = 0;
  int _occupiedCount = 0;

  @override
  void initState() {
    super.initState();
    widget.parkingLogic.events?.listen((e) {
      if (mounted) setState(() => _sessionMsg = e.message);
    });
    _loadParkingZones();
  }

  Future<void> _loadParkingZones() async {
    final zones = await widget.osmService.getParkingZones(40.4168, -3.7038, radius: 0.01);
    if (!mounted) return;
    for (final z in zones) {
      _zoneMarkers.add(Marker(
        point: LatLng(z.lat, z.lng),
        width: 28, height: 28,
        child: Container(
          decoration: BoxDecoration(
            color: z.canPark
              ? AppConfig.colorFree.withValues(alpha: 0.55)
              : AppConfig.colorOccupied.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Icon(z.canPark ? Icons.local_parking : Icons.block, color: Colors.white, size: 16),
        ),
      ));
    }
    setState(() {});
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) { _stopMonitoring(); return; }
    final ok = await widget.locationService.requestPermissions();
    if (!ok || !mounted) return;

    await widget.parkingLogic.startSession();
    await widget.locationService.startMonitoring();

    setState(() => _isMonitoring = true);

    widget.locationService.locationStream?.listen((loc) async {
      _currentPosition = LatLng(loc.lat, loc.lng);
      final r = await widget.parkingLogic.processLocation(loc);
      if (r == StateTransitionResult.spotFreed || r == StateTransitionResult.spotOccupied) {
        _refreshSpots(loc.lat, loc.lng);
      }
    });
  }

  void _stopMonitoring() {
    widget.locationService.stopMonitoring();
    widget.parkingLogic.endSession();
    setState(() {
      _isMonitoring = false;
      _sessionMsg = 'Monitoreo detenido';
      _markers.clear();
      _freeCount = 0;
      _occupiedCount = 0;
    });
  }

  Future<void> _refreshSpots(double lat, double lng) async {
    final spots = await widget.storageService.getNearbySpots(lat, lng);
    setState(() {
      _markers.clear();
      _freeCount = spots.where((s) => s.isFree).length;
      _occupiedCount = spots.where((s) => s.isOccupied).length;
      for (final s in spots) { _addMarker(s.lat, s.lng, s.status); }
    });
  }

  void _addMarker(double lat, double lng, SpotStatus status) {
    _markers.removeWhere((m) => m.point.latitude == lat && m.point.longitude == lng);
    _markers.add(Marker(
      point: LatLng(lat, lng),
      width: 60, height: 55,
      child: ParkingMarker(
        status: status,
        onTap: () => _showSpotInfo(lat, lng, status),
      ),
    ));
  }

  void _showSpotInfo(double lat, double lng, SpotStatus status) async {
    final restriction = await widget.osmService.getRestriction(lat, lng);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConfig.colorSurface,
      builder: (_) => InfoPanel(lat: lat, lng: lng, restriction: restriction, status: status,
        onFreeSpot: (lat, lng) async {
          await widget.storageService.reportSpotFree(lat, lng);
          _addMarker(lat, lng, SpotStatus.free);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _madrid,
            initialZoom: 15,
            onTap: (_, ll) => _showSpotInfo(ll.latitude, ll.longitude, SpotStatus.free),
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.5, 0, 0, 0, 0,
                0, 0.5, 0, 0, 0,
                0, 0, 0.5, 0, 0,
                0, 0, 0, 0.8, 0,
              ]),
              child: TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.smart_parking',
              ),
            ),
            MarkerLayer(markers: _zoneMarkers),
            MarkerLayer(markers: _markers),
            if (_currentPosition != null)
              MarkerLayer(markers: [
                Marker(point: _currentPosition!, width: 28, height: 28, child: _currentLocDot()),
              ]),
          ],
        ),
        _topBar(),
        if (_showLegend) const Positioned(top: 110, left: 14, child: LegendWidget()),
        _bottomPanel(),
      ]),
    );
  }

  Widget _currentLocDot() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.my_location, color: Colors.white, size: 14),
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
          GestureDetector(
            onTap: () => setState(() => _showLegend = !_showLegend),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: Icon(_showLegend ? Icons.info : Icons.info_outline, color: AppConfig.colorTextSecondary, size: 20),
            ),
          ),
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
    widget.parkingLogic.events?.drain();
    super.dispose();
  }
}
