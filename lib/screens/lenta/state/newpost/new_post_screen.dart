// lib/screens/lenta/state/newpost/new_post_screen.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../theme/app_theme.dart';
import '../../../../utils/local_image_compressor.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../service/api_service.dart';
import '../../../../providers/lenta/lenta_provider.dart';

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

  // Состояние загрузки
  bool _isLoading = false;

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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Новый пост'),
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
                  const SizedBox(height: 8),
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

                  // ────────────────────────────────────────────────────────────────
                  // 💾 КНОПКА ПУБЛИКАЦИИ
                  // ────────────────────────────────────────────────────────────────
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
    // Общее количество элементов: кнопка добавления + фотографии
    final totalItems = 1 + _images.length;

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: totalItems,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Первый элемент — кнопка добавления фото
          if (index == 0) {
            return _buildAddPhotoButton();
          }
          // Остальные элементы — фотографии
          final photoIndex = index - 1;
          final file = _images[photoIndex];
          return _buildPhotoItem(file, photoIndex);
        },
      ),
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton() {
    return Builder(
      builder: (context) => GestureDetector(
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
      ),
    );
  }

  /// Элемент фотографии с кнопкой удаления
  Widget _buildPhotoItem(File file, int photoIndex) {
    return Builder(
      builder: (context) => Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () async {
              // По тапу можно заменить картинку
              final picker = ImagePicker();
              final XFile? pickedFile = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (pickedFile == null) return;

              // ── сжимаем выбранное фото перед заменой
              final compressed = await compressLocalImage(
                sourceFile: File(pickedFile.path),
                maxSide: 1600,
                jpegQuality: 80,
              );
              if (!mounted) return;

              setState(() {
                _images[photoIndex] = compressed;
                _updatePublishState();
              });
            },
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.getBackgroundColor(context),
              ),
              clipBehavior: Clip.hardEdge,
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
                  border: Border.all(color: AppColors.getBorderColor(context)),
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
  }

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return Builder(
      builder: (context) => TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocusNode,
        maxLines: 24,
        minLines: 14,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Расскажите, о чём ваш пост...',
          hintStyle: AppTextStyles.h14w4Place,
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

    return Builder(
      builder: (context) => InputDecorator(
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
    return PrimaryButton(
      text: 'Опубликовать',
      onPressed: !_isLoading ? _submitPost : () {},
      width: 190,
      isLoading: _isLoading,
      enabled: _canPublish,
    );
  }

  /// Сохраняет пост на сервер
  Future<void> _submitPost() async {
    if (_isLoading || !_canPublish) return;

    final text = _descriptionController.text.trim();

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
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

      if (success) {
        // Очищаем форму
        _descriptionController.clear();
        setState(() {
          _images.clear();
          _canPublish = false;
        });

        // Обновляем ленту
        await ref.read(lentaProvider(widget.userId).notifier).forceRefresh();

        // Небольшая задержка для гарантии обновления данных на сервере
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (!mounted) return;
        final msg = errorMessage ?? 'Ошибка сервера';
        _showError(msg);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError('Ошибка: $e');
    } catch (e) {
      if (!mounted) return;
      _showError('Ошибка при создании поста: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Обработчик добавления фотографий к посту
  Future<void> _handleAddPhotos() async {
    final picker = ImagePicker();

    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      // ── подготавливаем сжатые версии всех выбранных фотографий
      final compressedFiles = <File>[];
      for (final file in pickedFiles) {
        final compressed = await compressLocalImage(
          sourceFile: File(file.path),
          maxSide: 1600,
          jpegQuality: 80,
        );
        compressedFiles.add(compressed);
      }

      if (!mounted) return;
      setState(() {
        _images.addAll(compressedFiles);
        _updatePublishState();
      });
    } on PlatformException catch (e) {
      if (mounted) {
        _showError(
          'Нет доступа к галерее: ${e.message ?? 'неизвестная ошибка'}.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Не удалось загрузить фотографии. Попробуйте ещё раз.');
      }
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
}
