import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/transparent_route.dart';
import 'event_detail_screen2.dart';
import 'official_event_detail_screen.dart';

/// Каркас bottom sheet для вкладки «События».
class EventsBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const EventsBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top; // Высота верхней брови (notch)
    final bottomPadding =
        mediaQuery.padding.bottom; // Высота нижней безопасной зоны
    // Максимальная высота: от низа экрана до верхней брови
    // Вычитаем небольшой отступ снизу для визуального комфорта
    final maxH =
        screenHeight - topPadding - (bottomPadding > 0 ? bottomPadding : 16);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Вычисляем доступную высоту для контента
            // Вычитаем высоту ручки (4 + 10), заголовка (~40), отступов (12 + 10 + 12)
            final availableHeight = maxH - 88;
            final contentMaxHeight = availableHeight > 0
                ? availableHeight
                : 100.0;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // «ручка»
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10, top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.getOutlineColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),

                  // заголовок
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        title,
                        style: AppTextStyles.h17w6.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // контент — динамическая высота: занимает только необходимое место
                  // до максимальной высоты, после чего включается скролл
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: contentMaxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: child,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Заглушка (если контента нет)
class EventsSheetPlaceholder extends StatelessWidget {
  const EventsSheetPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Text(
        'Здесь будет контент…',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.getTextSecondaryColor(context),
        ),
      ),
    );
  }
}

/// Простой текст для шита «События» (замена _SimpleText)
class EventsSheetText extends StatelessWidget {
  final String text;
  const EventsSheetText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

/// Список событий из API (для отображения в bottom sheet)
class EventsListFromApi extends StatefulWidget {
  final List<dynamic> events;
  final double? latitude;
  final double? longitude;

  const EventsListFromApi({
    super.key,
    required this.events,
    this.latitude,
    this.longitude,
  });

  @override
  State<EventsListFromApi> createState() => _EventsListFromApiState();
}

class _EventsListFromApiState extends State<EventsListFromApi> {
  late List<dynamic> _events;

  @override
  void initState() {
    super.initState();
    // ── Создаем копию списка для локального обновления
    _events = List.from(widget.events);
  }

  @override
  void didUpdateWidget(EventsListFromApi oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ── Обновляем список, если изменился исходный список
    if (oldWidget.events != widget.events) {
      _events = List.from(widget.events);
    }
  }

  /// ──────────────────────── Обновление количества участников ────────────────────────
  void _updateParticipantsCount(int eventId, int newCount) {
    setState(() {
      for (var i = 0; i < _events.length; i++) {
        final event = _events[i] as Map<String, dynamic>;
        final id = event['id'] as int?;
        if (id != null && id == eventId) {
          final updatedEvent = Map<String, dynamic>.from(event);
          updatedEvent['participants_count'] = newCount;
          _events[i] = updatedEvent;
          break;
        }
      }
    });
  }

