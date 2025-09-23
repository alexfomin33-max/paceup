import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/market_models.dart' show Gender;

/// Единый экран продажи: сверху переключатель, в теле — нужная форма.
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  /// 0 — Продажа слота, 1 — Продажа вещи
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F9),
        elevation: 0,
        leadingWidth: 36, // ширина зоны leading
        leading: Padding(
          padding: const EdgeInsets.only(
            left: 6,
          ), // 🔹 отступ 10 пикселей от края
          child: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        centerTitle: true,
        title: null, // title убираем
        flexibleSpace: SafeArea(
          child: Center(
            child: _TopTabsSwitch(
              left: 'Продажа слота',
              right: 'Продажа вещи',
              value: _tab,
              onTapLeft: () => setState(() => _tab = 0),
              onTapRight: () => setState(() => _tab = 1),
            ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),

      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _tab == 0 ? const _SlotForm() : const _GoodForm(),
        ),
      ),
    );
  }
}

/// ─────────────────────── ФОРМА: Продажа слота ───────────────────────
class _SlotForm extends StatefulWidget {
  const _SlotForm();

  @override
  State<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends State<_SlotForm> {
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
      key: const ValueKey('slot_form'),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
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
          const SizedBox(height: 28),

          _PrimaryButton(
            text: 'Разместить продажу',
            enabled: _isValid,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────── ФОРМА: Продажа вещи ───────────────────────
class _GoodForm extends StatefulWidget {
  const _GoodForm();

  @override
  State<_GoodForm> createState() => _GoodFormState();
}

class _GoodFormState extends State<_GoodForm> {
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
    return SingleChildScrollView(
      key: const ValueKey('good_form'),
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
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
          const SizedBox(height: 28),

          _PrimaryButton(
            text: 'Разместить продажу',
            enabled: _isValid,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────── Общие UI-компоненты ───────────────────────

const TextStyle _fieldText = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
); // 4) помельче + Inter
const TextStyle _hintText = TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  color: AppColors.greytext,
);

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF565D6D),
        fontSize: 16,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      ),
    );
  }
}

class _TopTabsSwitch extends StatelessWidget {
  final String left;
  final String right;

  /// 0 или 1
  final int value;
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;
  const _TopTabsSwitch({
    required this.left,
    required this.right,
    required this.value,
    this.onTapLeft,
    this.onTapRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(value == 0, left, onTapLeft),
          _seg(value == 1, right, onTapRight),
        ],
      ),
    );
  }

  // 3) увеличил высоту переключателей (vertical: 12 было 8)
  Widget _seg(bool selected, String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
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

class _GenderAnyRow extends StatelessWidget {
  final Gender? value; // null = Любой
  final ValueChanged<Gender?> onChanged; // может отдавать null
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
              color: sel ? AppColors.secondary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? AppColors.secondary : AppColors.border,
              ),
            ),
            child: Text(
              items[i],
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: sel ? Colors.white : AppColors.text,
              ),
            ),
          ),
        );
      }),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: _fieldText, // 4) меньший размер + Inter
      decoration: InputDecoration(
        label: _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: _hintText, // 4) меньший размер + Inter
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
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
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      onChanged: onChanged,
      style: _fieldText, // 4) текст выбранного значения
      decoration: InputDecoration(
        label: _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: items
          .map(
            (o) => DropdownMenuItem<String>(
              value: o,
              child: Text(
                o,
                style: _fieldText,
              ), // 4) пункты списка — тоже Inter 13
            ),
          )
          .toList(),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _PriceField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120, // 🔹 фиксированная ширина поля (можно подогнать)
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            style: _fieldText,
            decoration: const InputDecoration(
              label: _LabelWithStarText('Цена'),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppRadius.small),
                ),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppRadius.small),
                ),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppRadius.small),
                ),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5FF),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Text(
              '₽',
              style: TextStyle(fontSize: 16, fontFamily: 'Inter'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.text,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center, // кнопка по центру
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.primary : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xlarge),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 40, // 🔹 горизонтальный паддинг
            vertical: 14,
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

// ——— Метка-лейбл со звёздочкой (чтобы можно было использовать в const-контексте выше)
class _LabelWithStarText extends StatelessWidget {
  final String text;
  const _LabelWithStarText(this.text);

  @override
  Widget build(BuildContext context) => _labelWithStar(text);
}

Widget _labelWithStar(String label) {
  return RichText(
    text: TextSpan(
      text: label.replaceAll('*', ''),
      style: const TextStyle(
        color: Color(0xFF565D6D),
        fontSize: 15, // слегка меньше
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter', // 4) Inter
      ),
      children: [
        if (label.contains('*'))
          const TextSpan(
            text: '*',
            style: TextStyle(
              color: Colors.red,
              fontSize: 15,
              fontFamily: 'Inter',
            ),
          ),
      ],
    ),
  );
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
    final bg = selected ? AppColors.secondary : Colors.white;
    final fg = selected ? Colors.white : AppColors.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: null,
          ).copyWith(color: fg),
        ),
      ),
    );
  }
}
