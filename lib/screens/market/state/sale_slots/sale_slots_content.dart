import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/market_models.dart' show Gender;
import '../../../../core/widgets/primary_button.dart';

/// Контент вкладки «Продажа слота»
class SaleSlotsContent extends StatefulWidget {
  const SaleSlotsContent({super.key});

  @override
  State<SaleSlotsContent> createState() => _SaleSlotsContentState();
}

class _SaleSlotsContentState extends State<SaleSlotsContent> {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  Gender _gender = Gender.male;
  int _distanceIndex = 0;
  final List<String> _distances = const [
    '5 км',
    '10,5 км',
    '21,1 км',
    '42,2 км',
  ];

  bool get _isValid =>
      nameCtrl.text.trim().isNotEmpty && priceCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isValid) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Объявление о продаже слота размещено (демо)'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LabeledTextField(
            label: 'Название события',
            hint: 'Название спортивного события',
            controller: nameCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          const _SmallLabel('Пол'),
          const SizedBox(height: 8),
          _GenderRow(
            maleSelected: _gender == Gender.male,
            femaleSelected: _gender == Gender.female,
            onMaleTap: () => setState(() => _gender = Gender.male),
            onFemaleTap: () => setState(() => _gender = Gender.female),
          ),
          const SizedBox(height: 20),

          const _SmallLabel('Дистанция'),
          const SizedBox(height: 8),
          _ChipsRow(
            items: _distances,
            selectedIndex: _distanceIndex,
            onSelected: (i) => setState(() => _distanceIndex = i),
          ),
          const SizedBox(height: 20),

          _PriceField(controller: priceCtrl, onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),

          _LabeledTextField(
            label: 'Описание',
            hint:
                'Опишите варианты передачи слота, кластер и другую информацию',
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
        _SmallLabel(label),
        const SizedBox(height: 8),
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

class _GenderRow extends StatelessWidget {
  final bool maleSelected;
  final bool femaleSelected;
  final VoidCallback onMaleTap;
  final VoidCallback onFemaleTap;

  const _GenderRow({
    required this.maleSelected,
    required this.femaleSelected,
    required this.onMaleTap,
    required this.onFemaleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OvalToggle(label: 'Мужской', selected: maleSelected, onTap: onMaleTap),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Женский',
          selected: femaleSelected,
          onTap: onFemaleTap,
        ),
      ],
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _ChipsRow({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(items.length, (i) {
        final sel = selectedIndex == i;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.brandPrimary
                  : AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: sel
                    ? AppColors.brandPrimary
                    : AppColors.getBorderColor(context),
              ),
            ),
            child: Text(
              items[i],
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: sel
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surface
                          : AppColors.getSurfaceColor(context))
                    : AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
        );
      }),
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
