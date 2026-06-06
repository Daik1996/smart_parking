import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';

class ParkingMarker extends StatefulWidget {
  final SpotStatus status;
  final VoidCallback? onTap;

  const ParkingMarker({super.key, required this.status, this.onTap});

  @override
  State<ParkingMarker> createState() => _ParkingMarkerState();
}

class _ParkingMarkerState extends State<ParkingMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    if (widget.status == SpotStatus.free) {
      _pulseCtrl.repeat(reverse: true);
      _glowCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ParkingMarker old) {
    super.didUpdateWidget(old);
    if (widget.status != old.status) {
      if (widget.status == SpotStatus.free) {
        _pulseCtrl.repeat(reverse: true);
        _glowCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _glowCtrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status) {
      case SpotStatus.free: return AppConfig.colorFree;
      case SpotStatus.occupied: return AppConfig.colorOccupied;
      case SpotStatus.expired: return AppConfig.colorExpired;
      case SpotStatus.unknown: return AppConfig.colorWarning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _glowCtrl]),
        builder: (context, _) {
          final isFree = widget.status == SpotStatus.free;
          final pulse = isFree ? _pulseCtrl.value : 0.0;
          final glow = isFree ? _glowCtrl.value : 0.0;

          return Container(
            width: 60,
            height: 44,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.85 + pulse * 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7 + glow * 0.3),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.3 + glow * 0.4),
                  blurRadius: 8 + glow * 8,
                  spreadRadius: 1 + glow * 3,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car, color: Colors.white, size: 22),
              ],
            ),
          );
        },
      ),
    );
  }
}
