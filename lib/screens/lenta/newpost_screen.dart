import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';

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
  const NewPostScreen({super.key});

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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Новый пост', style: AppTextStyles.h1),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
        ),
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
          borderRadius: BorderRadius.circular(6),
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(CupertinoIcons.photo, size: 28, color: Colors.grey),
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
              borderRadius: BorderRadius.circular(6),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                CupertinoIcons.clear_circled_solid,
                size: 20,
                color: Colors.red,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: _descController,
        expands: true, // 🔹 растягивается по высоте
        maxLines: null,
        minLines: null,
        decoration: const InputDecoration.collapsed(
          hintText: 'Добавьте описание...',
          hintStyle: TextStyle(color: Color(0xFF8F8F8F)),
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
          backgroundColor: _canPublish ? AppColors.secondary : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Опубликовать', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 🔹 Отправка поста на API
  Future<void> _submitPost() async {
    if (_loading) return;
    if (!_canPublish) return;

    setState(() => _loading = true);
    try {
      Map<String, dynamic> respJson;

      if (_images.isEmpty) {
        // Без файлов — обычный JSON
        final res = await http.post(
          Uri.parse(kCreatePostUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            // TODO: добавь user_id / token на своей стороне, если нужно
            'text': _descController.text.trim(),
          }),
        );
        respJson = safeDecodeJsonAsMap(res.bodyBytes);
      } else {
        // Есть картинки — multipart
        final req = http.MultipartRequest('POST', Uri.parse(kCreatePostUrl));
        req.fields['text'] = _descController.text.trim();
        // TODO: добавь сюда req.fields['user_id'] или токен, если это требуется сервером

        for (final file in _images) {
          final mf = await http.MultipartFile.fromPath('images[]', file.path);
          req.files.add(mf);
        }

        final streamed = await req.send();
        final res = await http.Response.fromStream(streamed);
        respJson = safeDecodeJsonAsMap(res.bodyBytes);
      }

      if (respJson['success'] == true) {
        // Очистим форму и вернёмся назад с флагом обновления
        _descController.clear();
        setState(() {
          _images.clear();
          _canPublish = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Пост опубликован')));
          Navigator.pop(context, true);
        }
      } else {
        final msg = (respJson['message'] ?? 'Неизвестная ошибка').toString();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка: $msg')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Сбой сети: $e')));
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


/*import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';

/// 🔹 Экран создания нового поста
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final List<File> _images = []; // выбранные картинки
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  bool _canPublish = false; // доступность кнопки

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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Новый пост', style: AppTextStyles.h1),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
        ),
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
          borderRadius: BorderRadius.circular(6),
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(CupertinoIcons.photo, size: 28, color: Colors.grey),
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
              borderRadius: BorderRadius.circular(6),
              // ВАЖНО: без рамки у выбранного фото
              image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _images.remove(file);
                _updatePublishState();
              });
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // 🔹 Ввод описания
  Widget _descriptionInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: _descController,
        expands: true, // 🔹 растягивается по высоте
        maxLines: null,
        minLines: null,
        decoration: const InputDecoration.collapsed(
          hintText: 'Добавьте описание...',
          hintStyle: TextStyle(color: Color(0xFF8F8F8F)),
        ),
      ),
    );
  }

  // 🔹 Кнопка публикации
  Widget _publishButton(BuildContext context) {
    return SizedBox(
      width: 181,
      height: 40,
      child: ElevatedButton(
        onPressed: _canPublish
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пост опубликован!')),
                );
              }
            : null, // 🔹 disabled если _canPublish == false
        style: ElevatedButton.styleFrom(
          backgroundColor: _canPublish ? AppColors.secondary : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          'Опубликовать',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
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
*/