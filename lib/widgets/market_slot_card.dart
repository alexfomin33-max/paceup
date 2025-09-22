// lib/widgets/market_slot_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/market_models.dart';
import 'image_gallery.dart';
import 'pills.dart';

/// Отдельный виджет карточки СЛОТА.
/// При клике по миниатюре откроется полноэкранная галерея (одна картинка).
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
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
                // Миниатюра слева — кликабельна, откроет галерею
                _Thumb(imageAsset: item.imageUrl, heroGroup: item),
                const SizedBox(width: 10),

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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (_hasDetails) ...[
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 150),
                              turns: expanded ? 0.5 : 0.0,
                              child: Icon(
                                CupertinoIcons.chevron_down,
                                size: 18,
                                color: AppColors.text.withValues(alpha: 0.6),
                              ),
                            ),
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
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Имя: Илья. Время: 3:01 - 3:15. '
                      'Передача по доверенности в Москве, либо в СПб на экспо.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.black,
                      ),
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

/// Кликабельная миниатюра слота.
/// По нажатию откроет [showImageGallery] с одной картинкой.
class _Thumb extends StatelessWidget {
  final String imageAsset;
  final Object? heroGroup;

  const _Thumb({required this.imageAsset, this.heroGroup});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showImageGallery(
          context,
          images: [imageAsset],
          initialIndex: 0,
          heroGroup: heroGroup ?? imageAsset,
        );
      },
      child: Hero(
        tag: Object.hash(heroGroup ?? imageAsset, 0),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            image: DecorationImage(
              image: AssetImage(imageAsset),
              fit: BoxFit.cover,
            ),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      ),
    );
  }
}

/// Кнопка «Купить» / «Бронь» справа от чипов.
class _BuyButtonText extends StatelessWidget {
  final String text;
  final bool enabled;

  const _BuyButtonText({required this.text, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? AppColors.secondary : Colors.grey.shade300;
    final fg = enabled ? Colors.white : Colors.grey.shade700;
    final icon = text == 'Бронь' ? CupertinoIcons.lock : CupertinoIcons.cart;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: SizedBox(
        height: 30,
        child: ElevatedButton.icon(
          onPressed: enabled ? () {} : null, // если disabled — null
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: Icon(icon, size: 14),
          label: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
