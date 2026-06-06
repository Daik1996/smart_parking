import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';
import '../services/osm_service.dart';

class InfoPanel extends StatelessWidget {
  final double lat;
  final double lng;
  final OsmRestriction restriction;
  final SpotStatus status;
  final String? spotId;
  final void Function(double lat, double lng)? onFreeSpot;

  const InfoPanel({
    super.key,
    required this.lat,
    required this.lng,
    required this.restriction,
    required this.status,
    this.spotId,
    this.onFreeSpot,
  });

  @override
  Widget build(BuildContext context) {
    final color = status == SpotStatus.free ? AppConfig.colorFree : AppConfig.colorOccupied;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppConfig.colorSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _carIcon(color),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status == SpotStatus.free ? 'Plaza libre' : 'Plaza ocupada',
              style: const TextStyle(color: AppConfig.colorText, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(restriction.displayText,
              style: TextStyle(color: restriction.isLegalToPark ? AppConfig.colorFree : AppConfig.colorOccupied, fontSize: 13)),
          ])),
          IconButton(
            icon: const Icon(Icons.close, color: AppConfig.colorTextSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _badge(Icons.pin_drop, '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
          const Spacer(),
          if (restriction.isMaxStay || restriction.isPaid)
            _badge(Icons.access_time, restriction.isMaxStay ? restriction.maxStayDuration! : 'Pago'),
        ]),
        const SizedBox(height: 16),
        if (onFreeSpot != null && restriction.isLegalToPark)
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => onFreeSpot!(lat, lng),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('Marcar como libre', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.colorFree,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
      ]),
    );
  }

  Widget _carIcon(Color color) {
    return Container(
      width: 48, height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10), topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5),
        ),
        border: Border.all(color: Colors.white70, width: 2),
      ),
      child: const Icon(Icons.directions_car, color: Colors.white, size: 22),
    );
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppConfig.colorAccent.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppConfig.colorTextSecondary),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: AppConfig.colorTextSecondary, fontSize: 12)),
      ]),
    );
  }
}
