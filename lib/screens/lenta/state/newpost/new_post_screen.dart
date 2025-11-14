import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/primary_button.dart';
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
  final FocusNode _descFocusNode = FocusNode();

  bool _canPublish = false; // доступность кнопки
  bool _loading = false; // индикатор отправки

  @override
  void initState() {
    super.initState();
    _descController.addListener(_updatePublishState);
    _descFocusNode.addListener(_updatePublishState);
  }

  @override
  void dispose() {
    _descController.dispose();
    _descFocusNode.dispose();
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

        body: GestureDetector(
          // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Padding(
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
                const SizedBox(height: 20),

                // 🔹 описание растягивается
                Expanded(child: _descriptionInput()),
                const SizedBox(height: 24),

                // 🔹 Кнопка снова по центру
                Center(child: _publishButton(context)),
              ],
            ),
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

  // 🔹 Поле описания с динамическим лейблом
  Widget _descriptionInput() {
    // ── определяем, какой лейбл показывать
    final bool hasText = _descController.text.trim().isNotEmpty;
    final bool isFocused = _descFocusNode.hasFocus;
    final String labelText = (hasText || isFocused)
        ? 'Описание поста'
        : 'Добавьте описание';

    return TextField(
      controller: _descController,
      focusNode: _descFocusNode,
      expands: true, // 🔹 растягивается по высоте
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top, // 🔹 текст всегда сверху
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: AppTextStyles
            .h14w4Sec, // 🔹 стиль лейбла, когда он внутри поля (нет текста)
        floatingLabelStyle: TextStyle(
          color: AppColors.textSecondary,
        ), // 🔹 цвет лейбла, когда он всплывает (фокус или есть текст)
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        alignLabelWithHint: true, // 🔹 лейбл выравнивается с hintText
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

  // 🔹 Кнопка публикации
  Widget _publishButton(BuildContext context) {
    return PrimaryButton(
      text: 'Опубликовать',
      onPressed: _submitPost,
      width: 190,
      isLoading: _loading,
      enabled: _canPublish,
    );
  }

  // 🔹 Отправка поста на API
  Future<void> _submitPost() async {
    if (_loading || !_canPublish) return;
    final text = _descController.text.trim();

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
      print('🔍 [CREATE POST] Response type: ${data.runtimeType}');
      print('🔍 [CREATE POST] Response keys: ${data.keys.toList()}');

      // 🔹 Проверяем разные форматы ответа API
      bool success = false;
      String? errorMessage;

      // Формат 1: прямой success в корне
      if (data['success'] == true) {
        success = true;
        print('✅ [CREATE POST] Success (direct): true');
      }
      // Формат 2: success в data массиве
      else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
        final firstItem = (data['data'] as List)[0];
        if (firstItem is Map<String, dynamic>) {
          if (firstItem['success'] == true) {
            success = true;
            print('✅ [CREATE POST] Success (in data array): true');
          } else {
            errorMessage = firstItem['message']?.toString();
            print('❌ [CREATE POST] Error (in data array): $errorMessage');
          }
        }
      }
      // Формат 3: success в data объекте
      else if (data['data'] is Map<String, dynamic>) {
        final dataObj = data['data'] as Map<String, dynamic>;
        if (dataObj['success'] == true) {
          success = true;
          print('✅ [CREATE POST] Success (in data object): true');
        } else {
          errorMessage = dataObj['message']?.toString();
          print('❌ [CREATE POST] Error (in data object): $errorMessage');
        }
      }
      // Формат 4: error или message в корне
      else if (data['error'] != null || data['message'] != null) {
        errorMessage = (data['error'] ?? data['message']).toString();
        print('❌ [CREATE POST] Error (direct): $errorMessage');
      }
      // Неизвестный формат
      else {
        errorMessage = 'Неизвестный формат ответа сервера';
        print('❌ [CREATE POST] Unknown response format');
      }

      if (success) {
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
        final msg = errorMessage ?? 'Ошибка сервера';
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
