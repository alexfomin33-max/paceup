// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE FORM FIELDS
//
//  Переиспользуемые UI-компоненты для формы редактирования профиля
//  Включает: _FieldRow, _GroupBlock, _NameBlock, _BareTextField, _CircleIconBtn
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../core/theme/app_theme.dart';

/// Ширина лейбла для полей формы
const double kEditProfileLabelWidth = 170.0;

/// ───────────────────────────── Группа полей ─────────────────────────────

/// Контейнер для группы полей формы с общим стилем
class EditProfileGroupBlock extends StatelessWidget {
  const EditProfileGroupBlock({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.7,
        ),
        // boxShadow: [
        //   BoxShadow(
        //     color: Theme.of(context).brightness == Brightness.dark
        //         ? AppColors.darkShadowSoft
        //         : AppColors.shadowSoft,
        //     offset: const Offset(0, 1),
        //     blurRadius: 1,
        //     spreadRadius: 0,
        //   ),
        // ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.getDividerColor(context),
                indent: 10,
                endIndent: 10,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// ───────────────────────────── Строка поля ─────────────────────────────

enum EditProfileFieldRowType { input, picker, dropdown }

/// Универсальная строка поля формы (текстовое поле, пикер, выпадающий список)
class EditProfileFieldRow extends StatelessWidget {
  const EditProfileFieldRow._({
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.value,
    this.onTap,
    this.dropdownItems,
    this.onDropdownChanged,
    required this.type,
  });

  /// Фабрика для текстового поля
  factory EditProfileFieldRow.input({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => EditProfileFieldRow._(
    label: label,
    controller: controller,
    hint: hint,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    type: EditProfileFieldRowType.input,
  );

  /// Фабрика для пикера (дата, время и т.д.)
  factory EditProfileFieldRow.picker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) => EditProfileFieldRow._(
    label: label,
    value: value,
    onTap: onTap,
    type: EditProfileFieldRowType.picker,
  );

  /// Фабрика для выпадающего списка
  factory EditProfileFieldRow.dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String) onChanged,
  }) => EditProfileFieldRow._(
    label: label,
    value: value,
    dropdownItems: items,
    onDropdownChanged: onChanged,
    type: EditProfileFieldRowType.dropdown,
  );

  final String label;

  // Параметры для текстового поля
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  // Параметры для пикера
  final String? value;
  final VoidCallback? onTap;

  // Параметры для выпадающего списка
  final List<String>? dropdownItems;
  final void Function(String)? onDropdownChanged;

  final EditProfileFieldRowType type;

  Widget _buildFieldContent(BuildContext context) {
    switch (type) {
      case EditProfileFieldRowType.input:
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller!,
          builder: (context, value, child) {
            final isEmptyOrZero =
                value.text.isEmpty || value.text == '0';
            return TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTextStyles.h14w4Place,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isEmptyOrZero
                    ? AppColors.textPlaceholder
                    : AppColors.getTextPrimaryColor(context),
              ),
            );
          },
        );

      case EditProfileFieldRowType.picker:
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  (value ?? '').isEmpty ? 'Выбрать' : value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: (value ?? '').isEmpty
                        ? AppColors.getTextTertiaryColor(context)
                        : AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: AppColors.getIconSecondaryColor(context),
              ),
            ],
          ),
        );

      case EditProfileFieldRowType.dropdown:
        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            style: TextStyle(
              color: value == null || value!.isEmpty
                  ? AppColors.getTextTertiaryColor(context)
                  : AppColors.getTextPrimaryColor(context),
              fontFamily: 'Inter',
              fontSize: 14,
            ),
            hint: Text(
              'Выбрать',
              style: TextStyle(
                color: AppColors.getTextTertiaryColor(context),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            onChanged: (String? newValue) {
              if (newValue != null && onDropdownChanged != null) {
                onDropdownChanged!(newValue);
              }
            },
            items: dropdownItems?.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 13,
      color: AppColors.getTextSecondaryColor(context),
      fontWeight: FontWeight.w500,
    );

    return SizedBox(
      height: 50,
      child: Row(
        children: [
          SizedBox(
            width: kEditProfileLabelWidth,
            child: Text(label, style: labelStyle),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildFieldContent(context)),
        ],
      ),
    );
  }
}

/// ───────────────────────────── Блок имени/фамилии ─────────────────────────────

/// Блок с двумя полями (имя и фамилия) в одном контейнере
class EditProfileNameBlock extends StatelessWidget {
  const EditProfileNameBlock({
    super.key,
    required this.firstController,
    required this.secondController,
    required this.firstHint,
    required this.secondHint,
  });

  final TextEditingController firstController;
  final TextEditingController secondController;
  final String firstHint;
  final String secondHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.7,
        ),
        // boxShadow: [
        //   BoxShadow(
        //     color: Theme.of(context).brightness == Brightness.dark
        //         ? AppColors.darkShadowSoft
        //         : AppColors.shadowSoft,
        //     offset: const Offset(0, 1),
        //     blurRadius: 1,
        //     spreadRadius: 0,
        //   ),
        // ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 46,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BareTextField(
                  controller: firstController,
                  hint: firstHint,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
            indent: 10,
            endIndent: 10,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 46,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BareTextField(
                  controller: secondController,
                  hint: secondHint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────────── Простое текстовое поле ─────────────────────────────

/// Текстовое поле без декорации (используется внутри других виджетов)
class _BareTextField extends StatelessWidget {
  const _BareTextField({required this.controller, this.hint});

  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: AppTextStyles.h14w4Place,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

/// ───────────────────────────── Круглая кнопка с иконкой ─────────────────────────────

/// Круглая кнопка с иконкой (например, для QR-кода)
class EditProfileCircleIconBtn extends StatelessWidget {
  const EditProfileCircleIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44.0,
    this.iconSize = 24.0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}
