// lib/screens/lenta/widgets/activity_description_block.dart
import 'dart:io';

import 'package:flutter/cupertino.dart'
    show
        CupertinoIcons,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoActivityIndicator,
        CupertinoSliverRefreshControl,
        showCupertinoDialog;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show ImageProvider, NetworkImage, ImageConfiguration;
import 'dart:ui' as ui; // для ui.Path
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
// Берём готовые виджеты (чтобы совпадал верх с ActivityBlock)
import '../widgets/activity/header/activity_header.dart';
import '../widgets/activity/stats/stats_row.dart';
import '../widgets/activity/equipment/equipment_chip.dart'
    as ab
    show EquipmentChip;
// Блок действий (лайк, комментарии, совместно)
import '../widgets/activity/actions/activity_actions_row.dart';
// Карусель маршрута с фотографиями
import '../../widgets/activity_route_carousel.dart';
// Комментарии и совместные активности
import '../widgets/comments_bottom_sheet.dart';
import 'together/together_screen.dart';
// Модель — через алиас, чтобы не конфликтовало имя Equipment
import '../../../../domain/models/activity_lenta.dart' as al;
import 'combining_screen.dart';
import 'fullscreen_route_map_screen.dart';
import 'edit_activity_screen.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/more_menu_overlay.dart';
import '../../../../core/widgets/more_menu_hub.dart';
import '../../../../features/complaint.dart';
import '../../../../core/services/api_service.dart'
    show ApiService, ApiException;
import '../../../../core/utils/activity_format.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../providers/lenta_provider.dart';
import 'together/together_providers.dart';
import '../../../../core/services/route_map_service.dart';

/// Страница с подробным описанием тренировки.
/// Верхний блок (аватар, дата, метрики) полностью повторяет ActivityBlock.
/// Добавлены: плашка часов, «Отрезки» на всю ширину, сегменты «Темп/Пульс/Высота»,
/// единый блок «График + сводка темпа».
class ActivityDescriptionPage extends ConsumerStatefulWidget {
  final al.Activity activity;
  final int currentUserId;

  const ActivityDescriptionPage({
    super.key,
    required this.activity,
    this.currentUserId = 0,
  });

  @override
  ConsumerState<ActivityDescriptionPage> createState() =>
      _ActivityDescriptionPageState();
}

