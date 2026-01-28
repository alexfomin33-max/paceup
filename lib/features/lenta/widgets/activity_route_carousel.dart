// lib/widgets/activity_route_carousel.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/utils/static_map_url_builder.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/route_map_service.dart';

/// Карусель маршрута с фотографиями для активности.
/// Карта и фотографии отображаются в порядке, указанном в mapSortOrder.
///
/// ⚡ PERFORMANCE OPTIMIZATION:
/// - Использует сохраненные изображения карт с сервера вместо генерации через Mapbox
/// - Если изображение не найдено, генерирует через Mapbox и сохраняет на сервер
/// - Использует статичные PNG картинки вместо Mapbox GL для устранения jank
/// - Кеширование через CachedNetworkImage снижает повторные запросы
/// - Упрощение полилинии уменьшает размер URL и ускоряет генерацию
class ActivityRouteCarousel extends StatefulWidget {
  /// Точки трека в порядке следования.
  final List<LatLng> points;

  /// Список URL фотографий активности.
  final List<String> imageUrls;

  /// Высота карусели (по умолчанию 240).
  final double height;

  /// Callback для клика на карту (вызывается только при клике на слайд с картой).
  final VoidCallback? onMapTap;

  /// Позиция карты в общем списке (изображения + карта).
  /// Если null, карта идет первой (для обратной совместимости).
  final int? mapSortOrder;

  /// ID активности (для получения сохраненного изображения карты).
  /// Если не указан, карта будет генерироваться через Mapbox без сохранения.
  final int? activityId;

  /// ID пользователя (для сохранения изображения карты на сервер).
  /// Если не указан, карта будет генерироваться через Mapbox без сохранения.
  final int? userId;

  /// Позиция индикаторов свайпа: true - сверху, false - снизу (по умолчанию).
  final bool dotsOnTop;

  /// Показывать ли градиентное затемнение сверху: true - показывать (по умолчанию), false - скрыть.
  final bool showTopGradient;

  const ActivityRouteCarousel({
    super.key,
    required this.points,
    required this.imageUrls,
    this.height = 240,
    this.onMapTap,
    this.mapSortOrder,
    this.activityId,
    this.userId,
    this.dotsOnTop = false,
    this.showTopGradient = true,
  });

  @override
  State<ActivityRouteCarousel> createState() => _ActivityRouteCarouselState();
}

