// ─────────────────────────────────────────────────────────────────────────────
// Общее окно редактирования маршрута (название + сложность).
// Используется на экране списка избранных маршрутов и на экране описания маршрута.
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

/// Показывает то же окно снизу, что и при сохранении маршрута: название + сложность.
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
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(ctx),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Сохранить маршрут',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Название маршрута',
                        hintStyle: TextStyle(
                          color: AppColors.getTextSecondaryColor(ctx),
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Сложность',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.getTextSecondaryColor(ctx),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'easy',
                          label: Text('Лёгкий'),
                        ),
                        ButtonSegment<String>(
                          value: 'medium',
                          label: Text('Средний'),
                        ),
                        ButtonSegment<String>(
                          value: 'hard',
                          label: Text('Сложный'),
                        ),
                      ],
                      selected: {difficulty},
                      onSelectionChanged: (Set<String> v) {
                        setModalState(() {
                          difficulty = v.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Отмена',
                              style: TextStyle(
                                color: AppColors.getTextSecondaryColor(
                                  ctx,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final name =
                                  nameController.text.trim();
                              final finalName = name.isEmpty
                                  ? route.name
                                  : name;
                              Navigator.of(ctx).pop();
                              try {
                                await RoutesService().updateRoute(
                                  routeId: route.id,
                                  userId: userId,
                                  name: finalName,
                                  difficulty: difficulty,
                                );
                                if (context.mounted) onSaved();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Маршрут сохранён',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: SelectableText.rich(
                                        TextSpan(
                                          text: 'Ошибка: $e',
                                          style: const TextStyle(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
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
