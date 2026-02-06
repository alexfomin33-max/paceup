// ─────────────────────────────────────────────────────────────────────────────
// Общее окно редактирования маршрута (название + сложность).
// Используется на экране списка избранных маршрутов и на экране описания маршрута.
// Стиль приведён к единому виду с events_filters_bottom_sheet: ручка, заголовок,
// разделитель, AppTextStyles/AppRadius, одна основная кнопка.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/routes_service.dart';

/// Нормализует сложность до easy | medium | hard.
String normalizeRouteDifficulty(String d) {
  switch (d.toLowerCase()) {
    case 'easy':
      return 'easy';
    case 'hard':
      return 'hard';
    default:
      return 'medium';
  }
}

/// Показывает окно снизу: название + сложность в стиле events_filters_bottom_sheet.
void showEditRouteBottomSheet(
  BuildContext context, {
  required SavedRouteItem route,
  required int userId,
  required VoidCallback onSaved,
}) {
  String difficulty = normalizeRouteDifficulty(route.difficulty);
  final nameController = TextEditingController(text: route.name);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(ctx),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ──── Ручка для перетаскивания ────
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(
                        bottom: 10,
                        top: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getBorderColor(ctx),
                        borderRadius:
                            BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    // ──── Заголовок ────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: Center(
                        child: Text(
                          'Сохранить маршрут',
                          style: AppTextStyles.h17w6.copyWith(
                            color:
                                AppColors.getTextPrimaryColor(ctx),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ──── Разделительная линия ────
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.getBorderColor(ctx),
                      indent: 4,
                      endIndent: 4,
                    ),
                    const SizedBox(height: 16),
                    // ──── Контент ────
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _SectionTitle(
                            'Название маршрута',
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Название маршрута',
                              hintStyle: TextStyle(
                                color: AppColors
                                    .getTextSecondaryColor(ctx),
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _SectionTitle('Сложность'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _DifficultyPillButton(
                                label: 'Лёгкий',
                                value: 'easy',
                                selected: difficulty == 'easy',
                                onTap: () {
                                  setModalState(() {
                                    difficulty = 'easy';
                                  });
                                },
                              ),
                              _DifficultyPillButton(
                                label: 'Средний',
                                value: 'medium',
                                selected: difficulty == 'medium',
                                onTap: () {
                                  setModalState(() {
                                    difficulty = 'medium';
                                  });
                                },
                              ),
                              _DifficultyPillButton(
                                label: 'Сложный',
                                value: 'hard',
                                selected: difficulty == 'hard',
                                onTap: () {
                                  setModalState(() {
                                    difficulty = 'hard';
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(ctx).pop(),
                            child: Text(
                              'Отмена',
                              style: TextStyle(
                                color: AppColors
                                    .getTextSecondaryColor(ctx),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final name =
                                  nameController.text.trim();
                              final finalName = name.isEmpty
                                  ? route.name
                                  : name;
                              Navigator.of(ctx).pop();
                              try {
                                await RoutesService()
                                    .updateRoute(
                                  routeId: route.id,
                                  userId: userId,
                                  name: finalName,
                                  difficulty: difficulty,
                                );
                                if (context.mounted) onSaved();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Маршрут сохранён',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content:
                                          SelectableText.rich(
                                        TextSpan(
                                          text: 'Ошибка: $e',
                                          style: const TextStyle(
                                            color:
                                                AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.button,
                              foregroundColor:
                                  AppColors.getSurfaceColor(ctx),
                              elevation: 0,
                              padding: const EdgeInsets
                                  .symmetric(horizontal: 30),
                              shape: const StadiumBorder(),
                              minimumSize: const Size(
                                double.infinity,
                                50,
                              ),
                              tapTargetSize:
                                  MaterialTapTargetSize
                                      .shrinkWrap,
                              alignment: Alignment.center,
                            ),
                            child: Text(
                              'Сохранить',
                              style: AppTextStyles.h15w5
                                  .copyWith(
                                color: AppColors
                                    .getSurfaceColor(ctx),
                                height: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ──────────── Вспомогательные виджеты ────────────

/// Заголовок секции (как в events_filters_bottom_sheet).
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.h14w6.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

/// Кнопка-пилюля для выбора сложности (в стиле _SportPillButton).
class _DifficultyPillButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _DifficultyPillButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    final textColor = selected
        ? AppColors.surface
        : AppColors.getTextPrimaryColor(context);
    final borderColor = selected
        ? AppColors.brandPrimary
        : AppColors.getBorderColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.h14w4.copyWith(
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
