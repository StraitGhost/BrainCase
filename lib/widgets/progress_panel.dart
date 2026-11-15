// lib/widgets/progress_panel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_preferences.dart';
import '../services/profile_data_service.dart';

double _asDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0.0;

Map<String, double> _parseMastery(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map((k, v) =>
      MapEntry(k.toString(), _asDouble(v).clamp(0.0, 1.0).toDouble()));
}

/// Panel de progreso general DE UN PERFIL.
class ProgressPanel extends StatefulWidget {
  final String profileId;
  final int completedCases;
  final int totalCases;
  final Map<String, double> topicMastery;
  final List<Map<String, dynamic>> dynamicModulesData; // ✅ NUEVO PARÁMETRO

  const ProgressPanel({
    super.key,
    required this.profileId,
    this.completedCases = 0,
    this.totalCases = 0,
    this.topicMastery = const {},
    required this.dynamicModulesData, // ✅ REQUERIDO
  });

  @override
  State<ProgressPanel> createState() => _ProgressPanelState();
}

class _ProgressPanelState extends State<ProgressPanel> {
  static const double _listHeight = 230;

  final ScrollController _scroll = ScrollController();
  late Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _stream = ProfileDataService.refFor(widget.profileId)?.snapshots();
  }

  @override
  void didUpdateWidget(covariant ProgressPanel old) {
    super.didUpdateWidget(old);
    if (old.profileId != widget.profileId) {
      _stream = ProfileDataService.refFor(widget.profileId)?.snapshots();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ✅ Convierte los datos dinámicos al formato que usa la UI del panel
  List<({String name, IconData icon, Color color})> _getTopics() {
    return widget.dynamicModulesData.map((data) {
      return (
        name: data['name'] as String,
        icon: data['icon'] as IconData,
        color: data['color'] as Color,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemePreferences.instance.themeMode,
      builder: (context, _, __) {
        final stream = _stream;
        if (stream == null) {
          return _buildPanel(widget.topicMastery, widget.completedCases);
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            var mastery = widget.topicMastery;
            var completed = widget.completedCases;

            if (snap.hasData && snap.data!.exists) {
              final m = snap.data!.data() ?? <String, dynamic>{};

              // Siempre el dominio del perfil (vacío = 0%)
              mastery = _parseMastery(m['topicMastery']);

              final raw = m['completedCases'];
              if (completed == 0) {
                if (raw is List) {
                  completed = raw.length;
                } else if (raw is num) {
                  completed = raw.toInt();
                }
              }
            }
            return _buildPanel(mastery, completed);
          },
        );
      },
    );
  }

  Widget _buildPanel(Map<String, double> mastery, int completed) {
    final topicsList = _getTopics(); // ✅ Usamos la lista dinámica

    if (topicsList.isEmpty) {
      return const SizedBox.shrink();
    }

    final general = (topicsList.fold<double>(0.0,
                (sum, t) => sum + (mastery[t.name] ?? 0.0).clamp(0.0, 1.0)) /
            topicsList.length)
        .clamp(0.0, 1.0);

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
            'Tu progreso general',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: general,
                        strokeWidth: 8,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    Text(
                      '${(general * 100).round()}%',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: SizedBox(
                  height: _listHeight,
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.only(right: 12),
                      physics: const BouncingScrollPhysics(),
                      children: topicsList.map((topic) { // ✅ Mapeamos la lista dinámica
                        final value = (mastery[topic.name] ?? 0.0).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(topic.icon, color: topic.color, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      topic.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(value * 100).round()}%',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: value,
                                  backgroundColor: AppColors.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}