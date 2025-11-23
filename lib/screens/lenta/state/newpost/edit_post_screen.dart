// lib/screens/lenta/state/newpost/edit_post_screen.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/primary_button.dart';
import '../../../../service/api_service.dart';
import '../../../../providers/lenta/lenta_provider.dart';

/// Модель «существующего» изображения, пришедшего с бэка
class _ExistingImage {
  final String url;
  bool keep;
  _ExistingImage(this.url, {required this.keep});
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭКРАН РЕДАКТИРОВАНИЯ ПОСТА
/// ────────────────────────────────────────────────────────────────
/// Позволяет редактировать существующий пост с:
/// 1. Фотографиями поста (горизонтальная карусель)
///    - Существующие изображения (можно удалить/вернуть)
///    - Новые изображения (можно добавить)
/// 2. Описанием поста (текстовое поле)
/// ────────────────────────────────────────────────────────────────
class EditPostScreen extends ConsumerStatefulWidget {
  final int userId;
  final int postId;

  /// Текст и изображения поста на момент открытия экрана
  final String initialText;
  final List<String> initialImageUrls;

  const EditPostScreen({
    super.key,
    required this.userId,
    required this.postId,
    required this.initialText,
    required this.initialImageUrls,
  });

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  // ────────────────────────────────────────────────────────────────
  // 📝 КОНТРОЛЛЕРЫ И СОСТОЯНИЕ
  // ────────────────────────────────────────────────────────────────
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocusNode;

  // Существующие картинки (по URL) — можно помечать keep=false
  late final List<_ExistingImage> _existing = widget.initialImageUrls
      .map((u) => _ExistingImage(u, keep: true))
      .toList();

  // Новые картинки, выбранные на устройстве
  final List<File> _newImages = [];

  // Состояние загрузки
  bool _isLoading = false;

  // Доступность кнопки сохранения
  bool _canSave = false;

  // Состояние видимости: 0 = Все пользователи, 1 = Только подписчики, 2 = Только Вы
  int _selectedVisibility = 0;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialText);
    _descriptionFocusNode = FocusNode();
    _descriptionController.addListener(_updateSaveState);
    _descriptionFocusNode.addListener(_updateSaveState);
    _updateSaveState();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  /// Проверяет, есть ли какие-либо изменения относительно исходных
  bool _hasChanges() {
    final textChanged =
        _descriptionController.text.trim() != widget.initialText.trim();

    final existingKeptUrls = _existing
        .where((e) => e.keep)
        .map((e) => e.url)
        .toList();
    final initiallyUrls = widget.initialImageUrls;

    // Сравним множества сохранённых URL с исходными
    final sameExisting =
        existingKeptUrls.length == initiallyUrls.length &&
        existingKeptUrls.toSet().containsAll(initiallyUrls.toSet());

    final newFilesAdded = _newImages.isNotEmpty;

    return textChanged || !sameExisting || newFilesAdded;
  }