  /// Форматирует дату в формат "10.01.2027"
  /// Работает с форматом "10 января 2027" → "10.01.2027"
  String _formatDateToNumeric(String dateFormatted) {
    if (dateFormatted.isEmpty) {
      return dateFormatted;
    }

    final trimmedDate = dateFormatted.trim();

    // ──────────────────────────────────────────────────────────────
    // Парсим формат: "dd месяца yyyy"
    // Пример: "10 января 2027" → "10.01.2027"
    // ──────────────────────────────────────────────────────────────
    final regexWithYear = RegExp(
      r'^(\d{1,2})\s+([а-яА-ЯёЁ]+)\s+(\d{4})$',
      caseSensitive: false,
    );

    final matchWithYear = regexWithYear.firstMatch(trimmedDate);
    if (matchWithYear != null) {
      final dayStr = matchWithYear.group(1)!;
      final monthName = matchWithYear.group(2)!.toLowerCase();
      final yearStr = matchWithYear.group(3)!;

      // Преобразуем название месяца в число
      final monthMap = {
        'января': '01',
        'февраля': '02',
        'марта': '03',
        'апреля': '04',
        'мая': '05',
        'июня': '06',
        'июля': '07',
        'августа': '08',
        'сентября': '09',
        'октября': '10',
        'ноября': '11',
        'декабря': '12',
      };

      final monthNum = monthMap[monthName];
      if (monthNum != null) {
        // Форматируем день с ведущим нулём, если нужно
        final day = dayStr.padLeft(2, '0');
        return '$day.$monthNum.$yearStr';
      }
    }

    // Если не удалось распарсить, возвращаем как есть
    return dateFormatted;
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Text(
          'События не найдены',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // ───────────────────── Лёгкий префетч логотипов (топ-8) ─────────────────────
    // Выполняется при первом построении: подогреваем кэш под целевые размеры
    // для ускорения первого кадра и плавного скролла.
    () {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final targetW = (100 * dpr).round();
      final int limit = _events.length < 8 ? _events.length : 8;
      for (var i = 0; i < limit; i++) {
        final e = _events[i] as Map<String, dynamic>;
        final logoUrl = e['logo_url'] as String?;
        if (logoUrl != null && logoUrl.isNotEmpty) {
          // precacheImage не блокирует UI; повторные вызовы недороги благодаря кэшу
          precacheImage(
            CachedNetworkImageProvider(
              logoUrl,
              maxWidth: targetW,
              maxHeight: targetW,
            ),
            context,
          );
        }
      }
    }();

    // ───────────────────── Карточка события ─────────────────────
    Widget eventCard({
      required String? logoUrl,
      required String title,
      required String date,
      required int participantsCount,
      VoidCallback? onTap,
    }) {
      // ── определяем цвет тени в зависимости от темы
      final brightness = Theme.of(context).brightness;
      final shadowColor = brightness == Brightness.dark
          ? AppColors.darkShadowSoft
          : AppColors.shadowSoft;

      final card = Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Логотип события (круглый)
            SizedBox(
              height: 100,
              width: 100,
              child: ClipOval(child: _EventLogoImage(logoUrl: logoUrl)),
            ),
            const SizedBox(height: 8),

            // Название события с горизонтальным скроллингом
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Дата и количество участников
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.2,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.2,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.person_2,
                    size: 15,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatParticipants(participantsCount),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.2,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      if (onTap == null) return card;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }

    // ─────────────────────────── Сетка карточек 2xN (или 1xN если событие одно) ───────────────────────────
    // Если событий только одно, показываем карточку на всю ширину (как две карточки)
    // Используем shrinkWrap для динамической высоты bottom sheet
    final isSingleEvent = _events.length == 1;
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSingleEvent ? 1 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 174,
      ),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index] as Map<String, dynamic>;
        final eventId = event['id'] as int?;
        final name = event['name'] as String? ?? '';
        final logoUrl = event['logo_url'] as String?;
        final dateRaw = event['date'] as String? ?? '';
        // ── Если событие одно, используем исходный формат даты (например, "13 августа 2026")
        // ── Если событий несколько, форматируем в числовой формат "10.01.2027"
        final date = isSingleEvent ? dateRaw : _formatDateToNumeric(dateRaw);
        final participantsCount = event['participants_count'] as int? ?? 0;
        // ── Проверяем, является ли событие официальным (топ событием)
        // Используем event_type для точного определения, так как registration_link может отсутствовать в кратком списке
        final eventType = event['event_type'] as String? ?? 'amateur';
        final registrationLink =
            event['registration_link'] as String? ??
            event['event_link'] as String? ??
            '';
        final isOfficialEvent =
            eventType == 'official' || registrationLink.isNotEmpty;

        return eventCard(
          logoUrl: logoUrl,
          title: name,
          date: date,
          participantsCount: participantsCount,
          onTap: eventId != null
              ? () async {
                  final result = await Navigator.of(context).push<dynamic>(
                    TransparentPageRoute(
                      builder: (_) => isOfficialEvent
                          ? OfficialEventDetailScreen(eventId: eventId)
                          : EventDetailScreen2(eventId: eventId),
                    ),
                  );
                  // ── если количество участников было обновлено, обновляем локально
                  if (result is Map<String, dynamic> &&
                      result['participants_count_updated'] == true &&
                      context.mounted) {
                    final updatedCount =
                        result['participants_count'] as int? ?? 0;
                    final updatedEventId = result['event_id'] as int?;
                    if (updatedEventId != null) {
                      _updateParticipantsCount(updatedEventId, updatedCount);
                    }
                  }
                  // ── если событие было удалено, закрываем bottom sheet с результатом
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop('event_deleted');
                  }
                  // ── если событие было обновлено, закрываем bottom sheet с результатом
                  if (result == 'updated' && context.mounted) {
                    Navigator.of(context).pop('event_updated');
                  }
                }
              : null,
        );
      },
    );
  }
}

/// Виджет для отображения логотипа события
///
/// Использует CachedNetworkImage для загрузки изображения из API
/// Показывает placeholder при отсутствии логотипа или ошибке загрузки
class _EventLogoImage extends StatelessWidget {
  final String? logoUrl;
  const _EventLogoImage({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    // Если логотип не указан, показываем placeholder
    if (logoUrl == null || logoUrl!.isEmpty) {
      return Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.calendar,
          size: 40,
          color: AppColors.textSecondary,
        ),
      );
    }

    // Загружаем логотип из сети с кэшированием
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetW = (100 * dpr).round();

    return CachedNetworkImage(
      imageUrl: logoUrl!,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: targetW,
      maxWidthDiskCache: targetW,
      errorWidget: (context, imageUrl, error) => Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: AppColors.textSecondary,
        ),
      ),
      placeholder: (context, imageUrl) => Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

// Формат "58 234"
String _formatParticipants(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) {
      buf.write('\u202F'); // узкий неразрывный пробел
    }
  }
  return buf.toString();
}
