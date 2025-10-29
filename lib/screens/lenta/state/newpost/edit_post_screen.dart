// lib/screens/lenta/state/newpost/edit_post_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';

/// 👉 ЗАМЕНИ на свой URL эндпоинта редактирования поста
const String kUpdatePostUrl = 'http://api.paceup.ru/update_post.php';

/// Безопасный JSON-декодер: чистит BOM и гарантирует Map
Map<String, dynamic> safeDecodeJsonAsMap(List<int> bodyBytes) {
  final raw = utf8.decode(bodyBytes);
  final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  final v = json.decode(cleaned);
  if (v is Map<String, dynamic>) return v;
  throw const FormatException('JSON is not an object');
}

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
    final uri = Uri.parse(kUpdatePostUrl);

    try {
      Map<String, dynamic> data;

      if (!hasNewFiles) {
        // —— JSON: только текст/состав существующих картинок
        final payload = {
          'post_id': widget.postId,
          'user_id': widget.userId,
          'text': text,
          'privacy': 'public',
          // серверу передаём, какие старые картинки оставить
          'keep_images': keepUrls,
        };

        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30));

        if (res.statusCode < 200 || res.statusCode >= 300) {
          debugPrint(
            'POST ${res.request?.url} -> ${res.statusCode}\n${res.body}',
          );
          throw Exception('HTTP ${res.statusCode}');
        }

        data = safeDecodeJsonAsMap(res.bodyBytes);
      } else {
        // —— Multipart: добавились новые файлы
        final req = http.MultipartRequest('POST', uri);
        req.fields['post_id'] = widget.postId.toString();
        req.fields['user_id'] = widget.userId.toString();
        req.fields['text'] = text;
        req.fields['privacy'] = 'public';
        // keep_images как JSON-строка
        req.fields['keep_images'] = jsonEncode(keepUrls);

        for (final file in _newImages) {
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

        data = safeDecodeJsonAsMap(res.bodyBytes);
      }

      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Изменения сохранены')));
        Navigator.pop(context, true); // вернёмся с флагом «обновлено»
      } else {
        final msg = (data['message'] ?? 'Ошибка сервера').toString();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (!mounted) return;
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
