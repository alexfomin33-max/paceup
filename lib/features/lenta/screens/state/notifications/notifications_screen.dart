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
import '../../../../map/screens/events/event_detail_screen2.dart';
import '../../activity/description_screen.dart';
import '../../../../../domain/models/activity_lenta.dart' as al;
import '../../../providers/lenta_provider.dart';
import '../../widgets/post/description_post_card.dart';
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
  bool _isMarkingAllAsRead = false;

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

  // ─────────────────────────────────────────────────────────────────────────────
  // ФОРМАТИРОВАНИЕ ТЕКСТА УВЕДОМЛЕНИЯ: для забегов и заездов — округление до 2 знаков после запятой,
  // для заплывов — конвертация в метры без десятичных значений
  // ─────────────────────────────────────────────────────────────────────────────
  String _formatNotificationText(String text) {
    // Паттерн для забегов: "закончил забег X км." или "закончил забег X.XX км."
    // Поддерживаем как точку, так и запятую в числе
    // Округляем до 2 знаков после запятой
    final runPattern = RegExp(
      r'закончил забег\s+(\d+(?:[.,]\d+)?)\s*км\.?',
      caseSensitive: false,
    );

    text = text.replaceAllMapped(runPattern, (match) {
      final distanceStr = (match.group(1) ?? '0').replaceAll(',', '.');
      final distanceKm = double.tryParse(distanceStr) ?? 0.0;
      // Округляем до 2 знаков после запятой и форматируем с запятой
      final formattedDistance = distanceKm.toStringAsFixed(2).replaceAll('.', ',');
      return 'закончил забег $formattedDistance км';
    });

    // Паттерн для заездов: "закончил заезд X км." или "закончил заезд X.XX км."
    // Поддерживаем как точку, так и запятую в числе
    // Округляем до 2 знаков после запятой
    final ridePattern = RegExp(
      r'закончил заезд\s+(\d+(?:[.,]\d+)?)\s*км\.?',
      caseSensitive: false,
    );

    text = text.replaceAllMapped(ridePattern, (match) {
      final distanceStr = (match.group(1) ?? '0').replaceAll(',', '.');
      final distanceKm = double.tryParse(distanceStr) ?? 0.0;
      // Округляем до 2 знаков после запятой и форматируем с запятой
      final formattedDistance = distanceKm.toStringAsFixed(2).replaceAll('.', ',');
      return 'закончил заезд $formattedDistance км';
    });

    // Паттерн для заплывов: "закончил заплыв X.XX км." или "закончил заплыв X км."
    // Поддерживаем как точку, так и запятую в числе
    // Заменяем на формат в метрах без десятичных значений: "закончил заплыв XXX м"
    final swimPattern = RegExp(
      r'закончил заплыв\s+(\d+(?:[.,]\d+)?)\s*км\.?',
      caseSensitive: false,
    );

    text = text.replaceAllMapped(swimPattern, (match) {
      final distanceStr = (match.group(1) ?? '0').replaceAll(',', '.');
      final distanceKm = double.tryParse(distanceStr) ?? 0.0;
      final distanceMeters = (distanceKm * 1000).round();
      return 'закончил заплыв $distanceMeters м';
    });

    return text;
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
        return CupertinoIcons.person_badge_plus;
      default:
        return CupertinoIcons.bell;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Получение иконки для уведомления на основе текста
  // Для тренировок определяет иконку по тексту ("закончил заплыв" → иконка плавания и т.д.)
  // ─────────────────────────────────────────────────────────────────────────────
  IconData _getIconDataForNotification(NotificationItem notification) {
    final text = notification.text.toLowerCase();

    // Проверяем текст на наличие упоминаний о тренировках
    if (text.contains('закончил заплыв') || text.contains('заплыв')) {
      return Icons.pool;
    }
    // Проверяем лыжи перед заездом, чтобы приоритет был у лыж
    if (text.contains('лыжах') || text.contains('лыж') || text.contains('лыжный')) {
      return Icons.downhill_skiing;
    }
    if (text.contains('закончил заезд') || text.contains('заезд') || text.contains('велотренажер')) {
      return Icons.pedal_bike;
    }
    if (text.contains('закончил забег') || text.contains('забег') || text.contains('беговой дорожке')) {
      return Icons.directions_run;
    }
    if (text.contains('закончил прогулку') || text.contains('прогулку')) {
      return Icons.directions_walk;
    }
    if (text.contains('закончил поход') || text.contains('поход')) {
      return Icons.terrain;
    }

    // Если это не тренировка, используем стандартную логику по icon коду
    return _getIconData(notification.icon);
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

    // Для подписок всегда зеленый цвет
    const followIcons = {'person_badge_plus', 'person_add'};

    if (trainingIcons.contains(notification.icon.toLowerCase())) {
      return AppColors.brandPrimary;
    }

    if (heartIcons.contains(notification.icon.toLowerCase())) {
      return AppColors.error;
    }

    if (followIcons.contains(notification.icon.toLowerCase())) {
      return AppColors.green;
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
  // ОБРАБОТКА КЛИКА: массовая пометка всех уведомлений как прочитанных
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _markAllAsRead() async {
    if (_isMarkingAllAsRead) return; // Предотвращаем множественные вызовы

    final state = ref.read(notificationsProvider);

    // Проверяем, есть ли непрочитанные уведомления
    final hasUnread = state.items.any((n) => !n.isRead);
    if (!hasUnread && state.unreadCount == 0) {
      // Все уже прочитаны, ничего не делаем
      return;
    }

    setState(() {
      _isMarkingAllAsRead = true;
    });

    try {
      // Вызываем метод провайдера для массовой пометки (передаем null для всех уведомлений)
      await ref.read(notificationsProvider.notifier).markAsRead(null);
    } catch (e) {
      // Показываем ошибку пользователю, если что-то пошло не так
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отметке уведомлений: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAllAsRead = false;
        });
      }
    }
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
  // ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: загрузка поста по ID
  // ─────────────────────────────────────────────────────────────────────────────
  Future<al.Activity?> _loadPostById(int postId, int currentUserId) async {
    // Сначала пытаемся найти в ленте
    final lentaState = ref.read(lentaProvider(currentUserId));
    try {
      return lentaState.items.firstWhere(
        (a) => a.id == postId && a.type == 'post',
      );
    } catch (e) {
      // Пост не найден в ленте
    }

    // Загружаем через API, проверяя несколько страниц
    try {
      final api = ref.read(apiServiceProvider);

      // Проверяем первые 3 страницы (до 300 элементов)
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
              (a) => a.id == postId && a.type == 'post',
            );
          } catch (e2) {
            // Пост не найден на этой странице, продолжаем поиск
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
          builder: (_) => EventDetailScreen2(eventId: objectId),
        ),
      );
      return;
    }

    // ─── Переход на комментарий
    // ВАЖНО: проверяем комментарии ПЕРВЫМИ, так как они более специфичны
    // Для комментария objectType и objectId указывают на объект (activity/post),
    // к которому был оставлен комментарий, а не на сам комментарий
    final isCommentNotification =
        notificationType == 'comments' ||
        notificationType.contains('comment') ||
        notificationType.contains('комментар');

    if (isCommentNotification) {
      // Открываем экран объекта, к которому относится комментарий
      if (objectType == 'activity' || objectType == 'training') {
        final foundActivity = await _loadActivityById(objectId, currentUserId);

        // Проверяем, что виджет все еще смонтирован после async операции
        if (!mounted) return;

        if (foundActivity != null) {
          Navigator.of(context, rootNavigator: true).push(
            TransparentPageRoute(
              builder: (_) => ActivityDescriptionPage(
                activity: foundActivity,
                currentUserId: currentUserId,
              ),
            ),
          );
        }
      } else if (objectType == 'post') {
        final foundPost = await _loadPostById(objectId, currentUserId);

        // Проверяем, что виджет все еще смонтирован после async операции
        if (!mounted) return;

        if (foundPost != null) {
          Navigator.of(context, rootNavigator: true).push(
            TransparentPageRoute(
              builder: (_) => PostDescriptionScreen(
                post: foundPost,
                currentUserId: currentUserId,
              ),
            ),
          );
        }
      }
      return;
    }

    // ─── Переход на лайк
    // ВАЖНО: проверяем лайки ВТОРЫМИ, так как они более специфичны чем общие посты/активности
    // Для лайка открываем экран объекта, которому поставили лайк
    final isLikeNotification =
        notificationType == 'likes' ||
        notificationType.contains('like') ||
        notificationType.contains('лайк');

    if (isLikeNotification) {
      if (objectType == 'activity' || objectType == 'training') {
        final foundActivity = await _loadActivityById(objectId, currentUserId);

        // Проверяем, что виджет все еще смонтирован после async операции
        if (!mounted) return;

        if (foundActivity != null) {
          Navigator.of(context, rootNavigator: true).push(
            TransparentPageRoute(
              builder: (_) => ActivityDescriptionPage(
                activity: foundActivity,
                currentUserId: currentUserId,
              ),
            ),
          );
        }
      } else if (objectType == 'post') {
        final foundPost = await _loadPostById(objectId, currentUserId);

        // Проверяем, что виджет все еще смонтирован после async операции
        if (!mounted) return;

        if (foundPost != null) {
          Navigator.of(context, rootNavigator: true).push(
            TransparentPageRoute(
              builder: (_) => PostDescriptionScreen(
                post: foundPost,
                currentUserId: currentUserId,
              ),
            ),
          );
        }
      }
      return;
    }

    // ─── Переход на пост
    // Для поста открываем экран поста
    // ВАЖНО: проверяем как objectType, так и notificationType ('posts' для новых постов)
    final isPostNotification =
        objectType == 'post' ||
        notificationType == 'posts' ||
        notificationType.contains('post') ||
        notificationType.contains('пост');

    if (isPostNotification) {
      final foundPost = await _loadPostById(objectId, currentUserId);

      // Проверяем, что виджет все еще смонтирован после async операции
      if (!mounted) return;

      if (foundPost != null) {
        Navigator.of(context, rootNavigator: true).push(
          TransparentPageRoute(
            builder: (_) => PostDescriptionScreen(
              post: foundPost,
              currentUserId: currentUserId,
            ),
          ),
        );
      }
      return;
    }

    // ─── Переход на тренировку/активность
    // Проверяем и objectType и notificationType для надежности
    // ВАЖНО: эта проверка идет ПОСЛЕДНЕЙ, так как она самая общая
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
        Navigator.of(context, rootNavigator: true).push(
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
            // Кнопка «отметить все как прочитанные»
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: _isMarkingAllAsRead ? null : _markAllAsRead,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                splashRadius: 22,
                icon: _isMarkingAllAsRead
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CupertinoActivityIndicator(radius: 8),
                      )
                    : Icon(
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
                indent: 70,
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
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Аватарка отправителя (с обработчиком клика)
                            GestureDetector(
                              onTap: () =>
                                  _handleAvatarTap(notification.senderId),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: notification.senderAvatar,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              width: 52,
                                              height: 52,
                                              color: AppColors.skeletonBase,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              width: 52,
                                              height: 52,
                                              color: AppColors.skeletonBase,
                                              child: const Icon(
                                                CupertinoIcons.person,
                                              ),
                                            ),
                                      ),
                                    ),
                                    // ─── Иконка уведомления в правом верхнем углу ───
                                    Positioned(
                                      right: -3,
                                      top: -3,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _resolveIconColor(
                                            notification,
                                          ),
                                          border: Border.all(
                                            color: AppColors.getSurfaceColor(
                                              context,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          _getIconDataForNotification(
                                            notification,
                                          ),
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                _formatNotificationText(notification.text),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ─── Дата в правом нижнем углу карточки ───
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Text(
                            _formatWhen(notification.createdAt),
                            style: AppTextStyles.h11w4Ter,
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
