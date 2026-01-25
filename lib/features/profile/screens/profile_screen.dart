import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart'; // ← наш глобальный AppBar
import '../../../core/widgets/transparent_route.dart';
import '../../../core/widgets/more_menu_overlay.dart';
import '../../../features/complaint.dart';
import '../../../core/widgets/more_menu_hub.dart';
import '../providers/profile_header_provider.dart';
import '../providers/profile_header_state.dart';
import '../providers/user_photos_provider.dart';
import '../providers/user_clubs_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../providers/avatar_version_provider.dart';
import '../../../providers/services/api_provider.dart';
import '../../../core/services/api_service.dart'; // для ApiException
import '../../lenta/providers/lenta_provider.dart';
import '../../../core/widgets/avatar.dart';

// общие виджеты
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

// экран редактирования профиля
import 'edit_profile_screen.dart';

// экран подписок и подписчиков
import 'state/subscribe/communication_screen.dart';

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
  final GlobalKey<StatsTabState> _statsTabKey = GlobalKey<StatsTabState>();
  final GlobalKey<TrainingTabState> _trainingTabKey = GlobalKey<TrainingTabState>();
  final GlobalKey<GearTabState> _gearTabKey = GlobalKey<GearTabState>();
  late List<Widget?> _tabCache = List<Widget?>.filled(
    _tabTitles.length,
    null,
    growable: false,
  );
  int? _cachedUserId;
  DateTime? _lastProfileRefresh;
  static const _profileRefreshDebounce = Duration(seconds: 4);

  int _tab = 0;
  bool _wasRouteActive =
      false; // Отслеживание предыдущего состояния видимости маршрута
  bool _isScrolled =
      false; // Состояние скролла для раннего показа имени и изменения иконки
  double _titleOpacity =
      0; // Плавное появление имени пользователя в AppBar от 0 до 1
  double _headerOpacity =
      1; // Плавное исчезновение всей шапки (cover + карточка) при скролле
  double _circleOpacity =
      1; // Плавное исчезновение кружков в AppBar с самого начала скролла

  @override
  void initState() {
    super.initState();
    // ────────────────────────────────────────────────────────────────
    // Предкэшируем обложку, чтобы убрать декодирование в первый кадр
    // и снизить лаг при открытии профиля.
    // ────────────────────────────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await precacheImage(const AssetImage('assets/fon.jpg'), context);
    });
  }

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
    // Используем refresh() с антидребезгом, чтобы не спамить сетью
    // при быстром перелистывании вкладок.
    _refreshProfileDebounced(userId);
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

  // ────────────────────────────────────────────────────────────────────
  //                           КЭШИРОВАНИЕ ВКЛАДОК
  // ────────────────────────────────────────────────────────────────────

  /// Следим, что кэш соответствует текущему userId, иначе пересобираем его.
  void _ensureTabCacheForUser(int userId) {
    if (_cachedUserId == userId) return;
    _cachedUserId = userId;
    _tabCache = List<Widget?>.filled(_tabTitles.length, null, growable: false);
    _tabCache[0] = MainTab(key: _mainTabKey, userId: userId);
  }

  /// Возвращает вкладку из кэша или создаёт новую с сохранением.
  Widget _getTab(int index, int userId) {
    final cached = _tabCache[index];
    if (cached != null) return cached;
    final created = _createTab(index, userId);
    _tabCache[index] = created;
    return created;
  }

  /// Создаёт конкретную вкладку по индексу.
  Widget _createTab(int index, int userId) {
    switch (index) {
      case 0:
        return MainTab(key: _mainTabKey, userId: userId);
      case 1:
        return PhotosTab(userId: userId);
      case 2:
        return StatsTab(key: _statsTabKey, userId: userId);
      case 3:
        return TrainingTab(key: _trainingTabKey, userId: userId);
      case 4:
        return const RacesTab();
      case 5:
        return GearTab(key: _gearTabKey, userId: userId);
      case 6:
        return ClubsTab(userId: userId);
      case 7:
        return const AwardsTab();
      case 8:
        return const SkillsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onPageChanged(int i) {
    setState(() => _tab = i);

    // ────────────────────────────────────────────────────────────────────────
    // Обновление данных конкретной вкладки при переключении
    // ────────────────────────────────────────────────────────────────────────
    final userId = widget.userId ?? ref.read(currentUserIdProvider).value;
    if (userId == null) return;

    switch (i) {
      case 0: // Основное
        MainTab.checkCache(_mainTabKey);
        break;
      case 1: // Фото
        ref.read(userPhotosProvider(userId).notifier).refresh();
        break;
      case 2: // Статистика
        _statsTabKey.currentState?.refresh();
        break;
      case 3: // Тренировки
        _trainingTabKey.currentState?.refresh();
        break;
      case 4: // Соревнования - статические данные, не обновляем
        break;
      case 5: // Снаряжение
        _gearTabKey.currentState?.refresh();
        break;
      case 6: // Клубы
        ref.invalidate(userClubsProvider(userId));
        break;
      case 7: // Награды - статические данные, не обновляем
        break;
      case 8: // Навыки - статические данные, не обновляем
        break;
    }

    // ────────────────────────────────────────────────────────────────────────
    // Обновление данных профиля при переключении вкладок
    // Обновляем количество подписок и подписчиков при каждом переключении
    // ────────────────────────────────────────────────────────────────────────
    _refreshProfileDebounced(userId);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Формируем отображаемое имя для заголовка AppBar при скролле
  // ────────────────────────────────────────────────────────────────────────
  String? _buildDisplayName(ProfileHeaderState state) {
    final profile = state.profile;
    if (profile == null) return null;

    final fn = profile.firstName.trim();
    final ln = profile.lastName.trim();
    final full = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
    if (full.isNotEmpty) return full;
    return 'Профиль';
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
            appBar: const PaceAppBar(
              title: 'Профиль',
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
          title: 'Профиль',
          showBack: false,
          showBottomDivider: true,
        ),
        body: const Center(child: CupertinoActivityIndicator(radius: 10)),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Профиль',
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
    final avatarVersion = ref.watch(avatarVersionProvider);

    // ────────────────────────────────────────────────────────────────
    // Высоты шапки, рассчитанные один раз за build (без повторных MediaQuery).
    // ────────────────────────────────────────────────────────────────
    final headerMetrics = _headerMetrics(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final coverStackHeight = headerMetrics.coverHeight + topSafeArea;

    // ────────────────────────────────────────────────────────────────
    // Ленивая инициализация табов под конкретного пользователя, чтобы
    // не держать в кэше чужие вкладки и не пересоздавать MainTab.
    // ────────────────────────────────────────────────────────────────
    _ensureTabCacheForUser(userId);

    // ────────────────────────────────────────────────────────────────
    // 🔹 КЛЮЧ ДЛЯ МЕНЮ: нужен для привязки всплывающего меню в AppBar
    // ────────────────────────────────────────────────────────────────
    final menuKey = GlobalKey();

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Stack(
        children: [
          // ──────────────────────────────────────────────────────────────
          // Зафиксированная фоновая картинка, которая не скроллится
          // Высота блока = 180px + верхний SafeArea (status bar).
          // Это нужно, потому что SliverAppBar по умолчанию учитывает SafeArea
          // в своей высоте (primary=true), и без добавки появляется серая
          // «полоса» между обложкой и карточкой профиля.
          // Исчезает при скролле, когда появляется AppBar
          // ──────────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: coverStackHeight,
            child: Opacity(
              opacity: _headerOpacity,
              child: _FixedBackgroundCover(
                key: ValueKey('profile_bg_${userId}_v$avatarVersion'),
                userId: userId,
                backgroundUrl: _cacheBustUrl(
                  profileState.profile?.background,
                  avatarVersion,
                ),
                coverHeight: coverStackHeight,
              ),
            ),
          ),
          // ──────────────────────────────────────────────────────────────
          // Скроллируемый контент поверх фона
          // ──────────────────────────────────────────────────────────────
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // ──────────────────────────────────────────────────────────────
              // При любом вертикальном скролле прячем всплывающее меню
              // с тремя точками, чтобы оно не перекрывало контент.
              // ──────────────────────────────────────────────────────────────
              if (notification.depth == 0 &&
                  notification.metrics.axis == Axis.vertical) {
                MoreMenuHub.hide();
              }

              // Обрабатываем только вертикальные уведомления верхнего уровня,
              // чтобы свайпы PageView (горизонтальные) не трогали анимацию шапки.
              if (notification is ScrollUpdateNotification &&
                  notification.depth == 0 &&
                  notification.metrics.axis == Axis.vertical) {
                final threshold =
                    headerMetrics.threshold; // Порог коллапса шапки (кэш)

                // ──────────────────────────────────────────────────────────────
                // Плавно считаем прогресс схлопывания шапки, чтобы анимировать
                // появление имени в AppBar. AppBar начинает появляться после
                // достижения порога appBarStartThreshold.
                // Ограничиваем обновления, чтобы не триггерить лишние rebuild'ы
                // при минимальных изменениях.
                // ──────────────────────────────────────────────────────────────
                final rawProgress = notification.metrics.pixels / threshold;
                final newOpacity = rawProgress.clamp(0.0, 1.0).toDouble();
                final newIsScrolled = newOpacity >= 1;
                // AppBar начинает появляться после 60% скролла
                const appBarStartThreshold = 0.6;
                final appBarProgress = newOpacity > appBarStartThreshold
                    ? ((newOpacity - appBarStartThreshold) /
                              (1.0 - appBarStartThreshold))
                          .clamp(0.0, 1.0)
                    : 0.0;
                final newHeaderOpacity = (1 - appBarProgress).clamp(0.0, 1.0);
                // Кружки исчезают с самого начала скролла
                final newCircleOpacity = (1 - newOpacity).clamp(0.0, 1.0);
                // Имя появляется плавно, начиная с 30% прогресса скролла
                const titleStartThreshold = 0.9;
                final newTitleOpacity = newOpacity > titleStartThreshold
                    ? ((newOpacity - titleStartThreshold) /
                              (1.0 - titleStartThreshold))
                          .clamp(0.0, 1.0)
                    : 0.0;

                if (newIsScrolled != _isScrolled ||
                    newTitleOpacity != _titleOpacity ||
                    (newHeaderOpacity - _headerOpacity).abs() > 0.04 ||
                    (newCircleOpacity - _circleOpacity).abs() > 0.04) {
                  setState(() {
                    _isScrolled = newIsScrolled;
                    _titleOpacity = newTitleOpacity;
                    _headerOpacity = newHeaderOpacity;
                    _circleOpacity = newCircleOpacity;
                  });
                }
              }
              return false;
            },
            child: NestedScrollView(
              // ──────────────────────────────────────────────────────────────
              // Скроллируем шапку как в VK: cover + данные в flexibleSpace,
              // имя появляется в заголовке при прокрутке.
              // ──────────────────────────────────────────────────────────────
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                final coverHeight = headerMetrics.coverHeight;
                // Высота AppBar равна высоте фона, чтобы он был прозрачным над фоном
                final expandedHeight = coverHeight;
                final displayName = _buildDisplayName(profileState);

                // Используем прогресс скролла для плавного появления заголовка
                final titleOpacity = _titleOpacity.clamp(0.0, 1.0);
                final headerOpacity = _headerOpacity.clamp(0.0, 1.0);
                final isCollapsed = _isScrolled || innerBoxIsScrolled;

                return [
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    snap: false,
                    automaticallyImplyLeading: false,
                    expandedHeight: expandedHeight,
                    collapsedHeight: kToolbarHeight,
                    backgroundColor: AppColors.getSurfaceColor(
                      context,
                    ).withValues(alpha: 1 - headerOpacity),
                    elevation: 0,
                    scrolledUnderElevation: 1,
                    forceElevated: headerOpacity < 1,
                    leadingWidth: 46,
                    // ──────────────────────────────────────────────────────────────
                    // Показываем кнопку "назад" если:
                    // 1. Это не свой профиль ИЛИ
                    // 2. Это свой профиль, но можно вернуться назад (переход с другого экрана)
                    // Не показываем кнопку только если это свой профиль и это корневой экран
                    // (открыт из нижнего навигационного меню)
                    // ──────────────────────────────────────────────────────────────
                    leading: (isOwnProfile && !Navigator.canPop(context))
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _CircleAppIcon(
                              icon: CupertinoIcons.back,
                              isScrolled: isCollapsed,
                              fadeOpacity: _circleOpacity,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                    title: displayName != null && titleOpacity > 0
                        ? Opacity(
                            opacity: titleOpacity,
                            child: Text(
                              displayName,
                              style: AppTextStyles.h18w6.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          )
                        : null,
                    centerTitle: false,
                    actions: isOwnProfile
                        ? [
                            _CircleAppIcon(
                              icon: CupertinoIcons.ellipsis_vertical,
                              key: menuKey,
                              isScrolled: isCollapsed,
                              fadeOpacity: _circleOpacity,
                              onPressed: () {
                                _showOwnProfileMenu(
                                  context: context,
                                  ref: ref,
                                  userId: userId,
                                  menuKey: menuKey,
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                          ]
                        : [
                            _CircleAppIcon(
                              icon: CupertinoIcons.ellipsis_vertical,
                              key: menuKey,
                              isScrolled: isCollapsed,
                              fadeOpacity: _circleOpacity,
                              onPressed: () {
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
                    flexibleSpace: const SizedBox.shrink(),
                  ),
                  // ──────────────────────────────────────────────────────────────
                  // Блок с аватаром и информацией на белом фоне, который скроллится
                  // Частично налазит на фоновую картинку для визуального эффекта
                  // ──────────────────────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: Transform.translate(
                        offset: const Offset(0, -20),
                        child: _ProfileInfoCard(
                          userId: userId,
                          profileState: profileState,
                          coverHeight: coverHeight,
                          displayName: displayName ?? 'Профиль',
                        ),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabsHeaderDelegate(
                      pageController: _pageController,
                      tab: _tab,
                      items: _tabTitles,
                      onTap: _onTabTap,
                    ),
                  ),
                ];
              },
              body: GearPrefsScope(
                notifier: _gearPrefs,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  itemCount: _tabTitles.length,
                  // Ленивая сборка вкладок: создаём по требованию и кэшируем,
                  // чтобы не тратить кадры и память на невидимые экраны.
                  itemBuilder: (context, index) => _getTab(index, userId),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // МЕТРИКИ ШАПКИ (кэшируем расчёты размеров) + антидребезг refresh
  // ────────────────────────────────────────────────────────────────────

  _HeaderMetrics _headerMetrics(BuildContext context) =>
      _HeaderMetrics.fromContext(context);

  // ────────────────────────────────────────────────────────────────────
  // Добавляем cache-busting параметр к URL, чтобы сразу подхватывать
  // новую обложку после сохранения (пробиваем CDN и дисковый кэш).
  // ────────────────────────────────────────────────────────────────────
  String? _cacheBustUrl(String? url, int version) {
    if (url == null || url.isEmpty || version <= 0) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$version';
  }

  void _refreshProfileDebounced(int userId) {
    final now = DateTime.now();
    if (_lastProfileRefresh != null &&
        now.difference(_lastProfileRefresh!) < _profileRefreshDebounce) {
      return;
    }
    _lastProfileRefresh = now;
    ref.read(profileHeaderProvider(userId).notifier).refresh();
  }
}

// ────────────────────────────────────────────────────────────────────
//                           ЛОКАЛЬНЫЕ ВИДЖЕТЫ
// ────────────────────────────────────────────────────────────────────

// ────────────────────────────────────────────────────────────────────
//                           МОДЕЛЬ МЕТРИК ШАПКИ
// ────────────────────────────────────────────────────────────────────

class _HeaderMetrics {
  final double coverHeight;
  final double threshold;

  const _HeaderMetrics({required this.coverHeight, required this.threshold});

  factory _HeaderMetrics.fromContext(BuildContext context) {
    // Фиксированная высота обложки профиля
    const coverHeight = 150.0;
    // Порог для анимации появления имени в AppBar при скролле
    // Рассчитывается на основе высоты фона
    final threshold = coverHeight + 30;
    return _HeaderMetrics(coverHeight: coverHeight, threshold: threshold);
  }
}

/// Зафиксированная фоновая картинка профиля, которая не скроллится
class _FixedBackgroundCover extends StatelessWidget {
  final int userId;
  final String? backgroundUrl;
  final double coverHeight;

  const _FixedBackgroundCover({
    super.key,
    required this.userId,
    required this.backgroundUrl,
    required this.coverHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.95,
      child: backgroundUrl != null && backgroundUrl!.isNotEmpty
          ? CachedNetworkImage(
              // Используем backgroundUrl в ключе для принудительного
              // пересоздания виджета при изменении URL (включая cache-busting параметры)
              key: ValueKey('profile_bg_image_$backgroundUrl'),
              imageUrl: backgroundUrl!,
              width: double.infinity,
              height: coverHeight,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: double.infinity,
                height: coverHeight,
                color: AppColors.getBackgroundColor(context),
                child: Center(
                  child: CupertinoActivityIndicator(
                    radius: 10,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Image.asset(
                'assets/fon.jpg',
                width: double.infinity,
                height: coverHeight,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              // Показываем только индикатор загрузки или прозрачный контейнер,
              // пока данные профиля не загружены. Дефолтная картинка показывается
              // только при ошибке загрузки пользовательской картинки.
              width: double.infinity,
              height: coverHeight,
              color: AppColors.getBackgroundColor(context),
              child: Center(
                child: CupertinoActivityIndicator(
                  radius: 10,
                  color: AppColors.getIconSecondaryColor(context),
                ),
              ),
            ),
    );
  }
}

/// Блок с аватаром и информацией на белом фоне, который скроллится
class _ProfileInfoCard extends StatelessWidget {
  final int userId;
  final ProfileHeaderState profileState;
  final double coverHeight;
  final String displayName;

  const _ProfileInfoCard({
    required this.userId,
    required this.profileState,
    required this.coverHeight,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.getSurfaceColor(context);
    final profile = profileState.profile;

    // ──────────────────────────────────────────────────────────────
    // 🔹 ПРОВЕРКА: убеждаемся, что профиль соответствует текущему
    // userId, чтобы не показывать данные другого пользователя
    // ──────────────────────────────────────────────────────────────
    final isValidProfile = profile != null && profile.id == userId;

    final followers = isValidProfile ? (profile.followers ?? 0) : 0;
    final following = isValidProfile ? (profile.following ?? 0) : 0;
    final avatarUrl = isValidProfile ? profile.avatar : null;
    final city = isValidProfile ? profile.city : null;

    // ──────────────────────────────────────────────────────────────
    // ВАЖНО: не поднимаем карточку через Transform.translate.
    // Transform не меняет layout-высоту, из-за чего снизу остаётся
    // «пустота», через которую виден серый фон экрана.
    // ──────────────────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xll)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // ──────────────────────────────────────────────────────────────
          // Слой с информацией (определяет высоту блока)
          // ──────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 52, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                // Блок с именем и статистикой
                SizedBox(
                  height: 24,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h18w6,
                  ),
                ),
                // Город с иконкой location (отображается только если указан)
                if (city != null && city.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.placemark,
                        size: 14,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.twinBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _CountPill(
                            label: 'Подписки',
                          value: following,
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => CommunicationPrefsPage(
                                  startIndex: 0,
                                  userId: userId,
                                ),
                              ),
                            );
                          },
                        ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.twinBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _CountPill(
                            label: 'Подписчики',
                          value: followers,
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => CommunicationPrefsPage(
                                  startIndex: 1,
                                  userId: userId,
                                ),
                              ),
                            );
                          },
                        ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.twinBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _SearchPill(
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              CupertinoPageRoute(
                                builder: (_) => const SearchPrefsPage(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
                const SizedBox(height: 0),
              ],
            ),
          ),
          // ──────────────────────────────────────────────────────────────
          // Слой с аватаром (не влияет на высоту блока)
          // ──────────────────────────────────────────────────────────────
          Positioned(
            top: -52,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: isValidProfile
                      ? Avatar(
                          key: ValueKey(
                            'profile_avatar_${userId}_${avatarUrl ?? 'default'}',
                          ),
                          image: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? avatarUrl
                              : 'assets/avatar_0.png',
                          size: 100,
                          fadeIn: true,
                          gapless: true,
                        )
                      : Container(
                          width: 100,
                          height: 100,
                          color: AppColors.getBackgroundColor(context),
                          child: Center(
                            child: CupertinoActivityIndicator(
                              radius: 10,
                              color: AppColors.getIconSecondaryColor(context),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Делегат для закреплённой TabsBar под шапкой.
class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PageController pageController;
  final int tab;
  final List<String> items;
  final ValueChanged<int> onTap;

  _TabsHeaderDelegate({
    required this.pageController,
    required this.tab,
    required this.items,
    required this.onTap,
  });

  @override
  double get minExtent => 41 + _overlap() + 8; // 12 сверху + 12 снизу

  @override
  double get maxExtent => 41 + _overlap() + 8; // 12 сверху + 12 снизу

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.md),
            topRight: Radius.circular(AppRadius.md),
          ),
        ),
        padding: EdgeInsets.only(top: _overlap() + 4, bottom: 4),
        child: Column(
          children: [
            SizedBox(
              height: 40.5,
              child: AnimatedBuilder(
                animation: pageController,
                builder: (_, __) {
                  final page = pageController.hasClients
                      ? (pageController.page ?? tab.toDouble())
                      : tab.toDouble();
                  return TabsBar(
                    value: tab,
                    page: page,
                    items: items,
                    onChanged: onTap,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsHeaderDelegate oldDelegate) {
    return oldDelegate.tab != tab ||
        oldDelegate.items != items ||
        oldDelegate.pageController != pageController;
  }

  double _overlap() {
    // Небольшое перекрытие, чтобы Tabs визуально "поджимались" к шапке
    // (как в club_detail_screen).
    return 2;
  }
}

/// Блок «Поиск» с иконкой.
class _SearchPill extends StatelessWidget {
  final VoidCallback? onTap;

  const _SearchPill({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Поиск',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              CupertinoIcons.search,
              size: 16,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Небольшая «пилюля» со счётчиком (подписки/подписчики).
class _CountPill extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _CountPill({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12, 
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Полупрозрачная круглая кнопка-иконка для AppBar (как в клубах)
/// Плавно меняет стиль при скролле: кружок исчезает, иконка становится темной
class _CircleAppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isScrolled;
  final double fadeOpacity; // Плавное исчезновение фона при начале скролла
  const _CircleAppIcon({
    required this.icon,
    required this.isScrolled,
    required this.fadeOpacity,
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Цвет иконки: плавно переходим от светлого (на обложке) к темному
    // (в AppBar) с самого начала скролла
    final lightIcon = AppColors.getSurfaceColor(context);
    final darkIcon = AppColors.getIconPrimaryColor(context);
    final iconColor = Color.lerp(
      lightIcon,
      darkIcon,
      (1 - fadeOpacity.clamp(0.0, 1.0)),
    );

    // Цвет фона: темный с прозрачностью когда не скроллено, прозрачный когда скроллено
    final backgroundColor = isScrolled
        ? Colors.transparent
        : AppColors.getTextPrimaryColor(
            context,
          ).withValues(alpha: 0.5 * fadeOpacity.clamp(0.0, 1.0));

    return SizedBox(
      width: 38.0, // kAppBarTapTarget
      height: 38.0, // kAppBarTapTarget
      child: GestureDetector(
        onTap: onPressed ?? () {},
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

/// Показывает информационное сообщение снизу экрана в Cupertino стиле
/// Автоматически исчезает через указанное время
void _showInfoMessage(BuildContext context, String message) {
  if (!context.mounted) return;

  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, opacity, child) {
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - opacity)),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.h15w5.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  // Автоматически скрываем через 2 секунды
  Future.delayed(const Duration(seconds: 2), () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

/// Показывает всплывающее меню для действий со своим профилем
/// (редактирование профиля, поиск людей, настройки).
Future<void> _showOwnProfileMenu({
  required BuildContext context,
  required WidgetRef ref,
  required int userId,
  required GlobalKey menuKey,
}) async {
  // ──────────────────────────────────────────────
  // Формируем список пунктов меню для своего профиля
  // ──────────────────────────────────────────────
  final items = <MoreMenuItem>[
    // 1) Редактировать
    MoreMenuItem(
      text: 'Редактировать',
      icon: CupertinoIcons.pencil,
      iconColor: AppColors.brandPrimary,
      onTap: () async {
        MoreMenuHub.hide();
        if (!context.mounted) return;
        final changed = await Navigator.of(context).push<bool>(
          TransparentPageRoute(
            builder: (_) => EditProfileScreen(userId: userId),
          ),
        );
        if (changed == true && context.mounted) {
          // Обновляем профиль после редактирования
          ref.read(profileHeaderProvider(userId).notifier).reload();
        }
      },
    ),

    // 2) Поиск людей
    MoreMenuItem(
      text: 'Поиск людей',
      icon: CupertinoIcons.person_badge_plus,
      iconColor: AppColors.brandPrimary,
      onTap: () {
        MoreMenuHub.hide();
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (_) => const SearchPrefsPage(startIndex: 0),
          ),
        );
      },
    ),

    // 3) Настройки
    MoreMenuItem(
      text: 'Настройки',
      icon: CupertinoIcons.gear,
      iconColor: AppColors.brandPrimary,
      onTap: () {
        MoreMenuHub.hide();
        if (!context.mounted) return;
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(TransparentPageRoute(builder: (_) => const SettingsScreen()));
      },
    ),
  ];

  MoreMenuOverlay(anchorKey: menuKey, items: items).show(context);
}

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
  final textPrimaryColor = AppColors.getTextPrimaryColor(context);

  // Получаем статусы пользователя с сервера
  final api = ref.read(apiServiceProvider);
  bool isSubscribed = false;
  bool arePostsHidden = false;
  bool areActivitiesHidden = false;
  bool isBlocked = false;

  try {
    final statusData = await api.post(
      '/get_user_status.php',
      body: {'target_user_id': userId.toString()},
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
      textStyle: isSubscribed ? TextStyle(color: textPrimaryColor) : null,
      iconColor: isSubscribed ? AppColors.error : AppColors.brandPrimary,
      onTap: () async {
        MoreMenuHub.hide();
        _showInfoMessage(
          context,
          isSubscribed
              ? 'Вы отписались от пользователя'
              : 'Вы подписались на пользователя',
        );
        await _handleSubscribe(
          context: context,
          ref: ref,
          userId: userId,
          currentUserId: currentUserId,
          isSubscribed: isSubscribed,
        );
      },
    ),

    // 2) Скрыть посты / Показать посты (только для подписанных)
    if (isSubscribed)
      MoreMenuItem(
        text: arePostsHidden ? 'Показать посты' : 'Скрыть посты',
        icon: CupertinoIcons.text_bubble,
        iconColor: arePostsHidden ? AppColors.brandPrimary : AppColors.error,
        textStyle: arePostsHidden ? null : TextStyle(color: textPrimaryColor),
        onTap: () async {
          MoreMenuHub.hide();
          _showInfoMessage(
            context,
            arePostsHidden
                ? 'Посты пользователя показаны'
                : 'Посты пользователя скрыты',
          );
          await _handleHidePosts(
            context: context,
            ref: ref,
            userId: userId,
            currentUserId: currentUserId,
            arePostsHidden: arePostsHidden,
          );
        },
      ),

    // 3) Скрыть тренировки / Показать тренировки (только для подписанных)
    if (isSubscribed)
      MoreMenuItem(
        text: areActivitiesHidden ? 'Показать тренировки' : 'Скрыть тренировки',
        icon: CupertinoIcons.flame,
        iconColor: areActivitiesHidden
            ? AppColors.brandPrimary
            : AppColors.error,
        textStyle: areActivitiesHidden
            ? null
            : TextStyle(color: textPrimaryColor),
        onTap: () async {
          MoreMenuHub.hide();
          _showInfoMessage(
            context,
            areActivitiesHidden
                ? 'Тренировки пользователя показаны'
                : 'Тренировки пользователя скрыты',
          );
          await _handleHideActivities(
            context: context,
            ref: ref,
            userId: userId,
            currentUserId: currentUserId,
            areActivitiesHidden: areActivitiesHidden,
          );
        },
      ),

    // 4) Пожаловаться
    // ⚠️ ВНИМАНИЕ: Жалоба на пользователя требует отдельной реализации API
    // Сейчас передаются значения для компиляции, но функционал не будет работать
    MoreMenuItem(
      text: 'Пожаловаться',
      icon: CupertinoIcons.exclamationmark_circle,
      iconColor: AppColors.error,
      textStyle: TextStyle(color: textPrimaryColor),
      onTap: () {
        MoreMenuHub.hide();
        // TODO: Реализовать отдельный API endpoint для жалоб на пользователей
        // Пока передаем значения для компиляции, но это не будет работать
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(
          TransparentPageRoute(
            builder: (_) => ComplaintScreen(
              contentType: 'activity', // Временное значение
              contentId: userId, // Временное значение
            ),
          ),
        );
      },
    ),

    // 5) Заблокировать / Разблокировать
    MoreMenuItem(
      text: isBlocked ? 'Разблокировать' : 'Заблокировать',
      icon: CupertinoIcons.nosign,
      iconColor: isBlocked ? AppColors.brandPrimary : AppColors.error,
      textStyle: TextStyle(color: textPrimaryColor),
      onTap: () async {
        MoreMenuHub.hide();
        _showInfoMessage(
          context,
          isBlocked
              ? 'Пользователь разблокирован'
              : 'Пользователь заблокирован',
        );
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

  MoreMenuOverlay(anchorKey: menuKey, items: items).show(context);
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
        ref
            .read(lentaProvider(currentUserId).notifier)
            .removeUserContent(hiddenUserId: userId, contentType: 'post');
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
        ref
            .read(lentaProvider(currentUserId).notifier)
            .removeUserContent(hiddenUserId: userId, contentType: 'activity');
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
Future<void> _showErrorDialog(BuildContext context, String message) async {
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
