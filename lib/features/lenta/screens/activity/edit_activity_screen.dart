// lib/screens/lenta/activity/edit_activity_screen.dart
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
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/route_card.dart';
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

  // Индекс перетаскиваемой фотографии
  int? _draggedIndex;

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

    // Инициализируем видимость из userGroup
    // Предполагаем: 0 = публичная, 1 = подписчики, 2 = только я
    _selectedVisibility = widget.activity.userGroup.clamp(0, 2);

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
                  // 👟 3. СМЕНА ЭКИПИРОВКИ (показываем только если есть экипировка)
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

                      // Показываем блок только если есть экипировка
                      if (updatedActivity.equipments.isEmpty) {
                        return const SizedBox.shrink();
                      }

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

  /// Горизонтальная карусель фотографий
  /// Порядок: кнопка добавления фото → карта (если есть маршрут) → фотографии
  Widget _buildPhotoCarousel() {
    // Проверяем, есть ли у тренировки маршрут
    final hasRoute = widget.activity.points.isNotEmpty;

    // Преобразуем точки маршрута в LatLng для карты (если есть)
    final routePoints = hasRoute
        ? widget.activity.points.map((c) => LatLng(c.lat, c.lng)).toList()
        : <LatLng>[];

    // Общее количество элементов:
    // кнопка добавления (1) + карта (1, если есть маршрут) + фотографии
    final totalItems = 1 + (hasRoute ? 1 : 0) + _imageUrls.length;

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

          // Если есть маршрут, второй элемент — карта
          if (hasRoute && index == 1) {
            return _buildMapItem(routePoints);
          }

          // Остальные элементы — фотографии
          // Если есть маршрут, фотографии начинаются с index 2
          // Если нет маршрута, фотографии начинаются с index 1
          final photoIndex = hasRoute ? index - 2 : index - 1;
          final imageUrl = _imageUrls[photoIndex];
          return _buildDraggablePhotoItem(imageUrl, photoIndex);
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

  /// Элемент карты маршрута (второй в карусели)
  Widget _buildMapItem(List<LatLng> points) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: AppColors.getBackgroundColor(context),
        border: Border.all(color: AppColors.getBorderColor(context)),
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
          : RouteCard(points: points, height: 90),
    );
  }

  /// Перетаскиваемый элемент фотографии
  Widget _buildDraggablePhotoItem(String imageUrl, int photoIndex) {
    final isDragging = _draggedIndex == photoIndex;

    return LongPressDraggable<String>(
      data: imageUrl,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: _buildPhotoItemContent(imageUrl, isDragging: true),
        ),
      ),
      onDragStarted: () {
        setState(() {
          _draggedIndex = photoIndex;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggedIndex = null;
        });
      },
      child: DragTarget<String>(
        onWillAcceptWithDetails: (data) => data.data != imageUrl,
        onAcceptWithDetails: (data) {
          final oldIndex = _imageUrls.indexOf(data.data);
          final newIndex = photoIndex;

          if (oldIndex != -1 && oldIndex != newIndex) {
            setState(() {
              _imageUrls.removeAt(oldIndex);
              _imageUrls.insert(newIndex, data.data);
              _checkForChanges();
            });
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
      onEquipmentChanged: () async {
        // Обновляем ленту после замены эквипа
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .forceRefresh();

        // Проверяем изменения
        _checkForChanges();
      },
    );
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

        final response = await api.post(
          '/update_activity.php',
          body: {
            'user_id': userId.toString(),
            'activity_id': widget.activity.id.toString(),
            'content': _descriptionController.text.trim(),
            'user_group': _selectedVisibility.toString(),
            'media_images': _imageUrls, // Отправляем новый порядок фотографий
          },
        );

        if (response['success'] != true) {
          final message =
              response['message']?.toString() ??
              'Не удалось сохранить изменения';
          throw Exception(message);
        }

        // Обновляем ленту
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .forceRefresh();
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

    void hideLoader() {
      if (loaderShown && navigator.mounted) {
        navigator.pop();
        loaderShown = false;
      }
    }

    try {
      final pickedFiles = await picker.pickMultiImage();
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
        // Обрезаем изображение в соотношении 1.3:1
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: 1.3,
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

        if (mounted) {
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
      } else {
        // Если сервер не вернул список, обновляем через refresh
        await ref.read(lentaProvider(widget.currentUserId).notifier).refresh();
        // Обновляем локальный список из обновленной активности
        final lentaState = ref.read(lentaProvider(widget.currentUserId));
        final updatedActivity = lentaState.items.firstWhere(
          (a) => a.lentaId == widget.activity.lentaId,
          orElse: () => widget.activity,
        );
        setState(() {
          _imageUrls.clear();
          _imageUrls.addAll(updatedActivity.mediaImages);
        });
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
