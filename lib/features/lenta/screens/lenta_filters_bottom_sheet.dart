import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';

/// ──────────── Bottom Sheet для фильтров ленты ────────────
///
/// Отображает фильтры: тип записи (Тренировки/Посты), чьи записи (Свои/Других).
/// Использует стиль iOS с BouncingScrollPhysics и AppTheme токенами.
class LentaFiltersBottomSheet extends StatefulWidget {
  /// Callback для применения фильтров
  /// Передает параметры фильтра: тип записи, чьи записи
  final Function(LentaFilterParams)? onApplyFilters;

  /// Начальные параметры фильтра (для восстановления состояния)
  final LentaFilterParams? initialParams;

  const LentaFiltersBottomSheet({
    super.key,
    this.onApplyFilters,
    this.initialParams,
  });

  @override
  State<LentaFiltersBottomSheet> createState() =>
      _LentaFiltersBottomSheetState();
}

class _LentaFiltersBottomSheetState extends State<LentaFiltersBottomSheet> {
  // ──── Состояние фильтров ────

  /// Выбранные типы записей (множественный выбор, минимум один)
  late Set<ContentType> _selectedContentTypes;

  /// Выбранные типы авторов (множественный выбор, минимум один)
  late Set<AuthorType> _selectedAuthorTypes;

  // ──── Инициализация фильтров ────
  @override
  void initState() {
    super.initState();

    // Восстанавливаем параметры из initialParams, если они есть
    if (widget.initialParams != null) {
      _selectedContentTypes = widget.initialParams!.contentTypes.toSet();
      _selectedAuthorTypes = widget.initialParams!.authorTypes.toSet();
    } else {
      // Устанавливаем дефолтные значения (все выбраны)
      _selectedContentTypes = {ContentType.trainings, ContentType.posts};
      _selectedAuthorTypes = {AuthorType.own, AuthorType.others};
    }
  }

  // ──── Применение фильтров ────
  void _applyFilters() {
    // Формируем параметры фильтра
    final params = LentaFilterParams(
      contentTypes: _selectedContentTypes.toList(),
      authorTypes: _selectedAuthorTypes.toList(),
    );

    // Вызываем callback с параметрами фильтра
    widget.onApplyFilters?.call(params);

    // Закрываем bottom sheet
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
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
              margin: const EdgeInsets.only(bottom: 10, top: 4),
              decoration: BoxDecoration(
                color: AppColors.getBorderColor(context),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            ),

            // ──── Заголовок ────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Фильтры',
                  style: AppTextStyles.h17w6.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ──── Разделительная линия ────
            Divider(
              height: 1,
              thickness: 0.5,
              color: AppColors.getBorderColor(context),
              indent: 4,
              endIndent: 4,
            ),
            const SizedBox(height: 16),

            // ──── Контент ────
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ──── Секция "Тип записи" ────
                  const _SectionTitle('Тип записи'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ContentType.values.map((type) {
                      final isSelected = _selectedContentTypes.contains(type);
                      return _ContentTypePillButton(
                        type: type,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              // Нельзя снять последний выбранный тип записи
                              if (_selectedContentTypes.length > 1) {
                                _selectedContentTypes.remove(type);
                              }
                            } else {
                              _selectedContentTypes.add(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ──── Секция "Чьи записи" ────
                  const _SectionTitle('Чьи записи'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AuthorType.values.map((type) {
                      final isSelected = _selectedAuthorTypes.contains(type);
                      return _AuthorTypePillButton(
                        type: type,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              // Нельзя снять последний выбранный тип автора
                              if (_selectedAuthorTypes.length > 1) {
                                _selectedAuthorTypes.remove(type);
                              }
                            } else {
                              _selectedAuthorTypes.add(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 34),

                  // ──── Кнопка "Применить" ────
                  ElevatedButton(
                    onPressed: _applyFilters,
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
                      'Применить',
                      style: AppTextStyles.h15w5.copyWith(
                        color: AppColors.getSurfaceColor(context),
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
    );
  }
}

// ──────────── Вспомогательные виджеты ────────────

/// Заголовок секции фильтров
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

/// Кнопка-пилюля для типа записи
class _ContentTypePillButton extends StatelessWidget {
  final ContentType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContentTypePillButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    final textColor = isSelected
        ? AppColors.surface
        : AppColors.getTextPrimaryColor(context);
    final borderColor = isSelected
        ? AppColors.brandPrimary
        : AppColors.getBorderColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: AppTextStyles.h14w4.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка-пилюля для типа автора
class _AuthorTypePillButton extends StatelessWidget {
  final AuthorType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _AuthorTypePillButton({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    final textColor = isSelected
        ? AppColors.surface
        : AppColors.getTextPrimaryColor(context);
    final borderColor = isSelected
        ? AppColors.brandPrimary
        : AppColors.getBorderColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: AppTextStyles.h14w4.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────── Модели данных ────────────

/// Параметры фильтра ленты
class LentaFilterParams {
  /// Выбранные типы записей
  final List<ContentType> contentTypes;

  /// Выбранные типы авторов
  final List<AuthorType> authorTypes;

  const LentaFilterParams({
    required this.contentTypes,
    required this.authorTypes,
  });

  /// Проверяет, применены ли какие-либо фильтры (кроме дефолтных)
  bool get hasFilters {
    // Если выбраны не все типы записей или не все типы авторов - есть фильтры
    if (contentTypes.length < ContentType.values.length) return true;
    if (authorTypes.length < AuthorType.values.length) return true;
    return false;
  }
}

/// Типы контента для фильтра
enum ContentType { trainings, posts }

extension ContentTypeExtension on ContentType {
  String get label {
    switch (this) {
      case ContentType.trainings:
        return 'Тренировки';
      case ContentType.posts:
        return 'Посты';
    }
  }

  IconData get icon {
    switch (this) {
      case ContentType.trainings:
        return Icons.directions_run;
      case ContentType.posts:
        return CupertinoIcons.square_pencil;
    }
  }
}

/// Типы авторов для фильтра
enum AuthorType { own, others }

extension AuthorTypeExtension on AuthorType {
  String get label {
    switch (this) {
      case AuthorType.own:
        return 'Свои';
      case AuthorType.others:
        return 'Других';
    }
  }

  IconData get icon {
    switch (this) {
      case AuthorType.own:
        return CupertinoIcons.person_fill;
      case AuthorType.others:
        return CupertinoIcons.person_2_fill;
    }
  }
}
