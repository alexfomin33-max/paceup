import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/market_models.dart' show Gender;
import 'sale_slot_screen.dart';

class SaleGoodScreen extends StatefulWidget {
  const SaleGoodScreen({super.key});

  @override
  State<SaleGoodScreen> createState() => _SaleGoodScreenState();
}

class _SaleGoodScreenState extends State<SaleGoodScreen> {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Продажа', style: AppTextStyles.h1),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopTabsSwitch(
                left: 'Продажа слота',
                right: 'Продажа вещи',
                value: 1,
                onTapLeft: () {
                  Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute(builder: (_) => const SaleSlotScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

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

              _PriceField(
                controller: priceCtrl,
                onChanged: (_) => setState(() {}),
              ),
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
        ),
      ),
    );
  }
}

/// ===== UI блоки =====

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
      ),
    );
  }
}

class _TopTabsSwitch extends StatelessWidget {
  final String left;
  final String right;
  final int value; // 0 или 1
  final VoidCallback? onTapLeft;
  final VoidCallback? onTapRight;
  const _TopTabsSwitch({
    required this.left,
    required this.right,
    required this.value,
    this.onTapLeft,
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

  Widget _seg(bool selected, String text, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
      style: const TextStyle(color: Colors.black, fontFamily: 'Inter'),
      decoration: InputDecoration(
        label: _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.greytext,
          fontFamily: 'Inter',
        ),
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
              child: Text(o, style: const TextStyle(fontFamily: 'Inter')),
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
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.black, fontFamily: 'Inter'),
            decoration: InputDecoration(
              label: _labelWithStar('Цена'),
              floatingLabelBehavior: FloatingLabelBehavior.always,
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
          child: const Center(child: Text('₽', style: TextStyle(fontSize: 16))),
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
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? AppColors.primary : Colors.grey.shade400,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

Widget _labelWithStar(String label) {
  return RichText(
    text: TextSpan(
      text: label.replaceAll('*', ''),
      style: const TextStyle(
        color: Color(0xFF565D6D),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      children: [
        if (label.contains('*'))
          const TextSpan(
            text: '*',
            style: TextStyle(color: Colors.red, fontSize: 16),
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
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }
}