class _ActivityDescriptionPageState
    extends ConsumerState<ActivityDescriptionPage> {
  // Данные пользователя (владельца тренировки)
  String? _userFirstName;
  String? _userLastName;
  String? _userAvatar;
  bool _isLoadingUserData = true;

  // ────────────────────────────────────────────────────────────────
  // ✅ Совместная тренировка: плашка приглашения
  // ────────────────────────────────────────────────────────────────
  bool _inviteBannerDismissed = false;

  // ────────────────────────────────────────────────────────────────
  // 🔹 КЛЮЧ ДЛЯ МЕНЮ: нужен для привязки всплывающего меню
  // ────────────────────────────────────────────────────────────────
  final GlobalKey _menuKey = GlobalKey();

  // ────────────────────────────────────────────────────────────────
  // 📦 ЛОКАЛЬНОЕ СОСТОЯНИЕ: храним обновленную активность после замены экипировки
  // ────────────────────────────────────────────────────────────────
  al.Activity? _updatedActivity;

  // ────────────────────────────────────────────────────────────────
  // 📊 ДАННЫЕ ДЛЯ ГРАФИКОВ: темп, пульс, высота, мощность по километрам
  // ────────────────────────────────────────────────────────────────
  List<double> _paceData = [];
  List<double> _heartRateData = [];
  List<double> _elevationData = [];
  List<double> _wattsData = []; // мощность (ватты) по километрам
  List<int> _paceLabels = []; // Метки для оси X (в метрах для плавания, в км для остальных)
  bool _isLoadingCharts = true;
  bool _isSwimmingChart = false; // Флаг, что это плавание

  // Сводка данных для отображения под графиками
  Map<String, dynamic>? _chartsSummary;

  final ApiService _api = ApiService();

  // ────────────────────────────────────────────────────────────────
  // 🎬 АНИМАЦИЯ ПРИ СКРОЛЛЕ: состояние для плавного появления заголовка
  // ────────────────────────────────────────────────────────────────
  bool _isScrolled = false;
  double _titleOpacity = 0;
  double _headerOpacity = 1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChartsData();
    // ────────────────────────────────────────────────────────────────
    // 🗺️ ПРЕДЗАГРУЗКА КАРТЫ: проверяем наличие сохраненного изображения
    // для ускорения отображения карты при открытии из профиля
    // ────────────────────────────────────────────────────────────────
    _preloadRouteMap();
  }

  /// Предзагружает карту маршрута в фоне для ускорения отображения
  /// Загружает изображение заранее, чтобы оно было готово к отображению
  Future<void> _preloadRouteMap() async {
    final a = widget.activity;
    // Предзагружаем только если есть точки маршрута и activityId
    if (a.points.isNotEmpty && a.id > 0) {
      try {
        final routeMapService = RouteMapService();
        // Проверяем наличие сохраненного изображения на сервере
        // Это заполнит кеш сервиса для быстрого доступа в ActivityRouteCarousel
        final savedUrl = await routeMapService.getRouteMapUrl(a.id);
        
        // ────────────────────────────────────────────────────────────────
        // ✅ ПРЕДЗАГРУЗКА ИЗОБРАЖЕНИЯ: если карта найдена, предзагружаем её
        // Это устраняет задержку при отображении карты
        // ────────────────────────────────────────────────────────────────
        if (savedUrl != null) {
          // Предзагружаем изображение в кеш CachedNetworkImage
          try {
            final imageProvider = NetworkImage(savedUrl);
            await imageProvider.resolve(const ImageConfiguration());
          } catch (e) {
            // Игнорируем ошибки предзагрузки изображения
          }
        }
      } catch (e) {
        // Игнорируем ошибки предзагрузки (не критично)
      }
    }
  }

  /// Загружает данные пользователя (владельца тренировки) из базы данных
  Future<void> _loadUserData() async {
    final activityUserId = widget.activity.userId;
    if (activityUserId <= 0) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
      return;
    }

    try {
      final data = await _api.post(
        '/get_user_info.php',
        body: {'user_id': activityUserId.toString()},
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        if (data['ok'] == true) {
          setState(() {
            _userFirstName = data['first_name']?.toString() ?? '';
            _userLastName = data['last_name']?.toString() ?? '';
            _userAvatar = data['avatar']?.toString() ?? '';
            _isLoadingUserData = false;
          });
        } else {
          // Если ошибка, используем данные из Activity как fallback
          setState(() {
            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      // В случае ошибки используем данные из Activity как fallback
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  /// Загружает данные для графиков (темп, пульс, высота по километрам)
  Future<void> _loadChartsData() async {
    final activityId = widget.activity.id;
    if (activityId <= 0) {
      if (mounted) {
        setState(() {
          _isLoadingCharts = false;
        });
      }
      return;
    }

    try {
      final data = await _api.post(
        '/get_activity_charts.php',
        body: {'activity_id': activityId.toString()},
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        if (data['ok'] == true) {
          setState(() {
            // Преобразуем массивы в List<double>
            _paceData =
                (data['pace'] as List<dynamic>?)
                    ?.map((e) => (e as num).toDouble())
                    .toList() ??
                [];
            _heartRateData =
                (data['heartRate'] as List<dynamic>?)
                    ?.map((e) => (e as num).toDouble())
                    .toList() ??
                [];
            _elevationData =
                (data['elevation'] as List<dynamic>?)
                    ?.map((e) => (e as num).toDouble())
                    .toList() ??
                [];
            _wattsData =
                (data['watts'] as List<dynamic>?)
                    ?.map((e) => (e as num).toDouble())
                    .toList() ??
                [];
            // Метки для оси X (для плавания - в метрах)
            _paceLabels =
                (data['paceLabels'] as List<dynamic>?)
                    ?.map((e) => (e as num).toInt())
                    .toList() ??
                [];
            // Флаг, что это плавание
            _isSwimmingChart = data['isSwimming'] == true;
            _chartsSummary = data['summary'] as Map<String, dynamic>?;
            _isLoadingCharts = false;
          });
        } else {
          // Если ошибка, оставляем пустые данные
          setState(() {
            _isLoadingCharts = false;
          });
        }
      }
    } catch (e) {
      // В случае ошибки оставляем пустые данные
      if (mounted) {
        setState(() {
          _isLoadingCharts = false;
        });
      }
    }
  }

  /// Получает актуальную активность: либо из провайдера (если обновлена),
  /// либо из widget.activity
  al.Activity get _currentActivity {
    // Если есть обновленная активность в локальном состоянии — используем её
    if (_updatedActivity != null) {
      return _updatedActivity!;
    }

    // Пытаемся получить обновленную активность из провайдера
    final userId = widget.currentUserId > 0
        ? widget.currentUserId
        : widget.activity.userId;
    if (userId > 0) {
      try {
        final lentaState = ref.read(lentaProvider(userId));
        final updated = lentaState.items.firstWhere(
          (a) => a.lentaId == widget.activity.lentaId,
          orElse: () => widget.activity,
        );
        return updated;
      } catch (e) {
        // Если ошибка — используем исходную активность
        return widget.activity;
      }
    }

    return widget.activity;
  }

  /// Обновляет активность после замены экипировки
  Future<void> _refreshActivityAfterEquipmentChange() async {
    final userId = widget.currentUserId > 0
        ? widget.currentUserId
        : widget.activity.userId;
    if (userId <= 0) return;

    try {
      // Обновляем провайдер
      await ref.read(lentaProvider(userId).notifier).refresh();

      // Получаем обновленную активность из провайдера
      final lentaState = ref.read(lentaProvider(userId));
      final updated = lentaState.items.firstWhere(
        (a) => a.lentaId == widget.activity.lentaId,
        orElse: () => widget.activity,
      );

      // Обновляем локальное состояние
      if (mounted) {
        setState(() {
          _updatedActivity = updated;
        });
      }
    } catch (e) {
      // В случае ошибки просто обновляем локальное состояние из провайдера
      // без дополнительных действий
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🔹 ПОКАЗ МЕНЮ: показывает меню с действиями для тренировки
  /// ────────────────────────────────────────────────────────────────
  void _showMenu(BuildContext context) {
    final a = _currentActivity;
    final items = <MoreMenuItem>[];

    // ────────────────────────────────────────────────────────────────
    // 🔹 МЕНЮ ДЛЯ АВТОРА: редактирование, добавление фото, удаление
    // ────────────────────────────────────────────────────────────────
    if (a.userId == widget.currentUserId) {
      items.addAll([
        MoreMenuItem(
          text: 'Редактировать',
          icon: CupertinoIcons.pencil,
          iconColor: AppColors.brandPrimary,
          onTap: () {
            MoreMenuHub.hide();
            Navigator.of(context, rootNavigator: true)
                .push(
                  TransparentPageRoute(
                    builder: (_) => EditActivityScreen(
                      activity: a,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                )
                .then((updated) {
                  // Если изменения были сохранены, обновляем данные
                  if (updated == true && mounted) {
                    _refreshActivityAfterEquipmentChange();
                  }
                });
          },
        ),
        MoreMenuItem(
          text: 'Добавить фотографии',
          icon: CupertinoIcons.photo_on_rectangle,
          iconColor: AppColors.brandPrimary,
          onTap: () {
            MoreMenuHub.hide();
            _handleAddPhotos(
              context: context,
              activityId: a.id,
              lentaId: a.lentaId,
            );
          },
        ),
        MoreMenuItem(
          text: 'Объединить тренировку',
          icon: CupertinoIcons.personalhotspot,
          onTap: () {
            MoreMenuHub.hide();
            Navigator.of(context).push(
              TransparentPageRoute(builder: (_) => const CombiningScreen()),
            );
          },
        ),
        MoreMenuItem(
          text: 'Удалить тренировку',
          icon: CupertinoIcons.minus_circle,
          iconColor: AppColors.error,
          textStyle: const TextStyle(color: AppColors.error),
          onTap: () {
            MoreMenuHub.hide();
            _handleDeleteActivity(context: context, activity: a);
          },
        ),
      ]);
    } else {
      // ────────────────────────────────────────────────────────────────
      // 🔹 МЕНЮ ДЛЯ ДРУГИХ ПОЛЬЗОВАТЕЛЕЙ: "Пожаловаться" и "Скрыть тренировки"
      // ────────────────────────────────────────────────────────────────
      items.addAll([
        MoreMenuItem(
          text: 'Пожаловаться',
          icon: CupertinoIcons.exclamationmark_circle,
          iconColor: AppColors.orange,
          textStyle: const TextStyle(color: AppColors.orange),
          onTap: () {
            MoreMenuHub.hide();
            final activity = _updatedActivity ?? widget.activity;
            Navigator.of(context, rootNavigator: true).push(
              TransparentPageRoute(
                builder: (_) => ComplaintScreen(
                  contentType: activity.type == 'post' ? 'post' : 'activity',
                  contentId: activity.id,
                ),
              ),
            );
          },
        ),
        MoreMenuItem(
          text: 'Скрыть тренировки',
          icon: CupertinoIcons.eye_slash,
          iconColor: AppColors.error,
          textStyle: const TextStyle(color: AppColors.error),
          onTap: () {
            MoreMenuHub.hide();
            _handleHideActivities(context: context, activity: a);
          },
        ),
      ]);
    }

    MoreMenuOverlay(anchorKey: _menuKey, items: items).show(context);
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🔄 ОБНОВЛЕНИЕ ЭКРАНА: при скролле сверху вниз (pull-to-refresh)
  /// ────────────────────────────────────────────────────────────────
  /// Обновляет данные активности из провайдера и перезагружает данные пользователя
  Future<void> _onRefresh() async {
    final userId = widget.currentUserId > 0
        ? widget.currentUserId
        : widget.activity.userId;
    if (userId <= 0) return;

    try {
      // Обновляем провайдер ленты
      await ref.read(lentaProvider(userId).notifier).refresh();

      // Получаем обновленную активность из провайдера
      final lentaState = ref.read(lentaProvider(userId));
      final updated = lentaState.items.firstWhere(
        (a) => a.lentaId == widget.activity.lentaId,
        orElse: () => widget.activity,
      );

      // Обновляем локальное состояние активности
      if (mounted) {
        setState(() {
          _updatedActivity = updated;
        });
      }

      // Перезагружаем данные пользователя
      await _loadUserData();
    } catch (e) {
      // В случае ошибки просто перезагружаем данные пользователя
      if (mounted) {
        await _loadUserData();
      }
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 📏 МЕТРИКИ ШАПКИ: вычисляем высоту карты для анимации
  // ────────────────────────────────────────────────────────────────
  double _getMapHeight(BuildContext context) {
    final a = _currentActivity;
    final noRouteAndNoPhotos = a.points.isEmpty && a.mediaImages.isEmpty;

    // Блок показываем: есть маршрут/фото или нет ни того ни другого (дефолт по типу)
    if (a.points.isNotEmpty || a.mediaImages.isNotEmpty || noRouteAndNoPhotos) {
      // Нет маршрута и нет фото — дефолтная картинка, высота 350 px
      if (noRouteAndNoPhotos) {
        return 350.0;
      }

      // ────────────────────────────────────────────────────────────────
      // 📐 ВЫЧИСЛЕНИЕ ВЫСОТЫ ПО СООТНОШЕНИЮ 1:1.1 С УЧЕТОМ SAFEAREA:
      // Высота = (ширина экрана с учетом SafeArea) × 1.1
      // ────────────────────────────────────────────────────────────────
      final mediaQuery = MediaQuery.of(context);
      final safeAreaPadding = mediaQuery.padding;
      final screenWidth =
          mediaQuery.size.width - safeAreaPadding.left - safeAreaPadding.right;
      return screenWidth * 1.1;
    }

    // Иначе — высота 0 (ничего не показываем)
    return 0;
  }

  double _getHeaderThreshold(BuildContext context) {
    final mapHeight = _getMapHeight(context);
    // Порог коллапса шапки (80% от высоты карты)
    return mapHeight * 0.8;
  }

  /// ────────────────────────────────────────────────────────────────
  /// 📏 ФОРМАТИРОВАНИЕ РАССТОЯНИЯ: для плавания показываем в метрах,
  /// для остальных типов — в километрах
  /// ────────────────────────────────────────────────────────────────
  String _formatDistance(double? distanceMeters, String activityType) {
    if (distanceMeters == null) return '—';

    final isSwim =
        activityType.toLowerCase() == 'swim' ||
        activityType.toLowerCase() == 'swimming';

    if (isSwim) {
      // Для плавания: форматируем в метрах с пробелами после каждых 3 цифр
      final value = distanceMeters.toStringAsFixed(0);
      final buffer = StringBuffer();
      for (int i = 0; i < value.length; i++) {
        if (i > 0 && (value.length - i) % 3 == 0) {
          buffer.write(' ');
        }
        buffer.write(value[i]);
      }
      return '${buffer.toString()} м';
    } else {
      // Для остальных типов: форматируем в километрах с 2 знаками после запятой
      return '${(distanceMeters / 1000.0).toStringAsFixed(2)} км';
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _currentActivity;
    final stats = a.stats;
    final mapHeight = _getMapHeight(context);
    final threshold = _getHeaderThreshold(context);
    final distanceText = _formatDistance(stats?.distance, a.type);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        // ────────────────────────────────────────────────────────────────
        // ✅ Плашка приглашения в совместную тренировку (фиксированная снизу)
        // ────────────────────────────────────────────────────────────────
        // ВАЖНО: визуально это "плавающая плашка", но реализуем через
        // bottomNavigationBar, чтобы не вмешиваться в сложную верстку NestedScrollView
        // и гарантировать отсутствие регрессий.
        bottomNavigationBar: _inviteBannerDismissed
            ? null
            : _TogetherInviteBottomBar(
                activityId: a.id,
                activityOwnerId: a.userId,
                currentUserId: widget.currentUserId,
                onDismiss: () => setState(() => _inviteBannerDismissed = true),
              ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // ──────────────────────────────────────────────────────────────
            // При любом вертикальном скролле прячем всплывающее меню
            // ──────────────────────────────────────────────────────────────
            if (notification.depth == 0 &&
                notification.metrics.axis == Axis.vertical) {
              MoreMenuHub.hide();
            }

            // Обрабатываем только вертикальные уведомления верхнего уровня
            if (notification is ScrollUpdateNotification &&
                notification.depth == 0 &&
                notification.metrics.axis == Axis.vertical) {
              // ──────────────────────────────────────────────────────────────
              // Плавно считаем прогресс схлопывания шапки
              // Заголовок появляется только в конце скролла (после 70%),
              // фон (карта/картинка) начинает менять прозрачность
              // также только в самом конце скролла, а не с нуля.
              // ──────────────────────────────────────────────────────────────
              final thresholdValue = threshold > 0 ? threshold : 1.0;
              final rawProgress = notification.metrics.pixels / thresholdValue;
              final clampedProgress = rawProgress.clamp(0.0, 1.0).toDouble();

              // Заголовок начинает появляться только после 90% скролла
              const titleStartProgress = 0.9;
              final titleProgress = clampedProgress < titleStartProgress
                  ? 0.0
                  : ((clampedProgress - titleStartProgress) /
                            (1.0 - titleStartProgress))
                        .clamp(0.0, 1.0);

              final newOpacity = titleProgress;
              final newIsScrolled = clampedProgress >= 1;
              // ──────────────────────────────────────────────────────────────
              // Прозрачность фоновой картинки/карты:
              // до 90% скролла фон полностью видимый (opacity = 1),
              // затем в последней десятой части скролла плавно скрываем его.
              // ──────────────────────────────────────────────────────────────
              const headerFadeStartProgress = 0.9;
              final headerFadeProgress =
                  clampedProgress < headerFadeStartProgress
                  ? 0.0
                  : ((clampedProgress - headerFadeStartProgress) /
                            (1.0 - headerFadeStartProgress))
                        .clamp(0.0, 1.0);
              final newHeaderOpacity = (1.0 - headerFadeProgress).clamp(
                0.0,
                1.0,
              );

              if (newIsScrolled != _isScrolled ||
                  (newOpacity - _titleOpacity).abs() > 0.04 ||
                  (newHeaderOpacity - _headerOpacity).abs() > 0.04) {
                setState(() {
                  _isScrolled = newIsScrolled;
                  _titleOpacity = newOpacity;
                  _headerOpacity = newHeaderOpacity;
                });
              }
            }
            return false;
          },
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              // ────────────────────────────────────────────────────────────────
              // 🖼️ ДЕФОЛТНАЯ КАРТИНКА: нет маршрута и нет фото — 350 px
              // SliverAppBar добавляет SafeArea.top, вычитаем для совпадения с ActivityBlock
              // ────────────────────────────────────────────────────────────────
              final noRouteAndNoPhotos =
                  a.points.isEmpty && a.mediaImages.isEmpty;
              // ────────────────────────────────────────────────────────────────
              // 📐 ВЫЧИСЛЕНИЕ ВЫСОТЫ С УЧЕТОМ SAFEAREA:
              // SliverAppBar автоматически добавляет SafeArea.top к expandedHeight
              // Чтобы контент занимал нужную высоту (350 для дефолтной картинки,
              // или вычисленную высоту для карты маршрута с соотношением 1:1.1),
              // нужно вычесть SafeArea.top из expandedHeight
              // Это обеспечивает одинаковую высоту контента с ActivityBlock
              // ────────────────────────────────────────────────────────────────
              final safeAreaTop = MediaQuery.of(context).padding.top;
              final baseHeight = noRouteAndNoPhotos ? 350.0 : mapHeight;
              final expandedHeight = baseHeight - safeAreaTop;
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
                  backgroundColor: AppColors.getSurfaceColor(context),
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  forceElevated: isCollapsed || titleOpacity > 0.05,
                  leadingWidth: 46,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _CircleAppIcon(
                      icon: CupertinoIcons.back,
                      isScrolled: isCollapsed,
                      fadeOpacity: headerOpacity,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  title: titleOpacity > 0.01
                      ? AnimatedOpacity(
                          opacity: titleOpacity,
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          child: Text(
                            distanceText,
                            style: AppTextStyles.h18w6.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        )
                      : null,
                  centerTitle: true,
                  actions: [
                    _CircleAppIcon(
                      icon: CupertinoIcons.ellipsis_vertical,
                      key: _menuKey,
                      isScrolled: isCollapsed,
                      fadeOpacity: headerOpacity,
                      onPressed: () => _showMenu(context),
                    ),
                    const SizedBox(width: 6),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.none,
                    // Плавно скрываем карту при скролле
                    background: AnimatedOpacity(
                      opacity: headerOpacity,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: Builder(
                        builder: (context) {
                          // Если есть маршрут или изображения — показываем карусель
                          if (a.points.isNotEmpty || a.mediaImages.isNotEmpty) {
                            return ActivityRouteCarousel(
                              points: a.points
                                  .map((c) => ll.LatLng(c.lat, c.lng))
                                  .toList(),
                              imageUrls: a.mediaImages,
                              height: mapHeight,
                              mapSortOrder: a.mapSortOrder,
                              activityId: a.id,
                              userId: a.userId,
                              // ────────────────────────────────────────────────────────────────
                              // 🔹 ОТКРЫТИЕ ПОЛНОЭКРАННОЙ КАРТЫ: при клике на слайд с картой
                              // ────────────────────────────────────────────────────────────────
                              onMapTap: a.points.isNotEmpty
                                  ? () {
                                      Navigator.of(context).push(
                                        TransparentPageRoute(
                                          builder: (context) =>
                                              FullscreenRouteMapScreen(
                                                points: a.points
                                                    .map(
                                                      (c) => ll.LatLng(
                                                        c.lat,
                                                        c.lng,
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          }

                          // Нет маршрута и нет фото — дефолтная картинка по типу:
                          // Бег — nogps.jpg, Велосипед — nogsp_bike.jpg,
                          // Плавание — nogps_swim.jpg, Лыжи — nogps_ski.jpg
                          if (a.points.isEmpty && a.mediaImages.isEmpty) {
                            final defaultImagePath = getDefaultNoRouteImagePath(
                              a.type,
                            );
                            return SizedBox(
                              height: 350.0,
                              width: double.infinity,
                              child: Image.asset(
                                defaultImagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppColors.disabled,
                                      child: const Center(
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          size: 48,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ),
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ───────────────── Pull-to-refresh ─────────────────
                CupertinoSliverRefreshControl(onRefresh: _onRefresh),
                // ───────── Верхний блок (как в ActivityBlock)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      border: Border(
                        top: BorderSide(
                          width: 0.5,
                          color: AppColors.getBorderColor(context),
                        ),
                        bottom: BorderSide(
                          width: 0.5,
                          color: AppColors.getBorderColor(context),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Шапка: при загрузке — плейсхолдер аватара и индикатор
                        // имени; после загрузки — данные с fade-in.
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _isLoadingUserData
                              ? ActivityHeader(
                                  userId: widget.activity.userId,
                                  userName: '',
                                  userAvatar: '',
                                  isUserDataLoading: true,
                                  dateStart: a.dateStart,
                                  dateTextOverride: a.postDateText,
                                  bottom: StatsRow(
                                    distanceMeters: stats?.distance,
                                    durationSec: stats?.effectiveDuration,
                                    elevationGainM:
                                        stats?.cumulativeElevationGain,
                                    avgPaceMinPerKm: stats?.avgPace,
                                    avgHeartRate: stats?.avgHeartRate,
                                    avgCadence: stats?.avgCadence,
                                    calories: stats?.calories,
                                    totalSteps: stats?.totalSteps,
                                    // ────────────────────────────────────────────────────────────────
                                    // Тренировка добавлена вручную только если нет GPS-трека
                                    // И нет данных о пульсе/каденсе (значит действительно вручную)
                                    // ────────────────────────────────────────────────────────────────
                                    isManuallyAdded:
                                        a.points.isEmpty &&
                                        (stats?.avgHeartRate == null &&
                                            stats?.avgCadence == null),
                                    // ────────────────────────────────────────────────────────────────
                                    // Показываем третью строку (Калории | Шаги | Скорость) на экране описания
                                    // 🚴 ДЛЯ ВЕЛОСИПЕДА: не показываем третью строку метрик
                                    // 🏊 ДЛЯ ПЛАВАНИЯ: не показываем третью строку метрик
                                    // ────────────────────────────────────────────────────────────────
                                    showExtendedStats:
                                        !(a.type.toLowerCase() == 'bike' ||
                                            a.type.toLowerCase() == 'bicycle' ||
                                            a.type.toLowerCase() == 'cycling' ||
                                            a.type.toLowerCase() == 'indoor-cycling' ||
                                            a.type.toLowerCase() == 'swim' ||
                                            a.type.toLowerCase() == 'swimming'),
                                    // ────────────────────────────────────────────────────────────────
                                    // 📏 ПЕРЕДАЧА ТИПА АКТИВНОСТИ: для плавания расстояние показываем в метрах
                                    // ────────────────────────────────────────────────────────────────
                                    activityType: a.type,
                                    // ────────────────────────────────────────────────────────────────
                                    // 📏 УМЕНЬШАЕМ НИЖНИЙ PADDING: для уменьшения промежутка между метриками и картой
                                    // ────────────────────────────────────────────────────────────────
                                    bottomPadding: 0,
                                    // ────────────────────────────────────────────────────────────────
                                    // 🏊 ДЛЯ ПЛАВАНИЯ НА ЭКРАНЕ ОПИСАНИЯ: показываем вторую строку метрик
                                    // ────────────────────────────────────────────────────────────────
                                    hideSecondRowForSwimInFeed: false,
                                    // ────────────────────────────────────────────────────────────────
                                    // 🚴 ПЕРЕДАЧА ИНФОРМАЦИИ О НАЛИЧИИ ТРЕКА: для пересчета скорости велотренировок без трека
                                    // ────────────────────────────────────────────────────────────────
                                    hasRoute: a.points.isNotEmpty,
                                  ),
                                  bottomGap: 16.0,
                                )
                              : _FadeInWidget(
                                  child: ActivityHeader(
                                    userId: widget.activity.userId,
                                    userName:
                                        _userFirstName != null &&
                                            _userLastName != null
                                        ? '$_userFirstName $_userLastName'
                                              .trim()
                                        : (_userFirstName?.isNotEmpty == true
                                              ? _userFirstName!
                                              : (_userLastName?.isNotEmpty ==
                                                        true
                                                    ? _userLastName!
                                                    : (a.userName.isNotEmpty
                                                          ? a.userName
                                                          : 'Аноним'))),
                                    userAvatar: _userAvatar?.isNotEmpty == true
                                        ? _userAvatar!
                                        : a.userAvatar,
                                    isUserDataLoading: false,
                                    dateStart: a.dateStart,
                                    dateTextOverride: a.postDateText,
                                    bottom: StatsRow(
                                      distanceMeters: stats?.distance,
                                      durationSec: stats?.effectiveDuration,
                                      elevationGainM:
                                          stats?.cumulativeElevationGain,
                                      avgPaceMinPerKm: stats?.avgPace,
                                      avgHeartRate: stats?.avgHeartRate,
                                      avgCadence: stats?.avgCadence,
                                      calories: stats?.calories,
                                      totalSteps: stats?.totalSteps,
                                      isManuallyAdded:
                                          a.points.isEmpty &&
                                          (stats?.avgHeartRate == null &&
                                              stats?.avgCadence == null),
                                      showExtendedStats:
                                          !(a.type.toLowerCase() == 'bike' ||
                                              a.type.toLowerCase() ==
                                                  'bicycle' ||
                                              a.type.toLowerCase() ==
                                                  'cycling' ||
                                              a.type.toLowerCase() == 'swim' ||
                                              a.type.toLowerCase() ==
                                                  'swimming'),
                                      activityType: a.type,
                                      bottomPadding: 0,
                                      hideSecondRowForSwimInFeed: false,
                                      // ────────────────────────────────────────────────────────────────
                                      // 🚴 ПЕРЕДАЧА ИНФОРМАЦИИ О НАЛИЧИИ ТРЕКА: для пересчета скорости велотренировок без трека
                                      // ────────────────────────────────────────────────────────────────
                                      hasRoute: a.points.isNotEmpty,
                                    ),
                                    bottomGap: 16.0,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ────────────────────────────────────────────────────────────────
                // 📦 ЭКИПИРОВКА: на всю ширину экрана, под блоком с хэдером
                // ────────────────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    // ────────────────────────────────────────────────────────────────
                    // 🌓 ФОН: используем surface цвет (белый в светлой теме)
                    // ────────────────────────────────────────────────────────────────
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                    ),
                    child: ab.EquipmentChip(
                      items: a.equipments,
                      userId: a.userId,
                      activityType: a.type,
                      activityId: a.id,
                      activityDistance: (stats?.distance ?? 0.0) / 1000.0,
                      // ────────────────────────────────────────────────────────────────
                      // 🔹 ПОКАЗ КНОПКИ МЕНЮ: только для владельца тренировки
                      // ────────────────────────────────────────────────────────────────
                      showMenuButton: a.userId == widget.currentUserId,
                      onEquipmentChanged: _refreshActivityAfterEquipmentChange,
                    ),
                  ),
                ),

                // ────────────────────────────────────────────────────────────────
                // 🎯 ДЕЙСТВИЯ: лайк, комментарии, совместно
                // ────────────────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppRadius.xl),
                        bottomRight: Radius.circular(AppRadius.xl),
                      ),
                      border: const Border(
                        bottom: BorderSide(
                          color: AppColors.twinchip,
                          width: 1.0,
                        ),
                      ),
                          boxShadow: const [
          BoxShadow(
            color: AppColors.twinchip,
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: ActivityActionsRow(
                      activityId: a.id,
                      activityUserId: a.userId,
                      currentUserId: widget.currentUserId,
                      initialLikes: a.likes,
                      initiallyLiked: a.islike,
                      commentsCount: a.comments,
                      hideRightActions: a.points.isEmpty,
                      activity: a,
                      onOpenComments: () {
                        // ────────────────────────────────────────────────────────────────
                        // 🔹 Открываем комментарии в bottom sheet с плавной анимацией
                        // ────────────────────────────────────────────────────────────────
                        final lentaState = ref.read(
                          lentaProvider(widget.currentUserId),
                        );
                        final activityItem = lentaState.items.firstWhere(
                          (item) => item.lentaId == a.lentaId,
                          orElse: () => a,
                        );

                        showCommentsBottomSheet(
                          context: context,
                          itemType: 'activity',
                          itemId: activityItem.id,
                          currentUserId: widget.currentUserId,
                          lentaId: activityItem.lentaId,
                          onCommentAdded: () {
                            final currentState = ref.read(
                              lentaProvider(widget.currentUserId),
                            );
                            final latestActivity = currentState.items
                                .firstWhere(
                                  (a) => a.lentaId == activityItem.lentaId,
                                  orElse: () => activityItem,
                                );

                            ref
                                .read(
                                  lentaProvider(widget.currentUserId).notifier,
                                )
                                .updateComments(
                                  activityItem.lentaId,
                                  latestActivity.comments + 1,
                                );
                          },
                          onCommentDeleted: () {
                            final currentState = ref.read(
                              lentaProvider(widget.currentUserId),
                            );
                            final latestActivity = currentState.items
                                .firstWhere(
                                  (a) => a.lentaId == activityItem.lentaId,
                                  orElse: () => activityItem,
                                );

                            // Уменьшаем счетчик на 1 (но не меньше 0)
                            final newCount = (latestActivity.comments - 1)
                                .clamp(0, double.infinity)
                                .toInt();
                            ref
                                .read(
                                  lentaProvider(widget.currentUserId).notifier,
                                )
                                .updateComments(activityItem.lentaId, newCount);
                          },
                        );
                      },
                      onOpenTogether: () {
                        // ────────────────────────────────────────────────────────────────
                        // 🔹 Открываем экран совместных активностей (без нижнего меню)
                        // ────────────────────────────────────────────────────────────────
                        Navigator.of(context, rootNavigator: true).push(
                          TransparentPageRoute(
                            builder: (_) => TogetherScreen(activityId: a.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ───────── «Отрезки» — таблица на всю ширину экрана
                // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем только если есть трек И есть разбивка на отрезки
                // Для других типов показываем всегда, если есть данные
                Builder(
                  builder: (context) {
                    final isBikeType = a.type.toLowerCase() == 'bike' ||
                        a.type.toLowerCase() == 'bicycle' ||
                        a.type.toLowerCase() == 'cycling' ||
                        a.type.toLowerCase() == 'indoor-cycling';
                    final hasSplitsData = stats?.pacePerKm.isNotEmpty == true ||
                        stats?.heartRatePerKm.isNotEmpty == true;
                    if ((!isBikeType && hasSplitsData) ||
                        (isBikeType && a.points.isNotEmpty && hasSplitsData)) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: AppColors.twinchip,
                                width: 0.7,
                              ),
                            ),
                            child: _SplitsTableFull(
                              stats: stats,
                              activityType: a.type,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  },
                ),
                Builder(
                  builder: (context) {
                    final isBikeType = a.type.toLowerCase() == 'bike' ||
                        a.type.toLowerCase() == 'bicycle' ||
                        a.type.toLowerCase() == 'cycling' ||
                        a.type.toLowerCase() == 'indoor-cycling';
                    final hasSplitsData = stats?.pacePerKm.isNotEmpty == true ||
                        stats?.heartRatePerKm.isNotEmpty == true;
                    if ((!isBikeType && hasSplitsData) ||
                        (isBikeType && a.points.isNotEmpty && hasSplitsData)) {
                      return const SliverToBoxAdapter(child: SizedBox(height: 12));
                    }
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  },
                ),

                // ───────── БЛОК ГРАФИКА ТЕМПА
                // Показываем только если есть данные pacePerKm в params
                // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем только если есть трек или есть разбивка на отрезки
                if (stats?.pacePerKm.isNotEmpty == true &&
                    !((a.type.toLowerCase() == 'bike' ||
                            a.type.toLowerCase() == 'bicycle' ||
                            a.type.toLowerCase() == 'cycling' ||
                            a.type.toLowerCase() == 'indoor-cycling') &&
                        a.points.isEmpty)) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.twinchip,
                            width: 0.7,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                // ────────────────────────────────────────────────────────────────
                                // 🏊 ДЛЯ ПЛАВАНИЯ: пересчитываем средний темп из stats.avgPace
                                // если summary неправильный или отсутствует
                                // ────────────────────────────────────────────────────────────────
                                Map<String, dynamic>? correctedSummary = _chartsSummary;
                                final isSwimming = a.type.toLowerCase() == 'swim' ||
                                    a.type.toLowerCase() == 'swimming';
                                if (isSwimming && stats?.avgPace != null && stats!.avgPace > 0) {
                                  // Пересчитываем из мин/км в секунды на 100м
                                  final avgPaceMinPerKm = stats.avgPace;
                                  final avgPaceSecPer100m = (avgPaceMinPerKm / 10.0) * 60.0;
                                  
                                  // Создаем или обновляем summary
                                  correctedSummary = Map<String, dynamic>.from(_chartsSummary ?? {});
                                  final paceSummary = Map<String, dynamic>.from(
                                    correctedSummary['pace'] as Map<String, dynamic>? ?? {},
                                  );
                                  paceSummary['average'] = avgPaceSecPer100m;
                                  correctedSummary['pace'] = paceSummary;
                                }
                                return _ChartMetricsHeader(
                                  mode: 0,
                                  summary: correctedSummary,
                                  isLoading: _isLoadingCharts,
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 210,
                              width: double.infinity,
                              child: _isLoadingCharts
                                  ? const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 10,
                                      ),
                                    )
                                  : _FadeInWidget(
                                      child: _SimpleLineChart(
                                        mode: 0,
                                        paceData: _paceData,
                                        heartRateData: _heartRateData,
                                        elevationData: _elevationData,
                                        wattsData: _wattsData,
                                        paceLabels: _paceLabels,
                                        isSwimming: _isSwimmingChart,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],

                // ───────── БЛОК ГРАФИКА ПУЛЬСА
                // Показываем только если есть данные heartRatePerKm в params
                // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем только если есть трек или есть разбивка на отрезки
                if (stats?.heartRatePerKm.isNotEmpty == true &&
                    !((a.type.toLowerCase() == 'bike' ||
                            a.type.toLowerCase() == 'bicycle' ||
                            a.type.toLowerCase() == 'cycling' ||
                            a.type.toLowerCase() == 'indoor-cycling') &&
                        a.points.isEmpty)) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.twinchip,
                            width: 0.7,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChartMetricsHeader(
                              mode: 1,
                              summary: _chartsSummary,
                              isLoading: _isLoadingCharts,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 210,
                              width: double.infinity,
                              child: _isLoadingCharts
                                  ? const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 10,
                                      ),
                                    )
                                  : _FadeInWidget(
                                      child: _SimpleLineChart(
                                        mode: 1,
                                        paceData: _paceData,
                                        heartRateData: _heartRateData,
                                        elevationData: _elevationData,
                                        wattsData: _wattsData,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],

                // ───────── БЛОК ГРАФИКА ВЫСОТЫ
                // Показываем только если есть данные elevationPerKm в params или в загруженных данных API
                // и это не плавание
                // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем только если есть трек или есть разбивка на отрезки
                // Проверяем оба источника: stats (из params) и _elevationData (из API)
                if (!(a.type.toLowerCase() == 'swim' ||
                        a.type.toLowerCase() == 'swimming') &&
                    (stats?.elevationPerKm?.isNotEmpty == true ||
                        (!_isLoadingCharts && _elevationData.isNotEmpty)) &&
                    !((a.type.toLowerCase() == 'bike' ||
                            a.type.toLowerCase() == 'bicycle' ||
                            a.type.toLowerCase() == 'cycling' ||
                            a.type.toLowerCase() == 'indoor-cycling') &&
                        a.points.isEmpty)) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.twinchip,
                            width: 1.0,
                          ),
                          boxShadow: const [
          BoxShadow(
            color: AppColors.twinchip,
            blurRadius: 10,
            offset: Offset(0, 1),
          ),
        ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChartMetricsHeader(
                              mode: 2,
                              summary: _chartsSummary,
                              isLoading: _isLoadingCharts,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 210,
                              width: double.infinity,
                              child: _isLoadingCharts
                                  ? const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 10,
                                      ),
                                    )
                                  : _FadeInWidget(
                                      child: _SimpleLineChart(
                                        mode: 2,
                                        paceData: _paceData,
                                        heartRateData: _heartRateData,
                                        elevationData: _elevationData,
                                        wattsData: _wattsData,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],

                // ───────── БЛОК ГРАФИКА МОЩНОСТИ (WATTS)
                // Показываем только если есть данные wattsPerKm в params или в загруженных данных
                // 🚴 ДЛЯ ВЕЛОТРЕНИРОВОК: показываем только если есть трек или есть разбивка на отрезки
                // Проверяем оба источника: stats (из params) и _wattsData (из API)
                if ((stats != null && stats.wattsPerKm.isNotEmpty) ||
                    (!_isLoadingCharts && _wattsData.isNotEmpty)) ...[
                  // Дополнительная проверка для велотренировок без трека
                  if (!((a.type.toLowerCase() == 'bike' ||
                          a.type.toLowerCase() == 'bicycle' ||
                          a.type.toLowerCase() == 'cycling' ||
                          a.type.toLowerCase() == 'indoor-cycling') &&
                      a.points.isEmpty))
                    SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.twinchip,
                            width: 0.7,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ChartMetricsHeader(
                              mode: 3,
                              summary: _chartsSummary,
                              isLoading: _isLoadingCharts,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 210,
                              width: double.infinity,
                              child: _isLoadingCharts
                                  ? const Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 10,
                                      ),
                                    )
                                  : _FadeInWidget(
                                      child: _SimpleLineChart(
                                        mode: 3,
                                        paceData: _paceData,
                                        heartRateData: _heartRateData,
                                        elevationData: _elevationData,
                                        wattsData: _wattsData,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ────────────────────────────────────────────────────────────────
  /// 📸 ОБРАБОТЧИК ДОБАВЛЕНИЯ ФОТОГРАФИЙ
  /// ────────────────────────────────────────────────────────────────
  Future<void> _handleAddPhotos({
    required BuildContext context,
    required int activityId,
    required int lentaId,
  }) async {
    final picker = ImagePicker();
    final container = ProviderScope.containerOf(context);
    final auth = container.read(authServiceProvider);
    final navigator = Navigator.of(context, rootNavigator: true);
    var loaderShown = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final aspectRatio = screenWidth / 400.0;

    void hideLoader() {
      if (loaderShown && navigator.mounted) {
        navigator.pop();
        loaderShown = false;
      }
    }

    try {
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: ImagePickerHelper.maxPickerDimension,
        maxHeight: ImagePickerHelper.maxPickerDimension,
        imageQuality: ImagePickerHelper.pickerImageQuality,
      );
      if (pickedFiles.isEmpty) return;

      final userId = await auth.getUserId();
      if (userId == null) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            error:
                'Не удалось определить пользователя. Пожалуйста, авторизуйтесь.',
          );
        }
        return;
      }

      final filesForUpload = <String, File>{};
      for (var i = 0; i < pickedFiles.length; i++) {
        if (!context.mounted) return;

        final picked = pickedFiles[i];
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: aspectRatio,
          title: 'Обрезать',
        );

        if (cropped == null) {
          continue;
        }

        final compressed = await compressLocalImage(
          sourceFile: cropped,
          maxSide: ImageCompressionPreset.activity.maxSide,
          jpegQuality: ImageCompressionPreset.activity.quality,
        );

        if (cropped.path != compressed.path) {
          try {
            await cropped.delete();
          } catch (_) {
            // Игнорируем ошибки удаления
          }
        }

        filesForUpload['file$i'] = compressed;
      }

      if (filesForUpload.isEmpty) {
        if (context.mounted) {
          await _showErrorDialog(
            context: context,
            error: 'Не удалось подготовить файлы для загрузки.',
          );
        }
        return;
      }

      if (!context.mounted) return;
      _showBlockingLoader(context, message: 'Загружаем фотографии…');
      loaderShown = true;

      final api = ref.read(apiServiceProvider);
      final response = await api.postMultipart(
        '/upload_activity_photos.php',
        files: filesForUpload,
        fields: {'user_id': '$userId', 'activity_id': '$activityId'},
        timeout: const Duration(minutes: 2),
      );

      hideLoader();

      if (response['success'] != true) {
        final message =
            response['message']?.toString() ??
            'Не удалось загрузить фотографии. Попробуйте ещё раз.';
        if (context.mounted) {
          await _showErrorDialog(context: context, error: message);
        }
        return;
      }

      final images =
          (response['images'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [];

      if (images.isNotEmpty) {
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .updateActivityMedia(lentaId: lentaId, mediaImages: images);
      } else {
        await ref.read(lentaProvider(widget.currentUserId).notifier).refresh();
      }

      if (context.mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Готово'),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Фотографии добавлены к тренировке.'),
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

      // Обновляем локальное состояние активности
      await _refreshActivityAfterEquipmentChange();
    } catch (e) {
      hideLoader();
      if (context.mounted) {
        await _showErrorDialog(context: context, error: e);
      }
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🗑️ ОБРАБОТЧИК УДАЛЕНИЯ ТРЕНИРОВКИ
  /// ────────────────────────────────────────────────────────────────
  Future<void> _handleDeleteActivity({
    required BuildContext context,
    required al.Activity activity,
  }) async {
    final confirmed = await _confirmDeletion(context);
    if (!confirmed || !context.mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    _showBlockingLoader(context);

    final success = await _sendDeleteActivityRequest(
      context: context,
      userId: widget.currentUserId,
      activityId: activity.id,
    );

    if (navigator.mounted) {
      navigator.pop();
    }

    if (!context.mounted) return;

    if (success) {
      // Удаляем элемент из провайдера
      await ref
          .read(lentaProvider(widget.currentUserId).notifier)
          .removeItem(activity.lentaId);
      // Закрываем экран описания
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      await _showErrorDialog(
        context: context,
        error: 'Не удалось удалить тренировку. Попробуйте ещё раз.',
      );
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 👁️ ОБРАБОТЧИК СКРЫТИЯ ТРЕНИРОВОК ПОЛЬЗОВАТЕЛЯ
  /// ────────────────────────────────────────────────────────────────
  Future<void> _handleHideActivities({
    required BuildContext context,
    required al.Activity activity,
  }) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Скрыть тренировки?'),
        content: Text(
          'Тренировки ${activity.userName} будут скрыты из вашей ленты.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Да, скрыть'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/hide_user_content.php',
        body: {
          'userId': '${widget.currentUserId}',
          'hidden_user_id': '${activity.userId}',
          'action': 'hide',
          'content_type': 'activity',
        },
        timeout: const Duration(seconds: 10),
      );

      final success = data['success'] == true;

      if (success && context.mounted) {
        // Удаляем тренировки пользователя из ленты локально
        ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .removeUserContent(
              hiddenUserId: activity.userId,
              contentType: 'activity',
            );
        // Закрываем экран описания
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } else if (context.mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Ошибка'),
            content: Text(
              data['message']?.toString() ??
                  'Не удалось скрыть тренировки пользователя',
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
    } catch (e) {
      if (context.mounted) {
        await _showErrorDialog(context: context, error: e);
      }
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🔹 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  /// ────────────────────────────────────────────────────────────────

  /// Показывает модальный диалог подтверждения удаления
  Future<bool> _confirmDeletion(BuildContext context) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удалить тренировку?'),
        content: const Text('Действие нельзя отменить.'),
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

  /// Показывает блокирующий лоадер
  void _showBlockingLoader(
    BuildContext context, {
    String message = 'Удаляем тренировку…',
  }) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CupertinoAlertDialog(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 12),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  /// Универсальный показ ошибки
  Future<void> _showErrorDialog({
    required BuildContext context,
    required dynamic error,
  }) {
    final message = ErrorHandler.format(error);
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ошибка'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText.rich(
            TextSpan(
              text: message,
              style: const TextStyle(color: AppColors.error, fontSize: 15),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  /// Вызывает API удаления активности и возвращает bool-успех
  Future<bool> _sendDeleteActivityRequest({
    required BuildContext context,
    required int userId,
    required int activityId,
  }) async {
    try {
      final container = ProviderScope.containerOf(context);
      final api = container.read(apiServiceProvider);
      final response = await api.post(
        '/delete_activity.php',
        body: {'userId': '$userId', 'activityId': '$activityId'},
        timeout: const Duration(seconds: 12),
      );

      final success = response['success'] == true;
      final message = response['message']?.toString() ?? '';

      return success || message == 'Тренировка удалена';
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ✅ Плашка приглашения "Принять / Отменить"
// ─────────────────────────────────────────────────────────────────────────────
class _TogetherInviteBottomBar extends ConsumerWidget {
  final int activityId;
  final int activityOwnerId;
  final int currentUserId;
  final VoidCallback onDismiss;

  const _TogetherInviteBottomBar({
    required this.activityId,
    required this.activityOwnerId,
    required this.currentUserId,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ─────────────────────────────────────────────────────────────────────────
    // Условия показа:
    // - видит только получатель (не владелец)
    // - только на тренировке отправителя
    // ─────────────────────────────────────────────────────────────────────────
    if (currentUserId == activityOwnerId) {
      return const SizedBox.shrink();
    }

    final state = ref.watch(togetherInviteStatusProvider(activityId));

    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dto) {
        if (!dto.hasPending) return const SizedBox.shrink();
        if (dto.inviteId == null || dto.senderId == null) {
          return const SizedBox.shrink();
        }
        if (dto.senderId != activityOwnerId) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.getBorderColor(context),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () async {
                          onDismiss();
                          try {
                            final api = ref.read(togetherApiProvider);
                            await api.respondInvite(
                              inviteId: dto.inviteId!,
                              accept: true,
                            );
                          } finally {
                            // ────────────────────────────────────────────
                            // Обновляем локальные данные
                            // ────────────────────────────────────────────
                            ref.invalidate(
                              togetherInviteStatusProvider(activityId),
                            );
                            ref.invalidate(togetherMembersProvider(activityId));
                            ref.invalidate(
                              togetherCandidatesProvider(activityId),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? AppColors.surface
                              : AppColors.getSurfaceColor(context),
                          elevation: 0,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Принять',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () async {
                          onDismiss();
                          try {
                            final api = ref.read(togetherApiProvider);
                            await api.respondInvite(
                              inviteId: dto.inviteId!,
                              accept: false,
                            );
                          } finally {
                            ref.invalidate(
                              togetherInviteStatusProvider(activityId),
                            );
                            ref.invalidate(
                              togetherCandidatesProvider(activityId),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.getBorderColor(context),
                          ),
                          foregroundColor: AppColors.getTextPrimaryColor(
                            context,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Отменить',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ───────────────────────────── ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ─────────────────────

/// ────────────────────────────────────────────────────────────────
/// 🔹 ПЛАШКА ЧАСОВ: временно закомментирована
/// ────────────────────────────────────────────────────────────────
// /// Плашка «часы» — визуально как плашка «обувь», НО без кнопки «…»
// class _WatchPill extends StatelessWidget {
//   final String asset;
//   final String title;
//   const _WatchPill({required this.asset, required this.title});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 56,
//       decoration: ShapeDecoration(
//         // ────────────────────────────────────────────────────────────────
//         // 🌓 ТЕМНАЯ ТЕМА: фон плашки часов такой же, как у плашки кроссовок
//         // ────────────────────────────────────────────────────────────────
//         // В темной теме используем darkSurfaceMuted (как у плашки кроссовок)
//         // В светлой теме оставляем getBackgroundColor (не трогаем)
//         color: Theme.of(context).brightness == Brightness.dark
//             ? AppColors.darkSurfaceMuted
//             : AppColors.getBackgroundColor(context),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(AppRadius.xxl),
//         ),
//       ),
//       child: Stack(
//         children: [
//           Positioned(
//             left: 3,
//             top: 3,
//             bottom: 3,
//             child: Container(
//               width: 50,
//               height: 50,
//               decoration: ShapeDecoration(
//                 image: DecorationImage(
//                   image: AssetImage(asset),
//                   fit: BoxFit.fill,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(AppRadius.xxl),
//                 ),
//               ),
//             ),
//           ),
//           Positioned(
//             left: 60,
//             top: 0,
//             bottom: 0,
//             child: Align(
//               alignment: Alignment.centerLeft,
//               child: Text(
//                 title,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: AppTextStyles.h13w5.copyWith(
//                   color: AppColors.getTextPrimaryColor(context),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

/// Таблица «Отрезки» — на всю ширину, белый фон с тонкими линиями
/// Использует реальные данные из Garmin Connect (pacePerKm и heartRatePerKm)
///
/// Как проверить наличие данных о сегментах:
/// 1. В логах (developer.log) будет видно количество сегментов
/// 2. Используйте stats?.hasSplitsData() для проверки наличия данных
/// 3. Используйте stats?.splitsCount для получения количества сегментов
// ignore: unintended_html_in_doc_comment
/// 4. Данные приходят из API в формате Map<String, double>:
///    - pacePerKm: {"1": 355.0, "2": 333.0, ...} (секунды на километр)
///    - heartRatePerKm: {"1": 128.0, "2": 135.0, ...} (пульс в bpm)
///    - Для типа "run": pacePerKm может быть в формате {"km_1": 5.7, ...} где 5.7 = 5:42 мин/км
class _SplitsTableFull extends StatelessWidget {
  final al.ActivityStats? stats;
  final String activityType;

  const _SplitsTableFull({this.stats, required this.activityType});

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // Определяем, является ли это плаванием
    // ────────────────────────────────────────────────────────────────
    final isSwimming = activityType.toLowerCase() == 'swimming' ||
        activityType.toLowerCase() == 'swim';

    // ────────────────────────────────────────────────────────────────
    // Извлекаем данные о сегментах из stats
    // pacePerKm и heartRatePerKm — это Map<String, double>
    // где ключи — номера километров ("1", "2", "3" и т.д.)
    // Для типа "run" ключи могут быть в формате "km_1", "km_2" и т.д.
    // Для плавания: ключи в формате "km_1", "km_3", "km_5" означают отрезки по 100м (100м, 300м, 500м)
    // ────────────────────────────────────────────────────────────────
    var pacePerKm = stats?.pacePerKm ?? <String, double>{};
    var heartRatePerKm = stats?.heartRatePerKm ?? <String, double>{};

    // ────────────────────────────────────────────────────────────────
    // Для типов "run" и "ski" преобразуем ключи из "km_1" в "1"
    // Для плавания также нормализуем ключи, но темп пересчитаем на 100м
    // ────────────────────────────────────────────────────────────────
    if (activityType == 'run' ||
        activityType == 'ski' ||
        activityType == 'indoor-running' ||
        activityType == 'walking' ||
        activityType == 'hiking' ||
        isSwimming) {
      final normalizedPacePerKm = <String, double>{};
      final normalizedHeartRatePerKm = <String, double>{};

      pacePerKm.forEach((key, value) {
        // Убираем префикс "km_" если он есть
        final normalizedKey = key.startsWith('km_') ? key.substring(3) : key;
        if (isSwimming) {
          // Для плавания: темп указан на километр, пересчитываем на 100м
          // Если значение < 100, это формат минут (24.6 = 24:36 мин/км)
          // Сначала переводим в секунды, потом делим на 10
          if (value < 100) {
            // Формат минут: переводим в секунды, затем делим на 10
            final minutes = value.floor();
            final seconds = ((value - minutes) * 60).round();
            final totalSeconds = minutes * 60 + seconds;
            normalizedPacePerKm[normalizedKey] = totalSeconds / 10.0;
          } else {
            // Уже в секундах, просто делим на 10
            normalizedPacePerKm[normalizedKey] = value / 10.0;
          }
        } else {
          normalizedPacePerKm[normalizedKey] = value;
        }
      });

      heartRatePerKm.forEach((key, value) {
        // Убираем префикс "km_" если он есть
        final normalizedKey = key.startsWith('km_') ? key.substring(3) : key;
        normalizedHeartRatePerKm[normalizedKey] = value;
      });

      pacePerKm = normalizedPacePerKm;
      heartRatePerKm = normalizedHeartRatePerKm;
    }

    // ────────────────────────────────────────────────────────────────
    // Если данных нет, показываем пустую таблицу с заголовками
    // ────────────────────────────────────────────────────────────────
    if (pacePerKm.isEmpty && heartRatePerKm.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    isSwimming ? 'М' : 'Км',
                    style: AppTextStyles.h12w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    'Темп',
                    style: AppTextStyles.h12w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Пульс',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.h12w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getBorderColor(context),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Нет данных о сегментах',
                  style: AppTextStyles.h13w4.copyWith(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
                if (stats == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Статистика тренировки недоступна',
                      style: AppTextStyles.h12w4.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Garmin Connect не передал данные о сегментах',
                      style: AppTextStyles.h12w4.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // ────────────────────────────────────────────────────────────────
    // Собираем все ключи (номера километров) и сортируем их
    // Для типа "run" ключи уже нормализованы (без префикса "km_")
    // ────────────────────────────────────────────────────────────────
    final allKeys = <String>{...pacePerKm.keys, ...heartRatePerKm.keys};
    final sortedKeys = allKeys.toList()
      ..sort((a, b) {
        // Сортируем по числовому значению ключа
        // Убираем суффикс "_partial" если есть для правильной сортировки
        final aClean = a.replaceAll('_partial', '');
        final bClean = b.replaceAll('_partial', '');
        final aNum = int.tryParse(aClean) ?? 0;
        final bNum = int.tryParse(bClean) ?? 0;
        if (aNum != bNum) {
          return aNum.compareTo(bNum);
        }
        // Если числа равны, то "_partial" идет после обычного
        if (a.contains('_partial') && !b.contains('_partial')) return 1;
        if (!a.contains('_partial') && b.contains('_partial')) return -1;
        return a.compareTo(b);
      });

    if (sortedKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    // ────────────────────────────────────────────────────────────────
    // Находим самый быстрый темп для нормализации визуальных полос
    // Для типа "run" значения в формате минут (5.7 = 5:42), для других — секунды
    // Для плавания: темп уже пересчитан на 100м (в секундах)
    // ────────────────────────────────────────────────────────────────
    final paceValues = sortedKeys
        .map((k) => pacePerKm[k] ?? 0.0)
        .where((v) => v > 0)
        .toList();

    // Для типов "run" и "ski" конвертируем минуты в секунды для сравнения
    // Для плавания: темп уже в секундах на 100м, используем как есть
    final paceValuesForComparison =
        (activityType == 'run' || activityType == 'ski' || activityType == 'indoor-running' || activityType == 'walking' || activityType == 'hiking')
        ? paceValues
              .map(
                (v) => (v.floor() * 60 + ((v - v.floor()) * 60).round())
                    .toDouble(),
              )
              .toList()
        : paceValues;

    // ────────────────────────────────────────────────────────────────
    // Находим самый быстрый темп (минимальное значение в секундах)
    // У самого быстрого темпа полоска будет на всю ширину (1.0)
    // ────────────────────────────────────────────────────────────────
    final fastestPace = paceValuesForComparison.isEmpty
        ? 1.0
        : paceValuesForComparison.reduce((a, b) => a < b ? a : b);

    // ────────────────────────────────────────────────────────────────
    // Форматирование темпа
    // Для типов "run" и "ski": значение в формате минут (5.7 = 5:42 мин/км)
    // Для других типов: значение в секундах, форматируем как ММ:СС
    // ────────────────────────────────────────────────────────────────
    String fmtPace(double paceValue) {
      if (paceValue <= 0) return '-';

      if (activityType == 'run' || activityType == 'ski' || activityType == 'indoor-running' || activityType == 'walking' || activityType == 'hiking') {
        // Формат: 5.7 означает 5 минут и 7 десятых от минуты = 5:42 мин/км
        final minutes = paceValue.floor();
        final seconds = ((paceValue - minutes) * 60).round();
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      } else {
        // Для других типов: значение в секундах
        final s = paceValue.round();
        final m = s ~/ 60;
        final r = s % 60;
        return '$m:${r.toString().padLeft(2, '0')}';
      }
    }

    return Column(
      children: [
        // ───── Заголовок столбцов
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  isSwimming ? 'М' : 'Км',
                  style: AppTextStyles.h12w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  'Темп',
                  style: AppTextStyles.h12w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
              SizedBox(
                width: 40,
                child: Text(
                  'Пульс',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.h12w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.getBorderColor(context),
        ),

        // ───── Строки данных из реальных данных Garmin Connect
        ...List.generate(sortedKeys.length, (i) {
          final kmKey = sortedKeys[i];
          final paceValue = pacePerKm[kmKey] ?? 0.0;
          final hr = heartRatePerKm[kmKey] ?? 0.0;

          // ────────────────────────────────────────────────────────────────
          // Вычисляем долю для визуальной полосы темпа
          // Чем быстрее темп (меньше секунд), тем длиннее полоса
          // Используем пропорцию: fastestPace / paceSecForVisual
          // Самый быстрый темп (fastestPace) будет иметь полоску на всю ширину (1.0)
          // Для типов "run" и "ski" конвертируем минуты в секунды для сравнения
          // Для плавания: темп уже пересчитан на 100м (в секундах), используем как есть
          // ────────────────────────────────────────────────────────────────
          final paceSecForVisual =
              (activityType == 'run' || activityType == 'ski' || activityType == 'indoor-running' || activityType == 'walking' || activityType == 'hiking')
              ? (paceValue.floor() * 60 +
                        ((paceValue - paceValue.floor()) * 60).round())
                    .toDouble()
              : paceValue;
          final visualFrac = paceSecForVisual > 0 && fastestPace > 0
              ? (fastestPace / paceSecForVisual).clamp(0.05, 1.0)
              : 0.05;

          // Форматируем ключ для отображения (убираем "_partial" если есть)
          final displayKey = kmKey.replaceAll('_partial', '');
          // Для плавания: отображаем метры без буквы "м" (100, 200, 300 и т.д.)
          final displayText = isSwimming
              ? '${(int.tryParse(displayKey) ?? 0) * 100}'
              : displayKey;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        displayText,
                        style: AppTextStyles.h12w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        fmtPace(paceValue),
                        style: AppTextStyles.h12w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, c) => Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.skeletonBase,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                            Container(
                              width: c.maxWidth * visualFrac,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        hr > 0 ? hr.round().toString() : '-',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.h12w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (i != sortedKeys.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.getBorderColor(context),
                ),
            ],
          );
        }),
      ],
    );
  }
}

/// Простой линейный график:
/// - Для «Темп» ось Y — ММ:СС (мин/км или мин/100м для плавания), данные храним в сек/км или сек/100м;
/// - Ось X — километры 0..N (где N — количество точек) или метры для плавания;
/// - Для «Пульс»/«Высота»/«Мощность» — обычные числа.
/// - Единицы измерения на оси Y НЕ отображаем.
class _SimpleLineChart extends StatefulWidget {
  final int mode; // 0 pace, 1 hr, 2 elev, 3 watts
  final List<double> paceData;
  final List<double> heartRateData;
  final List<double> elevationData;
  final List<double> wattsData;
  final List<int> paceLabels; // Метки для оси X (в метрах для плавания, в км для остальных)
  final bool isSwimming; // Флаг, что это плавание

  const _SimpleLineChart({
    required this.mode,
    required this.paceData,
    required this.heartRateData,
    required this.elevationData,
    this.wattsData = const [],
    this.paceLabels = const [],
    this.isSwimming = false,
  });

  @override
  State<_SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<_SimpleLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    List<double> y;
    bool isPace;

    if (widget.mode == 0) {
      // Темп: секунд/км -> будем форматировать как мин/км
      y = widget.paceData.isNotEmpty ? widget.paceData : [];
      isPace = true;
    } else if (widget.mode == 1) {
      // Пульс
      y = widget.heartRateData.isNotEmpty ? widget.heartRateData : [];
      isPace = false;
    } else if (widget.mode == 2) {
      // Высота
      y = widget.elevationData.isNotEmpty ? widget.elevationData : [];
      isPace = false;
    } else {
      // Мощность (watts)
      y = widget.wattsData.isNotEmpty ? widget.wattsData : [];
      isPace = false;
    }

    // Если данных нет, показываем пустой график
    if (y.isEmpty) {
      return Center(
        child: Text(
          'Нет данных для отображения',
          style: AppTextStyles.h13w4.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // xMax = число километров (точек). Подписываем 0..xMax (включительно).
    // Для плавания: xMax = количество точек - 1 (индексы от 0 до length-1)
    // Для остальных: xMax = количество точек
    final xMax = (widget.isSwimming && widget.mode == 0 && y.length > 0)
        ? y.length - 1
        : y.length;

    return GestureDetector(
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final painter = _LinePainter(
          yValues: y,
          paceMode: isPace,
          xMax: xMax,
          chartMode: widget.mode,
          textSecondaryColor: AppColors.getTextSecondaryColor(context),
          borderColor: AppColors.getBorderColor(context),
          selectedIndex: _selectedIndex,
          paceLabels: widget.paceLabels,
          isSwimming: widget.isSwimming,
        );
        final tappedIndex = painter.getTappedIndex(localPosition, box.size);
        if (mounted) {
          setState(() {
            // Если кликнули по той же точке, снимаем выделение
            _selectedIndex = tappedIndex == _selectedIndex ? null : tappedIndex;
          });
        }
      },
      child: CustomPaint(
        painter: _LinePainter(
          yValues: y,
          paceMode: isPace,
          xMax: xMax,
          chartMode: widget.mode,
          textSecondaryColor: AppColors.getTextSecondaryColor(context),
          borderColor: AppColors.getBorderColor(context),
          selectedIndex: _selectedIndex,
          paceLabels: widget.paceLabels,
          isSwimming: widget.isSwimming,
        ),
        willChange: false,
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> yValues; // для Темпа — секунды/км или сек/100м для плавания
  final bool paceMode; // true -> формат ММ:СС
  final int xMax; // количество км (точек), рисуем подписи 0..xMax
  final int chartMode; // 0 = Темп, 1 = Пульс, 2 = Высота, 3 = Мощность
  final Color textSecondaryColor; // цвет текста для подписей осей
  final Color borderColor; // цвет границы для сетки
  final int? selectedIndex; // индекс выбранной точки
  final List<int> paceLabels; // Метки для оси X (в метрах для плавания, в км для остальных)
  final bool isSwimming; // Флаг, что это плавание

  _LinePainter({
    required this.yValues,
    required this.paceMode,
    required this.xMax,
    required this.chartMode,
    required this.textSecondaryColor,
    required this.borderColor,
    this.selectedIndex,
    this.paceLabels = const [],
    this.isSwimming = false,
  });

  /// Получает цвет линии графика в зависимости от режима
  /// 0 = Темп (brandPrimary), 1 = Пульс (female), 2 = Высота (accentMint), 3 = Мощность (warning)
  Color get lineColor {
    switch (chartMode) {
      case 0:
        return AppColors.brandPrimary;
      case 1:
        return AppColors.female;
      case 2:
        return AppColors.accentMint;
      case 3:
        return AppColors.warning; // Оранжевый для мощности
      default:
        return AppColors.brandPrimary;
    }
  }

  String _fmtSecToMinSec(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  /// Определяет, какая точка была нажата по координатам
  int? getTappedIndex(Offset localPosition, Size size) {
    if (yValues.isEmpty) return null;

    const left = 36.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 38.0;
    final chartW = size.width - left - right;
    final chartH = size.height - top - bottom;

    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs() < 1e-6 ? 1 : (maxY - minY);

    final n = yValues.length;
    final dx = n > 1 ? chartW / (n - 1) : 0;

    for (int i = 0; i < n; i++) {
      final cx = n > 1 ? left + dx * i : left + chartW / 2;
      final frac = (yValues[i] - minY) / range;
      // ────────────────────────────────────────────────────────────────
      // Для темпа переворачиваем ось Y: меньшие значения (быстрый темп) сверху
      // Инверсия: быстрый темп (minY) → сверху, медленный темп (maxY) → снизу
      // Для темпа: frac=0 (minY) → cy=top (сверху), frac=1 (maxY) → cy=top+chartH (снизу)
      // ────────────────────────────────────────────────────────────────
      final cy = paceMode
          ? top +
                frac *
                    chartH // Инверсия: frac=0 (minY) → top, frac=1 (maxY) → top+chartH
          : size.height - bottom - frac * chartH;

      final pointRadius = selectedIndex == i ? 6.0 : 4.0;
      final distanceToPoint = (localPosition - Offset(cx, cy)).distance;

      // Увеличиваем область клика для удобства
      if (distanceToPoint <= pointRadius + 10) {
        return i;
      }
    }

    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Используем borderColor для сетки (как в профиле)
    final paintGrid = Paint()
      ..color = borderColor
      ..strokeWidth = 0.5;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Заливка под линией (как в профиле)
    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    // Точки на линии
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // Точка выбранная (больше размером)
    final selectedPointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    // Паддинги для осей и подписей
    const left = 36.0;
    const bottom = 38.0; // место под подписи км
    const top = 8.0;
    const right = 8.0;

    final w = size.width - left - right;
    final h = size.height - top - bottom;

    if (yValues.isEmpty || w <= 0 || h <= 0) return;

    // Нормализация Y
    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs() < 1e-6 ? 1 : (maxY - minY);

    // Горизонтальные линии сетки (как в профиле)
    const gridY = 5;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= gridY; i++) {
      final y = top + h * (i / gridY);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), paintGrid);
    }

    // Подписи оси Y — единицу измерения НЕ рисуем
    // ────────────────────────────────────────────────────────────────
    // Для темпа переворачиваем: minY (быстрый темп) сверху, maxY (медленный) снизу
    // Рисуем подписи для всех линий сетки (5 подписей)
    // ────────────────────────────────────────────────────────────────
    final tpYStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: textSecondaryColor,
    );
    // Генерируем 5 значений для подписей (соответствуют линиям сетки)
    for (int i = 0; i <= gridY; i++) {
      final frac = i / gridY;
      // ────────────────────────────────────────────────────────────────
      // Для темпа переворачиваем: minY (быстрый темп) сверху, maxY (медленный) снизу
      // Для обычных графиков: maxY сверху, minY снизу
      // ────────────────────────────────────────────────────────────────
      final val = paceMode
          ? minY +
                (maxY - minY) *
                    frac // Для темпа: frac=0 → minY (быстрый, верх), frac=1 → maxY (медленный, низ)
          : minY +
                (maxY - minY) *
                    (1 -
                        frac); // Для обычных: frac=0 → maxY (верх), frac=1 → minY (низ)
      final ly = top + h * frac;
      final txt = paceMode ? _fmtSecToMinSec(val) : val.toStringAsFixed(0);
      tp.text = TextSpan(text: txt, style: tpYStyle);
      tp.layout();
      tp.paint(canvas, Offset(left - tp.width - 6, ly - tp.height / 2));
    }

    // Линия графика и заливка
    final dx = yValues.length > 1 ? w / (yValues.length - 1) : 0;
    final path = ui.Path();
    final fillPath = ui.Path();

    for (int i = 0; i < yValues.length; i++) {
      final nx = yValues.length > 1 ? left + dx * i : left + w / 2;
      // ────────────────────────────────────────────────────────────────
      // Для темпа переворачиваем ось Y: меньшие значения (быстрый темп) сверху
      // Инверсия: быстрый темп (minY) → сверху, медленный темп (maxY) → снизу
      // Для темпа: frac=0 (minY) → ny=top (сверху), frac=1 (maxY) → ny=top+h (снизу)
      // ────────────────────────────────────────────────────────────────
      final frac = (yValues[i] - minY) / range;
      final ny = paceMode ? top + h * frac : top + h * (1 - frac);

      if (i == 0) {
        path.moveTo(nx, ny);
        fillPath.moveTo(nx, size.height - bottom);
        fillPath.lineTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
        fillPath.lineTo(nx, ny);
      }
    }

    // Замыкаем путь заливки
    if (yValues.isNotEmpty) {
      final lastNx = yValues.length > 1
          ? left + dx * (yValues.length - 1)
          : left + w / 2;
      fillPath.lineTo(lastNx, size.height - bottom);
      fillPath.close();
    }

    // Рисуем заливку под линией (как в профиле)
    canvas.drawPath(fillPath, fillPaint);

    // Рисуем линию графика
    canvas.drawPath(path, paintLine);

    // Рисуем точки на линии (как в профиле)
    for (int i = 0; i < yValues.length; i++) {
      final nx = yValues.length > 1 ? left + dx * i : left + w / 2;
      // ────────────────────────────────────────────────────────────────
      // Для темпа переворачиваем ось Y: меньшие значения (быстрый темп) сверху
      // Инверсия: быстрый темп (minY) → сверху, медленный темп (maxY) → снизу
      // Для темпа: frac=0 (minY) → ny=top (сверху), frac=1 (maxY) → ny=top+h (снизу)
      // ────────────────────────────────────────────────────────────────
      final frac = (yValues[i] - minY) / range;
      final ny = paceMode ? top + h * frac : top + h * (1 - frac);

      final isSelected = selectedIndex == i;
      final pointRadius = isSelected ? 6.0 : 4.0;
      final paint = isSelected ? selectedPointPaint : pointPaint;

      // Рисуем точку
      canvas.drawCircle(Offset(nx, ny), pointRadius, paint);

      // Если точка выбрана, рисуем вертикальную линию и метку
      if (isSelected) {
        // Вертикальная линия до оси X
        final verticalLinePaint = Paint()
          ..color = lineColor
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(nx, ny),
          Offset(nx, size.height - bottom),
          verticalLinePaint,
        );

        // Метка над точкой с значением
        final value = yValues[i];
        final valueText = paceMode
            ? _fmtSecToMinSec(value)
            : value.toStringAsFixed(0);
        tp.text = TextSpan(
          text: valueText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: lineColor,
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(nx - tp.width / 2, ny - tp.height - 8));
      }
    }

    // Подписи X (0..xMax) — без вертикальных линий
    // Если точек больше 20, пропускаем подписи для лучшей читаемости
    // Для плавания используем метки в метрах из paceLabels
    final tpXStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: textSecondaryColor,
    );

    // Для плавания используем метки из paceLabels (в метрах)
    if (isSwimming && paceLabels.isNotEmpty && paceLabels.length == yValues.length) {
      // Определяем шаг для подписей в зависимости от количества точек
      final step = xMax <= 20
          ? 1
          : xMax <= 40
          ? 2
          : xMax <= 60
          ? 3
          : xMax <= 80
          ? 4
          : xMax <= 100
          ? 5
          : (xMax / 10).ceil();

      // Всегда показываем первую и последнюю подпись
      final lastIndex = xMax > 0 ? xMax : 0;
      final labelsToShow = <int>{0};
      if (lastIndex > 0) {
        labelsToShow.add(lastIndex);
      }

      // Добавляем промежуточные подписи с учетом шага
      for (int k = step; k < lastIndex; k += step) {
        labelsToShow.add(k);
      }

      // Сортируем и рисуем подписи с метками в метрах
      final sortedLabels = labelsToShow.toList()..sort();
      for (final k in sortedLabels) {
        if (k < paceLabels.length && lastIndex > 0) {
          final x = left + w * (k / lastIndex);
          final labelValue = paceLabels[k];
          final span = TextSpan(text: '$labelValueм', style: tpXStyle);
          tp.text = span;
          tp.layout();
          tp.paint(canvas, Offset(x - tp.width / 2, top + h + 6));
        }
      }
    } else {
      // Для остальных типов: используем индексы (километры)
      // Определяем шаг для подписей в зависимости от количества точек
      // Цель: показать примерно 10-15 подписей максимум
      final step = xMax <= 20
          ? 1
          : xMax <= 40
          ? 2
          : xMax <= 60
          ? 3
          : xMax <= 80
          ? 4
          : xMax <= 100
          ? 5
          : (xMax / 10).ceil();

      // Всегда показываем первую (0) и последнюю (xMax) подпись
      final labelsToShow = <int>{0, xMax};

      // Добавляем промежуточные подписи с учетом шага
      for (int k = step; k < xMax; k += step) {
        labelsToShow.add(k);
      }

      // Сортируем и рисуем подписи
      final sortedLabels = labelsToShow.toList()..sort();
      for (final k in sortedLabels) {
        final x = left + w * (k / xMax);
        final span = TextSpan(text: '$k', style: tpXStyle);
        tp.text = span;
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, top + h + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.yValues != yValues ||
      old.paceMode != paceMode ||
      old.xMax != xMax ||
      old.chartMode != chartMode ||
      old.textSecondaryColor != textSecondaryColor ||
      old.borderColor != borderColor ||
      old.selectedIndex != selectedIndex ||
      old.paceLabels != paceLabels ||
      old.isSwimming != isSwimming;
}

/// ────────────────────────────────────────────────────────────────
/// 🎬 FADE-IN: плавное появление контента после загрузки (opacity 0 → 1)
/// ────────────────────────────────────────────────────────────────
class _FadeInWidget extends StatefulWidget {
  final Widget child;

  const _FadeInWidget({required this.child});

  @override
  State<_FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<_FadeInWidget> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: widget.child,
    );
  }
}

/// ────────────────────────────────────────────────────────────────
/// 📊 ЗАГОЛОВОК С МЕТРИКАМИ: отображает ключевые метрики над графиком
/// В стиле скриншотов: два значения по центру с подписями
/// ────────────────────────────────────────────────────────────────
class _ChartMetricsHeader extends StatelessWidget {
  final int mode; // 0 pace, 1 hr, 2 elev, 3 watts
  final Map<String, dynamic>? summary;

  /// При true — индикатор загрузки вместо прочерков в блоке метрик
  final bool isLoading;

  const _ChartMetricsHeader({
    required this.mode,
    this.summary,
    this.isLoading = false,
  });

  String _fmtSecToMinSec(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ЗАГОЛОВОК ГРАФИКА: слева вверху
    // ────────────────────────────────────────────────────────────────
    String getTitle() {
      switch (mode) {
        case 0:
          return 'Темп';
        case 1:
          return 'Пульс';
        case 2:
          return 'Высота';
        case 3:
          return 'Мощность';
        default:
          return '';
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ИКОНКА ГРАФИКА: слева от заголовка
    // ────────────────────────────────────────────────────────────────
    IconData getIcon() {
      switch (mode) {
        case 0:
          return Icons.speed;
        case 1:
          return CupertinoIcons.heart;
        case 2:
          return Icons.landscape;
        case 3:
          return CupertinoIcons.bolt; // Иконка молнии для мощности
        default:
          return CupertinoIcons.chart_bar;
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ЦВЕТ ИКОНКИ: в зависимости от типа графика
    // ────────────────────────────────────────────────────────────────
    Color getIconColor() {
      switch (mode) {
        case 0:
          return AppColors.brandPrimary;
        case 1:
          return AppColors.female;
        case 2:
          return AppColors.accentMint;
        case 3:
          return AppColors.warning; // Оранжевый для мощности
        default:
          return AppColors.getTextPrimaryColor(context);
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ВИДЖЕТ ДЛЯ ОТОБРАЖЕНИЯ МЕТРИКИ: большое значение и подпись
    // ────────────────────────────────────────────────────────────────
    Widget metricItem(String value, String label, {Widget? icon}) {
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.h18w6.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
              if (icon != null) ...[const SizedBox(width: 4), icon],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.h12w4.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ВИДЖЕТ С МЕТРИКАМИ: по центру справа.
    // При isLoading — индикатор загрузки вместо прочерков.
    // ────────────────────────────────────────────────────────────────
    Widget buildMetrics() {
      if (isLoading) {
        return Center(
          child: CupertinoActivityIndicator(
            radius: 10,
            color: AppColors.getIconSecondaryColor(context),
          ),
        );
      }
      if (summary == null) {
        // Если данных нет, показываем пустые значения
        if (mode == 0) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Ср. темп'),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. темп'),
            ],
          );
        } else if (mode == 1) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem(
                '—',
                'Пульс',
                icon: const Icon(
                  CupertinoIcons.heart_fill,
                  size: 16,
                  color: AppColors.female,
                ),
              ),
              const SizedBox(width: 64),
              metricItem(
                '—',
                'Макс. пульс',
                icon: const Icon(
                  CupertinoIcons.heart_fill,
                  size: 16,
                  color: AppColors.female,
                ),
              ),
            ],
          );
        } else if (mode == 2) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Мин. высота'),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. высота'),
            ],
          );
        } else {
          // Мощность: Ср. мощность и Макс. мощность
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Ср. мощность'),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. мощность'),
            ],
          );
        }
      }

      if (mode == 0) {
        // Темп: Ср. темп и Макс. темп (самый быстрый = минимальное время)
        final paceSummary = summary!['pace'] as Map<String, dynamic>?;
        if (paceSummary == null) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Ср. темп'),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. темп'),
            ],
          );
        }

        final average = paceSummary['average'] as num?;
        final fastest = paceSummary['fastest'] as num?;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            metricItem(
              average != null ? _fmtSecToMinSec(average.toDouble()) : '—',
              'Ср. темп',
            ),
            const SizedBox(width: 64),
            metricItem(
              fastest != null ? _fmtSecToMinSec(fastest.toDouble()) : '—',
              'Макс. темп',
            ),
          ],
        );
      } else if (mode == 1) {
        // Пульс: Пульс и Макс. пульс
        final hrSummary = summary!['heartRate'] as Map<String, dynamic>?;
        final heartIcon = const Icon(
          CupertinoIcons.heart_fill,
          size: 12,
          color: AppColors.error,
        );
        if (hrSummary == null) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Пульс', icon: heartIcon),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. пульс', icon: heartIcon),
            ],
          );
        }

        final average = hrSummary['average'] as num?;
        final max = hrSummary['max'] as num?;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            metricItem(
              average != null ? '${average.round()}' : '—',
              'Ср. пульс',
              icon: heartIcon,
            ),
            const SizedBox(width: 64),
            metricItem(
              max != null ? '${max.round()}' : '—',
              'Макс. пульс',
              icon: heartIcon,
            ),
          ],
        );
      } else if (mode == 2) {
        // Высота: Мин. высота и Макс. высота
        final elevSummary = summary!['elevation'] as Map<String, dynamic>?;
        if (elevSummary == null) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Мин. высота'),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. высота'),
            ],
          );
        }

        final min = elevSummary['min'] as num?;
        final max = elevSummary['max'] as num?;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            metricItem(
              min != null ? min.toStringAsFixed(1) : '—',
              'Мин. высота',
            ),
            const SizedBox(width: 64),
            metricItem(
              max != null ? max.toStringAsFixed(1) : '—',
              'Макс. высота',
            ),
          ],
        );
      } else {
        // Мощность: Ср. мощность и Макс. мощность
        final wattsSummary = summary!['watts'] as Map<String, dynamic>?;
        if (wattsSummary == null) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              metricItem('—', 'Ср. мощность'),
              const SizedBox(width: 64),
              metricItem('—', 'Макс. мощность'),
            ],
          );
        }

        final average = wattsSummary['average'] as num?;
        final max = wattsSummary['max'] as num?;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            metricItem(
              average != null ? '${average.round()}' : '—',
              'Ср. мощность',
            ),
            const SizedBox(width: 64),
            metricItem(
              max != null ? '${max.round()}' : '—',
              'Макс. мощность',
            ),
          ],
        );
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 СТРУКТУРА: заголовок на отдельной строке, метрики ниже по центру
    // ────────────────────────────────────────────────────────────────
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с иконкой на первой строке
          Row(
            children: [
              // Иконка без кружка для всех типов графиков
              Icon(getIcon(), size: 22, color: getIconColor()),
              const SizedBox(width: 8),
              Text(
                getTitle(),
                style: AppTextStyles.h17w6.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Метрики по центру на второй строке
          Center(child: buildMetrics()),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────
/// 🎨 КНОПКА-ИКОНКА: иконка для AppBar без фонового кружка
/// Плавно меняет цвет при скролле: от светлого (на карте) к темному (в AppBar)
/// ────────────────────────────────────────────────────────────────────
class _CircleAppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isScrolled;
  final double fadeOpacity; // Плавное изменение цвета иконки при скролле
  const _CircleAppIcon({
    required this.icon,
    required this.isScrolled,
    required this.fadeOpacity,
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Цвет иконки: плавно переходим от светлого (на карте) к темному
    // (в AppBar) с самого начала скролла
    final lightIcon = AppColors.getSurfaceColor(context);
    final darkIcon = AppColors.getIconPrimaryColor(context);
    final iconColor = Color.lerp(
      lightIcon,
      darkIcon,
      (1 - fadeOpacity.clamp(0.0, 1.0)),
    );

    return SizedBox(
      width: 46.0,
      height: 44.0,
      child: GestureDetector(
        onTap: onPressed ?? () {},
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}