class _ActivityRouteCarouselState extends State<ActivityRouteCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  String? _savedRouteMapUrl;
  bool _isLoadingRouteMap = false;
  final RouteMapService _routeMapService = RouteMapService();

  static const _dotsBottom = 10.0;
  static const _dotsTop = 10.0;

  // ────────────────────────────────────────────────────────────────
  // ⚡ КЭШИРОВАНИЕ URL КАРТЫ: генерируем один раз вместо каждого rebuild
  // ────────────────────────────────────────────────────────────────
  // Это устраняет джанк при скролле, так как кодирование полилинии
  // и формирование URL выполняется только один раз при первом build
  String? _cachedMapUrl;
  int? _cachedWidthPx;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // ────────────────────────────────────────────────────────────────
    // ✅ ПРОВЕРКА КЕША И СЕРВЕРА: проверяем синхронно кеш, затем сервер
    // ────────────────────────────────────────────────────────────────
    if (widget.activityId != null && widget.points.isNotEmpty) {
      // Проверяем кеш сервиса синхронно (если есть в кеше - используем сразу)
      final cachedUrl = _routeMapService.getCachedRouteMapUrl(
        widget.activityId!,
      );
      if (cachedUrl != null) {
        _savedRouteMapUrl = cachedUrl;
      } else {
        // ────────────────────────────────────────────────────────────────
        // ✅ ПРИОРИТЕТНАЯ ПРОВЕРКА СЕРВЕРА: проверяем сервер сразу, не ждем
        // Это важно для правильного отображения карты при открытии из профиля
        // ────────────────────────────────────────────────────────────────
        // Проверяем сервер асинхронно и обновляем состояние сразу после получения
        // Используем unawaited для немедленного запуска без ожидания
        _checkSavedRouteMapInBackground();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Проверяет наличие сохраненного изображения карты маршрута в фоне
  /// Обновляет состояние виджета, если карта найдена на сервере
  /// Вызывается сразу при initState для быстрой загрузки карты
  Future<void> _checkSavedRouteMapInBackground() async {
    if (widget.activityId == null) return;

    try {
      // ────────────────────────────────────────────────────────────────
      // ✅ ПРИОРИТЕТНАЯ ПРОВЕРКА: проверяем сервер сразу при инициализации
      // Это важно для правильного отображения карты при открытии из профиля
      // ────────────────────────────────────────────────────────────────
      final savedUrl = await _routeMapService.getRouteMapUrl(
        widget.activityId!,
      );
      // ────────────────────────────────────────────────────────────────
      // ✅ ОБНОВЛЯЕМ СОСТОЯНИЕ: если карта найдена на сервере, используем её
      // Это устраняет задержку и улучшает отображение карты
      // ────────────────────────────────────────────────────────────────
      if (savedUrl != null && mounted) {
        // Обновляем состояние сразу после получения URL
        // Это переключит карту с Mapbox на сохраненное изображение
        setState(() {
          _savedRouteMapUrl = savedUrl;
        });
      }
    } catch (e) {
      // Игнорируем ошибки проверки в фоне
    }
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 📍 ЛОГИКА ОТОБРАЖЕНИЯ: карта только если есть точки маршрута
    // ────────────────────────────────────────────────────────────────

    // Если нет точек маршрута и нет фотографий — ничего не показываем
    if (widget.points.isEmpty && widget.imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    // Если нет точек маршрута, но есть фотографии — показываем только фотографии
    if (widget.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              allowImplicitScrolling: false,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                // Очищаем кэш изображений, которые далеко от текущего
                final evictIndex = index - 2;
                if (evictIndex >= 0 && evictIndex < widget.imageUrls.length) {
                  _evictNetworkImage(widget.imageUrls[evictIndex]);
                }
              },
              itemBuilder: (context, index) {
                return _buildPhotoSlide(widget.imageUrls[index]);
              },
            ),
            // Индикаторы точек, если фотографий больше одной
            if (widget.imageUrls.length > 1)
              Positioned(
                top: widget.dotsOnTop ? _dotsTop : null,
                bottom: widget.dotsOnTop ? null : _dotsBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildDots(
                    widget.imageUrls.length,
                    isPhotosOnly: true,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Если есть точки маршрута, но нет фотографий — показываем только статичную карту
    if (widget.imageUrls.isEmpty) {
      return GestureDetector(
        onTap: widget.onMapTap,
        child: _buildStaticMapSlide(),
      );
    }

    // Если есть и точки, и фотографии — показываем карусель с картой и фотографиями
    // Определяем позицию карты в общем списке
    // Если mapSortOrder == null, карта идет после всех изображений (для обратной совместимости)
    final mapPosition = widget.mapSortOrder ?? widget.imageUrls.length;
    final totalSlides = 1 + widget.imageUrls.length;

    // Создаем список элементов для отображения
    final List<_CarouselItem> items = [];
    for (int i = 0; i < widget.imageUrls.length; i++) {
      items.add(_CarouselItem.image(widget.imageUrls[i], i));
    }
    // Вставляем карту в нужную позицию
    final insertIndex = mapPosition.clamp(0, items.length);
    items.insert(insertIndex, _CarouselItem.map());

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ────────────────────────────────────────────────────────────────
          // 📱 КАРУСЕЛЬ: PageView со статичной картой и фотографиями
          // ────────────────────────────────────────────────────────────────
          PageView.builder(
            key: const PageStorageKey('activity_route_carousel'),
            controller: _pageController,
            itemCount: totalSlides,
            allowImplicitScrolling: false,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              // Очищаем кэш изображений, которые далеко от текущего
              final evictIndex = index - 2;
              if (evictIndex >= 0 && evictIndex < items.length) {
                final item = items[evictIndex];
                if (item.isImage) {
                  _evictNetworkImage(item.imageUrl!);
                }
              }
            },
            itemBuilder: (context, index) {
              final item = items[index];

              if (item.isMap) {
                return GestureDetector(
                  onTap: widget.onMapTap,
                  child: _buildStaticMapSlide(),
                );
              } else {
                return _buildPhotoSlide(item.imageUrl!);
              }
            },
          ),

          // ────────────────────────────────────────────────────────────────
          // 🔘 ИНДИКАТОРЫ: точки для навигации (сверху или снизу в зависимости от dotsOnTop)
          // ────────────────────────────────────────────────────────────────
          if (totalSlides > 1)
            Positioned(
              top: widget.dotsOnTop ? _dotsTop : null,
              bottom: widget.dotsOnTop ? null : _dotsBottom,
              left: 0,
              right: 0,
              child: Center(child: _buildDots(totalSlides, items: items)),
            ),
        ],
      ),
    );
  }

  /// Строит слайд со статичной картой маршрута.
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION:
  /// - Сначала проверяет наличие сохраненного изображения на сервере
  /// - Если изображение найдено, использует его (быстрее загрузка)
  /// - Если не найдено, генерирует через Mapbox и сохраняет на сервер
  /// - Использует кэшированный URL вместо генерации при каждом rebuild
  /// - Кеширование через CachedNetworkImage с memCacheWidth/maxWidthDiskCache
  /// - Placeholder и error widgets для улучшения UX
  ///
  /// ⚡ КЭШИРОВАНИЕ URL: URL генерируется один раз при первом вызове,
  /// что устраняет джанк при скролле (кодирование полилинии выполняется только один раз)
  Widget _buildStaticMapSlide() {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasValidSize =
              constraints.maxWidth > 0 && constraints.maxHeight > 0;

          // Если размер невалидный, показываем placeholder
          if (!hasValidSize) {
            return Container(
              color: AppColors.getSurfaceColor(context),
              child: const Center(child: CupertinoActivityIndicator()),
            );
          }

          // ────────────────────────────────────────────────────────────────
          // ⚡ КЭШИРОВАНИЕ URL: генерируем только один раз при первом build
          // ────────────────────────────────────────────────────────────────
          // Если URL еще не сгенерирован - генерируем и кэшируем
          // При последующих rebuild используем кэшированный URL
          if (_cachedMapUrl == null) {
            // Используем фиксированный DPR = 2.0 для оптимизации
            const double fixedDpr = 2.0;

            final screenW = constraints.maxWidth;
            final screenH = widget.height;

            // Генерируем размеры с учетом фиксированного DPR
            final widthPx = (screenW * fixedDpr).round();
            final heightPx = (screenH * fixedDpr).round();

            // Проверяем, что размеры валидны
            if (widthPx > 0 && heightPx > 0) {
              // Генерируем URL статичной карты один раз и кэшируем
              _cachedMapUrl = StaticMapUrlBuilder.fromPoints(
                points: widget.points,
                widthPx: widthPx.toDouble(),
                heightPx: heightPx.toDouble(),
                strokeWidth: 3.0,
                padding: 12.0,
              );

              _cachedWidthPx = widthPx;
            }
          }

          // Если URL все еще не сгенерирован (не должно произойти)
          if (_cachedMapUrl == null || _cachedWidthPx == null) {
            return Container(
              color: AppColors.getSurfaceColor(context),
              child: const Center(child: CupertinoActivityIndicator()),
            );
          }

          // ────────────────────────────────────────────────────────────────
          // 🔹 ЛОГИКА ОТОБРАЖЕНИЯ КАРТЫ:
          // 1. Приоритетно используем сохраненное изображение с сервера (если есть)
          // 2. Если сохраненного нет - используем кэшированный Mapbox URL
          // 3. Сохранение на сервер происходит в фоне после загрузки Mapbox изображения
          // ────────────────────────────────────────────────────────────────
          // Определяем финальный URL для отображения
          final String finalMapUrl;
          final bool shouldSaveAfterLoad;
          final bool useSavedImage;

          // ────────────────────────────────────────────────────────────────
          // ✅ ПРОВЕРКА СОХРАНЕННОГО ИЗОБРАЖЕНИЯ: проверяем состояние и кеш
          // ────────────────────────────────────────────────────────────────
          // Проверяем наличие сохраненного изображения в кеше (проверено синхронно в initState)
          // Также проверяем кеш сервиса еще раз на случай, если состояние обновилось
          String? savedUrl = _savedRouteMapUrl;
          if (savedUrl == null && widget.activityId != null) {
            // Дополнительная проверка кеша сервиса (на случай, если состояние не обновилось)
            final cachedUrl = _routeMapService.getCachedRouteMapUrl(
              widget.activityId!,
            );
            if (cachedUrl != null) {
              // Обновляем состояние сразу, если нашли в кеше
              // Используем синхронное обновление для немедленного отображения
              _savedRouteMapUrl = cachedUrl;
              savedUrl = cachedUrl;
            }
          }

          if (savedUrl != null) {
            // Используем сохраненное изображение с сервера (приоритет)
            finalMapUrl = savedUrl;
            useSavedImage = true;
            shouldSaveAfterLoad = false; // Не нужно сохранять, уже сохранено
          } else {
            // Используем кэшированный Mapbox URL (избегаем перегенерации при каждом rebuild)
            finalMapUrl = _cachedMapUrl!;
            useSavedImage = false;
            // Сохраняем изображение на сервер в фоне после успешной загрузки
            // (не блокируя UI, не вызывая перерисовку)
            shouldSaveAfterLoad =
                widget.activityId != null && widget.userId != null;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: finalMapUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.medium,
                memCacheWidth: _cachedWidthPx!,
                maxWidthDiskCache: _cachedWidthPx!,
                placeholder: (context, url) => Container(
                  color: AppColors.getSurfaceColor(context),
                  child: const Center(child: CupertinoActivityIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.getSurfaceColor(context),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.map,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Карта недоступна',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // ────────────────────────────────────────────────────────────────
                // ✅ СОХРАНЕНИЕ КАРТЫ: сохраняем изображение на сервер после загрузки
                // Это нужно для ускорения последующих загрузок
                // ────────────────────────────────────────────────────────────────
                imageBuilder: shouldSaveAfterLoad && !useSavedImage
                    ? (context, imageProvider) {
                        // Сохраняем изображение асинхронно в фоне, не блокируя UI
                        // После сохранения обновляем состояние для использования сохраненного URL
                        _saveRouteMapImage(finalMapUrl).then((savedUrl) {
                          if (savedUrl != null && mounted) {
                            setState(() {
                              _savedRouteMapUrl = savedUrl;
                            });
                          }
                        });
                        return Image(image: imageProvider);
                      }
                    : null,
              ),
              // Градиентное затемнение сверху (только если showTopGradient = true)
              if (widget.showTopGradient)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: widget.height * 0.3,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.scrim40,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Сохраняет изображение карты маршрута на сервер в фоне
  /// Возвращает URL сохраненного изображения для обновления состояния
  Future<String?> _saveRouteMapImage(String mapboxUrl) async {
    if (widget.activityId == null || widget.userId == null) return null;

    // Проверяем, что изображение еще не сохранено
    if (_savedRouteMapUrl != null) return _savedRouteMapUrl;

    try {
      // Сохраняем изображение на сервер в фоне
      // URL автоматически сохраняется в кеш сервиса для следующей загрузки
      final savedUrl = await _routeMapService.saveRouteMapFromUrl(
        activityId: widget.activityId!,
        userId: widget.userId!,
        mapboxUrl: mapboxUrl,
      );

      return savedUrl;
    } catch (e) {
      // Игнорируем ошибки сохранения (не критично)
      return null;
    }
  }

  /// Строит слайд с фотографией.
  Widget _buildPhotoSlide(String imageUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ────────────────────────────────────────────────────────────────
        // ⚡ ОПТИМИЗАЦИЯ: используем фиксированный DPR = 2.0 вместо MediaQuery
        // ────────────────────────────────────────────────────────────────
        // Для фотографий в ленте фиксированный DPR 2.0 обеспечивает хорошее качество
        // на всех устройствах без запросов MediaQuery при каждом rebuild
        // Это снижает CPU usage и устраняет джанк при скролле
        const double fixedDpr = 2.0;
        final screenW = constraints.maxWidth;
        final targetW = (screenW * fixedDpr).round();

        return Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              filterQuality: FilterQuality.low,
              memCacheWidth: targetW,
              maxWidthDiskCache: targetW,
              placeholder: (context, url) => Container(
                color: AppColors.disabled,
                child: const Center(child: CupertinoActivityIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.disabled,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.photo,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Изображение недоступно',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            // Градиентное затемнение сверху (только если showTopGradient = true)
            if (widget.showTopGradient)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: widget.height * 0.3,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.scrim40,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Строит индикаторы точек снизу карусели.
  /// Если переданы items, определяет цвет по типу активного элемента:
  /// - темные точки для карты маршрута
  /// - светлые точки для фотографий
  Widget _buildDots(
    int total, {
    List<_CarouselItem>? items,
    bool isPhotosOnly = false,
  }) {
    // Определяем, карта ли сейчас активна
    final isCurrentMap =
        items != null &&
        _currentIndex < items.length &&
        items[_currentIndex].isMap;

    // Если только фотографии или текущий слайд - фото, используем светлые точки
    // Если текущий слайд - карта, используем темные точки
    final useLightDots = isPhotosOnly || !isCurrentMap;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scrim40.withValues(alpha: 0.25), // Более прозрачный фон
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(total, (index) {
          final isActive = _currentIndex == index;
          final color = useLightDots
              ? (isActive
                    ? AppColors.surface
                    : AppColors.surface.withValues(alpha: 0.3))
              : (isActive
                    ? AppColors.surface
                    : AppColors.surface.withValues(alpha: 0.3));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          );
        }),
      ),
    );
  }

  /// Очищает кэш изображения для освобождения памяти.
  void _evictNetworkImage(String url) {
    try {
      CachedNetworkImage.evictFromCache(url);
    } catch (e) {
      // Игнорируем ошибки очистки кэша
    }
  }
}

/// Вспомогательный класс для представления элемента карусели (изображение или карта)
class _CarouselItem {
  final String? imageUrl;
  final int? photoIndex;
  final bool isMap;

  _CarouselItem.image(this.imageUrl, this.photoIndex) : isMap = false;
  _CarouselItem.map() : imageUrl = null, photoIndex = null, isMap = true;

  bool get isImage => !isMap;
}
