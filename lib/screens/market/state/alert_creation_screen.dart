// lib/screens/market/state/alert_creation_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Создание оповещения» для уведомлений о новых слотах
// Форма создания в стиле sale_slots_content.dart
// Карточки текущих оповещений в стиле market_slot_card.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/market_models.dart' show Gender;
import '../../../widgets/app_bar.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../widgets/pills.dart';

/// Модель оповещения о слоте
class AlertItem {
  final String id;
  final String eventName;
  final Gender gender;
  final String distance;
  final String imageUrl;

  const AlertItem({
    required this.id,
    required this.eventName,
    required this.gender,
    required this.distance,
    required this.imageUrl,
  });
}

/// Экран создания оповещений
class AlertCreationScreen extends StatefulWidget {
  const AlertCreationScreen({super.key});

  @override
  State<AlertCreationScreen> createState() => _AlertCreationScreenState();
}

class _AlertCreationScreenState extends State<AlertCreationScreen> {
  final nameCtrl = TextEditingController();

  Gender _gender = Gender.male;
  int _distanceIndex = 0;
  final List<String> _distances = const ['5 км', '10 км', '21,1 км', '42,2 км'];

  // Демо-данные текущих оповещений
  final List<AlertItem> _alerts = [
    const AlertItem(
      id: '1',
      eventName: 'СберПрайм Казанский марафон 2025',
      gender: Gender.male,
      distance: '42,2 км',
      imageUrl: 'assets/race_kazan.png',
    ),
    const AlertItem(
      id: '2',
      eventName: 'Московский полумарафон',
      gender: Gender.female,
      distance: '21,1 км',
      imageUrl: 'assets/race_moscow.png',
    ),
  ];

  bool get _isValid => nameCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  void _createAlert() {
    if (!_isValid) return;

    // Добавляем новое оповещение
    final newAlert = AlertItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventName: nameCtrl.text.trim(),
      gender: _gender,
      distance: _distances[_distanceIndex],
      imageUrl: 'assets/race_moscow.png', // Демо-изображение
    );

    setState(() {
      _alerts.insert(0, newAlert);
      nameCtrl.clear();
      _distanceIndex = 0;
      _gender = Gender.male;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Оповещение создано'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _deleteAlert(String id) {
    setState(() {
      _alerts.removeWhere((alert) => alert.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Создание оповещения',
          showBack: true,
          showBottomDivider: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Контейнер формы с фоном surface ───
              Container(
                decoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(context),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Информационное сообщение ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Text(
                          'Вам придёт оповещение, если кто-то разместит слот, '
                          'соответствующий указанным критериям',
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Форма создания оповещения ───
                      _LabeledTextField(
                        label: 'Название события',
                        hint: 'Официальное название события',
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
                        onFemaleTap: () =>
                            setState(() => _gender = Gender.female),
                      ),
                      const SizedBox(height: 20),

                      const _SmallLabel('Дистанция'),
                      const SizedBox(height: 8),
                      _ChipsRow(
                        items: _distances,
                        selectedIndex: _distanceIndex,
                        onSelected: (i) => setState(() => _distanceIndex = i),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: PrimaryButton(
                          text: 'Создать оповещение',
                          onPressed: _createAlert,
                          width: 220,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Раздел «Текущие оповещения» ───
              if (_alerts.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _SmallLabel('Текущие оповещения'),
                      ),
                      const SizedBox(height: 12),
                      ..._alerts.map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AlertCard(
                            alert: alert,
                            onDelete: () => _deleteAlert(alert.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ——— Локальные UI-компоненты ———

const TextStyle _fieldText = TextStyle(fontFamily: 'Inter', fontSize: 14);
// _hintText теперь создается динамически с учетом темы
TextStyle _hintText(BuildContext context) => TextStyle(
  fontFamily: 'Inter',
  fontSize: 14,
  color: AppColors.getTextPlaceholderColor(context),
);

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.getTextPrimaryColor(context),
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
  final ValueChanged<String>? onChanged;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
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
          onChanged: onChanged,
          style: _fieldText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _hintText(context),
            filled: true,
            fillColor: AppColors.getSurfaceColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.getBorderColor(context)),
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
    // Используем ту же логику, что и в PrimaryButton
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

/// Карточка оповещения в стиле market_slot_card.dart
class _AlertCard extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback onDelete;

  const _AlertCard({required this.alert, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Миниатюра слева
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              color: AppColors.getBackgroundColor(context),
              image: DecorationImage(
                image: AssetImage(alert.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          const SizedBox(width: 8),

          // Текстовая часть
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  alert.eventName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DistancePill(text: alert.distance),
                    const SizedBox(width: 6),
                    alert.gender == Gender.male
                        ? const GenderPill.male()
                        : const GenderPill.female(),
                    const Spacer(),
                    // Кнопка удаления
                    _DeleteButton(onPressed: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка удаления в стиле _BuyButtonText из market_slot_card.dart
class _DeleteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: SizedBox(
        height: 28,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.getSurfaceMutedColor(context)
                : AppColors.redBg,
            foregroundColor: AppColors.red,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          child: const Text(
            'Удалить',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.red,
            ),
          ),
        ),
      ),
    );
  }
}
