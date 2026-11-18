// lib/widgets/level_panel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../models/profile.dart';
import '../services/profile_data_service.dart';
import '../features/level_assessment/level_assessment_screen.dart';

class LevelPanel extends StatefulWidget {
  final UserProfile userProfile;
  const LevelPanel({super.key, required this.userProfile});

  /// ✅ LLAMAR AL TERMINAR EL EXAMEN (suba, se quede o baje de nivel).
  /// Deja el progreso en 0: iguala la línea base a los aciertos actuales,
  /// así el usuario debe volver a hacer lecciones para el siguiente examen.
  static Future<void> resetProgressAfterExam(String profileId) async {
    final ref = ProfileDataService.refFor(profileId);
    if (ref == null) return;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final current = data['correctAnswers'];
      final value = current is num ? current.toInt() : int.tryParse('${current ?? ''}') ?? 0;
      tx.set(ref, {'correctAnswersAtLastExam': value}, SetOptions(merge: true));
    });
  }

  @override
  State<LevelPanel> createState() => _LevelPanelState();
}

class _LevelPanelState extends State<LevelPanel> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;

  static const _levelNames = [
    'Principiante', 'Intermedio', 'Avanzado',
    'Experto', 'Experto Avanzado', 'Maestro',
  ];

  // ✅ Principiante 100, y +50 por cada nivel
  static const _questionsByLevel = [100, 150, 200, 250, 300, 350];

  @override
  void initState() {
    super.initState();
    _stream = ProfileDataService.refFor(widget.userProfile.id)?.snapshots();
  }

  int _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  // ✅ El nivel sale del campo `experienceLevel` (texto) del documento
  int _levelFrom(Map<String, dynamic> data) {
    final i = _levelNames.indexOf('${data['experienceLevel'] ?? ''}'.trim());
    return i < 0 ? 0 : i;
  }

  int _countMastered(Map<String, dynamic> data) {
    final current = _asInt(data['correctAnswers']);
    final baseline = _asInt(data['correctAnswersAtLastExam']); // 0 si nunca examinó
    final mastered = current - baseline;
    return mastered < 0 ? 0 : mastered;
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
          level = _levelFrom(data);
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
                        : 'Consigue $missing aciertos NUEVOS (desde tu último examen) para desbloquearlo.',
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
                      : null,
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