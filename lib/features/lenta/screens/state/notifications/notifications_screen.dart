// lib/screens/notifications_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../../providers/services/auth_provider.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../profile/screens/profile_screen.dart';
import '../../../../map/screens/events/event_detail_screen.dart';
import '../../activity/description_screen.dart';
import '../../../../../domain/models/activity_lenta.dart' as al;
import '../../../providers/lenta_provider.dart';
import 'settings_bottom_sheet.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Загружаем уведомления при открытии экрана
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).loadInitial();
    });

    // Автоматическая подгрузка при скролле
    _scrollController.addListener(() {
      final state = ref.read(notificationsProvider);
      final pos = _scrollController.position;

      if (state.hasMore && !state.isLoadingMore && pos.extentAfter < 400) {
        ref.read(notificationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatWhen(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diffDays = day.difference(today).inDays;

    if (diffDays == 0) return DateFormat('HH:mm').format(d);
    if (diffDays == -1) return 'Вчера, ${DateFormat('HH:mm').format(d)}';
    if (diffDays == -2) return 'Позавчера, ${DateFormat('HH:mm').format(d)}';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  // Получение иконки по строковому коду
  // ─────────────────────────────────────────────────────────────────────────────
  // Подбираем иконку по строковому коду; для тренировок берём те же иконки,
  // что используются во вкладке тренировок профиля
  // ─────────────────────────────────────────────────────────────────────────────
  IconData _getIconData(String iconCode) {
    final code = iconCode.toLowerCase();

    switch (code) {
      case 'directions_run':
      case 'run':
        return Icons.directions_run;
      case 'pedal_bike':
      case 'bike':
      case 'directions_bike':
        return Icons.pedal_bike;
      case 'pool':
      case 'swim':
        return Icons.pool;
      case 'favorite':
        return CupertinoIcons.heart;
      case 'comment':
        return CupertinoIcons.text_bubble;
      case 'article':
        return CupertinoIcons.square_pencil;
      case 'event':
        return CupertinoIcons.calendar_badge_plus;
      case 'how_to_reg':
        return Icons.emoji_events_outlined;
      case 'person_add':
        return CupertinoIcons.person_add;
      default:
        return CupertinoIcons.bell;
    }
  }

  // Получение цвета из строки
  Color _getColorFromString(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.brandPrimary;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Получаем цвет иконки уведомления; для тренировок всегда brandPrimary
  // ─────────────────────────────────────────────────────────────────────────────
  Color _resolveIconColor(NotificationItem notification) {
    // Для тренировок принудительно используем фирменный цвет
    const trainingIcons = {
      'directions_run',
      'run',
      'pedal_bike',
      'bike',
      'directions_bike',
      'pool',
      'swim',
    };

    // Для лайков/сердец всегда красный цвет
    const heartIcons = {'favorite', 'heart'};

    if (trainingIcons.contains(notification.icon.toLowerCase())) {
      return AppColors.brandPrimary;
    }

    if (heartIcons.contains(notification.icon.toLowerCase())) {
      return AppColors.error;
    }

    return _getColorFromString(notification.color);
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsSheet(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: загрузка активности по ID
  // ─────────────────────────────────────────────────────────────────────────────
  Future<al.Activity?> _loadActivityById(
    int activityId,
    int currentUserId,
  ) async {
    // Сначала пытаемся найти в ленте
    final lentaState = ref.read(lentaProvider(currentUserId));
    try {
      return lentaState.items.firstWhere(
        (a) => a.id == activityId && a.type != 'post',
      );
    } catch (e) {
      // Активность не найдена в ленте
    }

    // Загружаем через API, проверяя несколько страниц
    try {
      final api = ref.read(apiServiceProvider);

      // Проверяем первые 3 страницы (до 300 активностей)
      for (int page = 1; page <= 3; page++) {
        try {
          final data = await api.post(
            '/activities_lenta.php',
            body: {
              'userId': currentUserId.toString(),
              'limit': '100',
              'page': page.toString(),
            },
            timeout: const Duration(seconds: 10),
          );

          final List rawList = data['data'] as List? ?? const [];
          final activities = rawList
              .whereType<Map<String, dynamic>>()
              .map((json) => al.Activity.fromApi(json))
              .toList();

          try {
            return activities.firstWhere(
              (a) => a.id == activityId && a.type != 'post',
            );
          } catch (e2) {
            // Активность не найдена на этой странице, продолжаем поиск
          }
        } catch (e) {
          // Ошибка загрузки страницы, продолжаем
          break;
        }
      }
    } catch (e) {
      // Ошибка загрузки через API
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // НАВИГАЦИЯ: обработка клика на уведомление
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleNotificationTap(NotificationItem notification) async {
    // Получаем userId из FutureProvider через .future для await
    final currentUserId = await ref.read(currentUserIdProvider.future);

    // Проверяем, что виджет все еще смонтирован после async операции
    if (!mounted) return;

    if (currentUserId == null) return;

    // Отмечаем уведомление как прочитанное
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead([notification.id]);
    }

    // Определяем тип объекта и выполняем навигацию
    final objectType = notification.objectType.toLowerCase();
    final objectId = notification.objectId;
    final notificationType = notification.notificationType.toLowerCase();

    // ─── Переход на профиль пользователя (клик на аватарку обрабатывается отдельно)
    if (objectType == 'user' ||
        notificationType.contains('follow') ||
        notificationType.contains('подпис')) {
      if (!mounted) return;
      Navigator.of(context).push(
        TransparentPageRoute(
          builder: (_) => ProfileScreen(userId: notification.senderId),
        ),
      );
      return;
    }

    // ─── Переход на событие
    if (objectType == 'event') {
      // Проверяем, является ли это официальным событием (топ событие)
      // Для простоты используем обычный экран события
      // Если нужно различать, можно добавить дополнительное поле в уведомление
      if (!mounted) return;
      Navigator.of(context).push(
        TransparentPageRoute(
          builder: (_) => EventDetailScreen(eventId: objectId),
        ),
      );
      return;
    }

    // ─── Переход на тренировку/активность
    // Проверяем и objectType и notificationType для надежности
    final isActivityNotification =
        objectType == 'activity' ||
        objectType == 'training' ||
        notificationType == 'workouts' ||
        notificationType.contains('workout') ||
        notificationType.contains('тренировк');

    if (isActivityNotification) {
      final foundActivity = await _loadActivityById(objectId, currentUserId);

      // Проверяем, что виджет все еще смонтирован после async операции
      if (!mounted) return;

      if (foundActivity != null) {
        Navigator.of(context).push(
          TransparentPageRoute(
            builder: (_) => ActivityDescriptionPage(
              activity: foundActivity,
              currentUserId: currentUserId,
            ),
          ),
        );
      }
      return;
    }

    // ─── Переход на пост
    // Для поста открываем экран поста (комментарии открываются внутри)
    // Но так как отдельного экрана поста нет, открываем комментарии
    // В будущем можно добавить отдельный экран поста
    if (objectType == 'post' || notificationType.contains('пост')) {
      // Пока просто ничего не делаем, так как нет отдельного экрана поста
      // Можно открыть ленту и прокрутить к посту, но это сложно
      return;
    }

    // ─── Переход на комментарий
    // Для комментария objectType и objectId указывают на объект (activity/post),
    // к которому был оставлен комментарий, а не на сам комментарий
    final isCommentNotification =
        notificationType == 'comments' ||
        notificationType.contains('comment') ||
        notificationType.contains('комментар');

    if (isCommentNotification) {
      // Открываем экран объекта, к которому относится комментарий
      if (objectType == 'activity') {
        final foundActivity = await _loadActivityById(objectId, currentUserId);

        // Проверяем, что виджет все еще смонтирован после async операции
        if (!mounted) return;

        if (foundActivity != null) {
          Navigator.of(context).push(
            TransparentPageRoute(
              builder: (_) => ActivityDescriptionPage(
                activity: foundActivity,
                currentUserId: currentUserId,
              ),
            ),
          );
        }
      } else if (objectType == 'post') {
        // Для поста пока ничего не делаем (нет отдельного экрана поста)
      }
      return;
    }

    // ─── Переход на лайк
    // Для лайка открываем экран объекта, которому поставили лайк
    final isLikeNotification =
        notificationType == 'likes' ||
        notificationType.contains('like') ||
        notificationType.contains('лайк');

    if (isLikeNotification) {
      if (objectType == 'activity') {
        final foundActivity = await _loadActivityById(objectId, currentUserId);

        // Проверяем, что виджет все еще смонтирован после async операции
        if (!mounted) return;

        if (foundActivity != null) {
          Navigator.of(context).push(
            TransparentPageRoute(
              builder: (_) => ActivityDescriptionPage(
                activity: foundActivity,
                currentUserId: currentUserId,
              ),
            ),
          );
        }
      } else if (objectType == 'post') {
        // Для поста пока ничего не делаем
      }
      return;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // НАВИГАЦИЯ: обработка клика на аватарку пользователя
  // ─────────────────────────────────────────────────────────────────────────────
  void _handleAvatarTap(int userId) {
    Navigator.of(
      context,
    ).push(TransparentPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),

        appBar: PaceAppBar(
          title: 'Уведомления',
          actions: [
            // Кнопка «отметить» (функционал добавим позже)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                splashRadius: 22,
                icon: Icon(
                  CupertinoIcons.check_mark_circled,
                  size: 20,
                  color: AppColors.getIconPrimaryColor(context),
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: _openSettingsSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                splashRadius: 22,
                icon: Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 20,
                  color: AppColors.getIconPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),

        body: RefreshIndicator.adaptive(
          onRefresh: () async {
            await ref.read(notificationsProvider.notifier).refresh();
          },
          child: () {
            // Показываем ошибку, если есть
            if (state.error != null && state.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ошибка загрузки уведомлений',
                      style: TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      onPressed: () {
                        ref.read(notificationsProvider.notifier).loadInitial();
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }

            // Показываем индикатор загрузки при первой загрузке
            if (state.isLoading && state.items.isEmpty) {
              return const Center(child: CupertinoActivityIndicator());
            }

            // Показываем пустое состояние
            if (state.items.isEmpty) {
              return Center(
                child: Text(
                  'Нет уведомлений',
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              );
            }

            // Список уведомлений
            return ListView.separated(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.getBorderColor(context)
                    : AppColors.border,
                indent: 57,
                endIndent: 8,
              ),
              itemBuilder: (context, i) {
                // Индикатор загрузки в конце списка
                if (i == state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                final notification = state.items[i];
                final isRead = notification.isRead;

                // ────────────────────────────────────────────────────────────────
                // Оборачиваем в GestureDetector для обработки клика на уведомление
                // ────────────────────────────────────────────────────────────────
                final item = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleNotificationTap(notification),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Аватарка отправителя (с обработчиком клика)
                        GestureDetector(
                          onTap: () => _handleAvatarTap(notification.senderId),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: notification.senderAvatar,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 40,
                                height: 40,
                                color: AppColors.skeletonBase,
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 40,
                                height: 40,
                                color: AppColors.skeletonBase,
                                child: const Icon(CupertinoIcons.person),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getIconData(notification.icon),
                                    size: 16,
                                    color: _resolveIconColor(notification),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatWhen(notification.createdAt),
                                    style: AppTextStyles.h11w4Ter,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notification.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                // Нижняя граница под самой последней карточкой
                final isLastVisible = i == state.items.length - 1;
                if (isLastVisible) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item,
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.getBorderColor(context)
                            : AppColors.border,
                      ),
                    ],
                  );
                }

                return item;
              },
            );
          }(),
        ),
      ),
    );
  }
}
