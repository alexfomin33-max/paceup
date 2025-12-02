import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../domain/models/event.dart';
import '../../../../../../features/map/providers/events/bookmarked_events_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../features/map/screens/events/event_detail_screen.dart';

/// Вкладка «Закладки» — карточный список с промежутками (как в Маршрутах)
/// Загружает события из закладок пользователя через API
class BookmarksContent extends ConsumerStatefulWidget {
  const BookmarksContent({super.key});

  @override
  ConsumerState<BookmarksContent> createState() => _BookmarksContentState();
}

class _BookmarksContentState extends ConsumerState<BookmarksContent> {
  @override
  Widget build(BuildContext context) {
    // Получаем текущего пользователя из AuthService
    final currentUserIdAsync = ref.watch(currentUserIdProvider);

    // Обрабатываем состояние загрузки userId
    return currentUserIdAsync.when(
      data: (userId) {
        if (userId == null) {
          // Пользователь не авторизован
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Необходима авторизация',
                      // ── Цвет текста из темы
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Загружаем события из закладок через provider
        final eventsState = ref.watch(bookmarkedEventsProvider(userId));

        return RefreshIndicator.adaptive(
          onRefresh: () async {
            await ref.read(bookmarkedEventsProvider(userId).notifier).refresh();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // ── Состояния загрузки и ошибок
              if (eventsState.isLoading && eventsState.events.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                )
              else if (eventsState.error != null && eventsState.events.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ошибка: ${eventsState.error}',
                            // ── Цвет текста из темы
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          CupertinoButton(
                            onPressed: () {
                              ref
                                  .read(
                                    bookmarkedEventsProvider(userId).notifier,
                                  )
                                  .loadInitial();
                            },
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (eventsState.events.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'У вас пока нет закладок',
                        // ── Цвет текста из темы
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // ── Карточный список с зазором 2 px (как в Маршрутах)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  sliver: SliverList.separated(
                    itemCount: eventsState.events.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: 2,
                    ), // такой же зазор, как в Маршрутах
                    itemBuilder: (context, i) {
                      final event = eventsState.events[i];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          final result = await Navigator.of(context)
                              .push<dynamic>(
                                TransparentPageRoute(
                                  builder: (_) =>
                                      EventDetailScreen(eventId: event.id),
                                ),
                              );
                          // Если событие было удалено или удалено из закладок, обновляем список
                          if (result == true || result == 'bookmark_removed') {
                            if (mounted) {
                              await ref
                                  .read(
                                    bookmarkedEventsProvider(userId).notifier,
                                  )
                                  .refresh();
                            }
                          }
                        },
                        child: _BookmarkCard(event: event),
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
      loading: () => const CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CupertinoActivityIndicator()),
            ),
          ),
        ],
      ),
      error: (err, stack) => CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Ошибка: $err',
                  // ── Цвет текста из темы
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final Event event;
  const _BookmarkCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // ── Цвет поверхности из темы
        color: AppColors.getSurfaceColor(context),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            // ── Тень из темы (более заметная в темной теме)
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: _BookmarkRow(event: event),
    );
  }
}

class _BookmarkRow extends ConsumerWidget {
  final Event event;
  const _BookmarkRow({required this.event});

