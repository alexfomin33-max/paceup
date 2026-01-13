import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';

/// ──────────── Bottom Sheet для фильтров клубов ────────────
///
/// Отображает фильтры: вид спорта, тип клуба.
/// Использует стиль iOS с BouncingScrollPhysics и AppTheme токенами.
class ClubsFiltersBottomSheet extends StatefulWidget {
  /// Callback для применения фильтров
  /// Передает параметры фильтра: виды спорта, типы клубов
  final Function(ClubsFilterParams)? onApplyFilters;

  /// Начальные параметры фильтра (для восстановления состояния)
  final ClubsFilterParams? initialParams;

  const ClubsFiltersBottomSheet({
    super.key,
    this.onApplyFilters,
    this.initialParams,
  });

  @override
  State<ClubsFiltersBottomSheet> createState() =>
      _ClubsFiltersBottomSheetState();
}

class _ClubsFiltersBottomSheetState extends State<ClubsFiltersBottomSheet> {
  // ──── Состояние фильтров ────

  /// Выбранные виды спорта (множественный выбор, минимум один)
  late Set<SportType> _selectedSports;

  /// Выбранные типы клубов (множественный выбор, минимум один)
  late Set<ClubType> _selectedClubTypes;

  // ──── Инициализация фильтров ────
  @override
  void initState() {
    super.initState();

    // Восстанавливаем параметры из initialParams, если они есть
    if (widget.initialParams != null) {
      _selectedSports = widget.initialParams!.sports.toSet();
      _selectedClubTypes = widget.initialParams!.clubTypes.toSet();
    } else {
      // Устанавливаем дефолтные значения
      _selectedSports = {
        SportType.run,
        SportType.bike,
        SportType.ski,
        SportType.swim,
      };
      _selectedClubTypes = {ClubType.open, ClubType.closed};
    }
  }

  // ──── Применение фильтров ────
  void _applyFilters() {
    // Формируем параметры фильтра
    final params = ClubsFilterParams(
      sports: _selectedSports.toList(),
      clubTypes: _selectedClubTypes.toList(),
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
              thickness: 1,
              color: AppColors.getBorderColor(context),
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
                  // ──── Секция "Вид спорта" ────
                  const _SectionTitle('Вид спорта'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: SportType.values.map((sport) {
                      final isSelected = _selectedSports.contains(sport);
                      return _SportPillButton(
                        sport: sport,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              // Нельзя снять последний выбранный вид спорта
                              if (_selectedSports.length > 1) {
                                _selectedSports.remove(sport);
                              }
                            } else {
                              _selectedSports.add(sport);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ──── Секция "Тип клуба" ────
                  const _SectionTitle('Тип клуба'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ClubType.values.map((type) {
                      final isSelected = _selectedClubTypes.contains(type);
                      return _ClubTypePillButton(
                        type: type,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              // Нельзя снять последний выбранный тип клуба
                              if (_selectedClubTypes.length > 1) {
                                _selectedClubTypes.remove(type);
                              }
                            } else {
                              _selectedClubTypes.add(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 34),

                  // ──── Кнопка "Применить" ────
                  Center(
                    child: PrimaryButton(
                      text: 'Применить',
                      onPressed: _applyFilters,
                      width: MediaQuery.of(context).size.width * 0.5,
                    ),
                  ),
                  const SizedBox(height: 26),
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

/// Кнопка-пилюля для вида спорта
class _SportPillButton extends StatelessWidget {
  final SportType sport;
  final bool isSelected;
  final VoidCallback onTap;

  const _SportPillButton({
    required this.sport,
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
              Icon(sport.icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                sport.label,
                style: AppTextStyles.h14w4.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка-пилюля для типа клуба
class _ClubTypePillButton extends StatelessWidget {
  final ClubType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _ClubTypePillButton({
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

/// Параметры фильтра клубов
class ClubsFilterParams {
  /// Выбранные виды спорта
  final List<SportType> sports;

  /// Выбранные типы клубов
  final List<ClubType> clubTypes;

  const ClubsFilterParams({required this.sports, required this.clubTypes});

  /// Проверяет, применены ли какие-либо фильтры (кроме дефолтных)
  bool get hasFilters {
    // Если выбраны не все виды спорта или не все типы клубов - есть фильтры
    if (sports.length < SportType.values.length) return true;
    if (clubTypes.length < ClubType.values.length) return true;
    return false;
  }
}

/// Виды спорта для фильтра
enum SportType { run, bike, ski, swim }

extension SportTypeExtension on SportType {
  String get label {
    switch (this) {
      case SportType.run:
        return 'Бег';
      case SportType.bike:
        return 'Велосипед';
      case SportType.swim:
        return 'Плавание';
      case SportType.ski:
        return 'Лыжи';
    }
  }

  /// Преобразует вид спорта в строку для API
  String get apiValue {
    switch (this) {
      case SportType.run:
        return 'Бег';
      case SportType.bike:
        return 'Велосипед';
      case SportType.swim:
        return 'Плавание';
      case SportType.ski:
        return 'Лыжи';
    }
  }

  IconData get icon {
    switch (this) {
      case SportType.run:
        return Icons.directions_run;
      case SportType.bike:
        return Icons.directions_bike;
      case SportType.swim:
        return Icons.pool;
      case SportType.ski:
        return Icons.downhill_skiing;
    }
  }
}

/// Типы клубов для фильтра
enum ClubType { open, closed }

extension ClubTypeExtension on ClubType {
  String get label {
    switch (this) {
      case ClubType.open:
        return 'Открытые';
      case ClubType.closed:
        return 'Закрытые';
    }
  }

  /// Преобразует тип клуба в строку для API
  String get apiValue {
    switch (this) {
      case ClubType.open:
        return 'open';
      case ClubType.closed:
        return 'closed';
    }
  }

  IconData get icon {
    switch (this) {
      case ClubType.open:
        return CupertinoIcons.lock_open; // открытый замочек
      case ClubType.closed:
        return CupertinoIcons.lock_shield_fill; // закрытый замочек
    }
  }
}
