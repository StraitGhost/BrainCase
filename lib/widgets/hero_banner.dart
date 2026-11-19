// lib/features/home/widgets/hero_banner.dart
import 'package:flutter/material.dart';
import '../../../core/theme/theme_preferences.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemePreferences.instance.themeMode,
        ThemePreferences.instance.colorPalette,
      ]),
      builder: (context, _) {
        final primary = ThemePreferences.instance.primaryColor;

        // ✅ Overlay SIEMPRE oscuro (la imagen ya es oscura, no la blanquees)
        final textPrimary = Colors.white;
        final textMuted = const Color(0xFFD1D5DB);

        return LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 900;
            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withValues(alpha: 0.55), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.20),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    // 🖼️ CAPA 1: imagen como fondo total
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/brain_hero.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        gaplessPlayback: true,
                      ),
                    ),

                    // 🌑 CAPA 2: overlay oscuro sutil (no tapa la imagen)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.75),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.40),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // ✍️ CAPA 3: contenido
                    Padding(
                      padding: EdgeInsets.all(narrow ? 22 : 34),
                      child: narrow
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _badge(primary),
                                const SizedBox(height: 16),
                                _title(textPrimary, textMuted),
                                const SizedBox(height: 22),
                                _quote(primary, textMuted),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _badge(primary),
                                      const SizedBox(height: 16),
                                      _title(textPrimary, textMuted),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 3,
                                  child: _quote(primary, textMuted),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(Color primary) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.psychology, color: primary, size: 16),
          const SizedBox(width: 6),
          Text('Bienvenido a BrainCase',
              style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _title(Color t1, Color t2) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explora, analiza\ny comprende.',
            style: TextStyle(
              color: t1,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.2,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 12, offset: const Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('aprende', style: TextStyle(color: t2, fontSize: 14)),
        ],
      );

  Widget _quote(Color primary, Color muted) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: primary, size: 26),
          const SizedBox(height: 10),
          Text(
            '"La observación, el análisis y la empatía son herramientas fundamentales en la comprensión del comportamiento humano."',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              height: 1.7,
              fontStyle: FontStyle.italic,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 8),
              ],
            ),
          ),
        ],
      );
}