  /// Показываем диалог подтверждения удаления из закладок
  Future<bool> _confirmRemove(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удалить из закладок?'),
        content: const Text('Событие будет удалено из ваших закладок.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Обработчик удаления из закладок
  Future<void> _handleRemoveBookmark(
    BuildContext context,
    WidgetRef ref,
    int eventId,
  ) async {
    // Показываем диалог подтверждения
    final confirmed = await _confirmRemove(context);
    if (!confirmed) return;

    // Получаем userId из AuthService
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Пользователь не авторизован'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Удаляем из закладок через notifier
    final success = await ref
        .read(bookmarkedEventsProvider(userId).notifier)
        .removeBookmark(eventId);

    if (context.mounted) {
      if (success) {
        // Показываем уведомление об успешном удалении (опционально)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Событие удалено из закладок'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Показываем ошибку
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при удалении из закладок'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      // внутренние отступы карточки
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: event.logoUrl != null && event.logoUrl!.isNotEmpty
                ? Builder(
                    builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final targetW = (55 * dpr).round();
                      final targetH = (55 * dpr).round();
                      return CachedNetworkImage(
                        imageUrl: event.logoUrl!,
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                        memCacheWidth: targetW,
                        memCacheHeight: targetH,
                        maxWidthDiskCache: targetW,
                        maxHeightDiskCache: targetH,
                        errorWidget: (context, imageUrl, error) => Container(
                          width: 55,
                          height: 55,
                          // ── Цвет скелетона (можно оставить константу, т.к. это декоративный элемент)
                          color: AppColors.skeletonBase,
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.photo,
                            size: 20,
                            // ── Цвет иконки из темы
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                        ),
                        placeholder: (context, imageUrl) => Container(
                          width: 55,
                          height: 55,
                          color: AppColors.skeletonBase,
                          alignment: Alignment.center,
                          child: const CupertinoActivityIndicator(),
                        ),
                      );
                    },
                  )
                : Container(
                    width: 55,
                    height: 55,
                    color: AppColors.skeletonBase,
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 20,
                      // ── Цвет иконки из темы
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Первая строка: Название + красный кружок с крестиком
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // ── Цвет текста из темы
                        style: AppTextStyles.h14w6.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    _RemoveButton(
                      eventId: event.id,
                      onRemove: () =>
                          _handleRemoveBookmark(context, ref, event.id),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatDateWithoutCurrentYear(event.dateFormatted)}  ·  Участников: ${_fmt(event.participantsCount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // ── Цвет текста из темы
                  style: AppTextStyles.h13w5.copyWith(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка удаления из закладок (красный кружок с крестиком)
class _RemoveButton extends StatelessWidget {
  final int eventId;
  final VoidCallback onRemove;
  const _RemoveButton({required this.eventId, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      onPressed: onRemove,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.error, width: 1),
        ),
        child: const Icon(
          CupertinoIcons.xmark,
          size: 12,
          color: AppColors.error,
        ),
      ),
    );
  }
}

/// Форматирует дату, убирая год, если это текущий год
/// Работает с форматом "10 июня 2025" → "10 июня" (если 2025 = текущий год)
String _formatDateWithoutCurrentYear(String dateFormatted) {
  if (dateFormatted.isEmpty) {
    return dateFormatted;
  }

  final currentYear = DateTime.now().year;
  final trimmedDate = dateFormatted.trim();

  // ──────────────────────────────────────────────────────────────
  // Ищем паттерн: "dd месяца yyyy" (с годом)
  // Пример: "10 июня 2025" → "10 июня" (если 2025 = текущий год)
  // ──────────────────────────────────────────────────────────────
  final regexWithYear = RegExp(
    r'^(\d{1,2})\s+([а-яА-ЯёЁ]+)\s+(\d{4})$',
    caseSensitive: false,
  );

  final matchWithYear = regexWithYear.firstMatch(trimmedDate);
  if (matchWithYear != null) {
    final yearStr = matchWithYear.group(3)!;
    final year = int.tryParse(yearStr);
    if (year != null && year == currentYear) {
      // Год текущий — убираем его
      final day = matchWithYear.group(1)!;
      final monthName = matchWithYear.group(2)!;
      return '$day $monthName';
    }
    // Год не текущий — возвращаем как есть
    return dateFormatted;
  }

  // ──────────────────────────────────────────────────────────────
  // Более гибкий поиск: ищем любой 4-значный год в строке
  // и удаляем его, если это текущий год
  // ──────────────────────────────────────────────────────────────
  final yearPattern = RegExp(r'\b(\d{4})\b');
  final allMatches = yearPattern.allMatches(trimmedDate);

  for (final match in allMatches) {
    final yearStr = match.group(1)!;
    final year = int.tryParse(yearStr);
    if (year != null && year == currentYear) {
      // Нашли текущий год — удаляем его вместе с окружающими пробелами
      final before = trimmedDate.substring(0, match.start);
      final after = trimmedDate.substring(match.end);
      // Убираем лишние пробелы
      return '${before.trim()} ${after.trim()}'.trim();
    }
  }

  // Не нашли текущий год — возвращаем как есть
  return dateFormatted;
}

String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    b.write(s[i]);
    if (rev > 1 && rev % 3 == 1) b.write('\u202F'); // узкий неразрывный пробел
  }
  return b.toString();
}
