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

  // ✅ Preguntas del examen por nivel: 25, 35, 45, 55, 65, 75
  static const _questionsByLevel = [25, 35, 45, 55, 65, 75];

  // Segundos disponibles POR PREGUNTA (el cronómetro del encabezado es el total)
  static const _secondsByLevel = [20, 25, 30, 35, 40, 45];

  static const _pointsPerCorrect = 10;

  List<Map<String, dynamic>> _questions = [];
  int _currentLevel = 0;
  int _index = 0;
  int _correct = 0;
  int? _selected;
  int _committedIndex = -1; // última pregunta ya contabilizada

  bool _loading = true;
  bool _finished = false;
  bool _finishing = false;
  bool _noQuestions = false;

  Timer? _timer;
  int _totalRemaining = 0;

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

  // ✅ El nivel sale del campo `experienceLevel` (texto) del documento
  int _levelFrom(Map<String, dynamic> data) {
    final i = _levelNames.indexOf('${data['experienceLevel'] ?? ''}'.trim());
    return i < 0 ? 0 : i;
  }

  List<String> _extractMasteredIds(Map<String, dynamic> data) {
    final ids = <String>{};
    for (final key in [
      'correctQuestionIds', 'masteredQuestions', 'answeredCorrectly'
    ]) {
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
    return ids.toList();
  }

  Future<void> _prepareExam() async {
    final ref = ProfileDataService.refFor(widget.userProfile.id);
    Map<String, dynamic> profileData = {};
    if (ref != null) {
      final doc = await ref.get();
      if (doc.exists) profileData = doc.data() ?? {};
    }

    final level = _levelFrom(profileData);
    final needed = _questionsByLevel[level];
    final masteredIds = _extractMasteredIds(profileData);

    List<Map<String, dynamic>> pool =
        await QuestionService.getQuestionsByIds(masteredIds);

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
      }).toList()
        ..shuffle();
      pool.addAll(fillers);
    }

    pool.shuffle();
    final exam = pool.length >= needed ? pool.sublist(0, needed) : pool;

    if (!mounted) return;
    setState(() {
      _currentLevel = level;
      _questions = exam;
      _totalRemaining = exam.length * _secondsByLevel[level];
      _noQuestions = exam.isEmpty;
      _loading = false;
    });
    if (exam.isNotEmpty) _startTimer();
  }

  // ───────────── Cronómetro global ─────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_totalRemaining <= 1) {
        t.cancel();
        setState(() => _totalRemaining = 0);
        _commitCurrent(); // cuenta la selección pendiente, si la hay
        _finish();
      } else {
        setState(() => _totalRemaining--);
      }
    });
  }

  String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  // ───────────── Flujo de preguntas ─────────────
  void _select(int i) {
    if (_finishing) return;
    setState(() => _selected = i);
  }

  /// Contabiliza la respuesta de la pregunta actual (una sola vez).
  void _commitCurrent() {
    if (_committedIndex == _index || _selected == null) return;
    _committedIndex = _index;
    final correctIdx = _asInt(_questions[_index]['respuesta_correcta']);
    if (_selected == correctIdx) _correct++;
  }

  void _onNext() {
    if (_selected == null || _finishing) return;
    setState(_commitCurrent);

    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  int _applyRules(double score) {
    if (score >= 0.80) return (_currentLevel + 1).clamp(0, 5);
    if (score >= 0.50) return _currentLevel;
    return (_currentLevel - 1).clamp(0, 5);
  }

  Future<void> _finish() async {
    if (_finishing || _finished) return;
    _finishing = true;
    _timer?.cancel();

    final score = _questions.isEmpty ? 0.0 : _correct / _questions.length;
    final newLevel = _applyRules(score);

    try {
      final ref = ProfileDataService.refFor(widget.userProfile.id);
      if (ref != null) {
        // ✅ Suba, se quede o baje: el progreso vuelve a 0.
        // La línea base se iguala a los aciertos totales ACTUALES.
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final data = snap.data() ?? <String, dynamic>{};
          final totalNow = _asInt(data['correctAnswers']);
          tx.set(
            ref,
            {
              'level': newLevel,
              'experienceLevel': _levelNames[newLevel], // ✅ nivel en texto
              'correctAnswersAtLastExam': totalNow,
            },
            SetOptions(merge: true),
          );
        });
      }
    } catch (e) {
      debugPrint('❌ Error guardando resultado del examen: $e');
    }

    if (!mounted) return;
    setState(() => _finished = true);
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text('¿Salir del examen?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text('Perderás tu avance en este examen.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Continuar', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salir',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  // ───────────── UI ─────────────
  @override
  Widget build(BuildContext context) {
    final inExam = !_loading && !_noQuestions && !_finished;

    return PopScope(
      canPop: !inExam,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.background, AppColors.surface],
            ),
          ),
          child: SafeArea(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _noQuestions
                    ? _buildEmpty()
                    : _finished
                        ? _buildResult()
                        : _buildExam(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required String title, bool showTimer = true}) {
    final low = _totalRemaining <= 60;
    final timerColor = low ? AppColors.error : AppColors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.primary.withValues(alpha: 0.28),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceCard,
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 30, color: AppColors.border),
          const SizedBox(width: 14),
          Icon(Icons.psychology_rounded, color: AppColors.primary, size: 36),
          const SizedBox(width: 12),
          Container(width: 1, height: 30, color: AppColors.border),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
          ),
          if (showTimer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: AppColors.background.withValues(alpha: 0.6),
                border: Border.all(color: timerColor, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, color: timerColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _fmt(_totalRemaining),
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExam() {
    final q = _questions[_index];
    final options = List<String>.from(q['opciones'] ?? []);
    final progress = (_index + 1) / _questions.length;
    final isLast = _index + 1 >= _questions.length;
    final hasSelection = _selected != null;

    return Column(
      children: [
        _buildHeader(title: 'Examen de Nivelación'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pregunta ${_index + 1} de ${_questions.length}',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _levelNames[_currentLevel],
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 9,
                          backgroundColor: AppColors.border,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: AppColors.primary, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          '${_correct * _pointsPerCorrect} p',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _questionCard(q['pregunta']?.toString() ?? 'Pregunta sin texto'),
                    const SizedBox(height: 18),
                    for (int i = 0; i < options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _option(i, options[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildFooter(isLast: isLast, enabled: hasSelection),
      ],
    );
  }

  Widget _questionCard(String text) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: Icon(Icons.question_mark_rounded,
                          color: AppColors.textOnPrimary, size: 26),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
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

  Widget _option(int i, String text) {
    final selected = _selected == i;
    final c = AppColors.primary;

    return GestureDetector(
      onTap: () => _select(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.18) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c : AppColors.border,
            width: selected ? 2 : 1.2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: c.withValues(alpha: 0.25), blurRadius: 16)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c : c.withValues(alpha: 0.25),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + i),
                  style: TextStyle(
                    color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter({required bool isLast, required bool enabled}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.primary.withValues(alpha: 0.2),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    child: Icon(Icons.info_rounded,
                        color: AppColors.textPrimary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Selecciona la respuesta correcta y continúa.',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: enabled ? AppColors.primary : AppColors.surfaceCard,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: enabled ? _onNext : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      color: enabled ? AppColors.textOnPrimary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isLast ? 'Finalizar' : 'Siguiente',
                      style: TextStyle(
                        color: enabled ? AppColors.textOnPrimary : AppColors.textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(
      children: [
        _buildHeader(title: 'Examen de Nivelación', showTimer: false),
        Expanded(
          child: Center(
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
                        style: TextStyle(color: AppColors.textOnPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final score = _questions.isEmpty ? 0.0 : _correct / _questions.length;
    final pct = (score * 100).round();
    final newLevel = _applyRules(score);
    final wentUp = newLevel > _currentLevel;
    final wentDown = newLevel < _currentLevel;

    final Color resultColor = wentUp
        ? AppColors.success
        : wentDown
            ? AppColors.error
            : AppColors.info;

    final IconData resultIcon = wentUp
        ? Icons.check_rounded
        : wentDown
            ? Icons.priority_high_rounded
            : Icons.info_rounded;

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
                : 'Entre 50% y 79%. Sigues siendo ${_levelNames[newLevel]}.';

    final String detail = wentUp
        ? '¡Excelente trabajo! Tu esfuerzo está dando frutos.'
        : wentDown
            ? 'Tu progreso indica que necesitas repasar los conceptos.'
            : '¡Sigue practicando para subir de nivel!';

    return Stack(
      children: [
        // Decoración de fondo
        Positioned(
          top: -90,
          left: -90,
          child: _bgCircle(260, AppColors.primary.withValues(alpha: 0.18)),
        ),
        Positioned(
          top: -120,
          right: -100,
          child: _bgCircle(300, AppColors.primary.withValues(alpha: 0.14)),
        ),
        Positioned(
          bottom: -130,
          left: -110,
          child: _bgCircle(320, AppColors.primary.withValues(alpha: 0.12)),
        ),
        Positioned(
          bottom: -90,
          right: -80,
          child: _bgCircle(240, AppColors.primary.withValues(alpha: 0.16)),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cerebro con líneas
                  Row(
                    children: [
                      Expanded(child: _fadeLine(true)),
                      const SizedBox(width: 14),
                      Icon(Icons.psychology_rounded,
                          color: AppColors.primary, size: 56),
                      const SizedBox(width: 14),
                      Expanded(child: _fadeLine(false)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Anillo de porcentaje + trofeo
                        SizedBox(
                          width: 190,
                          height: 190,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: score.clamp(0.0, 1.0)),
                                duration: const Duration(milliseconds: 1100),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => SizedBox(
                                  width: 170,
                                  height: 170,
                                  child: CircularProgressIndicator(
                                    value: v,
                                    strokeWidth: 12,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary),
                                  ),
                                ),
                              ),
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Positioned(
                                right: 10,
                                bottom: 22,
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.warning.withValues(alpha: 0.18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.warning
                                            .withValues(alpha: 0.35),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  child: const Text('🏆',
                                      style: TextStyle(fontSize: 30)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          resultText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Acertaste: $_correct de ${_questions.length}',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: resultColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: resultColor.withValues(alpha: 0.7)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: resultColor,
                                ),
                                child: Icon(resultIcon,
                                    color: AppColors.textOnPrimary, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message,
                                      style: TextStyle(
                                        color: resultColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      detail,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tu progreso volvió a 0. Completa nuevas lecciones para el próximo examen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 18),
                        Material(
                          color: AppColors.primary,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: double.infinity,
                              constraints:
                                  const BoxConstraints(minHeight: 58),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22),
                              child: Row(
                                children: [
                                  const SizedBox(width: 24),
                                  const Spacer(),
                                  Icon(Icons.home_outlined,
                                      color: AppColors.textOnPrimary, size: 26),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Volver al Inicio',
                                    style: TextStyle(
                                      color: AppColors.textOnPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right_rounded,
                                      color: AppColors.textOnPrimary, size: 28),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bgCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _fadeLine(bool fadeToRight) => Container(
        height: 1.5,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: fadeToRight
                ? [Colors.transparent, AppColors.primary.withValues(alpha: 0.6)]
                : [AppColors.primary.withValues(alpha: 0.6), Colors.transparent],
          ),
        ),
      );
}