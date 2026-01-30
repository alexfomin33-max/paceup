// lib/screens/lenta/activity/edit_activity_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_image_compressor.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/utils/static_map_url_builder.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../domain/models/activity_lenta.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../features/lenta/providers/lenta_provider.dart';
import '../../../../core/providers/form_state_provider.dart';
import '../../../../core/widgets/form_error_display.dart';

import '../widgets/activity/equipment/equipment_chip.dart';

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭКРАН РЕДАКТИРОВАНИЯ АКТИВНОСТИ
/// ────────────────────────────────────────────────────────────────
/// Позволяет редактировать:
/// 1. Фотографии тренировки (горизонтальная карусель)
/// 2. Описание тренировки (текстовое поле)
/// 3. Экипировку (такая же плашка, как в activity_block)
/// 4. Видимость тренировки (выпадающий список)
/// ────────────────────────────────────────────────────────────────
class EditActivityScreen extends ConsumerStatefulWidget {
  final Activity activity;
  final int currentUserId;

  const EditActivityScreen({
    super.key,
    required this.activity,
    required this.currentUserId,
  });

  @override
  ConsumerState<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends ConsumerState<EditActivityScreen> {
  // ────────────────────────────────────────────────────────────────
  // 📝 КОНТРОЛЛЕРЫ И СОСТОЯНИЕ
  // ────────────────────────────────────────────────────────────────
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocusNode;

  // Состояние видимости: 0 = Все пользователи, 1 = Только подписчики, 2 = Только Вы
  int _selectedVisibility = 0;

  // Список фотографий (для отображения в карусели)
  final List<String> _imageUrls = [];

  // Позиция карты в общем списке (null если карты нет)
  // Это индекс в объединенном списке (изображения + карта)
  int? _mapPosition;

  // Индекс перетаскиваемого элемента (изображения или карты)
  int? _draggedIndex;

  // Экипировка (для добавления, если не выбрана)
  List<Equipment> _availableEquipment = [];
  Equipment? _selectedEquipment;
  bool _isLoadingEquipment = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем название из активности (если есть, иначе пустая строка)
    _titleController = TextEditingController(
      text: widget.activity.postTitle,
    );
    _titleFocusNode = FocusNode();
    // Инициализируем описание из активности
    _descriptionController = TextEditingController(
      text: widget.activity.postContent,
    );
    _descriptionFocusNode = FocusNode();

    // Инициализируем фотографии
    _imageUrls.addAll(widget.activity.mediaImages);

    // Инициализируем позицию карты
    // Если есть маршрут, используем сохраненную позицию или по умолчанию после всех изображений
    final hasRoute = widget.activity.points.isNotEmpty;
    if (hasRoute) {
      // Используем сохраненную позицию из БД, если есть, иначе после всех изображений
      _mapPosition = widget.activity.mapSortOrder ?? _imageUrls.length;
    } else {
      _mapPosition = null;
    }

    // Инициализируем видимость из userGroup
    // Предполагаем: 0 = публичная, 1 = подписчики, 2 = только я
    _selectedVisibility = widget.activity.userGroup.clamp(0, 2);

    // Загружаем экипировку автоматически, если экипировка не выбрана и тип активности позволяет выбрать экипировку
    if (widget.activity.equipments.isEmpty && _shouldShowEquipment()) {
      _loadEquipment();
    }

    // Слушаем изменения для определения, есть ли изменения
    _titleController.addListener(_checkForChanges);
    _titleFocusNode.addListener(_checkForChanges);
    _descriptionController.addListener(_checkForChanges);
    _descriptionFocusNode.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  /// Проверяет, были ли внесены изменения
  void _checkForChanges() {
    final textChanged =
        _descriptionController.text.trim() !=
        widget.activity.postContent.trim();
    final visibilityChanged = _selectedVisibility != widget.activity.userGroup;

    // Проверяем, изменился ли порядок или количество фотографий
    final originalImages = widget.activity.mediaImages;
    final imagesChanged =
        _imageUrls.length != originalImages.length ||
        !_listsEqual(_imageUrls, originalImages);

    setState(() {
      // Отслеживаем изменения для возможного использования в будущем
      // ignore: unused_local_variable
      final hasChanges = textChanged || visibilityChanged || imagesChanged;
    });
  }

  /// Сравнивает два списка строк на равенство
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  // ────────────────────────────────────────────────────────────────
  // 🔹 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ДЛЯ ПЕРЕТАСКИВАНИЯ КАРТЫ И ФОТО
  // ────────────────────────────────────────────────────────────────

  bool get _hasRoute => widget.activity.points.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        resizeToAvoidBottomInset: false,
        appBar: const PaceAppBar(
          title: 'Редактирование',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: GestureDetector(
          // Скрываем клавиатуру при нажатии на пустую область
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Stack(
              children: [
                // ────────────────────────────────────────────────────────────────
                // 📜 ПРОКРУЧИВАЕМАЯ ОБЛАСТЬ С КОНТЕНТОМ
                // ────────────────────────────────────────────────────────────────
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          // ────────────────────────────────────────────────────────────────
                          // 📸 1. ФОТОГРАФИИ ТРЕНИРОВКИ (горизонтальная карусель)
                          // ────────────────────────────────────────────────────────────────
                          const Text(
                            'Фото тренировки',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPhotoCarousel(),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Перетащите, чтобы изменить порядок',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppColors.getTextTertiaryColor(context),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ────────────────────────────────────────────────────────────────
                          // 📝 2. НАЗВАНИЕ ТРЕНИРОВКИ
                          // ────────────────────────────────────────────────────────────────
                          const Text(
                            'Название тренировки',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTitleInput(),

                          const SizedBox(height: 30),

                          // ────────────────────────────────────────────────────────────────
                          // 📝 3. ОПИСАНИЕ ТРЕНИРОВКИ
                          // ────────────────────────────────────────────────────────────────
                          const Text(
                            'Описание тренировки',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDescriptionInput(),

                          // ────────────────────────────────────────────────────────────────
                          // 👟 4. ЭКИПИРОВКА
                          // ────────────────────────────────────────────────────────────────
                          Builder(
                            builder: (context) {
                              // Получаем обновленную активность из провайдера для проверки
                              final lentaState = ref.watch(
                                lentaProvider(widget.currentUserId),
                              );
                              final updatedActivity = lentaState.items
                                  .firstWhere(
                                    (a) => a.lentaId == widget.activity.lentaId,
                                    orElse: () => widget.activity,
                                  );

                              // Если экипировка уже выбрана, показываем EquipmentChip
                              if (updatedActivity.equipments.isNotEmpty) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 30),
                                    const Text(
                                      'Экипировка',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildEquipmentSection(),
                                  ],
                                );
                              }

                              // Если экипировка не выбрана и тип активности позволяет выбрать экипировку
                              if (_shouldShowEquipment()) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 30),
                                    const Text(
                                      'Экипировка',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildEquipmentSelectionSection(),
                                  ],
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),

                          const SizedBox(height: 30),

                          // ────────────────────────────────────────────────────────────────
                          // 👁️ 5. КТО ВИДИТ ТРЕНИРОВКУ (выпадающий список)
                          // ────────────────────────────────────────────────────────────────
                          const Text(
                            'Кто видит тренировку',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildVisibilitySelector(),

                          const SizedBox(height: 30),

                          // Показываем ошибки, если есть
                          Builder(
                            builder: (context) {
                              final formState = ref.watch(formStateProvider);
                              if (formState.hasErrors) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: FormErrorDisplay(formState: formState),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                      // Добавляем нижний отступ для контента перед плавающей кнопкой
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // ───────── Плавающая кнопка сохранения (стеклянный эффект)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: _buildSaveButton(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Горизонтальная карусель фотографий и карты
  /// Порядок: кнопка добавления фото → изображения и карта (в порядке сортировки)
  Widget _buildPhotoCarousel() {
    return Builder(
      builder: (context) {
        // ────────────────────────────────────────────────────────────────
        // 🔹 ВЫЧИСЛЕНИЕ ДИНАМИЧЕСКОГО РАЗМЕРА ЭЛЕМЕНТА
        // ────────────────────────────────────────────────────────────────
        // Размер вычисляется так, чтобы в одну линию на экране помещалось ровно 3 элемента
        // Учитываем: паддинг Column (16px с каждой стороны = 32px) и отступы между элементами (2 отступа по 12px = 24px)
        final screenWidth = MediaQuery.of(context).size.width;
        const horizontalPadding = 16.0 * 2; // Паддинг Column с двух сторон
        const separatorWidth = 12.0 * 2; // 2 отступа между 3 элементами
        final itemSize = (screenWidth - horizontalPadding - separatorWidth) / 3;

        final hasRoute = _hasRoute;

        // Преобразуем точки маршрута в LatLng для карты (если есть)
        final routePoints = hasRoute
            ? widget.activity.points.map((c) => LatLng(c.lat, c.lng)).toList()
            : <LatLng>[];

        // ────────────────────────────────────────────────────────────────
        // 🔹 СОЗДАНИЕ СПИСКА ЭЛЕМЕНТОВ С ОГРАНИЧЕНИЕМ В 3 ЭЛЕМЕНТА
        // ────────────────────────────────────────────────────────────────
        // Максимум 3 элемента в карусели: фотографии/карта + кнопка (если есть место)
        final List<_MediaItem> items = [];

        // Добавляем изображения
        for (int i = 0; i < _imageUrls.length; i++) {
          items.add(_MediaItem.image(_imageUrls[i], i));
          // Ограничиваем максимум 3 элементами (без кнопки)
          if (items.length >= 3) break;
        }

        // Добавляем карту, если есть маршрут (если еще есть место)
        if (hasRoute && _mapPosition != null && items.length < 3) {
          // Вставляем карту в нужную позицию, но не выходим за лимит
          final insertIndex = _mapPosition!.clamp(0, items.length);
          items.insert(insertIndex, _MediaItem.map());
          // Если после вставки карты стало больше 3 элементов, обрезаем
          if (items.length > 3) {
            items.removeRange(3, items.length);
          }
        }

        // Показываем кнопку добавления только если есть место (меньше 3 элементов)
        final showAddButton = items.length < 3;
        final totalItems = items.length + (showAddButton ? 1 : 0);

        return SizedBox(
          height:
              itemSize +
              6, // Размер элемента + padding сверху для кнопок удаления
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 6,
            ), // Добавляем padding сверху для кнопок удаления
            itemCount: totalItems,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // Сначала показываем элементы медиа (фотографии и карта)
              if (index < items.length) {
                final item = items[index];

                if (item.isMap) {
                  return _buildDraggableMapItem(routePoints, index, itemSize);
                } else {
                  return _buildDraggablePhotoItem(
                    item.imageUrl!,
                    item.photoIndex!,
                    index,
                    itemSize,
                  );
                }
              }

              // Если есть место (items.length < 3), последний элемент — кнопка добавления
              // Кнопка всегда справа от всех элементов
              return _buildAddPhotoButton(itemSize);
            },
          ),
        );
      },
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton(double size) {
    return GestureDetector(
      onTap: _handleAddPhotos,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppColors.twinphoto,
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.camera_fill,
            size: 24,
            color: AppColors.scrim20,
          ),
        ),
      ),
    );
  }

  /// Перетаскиваемый элемент карты
  Widget _buildDraggableMapItem(
    List<LatLng> points,
    int itemIndex,
    double size,
  ) {
    final isDragging = _draggedIndex == itemIndex;

    return LongPressDraggable<int>(
      data: itemIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: _buildMapItem(points, size: size, isDragging: true),
        ),
      ),
      onDragStarted: () {
        setState(() {
          _draggedIndex = itemIndex;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggedIndex = null;
        });
      },
      child: DragTarget<int>(
        onWillAcceptWithDetails: (data) => data.data != itemIndex,
        onAcceptWithDetails: (data) {
          final oldIndex = data.data;
          final newIndex = itemIndex;

          if (oldIndex != newIndex) {
            _reorderMediaItems(oldIndex, newIndex);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isTargeted = candidateData.isNotEmpty;
          return Opacity(
            opacity: isDragging ? 0.5 : (isTargeted ? 0.7 : 1.0),
            child: _buildMapItem(points, size: size, isDragging: isDragging),
          );
        },
      ),
    );
  }

  /// Элемент карты маршрута
  /// Использует статичную картинку с оптимизацией размера
  Widget _buildMapItem(
    List<LatLng> points, {
    required double size,
    bool isDragging = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.getBackgroundColor(context),

      ),
      clipBehavior: Clip.antiAlias,
      child: points.isEmpty
          ? Container(
              color: AppColors.getBackgroundColor(context),
              child: Center(
                child: Icon(
                  CupertinoIcons.map,
                  size: 24,
                  color: AppColors.getIconSecondaryColor(context),
                ),
              ),
            )
          : _buildStaticMiniMap(points, size),
    );
  }

  /// Строит статичную мини-карту маршрута с оптимизацией размера.
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION для маленьких карт:
  /// - Использует DPR 1.5 (вместо полного devicePixelRatio) для уменьшения веса файла
  /// - Ограничивает maxWidth/maxHeight до 180x180px для еще большей экономии
  /// - Кеширование через CachedNetworkImage с memCacheWidth/maxWidthDiskCache
  Widget _buildStaticMiniMap(List<LatLng> points, double size) {
    final widthDp = size;
    final heightDp = size;

    // ────────────────────────────────────────────────────────────────
    // 🔹 ОПТИМИЗАЦИЯ РАЗМЕРА: используем ограниченный DPR для мини-карт
    // ────────────────────────────────────────────────────────────────
    // Для маленьких карт достаточно DPR 1.5 вместо полного devicePixelRatio
    // Это уменьшает размер файла в 2-3 раза без заметной потери качества
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final optimizedDpr = (dpr > 1.5 ? 1.5 : dpr).clamp(1.0, 1.5);

    final widthPx = (widthDp * optimizedDpr).round();
    final heightPx = (heightDp * optimizedDpr).round();

    // Генерируем URL статичной карты с дополнительными ограничениями размера
    final mapUrl = StaticMapUrlBuilder.fromPoints(
      points: points,
      widthPx: widthPx.toDouble(),
      heightPx: heightPx.toDouble(),
      strokeWidth: 2.5,
      padding: 10.0,
      maxWidth: 180.0, // Дополнительное ограничение для маленьких карт
      maxHeight: 180.0, // Дополнительное ограничение для маленьких карт
    );

    return CachedNetworkImage(
      imageUrl: mapUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      memCacheWidth: widthPx,
      maxWidthDiskCache: widthPx,
      placeholder: (context, url) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppColors.twinphoto,
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.map,
            size: 24,
            color: AppColors.scrim20,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppColors.twinphoto,
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.map,
            size: 24,
            color: AppColors.scrim20,
          ),
        ),
      ),
    );
  }

  /// Перетаскиваемый элемент фотографии
  Widget _buildDraggablePhotoItem(
    String imageUrl,
    int photoIndex,
    int itemIndex,
    double size,
  ) {
    final isDragging = _draggedIndex == itemIndex;

    return LongPressDraggable<int>(
      data: itemIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: _buildPhotoItemContent(imageUrl, size: size, isDragging: true),
        ),
      ),
      onDragStarted: () {
        setState(() {
          _draggedIndex = itemIndex;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggedIndex = null;
        });
      },
      child: DragTarget<int>(
        onWillAcceptWithDetails: (data) => data.data != itemIndex,
        onAcceptWithDetails: (data) {
          // oldIndex и newIndex - это индексы в объединенном списке элементов (без кнопки добавления)
          final oldIndex = data.data;
          final newIndex = itemIndex;

          if (oldIndex != newIndex) {
            _reorderMediaItems(oldIndex, newIndex);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isTargeted = candidateData.isNotEmpty;
          return Opacity(
            opacity: isDragging ? 0.5 : (isTargeted ? 0.7 : 1.0),
            child: _buildPhotoItemContent(
              imageUrl,
              size: size,
              isDragging: isDragging,
            ),
          );
        },
      ),
    );
  }

  /// Создает список элементов медиа (изображения + карта)
  List<_MediaItem> _buildMediaItemsList() {
    final List<_MediaItem> items = [];

    // Добавляем изображения
    for (int i = 0; i < _imageUrls.length; i++) {
      items.add(_MediaItem.image(_imageUrls[i], i));
    }

    // Добавляем карту, если есть маршрут
    final hasRoute = widget.activity.points.isNotEmpty;
    if (hasRoute && _mapPosition != null) {
      final insertIndex = _mapPosition!.clamp(0, items.length);
      items.insert(insertIndex, _MediaItem.map());
    }

    return items;
  }

  /// Перестраивает единый список медиа после любого dnd
  /// Позволяет менять местами карту и фото без потери порядка
  void _reorderMediaItems(int oldIndex, int newIndex) {
    final items = _buildMediaItemsList();

    if (oldIndex < 0 ||
        oldIndex >= items.length ||
        newIndex < 0 ||
        newIndex >= items.length) {
      return;
    }

    // Перемещаем элемент: при переносе вправо вставляем после цели,
    // чтобы фото могло занять место карты и наоборот
    final dragged = items.removeAt(oldIndex);
    final targetIndex = oldIndex < newIndex ? newIndex : newIndex;
    items.insert(targetIndex.clamp(0, items.length), dragged);

    final List<String> reorderedImages = [];
    int? mapPos;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.isMap) {
        mapPos = i;
      } else if (item.imageUrl != null) {
        reorderedImages.add(item.imageUrl!);
      }
    }

    setState(() {
      _imageUrls
        ..clear()
        ..addAll(reorderedImages);
      _mapPosition = mapPos;
      _checkForChanges();
    });
  }

  /// Содержимое элемента фотографии (без обертки drag and drop)
  Widget _buildPhotoItemContent(
    String imageUrl, {
    required double size,
    bool isDragging = false,
  }) {
    return Builder(
      builder: (context) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final w = (size * dpr).round();

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  color: AppColors.getBackgroundColor(context),
                  border: isDragging
                      ? Border.all(color: AppColors.brandPrimary, width: 2)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: w,
                  maxWidthDiskCache: w,
                  placeholder: (context, url) => Container(
                    color: AppColors.getBackgroundColor(context),
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.getBackgroundColor(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
              ),
              // Кнопка удаления в правом верхнем углу
              Positioned(
                right: -6,
                top: -6,
                child: GestureDetector(
                  onTap: () => _handleDeletePhoto(imageUrl),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.getBorderColor(context),
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 20,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Поле ввода названия
  Widget _buildTitleInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.7,
        ),
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) {
          FocusScope.of(context).requestFocus(_descriptionFocusNode);
        },
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Введите название тренировки',
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 22,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        // boxShadow: [
        //   const BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 20,
        //     offset: Offset(0, 1),
        //   ),
        // ],
      ),
      child: TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocusNode,
        maxLines: 14,
        minLines: 8,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Введите описание тренировки',
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Секция с экипировкой
  /// Использует обновленную активность из провайдера для отображения актуального эквипа
  Widget _buildEquipmentSection() {
    // Получаем обновленную активность из провайдера (если есть)
    final lentaState = ref.watch(lentaProvider(widget.currentUserId));
    final updatedActivity = lentaState.items.firstWhere(
      (a) => a.lentaId == widget.activity.lentaId,
      orElse: () => widget.activity,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        // boxShadow: [
        //   const BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 20,
        //     offset: Offset(0, 1),
        //   ),
        // ],
      ),
      child: EquipmentChip(
        items: updatedActivity.equipments,
        userId: updatedActivity.userId,
        activityType: updatedActivity.type,
        activityId: updatedActivity.id,
        activityDistance: (updatedActivity.stats?.distance ?? 0.0) / 1000.0,
        showMenuButton: true,
        // Убираем нижний разделитель на экране редактирования
        showDivider: false,
        // ────────────────────────────────────────────────────────────────
        // 🔹 ФОН ПЛАШКИ: в светлой теме используем surface вместо background
        // ────────────────────────────────────────────────────────────────
        // Только для светлой темы на этой странице
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getSurfaceColor(context)
            : null, // В темной теме используем дефолтное поведение
        // ────────────────────────────────────────────────────────────────
        // 🔹 ФОН КНОПКИ МЕНЮ: в светлой теме используем background вместо surface
        // ────────────────────────────────────────────────────────────────
        // Только для светлой темы на этой странице
        menuButtonColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getBackgroundColor(context)
            : null, // В темной теме используем дефолтное поведение
        onEquipmentChanged: () {
          // Обновляем ленту фоном без блокировки UI
          unawaited(
            ref
                .read(lentaProvider(widget.currentUserId).notifier)
                .forceRefresh(),
          );
          // Проверяем изменения после обновления
          _checkForChanges();
        },
      ),
    );
  }

  /// Секция выбора экипировки (если экипировка не выбрана)
  Widget _buildEquipmentSelectionSection() {
    if (_isLoadingEquipment) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_availableEquipment.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Нет доступной экипировки для выбранного типа тренировки',
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // Если экипировка выбрана, показываем EquipmentChip
    if (_selectedEquipment != null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
          // boxShadow: [
          //   const BoxShadow(
          //     color: AppColors.twinshadow,
          //     blurRadius: 20,
          //     offset: Offset(0, 1),
          //   ),
          // ],
        ),
        child: EquipmentChip(
          items: [_selectedEquipment!],
          userId: widget.currentUserId,
          activityType: widget.activity.type,
          activityId: widget.activity.id,
          activityDistance: (widget.activity.stats?.distance ?? 0.0) / 1000.0,
          showMenuButton: true,
          // Убираем нижний разделитель на экране редактирования
          showDivider: false,
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.getSurfaceColor(context)
              : null,
          menuButtonColor: Theme.of(context).brightness == Brightness.light
              ? AppColors.getBackgroundColor(context)
              : null,
          onEquipmentChanged: () {
            _loadEquipment();
          },
          onEquipmentSelected: (Equipment newEquipment) {
            setState(() {
              // Обновляем выбранную экипировку при выборе через попап
              // Это гарантирует, что последняя выбранная экипировка будет сохранена при сохранении изменений
              _selectedEquipment = newEquipment;
            });
            // Перезагружаем список доступной экипировки для обновления выпадающего списка
            _loadEquipment();
          },
        ),
      );
    }

    // Если экипировка не выбрана, показываем выпадающий список для выбора
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        // boxShadow: [
        //   const BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 20,
        //     offset: Offset(0, 1),
        //   ),
        // ],
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Equipment>(
            value: _selectedEquipment,
            isExpanded: true,
            hint: Text(
              'Выберите экипировку',
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPlaceholderColor(context),
              ),
            ),
            onChanged: (Equipment? newValue) {
              setState(() {
                _selectedEquipment = newValue;
              });
            },
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: _availableEquipment.map((equipment) {
              final displayName = equipment.brand.isNotEmpty
                  ? '${equipment.brand} ${equipment.name}'
                  : equipment.name;
              return DropdownMenuItem<Equipment>(
                value: equipment,
                child: Text(
                  displayName,
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Проверяет, нужно ли показывать чекбокс экипировки
  /// Показываем только для "Бег" и "Велосипед"
  bool _shouldShowEquipment() {
    final activityType = widget.activity.type.toLowerCase();
    return activityType == 'run' || activityType == 'bike';
  }

  /// Загружает список экипировки для типа тренировки
  Future<void> _loadEquipment() async {
    if (!_shouldShowEquipment()) return;

    setState(() {
      _isLoadingEquipment = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': widget.currentUserId.toString()},
      );

      if (data['success'] == true) {
        // Преобразуем тип активности в тип эквипа
        final String equipmentType = _activityTypeToEquipmentType(
          widget.activity.type,
        );

        if (equipmentType.isEmpty) {
          setState(() {
            _availableEquipment = [];
            _isLoadingEquipment = false;
          });
          return;
        }

        // Получаем эквип нужного типа (boots или bikes)
        final List<dynamic> equipmentList = equipmentType == 'boots'
            ? data['boots'] ?? []
            : data['bikes'] ?? [];

        // Преобразуем в модель Equipment
        final List<Equipment> allEquipment = equipmentList
            .map(
              (item) => Equipment.fromJson({
                'name': item['name'] ?? '',
                'brand': item['brand'] ?? '',
                'mileage': item['dist'] ?? 0,
                'img': item['image'] ?? '',
                'main': item['main'] ?? false,
                'myraiting': 0.0,
                'type': equipmentType,
                'equip_user_id': item['equip_user_id'],
              }),
            )
            .toList();

        setState(() {
          _availableEquipment = allEquipment;
          _isLoadingEquipment = false;
        });
      } else {
        setState(() {
          _availableEquipment = [];
          _isLoadingEquipment = false;
        });
      }
    } catch (e) {
      setState(() {
        _availableEquipment = [];
        _isLoadingEquipment = false;
      });
    }
  }

  /// Преобразует тип активности в тип эквипа
  String _activityTypeToEquipmentType(String activityType) {
    final String type = activityType.toLowerCase();
    if (type == 'run' || type == 'running') {
      return 'boots';
    } else if (type == 'bike' || type == 'cycling' || type == 'bicycle') {
      return 'bike';
    }
    return '';
  }

  /// Выпадающий список для выбора видимости
  Widget _buildVisibilitySelector() {
    const List<String> options = [
      'Все пользователи',
      'Только подписчики',
      'Только Вы',
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        // boxShadow: [
        //   const BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 20,
        //     offset: Offset(0, 1),
        //   ),
        // ],
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options[_selectedVisibility],
            isExpanded: true,
            onChanged: (String? newValue) {
              if (newValue != null) {
                final index = options.indexOf(newValue);
                if (index != -1) {
                  setState(() {
                    _selectedVisibility = index;
                    _checkForChanges();
                  });
                }
              }
            },
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    final formState = ref.watch(formStateProvider);
    final textColor = AppColors.getSurfaceColor(context);
    final isLoading = formState.isSubmitting;
    final isValid = true; // Всегда валидна, так как нет проверки isFormValid

    // ─────────── Содержимое кнопки без эффекта стекла
    final button = ElevatedButton(
      onPressed: (isLoading || !isValid) ? null : _saveChanges,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.button.withValues(alpha: 0.7);
            }
            return AppColors.button.withValues(alpha: 0.7);
          },
        ),
        foregroundColor: WidgetStateProperty.all(textColor),
        elevation: WidgetStateProperty.all(0),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 30),
        ),
        shape: WidgetStateProperty.all(
          StadiumBorder(
            side: BorderSide(
              color: AppColors.button.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, 50),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: isLoading
          ? CupertinoActivityIndicator(
              radius: 9,
              color: textColor,
            )
          : Text(
              'Сохранить',
              style: AppTextStyles.h15w5.copyWith(
                color: textColor,
                height: 1.0,
              ),
            ),
    );

    // ─────────── Стеклянная оболочка с блюром как в iOS
    final glassButton = ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.circular(AppRadius.xxl),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8,
          sigmaY: 8,
        ),
        child: button,
      ),
    );

    // Блокировка нажатий во время загрузки
    if (isLoading) {
      return IgnorePointer(child: glassButton);
    }

    return glassButton;
  }

  /// Сохраняет изменения на сервер
  Future<void> _saveChanges() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    final formNotifier = ref.read(formStateProvider.notifier);
    final auth = AuthService();
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        final userId = await auth.getUserId();
        if (userId == null) {
          throw Exception('Не удалось определить пользователя');
        }

        // Формируем тело запроса
        final body = <String, dynamic>{
          'user_id': userId.toString(),
          'activity_id': widget.activity.id.toString(),
          'title': _titleController.text.trim(),
          'content': _descriptionController.text.trim(),
          'user_group': _selectedVisibility.toString(),
          'media_images': _imageUrls, // Отправляем новый порядок фотографий
        };

        // Сохраняем порядок карты в общем списке (фото + карта)
        // Отправляем только если маршрут существует и позиция определена
        if (_hasRoute && _mapPosition != null) {
          body['map_sort_order'] = _mapPosition.toString();
        }

        // Получаем equip_user_id из выбранной экипировки
        // Отправляем только если экипировка выбрана
        if (_selectedEquipment != null) {
          final equipUserId = _selectedEquipment!.equipUserId ?? 0;
          if (equipUserId > 0) {
            body['equip_user_id'] = equipUserId.toString();
          }
        }

        final response = await api.post('/update_activity.php', body: body);

        if (response['success'] != true) {
          final message =
              response['message']?.toString() ??
              'Не удалось сохранить изменения';
          throw Exception(message);
        }

        // Обновляем ленту
        await ref.read(lentaProvider(widget.currentUserId).notifier).refresh();
      },
      onSuccess: () {
        if (!mounted) return;
        Navigator.of(context).pop(true); // Возвращаемся с флагом успеха
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при сохранении');
      },
    );
  }

  /// Показывает ошибку
  void _showError(dynamic error) {
    final message = ErrorHandler.format(error);
    showCupertinoDialog<void>(
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

  /// Обработчик добавления фотографий к тренировке
  Future<void> _handleAddPhotos() async {
    final picker = ImagePicker();
    final auth = AuthService();
    final navigator = Navigator.of(context, rootNavigator: true);
    var loaderShown = false;

    // ────────────────────────────────────────────────────────────────
    // 📐 ВЫЧИСЛЕНИЕ СООТНОШЕНИЯ ОБРЕЗКИ 1:1.1:
    // Высота = ширина × 1.1
    // Aspect ratio = ширина / высота = 1 / 1.1
    // ────────────────────────────────────────────────────────────────
    final aspectRatio = 1.0 / 1.1;

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
        if (mounted) {
          _showError(
            'Не удалось определить пользователя. Пожалуйста, авторизуйтесь.',
          );
        }
        return;
      }

      final filesForUpload = <String, File>{};
      for (var i = 0; i < pickedFiles.length; i++) {
        if (!mounted) return;

        final picked = pickedFiles[i];
        // ────────────────────────────────────────────────────────────────
        // 📐 ОБРЕЗКА ИЗОБРАЖЕНИЯ В СООТНОШЕНИИ 1:1.1:
        // Высота = ширина × 1.1 (как для карты маршрута)
        // ────────────────────────────────────────────────────────────────
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: aspectRatio,
          title: 'Обрезать',
        );

        if (cropped == null) {
          continue; // Пропускаем, если пользователь отменил обрезку
        }

        // Сжимаем обрезанное изображение
        final compressed = await compressLocalImage(
          sourceFile: cropped,
          maxSide: ImageCompressionPreset.activity.maxSide,
          jpegQuality: ImageCompressionPreset.activity.quality,
        );

        // Удаляем временный файл обрезки
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
        return;
      }

      _showBlockingLoader('Загружаем фотографии…');
      loaderShown = true;

      final api = ref.read(apiServiceProvider);
      final response = await api.postMultipart(
        '/upload_activity_photos.php',
        files: filesForUpload,
        fields: {
          'user_id': userId.toString(),
          'activity_id': widget.activity.id.toString(),
        },
        timeout: const Duration(minutes: 2),
      );

      hideLoader();

      if (response['success'] != true) {
        final message =
            response['message']?.toString() ??
            'Не удалось загрузить фотографии. Попробуйте ещё раз.';
        if (mounted) {
          _showError(message);
        }
        return;
      }

      final images =
          (response['images'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [];

      if (images.isNotEmpty) {
        // Обновляем локальный список фотографий
        // Сервер возвращает полный список всех фотографий активности,
        // поэтому заменяем весь список, а не добавляем к существующему
        setState(() {
          _imageUrls.clear();
          _imageUrls.addAll(images);
          _checkForChanges();
        });

        // Обновляем провайдер
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .updateActivityMedia(
              lentaId: widget.activity.lentaId,
              mediaImages: _imageUrls,
            );
      } else {
        // Если сервер не вернул список, обновляем через refresh
        if (!mounted) return;
        await ref.read(lentaProvider(widget.currentUserId).notifier).refresh();
        if (!mounted) return;
        // Обновляем локальный список из обновленной активности
        final lentaState = ref.read(lentaProvider(widget.currentUserId));
        final updatedActivity = lentaState.items.firstWhere(
          (a) => a.lentaId == widget.activity.lentaId,
          orElse: () => widget.activity,
        );
        if (mounted) {
          setState(() {
            _imageUrls.clear();
            _imageUrls.addAll(updatedActivity.mediaImages);
          });
        }
      }
    } catch (e) {
      hideLoader();
      if (mounted) {
        _showError(e);
      }
    }
  }

  /// Показывает блокирующий лоадер
  void _showBlockingLoader(String message) {
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

  /// Обработчик удаления фотографии
  Future<void> _handleDeletePhoto(String imageUrl) async {
    // Подтверждение удаления
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удалить фотографию?'),
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

    if (confirmed != true) return;

    try {
      final auth = AuthService();
      final userId = await auth.getUserId();
      if (userId == null) {
        if (mounted) {
          _showError('Не удалось определить пользователя');
        }
        return;
      }

      // Удаляем фотографию из локального списка
      setState(() {
        _imageUrls.remove(imageUrl);
        _checkForChanges();
      });

      // Вызываем API для удаления фотографии с сервера
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/delete_activity_photo.php',
        body: {
          'user_id': userId.toString(),
          'activity_id': widget.activity.id.toString(),
          'image_url': imageUrl,
        },
      );

      if (response['success'] == true) {
        // Обновляем провайдер с новым списком фотографий
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .updateActivityMedia(
              lentaId: widget.activity.lentaId,
              mediaImages: _imageUrls,
            );
      } else {
        // Если удаление на сервере не удалось, возвращаем фотографию в список
        setState(() {
          _imageUrls.add(imageUrl);
          _checkForChanges();
        });

        final message =
            response['message']?.toString() ??
            'Не удалось удалить фотографию. Попробуйте ещё раз.';
        if (mounted) {
          _showError(message);
        }
      }
    } catch (e) {
      // Возвращаем фотографию в список при ошибке
      setState(() {
        _imageUrls.add(imageUrl);
        _checkForChanges();
      });

      if (mounted) {
        _showError(e);
      }
    }
  }
}

/// Вспомогательный класс для представления элемента медиа (изображение или карта)
class _MediaItem {
  final String? imageUrl;
  final int? photoIndex;
  final bool isMap;

  _MediaItem.image(this.imageUrl, this.photoIndex) : isMap = false;
  _MediaItem.map() : imageUrl = null, photoIndex = null, isMap = true;
}
