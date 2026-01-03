// lib/widgets/goods_card.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/auth_service.dart';
import '../../../../models/market_models.dart';
import '../tradechat_things_screen.dart' show TradeChatThingsScreen;
import '../../../widgets/image_gallery.dart';
import '../../../widgets/pills.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../state/edit_thing/edit_thing_screen.dart';
import '../../../../providers/things_provider.dart';

/// Отдельный виджет карточки ТОВАРА.
class GoodsCard extends ConsumerStatefulWidget {
  final GoodsItem item;
  final bool expanded; // если есть описание — показываем/скрываем его
  final VoidCallback onToggle;

  const GoodsCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  @override
  ConsumerState<GoodsCard> createState() => _GoodsCardState();
}

class _GoodsCardState extends ConsumerState<GoodsCard> {
  int? _currentUserId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final auth = AuthService();
    final userId = await auth.getUserId();
    setState(() {
      _currentUserId = userId;
      _isLoadingUser = false;
    });
  }

  // Если описание пустое — не отображаем стрелку и не раскрываем
  bool get _hasDetails =>
      (widget.item.description != null &&
      widget.item.description!.trim().isNotEmpty);

  bool get _isSeller =>
      _currentUserId != null && _currentUserId == widget.item.sellerId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _hasDetails
          ? widget.onToggle
          : null, // клик по карточке — раскрыть описание
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
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
                      widget.item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  if (_hasDetails) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 150),
                      turns: widget.expanded ? 0.5 : 0.0,
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 18,
                        color: AppColors.getIconPrimaryColor(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Горизонтальная лента миниатюр — каждая кликабельна
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.item.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final img = widget.item.images[i];
                  final heroGroup =
                      widget.item; // общий «ключ» для Hero в рамках карточки
                  return GestureDetector(
                    onTap: () {
                      // Открываем полноэкранную галерею и начинаем с выбранной миниатюры
                      showImageGallery(
                        context,
                        images: widget.item.images,
                        initialIndex: i,
                        heroGroup: heroGroup,
                      );
                    },
                    child: Hero(
                      tag: Object.hash(heroGroup, i),
                      child: Container(
                        width: 80,
                        height: 80,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.getBorderColor(context),
                            width: 0.5,
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.getBackgroundColor(context),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 28,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.getBackgroundColor(context),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 28,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                            ),
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
                PricePill(text: _fmt(widget.item.price)),
                const SizedBox(width: 6),
                // ── если gender == null (выбрано "Любой"), показываем обе пилюли
                if (widget.item.gender == null) ...[
                  const GenderPill.male(),
                  const SizedBox(width: 6),
                  const GenderPill.female(),
                ] else if (widget.item.gender == Gender.female)
                  const GenderPill.female()
                else
                  const GenderPill.male(),
                // ── показываем пилюлю города только если город указан
                if (widget.item.city.isNotEmpty &&
                    widget.item.city != 'Не указано') ...[
                  const SizedBox(width: 6),
                  CityPill(text: widget.item.city),
                ],
              ],
            ),

            // Раскрывающийся блок: описание + кнопки
            if (_hasDetails)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceMutedColor(context),
                      border: Border.all(
                        color: AppColors.getBorderColor(context),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.description!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ──── Кнопки в зависимости от роли ────
                        if (_isLoadingUser)
                          const SizedBox(
                            height: 36,
                            child: Center(child: CupertinoActivityIndicator()),
                          )
                        else if (_isSeller)
                          // ──── Кнопка для продавца ────
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () async {
                                // Переход на экран редактирования
                                final result =
                                    await Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push(
                                      TransparentPageRoute(
                                        builder: (_) => EditThingScreen(
                                          thingId: widget.item.id,
                                        ),
                                      ),
                                    );
                                // ── обновляем список после редактирования
                                if (result == true && mounted) {
                                  ref
                                      .read(thingsProvider.notifier)
                                      .loadInitial();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: Colors.white,
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
                              child: const Text(
                                'Изменить',
                                style: TextStyle(fontFamily: 'Inter'),
                              ),
                            ),
                          )
                        else
                          // ──── Кнопка для покупателя ────
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Переход в чат с продавцом
                                Navigator.of(context, rootNavigator: true).push(
                                  TransparentPageRoute(
                                    builder: (_) => TradeChatThingsScreen(
                                      thingId: widget.item.id,
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
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
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
                crossFadeState: widget.expanded
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
