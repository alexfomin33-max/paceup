// lib/widgets/goods_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../models/market_models.dart';
import '../tradechat_things_screen.dart';
import '../../../widgets/image_gallery.dart';
import '../../../widgets/pills.dart';
import '../../../../../widgets/transparent_route.dart';

/// Отдельный виджет карточки ТОВАРА.
class GoodsCard extends StatelessWidget {
  final GoodsItem item;
  final bool expanded; // если есть описание — показываем/скрываем его
  final VoidCallback onToggle;

  const GoodsCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  // Если описание пустое — не отображаем стрелку и не раскрываем
  bool get _hasDetails =>
      (item.description != null && item.description!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hasDetails
          ? onToggle
          : null, // клик по карточке — раскрыть описание
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + стрелка (если есть описание)
            Padding(
              padding: const EdgeInsets.only(left: 2, top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
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
                        color: AppColors.iconPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Горизонтальная лента миниатюр — каждая кликабельна
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final img = item.images[i];
                  final heroGroup =
                      item; // общий «ключ» для Hero в рамках карточки
                  return GestureDetector(
                    onTap: () {
                      // Открываем полноэкранную галерею и начинаем с выбранной миниатюры
                      showImageGallery(
                        context,
                        images: item.images,
                        initialIndex: i,
                        heroGroup: heroGroup,
                      );
                    },
                    child: Hero(
                      tag: Object.hash(heroGroup, i),
                      child: Container(
                        width: 64,
                        height: 64,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          color: AppColors.background,
                          border: Border.all(color: AppColors.border),
                          image: DecorationImage(
                            image: AssetImage(img),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Чипы: цена • пол • город
            Row(
              children: [
                PricePill(text: _fmt(item.price)),
                const SizedBox(width: 6),
                if (item.gender == Gender.female)
                  const GenderPill.female()
                else
                  const GenderPill.male(),
                const SizedBox(width: 6),
                CityPill(text: item.city),
              ],
            ),

            // Раскрывающийся блок: описание + кнопка «Написать продавцу»
            if (_hasDetails)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,

                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Переход в чат с продавцом (экран уже у вас есть)
                              Navigator.of(context, rootNavigator: true).push(
                                TransparentPageRoute(
                                  builder: (_) => TradeChatScreen(
                                    itemTitle: item.title,
                                    itemThumb: item.images.isNotEmpty
                                        ? item.images.first
                                        : null,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              CupertinoIcons.paperplane,
                              size: 16,
                            ),
                            label: const Text(
                              'Написать продавцу',
                              style: TextStyle(fontFamily: 'Inter'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brandPrimary,
                              foregroundColor: AppColors.surface,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  /// Превращаем 10500 → «10 500 ₽»
  String _fmt(int p) {
    final s = p.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      b.write(s[i]);
      if (pos > 1 && pos % 3 == 1) b.write(' ');
    }
    return '${b.toString()} ₽';
  }
}
