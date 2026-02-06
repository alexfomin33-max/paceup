// ─────────────────────────────────────────────────────────────────────────────
// Общее окно редактирования/сохранения маршрута (название + сложность).
// Используется: список избранных маршрутов (редакт.), экран описания активности
// (сохранение из тренировки). Стиль как в events_filters_bottom_sheet.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
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

/// Показывает окно редактирования сохранённого маршрута (название + сложность).
void showEditRouteBottomSheet(
  BuildContext context, {
  required SavedRouteItem route,
  required int userId,
  required void Function(String name, String difficulty) onSaved,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (ctx) {
      return _RouteSaveSheetWrapper(
        initialName: route.name,
        initialDifficulty: normalizeRouteDifficulty(
          route.difficulty,
        ),
        fallbackName: route.name,
        onConfirm: (sheetCtx, name, difficulty) async {
          Navigator.of(sheetCtx).pop();
          try {
            await RoutesService().updateRoute(
              routeId: route.id,
              userId: userId,
              name: name,
              difficulty: difficulty,
            );
            if (context.mounted) {
              onSaved(name, difficulty);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Маршрут сохранён'),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: SelectableText.rich(
                    TextSpan(
                      text: 'Ошибка: $e',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              );
            }
          }
        },
      );
    },
  );
}

/// Показывает окно сохранения маршрута из тренировки (название + сложность).
/// [routePoints] — точки маршрута для построения превью-картинки (Mapbox).
void showSaveRouteFromActivityBottomSheet(
  BuildContext context, {
  required int userId,
  required int activityId,
  required String initialName,
  required List<LatLng> routePoints,
  void Function(SaveRouteResult result)? onSaved,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (ctx) {
      return _RouteSaveSheetWrapper(
        initialName: initialName,
        initialDifficulty: 'medium',
        fallbackName: initialName,
        onConfirm: (sheetCtx, name, difficulty) async {
          Navigator.of(sheetCtx).pop();
          final mapboxUrl = routePoints.isNotEmpty
              ? buildRouteMapboxImageUrl(routePoints)
              : null;
          try {
            final result = await RoutesService().saveRoute(
              userId: userId,
              activityId: activityId,
              name: name,
              difficulty: difficulty,
              mapboxImageUrl: mapboxUrl,
            );
            if (context.mounted) {
              onSaved?.call(result);
              final msg = result.message ??
                  (result.addedToFavorite
                      ? 'Маршрут добавлен в избранное'
                      : 'Маршрут сохранён');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: SelectableText.rich(
                    TextSpan(
                      text: 'Ошибка: ${e.toString()}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              );
            }
          }
        },
      );
    },
  );
}

/// Обёртка: отступ под клавиатуру + контейнер + общий контент листа.
class _RouteSaveSheetWrapper extends StatelessWidget {
  final String initialName;
  final String initialDifficulty;
  final String fallbackName;
  final Future<void> Function(
    BuildContext sheetCtx,
    String name,
    String difficulty,
  ) onConfirm;

  const _RouteSaveSheetWrapper({
    required this.initialName,
    required this.initialDifficulty,
    required this.fallbackName,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: GestureDetector(
            onTap: () =>
                FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.opaque,
            child: _RouteSaveSheetContent(
              initialName: initialName,
              initialDifficulty: initialDifficulty,
              fallbackName: fallbackName,
              onConfirm: onConfirm,
            ),
          ),
        ),
      ),
    );
  }
}

/// Контент листа: ручка, заголовок, поле названия, пилюли сложности, кнопка.
class _RouteSaveSheetContent extends StatefulWidget {
  final String initialName;
  final String initialDifficulty;
  final String fallbackName;
  final Future<void> Function(
    BuildContext sheetCtx,
    String name,
    String difficulty,
  ) onConfirm;

  const _RouteSaveSheetContent({
    required this.initialName,
    required this.initialDifficulty,
    required this.fallbackName,
    required this.onConfirm,
  });

  @override
  State<_RouteSaveSheetContent> createState() =>
      _RouteSaveSheetContentState();
}

class _RouteSaveSheetContentState extends State<_RouteSaveSheetContent> {
  late final TextEditingController _nameController;
  late String _difficulty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _difficulty = widget.initialDifficulty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHandle(),
        _buildTitle(),
        const SizedBox(height: 24),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SectionTitle('Название маршрута'),
              const SizedBox(height: 12),
              _buildNameField(context),
              const SizedBox(height: 24),
              const _SectionTitle('Сложность'),
              const SizedBox(height: 12),
              _buildDifficultyPills(context),
              const SizedBox(height: 40),
              _buildSaveButton(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 10, top: 4),
      decoration: BoxDecoration(
        color: AppColors.getBorderColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Text(
          'Сохранить маршрут',
          style: AppTextStyles.h17w6.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.h15w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        hintText: 'Введите название',
        hintStyle: AppTextStyles.h15w4.copyWith(
          color: AppColors.getTextSecondaryColor(context),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildDifficultyPills(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DifficultyPillButton(
          label: 'Лёгкий',
          value: 'easy',
          selected: _difficulty == 'easy',
          selectedColor: AppColors.success,
          onTap: () => setState(() => _difficulty = 'easy'),
        ),
        _DifficultyPillButton(
          label: 'Средний',
          value: 'medium',
          selected: _difficulty == 'medium',
          selectedColor: AppColors.warning,
          onTap: () => setState(() => _difficulty = 'medium'),
        ),
        _DifficultyPillButton(
          label: 'Сложный',
          value: 'hard',
          selected: _difficulty == 'hard',
          selectedColor: AppColors.error,
          onTap: () => setState(() => _difficulty = 'hard'),
        ),
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final name = _nameController.text.trim();
        final finalName =
            name.isEmpty ? widget.fallbackName : name;
        await widget.onConfirm(context, finalName, _difficulty);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.getSurfaceColor(context),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        shape: const StadiumBorder(),
        minimumSize: const Size(double.infinity, 50),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: Text(
        'Сохранить',
        style: AppTextStyles.h15w5.copyWith(
          color: AppColors.getSurfaceColor(context),
          height: 1.0,
        ),
      ),
    );
  }
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

/// Кнопка-пилюля для выбора сложности (зелёный/оранжевый/красный при выборе).
class _DifficultyPillButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _DifficultyPillButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? selectedColor
        : AppColors.getSurfaceColor(context);
    final textColor = selected
        ? AppColors.surface
        : AppColors.getTextPrimaryColor(context);
    final borderColor = selected
        ? selectedColor
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
