// lib/screens/lenta/activity/edit_activity_screen.dart
import 'dart:async';
import 'dart:io';

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
import '../../../../core/widgets/primary_button.dart';
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
  bool _showEquipment = false;
  List<Equipment> _availableEquipment = [];
  Equipment? _selectedEquipment;
  bool _isLoadingEquipment = false;

  @override
  void initState() {
    super.initState();
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

    // Инициализируем состояние экипировки
    // Если экипировка не выбрана и тип активности позволяет выбрать экипировку
    if (widget.activity.equipments.isEmpty && _shouldShowEquipment()) {
      _showEquipment = false; // По умолчанию чекбокс выключен
    }

    // Слушаем изменения для определения, есть ли изменения
    _descriptionController.addListener(_checkForChanges);
    _descriptionFocusNode.addListener(_checkForChanges);
  }

  @override
  void dispose() {
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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Редактировать тренировку'),
        body: GestureDetector(
          // Скрываем клавиатуру при нажатии на пустую область
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ────────────────────────────────────────────────────────────────
                  // 📸 1. ФОТОГРАФИИ ТРЕНИРОВКИ (горизонтальная карусель)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Фото тренировки',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildPhotoCarousel(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📝 2. ОПИСАНИЕ ТРЕНИРОВКИ
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Описание тренировки',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildDescriptionInput(),

                  // ────────────────────────────────────────────────────────────────
                  // 👟 3. ЭКИПИРОВКА
                  // ────────────────────────────────────────────────────────────────
                  Builder(
                    builder: (context) {
                      // Получаем обновленную активность из провайдера для проверки
                      final lentaState = ref.watch(
                        lentaProvider(widget.currentUserId),
                      );
                      final updatedActivity = lentaState.items.firstWhere(
                        (a) => a.lentaId == widget.activity.lentaId,
                        orElse: () => widget.activity,
                      );

                      // Если экипировка уже выбрана, показываем EquipmentChip
                      if (updatedActivity.equipments.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
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
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Transform.scale(
                                    scale: 0.85,
                                    alignment: Alignment.centerLeft,
                                    child: Checkbox(
                                      value: _showEquipment,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      activeColor: AppColors.brandPrimary,
                                      checkColor: AppColors.getSurfaceColor(
                                        context,
                                      ),
                                      side: BorderSide(
                                        color: AppColors.getIconSecondaryColor(
                                          context,
                                        ),
                                        width: 1.5,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _showEquipment = value ?? false;
                                          if (_showEquipment &&
                                              _availableEquipment.isEmpty) {
                                            _loadEquipment();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Добавить экипировку',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (_showEquipment) ...[
                              const SizedBox(height: 8),
                              _buildEquipmentSelectionSection(),
                            ],
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 👁️ 4. КТО ВИДИТ ТРЕНИРОВКУ (выпадающий список)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Кто видит тренировку',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildVisibilitySelector(),

                  const SizedBox(height: 32),

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

                  // ────────────────────────────────────────────────────────────────
                  // 💾 КНОПКА СОХРАНЕНИЯ
                  // ────────────────────────────────────────────────────────────────
                  Center(child: _buildSaveButton()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Горизонтальная карусель фотографий и карты
  /// Порядок: кнопка добавления фото → изображения и карта (в порядке сортировки)
  Widget _buildPhotoCarousel() {
    final hasRoute = _hasRoute;

    // Преобразуем точки маршрута в LatLng для карты (если есть)
    final routePoints = hasRoute
        ? widget.activity.points.map((c) => LatLng(c.lat, c.lng)).toList()
        : <LatLng>[];

    // Создаем объединенный список элементов для отображения
    final List<_MediaItem> items = [];

    // Добавляем изображения
    for (int i = 0; i < _imageUrls.length; i++) {
      items.add(_MediaItem.image(_imageUrls[i], i));
    }

    // Добавляем карту, если есть маршрут
    if (hasRoute && _mapPosition != null) {
      // Вставляем карту в нужную позицию
      final insertIndex = _mapPosition!.clamp(0, items.length);
      items.insert(insertIndex, _MediaItem.map());
    }

    // Общее количество элементов: кнопка добавления (1) + элементы (изображения + карта)
    final totalItems = 1 + items.length;

    return SizedBox(
      height: 96, // 90 + 6 (padding сверху для кнопок удаления)
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 6,
        ), // Добавляем padding сверху для кнопок удаления
        itemCount: totalItems,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Первый элемент — кнопка добавления фото
          if (index == 0) {
            return _buildAddPhotoButton();
          }

          // Остальные элементы — изображения и карта
          // itemIndex в отображаемом списке (без кнопки добавления)
          final itemIndex = index - 1;
          final item = items[itemIndex];

          if (item.isMap) {
            return _buildDraggableMapItem(routePoints, itemIndex);
          } else {
            return _buildDraggablePhotoItem(
              item.imageUrl!,
              item.photoIndex!,
              itemIndex,
            );
          }
        },
      ),
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _handleAddPhotos,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: AppColors.getSurfaceColor(context),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: Center(
          child: Icon(
            CupertinoIcons.photo,
            size: 28,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  /// Перетаскиваемый элемент карты
  Widget _buildDraggableMapItem(List<LatLng> points, int itemIndex) {
    final isDragging = _draggedIndex == itemIndex;

    return LongPressDraggable<int>(
      data: itemIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: _buildMapItem(points, isDragging: true),
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
            child: _buildMapItem(points, isDragging: isDragging),
          );
        },
      ),
    );
  }

  /// Элемент карты маршрута
  /// Использует статичную картинку с оптимизацией размера
  Widget _buildMapItem(List<LatLng> points, {bool isDragging = false}) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: AppColors.getBackgroundColor(context),
        border: isDragging
            ? Border.all(color: AppColors.brandPrimary, width: 2)
            : Border.all(color: AppColors.getBorderColor(context)),
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
          : _buildStaticMiniMap(points),
    );
  }

  /// Строит статичную мини-карту маршрута (90x90px) с оптимизацией размера.
  ///
  /// ⚡ PERFORMANCE OPTIMIZATION для маленьких карт:
  /// - Использует DPR 1.5 (вместо полного devicePixelRatio) для уменьшения веса файла
  /// - Ограничивает maxWidth/maxHeight до 180x180px для еще большей экономии
  /// - Кеширование через CachedNetworkImage с memCacheWidth/maxWidthDiskCache
  Widget _buildStaticMiniMap(List<LatLng> points) {
    const widthDp = 90.0;
    const heightDp = 90.0;

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
      padding: 8.0,
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
        color: AppColors.getSurfaceColor(context),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.getSurfaceColor(context),
        child: Icon(
          CupertinoIcons.map,
          size: 24,
          color: AppColors.getIconSecondaryColor(context),
        ),
      ),
    );
  }

  /// Перетаскиваемый элемент фотографии
  Widget _buildDraggablePhotoItem(
    String imageUrl,
    int photoIndex,
    int itemIndex,
  ) {
    final isDragging = _draggedIndex == itemIndex;

    return LongPressDraggable<int>(
      data: itemIndex,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: _buildPhotoItemContent(imageUrl, isDragging: true),
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
            child: _buildPhotoItemContent(imageUrl, isDragging: isDragging),
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
  Widget _buildPhotoItemContent(String imageUrl, {bool isDragging = false}) {
    return Builder(
      builder: (context) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final w = (90 * dpr).round();

        return SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return TextField(
      controller: _descriptionController,
      focusNode: _descriptionFocusNode,
      maxLines: 12,
      minLines: 7,
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
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
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

    return EquipmentChip(
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
          ref.read(lentaProvider(widget.currentUserId).notifier).forceRefresh(),
        );
        // Проверяем изменения после обновления
        _checkForChanges();
      },
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
      return EquipmentChip(
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
      );
    }

    // Если экипировка не выбрана, показываем выпадающий список для выбора
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Equipment>(
          value: _selectedEquipment,
          isExpanded: true,
          hint: const Text('Выберите экипировку', style: AppTextStyles.h14w4),
          onChanged: (Equipment? newValue) {
            setState(() {
              _selectedEquipment = newValue;
            });
          },
          dropdownColor: AppColors.getSurfaceColor(context),
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.getIconSecondaryColor(context),
          ),
          items: _availableEquipment.map((equipment) {
            final displayName = equipment.brand.isNotEmpty
                ? '${equipment.brand} ${equipment.name}'
                : equipment.name;
            return DropdownMenuItem<Equipment>(
              value: equipment,
              child: Text(displayName, style: AppTextStyles.h14w4),
            );
          }).toList(),
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

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
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
          borderRadius: BorderRadius.circular(AppRadius.md),
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
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    final formState = ref.watch(formStateProvider);
    return PrimaryButton(
      text: 'Сохранить',
      onPressed: !formState.isSubmitting ? _saveChanges : () {},
      width: 190,
      isLoading: formState.isSubmitting,
      enabled: !formState.isSubmitting,
    );
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
        // Отправляем только если чекбокс включен и экипировка выбрана
        if (_showEquipment && _selectedEquipment != null) {
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
    // 🔹 СОХРАНЯЕМ screenWidth ДО async операций, чтобы избежать
    // использования BuildContext через async gap
    // ────────────────────────────────────────────────────────────────
    final screenWidth = MediaQuery.of(context).size.width;
    final aspectRatio = screenWidth / 350.0;

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
        // Обрезаем изображение для высоты 350px (динамическое соотношение)
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: aspectRatio,
          title: 'Обрезка фотографии ${i + 1}',
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
        if (mounted) {
          _showError('Не удалось подготовить файлы для загрузки.');
        }
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
