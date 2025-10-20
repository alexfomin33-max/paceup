import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../theme/app_theme.dart';
import '../../../../../../widgets/primary_button.dart'; // ← глобальная бренд-кнопка

/// Контент для сегмента «Кроссовки»
class AddingSneakersContent extends StatefulWidget {
  const AddingSneakersContent({super.key});

  @override
  State<AddingSneakersContent> createState() => _AddingSneakersContentState();
}

class _AddingSneakersContentState extends State<AddingSneakersContent> {
  // ─────────────────────────────────────────────────────────────────────
  //                             КОНТРОЛЛЕРЫ
  // ─────────────────────────────────────────────────────────────────────
  final _brandCtrl = TextEditingController(text: 'Nike');
  final _modelCtrl = TextEditingController(text: 'Air Zoom');
  final _kmCtrl = TextEditingController(text: '250');
  DateTime _inUseFrom = DateTime(2023, 7, 21);

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ВЫБОР ДАТЫ (iOS)
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) {
        return Container(
          height: 280,
          color: AppColors.surface,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отменить'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
                indent: 12,
                endIndent: 12,
              ),

              // Сам пикер
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _inUseFrom,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) => setState(() => _inUseFrom = d),
                ),
              ),
            ],
          ),
        );
      },
    );
    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ФОРМАТТЕРЫ
  // ─────────────────────────────────────────────────────────────────────
  String get _dateLabel {
    final d = _inUseFrom;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  // ─────────────────────────────────────────────────────────────────────
  //                                 UI
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ───────────────────────── Карточка ─────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              // превью
              SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/add_sneakers.png',
                        width: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // кнопка «добавить фото» — снизу-справа
                    Positioned(
                      right: 70,
                      bottom: 18,
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Добавить фото (заглушка)',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Заглушка: выбор фото не реализован',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 28,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
                indent: 12,
                endIndent: 12,
              ),

              // строки полей
              _FieldRow(
                title: 'Бренд',
                child: _RightTextField(
                  controller: _brandCtrl,
                  hint: 'Введите бренд',
                ),
              ),
              _FieldRow(
                title: 'Модель',
                child: _RightTextField(
                  controller: _modelCtrl,
                  hint: 'Введите модель',
                ),
              ),
              _FieldRow(
                title: 'В использовании с',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _dateLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textSecondary, // правые значения серым
                      ),
                    ),
                  ),
                ),
              ),
              _FieldRow(
                title: 'Добавленная дистанция, км',
                child: _RightTextField(
                  controller: _kmCtrl,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─────────────────── Кнопка «Сохранить» (унифицированная) ───────────────────
        Center(
          child: PrimaryButton(
            text: 'Сохранить',
            onPressed: () {},
            width: 220, // ← единая ширина, как у «Пригласить»
          ),
        ),
      ],
    );
  }
}

/// ───────────────────── Левая метка + правый виджет ─────────────────────
class _FieldRow extends StatelessWidget {
  final String title;
  final Widget child;
  const _FieldRow({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14, // 14 pt
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: child),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.divider,
          indent: 12,
          endIndent: 12,
        ),
      ],
    );
  }
}

/// ───────────────────── Правый «плоский» TextField без рамки ─────────────────────
class _RightTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _RightTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      decoration: const InputDecoration(
        isDense: true,
        hintText: '',
        border: InputBorder.none,
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14, // 14 pt
        color: AppColors.textSecondary, // правые значения серым
      ),
    );
  }
}
