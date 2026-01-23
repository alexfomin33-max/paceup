// lib/features/leaderboard/widgets/city_autocomplete_field.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет автокомплита для поиска города с валидацией
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ПОЛЕ АВТОКОМПЛИТА ДЛЯ ГОРОДА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет автокомплита для поиска города с обязательным выбором из списка
class CityAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSelected;
  final VoidCallback? onSubmitted; // Callback для нажатия Enter
  final bool hasError; // Показывать ли ошибку
  final String? errorText; // Текст ошибки
  final String? hintText; // Подсказка
  final bool showBorder; // Показывать ли обводку поля
  final EdgeInsetsGeometry? contentPadding; // Паддинг внутри поля ввода

  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.onSubmitted,
    this.hasError = false,
    this.errorText,
    this.hintText,
    this.showBorder = true,
    this.contentPadding,
  });

  @override
  State<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends State<CityAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  String? _selectedCity; // Храним выбранный город из списка

  @override
  void initState() {
    super.initState();
    // Инициализируем выбранный город, если он уже есть в контроллере
    if (widget.controller.text.isNotEmpty) {
      final city = widget.controller.text.trim();
      if (widget.suggestions.contains(city)) {
        _selectedCity = city;
      }
    }

    // Слушаем изменения в контроллере
    widget.controller.addListener(_onControllerChanged);

    // Слушаем потерю фокуса для валидации
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    // Если текст изменился не через выбор из списка, сбрасываем выбранный город
    if (widget.controller.text.trim() != _selectedCity) {
      _selectedCity = null;
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // При потере фокуса проверяем, что город выбран из списка
      final city = widget.controller.text.trim();
      if (city.isNotEmpty && !widget.suggestions.contains(city)) {
        // Город не найден в списке - очищаем поле
        widget.controller.clear();
        _selectedCity = null;
        setState(() {});
      }
    }
  }

  /// Проверяет, что город выбран из списка
  bool get isValid => _selectedCity != null && _selectedCity!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? AppColors.error
        : AppColors.getBorderColor(context);

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return widget.suggestions.where((city) {
          return city.toLowerCase().startsWith(query);
        });
      },
      onSelected: (String city) {
        // Город выбран из списка
        _selectedCity = city;
        widget.controller.text = city;
        widget.onSelected(city);
        setState(() {});
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Инициализируем текст из внешнего контроллера
            if (textEditingController.text.isEmpty &&
                widget.controller.text.isNotEmpty) {
              textEditingController.text = widget.controller.text;
            }

            // Синхронизируем изменения в Autocomplete контроллере с внешним
            textEditingController.addListener(() {
              if (textEditingController.text != widget.controller.text) {
                widget.controller.text = textEditingController.text;
                // Если текст не совпадает с выбранным городом, сбрасываем выбор
                if (textEditingController.text.trim() != _selectedCity) {
                  _selectedCity = null;
                }
              }
            });

            // Используем наш FocusNode для отслеживания потери фокуса
            return Focus(
              focusNode: _focusNode,
              child: TextField(
                controller: textEditingController,
                focusNode: focusNode,
                onSubmitted: (String value) {
                  onFieldSubmitted();
                  // Вызываем дополнительный callback, если он предоставлен
                  if (widget.onSubmitted != null) {
                    widget.onSubmitted!();
                  }
                },
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Введите город',
                  hintStyle: AppTextStyles.h14w4Place,
                  filled: true,
                  fillColor: AppColors.getSurfaceColor(context),
                  contentPadding:
                      widget.contentPadding ??
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
                  border: widget.showBorder
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: borderColor, width: 1),
                        )
                      : OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                  enabledBorder: widget.showBorder
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: borderColor, width: 1),
                        )
                      : OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                  focusedBorder: widget.showBorder
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(color: borderColor, width: 1),
                        )
                      : OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide.none,
                        ),
                  errorText: widget.hasError
                      ? (widget.errorText ?? 'Выберите город из списка')
                      : null,
                  errorMaxLines: 2,
                ),
              ),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Text(
                            option,
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}