  /// Обновляет состояние доступности кнопки сохранения
  void _updateSaveState() {
    setState(() => _canSave = _hasChanges() && !_isLoading);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Редактировать пост'),
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
                  const Text(
                    'Фотографии поста',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildPhotoCarousel(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📝 2. ОПИСАНИЕ ПОСТА
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Описание поста',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildDescriptionInput(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 👁️ 3. КТО ВИДИТ ПОСТ (выпадающий список)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Кто видит пост',
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
  Widget _buildPhotoCarousel() {
    // Общее количество элементов: кнопка добавления + существующие + новые
    final totalItems = 1 + _existing.length + _newImages.length;

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
          // Следующие элементы — существующие изображения
          if (index <= _existing.length) {
            final existingIndex = index - 1;
            return _buildExistingPhotoItem(_existing[existingIndex]);
          }
          // Остальные элементы — новые фотографии
          final newIndex = index - 1 - _existing.length;
          return _buildNewPhotoItem(_newImages[newIndex], newIndex);
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

  /// Элемент существующего изображения (по URL) с возможностью удалить/вернуть
  Widget _buildExistingPhotoItem(_ExistingImage existing) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () async {
            // По тапу можно заменить файл (станет НОВОЙ картинкой),
            // а текущую пометим на удаление (keep=false)
            final picker = ImagePicker();
            final XFile? picked = await picker.pickImage(
              source: ImageSource.gallery,
            );
            if (picked != null) {
              setState(() {
                existing.keep = false;
                _newImages.add(File(picked.path));
                _updateSaveState();
              });
            }
          },
          child: Opacity(
            opacity: existing.keep ? 1.0 : 0.35,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.background,
              ),
              clipBehavior: Clip.hardEdge,
              child: Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final side = (90 * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: existing.url,
                    fit: BoxFit.cover,
                    memCacheWidth: side,
                    maxWidthDiskCache: side,
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
                  );
                },
              ),
            ),
          ),
        ),
        // Кнопка удалить/вернуть в правом верхнем углу
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                existing.keep = !existing.keep;
                _updateSaveState();
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                existing.keep
                    ? CupertinoIcons.clear_circled_solid
                    : CupertinoIcons.arrow_uturn_left_circle_fill,
                size: 20,
                color: existing.keep ? AppColors.error : AppColors.brandPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Элемент нового фото (локальный файл) с кнопкой удаления
  Widget _buildNewPhotoItem(File file, int photoIndex) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () async {
            // По тапу можно заменить картинку
            final picker = ImagePicker();
            final XFile? pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
            );
            if (pickedFile != null) {
              setState(() {
                _newImages[photoIndex] = File(pickedFile.path);
                _updateSaveState();
              });
            }
          },
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.background,
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.background,
                child: const Icon(
                  CupertinoIcons.photo,
                  size: 24,
                  color: AppColors.iconSecondary,
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
    );
  }

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return TextField(
      controller: _descriptionController,
      focusNode: _descriptionFocusNode,
      maxLines: 24,
      minLines: 14,
      textAlignVertical: TextAlignVertical.top,
      style: AppTextStyles.h14w4,
      decoration: InputDecoration(
        hintText: 'Обновите описание',
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
      onPressed: !_isLoading ? _submitEdit : () {},
      width: 190,
      isLoading: _isLoading,
      enabled: _canSave,
    );
  }

  /// Сохраняет изменения поста на сервер
  Future<void> _submitEdit() async {
    if (_isLoading || !_canSave) return;

    final text = _descriptionController.text.trim();
    final keepUrls = _existing.where((e) => e.keep).map((e) => e.url).toList();
    final hasNewFiles = _newImages.isNotEmpty;

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      Map<String, dynamic> data;

      if (!hasNewFiles) {
        // JSON-запрос: только текст/состав существующих картинок
        data = await api.post(
          '/update_post.php',
          body: {
            'post_id': widget.postId.toString(),
            'user_id': widget.userId.toString(),
            'text': text,
            'privacy': _selectedVisibility.toString(),
            'keep_images': keepUrls,
          },
        );
      } else {
        // Multipart-запрос: добавились новые файлы
        final files = <String, File>{};
        for (int i = 0; i < _newImages.length; i++) {
          files['images[$i]'] = _newImages[i];
        }

        data = await api.postMultipart(
          '/update_post.php',
          files: files,
          fields: {
            'post_id': widget.postId.toString(),
            'user_id': widget.userId.toString(),
            'text': text,
            'privacy': _selectedVisibility.toString(),
            'keep_images': keepUrls.toString(),
          },
          timeout: const Duration(seconds: 60),
        );
      }

      // Проверяем разные форматы ответа API
      bool success = false;
      String? errorMessage;

      // Сервер может возвращать массив внутри 'data'
      final actualData =
          data['data'] is List && (data['data'] as List).isNotEmpty
          ? (data['data'] as List)[0] as Map<String, dynamic>
          : data;

      // Формат 1: прямой success в корне
      if (actualData['success'] == true) {
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
      _showError('Ошибка при сохранении поста: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _updateSaveState();
      }
    }
  }

  /// Обработчик добавления фотографий к посту
  Future<void> _handleAddPhotos() async {
    final picker = ImagePicker();

    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      // Сохраняем выбранные файлы локально
      final files = pickedFiles.map((file) => File(file.path)).toList();
      setState(() {
        _newImages.addAll(files);
        _updateSaveState();
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
      _newImages.remove(file);
      _updateSaveState();
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
