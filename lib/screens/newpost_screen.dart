import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'dart:io';

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

  // 🔹 Кнопка добавления фото (пунктирная рамка)
  Widget _addPhotoButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: AppColors.background,
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: const Center(
            child: Icon(Icons.add, size: 36, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  // 🔹 Превью выбранного фото с кнопкой удаления
  Widget _photoPreview(File file) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFBDC1CA), width: 1),
            image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _images.remove(file);
                _updatePublishState();
              });
            },
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
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

/// 🔹 Кастомный рисовальщик пунктирной рамки
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    final paint = Paint()
      ..color = const Color(0xFFBDC1CA)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
