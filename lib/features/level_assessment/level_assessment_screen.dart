// lib/features/level_assessment/level_assessment_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../models/profile.dart';
import '../../services/profile_data_service.dart';
import '../../services/question_service.dart';

class LevelAssessmentScreen extends StatefulWidget {
  final UserProfile userProfile;
  const LevelAssessmentScreen({super.key, required this.userProfile});

  @override
  State<LevelAssessmentScreen> createState() => _LevelAssessmentScreenState();
}

class _LevelAssessmentScreenState extends State<LevelAssessmentScreen> {
  static const _levelNames = [
    'Principiante', 'Intermedio', 'Avanzado',
    'Experto', 'Experto Avanzado', 'Maestro',
  ];

  // ✅ Cantidad de preguntas del examen según el nivel actual
  static const _questionsByLevel = [8, 10, 12, 14, 16, 20];

  // ✅ Segundos por pregunta según el nivel (más difícil = más tiempo)
  static const _secondsByLevel = [20, 25, 30, 35, 40, 45];

  List<Map<String, dynamic>> _questions = [];
  int _currentLevel = 0;
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _answered = false;

  bool _loading = true;
  bool _finished = false;
  bool _noQuestions = false; // si el usuario aún no domina nada

  // ⏱️ Timer por pregunta
  Timer? _timer;
  int _remaining = 0;
  int _timePerQuestion = 20;

