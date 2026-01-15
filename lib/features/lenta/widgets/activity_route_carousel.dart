// lib/widgets/activity_route_carousel.dart
import 'package:flutter/cupertino.dart';
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
  const ActivityRouteCarousel({
    super.key,
    required this.points,
    required this.imageUrls,
    this.height = 240,
    this.onMapTap,
    this.mapSortOrder,
    this.activityId,
    this.userId,
  });

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Проверяем кеш сервиса синхронно (если есть в кеше - используем сразу)
    if (widget.activityId != null && widget.points.isNotEmpty) {
      final cachedUrl = _routeMapService.getCachedRouteMapUrl(widget.activityId!);
      if (cachedUrl != null) {
        _savedRouteMapUrl = cachedUrl;
      } else {
        // Если нет в кеше - проверяем сервер в фоне для следующей загрузки
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
  /// Не блокирует UI - используется только для кеширования на будущее
  Future<void> _checkSavedRouteMapInBackground() async {
    if (widget.activityId == null) return;

    try {
      final savedUrl = await _routeMapService.getRouteMapUrl(widget.activityId!);
      // URL сохраняется в кеш сервиса автоматически
      // При следующей загрузке виджета он будет использован из кеша
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
                bottom: _dotsBottom,
                left: 0,
                right: 0,
                child: _buildDots(widget.imageUrls.length),
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
          // 🔘 ИНДИКАТОРЫ: точки внизу для навигации
          // ────────────────────────────────────────────────────────────────
          if (totalSlides > 1)
            Positioned(
              bottom: _dotsBottom,
              left: 0,
              right: 0,
              child: _buildDots(totalSlides),
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
  /// - Кеширование через CachedNetworkImage с memCacheWidth/maxWidthDiskCache
  /// - Placeholder и error widgets для улучшения UX
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
              child: const Center(
                child: CupertinoActivityIndicator(),
              ),
            );
          }

          final dpr = MediaQuery.of(context).devicePixelRatio;
          final screenW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final screenH = widget.height;

          // ────────────────────────────────────────────────────────────────
          // 🔹 ОПТИМИЗАЦИЯ РАЗМЕРА: используем ограниченный DPR для уменьшения веса файла
          // ────────────────────────────────────────────────────────────────
          // Для карточек в ленте достаточно DPR 1.5-2.0 вместо полного devicePixelRatio
          // Это уменьшает размер файла в 2-4 раза без заметной потери качества
          // Например, вместо 3x (iPhone) используем 2x
          final optimizedDpr = (dpr > 2.0 ? 2.0 : dpr).clamp(1.0, 2.0);

          // Генерируем размеры с учетом оптимизированного DPR
          final widthPx = (screenW * optimizedDpr).round();
          final heightPx = (screenH * optimizedDpr).round();

          // Проверяем, что размеры валидны
          if (widthPx <= 0 || heightPx <= 0) {
            return Container(
              color: AppColors.getSurfaceColor(context),
              child: const Center(
                child: CupertinoActivityIndicator(),
              ),
            );
          }

          // ────────────────────────────────────────────────────────────────
          // 🔹 ЛОГИКА ОТОБРАЖЕНИЯ КАРТЫ:
          // 1. При первой загрузке: генерируем Mapbox URL и показываем сразу
          // 2. При повторной загрузке: если есть в кеше - используем сохраненное
          // 3. Сохранение на сервер происходит в фоне после загрузки Mapbox изображения
          // ────────────────────────────────────────────────────────────────
          String mapUrl;
          bool shouldSaveAfterLoad = false;
          bool useSavedImage = false;

          // Проверяем наличие сохраненного изображения в кеше (проверено синхронно в initState)
          if (_savedRouteMapUrl != null) {
            // Используем сохраненное изображение с сервера
            mapUrl = _savedRouteMapUrl!;
            useSavedImage = true;
          } else {
            // При первой загрузке генерируем через Mapbox и показываем сразу
            mapUrl = StaticMapUrlBuilder.fromPoints(
              points: widget.points,
              widthPx: widthPx.toDouble(),
              heightPx: heightPx.toDouble(),
              strokeWidth: 3.0,
              padding: 12.0,
            );
            
            // Сохраняем изображение на сервер в фоне после успешной загрузки
            // (не блокируя UI, не вызывая перерисовку)
            if (widget.activityId != null && widget.userId != null) {
              shouldSaveAfterLoad = true;
            }
          }

          return CachedNetworkImage(
            imageUrl: mapUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
            memCacheWidth: widthPx,
            maxWidthDiskCache: widthPx,
            placeholder: (context, url) => Container(
              color: AppColors.getSurfaceColor(context),
              child: const Center(
                child: CupertinoActivityIndicator(),
              ),
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
            // Сохраняем изображение на сервер после успешной загрузки (только если не используем сохраненное)
            imageBuilder: shouldSaveAfterLoad && !useSavedImage
                ? (context, imageProvider) {
                    // Сохраняем изображение асинхронно в фоне, не блокируя UI
                    _saveRouteMapImage(mapUrl);
                    return Image(image: imageProvider);
                  }
                : null,
          );
        },
      ),
    );
  }

  /// Сохраняет изображение карты маршрута на сервер в фоне
  /// Не вызывает перерисовку - URL сохраняется в кеш сервиса для следующей загрузки
  Future<void> _saveRouteMapImage(String mapboxUrl) async {
    if (widget.activityId == null || widget.userId == null) return;
    
    // Проверяем, что изображение еще не сохранено
    if (_savedRouteMapUrl != null) return;

    try {
      // Сохраняем изображение на сервер в фоне
      // URL автоматически сохраняется в кеш сервиса для следующей загрузки
      await _routeMapService.saveRouteMapFromUrl(
        activityId: widget.activityId!,
        userId: widget.userId!,
        mapboxUrl: mapboxUrl,
      );
      
      // НЕ обновляем состояние - не вызываем перерисовку
      // При следующей загрузке виджета URL будет взят из кеша сервиса
    } catch (e) {
      // Игнорируем ошибки сохранения (не критично)
    }
  }

  /// Строит слайд с фотографией.
  Widget _buildPhotoSlide(String imageUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final screenW = constraints.maxWidth;
        final targetW = (screenW * dpr).round();

        return CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          filterQuality: FilterQuality.low,
          memCacheWidth: targetW,
          maxWidthDiskCache: targetW,
          placeholder: (context, url) => Container(
            color: AppColors.disabled,
            child: const Center(
              child: CupertinoActivityIndicator(),
            ),
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
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Строит индикаторы точек внизу карусели.
  Widget _buildDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentIndex == index
                  ? AppColors.brandPrimary
                  : AppColors.brandPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),
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
