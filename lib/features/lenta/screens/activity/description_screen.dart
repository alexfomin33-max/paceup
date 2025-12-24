// lib/screens/lenta/widgets/activity_description_block.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui; // для ui.Path
import 'package:latlong2/latlong.dart' as ll;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
// Берём готовые виджеты (чтобы совпадал верх с ActivityBlock)
import '../widgets/activity/header/activity_header.dart';
import '../widgets/activity/stats/stats_row.dart';
import '../widgets/activity/equipment/equipment_chip.dart'
    as ab
    show EquipmentChip;
// Карусель маршрута с фотографиями
import '../../widgets/activity_route_carousel.dart';
// Модель — через алиас, чтобы не конфликтовало имя Equipment
import '../../../../domain/models/activity_lenta.dart' as al;
import 'combining_screen.dart';
import 'fullscreen_route_map_screen.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/services/api_service.dart';
import '../../providers/lenta_provider.dart';

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
  int _chartTab = 0; // 0=Темп, 1=Пульс, 2=Высота

  // Данные пользователя (владельца тренировки)
  String? _userFirstName;
  String? _userLastName;
  String? _userAvatar;
  bool _isLoadingUserData = true;

  // ────────────────────────────────────────────────────────────────
  // 📦 ЛОКАЛЬНОЕ СОСТОЯНИЕ: храним обновленную активность после замены экипировки
  // ────────────────────────────────────────────────────────────────
  al.Activity? _updatedActivity;

  // ────────────────────────────────────────────────────────────────
  // 📊 ДАННЫЕ ДЛЯ ГРАФИКОВ: темп, пульс, высота по километрам
  // ────────────────────────────────────────────────────────────────
  List<double> _paceData = [];
  List<double> _heartRateData = [];
  List<double> _elevationData = [];
  bool _isLoadingCharts = true;
  
  // Сводка данных для отображения под графиками
  Map<String, dynamic>? _chartsSummary;

  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChartsData();
  }

  /// Загружает данные пользователя (владельца тренировки) из базы данных
  Future<void> _loadUserData() async {
    final activityUserId = widget.activity.userId;
    if (activityUserId <= 0) {
      setState(() {
        _isLoadingUserData = false;
      });
      return;
    }

    try {
      final data = await _api.post(
        '/get_user_info.php',
        body: {'user_id': activityUserId.toString()},
        timeout: const Duration(seconds: 10),
      );

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
    } catch (e) {
      // В случае ошибки используем данные из Activity как fallback
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  /// Загружает данные для графиков (темп, пульс, высота по километрам)
  Future<void> _loadChartsData() async {
    final activityId = widget.activity.id;
    if (activityId <= 0) {
      setState(() {
        _isLoadingCharts = false;
      });
      return;
    }

    try {
      final data = await _api.post(
        '/get_activity_charts.php',
        body: {'activity_id': activityId.toString()},
        timeout: const Duration(seconds: 10),
      );

      if (data['ok'] == true) {
        setState(() {
          // Преобразуем массивы в List<double>
          _paceData = (data['pace'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              [];
          _heartRateData = (data['heartRate'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              [];
          _elevationData = (data['elevation'] as List<dynamic>?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              [];
          _chartsSummary = data['summary'] as Map<String, dynamic>?;
          _isLoadingCharts = false;
        });
      } else {
        // Если ошибка, оставляем пустые данные
        setState(() {
          _isLoadingCharts = false;
        });
      }
    } catch (e) {
      // В случае ошибки оставляем пустые данные
      setState(() {
        _isLoadingCharts = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final a = _currentActivity;
    final stats = a.stats;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Тренировка',
          showBottomDivider:
              false, // чтобы не было двойной линии со следующим блоком
          actions: [
            IconButton(
              splashRadius: 22,
              icon: Icon(
                CupertinoIcons.personalhotspot,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  TransparentPageRoute(builder: (_) => const CombiningScreen()),
                );
              },
            ),
            IconButton(
              splashRadius: 22,
              icon: Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              onPressed: () {},
            ),
          ],
        ),

        body: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
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
                      // Шапка: аватар, имя, дата, метрики (как в ActivityBlock)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ActivityHeader(
                          userId:
                              widget.activity.userId, // ID владельца тренировки
                          userName: _isLoadingUserData
                              ? (a.userName.isNotEmpty ? a.userName : 'Аноним')
                              : (_userFirstName != null && _userLastName != null
                                    ? '$_userFirstName $_userLastName'.trim()
                                    : (_userFirstName?.isNotEmpty == true
                                          ? _userFirstName!
                                          : (_userLastName?.isNotEmpty == true
                                                ? _userLastName!
                                                : (a.userName.isNotEmpty
                                                      ? a.userName
                                                      : 'Аноним')))),
                          userAvatar: _isLoadingUserData
                              ? a.userAvatar
                              : (_userAvatar?.isNotEmpty == true
                                    ? _userAvatar!
                                    : a.userAvatar),
                          dateStart: a.dateStart,
                          dateTextOverride: a.postDateText,
                          bottom: StatsRow(
                            distanceMeters: stats?.distance,
                            durationSec: stats?.duration,
                            elevationGainM: stats?.cumulativeElevationGain,
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
                          ),
                          bottomGap: 16.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ───────── Карта маршрута с фотографиями (как в ActivityBlock)
              // Показываем только если есть точки маршрута или есть изображения
              // Высота 350
              if (a.points.isNotEmpty || a.mediaImages.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: ActivityRouteCarousel(
                    points: a.points
                        .map((c) => ll.LatLng(c.lat, c.lng))
                        .toList(),
                    imageUrls: a.mediaImages,
                    height: 350,
                    // ────────────────────────────────────────────────────────────────
                    // 🔹 ОТКРЫТИЕ ПОЛНОЭКРАННОЙ КАРТЫ: при клике на слайд с картой
                    // ────────────────────────────────────────────────────────────────
                    onMapTap: a.points.isNotEmpty
                        ? () {
                            Navigator.of(context).push(
                              TransparentPageRoute(
                                builder: (context) => FullscreenRouteMapScreen(
                                  points: a.points
                                      .map((c) => ll.LatLng(c.lat, c.lng))
                                      .toList(),
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                // ────────────────────────────────────────────────────────────────
                // 📦 ЭКИПИРОВКА: на всю ширину экрана, вплотную под блоком с маршрутом
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
                      showMenuButton:
                          true, // показываем кнопку меню для замены экипировки
                      onEquipmentChanged: _refreshActivityAfterEquipmentChange,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],

              // ───────── «Отрезки» — таблица на всю ширину экрана
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: Text(
                        'Отрезки',
                        style: AppTextStyles.h15w5.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    _SplitsTableFull(stats: stats, activityType: a.type),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ───────── Сегменты — как в communication_prefs.dart (вынесены отдельно)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: _SegmentedPill(
                      left: 'Темп',
                      center: 'Пульс',
                      right: 'Высота',
                      value: _chartTab,
                      onChanged: (v) => setState(() => _chartTab = v),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ───────── ЕДИНЫЙ блок: график + сводка темпа
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 210,
                          width: double.infinity,
                          child: _isLoadingCharts
                              ? const Center(child: CircularProgressIndicator())
                              : _SimpleLineChart(
                                  mode: _chartTab,
                                  paceData: _paceData,
                                  heartRateData: _heartRateData,
                                  elevationData: _elevationData,
                                ),
                        ),
                        const SizedBox(height: 6),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.getBorderColor(context),
                        ),
                        const SizedBox(height: 4),
                        _ChartSummary(
                          mode: _chartTab,
                          summary: _chartsSummary,
                        ), // подписи с данными в зависимости от вкладки
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
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
    // Извлекаем данные о сегментах из stats
    // pacePerKm и heartRatePerKm — это Map<String, double>
    // где ключи — номера километров ("1", "2", "3" и т.д.)
    // Для типа "run" ключи могут быть в формате "km_1", "km_2" и т.д.
    // ────────────────────────────────────────────────────────────────
    var pacePerKm = stats?.pacePerKm ?? <String, double>{};
    var heartRatePerKm = stats?.heartRatePerKm ?? <String, double>{};

    // ────────────────────────────────────────────────────────────────
    // Для типа "run" преобразуем ключи из "km_1" в "1"
    // ────────────────────────────────────────────────────────────────
    if (activityType == 'run') {
      final normalizedPacePerKm = <String, double>{};
      final normalizedHeartRatePerKm = <String, double>{};

      pacePerKm.forEach((key, value) {
        // Убираем префикс "km_" если он есть
        final normalizedKey = key.startsWith('km_') ? key.substring(3) : key;
        normalizedPacePerKm[normalizedKey] = value;
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
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          border: Border(
            top: BorderSide(color: AppColors.getBorderColor(context), width: 1),
            bottom: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      'Км',
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
        ),
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
    // ────────────────────────────────────────────────────────────────
    final paceValues = sortedKeys
        .map((k) => pacePerKm[k] ?? 0.0)
        .where((v) => v > 0)
        .toList();

    // Для типа "run" конвертируем минуты в секунды для сравнения
    final paceValuesForComparison = activityType == 'run'
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
    // Для типа "run": значение в формате минут (5.7 = 5:42 мин/км)
    // Для других типов: значение в секундах, форматируем как ММ:СС
    // ────────────────────────────────────────────────────────────────
    String fmtPace(double paceValue) {
      if (paceValue <= 0) return '-';

      if (activityType == 'run') {
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border(
          top: BorderSide(color: AppColors.getBorderColor(context), width: 1),
          bottom: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // ───── Заголовок столбцов
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    'Км',
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
            // Для типа "run" конвертируем минуты в секунды для сравнения
            // ────────────────────────────────────────────────────────────────
            final paceSecForVisual = activityType == 'run'
                ? (paceValue.floor() * 60 +
                          ((paceValue - paceValue.floor()) * 60).round())
                      .toDouble()
                : paceValue;
            final visualFrac = paceSecForVisual > 0 && fastestPace > 0
                ? (fastestPace / paceSecForVisual).clamp(0.05, 1.0)
                : 0.05;

            // Форматируем ключ для отображения (убираем "_partial" если есть)
            final displayKey = kmKey.replaceAll('_partial', '');

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          displayKey,
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
      ),
    );
  }
}

/// Переключатель-пилюля (3 сегмента) — стиль как в communication_prefs.dart
class _SegmentedPill extends StatelessWidget {
  final String left;
  final String center;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;

  const _SegmentedPill({
    required this.left,
    required this.center,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _seg(0, left)),
            Expanded(child: _seg(1, center)),
            Expanded(child: _seg(2, right)),
          ],
        ),
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => onChanged(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.getTextPrimaryColor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected
                    ? AppColors.getSurfaceColor(context)
                    : AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Простой линейный график:
/// - Для «Темп» ось Y — ММ:СС (мин/км), данные храним в сек/км;
/// - Ось X — километры 0..N (где N — количество точек);
/// - Для «Пульс»/«Высота» — обычные числа.
/// - Единицы измерения на оси Y НЕ отображаем.
class _SimpleLineChart extends StatelessWidget {
  final int mode; // 0 pace, 1 hr, 2 elev
  final List<double> paceData;
  final List<double> heartRateData;
  final List<double> elevationData;
  
  const _SimpleLineChart({
    required this.mode,
    required this.paceData,
    required this.heartRateData,
    required this.elevationData,
  });

  @override
  Widget build(BuildContext context) {
    List<double> y;
    bool isPace;

    if (mode == 0) {
      // Темп: секунд/км -> будем форматировать как мин/км
      y = paceData.isNotEmpty ? paceData : [];
      isPace = true;
    } else if (mode == 1) {
      // Пульс
      y = heartRateData.isNotEmpty ? heartRateData : [];
      isPace = false;
    } else {
      // Высота
      y = elevationData.isNotEmpty ? elevationData : [];
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
    final xMax = y.length;

    return CustomPaint(
      painter: _LinePainter(
        yValues: y,
        paceMode: isPace,
        xMax: xMax,
        textSecondaryColor: AppColors.getTextSecondaryColor(context),
      ),
      willChange: false,
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> yValues; // для Темпа — секунды/км
  final bool paceMode; // true -> формат ММ:СС
  final int xMax; // количество км (точек), рисуем подписи 0..xMax
  final Color textSecondaryColor; // цвет текста для подписей осей

  _LinePainter({
    required this.yValues,
    required this.paceMode,
    required this.xMax,
    required this.textSecondaryColor,
  });

  String _fmtSecToMinSec(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Используем статические цвета для графика (brandPrimary и skeletonBase не зависят от темы)
    final paintGrid = Paint()
      ..color = AppColors.skeletonBase
      ..strokeWidth = 1;

    final paintLine = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Паддинги для осей и подписей — уменьшили left, чтобы график стал шире
    const left = 36.0; // было 48.0
    const bottom = 38.0; // место под подписи км
    const top = 8.0;
    const right = 8.0;

    final w = size.width - left - right;
    final h = size.height - top - bottom;

    if (yValues.isEmpty || w <= 0 || h <= 0) return;

    // Горизонтальные линии (Y)
    const gridY = 5;
    for (int i = 0; i <= gridY; i++) {
      final y = top + h * (i / gridY);
      canvas.drawLine(Offset(left, y), Offset(left + w, y), paintGrid);
    }

    // Вертикальные линии + подписи X (0..xMax)
    final tpXStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: textSecondaryColor,
    );
    for (int k = 0; k <= xMax; k++) {
      final x = left + w * (k / xMax);
      canvas.drawLine(Offset(x, top), Offset(x, top + h), paintGrid);

      final span = TextSpan(text: '$k', style: tpXStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, top + h + 6));
    }

    // Нормализация Y
    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs() < 1e-6 ? 1 : (maxY - minY);

    // Линия графика
    final dx = w / (yValues.length - 1);
    final path = ui.Path();
    for (int i = 0; i < yValues.length; i++) {
      final nx = left + dx * i;
      final ny = top + h * (1 - (yValues[i] - minY) / range);
      if (i == 0) {
        path.moveTo(nx, ny);
      } else {
        path.lineTo(nx, ny);
      }
    }
    canvas.drawPath(path, paintLine);

    // Подписи оси Y (max, mid, min) — единицу измерения НЕ рисуем
    final tpYStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: textSecondaryColor,
    );
    final labels = <double>[maxY, minY + (maxY - minY) * 0.5, minY];
    for (int i = 0; i < labels.length; i++) {
      final val = labels[i];
      final ly = i == 0 ? top : (i == 1 ? top + h / 2 : top + h);
      final txt = paceMode ? _fmtSecToMinSec(val) : val.toStringAsFixed(0);
      final span = TextSpan(text: txt, style: tpYStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, ly - tp.height / 2));
    }

    // (удалено) Единицы измерения у оси Y — не рисуем по задаче
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.yValues != yValues ||
      old.paceMode != paceMode ||
      old.xMax != xMax ||
      old.textSecondaryColor != textSecondaryColor;
}

/// Подписи к графику — в одном блоке с графиком
/// Отображает данные в зависимости от выбранной вкладки (темп, пульс, высота)
class _ChartSummary extends StatelessWidget {
  final int mode; // 0 pace, 1 hr, 2 elev
  final Map<String, dynamic>? summary;
  
  const _ChartSummary({
    required this.mode,
    this.summary,
  });

  String _fmtSecToMinSec(double sec) {
    final s = sec.round();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String name, String val) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            Text(
              val,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ],
        ),
      );
    }

    if (summary == null) {
      // Если данных нет, показываем пустые значения
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            row('—', '—'),
            row('—', '—'),
            if (mode == 0) row('—', '—'),
          ],
        ),
      );
    }

    if (mode == 0) {
      // Темп
      final paceSummary = summary!['pace'] as Map<String, dynamic>?;
      if (paceSummary == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              row('Самый быстрый', '—'),
              row('Средний темп', '—'),
              row('Самый медленный', '—'),
            ],
          ),
        );
      }

      final fastest = paceSummary['fastest'] as num?;
      final average = paceSummary['average'] as num?;
      final slowest = paceSummary['slowest'] as num?;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            row(
              'Самый быстрый',
              fastest != null ? '${_fmtSecToMinSec(fastest.toDouble())} /км' : '—',
            ),
            row(
              'Средний темп',
              average != null ? '${_fmtSecToMinSec(average.toDouble())} /км' : '—',
            ),
            row(
              'Самый медленный',
              slowest != null ? '${_fmtSecToMinSec(slowest.toDouble())} /км' : '—',
            ),
          ],
        ),
      );
    } else if (mode == 1) {
      // Пульс
      final hrSummary = summary!['heartRate'] as Map<String, dynamic>?;
      if (hrSummary == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              row('Минимальный', '—'),
              row('Средний', '—'),
              row('Максимальный', '—'),
            ],
          ),
        );
      }

      final min = hrSummary['min'] as num?;
      final average = hrSummary['average'] as num?;
      final max = hrSummary['max'] as num?;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            row(
              'Минимальный',
              min != null ? '${min.round()} уд/мин' : '—',
            ),
            row(
              'Средний',
              average != null ? '${average.round()} уд/мин' : '—',
            ),
            row(
              'Максимальный',
              max != null ? '${max.round()} уд/мин' : '—',
            ),
          ],
        ),
      );
    } else {
      // Высота
      final elevSummary = summary!['elevation'] as Map<String, dynamic>?;
      if (elevSummary == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              row('Минимальная', '—'),
              row('Максимальная', '—'),
            ],
          ),
        );
      }

      final min = elevSummary['min'] as num?;
      final max = elevSummary['max'] as num?;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            row(
              'Минимальная',
              min != null ? '${min.round()} м' : '—',
            ),
            row(
              'Максимальная',
              max != null ? '${max.round()} м' : '—',
            ),
          ],
        ),
      );
    }
  }
}
