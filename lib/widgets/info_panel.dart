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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppConfig.colorSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusIndicator(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información de plaza',
                      style: TextStyle(
                        color: AppConfig.colorText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: AppConfig.colorTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppConfig.colorTextSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: AppConfig.colorAccent),
          _infoRow(Icons.info_outline, 'Restricción', restriction.displayText),
          const SizedBox(height: 8),
          _infoRow(Icons.schedule, 'Estado', _statusText()),
          const SizedBox(height: 8),
          _infoRow(Icons.pin_drop, 'ID', spotId ?? 'No asignado'),
          const SizedBox(height: 16),
          if (restriction.isLegalToPark)
            _actionButton(
              context,
              Icons.check_circle_outline,
              'Marcar como libre',
              AppConfig.colorFree,
              () => onFreeSpot?.call(lat, lng),
            ),
          const SizedBox(height: 8),
          _actionButton(
            context,
            Icons.navigation,
            'Abrir en Google Maps',
            AppConfig.colorAccent,
            () => _openGoogleMaps(context, lat, lng),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statusIndicator() {
    final color = status == SpotStatus.free
      ? AppConfig.colorFree
      : status == SpotStatus.occupied
        ? AppConfig.colorOccupied
        : AppConfig.colorExpired;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _statusText() {
    switch (status) {
      case SpotStatus.free:
        return 'Libre (falta confirmación)';
      case SpotStatus.occupied:
        return 'Ocupado';
      case SpotStatus.expired:
        return 'Expirado';
      case SpotStatus.unknown:
        return 'Desconocido';
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppConfig.colorAccent, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppConfig.colorTextSecondary, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppConfig.colorText, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _openGoogleMaps(BuildContext ctx, double lat, double lng) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Google Maps navigation not available in demo')),
    );
  }
}
