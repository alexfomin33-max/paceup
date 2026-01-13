// lib/widgets/market_slot_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../models/market_models.dart';
import '../tradechat_slots_screen.dart';
import '../../../../../../core/services/auth_service.dart';
import '../../../widgets/pills.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../state/edit_slot/edit_slot_screen.dart';
import '../../../../../map/screens/events/official_event_detail_screen.dart';

/// Отдельный виджет карточки СЛОТА.
/// Миниатюра кликабельна: при наличии eventId открывает страницу события.
class MarketSlotCard extends StatelessWidget {
  final MarketItem item;
  final bool expanded; // сейчас используется только для «Алые Паруса» (пример)
  final VoidCallback onToggle; // коллбэк на тап по карточке (раскрыть/свернуть)
  final VoidCallback?
  onChatClosed; // коллбэк после закрытия экрана чата (для обновления списка)

  const MarketSlotCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
    this.onChatClosed,
  });

  // Показываем детали, если есть описание
  bool get _hasDetails =>
      item.description != null && item.description!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // По нажатию на свободное место карточки — переключаем раскрытие
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            // Верхняя строка: миниатюра + контент + кнопка
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Миниатюра слева — кликабельна (открывает страницу события)
                _Thumb(
                  imageUrl: item.imageUrl,
                  heroGroup: item,
                  eventId: item.eventId,
                ),
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
                              style: AppTextStyles.h14w5.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
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
                            onPressed: () async {
                              // Проверяем, является ли пользователь продавцом
                              final authService = AuthService();
                              final currentUserId = await authService
                                  .getUserId();
                              final isSeller =
                                  currentUserId != null &&
                                  currentUserId == item.sellerId;

                              if (!context.mounted) return;

                              if (isSeller && item.buttonText == 'Изменить') {
                                // Открываем экран редактирования для продавца
                                await Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).push(
                                  TransparentPageRoute(
                                    builder: (_) =>
                                        EditSlotScreen(slotId: item.id),
                                  ),
                                );
                              } else {
                                // Открываем экран чата для покупателя
                                // Если chatId существует, передаем его для прямого открытия чата
                                await Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).push(
                                  TransparentPageRoute(
                                    builder: (_) => TradeChatSlotsScreen(
                                      slotId: item.id,
                                      chatId: item.chatId,
                                    ),
                                  ),
                                );
                              }
                              // После возврата обновляем список слотов
                              // Это нужно, чтобы обновить статусы слотов (например, если слот был куплен)
                              if (onChatClosed != null) {
                                onChatClosed!();
                              }
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
                      border: Border.all(
                        color: AppColors.getBorderColor(context),
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      item.description!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.getTextPrimaryColor(context),
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
/// При клике открывает страницу события, если eventId указан.
/// Оставил Hero для красивого появления/скролла, но без переходов.
/// Поддерживает как AssetImage (для локальных ресурсов), так и NetworkImage (для URL из API).
class _Thumb extends StatelessWidget {
  final String imageUrl;
  final Object? heroGroup;
  final int? eventId; // ID события для открытия детальной страницы

  const _Thumb({required this.imageUrl, this.heroGroup, this.eventId});

  /// Определяет, является ли URL локальным ресурсом (assets) или сетевым URL
  bool get _isAsset => imageUrl.startsWith('assets/');

  /// Проверяет, является ли URL валидным HTTP/HTTPS URL
  bool get _isValidNetworkUrl {
    if (imageUrl.isEmpty) return false;
    if (_isAsset) return false;
    return imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final thumbContent = Hero(
      tag: Object.hash(heroGroup ?? imageUrl, 0),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          color: AppColors.getBackgroundColor(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl.isEmpty
            ? Container(
                color: AppColors.getBackgroundColor(context),
                child: Icon(
                  CupertinoIcons.photo,
                  size: 24,
                  color: AppColors.getIconSecondaryColor(context),
                ),
              )
            : _isAsset
            ? Image(
                image: AssetImage(imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ Ошибка загрузки asset: $imageUrl - $error');
                  return Container(
                    color: AppColors.getBackgroundColor(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  );
                },
              )
            : _isValidNetworkUrl
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.getBackgroundColor(context),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      radius: 10,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  debugPrint(
                    '❌ Ошибка загрузки изображения: $imageUrl - $error',
                  );
                  return Container(
                    color: AppColors.getBackgroundColor(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  );
                },
              )
            : Container(
                color: AppColors.getBackgroundColor(context),
                child: Icon(
                  CupertinoIcons.photo,
                  size: 24,
                  color: AppColors.getIconSecondaryColor(context),
                ),
              ),
      ),
    );

    // Если есть eventId, делаем миниатюру кликабельной
    if (eventId != null) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            TransparentPageRoute(
              builder: (_) => OfficialEventDetailScreen(eventId: eventId!),
            ),
          );
        },
        child: thumbContent,
      );
    }

    // Если eventId нет, возвращаем обычную миниатюру
    return thumbContent;
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
    // ── Определяем цвет фона: оранжевый для "В чат", приглушенный зеленый для "Купить", синий для остальных
    final bg = enabled
        ? (text == 'В чат'
              ? AppColors.orange
              : (text == 'Купить' ? AppColors.green : AppColors.brandPrimary))
        : AppColors.disabledBg; // disabledBg обычно не меняется
    // ── Для disabled кнопки в светлой теме используем более темный цвет текста
    final isLight = Theme.of(context).brightness == Brightness.light;
    final fg = enabled
        ? Colors
              .white // белый цвет для иконки и текста на синем/оранжевом фоне
        : (isLight
              ? AppColors
                    .textSecondary // более темный цвет для светлой темы
              : AppColors.disabledText); // в темной теме оставляем как было
    // ── Определяем иконку: пузырь сообщения для "В чат", корзина для остальных
    // Для "Изменить" и "Купить" иконка не отображается
    final icon = text == 'В чат'
        ? CupertinoIcons.chat_bubble
        : CupertinoIcons.cart;
    final showIcon = text != 'Изменить' && text != 'Купить';

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: Size.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );

    final textWidget = Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: fg, // уже адаптивный через fg
      ),
    );

    final button = showIcon
        ? ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            style: buttonStyle,
            icon: Icon(icon, size: 14, color: fg),
            label: textWidget,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: buttonStyle,
            child: textWidget,
          );

    // Кнопка "Купить" имеет фиксированную ширину 70 пикселей
    // Остальные кнопки имеют ширину по содержимому
    return SizedBox(
      height: 28,
      width: text == 'Купить' ? 70 : null,
      child: button,
    );
  }
}
