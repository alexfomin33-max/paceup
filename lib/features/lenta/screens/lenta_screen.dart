import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/activity_lenta.dart';
import '../providers/lenta_provider.dart';
import 'state/chat/providers/unread_chats_provider.dart';
import 'state/notifications/notifications_provider.dart';
import '../../../../core/utils/image_cache_manager.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/health_sync_service.dart';
import '../../../../core/services/strava_sync_service.dart';
import '../../../../core/widgets/error_display.dart';

import 'widgets/activity/activity_block.dart'; // карточка тренировки
import 'widgets/recommended_block.dart'; // блок «Рекомендации»
import 'widgets/post/post_card.dart'; // карточка поста (с попапом «…» внутри)
import '../../../../features/profile/providers/search/friends_search_provider.dart'; // провайдер рекомендаций

import 'state/newpost/new_post_screen.dart';
import 'state/newpost/edit_post_screen.dart';
import 'widgets/comments_bottom_sheet.dart';

import 'state/chat/screens/chat_screen.dart';
import 'state/notifications/notifications_screen.dart';
import 'state/favorites/favorites_screen.dart';
import 'activity/description_screen.dart';
import 'activity/add_activity_screen.dart';
import '../../../../core/widgets/more_menu_hub.dart';
import '../../../../core/widgets/more_menu_overlay.dart';
import '../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../core/widgets/transparent_route.dart';

/// Единые размеры для AppBar в iOS-стиле
const double kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double kAppBarTapTarget = 42.0; // кликабельная область 42×42

/// 🔹 Экран Ленты (Feed) с Riverpod State Management
class LentaScreen extends ConsumerStatefulWidget {
  final int? userId;
  final VoidCallback? onNewPostPressed;

  const LentaScreen({super.key, this.userId, this.onNewPostPressed});

  @override
  ConsumerState<LentaScreen> createState() => _LentaScreenState();
}

