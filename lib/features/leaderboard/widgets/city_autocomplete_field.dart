// lib/features/leaderboard/widgets/city_autocomplete_field.dart
// ─────────────────────────────────────────────────────────────────────────────
// Виджет автокомплита для поиска города
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                     ПОЛЕ АВТОКОМПЛИТА ДЛЯ ГОРОДА
// ─────────────────────────────────────────────────────────────────────────────
/// Виджет автокомплита для поиска города (аналогичен create_club_screen.dart)
class CityAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSelected;
  final VoidCallback? onSubmitted; // Callback для нажатия Enter

  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.getBorderColor(context);

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return suggestions.where((city) {
          return city.toLowerCase().startsWith(query);
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Инициализируем текст из внешнего контроллера
            if (textEditingController.text.isEmpty &&
                controller.text.isNotEmpty) {
              textEditingController.text = controller.text;
            }

            // Синхронизируем изменения в Autocomplete контроллере с внешним
            textEditingController.addListener(() {
              if (textEditingController.text != controller.text) {
                controller.text = textEditingController.text;
              }
            });

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (String value) {
                onFieldSubmitted();
                // Вызываем дополнительный callback, если он предоставлен
                if (onSubmitted != null) {
                  onSubmitted!();
                }
              },
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
              decoration: InputDecoration(
                hintText: 'Введите город',
                hintStyle: AppTextStyles.h14w4Place,
                filled: true,
                fillColor: AppColors.getSurfaceColor(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
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

