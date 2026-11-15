// lib/services/question_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'; // ✅ Ya incluye debugPrint, no necesita foundation.dart

class QuestionService {
  static const List<String> _allTypes = [
    'completar',
    'opcion_multiple',
    'ordenar',
    'relacionar',
    'verdadero_falso',
  ];

  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  static String _pathFor(String gameType) {
    return 'assets/questions/$gameType.json';
  }

  static Future<List<Map<String, dynamic>>> _loadQuestions(String path) async {
    if (_cache.containsKey(path)) return _cache[path]!;
    try {
      final jsonString = await rootBundle.loadString(path);
      final List<dynamic> jsonData = jsonDecode(jsonString);
      final list = jsonData.map((item) => Map<String, dynamic>.from(item)).toList();
      _cache[path] = list;
      return list;
    } catch (e) {
      debugPrint('Error cargando preguntas desde $path: $e');
      return [];
    }
  }

  /// ✅ Carga TODAS las preguntas de los 5 archivos (necesario para el examen)
  static Future<List<Map<String, dynamic>>> loadAll() async {
    final all = <Map<String, dynamic>>[];
    for (final tipo in _allTypes) {
      all.addAll(await _loadQuestions(_pathFor(tipo)));
    }
    return all;
  }

  static Future<List<Map<String, dynamic>>> getQuestionsByTopic(String moduleName) async {
    List<Map<String, dynamic>> moduleQuestions = [];
    for (final tipo in _allTypes) {
      final qs = await _loadQuestions(_pathFor(tipo));
      final filtered = qs.where((q) => q['tema']?.toString() == moduleName).toList();
      moduleQuestions.addAll(filtered);
    }
    return moduleQuestions;
  }

  static Future<List<String>> getTopics() async {
    final set = <String>{};
    for (final tipo in _allTypes) {
      final qs = await _loadQuestions(_pathFor(tipo));
      for (final q in qs) {
        final t = q['tema']?.toString();
        if (t != null && t.isNotEmpty) set.add(t);
      }
    }
    return set.toList()..sort();
  }

  static Future<List<Map<String, dynamic>>> getModules() async {
    final topics = await getTopics();
    return topics.asMap().entries.map((e) => {
      'name': e.value,
      'icon': _iconFor(e.value),
      'color': _colorFor(e.key),
    }).toList();
  }

  static IconData _iconFor(String tema) {
    switch (tema.toLowerCase()) {
      case 'conciencia': return Icons.wb_sunny_outlined;
      case 'orientación': case 'orientacion': return Icons.explore_outlined;
      case 'atención': case 'atencion': return Icons.center_focus_weak_outlined;
      case 'memoria': return Icons.memory_outlined;
      case 'percepción': case 'percepcion': return Icons.visibility_outlined;
      case 'pensamiento': return Icons.psychology_outlined;
      case 'sueño': case 'sueno': return Icons.nightlight_round;
      case 'apetito': case 'apetito e ingesta': return Icons.restaurant_outlined;
      case 'sexualidad': return Icons.favorite_outline;
      case 'síndromes': case 'sindromes': return Icons.medical_services_outlined;
      default: return Icons.school_outlined;
    }
  }

  static Color _colorFor(int i) {
    const palette = [
      Color(0xFF00B4DB), Color(0xFF11998E), Color(0xFFFF512F),
      Color(0xFF8E2DE2), Color(0xFF00C6FF), Color(0xFFDA22FF),
      Color(0xFF2193b0), Color(0xFF56ab2f), Color(0xFFff9a9e), Color(0xFF536976),
    ];
    return palette[i % palette.length];
  }

  /// ✅ Carga los 5 JSON y devuelve SOLO las preguntas que tengan 'opciones'
  /// (útiles para un examen cronometrado de opción múltiple).
  static Future<List<Map<String, dynamic>>> getMultipleChoiceQuestions() async {
    final all = await loadAll();
    return all.where((q) => q.containsKey('opciones')).toList();
  }

  /// ✅ Devuelve preguntas por una lista de IDs (las que el usuario dominó).
  /// Mantiene el orden de los IDs recibidos y filtra solo las de opción múltiple.
  static Future<List<Map<String, dynamic>>> getQuestionsByIds(List<String> ids) async {
    final all = await loadAll();
    final byId = <String, Map<String, dynamic>>{};
    for (final q in all) {
      final id = q['id']?.toString();
      if (id != null) byId[id] = q;
    }
    final result = <Map<String, dynamic>>[];
    for (final id in ids) {
      final q = byId[id];
      if (q != null && q.containsKey('opciones')) result.add(q);
    }
    return result;
  }
}