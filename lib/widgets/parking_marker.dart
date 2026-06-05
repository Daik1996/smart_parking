import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/parking_spot.dart';

class ParkingMarker extends StatefulWidget {
  final SpotStatus status;
  final double size;

  const ParkingMarker({
    super.key,
    required this.status,
    this.size = 40,
  });

  @override
  State<ParkingMarker> createState() => _ParkingMarkerState();
}

class _ParkingMarkerState extends State<ParkingMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.status == SpotStatus.free) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ParkingMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status == SpotStatus.free) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.status) {
      case SpotStatus.free:
        return AppConfig.colorFree;
      case SpotStatus.occupied:
        return AppConfig.colorOccupied;
      case SpotStatus.expired:
        return AppConfig.colorExpired;
      case SpotStatus.unknown:
        return AppConfig.colorWarning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.status == SpotStatus.free
          ? 1.0 + (_controller.value * 0.3)
          : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              widget.status == SpotStatus.free ? Icons.check : Icons.close,
              color: Colors.white,
              size: widget.size * 0.5,
            ),
          ),
        );
      },
    );
  }
}
