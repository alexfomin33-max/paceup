import 'package:flutter/material.dart';
import '../../../../../../../core/theme/app_theme.dart';

/// ───────────────────── Правый TextField с автодополнением ─────────────────────
class AutocompleteTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Future<List<String>> Function(String) onSearch;
  final bool enabled;
  final VoidCallback? onChanged;
  final void Function(FocusNode)? onFocusNodeCreated;

  const AutocompleteTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSearch,
    this.enabled = true,
    this.onChanged,
    this.onFocusNodeCreated,
  });

  @override
  State<AutocompleteTextField> createState() => _AutocompleteTextFieldState();
}

class _AutocompleteTextFieldState extends State<AutocompleteTextField> {
  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (!widget.enabled || textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return await widget.onSearch(textEditingValue.text);
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Сохраняем FocusNode для внешнего доступа
            widget.onFocusNodeCreated?.call(focusNode);

            // Синхронизируем контроллеры
            if (textEditingController.text != widget.controller.text) {
              textEditingController.text = widget.controller.text;
            }
            textEditingController.addListener(() {
              if (textEditingController.text != widget.controller.text) {
                widget.controller.text = textEditingController.text;
              }
            });

            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: textEditingController,
              builder: (context, value, child) {
                final isEmpty = value.text.trim().isEmpty;
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  enabled: widget.enabled,
                  textAlign: TextAlign.right,
                  onChanged: (value) {
                    widget.onChanged?.call();
                  },
                  onSubmitted: (String value) {
                    onFieldSubmitted();
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hint,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.getTextPlaceholderColor(context),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: isEmpty
                        ? AppColors.getTextPlaceholderColor(context)
                        : AppColors.getTextPrimaryColor(context),
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                  ),
                );
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topRight,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 180,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Text(
                            option,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
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
