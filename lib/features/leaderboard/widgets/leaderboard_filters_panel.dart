// lib/features/leaderboard/widgets/leaderboard_filters_panel.dart
// ─────────────────────────────────────────────────────────────────────────────
// Панель фильтров лидерборда (общая для всех вкладок)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'date_range_picker.dart';
import 'leaderboard_filters.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ПАНЕЛЬ ФИЛЬТРОВ
// ─────────────────────────────────────────────────────────────────────────────
/// Панель фильтров с параметрами, периодом, видом спорта и полом
class LeaderboardFiltersPanel extends StatefulWidget {
  final String? selectedParameter;
  final int sport;
  final String? selectedPeriod;
  final bool genderMale;
  final bool genderFemale;
  final ValueChanged<String?> onParameterChanged;
  final ValueChanged<int> onSportChanged;
  final ValueChanged<String?> onPeriodChanged;
  final ValueChanged<bool> onGenderMaleChanged;
  final ValueChanged<bool> onGenderFemaleChanged;
  final ValueChanged<DateTimeRange?>? onApplyDate;

  const LeaderboardFiltersPanel({
    super.key,
    required this.selectedParameter,
    required this.sport,
    required this.selectedPeriod,
    required this.genderMale,
    required this.genderFemale,
    required this.onParameterChanged,
    required this.onSportChanged,
    required this.onPeriodChanged,
    required this.onGenderMaleChanged,
    required this.onGenderFemaleChanged,
    this.onApplyDate,
  });

  @override
  State<LeaderboardFiltersPanel> createState() =>
      _LeaderboardFiltersPanelState();
}

class _LeaderboardFiltersPanelState extends State<LeaderboardFiltersPanel> {
  // ── состояние кнопки применения даты (активна при нажатии)
  bool _applyDatePressed = false;

  // ── контроллеры для полей дат (появляются при выборе "Выбранный период")
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  // ── FocusNode для полей дат
  final _startDateFocusNode = FocusNode();
  final _endDateFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // ── Добавляем слушатели для обновления состояния кнопки при изменении текста
    _startDateController.addListener(_updateDateButtonState);
    _endDateController.addListener(_updateDateButtonState);
  }

  @override
  void dispose() {
    _startDateController.removeListener(_updateDateButtonState);
    _endDateController.removeListener(_updateDateButtonState);
    _startDateController.dispose();
    _endDateController.dispose();
    _startDateFocusNode.dispose();
    _endDateFocusNode.dispose();
    super.dispose();
  }

  // ── Обновляет состояние при изменении текста в полях дат
  void _updateDateButtonState() {
    setState(() {});
  }

  // ── форматирует дату в формат "dd.MM.yyyy"
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  // ── проверяет, заполнены ли оба поля дат полностью (по 8 цифр в каждом)
  bool _areDateFieldsComplete() {
    final startDigits = _startDateController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final endDigits = _endDateController.text.replaceAll(RegExp(r'[^\d]'), '');
    return startDigits.length == 8 && endDigits.length == 8;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Выпадающий список параметров + иконки видов спорта
        Row(
          children: [
            Expanded(
              child: ParameterDropdown(
                value: widget.selectedParameter,
                onChanged: widget.onParameterChanged,
              ),
            ),
            const SizedBox(width: 16),
            SportIcon(
              selected: widget.sport == 0,
              icon: Icons.directions_run,
              onTap: () => widget.onSportChanged(0),
            ),
            const SizedBox(width: 8),
            SportIcon(
              selected: widget.sport == 1,
              icon: Icons.directions_bike,
              onTap: () => widget.onSportChanged(1),
            ),
            const SizedBox(width: 8),
            SportIcon(
              selected: widget.sport == 2,
              icon: Icons.pool,
              onTap: () => widget.onSportChanged(2),
            ),
            const SizedBox(width: 8),
            SportIcon(
              selected: widget.sport == 3,
              icon: Icons.downhill_skiing,
              onTap: () => widget.onSportChanged(3),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Выпадающий список периода + иконки пола
        Row(
          children: [
            Expanded(
              child: PeriodDropdown(
                value: widget.selectedPeriod,
                onChanged: widget.onPeriodChanged,
              ),
            ),
            const SizedBox(width: 16),
            GenderIcon(
              selected: widget.genderMale,
              label: 'М',
              onTap: () {
                // ── Если обе выбраны, снимаем выбор с мужской
                // ── Если выбрана только женская, выбираем обе
                // ── Если выбрана только мужская, нельзя снять (должна быть активна хотя бы одна)
                if (widget.genderMale && widget.genderFemale) {
                  widget.onGenderMaleChanged(false);
                } else if (!widget.genderMale && widget.genderFemale) {
                  widget.onGenderMaleChanged(true);
                }
              },
            ),
            const SizedBox(width: 8),
            GenderIcon(
              selected: widget.genderFemale,
              label: 'Ж',
              onTap: () {
                // ── Если обе выбраны, снимаем выбор с женской
                // ── Если выбрана только мужская, выбираем обе
                // ── Если выбрана только женская, нельзя снять (должна быть активна хотя бы одна)
                if (widget.genderMale && widget.genderFemale) {
                  widget.onGenderFemaleChanged(false);
                } else if (widget.genderMale && !widget.genderFemale) {
                  widget.onGenderFemaleChanged(true);
                }
              },
            ),
          ],
        ),
        // ── Поля для выбора дат (появляются при выборе "Выбранный период")
        if (widget.selectedPeriod == 'Выбранный период') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                flex: 2,
                child: DateField(
                  controller: _startDateController,
                  focusNode: _startDateFocusNode,
                  hintText: _formatDate(
                    DateTime.now().subtract(const Duration(days: 8)),
                  ),
                  onComplete: () {
                    // ── Переключаем фокус на второе поле
                    _endDateFocusNode.requestFocus();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '—',
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: DateField(
                  controller: _endDateController,
                  focusNode: _endDateFocusNode,
                  hintText: _formatDate(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ApplyDateIcon(
                selected: _applyDatePressed,
                enabled: _areDateFieldsComplete(),
                onTap: () {
                  if (_areDateFieldsComplete() && widget.onApplyDate != null) {
                    // Парсим даты из формата dd.MM.yyyy
                    final startDateStr = _startDateController.text;
                    final endDateStr = _endDateController.text;
                    
                    try {
                      final startParts = startDateStr.split('.');
                      final endParts = endDateStr.split('.');
                      
                      if (startParts.length == 3 && endParts.length == 3) {
                        final startDate = DateTime(
                          int.parse(startParts[2]), // год
                          int.parse(startParts[1]), // месяц
                          int.parse(startParts[0]), // день
                        );
                        final endDate = DateTime(
                          int.parse(endParts[2]), // год
                          int.parse(endParts[1]), // месяц
                          int.parse(endParts[0]), // день
                        );
                        
                        setState(() {
                          _applyDatePressed = !_applyDatePressed;
                        });
                        
                        widget.onApplyDate!(DateTimeRange(
                          start: startDate,
                          end: endDate,
                        ));
                      }
                    } catch (e) {
                      // Если ошибка парсинга, просто переключаем состояние кнопки
                      setState(() {
                        _applyDatePressed = !_applyDatePressed;
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

