// lib/screens/notifications_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
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

      if (state.hasMore &&
          !state.isLoadingMore &&
          pos.extentAfter < 400) {
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
  IconData _getIconData(String iconCode) {
    switch (iconCode) {
      case 'directions_run':
        return Icons.directions_run;
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

  // Отметка уведомления как прочитанного при клике
  void _onNotificationTap(NotificationItem notification) {
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead([notification.id]);
    }
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
            IconButton(
              padding: const EdgeInsets.only(right: 12),
              splashRadius: 22,
              icon: Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              onPressed: _openSettingsSheet,
            ),
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
                    Text(
                      'Ошибка загрузки уведомлений',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
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

                final item = InkWell(
                  onTap: () => _onNotificationTap(notification),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Аватарка отправителя
                        ClipOval(
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
                                    color: _getColorFromString(notification.color),
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
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
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
