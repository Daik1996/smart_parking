import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';
import '../services/location_service.dart';
import '../services/parking_logic_service.dart';
import '../services/local_storage_service.dart';
import '../services/osm_service.dart';
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
  final LatLng _madrid = const LatLng(40.4168, -3.7038);

  bool _isMonitoring = false;
  String _statusText = 'Iniciar monitoreo';
  String _sessionState = 'Esperando...';
  bool _showLegend = false;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    widget.parkingLogic.events?.listen((event) {
      if (mounted) {
        setState(() {
          _sessionState = event.message;
        });
      }
    });
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      _stopMonitoring();
    } else {
      await _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    final permissions = await widget.locationService.requestPermissions();
    if (!permissions || !mounted) return;

    await widget.parkingLogic.startSession();
    await widget.locationService.startMonitoring();

    setState(() {
      _isMonitoring = true;
      _statusText = 'Monitoreando...';
    });

    widget.locationService.locationStream?.listen((location) async {
      final pos = LatLng(location.lat, location.lng);
      _currentPosition = pos;

      final result = await widget.parkingLogic.processLocation(location);
      if (result == StateTransitionResult.spotFreed) {
        _addMarker(location.lat, location.lng, SpotStatus.free);
      } else if (result == StateTransitionResult.spotOccupied) {
        _addMarker(location.lat, location.lng, SpotStatus.occupied);
      }
      _refreshSpots(location.lat, location.lng);
    });
  }

  void _stopMonitoring() {
    widget.locationService.stopMonitoring();
    widget.parkingLogic.endSession();

    setState(() {
      _isMonitoring = false;
      _statusText = 'Iniciar monitoreo';
      _sessionState = 'Monitoreo detenido';
    });

    _markers.clear();
  }

  Future<void> _refreshSpots(double lat, double lng) async {
    final spots = await widget.storageService.getNearbySpots(lat, lng);

    setState(() {
      _markers.clear();
      for (final spot in spots) {
        _addMarker(spot.lat, spot.lng, spot.status, spotId: spot.id);
      }
    });
  }

  void _addMarker(double lat, double lng, SpotStatus status, {String? spotId}) {
    final color = status == SpotStatus.free
      ? AppConfig.colorFree
      : AppConfig.colorOccupied;

    final marker = Marker(
      point: LatLng(lat, lng),
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: () => _showSpotInfo(lat, lng, status, spotId),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            status == SpotStatus.free ? Icons.check : Icons.close,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );

    _markers.removeWhere((m) {
      final mPos = m.point;
      return (mPos.latitude - lat).abs() < 0.001 && (mPos.longitude - lng).abs() < 0.001;
    });
    _markers.add(marker);
  }

  void _showSpotInfo(double lat, double lng, SpotStatus status, String? spotId) async {
    final restriction = await widget.osmService.getRestriction(lat, lng);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConfig.colorSurface,
      builder: (ctx) => InfoPanel(
        lat: lat,
        lng: lng,
        restriction: restriction,
        status: status,
        spotId: spotId,
        onFreeSpot: _onConfirmFreeSpot,
      ),
    );
  }

  void _onConfirmFreeSpot(double lat, double lng) async {
    await widget.storageService.reportSpotFree(lat, lng);
    _addMarker(lat, lng, SpotStatus.free);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.colorBackground,
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        backgroundColor: AppConfig.colorSurface,
        actions: [
          IconButton(
            icon: Icon(_showLegend ? Icons.info : Icons.info_outline),
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _madrid,
              initialZoom: 14,
              onTap: (tapPos, latLng) => _showSpotInfo(latLng.latitude, latLng.longitude, SpotStatus.free, null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smart_parking',
              ),
              MarkerLayer(markers: _markers),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_showLegend) const Positioned(
            top: 16,
            left: 16,
            child: LegendWidget(),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppConfig.colorSurface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _sessionState,
                  style: const TextStyle(color: AppConfig.colorText, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleMonitoring,
        backgroundColor: _isMonitoring ? AppConfig.colorOccupied : AppConfig.colorFree,
        icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
        label: Text(_statusText),
      ),
    );
  }

  @override
  void dispose() {
    widget.parkingLogic.events?.drain();
    super.dispose();
  }
}
