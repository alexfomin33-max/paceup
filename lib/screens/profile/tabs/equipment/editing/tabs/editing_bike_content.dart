import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../../../theme/app_theme.dart';
import '../../../../../../../widgets/primary_button.dart';
import '../../../../../../../service/api_service.dart';
import '../../../../../../../service/auth_service.dart';
import '../../adding/widgets/autocomplete_text_field.dart';

/// Контент для редактирования велосипеда
class EditingBikeContent extends StatefulWidget {
  final int equipUserId; // ID записи в equip_user

  const EditingBikeContent({
    super.key,
    required this.equipUserId,
  });

  @override
  State<EditingBikeContent> createState() => _EditingBikeContentState();
}

class _EditingBikeContentState extends State<EditingBikeContent> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  DateTime _inUseFrom = DateTime.now();
  File? _imageFile;
  String? _currentImageUrl; // URL текущего изображения из базы
  final _picker = ImagePicker();
  bool _isLoading = false;
  bool _isLoadingData = true; // Загрузка данных для редактирования

  // Для автодополнения
  final ApiService _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadEquipmentData();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  /// Загрузка данных снаряжения для редактирования
  Future<void> _loadEquipmentData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь не авторизован')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = await _api.post(
        '/get_equipment_item.php',
        body: {
          'user_id': userId.toString(),
          'equip_user_id': widget.equipUserId.toString(),
        },
      );

      if (data['success'] == true) {
        setState(() {
          _brandCtrl.text = data['brand'] ?? '';
          _modelCtrl.text = data['name'] ?? '';
          _kmCtrl.text = data['dist']?.toString() ?? '0';
          _currentImageUrl = data['image'] as String?;
          // Загружаем дату из базы
          final inUseSinceStr = data['in_use_since'] as String?;
          if (inUseSinceStr != null && inUseSinceStr.isNotEmpty) {
            try {
              _inUseFrom = DateTime.parse(inUseSinceStr);
            } catch (e) {
              // Если не удалось распарсить, оставляем текущую дату
              _inUseFrom = DateTime.now();
            }
          }
          _isLoadingData = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Ошибка при загрузке данных')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
        Navigator.of(context).pop();
      }
    }
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
        body: {'query': query, 'type': 'bike'},
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
        body: {'brand': brand, 'query': query, 'type': 'bike'},
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
      setState(() {
        _imageFile = File(x.path);
        _currentImageUrl = null;
      });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите бренд')));
      return;
    }

    if (model.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите модель')));
      return;
    }

    // Дистанция необязательна, по умолчанию 0
    int km = 0;
    if (kmStr.isNotEmpty) {
      final parsedKm = int.tryParse(kmStr);
      if (parsedKm == null || parsedKm < 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Некорректная дистанция')));
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
        'equip_user_id': widget.equipUserId.toString(),
        'name': model,
        'brand': brand,
        'dist': km.toString(),
        'in_use_since': _formatDateForApi(_inUseFrom), // Дата в формате DD.MM.YYYY
      };

      // Добавляем изображение, если выбрано новое
      if (_imageFile != null) {
        files['image'] = _imageFile!;
      }

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        data = await api.post('/update_equipment.php', body: fields);
      } else {
        // Multipart запрос с файлами
        data = await api.postMultipart(
          '/update_equipment.php',
          files: files,
          fields: fields,
          timeout: const Duration(seconds: 60),
        );
      }

      // Проверяем ответ
      if (data['success'] == true) {
        if (mounted) {
          // Закрываем экран после успешного сохранения
          Navigator.of(context).pop(true); // Возвращаем true для обновления списка
        }
      } else {
        final errorMsg = data['message'] ?? 'Ошибка при сохранении';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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

  /// Форматирует дату для отправки в API (DD.MM.YYYY)
  String _formatDateForApi(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }

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
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.asset(
                          'assets/add_bike.png',
                          width: 150,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Отображение текущего изображения из базы или выбранного нового
                    if (_currentImageUrl != null && _imageFile == null)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 240,
                              maxHeight: 140,
                            ),
                            child: Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.contain,
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
                      )
                    else if (_imageFile != null)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 240,
                              maxHeight: 140,
                            ),
                            child: Image.file(
                              _imageFile!,
                              fit: BoxFit.contain,
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
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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

        const SizedBox(height: 25),

        // ─────────────── Кнопка «Сохранить» ───────────────
        Center(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _brandCtrl,
            builder: (context, brandValue, child) {
              return PrimaryButton(
                text: 'Сохранить',
                onPressed: _saveEquipment,
                isLoading: _isLoading,
                enabled: brandValue.text.trim().isNotEmpty,
                width: 220,
              );
            },
          ),
        ),
      ],
    );
  }
}

// — служебные виджеты
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
          color: AppColors.textPlaceholder,
        ),
      ),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

