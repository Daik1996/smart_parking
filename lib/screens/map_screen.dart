import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';
import '../services/location_service.dart';
import '../services/parking_logic_service.dart';
import '../services/firebase_service.dart';
import '../services/osm_service.dart';
import '../widgets/legend_widget.dart';
import '../widgets/info_panel.dart';

class MapScreen extends StatefulWidget {
  final LocationService locationService;
  final ParkingLogicService parkingLogic;
  final FirebaseService firebaseService;
  final OsmService osmService;

  const MapScreen({
    super.key,
    required this.locationService,
    required this.parkingLogic,
    required this.firebaseService,
    required this.osmService,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Marker> _markers = {};
  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(40.4168, -3.7038),
    zoom: 15,
  );

  bool _isMonitoring = false;
  String _statusText = 'Iniciar monitoreo';
  String _sessionState = 'Esperando...';
  bool _showLegend = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    widget.parkingLogic.events?.listen((event) {
      setState(() {
        _sessionState = event.message;
      });
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
    final spots = await widget.firebaseService.getNearbySpots(lat, lng);

    setState(() {
      _markers.clear();
      for (final spot in spots) {
        _addMarker(spot.lat, spot.lng, spot.status, spotId: spot.id);
      }
    });
  }

  void _addMarker(double lat, double lng, SpotStatus status, {String? spotId}) {
    final marker = Marker(
      markerId: MarkerId('${spotId ?? ''}_${lat}_$lng'),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        status == SpotStatus.free ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
      ),
      onTap: () => _showSpotInfo(lat, lng, status, spotId),
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId == marker.markerId);
      _markers.add(marker);
    });
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
    await widget.firebaseService.reportSpotFree(lat, lng);
    if (!mounted) return;
    _addMarker(lat, lng, SpotStatus.free);
    Navigator.of(context).pop();
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
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: _isMonitoring,
            myLocationButtonEnabled: _isMonitoring,
            onMapCreated: (controller) {},
            onTap: (latLng) => _showSpotInfo(latLng.latitude, latLng.longitude, SpotStatus.free, null),
            style: _darkMapStyle,
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

const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{ "color": "#242f3e" }]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#746855" }]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{ "color": "#242f3e" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{ "color": "#38414e" }]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{ "color": "#212a37" }]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{ "color": "#9ca5b3" }]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{ "color": "#17263c" }]
  }
]
''';
