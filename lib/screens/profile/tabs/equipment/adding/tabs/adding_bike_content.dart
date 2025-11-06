import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../../theme/app_theme.dart';
import '../../../../../../widgets/primary_button.dart';
import '../../../../../../service/api_service.dart';
import '../../../../../../service/auth_service.dart';
import '../widgets/autocomplete_text_field.dart';

/// Контент для сегмента «Велосипед»
class AddingBikeContent extends StatefulWidget {
  const AddingBikeContent({super.key});

  @override
  State<AddingBikeContent> createState() => _AddingBikeContentState();
}

class _AddingBikeContentState extends State<AddingBikeContent> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  DateTime _inUseFrom = DateTime.now();
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;
  
  // Для автодополнения
  final ApiService _api = ApiService();

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ПОИСК БРЕНДОВ
  // ─────────────────────────────────────────────────────────────────────
  Future<List<String>> _searchBrands(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final data = await _api.post(
        '/search_equipment_brands.php',
        body: {
          'query': query,
          'type': 'bike',
        },
      );

      if (data['success'] == true) {
        return (data['brands'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
    } catch (e) {
      // Игнорируем ошибки при поиске
    }

    return [];
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ПОИСК МОДЕЛЕЙ
  // ─────────────────────────────────────────────────────────────────────
  Future<List<String>> _searchModels(String query) async {
    final brand = _brandCtrl.text.trim();
    if (brand.isEmpty || query.isEmpty) {
      return [];
    }

    try {
      final data = await _api.post(
        '/search_equipment_models.php',
        body: {
          'brand': brand,
          'query': query,
          'type': 'bike',
        },
      );

      if (data['success'] == true) {
        return (data['models'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
    } catch (e) {
      // Игнорируем ошибки при поиске
    }

    return [];
  }

  Future<void> _pickDate() async {
    // Переменная для хранения выбранной даты, объявлена вне builder
    DateTime selectedDate = _inUseFrom;
    
    await showCupertinoModalPopup(
      context: context,
      builder: (popupContext) {
        return Container(
          height: 280,
          color: AppColors.surface,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(popupContext),
                      child: const Text('Отменить'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () {
                        // Обновляем состояние только если виджет еще смонтирован
                        if (mounted) {
                          setState(() => _inUseFrom = selectedDate);
                        }
                        Navigator.pop(popupContext);
                      },
                      child: const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
                indent: 12,
                endIndent: 12,
              ),

              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _inUseFrom,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) {
                    // Обновляем переменную, объявленную в области видимости _pickDate
                    selectedDate = d;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ВЫБОР ИЗОБРАЖЕНИЯ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) {
      setState(() => _imageFile = File(x.path));
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ОТПРАВКА ДАННЫХ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _saveEquipment() async {
    if (_isLoading) return;

    // Валидация
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final kmStr = _kmCtrl.text.trim();

    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите бренд')),
      );
      return;
    }

    if (model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите модель')),
      );
      return;
    }

    // Дистанция необязательна, по умолчанию 0
    int km = 0;
    if (kmStr.isNotEmpty) {
      final parsedKm = int.tryParse(kmStr);
      if (parsedKm == null || parsedKm < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Некорректная дистанция')),
        );
        return;
      }
      km = parsedKm;
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь не авторизован')),
          );
        }
        return;
      }

      // Формируем данные
      final files = <String, File>{};
      final fields = <String, String>{
        'user_id': userId.toString(),
        'type': 'bike',
        'name': model,
        'brand': brand,
        'dist': km.toString(),
        'main': '0', // По умолчанию не на главном экране
      };

      // Добавляем изображение, если есть
      if (_imageFile != null) {
        files['image'] = _imageFile!;
      }

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        data = await api.post('/add_equipment.php', body: fields);
      } else {
        // Multipart запрос с файлами
        data = await api.postMultipart(
          '/add_equipment.php',
          files: files,
          fields: fields,
          timeout: const Duration(seconds: 60),
        );
      }

      // Проверяем ответ
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Снаряжение успешно добавлено')),
          );
          // Закрываем экран после успешного сохранения
          Navigator.of(context).pop();
        }
      } else {
        final errorMsg = data['message'] ?? 'Ошибка при сохранении';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String get _dateLabel {
    final d = _inUseFrom;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 170,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/add_bike.png',
                        width: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Отображение выбранного изображения или заглушки
                    if (_imageFile != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Image.file(
                            _imageFile!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    // кнопка «добавить фото» — снизу-справа
                    Positioned(
                      right: 70,
                      bottom: 18,
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Добавить фото',
                          onPressed: _pickImage,
                          icon: const Icon(
                            Icons.add_a_photo_outlined,
                            size: 28,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
                indent: 12,
                endIndent: 12,
              ),

              _FieldRow(
                title: 'Бренд',
                child: AutocompleteTextField(
                  controller: _brandCtrl,
                  hint: 'Введите бренд',
                  onSearch: _searchBrands,
                  onChanged: () {
                    // Очищаем модель при изменении бренда
                    setState(() {
                      _modelCtrl.clear();
                    });
                  },
                ),
              ),
              _FieldRow(
                title: 'Модель',
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _brandCtrl,
                  builder: (context, brandValue, child) {
                    return AutocompleteTextField(
                      controller: _modelCtrl,
                      hint: 'Введите модель',
                      onSearch: _searchModels,
                      enabled: brandValue.text.trim().isNotEmpty,
                    );
                  },
                ),
              ),
              _FieldRow(
                title: 'В использовании с',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _dateLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.textSecondary, // правые значения серым
                      ),
                    ),
                  ),
                ),
              ),
              _FieldRow(
                title: 'Добавленная дистанция, км',
                child: _RightTextField(
                  controller: _kmCtrl,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─────────────── Кнопка «Сохранить» — глобальный PrimaryButton ───────────────
        Center(
          child: PrimaryButton(
            text: 'Сохранить',
            onPressed: _saveEquipment,
            isLoading: _isLoading,
            width: 220, // унифицированная ширина, как и в кроссовках
          ),
        ),
      ],
    );
  }
}

// — служебные виджеты (с типографикой 14 pt и серым справа)
class _FieldRow extends StatelessWidget {
  final String title;
  final Widget child;
  const _FieldRow({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: child),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.divider,
          indent: 12,
          endIndent: 12,
        ),
      ],
    );
  }
}

class _RightTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _RightTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  State<_RightTextField> createState() => _RightTextFieldState();
}

class _RightTextFieldState extends State<_RightTextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      textAlign: TextAlign.right,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        border: InputBorder.none,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}
