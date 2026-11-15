// lib/widgets/level_panel.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/profile.dart';
import '../features/level_assessment/level_assessment_screen.dart';

class LevelPanel extends StatelessWidget {
  final UserProfile userProfile; // ✅ Necesario para enviar al examen
  final int correctAnswers;
  final int wrongAnswers;
  final int currentLevel;
  final String levelName;

  const LevelPanel({
    super.key,
    required this.userProfile,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.currentLevel,
    required this.levelName,
  });

  double get _accuracy {
    final total = correctAnswers + wrongAnswers;
    if (total == 0) return 0.0;
    return (correctAnswers / total).clamp(0.0, 1.0);
  }

  String get _nextLevelName {
    if (currentLevel >= 5) return 'Maestro';
    switch (currentLevel + 1) {
      case 1: return 'Intermedio';
      case 2: return 'Avanzado';
      case 3: return 'Experto';
      case 4: return 'Experto Avanzado';
      case 5: return 'Maestro';
      default: return 'Siguiente nivel';
    }
  }

  // Umbrales de precisión para cada nivel
  static const List<double> _thresholds = [0.0, 0.50, 0.60, 0.70, 0.80, 0.95];

  // ✅ Calcula cuántos aciertos le faltan para llegar al siguiente umbral
  int get _correctNeededForNextLevel {
    if (currentLevel >= 5) return 0;
    final total = correctAnswers + wrongAnswers;
    if (total == 0) return 10; // Mínimo sugerido para empezar
    
    final nextThreshold = _thresholds[currentLevel + 1];
    final needed = (nextThreshold * total).ceil() - correctAnswers;
    return needed > 0 ? needed : 0;
  }

  Color get _levelColor {
    if (currentLevel >= 5) return AppColors.warning;
    return AppColors.primary;
  }

  LinearGradient get _levelGradient => LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final total = correctAnswers + wrongAnswers;
    final needed = _correctNeededForNextLevel;
    final isMaxLevel = currentLevel >= 5;
    final canTakeExam = total >= 10; // ✅ El examen se desbloquea a las 10 preguntas

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
                  gradient: _levelGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isMaxLevel ? Icons.emoji_events : Icons.trending_up,
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
                      levelName,
                      style: TextStyle(
                        color: _levelColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nivel $currentLevel',
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
          
          // Barra de progreso
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMaxLevel ? 'Nivel máximo alcanzado' : 'Progreso al siguiente nivel',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    isMaxLevel ? '100%' : '${(_accuracy * 100).round()}%',
                    style: TextStyle(
                      color: _levelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: isMaxLevel ? 1.0 : _accuracy,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(_levelColor),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              
              // ✅ Mensaje dinámico de cuántos aciertos le faltan
              Text(
                isMaxLevel
                    ? '¡Felicidades! Has dominado la materia.'
                    : !canTakeExam
                        ? 'Responde al menos 10 preguntas para desbloquear el examen.'
                        : needed == 0 
                            ? '¡Ya tienes la precisión necesaria! Haz el examen para subir.'
                            : 'Te faltan $needed aciertos (sin fallar) para subir a $_nextLevelName.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // ✅ BOTÓN PARA HACER EL EXAMEN
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canTakeExam ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LevelAssessmentScreen(userProfile: userProfile),
                  ),
                );
              } : null, // Deshabilitado si tiene menos de 10 preguntas
              
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(
                canTakeExam ? 'Hacer Examen de Nivelación' : 'Desbloquea en 10 preguntas',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canTakeExam ? _levelColor : AppColors.border,
                foregroundColor: canTakeExam ? AppColors.textOnPrimary : AppColors.textMuted,
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
  }
}