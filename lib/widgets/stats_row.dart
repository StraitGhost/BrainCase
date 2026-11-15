// lib/widgets/stats_row.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/learning_progress_service.dart';

class StatsRow extends StatefulWidget {
  final int completedTopics; // ✅ Cambiado de completedCases
  final int totalTopics;     // ✅ Cambiado de totalCases
  final int accuracy;
  final int errors;
  final int studyTimeMinutes;
  final String profileId;

  const StatsRow({
    super.key,
    required this.completedTopics,
    required this.totalTopics,
    required this.accuracy,
    required this.errors,
    required this.studyTimeMinutes,
    required this.profileId,
  });

  @override
  State<StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<StatsRow> {
  final LearningProgressService _service = LearningProgressService();
  late Stream<int> _mistakesStream;

  @override
  void initState() {
    super.initState();
    _mistakesStream = _service.getMistakesCount();
  }

  String _formatTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.hub_outlined, // ✅ Ícono más acorde a "Temas"
            label: 'Temas completados', // ✅ Cambiado
            value: '${widget.completedTopics} / ${widget.totalTopics}',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12), // ✅ Espaciado ligeramente reducido para pantallas pequeñas
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Precisión', // ✅ Más profesional que "Aciertos"
            value: '${widget.accuracy}%',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<int>(
            stream: _mistakesStream,
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data! : widget.errors;
              return _StatCard(
                icon: Icons.error_outline,
                label: 'Errores',
                value: '$count',
                color: AppColors.error,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.access_time_filled, // ✅ Ícono de tiempo más sólido
            label: 'Tiempo de estudio', // ✅ Etiqueta más clara
            value: _formatTime(widget.studyTimeMinutes),
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14), // ✅ Ligeramente más compacto
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}