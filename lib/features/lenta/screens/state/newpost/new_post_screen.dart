// lib/screens/lenta/state/newpost/new_post_screen.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/utils/image_picker_helper.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../providers/lenta_provider.dart';
import '../../../../../core/providers/form_state_provider.dart';
import '../../../../../core/widgets/form_error_display.dart';

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭКРАН СОЗДАНИЯ НОВОГО ПОСТА
/// ────────────────────────────────────────────────────────────────
/// Позволяет создать новый пост с:
/// 1. Фотографиями поста (горизонтальная карусель)
/// 2. Описанием поста (текстовое поле)
/// ────────────────────────────────────────────────────────────────
class NewPostScreen extends ConsumerStatefulWidget {
  final int userId;

  const NewPostScreen({super.key, required this.userId});

  @override
  ConsumerState<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends ConsumerState<NewPostScreen> {
  // ────────────────────────────────────────────────────────────────
  // 📝 КОНТРОЛЛЕРЫ И СОСТОЯНИЕ
  // ────────────────────────────────────────────────────────────────
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocusNode;

  // Список выбранных фотографий
  final List<File> _images = [];

  // Доступность кнопки публикации
  bool _canPublish = false;

  // Состояние видимости: 0 = Все пользователи, 1 = Только подписчики, 2 = Только Вы
  int _selectedVisibility = 0;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _descriptionFocusNode = FocusNode();
    _descriptionController.addListener(_updatePublishState);
    _descriptionFocusNode.addListener(_updatePublishState);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  /// Обновляет состояние доступности кнопки публикации
  void _updatePublishState() {
    setState(() {
      _canPublish =
          _images.isNotEmpty || _descriptionController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Новый пост',
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ────────────────────────────────────────────────────────────────
                  // 📸 1. ФОТОГРАФИИ ПОСТА (горизонтальная карусель)
                  // ────────────────────────────────────────────────────────────────
                  Text(
                    'Фотографии поста',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildPhotoCarousel(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📝 2. ОПИСАНИЕ ПОСТА
                  // ────────────────────────────────────────────────────────────────
                  Text(
                    'Описание поста',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDescriptionInput(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 👁️ 3. КТО ВИДИТ ПОСТ (выпадающий список)
                  // ────────────────────────────────────────────────────────────────
                  Text(
                    'Кто видит пост',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
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
                  // 💾 КНОПКА ПУБЛИКАЦИИ
                  // ────────────────────────────────────────────────────────────────
                  const SizedBox(height: 12),
                  Center(child: _buildPublishButton()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Горизонтальная карусель фотографий
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

        // ────────────────────────────────────────────────────────────────
        // 🔹 СОЗДАНИЕ СПИСКА ЭЛЕМЕНТОВ С ОГРАНИЧЕНИЕМ В 3 ЭЛЕМЕНТА
        // ────────────────────────────────────────────────────────────────
        // Максимум 3 элемента в карусели: фотографии + кнопка (если есть место)
        final displayImages = _images.take(3).toList();

        // Показываем кнопку добавления только если есть место (меньше 3 элементов)
        final showAddButton = displayImages.length < 3;
        final totalItems = displayImages.length + (showAddButton ? 1 : 0);

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
              // Сначала показываем элементы медиа (фотографии)
              if (index < displayImages.length) {
                final image = displayImages[index];
                final photoIndex = _images.indexOf(image);
                return _buildPhotoItem(image, photoIndex, itemSize);
              }

              // Если есть место (displayImages.length < 3), последний элемент — кнопка добавления
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

  /// Элемент фотографии с кнопкой удаления
  Widget _buildPhotoItem(File file, int photoIndex, double size) {
    return Builder(
      builder: (context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () async {
                // По тапу можно заменить картинку
                // ── выбираем и обрезаем изображение в соотношении 1:1.1 (ширина:высота)
                final aspectRatio = 1.0 / 1.1;
                final processed = await ImagePickerHelper.pickAndProcessImage(
                  context: context,
                  aspectRatio: aspectRatio,
                  maxSide: ImageCompressionPreset.post.maxSide,
                  jpegQuality: ImageCompressionPreset.post.quality,
                  cropTitle: 'Обрезка фотографии',
                );
                if (processed == null || !mounted) return;

                setState(() {
                  _images[photoIndex] = processed;
                  _updatePublishState();
                });
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  color: AppColors.getBackgroundColor(context),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.getBackgroundColor(context),
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
              ),
            ),
            // Кнопка удаления в правом верхнем углу
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                onTap: () => _handleDeletePhoto(file),
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
      ),
    );
  }

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          const BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 20,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocusNode,
        maxLines: 20,
        minLines: 10,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Расскажите, о чём ваш пост',
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

  /// Выпадающий список для выбора видимости
  Widget _buildVisibilitySelector() {
    const List<String> options = [
      'Все пользователи',
      'Только подписчики',
      'Только Вы',
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          const BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 20,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            borderSide: BorderSide.none,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options[_selectedVisibility],
            isExpanded: true,
            alignment: AlignmentDirectional.centerStart,
            onChanged: (String? newValue) {
              if (newValue != null) {
                final index = options.indexOf(newValue);
                if (index != -1) {
                  setState(() {
                    _selectedVisibility = index;
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
      ),
    );
  }

  /// Кнопка публикации
  Widget _buildPublishButton() {
    final formState = ref.watch(formStateProvider);
    final isSubmitting = formState.isSubmitting;
    final isEnabled = _canPublish && !isSubmitting;
    final textColor = AppColors.getSurfaceColor(context);

    // ────────────────────────────────────────────────────────────────
    // 💾 КНОПКА ПУБЛИКАЦИИ (единый стиль с экраном добавления)
    // ────────────────────────────────────────────────────────────────
    final button = ElevatedButton(
      onPressed: isEnabled ? _submitPost : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        shape: const StadiumBorder(),
        minimumSize: const Size(double.infinity, 50),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: isSubmitting
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CupertinoActivityIndicator(
                    radius: 9,
                    color: textColor,
                  ),
                ),
                Text(
                  'Опубликовать',
                  style: AppTextStyles.h15w5.copyWith(
                    color: textColor,
                    height: 1.0,
                  ),
                ),
              ],
            )
          : Text(
              'Опубликовать',
              style: AppTextStyles.h15w5.copyWith(
                color: textColor,
                height: 1.0,
              ),
            ),
    );

    if (isSubmitting) {
      return IgnorePointer(child: button);
    }

    return button;
  }

  /// Сохраняет пост на сервер
  Future<void> _submitPost() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting || !_canPublish) return;

    final text = _descriptionController.text.trim();
    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        Map<String, dynamic> data;

        if (_images.isEmpty) {
          // JSON-запрос (без файлов)
          data = await api.post(
            '/create_post.php',
            body: {
              'user_id': widget.userId.toString(),
              'text': text,
              'privacy': _selectedVisibility.toString(),
            },
          );
        } else {
          // Multipart-запрос (с файлами)
          final files = <String, File>{};
          for (int i = 0; i < _images.length; i++) {
            files['images[$i]'] = _images[i];
          }

          data = await api.postMultipart(
            '/create_post.php',
            files: files,
            fields: {
              'user_id': widget.userId.toString(),
              'text': text,
              'privacy': _selectedVisibility.toString(),
            },
            timeout: const Duration(seconds: 60),
          );
        }

        // Проверяем разные форматы ответа API
        bool success = false;
        String? errorMessage;

        // Формат 1: прямой success в корне
        if (data['success'] == true) {
          success = true;
        }
        // Формат 2: success в data массиве
        else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
          final firstItem = (data['data'] as List)[0];
          if (firstItem is Map<String, dynamic>) {
            if (firstItem['success'] == true) {
              success = true;
            } else {
              errorMessage = firstItem['message']?.toString();
            }
          }
        }
        // Формат 3: success в data объекте
        else if (data['data'] is Map<String, dynamic>) {
          final dataObj = data['data'] as Map<String, dynamic>;
          if (dataObj['success'] == true) {
            success = true;
          } else {
            errorMessage = dataObj['message']?.toString();
          }
        }
        // Формат 4: error или message в корне
        else if (data['error'] != null || data['message'] != null) {
          errorMessage = (data['error'] ?? data['message']).toString();
        }
        // Неизвестный формат
        else {
          errorMessage = 'Неизвестный формат ответа сервера';
        }

        if (!success) {
          final msg = errorMessage ?? 'Ошибка сервера';
          throw Exception(msg);
        }
      },
      onSuccess: () async {
        // Очищаем форму
        _descriptionController.clear();
        if (!mounted) return;
        setState(() {
          _images.clear();
          _canPublish = false;
        });

        // Обновляем ленту
        await ref.read(lentaProvider(widget.userId).notifier).forceRefresh();

        // Небольшая задержка для гарантии обновления данных на сервере
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;
        Navigator.pop(context, true);
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при создании поста');
      },
    );
  }

  /// Обработчик добавления фотографий к посту
  Future<void> _handleAddPhotos() async {
    try {
      // ── выбираем и обрезаем изображения в соотношении 1:1.1 (ширина:высота)
      // Используем стандартный pickMultiImage, затем обрезаем каждое
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: ImagePickerHelper.maxPickerDimension,
        maxHeight: ImagePickerHelper.maxPickerDimension,
        imageQuality: ImagePickerHelper.pickerImageQuality,
      );
      if (pickedFiles.isEmpty || !mounted) return;

      // Соотношение сторон 1:1.1 (ширина:высота)
      final aspectRatio = 1.0 / 1.1;

      // ── обрезаем и сжимаем все выбранные изображения
      final compressedFiles = <File>[];
      for (int i = 0; i < pickedFiles.length; i++) {
        if (!mounted) return;

        final picked = pickedFiles[i];
        // Обрезаем изображение в соотношении 1:1.1 (ширина:высота)
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: aspectRatio,
          title: 'Обрезка фотографии ${i + 1}',
        );

        if (cropped == null)
          continue; // Пропускаем, если пользователь отменил обрезку

        // Сжимаем обрезанное изображение
        final compressed = await compressLocalImage(
          sourceFile: cropped,
          maxSide: ImageCompressionPreset.post.maxSide,
          jpegQuality: ImageCompressionPreset.post.quality,
        );

        // Удаляем временный файл обрезки
        if (cropped.path != compressed.path) {
          try {
            await cropped.delete();
          } catch (_) {
            // Игнорируем ошибки удаления
          }
        }

        compressedFiles.add(compressed);
      }

      if (compressedFiles.isEmpty || !mounted) return;

      setState(() {
        _images.addAll(compressedFiles);
        _updatePublishState();
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  /// Обработчик удаления фотографии
  void _handleDeletePhoto(File file) {
    setState(() {
      _images.remove(file);
      _updatePublishState();
    });
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
}
