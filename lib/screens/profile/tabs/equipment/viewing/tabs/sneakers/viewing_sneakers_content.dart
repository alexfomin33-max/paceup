import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../theme/app_theme.dart';
import '../../../../../../../widgets/more_menu_overlay.dart';

class ViewingSneakersContent extends StatelessWidget {
  const ViewingSneakersContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        GearViewCard.shoes(
          brand: 'Asics',
          model: 'Jolt 3 Wide',
          asset: 'assets/view_asics.png',
          km: 582,
          workouts: 46,
          hours: 48,
          pace: '4:18 /км',
          since: 'В использовании с 21 июля 2023 г.',
          mainBadgeText: 'Основные',
        ),
        SizedBox(height: 12),
        GearViewCard.shoes(
          brand: 'Anta',
          model: 'M C202',
          asset: 'assets/view_anta.png',
          km: 1204,
          workouts: 68,
          hours: 102,
          pace: '3:42 /км',
          since: 'В использовании с 18 августа 2022 г.',
        ),
      ],
    );
  }
}

/// Публичная карточка для «Просмотра снаряжения»
class GearViewCard extends StatefulWidget {
  final String brand;
  final String model;
  final String asset;
  final int km;
  final int workouts;
  final int hours;
  final String thirdValue; // pace/speed
  final String thirdLabel;
  final String since;
  final String? mainBadgeText;

  const GearViewCard.shoes({
    super.key,
    required this.brand,
    required this.model,
    required this.asset,
    required this.km,
    required this.workouts,
    required this.hours,
    required String pace,
    required this.since,
    this.mainBadgeText,
  }) : thirdValue = pace,
       thirdLabel = 'Средний темп';

  const GearViewCard.bike({
    super.key,
    required this.brand,
    required this.model,
    required this.asset,
    required this.km,
    required this.workouts,
    required this.hours,
    required String speed,
    required this.since,
    this.mainBadgeText,
  }) : thirdValue = speed,
       thirdLabel = 'Скорость';

  @override
  State<GearViewCard> createState() => _GearViewCardState();
}

class _GearViewCardState extends State<GearViewCard> {
  /// Ключ для привязки всплывающего меню к кнопке "три точки"
  final GlobalKey _menuKey = GlobalKey();

  /// Показать всплывающее меню с действиями для карточки снаряжения
  void _showMenu(BuildContext context) {
    final items = <MoreMenuItem>[
      MoreMenuItem(
        text: 'Сделать основными',
        icon: CupertinoIcons.star_fill,
        onTap: () {
          // TODO: Реализовать логику установки как основных
        },
      ),
      MoreMenuItem(
        text: 'Редактировать',
        icon: CupertinoIcons.pencil,
        onTap: () {
          // TODO: Реализовать логику редактирования
        },
      ),
      MoreMenuItem(
        text: 'Удалить',
        icon: CupertinoIcons.minus_circle,
        iconColor: AppColors.error,
        textStyle: const TextStyle(color: AppColors.error),
        onTap: () {
          // TODO: Реализовать логику удаления
        },
      ),
    ];

    MoreMenuOverlay(
      anchorKey: _menuKey,
      items: items,
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок (иконка в одной строке с названием)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.brand} ',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: widget.model,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: _menuKey,
                  onPressed: () => _showMenu(context),
                  tooltip: 'Меню',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    CupertinoIcons.ellipsis, // горизонтальная иконка
                    size: 18,
                    color: AppColors.iconPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Чип «Основные/Основной» сразу под названием
          if (widget.mainBadgeText != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.xl), // пилюля
                ),
                child: Text(
                  widget.mainBadgeText!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ── Изображение
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AspectRatio(
              aspectRatio: 16 / 7.8,
              child: Image.asset(widget.asset, fit: BoxFit.contain),
            ),
          ),

          // ── Пробег
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    const TextSpan(text: 'Пробег '),
                    TextSpan(
                      text: '${widget.km}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(text: ' км'),
                  ],
                ),
              ),
            ),
          ),

          // ── Разделитель между пробегом и метриками
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.divider,
            indent: 12,
            endIndent: 12,
          ),

          // ── Метрики (левое выравнивание чисел)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _metric('Тренировок', '${widget.workouts}'),
                _metric('Время', '${widget.hours} ч'),
                _metric(widget.thirdLabel, widget.thirdValue),
              ],
            ),
          ),

          // ── Дата
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Text(
              widget.since,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ← левое выравнивание
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.left, // ← на всякий случай
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
