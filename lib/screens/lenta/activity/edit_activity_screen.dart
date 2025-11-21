// lib/screens/lenta/activity/edit_activity_screen.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/route_card.dart';
import '../../../models/activity_lenta.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import '../../../providers/lenta/lenta_provider.dart';

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
  bool _isLoading = false;
  bool _hasChanges = false;

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
      _hasChanges = textChanged || visibilityChanged || imagesChanged;
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
        backgroundColor: AppColors.surface,
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

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 👟 3. СМЕНА ЭКИПИРОВКИ
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Экипировка',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildEquipmentSection(),

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
  /// Порядок: кнопка добавления фото → карта → фотографии
  Widget _buildPhotoCarousel() {
    // Преобразуем точки маршрута в LatLng для карты
    final routePoints = widget.activity.points
        .map((c) => LatLng(c.lat, c.lng))
        .toList();

    // Общее количество элементов: кнопка добавления (1) + карта (1) + фотографии
    final totalItems = 2 + _imageUrls.length;

    return SizedBox(
      height: 96, // 90 + 6 (padding сверху для кнопок удаления)
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          top: 6,
        ), // Добавляем padding сверху для кнопок удаления
        itemCount: totalItems,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Первый элемент — кнопка добавления фото
          if (index == 0) {
            return _buildAddPhotoButton();
          }
          // Второй элемент — карта
          if (index == 1) {
            return _buildMapItem(routePoints);
          }
          // Остальные элементы — фотографии
          final photoIndex = index - 2;
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
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.photo,
            size: 28,
            color: AppColors.iconTertiary,
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
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: points.isEmpty
          ? Container(
              color: AppColors.background,
              child: const Center(
                child: Icon(
                  CupertinoIcons.map,
                  size: 24,
                  color: AppColors.iconSecondary,
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
        onWillAccept: (data) => data != imageUrl,
        onAccept: (data) {
          final oldIndex = _imageUrls.indexOf(data);
          final newIndex = photoIndex;

          if (oldIndex != -1 && oldIndex != newIndex) {
            setState(() {
              _imageUrls.removeAt(oldIndex);
              _imageUrls.insert(newIndex, data);
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
                  color: AppColors.background,
                  border: Border.all(
                    color: isDragging
                        ? AppColors.brandPrimary
                        : AppColors.border,
                    width: isDragging ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: w,
                  maxWidthDiskCache: w,
                  placeholder: (context, url) => Container(
                    color: AppColors.background,
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.background,
                    child: const Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: AppColors.iconSecondary,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
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
      style: AppTextStyles.h14w4,
      decoration: InputDecoration(
        hintText: 'Введите описание тренировки',
        hintStyle: AppTextStyles.h14w4Place,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
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
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
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
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.iconSecondary,
          ),
          style: AppTextStyles.h14w4,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option, style: AppTextStyles.h14w4),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    return PrimaryButton(
      text: 'Сохранить',
      onPressed: !_isLoading ? _saveChanges : () {},
      width: 190,
      isLoading: _isLoading,
      enabled: true,
    );
  }

  /// Сохраняет изменения на сервер
  Future<void> _saveChanges() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final auth = AuthService();
      final userId = await auth.getUserId();
      if (userId == null) {
        if (mounted) {
          _showError('Не удалось определить пользователя');
        }
        return;
      }

      final api = ApiService();
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

      if (response['success'] == true) {
        // Обновляем ленту
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .forceRefresh();

        if (mounted) {
          Navigator.of(context).pop(true); // Возвращаемся с флагом успеха
        }
      } else {
        final message =
            response['message']?.toString() ?? 'Не удалось сохранить изменения';
        if (mounted) {
          _showError(message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка при сохранении: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Показывает ошибку
  void _showError(String message) {
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
        final path = pickedFiles[i].path;
        if (path.isEmpty) continue;
        filesForUpload['file$i'] = File(path);
      }

      if (filesForUpload.isEmpty) {
        if (mounted) {
          _showError('Не удалось подготовить файлы для загрузки.');
        }
        return;
      }

      _showBlockingLoader('Загружаем фотографии…');
      loaderShown = true;

      final api = ApiService();
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
        setState(() {
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
    } on PlatformException catch (e) {
      hideLoader();
      if (mounted) {
        _showError(
          'Нет доступа к галерее: ${e.message ?? 'неизвестная ошибка'}.',
        );
      }
    } on ApiException catch (e) {
      hideLoader();
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      hideLoader();
      if (mounted) {
        _showError('Не удалось загрузить фотографии. Попробуйте ещё раз.');
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
      final api = ApiService();
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
    } on ApiException catch (e) {
      // Возвращаем фотографию в список при ошибке
      setState(() {
        _imageUrls.add(imageUrl);
        _checkForChanges();
      });

      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      // Возвращаем фотографию в список при ошибке
      setState(() {
        _imageUrls.add(imageUrl);
        _checkForChanges();
      });

      if (mounted) {
        _showError('Ошибка при удалении фотографии: $e');
      }
    }
  }
}
