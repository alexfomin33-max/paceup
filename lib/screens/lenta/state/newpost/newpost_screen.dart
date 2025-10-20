import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar

/// 👉 ЗАМЕНИ на свой URL эндпоинта создания поста
const String kCreatePostUrl = 'http://api.paceup.ru/create_post.php';

/// Безопасный JSON-декодер: чистит BOM и гарантирует Map
Map<String, dynamic> safeDecodeJsonAsMap(List<int> bodyBytes) {
  final raw = utf8.decode(bodyBytes);
  final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  final v = json.decode(cleaned);
  if (v is Map<String, dynamic>) return v;
  throw const FormatException('JSON is not an object');
}

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
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          Navigator.pop(context); // свайп вправо закрывает экран
        }
      },
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
    final uri = Uri.parse(kCreatePostUrl);

    try {
      Map<String, dynamic> data;

      if (_images.isEmpty) {
        // JSON-запрос (без файлов)
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_id': widget.userId,
                'text': text,
                'privacy': 'public',
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          debugPrint(
            'POST ${res.request?.url} -> ${res.statusCode}\n${res.body}',
          );
          throw Exception('HTTP ${res.statusCode}');
        }

        try {
          data = safeDecodeJsonAsMap(res.bodyBytes);
        } catch (_) {
          debugPrint('Bad JSON from server: ${res.body}');
          throw const FormatException('Невалидный JSON от сервера');
        }
      } else {
        // Multipart-запрос (с файлами)
        final req = http.MultipartRequest('POST', uri);
        req.fields['user_id'] = widget.userId.toString();
        req.fields['text'] = text;
        req.fields['privacy'] = 'public';

        for (final file in _images) {
          req.files.add(
            await http.MultipartFile.fromPath('images[]', file.path),
          );
        }

        final streamed = await req.send().timeout(const Duration(seconds: 60));
        final res = await http.Response.fromStream(streamed);

        if (res.statusCode < 200 || res.statusCode >= 300) {
          debugPrint(
            'POST(multipart) ${res.request?.url} -> ${res.statusCode}\n${res.body}',
          );
          throw Exception('HTTP ${res.statusCode}');
        }

        try {
          data = safeDecodeJsonAsMap(res.bodyBytes);
        } catch (_) {
          debugPrint('Bad JSON from server: ${res.body}');
          throw const FormatException('Невалидный JSON от сервера');
        }
      }

      if (data['success'] == true) {
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
        final msg = (data['message'] ?? 'Ошибка сервера').toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      // Один catch без «мертвых» веток: разбираем типы внутри
      if (e is TimeoutException) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Таймаут запроса')));
      } else if (e is SocketException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сеть недоступна: ${e.message}')),
        );
      } else if (e is http.ClientException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка HTTP-клиента: ${e.message}')),
        );
      } else if (e is FormatException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Невалидный JSON от сервера')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка запроса: $e')));
      }
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
