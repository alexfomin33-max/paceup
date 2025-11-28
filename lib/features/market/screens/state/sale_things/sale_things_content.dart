import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../models/market_models.dart' show Gender;
import '../../../../../core/widgets/primary_button.dart';

/// Контент вкладки «Продажа вещи»
class SaleThingsContent extends StatefulWidget {
  const SaleThingsContent({super.key});

  @override
  State<SaleThingsContent> createState() => _SaleThingsContentState();
}

class _SaleThingsContentState extends State<SaleThingsContent> {
  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  // ── контроллеры для полей ввода городов передачи
  final List<TextEditingController> _cityControllers = [];
  final descCtrl = TextEditingController();

  final List<String> _categories = const [
    'Кроссовки',
    'Часы',
    'Одежда',
    'Аксессуары',
  ];
  String _category = 'Кроссовки';

  /// null = Любой
  Gender? _gender;

  bool get _isValid =>
      titleCtrl.text.trim().isNotEmpty && priceCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // ── создаём первое поле для ввода города передачи
    _cityControllers.add(TextEditingController());
    _cityControllers.last.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    priceCtrl.dispose();
    // ── освобождаем все контроллеры городов
    for (final controller in _cityControllers) {
      controller.dispose();
    }
    descCtrl.dispose();
    super.dispose();
  }

  // ── добавление нового поля для ввода города передачи
  void _addCityField() {
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() => setState(() {}));
      _cityControllers.add(newController);
    });
  }

  void _submit() {
    if (!_isValid) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Объявление о продаже вещи размещено (демо)'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 🔻 умный нижний паддинг: клавиатура (viewInsets) > 0 ? берём её : берём safe-area
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom; // клавиатура
    final safeBottom = media.viewPadding.bottom; // «борода»/ноутч
    final bottomPad = (bottomInset > 0 ? bottomInset : safeBottom) + 20;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledTextField(
            label: 'Название вещи',
            hint: 'Наименование продаваемого товара',
            controller: titleCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          _DropdownField(
            label: 'Категория',
            value: _category,
            items: _categories,
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 20),

          const _SmallLabel('Пол'),
          const SizedBox(height: 8),
          _GenderAnyRow(
            value: _gender,
            onChanged: (g) =>
                setState(() => _gender = g), // g может быть null (= Любой)
          ),
          const SizedBox(height: 20),

          _PriceField(controller: priceCtrl, onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),

          // ── динамические поля для ввода городов передачи (в два столбца)
          const _SmallLabel('Город передачи'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_cityControllers.length, (index) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 24 - 12) / 2,
                child: TextFormField(
                  controller: _cityControllers[index],
                  onChanged: (_) => setState(() {}),
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Населенный пункт',
                    hintStyle: AppTextStyles.h14w4Place.copyWith(
                      color: AppColors.getTextPlaceholderColor(context),
                    ),
                    filled: true,
                    fillColor: AppColors.getSurfaceColor(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // ── кнопка "добавить ещё"
          GestureDetector(
            onTap: _addCityField,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.add_circled,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  'добавить ещё',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _LabeledTextField(
            label: 'Описание',
            hint: 'Размер, отправка, передача и другая полезная информация',
            controller: descCtrl,
            maxLines: 5,
          ),
          const SizedBox(height: 24),

          Center(
            child: PrimaryButton(
              text: 'Разместить продажу',
              onPressed: _submit,
              width: 220,
            ),
          ),
        ],
      ),
    );
  }
}

/// ——— Локальные UI-компоненты ———

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _SmallLabel(label),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.h14w4Place.copyWith(
              color: AppColors.getTextPlaceholderColor(context),
            ),
            filled: true,
            fillColor: AppColors.getSurfaceColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.getSurfaceColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              onChanged: onChanged,
              dropdownColor: AppColors.getSurfaceColor(context),
              menuMaxHeight: 300,
              borderRadius: BorderRadius.circular(AppRadius.md),
              icon: Icon(
                Icons.arrow_drop_down,
                color: AppColors.getIconSecondaryColor(context),
              ),
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
              items: items.map((o) {
                return DropdownMenuItem<String>(
                  value: o,
                  child: Text(o, style: AppTextStyles.h14w4),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _PriceField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel('Цена'),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                onChanged: onChanged,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: AppTextStyles.h14w4Place.copyWith(
                    color: AppColors.getTextPlaceholderColor(context),
                  ),
                  filled: true,
                  fillColor: AppColors.getSurfaceColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 17,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(
                      color: AppColors.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(
                      color: AppColors.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(
                      color: AppColors.getBorderColor(context),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '₽',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Inter',
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderAnyRow extends StatelessWidget {
  final Gender? value; // null = Любой
  final ValueChanged<Gender?> onChanged;
  const _GenderAnyRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OvalToggle(
          label: 'Любой',
          selected: value == null,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Мужской',
          selected: value == Gender.male,
          onTap: () => onChanged(Gender.male),
        ),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Женский',
          selected: value == Gender.female,
          onTap: () => onChanged(Gender.female),
        ),
      ],
    );
  }
}

class _OvalToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OvalToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    // Используем ту же логику, что и в alert_creation_screen.dart
    final fg = selected
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.surface
              : AppColors.getSurfaceColor(context))
        : AppColors.getTextPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected
                ? AppColors.brandPrimary
                : AppColors.getBorderColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}
