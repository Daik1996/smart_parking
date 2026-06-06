import 'package:flutter/material.dart';
import '../config/app_config.dart';

class LegendWidget extends StatelessWidget {
  const LegendWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConfig.colorSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Leyenda', style: TextStyle(color: AppConfig.colorText, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _row(_car(AppConfig.colorFree), 'Naranja libre', 'Disponible para aparcar'),
          const SizedBox(height: 6),
          _row(_car(AppConfig.colorOccupied), 'Naranja ocupado', 'Coche aparcado aquí'),
          const SizedBox(height: 6),
          _row(_car(AppConfig.colorWarning), 'Conductor fuera', 'Caminando, NO libera'),
        ],
      ),
    );
  }

  Widget _car(Color color) {
    return Container(
      width: 28, height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6), topRight: Radius.circular(6),
          bottomLeft: Radius.circular(3), bottomRight: Radius.circular(3),
        ),
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: const Icon(Icons.directions_car, color: Colors.white, size: 12),
    );
  }

  Widget _row(Widget icon, String label, String sub) {
    return Row(
      mainAxisSize: MainAxisSize.min, children: [
        icon, const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppConfig.colorText, fontSize: 13)),
          Text(sub, style: const TextStyle(color: AppConfig.colorTextSecondary, fontSize: 10)),
        ]),
      ],
    );
  }
}
