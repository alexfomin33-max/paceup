// ignore_for_file: avoid_print

// lib/screens/lenta/state/newpost/edit_post_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../service/api_service.dart';

/// Модель «существующего» изображения, пришедшего с бэка
class _ExistingImage {
  final String url;
  bool keep;
  // ignore: unused_element_parameter
  _ExistingImage(this.url, {this.keep = true});
}

/// 🔹 Экран редактирования поста
class EditPostScreen extends StatefulWidget {
  final int userId;
  final int postId;

  /// Текст и изображения поста на момент открытия экрана.
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
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  // существующие картинки (по URL) — можно помечать keep=false
  late final List<_ExistingImage> _existing = widget.initialImageUrls
      .map((u) => _ExistingImage(u))
      .toList();

  // новые картинки, выбранные на устройстве
  final List<File> _newImages = [];

  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _descController = TextEditingController(
    text: widget.initialText,
  );

  bool _canSave = false; // активность кнопки «Сохранить»
  bool _loading = false; // индикатор отправки

  @override
  void initState() {
    super.initState();
    _descController.addListener(_updateSaveState);
    _updateSaveState();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // есть ли какие-либо изменения относительно исходных?
  bool _hasChanges() {
    final textChanged =
        _descController.text.trim() != widget.initialText.trim();

    final existingKeptUrls = _existing
        .where((e) => e.keep)
        .map((e) => e.url)
        .toList();
    final initiallyUrls = widget.initialImageUrls;

    // сравним множества сохранённых URL с исходными
    final sameExisting =
        existingKeptUrls.length == initiallyUrls.length &&
        existingKeptUrls.toSet().containsAll(initiallyUrls.toSet());

    final newFilesAdded = _newImages.isNotEmpty;

    return textChanged || !sameExisting || newFilesAdded;
  }

  void _updateSaveState() {
    setState(() => _canSave = _hasChanges() && !_loading);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,

        appBar: const PaceAppBar(title: 'Редактировать пост'),

        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 2),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Фото поста',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 8),

              // 🔹 Горизонтальный список фото: + кнопка добавления
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _addPhotoButton(),
                    const SizedBox(width: 12),
                    ..._buildExistingPreviews(),
                    ..._newImages.map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _newPhotoPreview(file),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 🔹 Описание
              Expanded(child: _descriptionInput()),

              const SizedBox(height: 24),

              // 🔹 Кнопка «Сохранить»
              Center(child: _saveButton(context)),
            ],
          ),
        ),
      ),
    );
  }

  // Кнопка «добавить фото» — как в NewPost
  Widget _addPhotoButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 76,
        height: 76,
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

  // Превью существующих картинок (по URL) с возможностью «удалить/вернуть»
  List<Widget> _buildExistingPreviews() {
    return _existing.map((ex) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () async {
                // По тапу предложим заменить файл (станет НОВОЙ картинкой),
                // а текущую пометим на удаление (keep=false).
                final XFile? picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (picked != null) {
                  setState(() {
                    ex.keep = false;
                    _newImages.add(File(picked.path));
                    _updateSaveState();
                  });
                }
              },
              child: Opacity(
                opacity: ex.keep ? 1.0 : 0.35,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    color: AppColors.background,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Image.network(ex.url, fit: BoxFit.cover),
                ),
              ),
            ),

            // Кнопка удалить/вернуть
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    ex.keep = !ex.keep;
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
                    ex.keep
                        ? CupertinoIcons.clear_circled_solid
                        : CupertinoIcons.arrow_uturn_left_circle_fill,
                    size: 20,
                    color: ex.keep ? AppColors.error : AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Превью НОВОГО фото (локальный файл) с кнопкой удаления
  Widget _newPhotoPreview(File file) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () async {
            // заменить выбранное новое фото на другое
            final XFile? pickedFile = await _picker.pickImage(
              source: ImageSource.gallery,
            );
            if (pickedFile != null) {
              setState(() {
                final idx = _newImages.indexOf(file);
                if (idx != -1) _newImages[idx] = File(pickedFile.path);
                _updateSaveState();
              });
            }
          },
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.background,
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.file(file, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _newImages.remove(file);
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

  // Поле описания
  Widget _descriptionInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: _descController,
        expands: true,
        maxLines: null,
        minLines: null,
        decoration: const InputDecoration.collapsed(
          hintText: 'Обновите описание…',
          hintStyle: AppTextStyles.h14w4Place,
        ),
      ),
    );
  }

  // Кнопка «Сохранить»
  Widget _saveButton(BuildContext context) {
    return SizedBox(
      width: 181,
      height: 40,
      child: ElevatedButton(
        onPressed: (_canSave && !_loading) ? _submitEdit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canSave
              ? AppColors.brandPrimary
              : AppColors.disabledBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.surface,
                ),
              )
            : const Text(
                'Сохранить',
                style: TextStyle(color: AppColors.surface),
              ),
      ),
    );
  }

  // Отправка изменений на API
  Future<void> _submitEdit() async {
    if (_loading) return;

    final text = _descController.text.trim();
    final keepUrls = _existing.where((e) => e.keep).map((e) => e.url).toList();
    final hasNewFiles = _newImages.isNotEmpty;

    setState(() => _loading = true);
    final api = ApiService();

    try {
      Map<String, dynamic> data;

      if (!hasNewFiles) {
        // —— JSON: только текст/состав существующих картинок
        data = await api.post(
          '/update_post.php',
          body: {
            'post_id': '${widget.postId}', // 🔹 PHP ожидает строки
            'user_id': '${widget.userId}', // 🔹 PHP ожидает строки
            'text': text,
            'privacy': 'public',
            'keep_images': keepUrls,
          },
        );
      } else {
        // —— Multipart: добавились новые файлы
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
            'privacy': 'public',
            'keep_images': keepUrls.toString(),
          },
          timeout: const Duration(seconds: 60),
        );
      }

      // 🔍 Дебаг: проверяем формат ответа
      print('🔍 [EDIT POST] Response: $data');

      // 🔹 Сервер может возвращать массив внутри 'data'
      final actualData =
          data['data'] is List && (data['data'] as List).isNotEmpty
          ? (data['data'] as List)[0] as Map<String, dynamic>
          : data;

      if (actualData['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Изменения сохранены')));
        Navigator.pop(context, true); // вернёмся с флагом «обновлено»
      } else {
        final msg = (actualData['message'] ?? 'Ошибка сервера').toString();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
      _updateSaveState();
    }
  }

  // Выбор нового изображения
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _newImages.add(File(pickedFile.path));
        _updateSaveState();
      });
    }
  }
}
