// lib/widgets/market_slot_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/market_models.dart';
import '../tradechat_slots_screen.dart';
import '../../../widgets/pills.dart';
import '../../../../../widgets/transparent_route.dart';

/// Отдельный виджет карточки СЛОТА.
/// Миниатюра НЕ кликабельна.
class MarketSlotCard extends StatelessWidget {
  final MarketItem item;
  final bool expanded; // сейчас используется только для «Алые Паруса» (пример)
  final VoidCallback onToggle; // коллбэк на тап по карточке (раскрыть/свернуть)

  const MarketSlotCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  // Условный признак: только для одной карточки показываем «детали» ниже
  bool get _hasDetails =>
      item.title.contains('Алые Паруса') || item.title.contains('Алые Паруса"');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // По нажатию на свободное место карточки — переключаем раскрытие
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: [
            const BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            // Верхняя строка: миниатюра + контент + кнопка
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Миниатюра слева — НЕ кликабельна
                _Thumb(imageAsset: item.imageUrl, heroGroup: item),
                const SizedBox(width: 8),

                // Текстовая часть и чипы
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      // Заголовок + стрелка (если есть детали)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.h14w5,
                            ),
                          ),
                          if (_hasDetails) ...[
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 150),
                              turns: expanded ? 0.5 : 0.0,
                              child: Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Одна строка: дистанция • пол • цена • кнопка справа
                      Row(
                        children: [
                          DistancePill(text: item.distance),
                          const SizedBox(width: 6),
                          if (item.gender == Gender.male)
                            const GenderPill.male()
                          else
                            const GenderPill.female(),
                          const SizedBox(width: 6),
                          PricePill(text: _formatPrice(item.price)),
                          const Spacer(),
                          _BuyButtonText(
                            text: item.buttonText,
                            enabled: item.buttonEnabled,
                            onPressed: () {
                              Navigator.of(context, rootNavigator: true).push(
                                TransparentPageRoute(
                                  builder: (_) => TradeChatSlotsScreen(
                                    itemTitle: item.title,
                                    itemThumb: item.imageUrl,
                                    distance: item.distance,
                                    gender: item.gender,
                                    price: item.price,
                                    statusText: item.locked
                                        ? 'Бронь'
                                        : 'Свободен',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Нижняя «раскрывашка» — пример для одной карточки
            if (_hasDetails)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceMutedColor(context),
                      border: Border.all(color: AppColors.getBorderColor(context)),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Имя: Илья. Время: 3:01 - 3:15. '
                      'Передача по доверенности в Москве, либо в СПб на экспо.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13),
                    ),
                  ),
                ),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
          ],
        ),
      ),
    );
  }

  /// Форматирует цену в вид «12 345 ₽»
  String _formatPrice(int price) {
    final s = price.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      b.write(s[i]);
      if (pos > 1 && pos % 3 == 1) b.write(' ');
    }
    return '${b.toString()} ₽';
  }
}

/// НЕ кликабельная миниатюра слота.
/// Оставил Hero для красивого появления/скролла, но без переходов.
class _Thumb extends StatelessWidget {
  final String imageAsset;
  final Object? heroGroup;

  const _Thumb({required this.imageAsset, this.heroGroup});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: Object.hash(heroGroup ?? imageAsset, 0),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          color: AppColors.getBackgroundColor(context),
          image: DecorationImage(
            image: AssetImage(imageAsset),
            fit: BoxFit.cover,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}

class _BuyButtonText extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback? onPressed; // 🔹 новый параметр

  const _BuyButtonText({
    required this.text,
    required this.enabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = enabled
        ? AppColors.brandPrimary
        : AppColors.disabledBg; // disabledBg обычно не меняется
    final fg = enabled
        ? AppColors.getSurfaceColor(context)
        : AppColors.disabledText; // disabledText обычно не меняется
    final icon = text == 'Бронь' ? CupertinoIcons.lock : CupertinoIcons.cart;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: SizedBox(
        height: 28,
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null, // 🔹 используем коллбэк
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          icon: Icon(icon, size: 14),
          label: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
