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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConfig.colorAccent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Leyenda',
            style: TextStyle(
              color: AppConfig.colorText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _legendItem(AppConfig.colorFree, 'Plaza libre', 'Disponible 30 min'),
          const SizedBox(height: 4),
          _legendItem(AppConfig.colorOccupied, 'Ocupado', 'Coche aparcado'),
          const SizedBox(height: 4),
          _legendItem(AppConfig.colorWarning, 'Conductor andando', 'No libera plaza'),
          const SizedBox(height: 4),
          _legendItem(AppConfig.colorExpired, 'Expirado', 'Dato antiguo'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, String subtitle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppConfig.colorText,
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppConfig.colorTextSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
