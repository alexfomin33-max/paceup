import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../models/market_models.dart' show Gender;
import '../../../../widgets/primary_button.dart';

/// Контент вкладки «Продажа вещи»
class SaleThingsContent extends StatefulWidget {
  const SaleThingsContent({super.key});

  @override
  State<SaleThingsContent> createState() => _SaleThingsContentState();
}

class _SaleThingsContentState extends State<SaleThingsContent> {
  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final cityFromCtrl = TextEditingController();
  final cityToCtrl = TextEditingController();
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
  void dispose() {
    titleCtrl.dispose();
    priceCtrl.dispose();
    cityFromCtrl.dispose();
    cityToCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
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

          Row(
            children: [
              Expanded(
                child: _LabeledTextField(
                  label: 'Город передачи',
                  hint: 'Населенный пункт',
                  controller: cityFromCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledTextField(
                  label: 'Город передачи',
                  hint: 'Населенный пункт',
                  controller: cityToCtrl,
                ),
              ),
            ],
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

const TextStyle _fieldText = TextStyle(fontFamily: 'Inter', fontSize: 14);
const TextStyle _hintText = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  color: AppColors.textPlaceholder,
);

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      ),
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
        _SmallLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: _fieldText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _hintText,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.outline),
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
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          onChanged: onChanged,
          style: _fieldText,
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
          ),
          items: items.map((o) {
            return DropdownMenuItem<String>(
              value: o,
              child: Text(
                o,
                style: _fieldText.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
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
                style: _fieldText,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    borderSide: BorderSide(color: AppColors.outline),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '₽',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Inter',
                  color: AppColors.textPrimary,
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
    final bg = selected ? AppColors.brandPrimary : AppColors.surface;
    final fg = selected ? AppColors.surface : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.border,
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