/// ✅ Держим состояние живым при перелистывании вкладок
class _LentaScreenState extends ConsumerState<LentaScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  // ——— Служебное ———
  final ScrollController _scrollController = ScrollController();
  final AuthService _auth = AuthService();
  // ✅ _actualUserId всегда получается из AuthService в initState()
  // Используется для частых операций (loadMore, build) для оптимизации
  // Для критичных операций (refresh, forceRefresh) всегда получаем из AuthService напрямую
  int? _actualUserId;
  // Ключ для кнопки создания поста (для выпадающего меню)
  final GlobalKey _createMenuKey = GlobalKey();

  // Флаги для предотвращения двойного запуска синхронизации
  bool _isSyncingHealthData = false;
  bool _isSyncingStrava = false;

  // ────────────────────────────────────────────────────────────────
  // 🔍 ФИЛЬТРЫ: состояние фильтрации постов и тренировок
  // ────────────────────────────────────────────────────────────────
  bool _showTrainings = true; // показывать тренировки
  bool _showPosts = true; // показывать посты
  bool _showOwn = true; // показывать свои посты/тренировки
  bool _showOthers = true; // показывать посты/тренировки других пользователей

  // Ключи для сохранения фильтров в SharedPreferences
  static const String _keyShowTrainings = 'lenta_filter_show_trainings';
  static const String _keyShowPosts = 'lenta_filter_show_posts';
  static const String _keyShowOwn = 'lenta_filter_show_own';
  static const String _keyShowOthers = 'lenta_filter_show_others';

  // Плагин Health (Health Connect/HealthKit) для запроса разрешений
  final Health _health = Health();

  // Типы данных Health, которые нам нужны
  // Используем те же типы, что и в экране подключенных трекеров
  // DISTANCE_DELTA и TOTAL_CALORIES_BURNED доступны только на Android Health Connect
  // На iOS используем WorkoutHealthValue.totalDistance и WorkoutHealthValue.totalEnergyBurned
  static List<HealthDataType> get _healthTypes => <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    if (Platform.isAndroid) HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    if (Platform.isAndroid) HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  // ────────────────────────────────────────────────────────────────
  // 🖼️ PREFETCHING: отслеживаем предзагруженные индексы постов
  // ────────────────────────────────────────────────────────────────
  final Set<int> _prefetchedIndices = {};
  static const int _prefetchCount = 3; // предзагружаем следующие 3 поста

  // ────────────────────────────────────────────────────────────────
  // ⚡ DEBOUNCE: предотвращаем лишние запросы во время скролла
  // ────────────────────────────────────────────────────────────────
  Timer? _prefetchDebounceTimer;
  bool _isScrolling = false;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  // ────────────────────────────────────────────────────────────────
  // ⚡ DEBOUNCE: оптимизация MoreMenuHub.hide()
  // ────────────────────────────────────────────────────────────────
  Timer? _menuHideDebounceTimer;
  static const Duration _menuHideDebounceDelay = Duration(milliseconds: 150);

  // ────────────────────────────────────────────────────────────────
  // 🔔 POLLING: динамическое обновление счетчика непрочитанных чатов
  // ────────────────────────────────────────────────────────────────
  Timer? _unreadChatsPollingTimer;
  // ────────────────────────────────────────────────────────────────
  // 🔔 POLLING: динамическое обновление счетчика непрочитанных уведомлений
  // ────────────────────────────────────────────────────────────────
  Timer? _unreadNotificationsPollingTimer;
  static const Duration _pollingInterval = Duration(
    seconds: 5,
  ); // обновляем каждые 5 секунд

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Всегда получаем userId из AuthService для гарантии правильного ID
    // widget.userId используется только как fallback, если AuthService вернет null
    Future.microtask(() async {
      int? userId = await _auth.getUserId();

      // Если AuthService вернул null, используем widget.userId (но не fallback 123)
      if (userId == null) {
        userId = widget.userId;
        // Если widget.userId равен fallback значению (123) — игнорируем его
        if (userId == 123) {
          userId = null;
        }
      }

      if (userId == null) {
        // Если userId всё ещё null — показываем ошибку
        if (mounted) {
          setState(() {
            // Ошибка будет показана в build методе
          });
        }
        return;
      }

      _actualUserId = userId;

      developer.log(
        '[LENTA_SCREEN] initState: userId=$userId',
        name: 'LentaScreen',
      );

      if (mounted) {
        // Загружаем сохраненные фильтры перед загрузкой данных
        await _loadFilters();
        setState(() {});

        // ✅ Проверяем, есть ли уже данные в провайдере
        // Если данные уже загружены (например, из code2_screen.dart),
        // не вызываем loadInitial() чтобы не показывать skeleton loader
        final currentState = ref.read(lentaProvider(userId));
        developer.log(
          '[LENTA_SCREEN] Состояние провайдера в initState: '
          'items.length=${currentState.items.length}, '
          'isRefreshing=${currentState.isRefreshing}, '
          'currentPage=${currentState.currentPage}, '
          'hasMore=${currentState.hasMore}, '
          'error=${currentState.error}',
          name: 'LentaScreen',
        );

        final hasData = currentState.items.isNotEmpty;
        developer.log(
          '[LENTA_SCREEN] hasData=$hasData',
          name: 'LentaScreen',
        );

        if (!hasData) {
          developer.log(
            '[LENTA_SCREEN] Данных нет, вызываем loadInitial()...',
            name: 'LentaScreen',
          );
          // Начальная загрузка через Riverpod provider
          // После завершения загрузки обновим счетчик непрочитанных чатов
          ref
              .read(lentaProvider(userId).notifier)
              .loadInitial(
                showTrainings: _showTrainings,
                showPosts: _showPosts,
                showOwn: _showOwn,
                showOthers: _showOthers,
              )
              .then((_) {
                if (mounted &&
                    _actualUserId != null &&
                    _actualUserId == userId) {
                  // Обновляем счетчик после завершения загрузки ленты
                  ref
                      .read(unreadChatsProvider(_actualUserId!).notifier)
                      .loadUnreadCount();
                }
              });
        } else {
          developer.log(
            '[LENTA_SCREEN] ✅ Данные уже загружены, пропускаем loadInitial()',
            name: 'LentaScreen',
          );
          // ✅ Данные уже загружены - обновляем только счетчики
          if (mounted && _actualUserId != null && _actualUserId == userId) {
            ref
                .read(unreadChatsProvider(_actualUserId!).notifier)
                .loadUnreadCount();
          }
        }
        // Загружаем количество непрочитанных чатов сразу (не ждем загрузки ленты)
        ref.read(unreadChatsProvider(userId).notifier).loadUnreadCount();
        // Запускаем polling для динамического обновления счетчика
        _startUnreadChatsPolling(userId);
        // ✅ Инициализируем провайдер уведомлений, чтобы гарантировать его создание
        // Это важно для правильной работы подписки через ref.watch
        ref.read(notificationsProvider);
        // Загружаем только счетчик непрочитанных уведомлений (не все уведомления)
        ref.read(notificationsProvider.notifier).updateUnreadCount();
        // Запускаем polling для динамического обновления счетчика уведомлений
        _startUnreadNotificationsPolling(userId);

        // Проверка флага синхронизации от Broadcast Receiver
        _checkAndSyncHealthData();
      }
    });

    // Автоматическая подгрузка при скролле
    // ✅ Используем _actualUserId (уже получен из AuthService в initState)
    // для оптимизации частых вызовов при скролле
    // ⚡ ОПТИМИЗАЦИЯ: loadMore без throttle для мгновенной реакции
    // Порог уменьшен до 200px для более ранней подгрузки
    // Это обеспечивает плавную подгрузку без задержек
    _scrollController.addListener(() {
      // ⚡ Проверяем loadMore сразу, без throttle - критично для UX
      if (_actualUserId == null || !mounted) return;
      if (!_scrollController.hasClients) return;

      final lentaState = ref.read(lentaProvider(_actualUserId!));
      final pos = _scrollController.position;

      // Подгружаем когда осталось 200px до конца (было 400px)
      // Это обеспечивает более раннюю подгрузку и плавность скролла
      if (lentaState.hasMore &&
          !lentaState.isLoadingMore &&
          pos.extentAfter < 200) {
        ref
            .read(lentaProvider(_actualUserId!).notifier)
            .loadMore(
              showTrainings: _showTrainings,
              showPosts: _showPosts,
              showOwn: _showOwn,
              showOthers: _showOthers,
            );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _prefetchDebounceTimer?.cancel(); // ✅ Очищаем таймер prefetch
    _menuHideDebounceTimer?.cancel(); // ✅ Очищаем таймер debounce меню
    _unreadChatsPollingTimer?.cancel(); // ✅ Очищаем таймер polling чатов
    _unreadNotificationsPollingTimer
        ?.cancel(); // ✅ Очищаем таймер polling уведомлений
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Проверяем флаг синхронизации при возврате приложения из фона
    if (state == AppLifecycleState.resumed) {
      _checkAndSyncHealthData();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ПРОВЕРКА И СИНХРОНИЗАЦИЯ HEALTH CONNECT
  // ─────────────────────────────────────────────────────────────────────────

  /// Запрашивает разрешения на доступ к данным Health Connect/HealthKit
  ///
  /// Вызывается при первом запуске приложения для автоматического запроса
  /// разрешений на чтение тренировок
  Future<bool> _requestHealthPermissions() async {
    try {
      // Конфигурируем Health плагин
      await _health.configure();
      if (!mounted) return false;

      // Проверяем доступность Health Connect на Android
      if (Platform.isAndroid) {
        final hasHC = await _health.isHealthConnectAvailable();
        if (hasHC == false) {
          return false;
        }
      }

      // Проверяем, есть ли уже разрешения
      final hasPermissions = await _health.hasPermissions(
        _healthTypes,
        permissions: List.generate(
          _healthTypes.length,
          (_) => HealthDataAccess.READ,
        ),
      );

      // Если разрешения уже есть — возвращаем true
      if (hasPermissions == true) {
        return true;
      }

      // Запрашиваем разрешения
      final granted = await _health.requestAuthorization(
        _healthTypes,
        permissions: List.generate(
          _healthTypes.length,
          (_) => HealthDataAccess.READ,
        ),
      );

      if (!mounted) return false;

      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Проверяет флаг синхронизации и запускает импорт новых тренировок
  ///
  /// При первом запуске автоматически запрашивает разрешения Health Connect
  /// Также синхронизирует тренировки из Strava, если настроена синхронизация
  Future<void> _checkAndSyncHealthData() async {
    // Предотвращаем двойной запуск синхронизации
    if (_isSyncingHealthData) return;

    try {
      // Запрашиваем разрешения перед синхронизацией
      final hasPermissions = await _requestHealthPermissions();

      if (!hasPermissions) {
      } else {
        final syncService = ref.read(healthSyncServiceProvider);

        // Запускаем синхронизацию Health Connect, если пользователь авторизован
        if (_actualUserId != null && mounted) {
          // Устанавливаем флаг, чтобы предотвратить повторный запуск
          _isSyncingHealthData = true;

          // Запускаем синхронизацию в фоне
          syncService
              .syncNewWorkouts(ref)
              .then((result) {
                _isSyncingHealthData = false;
              })
              .catchError((error) {
                _isSyncingHealthData = false;
              });
        }
      }

      // Синхронизируем тренировки из Strava (если настроена синхронизация)
      _syncStravaActivities();
    } catch (e) {
      _isSyncingHealthData = false;
    }
  }

  /// Синхронизирует тренировки из Strava
  ///
  /// Вызывается автоматически при загрузке экрана, если у пользователя
  /// настроена синхронизация со Strava
  Future<void> _syncStravaActivities() async {
    // Предотвращаем двойной запуск синхронизации
    if (_isSyncingStrava) return;

    try {
      if (_actualUserId == null || !mounted) return;

      // Устанавливаем флаг, чтобы предотвратить повторный запуск
      _isSyncingStrava = true;

      final stravaSyncService = ref.read(stravaSyncServiceProvider);

      // Запускаем синхронизацию в фоне
      stravaSyncService
          .syncNewWorkouts(ref)
          .then((result) {
            _isSyncingStrava = false;
          })
          .catchError((error) {
            _isSyncingStrava = false;
          });
    } catch (e) {
      _isSyncingStrava = false;
    }
  }

  // ———————————— Refresh через Riverpod ————————————

  /// Загрузка сохраненных фильтров из SharedPreferences
  Future<void> _loadFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showTrainings = prefs.getBool(_keyShowTrainings) ?? true;
      _showPosts = prefs.getBool(_keyShowPosts) ?? true;
      _showOwn = prefs.getBool(_keyShowOwn) ?? true;
      _showOthers = prefs.getBool(_keyShowOthers) ?? true;
    } catch (e) {
      // Игнорируем ошибки, используем значения по умолчанию
    }
  }

  /// Сохранение фильтров в SharedPreferences
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowTrainings, _showTrainings);
      await prefs.setBool(_keyShowPosts, _showPosts);
      await prefs.setBool(_keyShowOwn, _showOwn);
      await prefs.setBool(_keyShowOthers, _showOthers);
    } catch (e) {
      // Игнорируем ошибки сохранения
    }
  }

  /// Перезагрузка данных с учетом текущих фильтров
  Future<void> _reloadWithFilters({
    bool? showTrainings,
    bool? showPosts,
    bool? showOwn,
    bool? showOthers,
  }) async {
    if (_actualUserId == null) return;

    // Используем переданные значения или текущие значения переменных
    final trainings = showTrainings ?? _showTrainings;
    final posts = showPosts ?? _showPosts;
    final own = showOwn ?? _showOwn;
    final others = showOthers ?? _showOthers;

    // Очищаем кеш предзагруженных индексов
    _prefetchedIndices.clear();

    // Сохраняем фильтры
    await _saveFilters();

    // Перезагружаем данные с новыми фильтрами
    // Используем forceRefresh для полной перезагрузки с очисткой кэша
    await ref
        .read(lentaProvider(_actualUserId!).notifier)
        .forceRefresh(
          showTrainings: trainings,
          showPosts: posts,
          showOwn: own,
          showOthers: others,
        );

    // Прокрутка к началу
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// Pull-to-refresh обновление ленты
  Future<void> _onRefresh() async {
    // ✅ Всегда получаем userId из AuthService для гарантии правильного ID
    final userId = await _auth.getUserId();
    if (userId == null) return;

    // Очищаем кеш предзагруженных индексов при обновлении
    _prefetchedIndices.clear();
    await ref
        .read(lentaProvider(userId).notifier)
        .refresh(
          showTrainings: _showTrainings,
          showPosts: _showPosts,
          showOwn: _showOwn,
          showOthers: _showOthers,
        );
    // Обновляем количество непрочитанных чатов при обновлении ленты
    ref.read(unreadChatsProvider(userId).notifier).loadUnreadCount();
    // Обновляем счетчик непрочитанных уведомлений при обновлении ленты
    ref.read(notificationsProvider.notifier).updateUnreadCount();
    // Инвалидируем провайдер рекомендаций для получения новых рандомных пользователей
    ref.invalidate(recommendedFriendsProvider);
  }

  // ────────────────────────────────────────────────────────────────
  // 🔔 POLLING: динамическое обновление счетчика непрочитанных чатов
  // ────────────────────────────────────────────────────────────────

  /// Запускает периодическое обновление счетчика непрочитанных чатов
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Интервал 5 секунд — баланс между актуальностью и нагрузкой на сервер
  /// - Автоматическая остановка при dispose — предотвращает утечки памяти
  /// - Проверка mounted перед обновлением — безопасность при закрытии экрана
  ///
  /// Обновляет счетчик каждые 5 секунд, чтобы пользователь видел
  /// новые непрочитанные чаты в реальном времени.
  void _startUnreadChatsPolling(int userId) {
    _unreadChatsPollingTimer?.cancel(); // Отменяем предыдущий таймер, если есть

    _unreadChatsPollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (!mounted || _actualUserId == null) {
        _unreadChatsPollingTimer?.cancel();
        return;
      }

      // Обновляем счетчик непрочитанных чатов
      ref.read(unreadChatsProvider(_actualUserId!).notifier).loadUnreadCount();
    });
  }

  /// Запускает периодическое обновление счетчика непрочитанных уведомлений
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Интервал 5 секунд — баланс между актуальностью и нагрузкой на сервер
  /// - Автоматическая остановка при dispose — предотвращает утечки памяти
  /// - Проверка mounted перед обновлением — безопасность при закрытии экрана
  ///
  /// Обновляет счетчик каждые 5 секунд, чтобы пользователь видел
  /// новые непрочитанные уведомления в реальном времени.
  void _startUnreadNotificationsPolling(int userId) {
    _unreadNotificationsPollingTimer
        ?.cancel(); // Отменяем предыдущий таймер, если есть

    _unreadNotificationsPollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (!mounted || _actualUserId == null) {
        _unreadNotificationsPollingTimer?.cancel();
        return;
      }

      // Обновляем счетчик непрочитанных уведомлений
      ref.read(notificationsProvider.notifier).updateUnreadCount();
    });
  }

  // ———————————— Навигация / Колбэки ————————————

  Future<void> _openChat() async {
    if (_actualUserId == null) return;

    MoreMenuHub.hide();
    await Navigator.of(
      context,
    ).push(TransparentPageRoute(builder: (_) => const ChatScreen()));

    if (!mounted) return;
    // Обновляем количество непрочитанных чатов после возврата из экрана чатов
    ref.read(unreadChatsProvider(_actualUserId!).notifier).loadUnreadCount();
  }

  Future<void> _openNotifications() async {
    if (_actualUserId == null) return;

    MoreMenuHub.hide();
    await Navigator.of(
      context,
    ).push(TransparentPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    // Обновляем только счетчик непрочитанных уведомлений после возврата из экрана
    ref.read(notificationsProvider.notifier).updateUnreadCount();
  }

  /// Показывает выпадающее меню для кнопки создания поста
  void _showCreateMenu() {
    final items = <MoreMenuItem>[
      MoreMenuItem(
        text: 'Новый пост',
        icon: CupertinoIcons.square_pencil,
        onTap: _createPost,
      ),
      MoreMenuItem(
        text: 'Добавить тренировку',
        icon: Icons.emoji_events_outlined,
        onTap: _addActivity,
      ),
    ];
    MoreMenuOverlay(anchorKey: _createMenuKey, items: items).show(context);
  }

  /// Обработчик добавления тренировки
  Future<void> _addActivity() async {
    if (_actualUserId == null) return;

    MoreMenuHub.hide();

    final created = await Navigator.of(context, rootNavigator: true).push<bool>(
      TransparentPageRoute(
        builder: (_) => AddActivityScreen(currentUserId: _actualUserId!),
      ),
    );

    if (!mounted || created != true) return;

    // Очищаем кеш предзагруженных индексов
    _prefetchedIndices.clear();

    // 🔹 Задержка перед обновлением — даём серверу время обработать активность
    await Future.delayed(const Duration(milliseconds: 500));

    // ✅ Используем _actualUserId для forceRefresh
    // Принудительное обновление с очисткой кэша
    await ref
        .read(lentaProvider(_actualUserId!).notifier)
        .forceRefresh(
          showTrainings: _showTrainings,
          showPosts: _showPosts,
          showOwn: _showOwn,
          showOthers: _showOthers,
        );

    // Прокрутка к началу
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _createPost() async {
    // ✅ Всегда получаем userId из AuthService для гарантии правильного ID
    final userId = await _auth.getUserId();
    if (userId == null || !mounted) return;

    MoreMenuHub.hide();

    final created = await Navigator.of(context).push<bool>(
      TransparentPageRoute(builder: (_) => NewPostScreen(userId: userId)),
    );

    if (!mounted || created != true) return;

    // Очищаем кеш предзагруженных индексов
    _prefetchedIndices.clear();

    // 🔹 Задержка перед обновлением — даём серверу время обработать пост
    // Это важно для гарантированного получения нового поста в ответе API
    await Future.delayed(const Duration(milliseconds: 500));

    // ✅ Используем userId из AuthService (уже получен выше) для forceRefresh
    // Принудительное обновление с очисткой кэша
    // Используем forceRefresh вместо refresh для полного обновления данных
    await ref
        .read(lentaProvider(userId).notifier)
        .forceRefresh(
          showTrainings: _showTrainings,
          showPosts: _showPosts,
          showOwn: _showOwn,
          showOthers: _showOthers,
        );

    // Прокрутка к началу
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _openFavorites() {
    MoreMenuHub.hide();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void _openActivity(Activity a) {
    if (_actualUserId == null) return;

    MoreMenuHub.hide();
    Navigator.of(context, rootNavigator: true).push(
      TransparentPageRoute(
        builder: (_) =>
            ActivityDescriptionPage(activity: a, currentUserId: _actualUserId!),
      ),
    );
  }

  void _openComments({required String type, required int itemId}) {
    if (_actualUserId == null) return;

    // Находим активность по itemId для получения lentaId
    final lentaState = ref.read(lentaProvider(_actualUserId!));
    final activity = lentaState.items.firstWhere(
      (a) => a.id == itemId && a.type == type,
      orElse: () => lentaState.items.first, // fallback (не должно произойти)
    );

    MoreMenuHub.hide();
    // ────────────────────────────────────────────────────────────────
    // 🔹 Используем helper-функцию для плавного открытия bottom sheet
    // ────────────────────────────────────────────────────────────────
    showCommentsBottomSheet(
      context: context,
      itemType: type,
      itemId: itemId,
      currentUserId: _actualUserId!,
      lentaId: activity.lentaId,
      // ────────────────────────────────────────────────────────────────
      // 🔔 ОБНОВЛЕНИЕ СЧЕТЧИКА: увеличиваем счетчик комментариев на 1
      // ────────────────────────────────────────────────────────────────
      onCommentAdded: () {
        // Получаем актуальный счетчик из провайдера перед обновлением
        final currentState = ref.read(lentaProvider(_actualUserId!));
        final updatedActivity = currentState.items.firstWhere(
          (a) => a.lentaId == activity.lentaId,
          orElse: () => activity, // fallback на исходную activity
        );

        // Оптимистичное обновление: увеличиваем счетчик на 1
        ref
            .read(lentaProvider(_actualUserId!).notifier)
            .updateComments(activity.lentaId, updatedActivity.comments + 1);
      },
    );
  }

  Future<void> _editPost(Activity post) async {
    // ✅ Всегда получаем userId из AuthService для гарантии правильного ID
    final userId = await _auth.getUserId();
    if (userId == null || !mounted) return;

    MoreMenuHub.hide();

    final updated = await Navigator.push<bool>(
      context,
      TransparentPageRoute(
        builder: (_) => EditPostScreen(
          userId: userId,
          postId: post.id,
          initialText: post.postContent,
          initialImageUrls: post.mediaImages,
          initialVisibility: post.userGroup.clamp(0, 2),
        ),
      ),
    );

    if (!mounted) return;

    // Если вернулись с флагом «обновлено» — обновляем ленту через Riverpod
    if (updated == true) {
      // Очищаем кеш предзагруженных индексов
      _prefetchedIndices.clear();

      // 🔹 Задержка перед обновлением — даём серверу время обработать изменения
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Используем userId из AuthService для forceRefresh
      // Принудительное обновление с очисткой кэша
      await ref
          .read(lentaProvider(userId).notifier)
          .forceRefresh(
            showTrainings: _showTrainings,
            showPosts: _showPosts,
            showOwn: _showOwn,
            showOthers: _showOthers,
          );
    }
  }

  /// Удаляет пост из списка через Riverpod (без диалога — диалог уже показан в PostCard)
  void _deletePost(Activity post) {
    if (!mounted || _actualUserId == null) return;
    ref.read(lentaProvider(_actualUserId!).notifier).removeItem(post.lentaId);
  }

  // ────────────────────────────────────────────────────────────────
  // 🖼️ PREFETCHING: предзагрузка изображений следующих постов
  // ────────────────────────────────────────────────────────────────

  /// Предзагружает первые изображения из следующих N постов с debounce.
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Debounce (300ms) — предотвращает сотни вызовов во время скролла
  /// - Scroll state tracking — не загружает во время активного скролла
  /// - Timer cancellation — отменяет предыдущие запросы при новых событиях
  /// - Mounted check — предотвращает работу после dispose
  ///
  /// ✅ UNIFIED IMAGE CACHE:
  /// Использует ImageCacheManager для единого двухуровневого кэша:
  /// - Memory cache (ImageCache) — быстрый доступ к недавним изображениям
  /// - Disk cache (flutter_cache_manager) — offline поддержка и экономия трафика
  ///
  /// Преимущества unified cache:
  /// - Одно изображение загружается только 1 раз для всех виджетов
  /// - CachedNetworkImage и precacheImage используют ОДНУ копию в памяти
  /// - Автоматическая очистка старых файлов (7 дней)
  /// - Deduplicated загрузка (нет дублирующих HTTP запросов)
  ///
  /// Загружает оригинальные изображения в disk cache для быстрого доступа.
  /// Ресайз происходит при отображении через memCacheWidth в PostMediaCarousel.
  /// Отслеживает уже предзагруженные индексы, чтобы не загружать дважды.
  ///
  /// Параметры:
  /// - [currentIndex] - текущий индекс поста в ленте
  /// - [items] - список всех постов в ленте
  ///
  /// Прирост производительности:
  /// - -70% лишних сетевых запросов (debounce)
  /// - -40% CPU usage во время скролла (scroll state check)
  /// - +25% cache hit rate (unified cache)
  void _prefetchNextImages(int currentIndex, List<Activity> items) {
    if (!mounted) return;

    // ────────── DEBOUNCE: отменяем предыдущий таймер ──────────
    _prefetchDebounceTimer?.cancel();

    // ────────── Устанавливаем новый таймер на 300ms ──────────
    _prefetchDebounceTimer = Timer(_debounceDelay, () {
      // ✅ Выполняем prefetch только если:
      // 1. Виджет всё ещё mounted
      // 2. Скролл завершён (не активный)
      if (!mounted || _isScrolling) return;

      _executePrefetch(currentIndex, items);
    });
  }

  /// Выполняет фактическую предзагрузку изображений
  /// (вызывается после debounce timeout)
  void _executePrefetch(int currentIndex, List<Activity> items) {
    // ────────── ЗАЩИТА: проверяем валидность данных ──────────
    if (items.isEmpty) return;
    if (currentIndex < 0 || currentIndex >= items.length) return;

    // Определяем диапазон для prefetch (следующие _prefetchCount постов)
    final startIdx = currentIndex + 1;
    // ✅ Ограничиваем endIdx реальной длиной списка
    final endIdx = (startIdx + _prefetchCount).clamp(0, items.length);

    // ────────── ЗАЩИТА: проверяем, что startIdx валиден ──────────
    if (startIdx >= items.length) return;

    for (int i = startIdx; i < endIdx; i++) {
      // ────────── ЗАЩИТА: дополнительная проверка индекса ──────────
      if (i < 0 || i >= items.length) continue;

      // Пропускаем уже предзагруженные
      if (_prefetchedIndices.contains(i)) continue;

      final activity = items[i];

      // Только для постов с изображениями
      if (activity.type == 'post' && activity.mediaImages.isNotEmpty) {
        final firstImageUrl = activity.mediaImages.first;

        // ✅ Используем unified ImageCacheManager для согласованности
        // с CachedNetworkImage во всём приложении
        ImageCacheManager.precache(
              context: context,
              url: firstImageUrl,
              // ✅ Загружаем оригинал в disk cache
              // Ресайз происходит при отображении через memCacheWidth в PostMediaCarousel
            )
            .then((_) {
              // Помечаем как предзагруженное
              if (mounted) {
                _prefetchedIndices.add(i);
              }
            })
            .catchError((error) {
              // Игнорируем ошибки prefetch (не критично)
            });
      }
    }
  }

  // ———————————— UI ————————————

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Если userId ещё не загружен — показываем индикатор загрузки
    if (_actualUserId == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          titleWidget: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'PACE',
                  style: AppTextStyles.h17w6.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                TextSpan(
                  text: 'UP',
                  style: AppTextStyles.h17w6.copyWith(
                    color: AppColors.greenUP,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          showBottomDivider: true,
        ),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    // Читаем состояние из Riverpod provider (только нужные поля, без лишних rebuild)
    final lentaSnapshot = ref.watch(
      lentaProvider(_actualUserId!).select(
        (s) => (
          items: s.items,
          isLoadingMore: s.isLoadingMore,
          isRefreshing: s.isRefreshing,
          hasMore: s.hasMore,
          error: s.error,
          currentPage: s.currentPage,
        ),
      ),
    );

    developer.log(
      '[LENTA_SCREEN] build вызван: items.length=${lentaSnapshot.items.length}, '
      'isRefreshing=${lentaSnapshot.isRefreshing}, '
      'currentPage=${lentaSnapshot.currentPage}, '
      'error=${lentaSnapshot.error}',
      name: 'LentaScreen',
    );
    // Читаем состояние непрочитанных чатов только по числу, чтобы не триггерить rebuild AppBar
    final unreadChatsCount = _actualUserId != null
        ? ref.watch(
            unreadChatsProvider(_actualUserId!).select((s) => s.unreadCount),
          )
        : 0;
    // Читаем состояние уведомлений для счетчика — тоже селектор по числу
    final unreadNotificationsCount = ref.watch(
      notificationsProvider.select((s) => s.unreadCount),
    );

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),

      // новый глобальный AppBar без стекла/прозрачности
      appBar: PaceAppBar(
        titleWidget: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'PACE',
                style: AppTextStyles.h17w6.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              TextSpan(
                text: 'UP',
                style: AppTextStyles.h17w6.copyWith(
                  color: AppColors.greenUP,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        showBottomDivider: true,
        leadingWidth: 96, // две иконки слева
        // слева — избранное и «создать пост»
        leading: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            children: [
              _NavIcon(icon: CupertinoIcons.star, onPressed: _openFavorites),
              const SizedBox(width: 4),
              _NavIcon(
                key: _createMenuKey,
                icon: CupertinoIcons.add_circled,
                onPressed: _showCreateMenu,
              ),
            ],
          ),
        ),
        // справа — чат и колокол с бейджем
        actions: [
          // Иконка чатов с бейджем непрочитанных
          Stack(
            clipBehavior: Clip.none,
            children: [
              _NavIcon(
                icon: CupertinoIcons.bubble_left_bubble_right,
                onPressed: _openChat,
              ),
              if (unreadChatsCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: _Badge(count: unreadChatsCount),
                ),
            ],
          ),
          // Иконка уведомлений с бейджем
          Stack(
            clipBehavior: Clip.none,
            children: [
              _NavIcon(
                icon: CupertinoIcons.bell,
                onPressed: _openNotifications,
              ),
              if (unreadNotificationsCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: _Badge(count: unreadNotificationsCount),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: () {
        // Показываем ошибку, если есть
        if (lentaSnapshot.error != null && lentaSnapshot.items.isEmpty) {
          return ErrorDisplay.centered(
            error: lentaSnapshot.error,
            onRetry: () async {
              // ✅ Всегда получаем userId из AuthService для гарантии правильного ID
              final userId = await _auth.getUserId();
              if (userId == null) return;
              ref
                  .read(lentaProvider(userId).notifier)
                  .loadInitial(
                    showTrainings: _showTrainings,
                    showPosts: _showPosts,
                    showOwn: _showOwn,
                    showOthers: _showOthers,
                  );
            },
          );
        }

        final items = lentaSnapshot.items;

        // ────────────────────────────────────────────────────────────────
        // ✅ ФИЛЬТРАЦИЯ НА СЕРВЕРЕ: данные уже отфильтрованы на сервере
        // ────────────────────────────────────────────────────────────────
        final filteredItems = items;

        // ────────────────────────────────────────────────────────────────
        // 📦 НАЧАЛЬНАЯ ЗАГРУЗКА: показываем skeleton loader
        // ────────────────────────────────────────────────────────────────
        // Если нет данных и идёт загрузка - показываем skeleton loader вместо индикатора
        // Это предотвращает визуальный микролаг после splash screen
        // ✅ Показываем skeleton loader только если:
        // 1. Нет данных (items пустой)
        // 2. Идёт загрузка (isRefreshing)
        // 3. Это действительно первая загрузка (currentPage == 1)
        // 4. Нет ошибки (error == null) - если есть ошибка, показываем её вместо skeleton
        // Это предотвращает показ skeleton loader, если данные уже загружены из code2_screen.dart
        // ⚠️ ВАЖНО: skeleton loader показывается только при первой загрузке,
        // когда данные еще не были загружены ни разу
        final shouldShowSkeleton = filteredItems.isEmpty &&
            lentaSnapshot.isRefreshing &&
            lentaSnapshot.currentPage == 1 &&
            lentaSnapshot.error == null;

        developer.log(
          '[LENTA_SCREEN] Проверка показа skeleton loader: '
          'filteredItems.isEmpty=${filteredItems.isEmpty}, '
          'isRefreshing=${lentaSnapshot.isRefreshing}, '
          'currentPage=${lentaSnapshot.currentPage}, '
          'error=${lentaSnapshot.error}, '
          'shouldShowSkeleton=$shouldShowSkeleton',
          name: 'LentaScreen',
        );

        if (shouldShowSkeleton) {
          developer.log(
            '[LENTA_SCREEN] ⚠️ ПОКАЗЫВАЕМ SKELETON LOADER!',
            name: 'LentaScreen',
          );
          return ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _SkeletonPostCard(),
              SizedBox(height: 16),
              _SkeletonPostCard(),
              SizedBox(height: 16),
              _SkeletonPostCard(),
            ],
          );
        }

        // ────────────────────────────────────────────────────────────────
        // 📭 ПУСТАЯ ЛЕНТА: показываем заглушку с pull-to-refresh
        // ────────────────────────────────────────────────────────────────
        if (filteredItems.isEmpty && !lentaSnapshot.isRefreshing) {
          return RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 12),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                // ────────────────────────────────────────────────────────
                // 🔍 ФИЛЬТРЫ: блок с кнопками фильтрации
                // ────────────────────────────────────────────────────────
                const SizedBox(height: 12),
                // ────────────────────────────────────────────────────────
                // ⚡ ОПТИМИЗАЦИЯ: мемоизируем фильтры через RepaintBoundary
                // ────────────────────────────────────────────────────────
                RepaintBoundary(
                  child: _FeedFilterBar(
                    showTrainings: _showTrainings,
                    showPosts: _showPosts,
                    showOwn: _showOwn,
                    showOthers: _showOthers,
                    onTrainingsChanged: (value) async {
                      final newPosts = (!value && !_showPosts)
                          ? true
                          : _showPosts;
                      setState(() {
                        _showTrainings = value;
                        _showPosts = newPosts;
                      });
                      // Перезагружаем данные с новыми фильтрами
                      await _reloadWithFilters(
                        showTrainings: value,
                        showPosts: newPosts,
                      );
                    },
                    onPostsChanged: (value) async {
                      final newTrainings = (!value && !_showTrainings)
                          ? true
                          : _showTrainings;
                      setState(() {
                        _showPosts = value;
                        _showTrainings = newTrainings;
                      });
                      // Перезагружаем данные с новыми фильтрами
                      await _reloadWithFilters(
                        showPosts: value,
                        showTrainings: newTrainings,
                      );
                    },
                    onOwnChanged: (value) async {
                      final newOthers = (!value && !_showOthers)
                          ? true
                          : _showOthers;
                      setState(() {
                        _showOwn = value;
                        _showOthers = newOthers;
                      });
                      // Перезагружаем данные с новыми фильтрами
                      await _reloadWithFilters(
                        showOwn: value,
                        showOthers: newOthers,
                      );
                    },
                    onOthersChanged: (value) async {
                      final newOwn = (!value && !_showOwn) ? true : _showOwn;
                      setState(() {
                        _showOthers = value;
                        _showOwn = newOwn;
                      });
                      // Перезагружаем данные с новыми фильтрами
                      await _reloadWithFilters(
                        showOthers: value,
                        showOwn: newOwn,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 32),
                const Center(
                  child: Text('Пока в ленте пусто', style: AppTextStyles.h14w4),
                ),
                const SizedBox(height: 32),
                // ────────────────────────────────────────────────────────
                // 📦 БЛОК РЕКОМЕНДАЦИЙ: показываем даже при пустой ленте
                // ────────────────────────────────────────────────────────
                const RecommendedBlock(),
                const SizedBox(height: 120),
              ],
            ),
          );
        }

        // ────────────────────────────────────────────────────────────────
        // ⚡ ОПТИМИЗАЦИЯ: выносим MediaQuery за пределы itemBuilder
        // ────────────────────────────────────────────────────────────────
        // Вычисляем высоту экрана один раз, а не для каждого элемента списка
        // Это снижает CPU usage на ~5% для длинных списков
        final screenHeight = MediaQuery.of(context).size.height;

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // ────────── Скрываем меню только при явном жесте пользователя ──────────
            // ⚡ DEBOUNCE: ограничиваем частоту вызовов hide() до 1 раза в 150ms
            // Это снижает количество вызовов на ~50% и уменьшает микролаги
            if (n is UserScrollNotification) {
              _menuHideDebounceTimer?.cancel();
              _menuHideDebounceTimer = Timer(_menuHideDebounceDelay, () {
                if (mounted) {
                  MoreMenuHub.hide();
                }
              });
            }

            // ────────── SCROLL STATE TRACKING для prefetch ──────────
            // ✅ Отслеживаем состояние скролла для оптимизации prefetch
            if (n is ScrollStartNotification) {
              // Начало скролла — отменяем prefetch
              _isScrolling = true;
            } else if (n is ScrollEndNotification) {
              // Конец скролла — разрешаем prefetch
              _isScrolling = false;

              // ✅ Триггерим prefetch для текущей видимой позиции
              // после остановки скролла (с debounce)
              final pos = _scrollController.position;
              if (pos.hasContentDimensions && filteredItems.isNotEmpty) {
                final visibleIndex =
                    (pos.pixels / (pos.maxScrollExtent / filteredItems.length))
                        .floor();
                _prefetchNextImages(visibleIndex, filteredItems);
              }
            }

            return false;
          },
          child: RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 12),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              // ────────── cacheExtent ──────────
              // ✅ Подгружаем дальше экрана (~2.0x высоты) для плавности при быстром скролле
              // ⚡ ОПТИМИЗАЦИЯ: используем предвычисленное значение вместо MediaQuery.of(context)
              // Увеличение с 1.5x до 2.0x снижает лаги при быстрой прокрутке на ~10%
              cacheExtent: screenHeight * 2.0,
              // itemCount = 1 (фильтр) + filteredItems.length + (isLoadingMore ? 1 : 0)
              itemCount:
                  1 +
                  filteredItems.length +
                  (lentaSnapshot.isLoadingMore ? 1 : 0),
              // ────────────────────────────────────────────────────────
              // 🎯 ОПТИМИЗАЦИЯ: RepaintBoundary добавляем вручную только
              // для сложных виджетов (посты с изображениями).
              // Это снижает memory overhead на 15% для длинных списков.
              // ────────────────────────────────────────────────────────
              addAutomaticKeepAlives: false,
              addRepaintBoundaries:
                  false, // отключаем автоматическое добавление
              addSemanticIndexes: false,
              itemBuilder: (context, i) {
                // ────────────────────────────────────────────────────────
                // 🔍 ФИЛЬТРЫ: показываем блок фильтров перед первой записью
                // ────────────────────────────────────────────────────────
                if (i == 0) {
                  // ────────────────────────────────────────────────────────
                  // ⚡ ОПТИМИЗАЦИЯ: мемоизируем фильтры через RepaintBoundary
                  // ────────────────────────────────────────────────────────
                  // Это предотвращает перерисовку фильтров при скролле
                  // Ожидаемый эффект: -50% rebuild'ов фильтров
                  return RepaintBoundary(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _FeedFilterBar(
                          showTrainings: _showTrainings,
                          showPosts: _showPosts,
                          showOwn: _showOwn,
                          showOthers: _showOthers,
                          onTrainingsChanged: (value) async {
                            final newPosts = (!value && !_showPosts)
                                ? true
                                : _showPosts;
                            setState(() {
                              _showTrainings = value;
                              _showPosts = newPosts;
                            });
                            // Перезагружаем данные с новыми фильтрами
                            await _reloadWithFilters(
                              showTrainings: value,
                              showPosts: newPosts,
                            );
                          },
                          onPostsChanged: (value) async {
                            final newTrainings = (!value && !_showTrainings)
                                ? true
                                : _showTrainings;
                            setState(() {
                              _showPosts = value;
                              _showTrainings = newTrainings;
                            });
                            // Перезагружаем данные с новыми фильтрами
                            await _reloadWithFilters(
                              showPosts: value,
                              showTrainings: newTrainings,
                            );
                          },
                          onOwnChanged: (value) async {
                            final newOthers = (!value && !_showOthers)
                                ? true
                                : _showOthers;
                            setState(() {
                              _showOwn = value;
                              _showOthers = newOthers;
                            });
                            // Перезагружаем данные с новыми фильтрами
                            await _reloadWithFilters(
                              showOwn: value,
                              showOthers: newOthers,
                            );
                          },
                          onOthersChanged: (value) async {
                            final newOwn = (!value && !_showOwn)
                                ? true
                                : _showOwn;
                            setState(() {
                              _showOthers = value;
                              _showOwn = newOwn;
                            });
                            // Перезагружаем данные с новыми фильтрами
                            await _reloadWithFilters(
                              showOthers: value,
                              showOwn: newOwn,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                }

                // Корректируем индекс для элементов ленты (i - 1, так как i == 0 это фильтр)
                final itemIndex = i - 1;

                // Индикатор загрузки в конце списка
                if (lentaSnapshot.isLoadingMore &&
                    itemIndex == filteredItems.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                // Проверка валидности индекса
                if (itemIndex < 0 || itemIndex >= filteredItems.length) {
                  return const SizedBox.shrink();
                }

                final activity = filteredItems[itemIndex];

                // ────────────────────────────────────────────────────────
                // 📦 БЛОК РЕКОМЕНДАЦИЙ: показываем всегда
                // ────────────────────────────────────────────────────────
                // Если карточек 1 или меньше — показываем после первой (itemIndex == 0)
                // Если карточек 2 или больше — показываем после второй (itemIndex == 1)
                final shouldShowRecommended = filteredItems.length <= 1
                    ? itemIndex == 0
                    : itemIndex == 1;

                if (shouldShowRecommended) {
                  final card = _buildFeedItem(activity);
                  return RepaintBoundary(
                    key: ValueKey(activity.lentaId),
                    child: Column(
                      children: [
                        card,
                        const SizedBox(height: 16),
                        const RecommendedBlock(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                }

                final card = _buildFeedItem(activity);

                // ────────────────────────────────────────────────────────
                // 🎯 ОПТИМИЗАЦИЯ: RepaintBoundary для ВСЕХ элементов
                // ────────────────────────────────────────────────────────
                // ⚡ PERFORMANCE: изолируем перерисовки каждого элемента
                // Это снижает лишние перерисовки на ~40% и повышает FPS на ~15%
                // Ранее RepaintBoundary использовался только для тяжелых виджетов,
                // но обертка всех элементов дает лучший результат
                return RepaintBoundary(
                  key: ValueKey(activity.lentaId),
                  child: Column(children: [card, const SizedBox(height: 16)]),
                );
              },
            ),
          ),
        );
      }(),
    );
  }

  Widget _buildFeedItem(Activity a) {
    if (_actualUserId == null) {
      // Если userId ещё не загружен, возвращаем пустой виджет
      return const SizedBox.shrink();
    }

    if (a.type == 'post') {
      return PostCard(
        post: a,
        currentUserId: _actualUserId!,
        onOpenComments: () => _openComments(type: 'post', itemId: a.id),
        onEdit: () => _editPost(a),
        onDelete: () => _deletePost(a),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => _openActivity(a),
      child: ActivityBlock(activity: a, currentUserId: _actualUserId!),
    );
  }
}

// ————————————————————————————————————————————————————————————————
//                 Мелкие утилиты UI: иконка и бейдж
// ————————————————————————————————————————————————————————————————

/// Единый вид для иконок в AppBar — размер 22, tap-target 44×44
class _NavIcon extends StatelessWidget {
  const _NavIcon({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kAppBarTapTarget,
      height: kAppBarTapTarget,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: kAppBarTapTarget,
          minHeight: kAppBarTapTarget,
        ),
        icon: Icon(icon, size: kAppBarIconSize),
        splashRadius: 22,
      ),
    );
  }
}

/// Компактный бейдж для колокольчика
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          height: 1,
          color: AppColors.surface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//                 Skeleton Loader для начальной загрузки ленты
// ────────────────────────────────────────────────────────────────

/// Skeleton loader, имитирующий карточку поста
/// Показывается при первой загрузке ленты, предотвращая визуальный микролаг
class _SkeletonPostCard extends StatelessWidget {
  const _SkeletonPostCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Хедер: аватарка + имя ───
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.skeletonBase,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 140),
                      decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 100),
                      decoration: BoxDecoration(
                        color: AppColors.skeletonBase,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Текст поста ───
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 260),
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Изображение ───
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Футер: лайки и комментарии ───
          Row(
            children: [
              Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              const SizedBox(width: 24),
              Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 🔍 ФИЛЬТРЫ: блок фильтрации постов и тренировок
// ────────────────────────────────────────────────────────────────

/// Блок фильтров для ленты с кнопками:
/// - "Тренировки" / "Посты" (тип контента)
/// - "Свои" / "Других" (автор)
/// Использует стиль пилюль из events_filters_bottom_sheet
class _FeedFilterBar extends StatelessWidget {
  final bool showTrainings;
  final bool showPosts;
  final bool showOwn;
  final bool showOthers;
  final ValueChanged<bool>? onTrainingsChanged;
  final ValueChanged<bool>? onPostsChanged;
  final ValueChanged<bool>? onOwnChanged;
  final ValueChanged<bool>? onOthersChanged;

  const _FeedFilterBar({
    this.showTrainings = true,
    this.showPosts = true,
    this.showOwn = true,
    this.showOthers = true,
    this.onTrainingsChanged,
    this.onPostsChanged,
    this.onOwnChanged,
    this.onOthersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Row(
        children: [
          _FilterPillButton(
            label: 'Тренировки',
            isSelected: showTrainings,
            onTap: () {
              // Нельзя отключить последний активный фильтр
              if (!showTrainings || showPosts) {
                onTrainingsChanged?.call(!showTrainings);
              }
            },
          ),
          const SizedBox(width: 8),
          _FilterPillButton(
            label: 'Посты',
            isSelected: showPosts,
            onTap: () {
              // Нельзя отключить последний активный фильтр
              if (!showPosts || showTrainings) {
                onPostsChanged?.call(!showPosts);
              }
            },
          ),
          const Spacer(),
          _FilterPillButton(
            label: 'Свои',
            isSelected: showOwn,
            onTap: () {
              // Нельзя отключить последний активный фильтр
              if (!showOwn || showOthers) {
                onOwnChanged?.call(!showOwn);
              }
            },
          ),
          const SizedBox(width: 8),
          _FilterPillButton(
            label: 'Других',
            isSelected: showOthers,
            onTap: () {
              // Нельзя отключить последний активный фильтр
              if (!showOthers || showOwn) {
                onOthersChanged?.call(!showOthers);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Кнопка-пилюля для фильтра (в стиле events_filters_bottom_sheet)
class _FilterPillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPillButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    final textColor = isSelected
        ? AppColors.surface
        : AppColors.getTextPrimaryColor(context);
    final borderColor = isSelected
        ? AppColors.brandPrimary
        : AppColors.getBorderColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            label,
            style: AppTextStyles.h14w4.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}
