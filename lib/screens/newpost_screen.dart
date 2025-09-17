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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10) {
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
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
                const SizedBox(height: 16),
                _descriptionInput(),
                const SizedBox(height: 24),
                _publishButton(context),
              ],
            ),
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
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFFF3F4F6),
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

  // 🔹 Превью выбранного фото
  Widget _photoPreview(File file) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFBDC1CA), width: 1),
        image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
      ),
    );
  }

  // 🔹 Ввод описания
  Widget _descriptionInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border, // 🔹 рамка по твоей теме
          width: 1,
        ),
      ),
      child: const TextField(
        maxLines: 15,
        decoration: InputDecoration.collapsed(
          hintText: 'Добавьте описание...',
          hintStyle: TextStyle(
            color: Color(0xFF8F8F8F), // 🔹 красный цвет подсказки
          ),
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
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Пост опубликован!')));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          'Опубликовать',
          style: TextStyle(color: Colors.white), // белый текст
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

    // прямоугольник по периметру
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));

    // превращаем линию в пунктир
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
