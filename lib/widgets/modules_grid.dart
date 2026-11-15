// lib/widgets/modules_grid.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../features/game/game_screen.dart';
import '../models/profile.dart';

class AppModule {
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;
  final String? imageAsset;

  const AppModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    this.imageAsset,
  });
}

class ModulesGrid extends StatelessWidget {
  final UserProfile currentUserProfile;
  final String searchQuery;
  final List<Map<String, dynamic>> dynamicModulesData;

  const ModulesGrid({
    super.key,
    required this.currentUserProfile,
    required this.searchQuery,
    required this.dynamicModulesData,
  });

  // ✅ AHORA RECIBE EL ÍNDICE (entry.key) Y LOS DATOS (entry.value)
  AppModule _mapToAppModule(MapEntry<int, Map<String, dynamic>> entry) {
    final int index = entry.key; // 0, 1, 2, 3...
    final Map<String, dynamic> data = entry.value;
    
    final String name = data['name'] as String;
    final IconData icon = data['icon'] as IconData;
    final Color color = data['color'] as Color;

    // 🎯 LÓGICA MÁGICA: El módulo #0 usa "1.png", el #1 usa "2.png", etc.
    final String imageName = '${index + 1}.png'; 
    final String imageAsset = 'assets/images/$imageName';

    return AppModule(
      title: name,
      description: 'Casos clínicos y preguntas de $name.',
      icon: icon,
      gradient: LinearGradient(
        colors: [color, color.withValues(alpha: 0.6)], 
        begin: Alignment.topLeft, 
        end: Alignment.bottomRight,
      ),
      imageAsset: imageAsset, // Siempre intentamos cargar la imagen por índice
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Usamos asMap().entries para tener acceso al índice de cada módulo
    final List<AppModule> allModules = dynamicModulesData.asMap().entries.map(_mapToAppModule).toList();

    final filteredModules = allModules.where((module) {
      return module.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
             module.description.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    if (filteredModules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            searchQuery.isEmpty ? 'Cargando módulos...' : 'No se encontraron módulos',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: filteredModules.length,
      itemBuilder: (context, index) {
        return _ModuleCard(
          module: filteredModules[index],
          currentUserProfile: currentUserProfile,
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final AppModule module;
  final UserProfile currentUserProfile;

  const _ModuleCard({
    required this.module,
    required this.currentUserProfile,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              moduleName: module.title,
              userProfile: currentUserProfile,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: module.gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: module.gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 🛡️ EL SEGURO: Si la imagen (ej. 5.png) no existe, no rompe la app.
            // Simplemente muestra el gradiente de fondo.
            if (module.imageAsset != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.4,
                  child: Image.asset(
                    module.imageAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink(); // Fallo silencioso
                    },
                  ),
                ),
              ),
            if (module.imageAsset != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(module.icon, color: Colors.white, size: 20),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 2,
                    width: 40,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Icon(
                Icons.arrow_forward,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}