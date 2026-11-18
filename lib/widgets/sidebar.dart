// lib/widgets/sidebar.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/profile.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<String> menuItems;
  final List<IconData> menuIcons;
  final UserProfile profile;
  final List<Map<String, dynamic>> learningModules; // ✅ DINÁMICO

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.menuItems,
    required this.menuIcons,
    required this.profile,
    required this.learningModules, // ✅ NUEVO PARÁMETRO
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        profile.name.isNotEmpty ? profile.name.substring(0, 1).toUpperCase() : 'U';

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header con logo
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology, // 🧠 Cerebro = BrainCase (tiene sentido literal)
                    color: AppColors.textOnPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BrainCase', // ✅ Cambiado de PsyCase
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Simulador de Aprendizaje', // ✅ Cambiado (ya no es solo psicopatología)
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: AppColors.border, height: 1),

          // Menú principal
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ...List.generate(menuItems.length, (index) {
                    final isSelected = selectedIndex == index;
                    return ListTile(
                      leading: Icon(
                        menuIcons[index],
                        color: isSelected ? AppColors.primary : AppColors.sidebarText,
                      ),
                      title: Text(
                        menuItems[index],
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.sidebarTextActive
                              : AppColors.sidebarText,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w700,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                      onTap: () => onItemSelected(index),
                    );
                  }),

                  const SizedBox(height: 20),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'MÓDULOS',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ✅ LISTA DINÁMICA: se pinta con el color real de cada módulo
                  ...List.generate(learningModules.length, (index) {
                    final module = learningModules[index];
                    final moduleColor =
                        module['color'] as Color? ?? AppColors.primary;
                    return ListTile(
                      leading: Icon(
                        module['icon'] as IconData,
                        color: moduleColor.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      title: Text(
                        module['name'] as String,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      onTap: () => onItemSelected(menuItems.length + index),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Footer con información real del usuario
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profile.career ?? 'Estudiante',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}