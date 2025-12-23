import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// ──────────── Виджет переключателя вкладок карты ────────────
/// Выделен отдельно, чтобы избежать дублирования и упростить тестирование.
class MapTabsWidget extends StatelessWidget {
  const MapTabsWidget({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final shadowColor = isDark ? null : AppColors.shadowMedium;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: shadowColor != null
                  ? [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: List.generate(tabs.length, (index) {
                final isSelected = selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (selectedIndex == index) return;
                      onSelect(index);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.getTextPrimaryColor(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Text(
                        tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w500 : FontWeight.w400,
                          color: isSelected
                              ? AppColors.getSurfaceColor(context)
                              : AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