  @override
  void initState() {
    super.initState();
    _prepareExam();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _asInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  /// Extrae los IDs de preguntas que el usuario ACERTÓ o CORRIGIÓ.
  /// Busca en varios campos posibles por compatibilidad con tu schema.
  List<String> _extractMasteredIds(Map<String, dynamic> data) {
    final ids = <String>{};

    // 1) Lista directa de correctas (nombres posibles)
    for (final key in ['correctQuestionIds', 'masteredQuestions', 'answeredCorrectly']) {
      final raw = data[key];
      if (raw is List) {
        for (final e in raw) {
          final s = e?.toString();
          if (s != null && s.isNotEmpty) ids.add(s);
        }
      }
    }

    // 2) De los errores, los que fueron corregidos
    final mistakes = data['mistakes'];
    if (mistakes is List) {
      for (final m in mistakes) {
        if (m is Map && m['corrected'] == true) {
          final qid = m['questionId']?.toString() ?? m['id']?.toString();
          if (qid != null && qid.isNotEmpty) ids.add(qid);
        }
      }
    }

    return ids.toList();
  }

  Future<void> _prepareExam() async {
    final ref = ProfileDataService.refFor(widget.userProfile.id);
    Map<String, dynamic> profileData = {};
    if (ref != null) {
      final doc = await ref.get();
      if (doc.exists) profileData = doc.data() ?? {};
    }

    final level = _asInt(profileData['level']).clamp(0, 5);
    final needed = _questionsByLevel[level];
    final masteredIds = _extractMasteredIds(profileData);

    // 1) Preguntas dominadas (acertadas o corregidas)
    List<Map<String, dynamic>> pool = await QuestionService.getQuestionsByIds(masteredIds);

    // 2) Si faltan para completar el examen, rellenar con opción múltiple
    //    de los temas que ya practicó (topicMastery > 0) o de todo el banco.
    if (pool.length < needed) {
      final allMc = await QuestionService.getMultipleChoiceQuestions();
      final practicedTopics = <String>{};
      final tm = profileData['topicMastery'];
      if (tm is Map) {
        tm.forEach((k, v) {
          final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
          if (d > 0) practicedTopics.add(k.toString());
        });
      }
      final existingIds = pool.map((q) => q['id'].toString()).toSet();
      final fillers = allMc.where((q) {
        final id = q['id']?.toString();
        if (id == null || existingIds.contains(id)) return false;
        final tema = q['tema']?.toString() ?? '';
        return practicedTopics.isEmpty || practicedTopics.contains(tema);
      }).toList()..shuffle();

      pool.addAll(fillers);
    }

    // 3) Tomar exactamente 'needed' y mezclar
    pool.shuffle();
    final exam = pool.length >= needed ? pool.sublist(0, needed) : pool;

    if (!mounted) return;
    setState(() {
      _currentLevel = level;
      _questions = exam;
      _timePerQuestion = _secondsByLevel[level];
      _remaining = _timePerQuestion;
      _noQuestions = exam.isEmpty;
      _loading = false;
    });

    if (exam.isNotEmpty) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remaining = _timePerQuestion);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_answered) return;
      if (_remaining <= 1) {
        t.cancel();
        _onTimeout();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _onTimeout() {
    // Se acaba el tiempo: cuenta como incorrecta
    setState(() {
      _answered = true;
      _selected = null;
    });
    Future.delayed(const Duration(milliseconds: 900), _next);
  }

  void _answer(int i) {
    if (_answered) return;
    _timer?.cancel();
    final q = _questions[_index];
    final correctIdx = _asInt(q['respuesta_correcta']);
    setState(() {
      _selected = i;
      _answered = true;
      if (i == correctIdx) _correct++;
    });
    Future.delayed(const Duration(milliseconds: 700), _next);
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
    });
    _startTimer();
  }

  /// ✅ Reglas: ≥80% sube, 50–79% mantiene, <50% baja.
  /// En nivel 0 no puede bajar más. En nivel 5 (Maestro) puede BAJAR si falla.
  int _applyRules(double score) {
    if (score >= 0.80) return (_currentLevel + 1).clamp(0, 5);
    if (score >= 0.50) return _currentLevel;
    return (_currentLevel - 1).clamp(0, 5);
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final score = _questions.isEmpty ? 0.0 : _correct / _questions.length;
    final newLevel = _applyRules(score);

    final ref = ProfileDataService.refFor(widget.userProfile.id);
    if (ref != null) {
      await ref.set({'level': newLevel}, SetOptions(merge: true));
    }

    if (!mounted) return;
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          _finished ? 'Resultado' : 'Examen de Nivelación',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _noQuestions
              ? _buildEmpty()
              : _finished
                  ? _buildResult()
                  : _buildQuestion(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty_rounded,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes preguntas dominadas',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Responde preguntas en los módulos y corrige tus errores '
              'en "Mis Errores" para desbloquear tu examen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: Text('Volver',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_index];
    final options = List<String>.from(q['opciones'] ?? []);
    final correctIdx = _asInt(q['respuesta_correcta']);
    final progress = (_index + 1) / _questions.length;
    final timeFraction = _remaining / _timePerQuestion;
    final timeColor = _remaining <= 5 ? AppColors.error : AppColors.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progreso del examen
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pregunta ${_index + 1} de ${_questions.length}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                Text(
                  _levelNames[_currentLevel],
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),

            // ⏱️ Timer
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: timeFraction),
                duration: const Duration(milliseconds: 250),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: _answered ? 0.0 : v,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(timeColor),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.timer_rounded, color: timeColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  _answered ? 'Tiempo detenido' : '$_remaining s',
                  style: TextStyle(
                      color: timeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['pregunta']?.toString() ?? 'Pregunta sin texto',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (int i = 0; i < options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _option(i, options[i], correctIdx),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(int i, String text, int correctIdx) {
    Color bg = AppColors.surfaceCard;
    Color border = AppColors.border;
    Color textColor = AppColors.textPrimary;

    if (_answered) {
      if (i == correctIdx) {
        bg = AppColors.success.withValues(alpha: 0.15);
        border = AppColors.success;
        textColor = AppColors.success;
      } else if (i == _selected) {
        bg = AppColors.error.withValues(alpha: 0.15);
        border = AppColors.error;
        textColor = AppColors.error;
      } else {
        textColor = AppColors.textMuted;
      }
    }

    return GestureDetector(
      onTap: _answered ? null : () => _answer(i),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: border.withValues(alpha: 0.2),
              ),
              child: Center(
                child: Text(String.fromCharCode(65 + i),
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text,
                    style: TextStyle(color: textColor, fontSize: 15))),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final score = _correct / _questions.length;
    final pct = (score * 100).round();
    final newLevel = _applyRules(score);
    final wentUp = newLevel > _currentLevel;
    final wentDown = newLevel < _currentLevel;

    final Color resultColor = wentUp
        ? AppColors.success
        : wentDown
            ? AppColors.error
            : AppColors.info;

    final String resultText = wentUp
        ? '¡Subiste de nivel!'
        : wentDown
            ? 'Bajaste de nivel'
            : 'Mantuviste tu nivel';

    final String message = _currentLevel == 5
        ? (wentDown
            ? 'No alcanzaste el 80%. Como Maestro, tu nivel baja a ${_levelNames[newLevel]}.'
            : 'Excelente. Mantienes tu rango de Maestro.')
        : wentUp
            ? 'Superaste el 80%. Ahora eres ${_levelNames[newLevel]}.'
            : wentDown
                ? 'No llegaste al 50%. Bajas a ${_levelNames[newLevel]} para reforzar.'
                : 'Entre 50% y 79%. Sigues siendo ${_levelNames[newLevel]}. ¡Sigue así!';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: resultColor.withValues(alpha: 0.15),
                border: Border.all(color: resultColor, width: 3),
              ),
              child: Center(
                child: Text('$pct%',
                    style: TextStyle(
                        color: resultColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 20),
            Text(resultText,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Aciertos: $_correct de ${_questions.length}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: resultColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: resultColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Volver al inicio',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}