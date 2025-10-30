import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../service/api_service.dart';

/// 🔹 Экран создания нового поста
class NewPostScreen extends StatefulWidget {
  final int userId;
  const NewPostScreen({super.key, required this.userId});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final List<File> _images = []; // выбранные картинки
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  bool _canPublish = false; // доступность кнопки
  bool _loading = false; // индикатор отправки

  @override
  void initState() {
    super.initState();
    _descController.addListener(_updatePublishState);
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _updatePublishState() {
    setState(() {
      _canPublish =
          _images.isNotEmpty || _descController.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,

        // ───── глобальная шапка
        appBar: const PaceAppBar(title: 'Новый пост'),

        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 2),

              // 🔹 Заголовок
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Фото поста',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 8),

              // 🔹 Горизонтальный список фото
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _addPhotoButton(),
                    const SizedBox(width: 12),
                    ..._images.map(
                      (file) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _photoPreview(file),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🔹 описание растягивается
              Expanded(child: _descriptionInput()),
              const SizedBox(height: 24),

              // 🔹 Кнопка снова по центру
              Center(child: _publishButton(context)),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Кнопка добавления фото — без пунктира, с иконкой фото
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

  // 🔹 Превью выбранного фото (без рамки) с кнопкой удаления
  Widget _photoPreview(File file) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () async {
            // по тапу можно заменить картинку
            final XFile? pickedFile = await _picker.pickImage(
              source: ImageSource.gallery,
            );
            if (pickedFile != null) {
              setState(() {
                final idx = _images.indexOf(file);
                if (idx != -1) {
                  _images[idx] = File(pickedFile.path);
                }
                _updatePublishState();
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
                _images.remove(file);
                _updatePublishState();
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

  // 🔹 Поле описания — та же типографика и отступы
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
        expands: true, // 🔹 растягивается по высоте
        maxLines: null,
        minLines: null,
        decoration: const InputDecoration.collapsed(
          hintText: 'Добавьте описание...',
          hintStyle: AppTextStyles.h14w4Place,
        ),
      ),
    );
  }

  // 🔹 Кнопка публикации (размеры/цвета сохранены)
  Widget _publishButton(BuildContext context) {
    return SizedBox(
      width: 181,
      height: 40,
      child: ElevatedButton(
        onPressed: (_canPublish && !_loading) ? _submitPost : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canPublish
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
                'Опубликовать',
                style: TextStyle(color: AppColors.surface),
              ),
      ),
    );
  }

  // 🔹 Отправка поста на API
  Future<void> _submitPost() async {
    if (_loading) return;
    final text = _descController.text.trim();
    if (_images.isEmpty && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте текст или вложения')),
      );
      return;
    }

    setState(() => _loading = true);
    final api = ApiService();

    try {
      Map<String, dynamic> data;

      if (_images.isEmpty) {
        // JSON-запрос (без файлов)
        data = await api.post(
          '/create_post.php',
          body: {
            'user_id': '${widget.userId}',
            'text': text,
            'privacy': 'public',
          }, // 🔹 PHP ожидает строки
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
            'privacy': 'public',
          },
          timeout: const Duration(seconds: 60),
        );
      }

      // 🔍 Дебаг: проверяем формат ответа
      print('🔍 [CREATE POST] Response: $data');

      // 🔹 Сервер может возвращать массив внутри 'data'
      final actualData =
          data['data'] is List && (data['data'] as List).isNotEmpty
          ? (data['data'] as List)[0] as Map<String, dynamic>
          : data;

      if (actualData['success'] == true) {
        _descController.clear();
        setState(() {
          _images.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Пост опубликован')));
          Navigator.pop(context, true);
        }
      } else {
        if (!mounted) {
          return; // 🔹 Проверка mounted перед использованием context
        }
        final msg = (actualData['message'] ?? 'Ошибка сервера').toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔹 Выбор изображения из галереи
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
        _updatePublishState();
      });
    }
  }
}
