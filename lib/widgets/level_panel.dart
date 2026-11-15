// lib/widgets/level_panel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../models/profile.dart';
import '../services/profile_data_service.dart';
import '../features/level_assessment/level_assessment_screen.dart';

class LevelPanel extends StatefulWidget {
  final UserProfile userProfile; // ✅ Ahora solo necesita el perfil
  const LevelPanel({super.key, required this.userProfile});

  @override
  State<LevelPanel> createState() => _LevelPanelState();
}

class _LevelPanelState extends State<LevelPanel> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;

  static const _levelNames = [
    'Principiante', 'Intermedio', 'Avanzado',
    'Experto', 'Experto Avanzado', 'Maestro',
  ];

  // ✅ Debe coincidir EXACTAMENTE con _questionsByLevel del examen
  static const _questionsByLevel = [8, 10, 12, 14, 16, 20];

  @override
  void initState() {
    super.initState();
    _stream = ProfileDataService.refFor(widget.userProfile.id)?.snapshots();
  }

  int _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  /// Mismo extractor que usa el examen, para que barra y examen estén sincronizados.
  int _countMastered(Map<String, dynamic> data) {
    final ids = <String>{};

    for (final key in ['correctQuestionIds', 'masteredQuestions', 'answeredCorrectly']) {
      final raw = data[key];
      if (raw is List) {
        for (final e in raw) {
          final s = e?.toString();
          if (s != null && s.isNotEmpty) ids.add(s);
        }
      }
    }

    final mistakes = data['mistakes'];
    if (mistakes is List) {
      for (final m in mistakes) {
        if (m is Map && m['corrected'] == true) {
          final qid = m['questionId']?.toString() ?? m['id']?.toString();
          if (qid != null && qid.isNotEmpty) ids.add(qid);
        }
      }
    }

    return ids.length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        int level = 0;
        int mastered = 0;

        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() ?? <String, dynamic>{};
          level = _asInt(data['level']).clamp(0, 5);
          mastered = _countMastered(data);
        }

        final required = _questionsByLevel[level];
        final prep = (mastered / required).clamp(0.0, 1.0);
        final ready = prep >= 1.0;

        final name = _levelNames[level];
        final color = AppColors.primary;
        final missing = (required - mastered).clamp(0, required);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu nivel actual',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      level >= 5 ? Icons.emoji_events : Icons.trending_up,
                      color: AppColors.textOnPrimary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nivel $level',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ✅ Barra de PREPARACIÓN (dominadas / necesarias)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Preparación para el examen',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$mastered / $required',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: prep),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ready ? AppColors.success : color,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ready
                        ? (level >= 5
                            ? '¡Listo! Puedes repetir el examen (⚠️ si no sacas 80% o más, bajarás de nivel).'
                            : '¡Listo! Ya dominas lo suficiente para examinarte.')
                        : 'Domina $missing pregunta(s) más (acierta o corrige en "Mis Errores") para desbloquear el examen.',
                    style: TextStyle(
                      color: ready ? AppColors.success : AppColors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ✅ Botón habilitado SOLO con la barra al 100%
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: ready
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LevelAssessmentScreen(
                                userProfile: widget.userProfile,
                              ),
                            ),
                          );
                        }
                      : null, // gris/bloqueado hasta llegar a 100%
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    ready
                        ? (level >= 5
                            ? 'Repetir Examen de Nivelación'
                            : 'Hacer Examen de Nivelación')
                        : 'Examen bloqueado',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ready ? color : AppColors.border,
                    foregroundColor:
                        ready ? AppColors.textOnPrimary : AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}