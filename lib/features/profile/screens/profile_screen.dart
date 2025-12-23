import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart'; // ← наш глобальный AppBar
import '../../../core/widgets/transparent_route.dart';
import '../../../core/widgets/more_menu_overlay.dart';
import '../../../core/widgets/more_menu_hub.dart';
import '../providers/profile_header_provider.dart';
import '../providers/profile_header_state.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../providers/services/api_provider.dart';
import '../../../core/services/api_service.dart'; // для ApiException
import '../../lenta/providers/lenta_provider.dart';

// общие виджеты
import 'widgets/header_card.dart';
import 'widgets/tabs_bar.dart';

// вкладки
import 'tabs/main/main_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/races/races_tab.dart';
import 'tabs/equipment/equipment_tab.dart';
import 'tabs/clubs_tab.dart';
import 'tabs/awards/awards_tab.dart';
import 'tabs/skills/skills_tab.dart';

// общий стейт видимости снаряжения
import 'tabs/main/widgets/gear_screen.dart';
import 'state/search/search_screen.dart';

// экран настроек
import 'state/settings/settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  /// Опциональный userId. Если не передан, используется текущий пользователь из AuthService
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _tabTitles = [
    'Основное',
    'Фото',
    'Статистика',
    'Тренировки',
    'Соревнования',
    'Снаряжение',
    'Клубы',
    'Награды',
    'Навыки',
  ];

  final PageController _pageController = PageController();
  final GearPrefs _gearPrefs = GearPrefs();
  final GlobalKey<MainTabState> _mainTabKey = GlobalKey<MainTabState>();

  int _tab = 0;
  bool _wasRouteActive =
      false; // Отслеживание предыдущего состояния видимости маршрута

  @override
  void dispose() {
    _pageController.dispose();
    _gearPrefs.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Обновление данных профиля при открытии экрана
  // Вызывается при инициализации виджета для получения свежих данных
  // Использует refresh() вместо reload() чтобы не очищать кэш аватарки
  // и избежать визуального "мигания" изображения
  // ────────────────────────────────────────────────────────────────────────
  void _updateProfileHeader(int userId) {
    // Используем refresh() для обновления данных без очистки кэша аватарки
    // Это обновит количество подписок и подписчиков без визуального эффекта
    ref.read(profileHeaderProvider(userId).notifier).refresh();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Проверка видимости экрана и обновление данных при отображении
  // Вызывается при каждом build для отслеживания видимости маршрута
  // ────────────────────────────────────────────────────────────────────────
  void _checkRouteVisibility() {
    final route = ModalRoute.of(context);
    final isRouteActive = route?.isCurrent ?? false;

    // Если маршрут стал активным (видимым), обновляем данные
    if (isRouteActive && !_wasRouteActive) {
      _wasRouteActive = true;

      // Обновляем данные профиля при отображении экрана
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final userId = widget.userId;
        if (userId != null) {
          _updateProfileHeader(userId);
        } else {
          final currentUserIdAsync = ref.read(currentUserIdProvider);
          currentUserIdAsync.whenData((currentUserId) {
            if (currentUserId != null && mounted) {
              _updateProfileHeader(currentUserId);
            }
          });
        }
      });
    } else if (!isRouteActive) {
      // Если маршрут стал неактивным, сбрасываем флаг для следующего отображения
      _wasRouteActive = false;
    }
  }

  void _onTabTap(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) {
    setState(() => _tab = i);
    // При переключении на вкладку "Основное" (индекс 0) проверяем кэш
    if (i == 0) {
      MainTab.checkCache(_mainTabKey);
    }

    // ────────────────────────────────────────────────────────────────────────
    // Обновление данных профиля при переключении вкладок
    // Обновляем количество подписок и подписчиков при каждом переключении
    // ────────────────────────────────────────────────────────────────────────
    final userId = widget.userId;
    if (userId != null) {
      _updateProfileHeader(userId);
    } else {
      // Если userId не передан, получаем текущего пользователя
      final currentUserIdAsync = ref.read(currentUserIdProvider);
      currentUserIdAsync.whenData((currentUserId) {
        if (currentUserId != null) {
          _updateProfileHeader(currentUserId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────────────
    // Проверка видимости экрана и обновление данных при отображении
    // Вызывается при каждом build для отслеживания, когда экран становится видимым
    // Это гарантирует обновление данных при возврате из других экранов (например, настроек)
    // ────────────────────────────────────────────────────────────────────────
    _checkRouteVisibility();

    // Если userId передан явно, используем его, иначе получаем текущего пользователя из AuthService
    if (widget.userId != null) {
      // Используем переданный userId (например, при открытии профиля другого пользователя из ленты)
      final profileState = ref.watch(profileHeaderProvider(widget.userId!));
      return _buildProfileContent(widget.userId!, profileState);
    }

    // Получаем текущего пользователя из AuthService
    final currentUserIdAsync = ref.watch(currentUserIdProvider);

    // Обрабатываем состояние загрузки userId
    return currentUserIdAsync.when(
      data: (userId) {
        if (userId == null) {
          // Пользователь не авторизован
          return Scaffold(
            backgroundColor: AppColors.getBackgroundColor(context),
            appBar: PaceAppBar(
              titleWidget: Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 20,
                    color: AppColors.getIconPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI тренер',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              showBack: false,
              showBottomDivider: true,
            ),
            body: Center(
              child: Text(
                'Необходима авторизация',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
          );
        }

        // Читаем состояние профиля из Riverpod provider для текущего пользователя
        final profileState = ref.watch(profileHeaderProvider(userId));

        return _buildProfileContent(userId, profileState);
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          titleWidget: Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'AI тренер',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16),
              ),
              SizedBox(width: 6),
            ],
          ),
          showBack: false,
          showBottomDivider: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          titleWidget: Row(
            children: [
              Icon(
                CupertinoIcons.sparkles,
                size: 20,
                color: AppColors.iconPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'AI тренер',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16),
              ),
              SizedBox(width: 6),
            ],
          ),
          showBack: false,
          showBottomDivider: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: AppColors.error,
              ),
              SizedBox(height: 16),
              Text(
                'Ошибка загрузки данных пользователя',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Строит контент профиля для указанного userId
  Widget _buildProfileContent(int userId, ProfileHeaderState profileState) {
    // ────────────────────────────────────────────────────────────────
    // 🔍 ОПРЕДЕЛЕНИЕ: является ли открытый профиль профилем текущего
    // пользователя для условного отображения AppBar
    // ────────────────────────────────────────────────────────────────
    final currentUserIdAsync = ref.watch(currentUserIdProvider);
    final currentUserId = currentUserIdAsync.value;
    final isOwnProfile = currentUserId != null && currentUserId == userId;

    // ────────────────────────────────────────────────────────────────
    // 🔹 КЛЮЧ ДЛЯ МЕНЮ: нужен для привязки всплывающего меню в AppBar
    // ────────────────────────────────────────────────────────────────
    final menuKey = GlobalKey();

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),

      // ─────────── Верхняя шапка: обычный, плоский PaceAppBar ───────────
      appBar: PaceAppBar(
        // ────────────────────────────────────────────────────────────────
        // 🔹 ЗАГОЛОВОК: показываем "AI тренер" только для своего профиля
        // ────────────────────────────────────────────────────────────────
        titleWidget: isOwnProfile
            ? Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 20,
                    color: AppColors.getIconPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI тренер',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              )
            : null,
        title: isOwnProfile ? null : '',
        // ────────────────────────────────────────────────────────────────
        // 🔹 КНОПКА НАЗАД: показываем только для чужих профилей
        // ────────────────────────────────────────────────────────────────
        showBack: !isOwnProfile,
        // ────────────────────────────────────────────────────────────────
        // 🔹 ДЕЙСТВИЯ В APP BAR: разные для своего и чужого профиля
        // ────────────────────────────────────────────────────────────────
        actions: isOwnProfile
            ? [
                // Свой профиль — показываем стандартные иконки
                const _AppIcon(CupertinoIcons.square_arrow_up),
                _AppIcon(
                  CupertinoIcons.person_badge_plus,
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const SearchPrefsPage(startIndex: 0),
                      ),
                    );
                  },
                ),
                _AppIcon(
                  CupertinoIcons.gear,
                  onPressed: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
              ]
            : [
                // Чужой профиль — показываем только иконку трех точек
                _AppIcon(
                  CupertinoIcons.ellipsis,
                  key: menuKey,
                  onPressed: () {
                    // Вызываем асинхронную функцию без await (обработчик onPressed не возвращает Future)
                    _showUserMenu(
                      context: context,
                      ref: ref,
                      userId: userId,
                      currentUserId: currentUserId ?? 0,
                      menuKey: menuKey,
                    );
                  },
                ),
                const SizedBox(width: 6),
              ],
        showBottomDivider: true,
      ),

      // ─────────── Статика сверху (HeaderCard + TabsBar) + вкладки ниже ───────────
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Хедер профиля — статичный
          RepaintBoundary(
            child: HeaderCard(
              profile: profileState.profile,
              userId: userId,
              onReload: () {
                ref.read(profileHeaderProvider(userId).notifier).reload();
              },
            ),
          ),

          // TabsBar — тоже статичный
          RepaintBoundary(
            child: SizedBox(
              height: 40.5,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (_, _) {
                  final page = _pageController.hasClients
                      ? (_pageController.page ?? _tab.toDouble())
                      : _tab.toDouble();
                  return TabsBar(
                    value: _tab,
                    page: page,
                    items: _tabTitles,
                    onChanged: _onTabTap,
                  );
                },
              ),
            ),
          ),

          // Разделитель под табами
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),

          // Контент вкладок — скроллится внутри, шапка/табы остаются на месте
          Expanded(
            child: GearPrefsScope(
              notifier: _gearPrefs,
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  MainTab(key: _mainTabKey, userId: userId),
                  PhotosTab(userId: userId),
                  StatsTab(userId: userId),
                  TrainingTab(userId: userId),
                  const RacesTab(),
                  GearTab(userId: userId),
                  ClubsTab(userId: userId),
                  const AwardsTab(),
                  const SkillsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _AppIcon(this.icon, {super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44.0, // kAppBarTapTarget
      height: 44.0, // kAppBarTapTarget
      child: IconButton(
        onPressed: onPressed ?? () {},
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44.0, minHeight: 44.0),
        icon: Icon(
          icon,
          color: AppColors.getIconPrimaryColor(context),
          size: 20.0,
        ),
        splashRadius: 22,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
//                           ЛОКАЛЬНЫЕ ХЕЛПЕРЫ
// ────────────────────────────────────────────────────────────────────

/// Показывает всплывающее меню для действий с чужим профилем
/// (подписка, скрытие постов/тренировок, блокировка).
Future<void> _showUserMenu({
  required BuildContext context,
  required WidgetRef ref,
  required int userId,
  required int currentUserId,
  required GlobalKey menuKey,
}) async {
  // ──────────────────────────────────────────────
  // Сохраняем значения цветов до async-операции
  // для избежания использования BuildContext после async gap
  // ──────────────────────────────────────────────
  final iconPrimaryColor = AppColors.getIconPrimaryColor(context);

  // Получаем статусы пользователя с сервера
  final api = ref.read(apiServiceProvider);
  bool isSubscribed = false;
  bool arePostsHidden = false;
  bool areActivitiesHidden = false;
  bool isBlocked = false;

  try {
    final statusData = await api.post(
      '/get_user_status.php',
      body: {
        'target_user_id': userId.toString(),
      },
      timeout: const Duration(seconds: 10),
    );

    if (statusData['success'] == true) {
      isSubscribed = statusData['is_subscribed'] == true;
      arePostsHidden = statusData['are_posts_hidden'] == true;
      areActivitiesHidden = statusData['are_activities_hidden'] == true;
      isBlocked = statusData['is_blocked'] == true;
    }
  } catch (e) {
    // В случае ошибки показываем меню с дефолтными значениями
    if (kDebugMode) {
      debugPrint('Ошибка загрузки статусов пользователя: $e');
    }
  }

  // Проверяем, что контекст все еще валиден перед использованием
  if (!context.mounted) return;

  // ──────────────────────────────────────────────
  // Формируем список пунктов меню
  // ──────────────────────────────────────────────
  final items = <MoreMenuItem>[
    // 1) Подписаться / Отписаться
    MoreMenuItem(
      text: isSubscribed ? 'Отписаться' : 'Подписаться',
      icon: isSubscribed
          ? CupertinoIcons.person_badge_minus
          : CupertinoIcons.person_badge_plus,
      textStyle: isSubscribed
          ? const TextStyle(
              color: AppColors.error,
            )
          : null,
      iconColor: isSubscribed ? AppColors.error : null,
      onTap: () async {
        MoreMenuHub.hide();
        await _handleSubscribe(
          context: context,
          ref: ref,
          userId: userId,
          currentUserId: currentUserId,
          isSubscribed: isSubscribed,
        );
      },
    ),

    // 2) Скрыть посты / Показать посты
    MoreMenuItem(
      text: arePostsHidden ? 'Показать посты' : 'Скрыть посты',
      icon: CupertinoIcons.text_bubble,
      iconColor: arePostsHidden ? iconPrimaryColor : AppColors.error,
      textStyle: arePostsHidden
          ? null
          : const TextStyle(
              color: AppColors.error,
            ),
      onTap: () async {
        MoreMenuHub.hide();
        await _handleHidePosts(
          context: context,
          ref: ref,
          userId: userId,
          currentUserId: currentUserId,
          arePostsHidden: arePostsHidden,
        );
      },
    ),

    // 3) Скрыть тренировки / Показать тренировки
    MoreMenuItem(
      text: areActivitiesHidden
          ? 'Показать тренировки'
          : 'Скрыть тренировки',
      icon: CupertinoIcons.flame,
      iconColor: areActivitiesHidden ? iconPrimaryColor : AppColors.error,
      textStyle: areActivitiesHidden
          ? null
          : const TextStyle(
              color: AppColors.error,
            ),
      onTap: () async {
        MoreMenuHub.hide();
        await _handleHideActivities(
          context: context,
          ref: ref,
          userId: userId,
          currentUserId: currentUserId,
          areActivitiesHidden: areActivitiesHidden,
        );
      },
    ),

    // 4) Заблокировать / Разблокировать
    MoreMenuItem(
      text: isBlocked ? 'Разблокировать' : 'Заблокировать',
      icon: CupertinoIcons.exclamationmark_octagon,
      iconColor: AppColors.error,
      textStyle: const TextStyle(
        color: AppColors.error,
      ),
      onTap: () async {
        MoreMenuHub.hide();
        await _handleBlock(
          context: context,
          ref: ref,
          userId: userId,
          currentUserId: currentUserId,
          isBlocked: isBlocked,
        );
      },
    ),
  ];

  MoreMenuOverlay(
    anchorKey: menuKey,
    items: items,
  ).show(context);
}

/// Обработчик подписки/отписки
Future<void> _handleSubscribe({
  required BuildContext context,
  required WidgetRef ref,
  required int userId,
  required int currentUserId,
  required bool isSubscribed,
}) async {
  if (!context.mounted) return;

  final api = ref.read(apiServiceProvider);

  try {
    final data = await api.post(
      '/toggle_subscribe.php',
      body: {
        'target_user_id': userId.toString(),
        'action': isSubscribed ? 'unsubscribe' : 'subscribe',
      },
      timeout: const Duration(seconds: 10),
    );

    if (data['success'] == true && context.mounted) {
      // Обновляем профиль для отображения новых счетчиков подписок
      ref.read(profileHeaderProvider(userId).notifier).refresh();
    } else if (context.mounted) {
      await _showErrorDialog(
        context,
        data['message']?.toString() ?? 'Не удалось выполнить действие',
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Ошибка: ${e.message}');
    }
  } catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Неизвестная ошибка: $e');
    }
  }
}

/// Обработчик скрытия/показа постов
Future<void> _handleHidePosts({
  required BuildContext context,
  required WidgetRef ref,
  required int userId,
  required int currentUserId,
  required bool arePostsHidden,
}) async {
  if (!context.mounted) return;

  final api = ref.read(apiServiceProvider);

  try {
    final data = await api.post(
      '/hide_user_content.php',
      body: {
        'hidden_user_id': userId.toString(),
        'action': arePostsHidden ? 'show' : 'hide',
        'content_type': 'post',
      },
      timeout: const Duration(seconds: 10),
    );

    if (data['success'] == true && context.mounted) {
      if (arePostsHidden) {
        // Показываем посты - обновляем ленту для загрузки постов пользователя
        await ref.read(lentaProvider(currentUserId).notifier).refresh();
      } else {
        // Скрываем посты - удаляем их из ленты
        ref.read(lentaProvider(currentUserId).notifier).removeUserContent(
          hiddenUserId: userId,
          contentType: 'post',
        );
      }
    } else if (context.mounted) {
      await _showErrorDialog(
        context,
        data['message']?.toString() ?? 'Не удалось выполнить действие',
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Ошибка: ${e.message}');
    }
  } catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Неизвестная ошибка: $e');
    }
  }
}

/// Обработчик скрытия/показа тренировок
Future<void> _handleHideActivities({
  required BuildContext context,
  required WidgetRef ref,
  required int userId,
  required int currentUserId,
  required bool areActivitiesHidden,
}) async {
  if (!context.mounted) return;

  final api = ref.read(apiServiceProvider);

  try {
    final data = await api.post(
      '/hide_user_content.php',
      body: {
        'hidden_user_id': userId.toString(),
        'action': areActivitiesHidden ? 'show' : 'hide',
        'content_type': 'activity',
      },
      timeout: const Duration(seconds: 10),
    );

    if (data['success'] == true && context.mounted) {
      if (areActivitiesHidden) {
        // Показываем тренировки - обновляем ленту для загрузки тренировок пользователя
        await ref.read(lentaProvider(currentUserId).notifier).refresh();
      } else {
        // Скрываем тренировки - удаляем их из ленты
        ref.read(lentaProvider(currentUserId).notifier).removeUserContent(
          hiddenUserId: userId,
          contentType: 'activity',
        );
      }
    } else if (context.mounted) {
      await _showErrorDialog(
        context,
        data['message']?.toString() ?? 'Не удалось выполнить действие',
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Ошибка: ${e.message}');
    }
  } catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Неизвестная ошибка: $e');
    }
  }
}

/// Обработчик блокировки/разблокировки
Future<void> _handleBlock({
  required BuildContext context,
  required WidgetRef ref,
  required int userId,
  required int currentUserId,
  required bool isBlocked,
}) async {
  if (!context.mounted) return;

  final api = ref.read(apiServiceProvider);

  try {
    final data = await api.post(
      '/toggle_block.php',
      body: {
        'blocked_user_id': userId.toString(),
        'action': isBlocked ? 'unblock' : 'block',
      },
      timeout: const Duration(seconds: 10),
    );

    if (data['success'] == true && context.mounted) {
      // Блокировка/разблокировка выполнена успешно
      // Остаемся на экране профиля
    } else if (context.mounted) {
      await _showErrorDialog(
        context,
        data['message']?.toString() ?? 'Не удалось выполнить действие',
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Ошибка: ${e.message}');
    }
  } catch (e) {
    if (context.mounted) {
      await _showErrorDialog(context, 'Неизвестная ошибка: $e');
    }
  }
}

/// Показ диалога с ошибкой
Future<void> _showErrorDialog(
  BuildContext context,
  String message,
) async {
  if (!context.mounted) return;

  await showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Ошибка'),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Ок'),
        ),
      ],
    ),
  );
}
