import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';

/// Экран редактирования клуба
class EditClubScreen extends StatefulWidget {
  final int clubId;

  const EditClubScreen({super.key, required this.clubId});

  @override
  State<EditClubScreen> createState() => _EditClubScreenState();
}

class _EditClubScreenState extends State<EditClubScreen> {
  // ── контроллеры
  final nameCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // ── выборы
  String? activity;
  DateTime? foundationDate;
  bool isOpenCommunity = true;

  // ── список городов для автокомплита (загружается из БД)
  List<String> _cities = [];

  // ── медиа
  final picker = ImagePicker();
  File? logoFile;
  String? logoUrl; // URL для отображения существующего логотипа
  String? logoFilename; // Имя файла существующего логотипа
  File? backgroundFile;
  String? backgroundUrl; // URL для отображения существующей фоновой картинки
  String? backgroundFilename; // Имя файла существующей фоновой картинки

  // ── состояние ошибок валидации
  final Set<String> _errorFields = {};

  // ── состояние загрузки
  bool _loading = false;
  bool _loadingData = true;
  bool _deleting = false; // ── состояние удаления

  bool get isFormValid =>
      nameCtrl.text.trim().isNotEmpty &&
      cityCtrl.text.trim().isNotEmpty &&
      activity != null &&
      foundationDate != null;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name');
    });
    cityCtrl.addListener(() {
      _refresh();
      _clearFieldError('city');
    });
    // Загружаем список городов из БД
    _loadCities();
    // Загружаем данные клуба для редактирования
    _loadClubData();
  }

  /// Загрузка списка городов из БД через API
  Future<void> _loadCities() async {
    try {
      final api = ApiService();
      final data = await api.get('/get_cities.php').timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Превышено время ожидания загрузки городов');
        },
      );

      if (data['success'] == true && data['cities'] != null) {
        final cities = data['cities'] as List<dynamic>? ?? [];
        setState(() {
          _cities = cities.map((city) => city.toString()).toList();
        });
      }
    } catch (e) {
      // В случае ошибки оставляем пустой список
      // Пользователь все равно сможет ввести город вручную
      // Ошибка не критична, так как автокомплит работает и без списка
    }
  }

  /// Загрузка данных клуба для редактирования
  Future<void> _loadClubData() async {
    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Ошибка авторизации')));
          Navigator.of(context).pop();
        }
        return;
      }

      final data = await api.get(
        '/get_clubs.php',
        queryParams: {'club_id': widget.clubId.toString()},
      );

      if (data['success'] == true && data['club'] != null) {
        final club = data['club'] as Map<String, dynamic>;

        // Заполняем текстовые поля
        nameCtrl.text = club['name'] as String? ?? '';
        cityCtrl.text = club['city'] as String? ?? '';
        descCtrl.text = club['description'] as String? ?? '';

        // Заполняем выборы
        final activityStr = club['activity'] as String?;
        // Проверяем, что значение активности входит в список допустимых
        const allowedActivities = ['Бег', 'Велосипед', 'Плавание'];
        if (activityStr != null && allowedActivities.contains(activityStr)) {
          activity = activityStr;
        } else {
          activity = null;
        }

        // Заполняем статус открытости
        final isOpen = club['is_open'];
        if (isOpen is bool) {
          isOpenCommunity = isOpen;
        } else if (isOpen is int) {
          isOpenCommunity = isOpen == 1;
        } else if (isOpen is String) {
          isOpenCommunity = isOpen == '1' || isOpen.toLowerCase() == 'true';
        }

        // Заполняем дату основания
        DateTime? parsedDate;
        // ── используем foundation_date (формат "YYYY-MM-DD" из БД), а не date_formatted
        final foundationDateStr = club['foundation_date'] as String? ?? '';
        if (foundationDateStr.isNotEmpty) {
          try {
            // Парсим дату в формате "YYYY-MM-DD" (стандартный формат MySQL DATE)
            parsedDate = DateTime.parse(foundationDateStr);
            // ── обрезаем время, оставляем только дату
            parsedDate = DateUtils.dateOnly(parsedDate);
          } catch (e) {
            // ── если не удалось распарсить, пробуем альтернативный формат "dd.mm.yyyy"
            try {
              final parts = foundationDateStr.split('.');
              if (parts.length == 3) {
                parsedDate = DateTime(
                  int.parse(parts[2]),
                  int.parse(parts[1]),
                  int.parse(parts[0]),
                );
                parsedDate = DateUtils.dateOnly(parsedDate);
              }
            } catch (e2) {
              // Игнорируем ошибку парсинга
            }
          }
        }

        // Заполняем медиа
        final parsedLogoUrl = club['logo_url'] as String?;
        // ── извлекаем имя файла из URL или используем поле logo из БД
        final parsedLogoFilename = club['logo'] as String? ??
            (parsedLogoUrl != null && parsedLogoUrl.isNotEmpty
                ? Uri.parse(parsedLogoUrl).pathSegments.last
                : null);
        final parsedBackgroundUrl = club['background_url'] as String?;
        // ── извлекаем имя файла из URL или используем поле background из БД
        final parsedBackgroundFilename = club['background'] as String? ??
            (parsedBackgroundUrl != null && parsedBackgroundUrl.isNotEmpty
                ? Uri.parse(parsedBackgroundUrl).pathSegments.last
                : null);

        // ── обновляем состояние внутри setState, чтобы виджеты перестроились
        setState(() {
          foundationDate = parsedDate;
          logoUrl = parsedLogoUrl;
          logoFilename = parsedLogoFilename;
          backgroundUrl = parsedBackgroundUrl;
          backgroundFilename = parsedBackgroundFilename;
          _loadingData = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] as String? ??
                    'Не удалось загрузить данные клуба',
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    cityCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── очистка ошибки для конкретного поля при взаимодействии
  void _clearFieldError(String fieldName) {
    if (_errorFields.contains(fieldName)) {
      setState(() => _errorFields.remove(fieldName));
    }
  }

  Future<void> _pickLogo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() {
        logoFile = File(x.path);
        logoUrl = null; // Сбрасываем URL, так как выбран новый файл
      });
    }
  }

  Future<void> _pickBackground() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() {
        backgroundFile = File(x.path);
        backgroundUrl = null; // Сбрасываем URL, так как выбран новый файл
      });
    }
  }

  Future<void> _pickDateCupertino() async {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(foundationDate ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      maximumDate: today, // дата основания не может быть в будущем
      initialDateTime: temp.isAfter(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        foundationDate = temp;
        _clearFieldError('foundationDate');
      });
    }
  }

  Future<T?> _showCupertinoSheet<T>({required Widget child}) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // маленькая серая полоска сверху (grabber)
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 0),

                // ── панель с кнопками
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('Отмена'),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(true),
                        child: const Text('Готово'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // ── сам пикер
                SizedBox(height: 260, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  /// Показываем диалог подтверждения удаления
  Future<bool> _confirmDelete() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удалить сообщество?'),
        content: const Text(
          'Сообщество будет скрыто из приложения. '
          'Вы сможете восстановить его позже.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Удаление клуба
  Future<void> _deleteClub() async {
    // ── показываем диалог подтверждения
    final confirmed = await _confirmDelete();
    if (!confirmed) return;

    // ── защита от повторных нажатий
    if (_deleting) return;
    setState(() => _deleting = true);

    final api = ApiService();
    final authService = AuthService();

    try {
      final userId = await authService.getUserId();
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка авторизации')),
        );
        return;
      }

      // Отправляем запрос на удаление
      final data = await api.post(
        '/delete_club.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
        },
      );

      // Проверяем ответ
      bool success = false;
      String? errorMessage;

      if (data['success'] == true) {
        success = true;
      } else if (data['success'] == false) {
        errorMessage = data['message'] ?? 'Ошибка при удалении клуба';
      } else {
        errorMessage = 'Неожиданный формат ответа сервера';
      }

      if (success) {
        if (!mounted) return;

        // Возвращаемся на предыдущий экран с результатом удаления
        Navigator.of(context).pop('deleted');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Ошибка при удалении клуба'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сети: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _submit() async {
    // ── проверяем все обязательные поля и подсвечиваем незаполненные
    final Set<String> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors.add('name');
    }
    if (cityCtrl.text.trim().isEmpty) {
      newErrors.add('city');
    }
    if (activity == null) {
      newErrors.add('activity');
    }
    if (foundationDate == null) {
      newErrors.add('foundationDate');
    }

    setState(() {
      _errorFields.clear();
      _errorFields.addAll(newErrors);
    });

    // ── если есть ошибки — не отправляем форму
    if (newErrors.isNotEmpty) {
      return;
    }

    // ── форма валидна — отправляем на сервер
    setState(() => _loading = true);

    final api = ApiService();
    final authService = AuthService();

    try {
      // Формируем данные
      final files = <String, File>{};
      final fields = <String, String>{};

      // Добавляем логотип (если выбран новый)
      if (logoFile != null) {
        files['logo'] = logoFile!;
      }

      // Добавляем фоновую картинку (если выбрана новая)
      if (backgroundFile != null) {
        files['background'] = backgroundFile!;
      }

      // Добавляем поля формы
      final userId = await authService.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка авторизации. Необходимо войти в систему'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      fields['club_id'] = widget.clubId.toString();
      fields['user_id'] = userId.toString();
      fields['name'] = nameCtrl.text.trim();
      fields['city'] = cityCtrl.text.trim();
      fields['description'] = descCtrl.text.trim();
      fields['activity'] = activity!;
      fields['is_open'] = isOpenCommunity ? '1' : '0';
      fields['foundation_date'] = _fmtDate(foundationDate!);
      // Координаты не обязательны - будут получены по городу на сервере

      // Флаги для сохранения существующих изображений
      if (logoUrl != null && logoFile == null && logoFilename != null) {
        fields['keep_logo'] = 'true';
      }
      if (backgroundUrl != null &&
          backgroundFile == null &&
          backgroundFilename != null) {
        fields['keep_background'] = 'true';
      }

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        data = await api.post('/edit_club.php', body: fields);
      } else {
        // Multipart запрос с файлами
        data = await api.postMultipart(
          '/edit_club.php',
          files: files,
          fields: fields,
          timeout: const Duration(seconds: 60),
        );
      }

      // Проверяем ответ
      bool success = false;
      String? errorMessage;

      if (data['success'] == true) {
        success = true;
      } else if (data['success'] == false) {
        errorMessage = data['message'] ?? 'Ошибка при обновлении клуба';
      } else {
        errorMessage = 'Неожиданный формат ответа сервера';
      }

      if (success) {
        if (!mounted) return;

        // Возвращаемся на экран детализации с обновленными данными
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Ошибка при обновлении клуба'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сети: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Редактирование клуба'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Редактирование клуба'),
        body: GestureDetector(
          // ── скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Медиа: логотип + фоновая картинка ----------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Логотип клуба',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MediaTile(
                            file: logoFile,
                            url: logoUrl,
                            onPick: _pickLogo,
                            onRemove: () => setState(() {
                              logoFile = null;
                              logoUrl = null;
                              logoFilename = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Фоновая картинка',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: _MediaTile(
                                file: backgroundFile,
                                url: backgroundUrl,
                                onPick: _pickBackground,
                                onRemove: () => setState(() {
                                  backgroundFile = null;
                                  backgroundUrl = null;
                                  backgroundFilename = null;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Название клуба ----------
                  const Text(
                    'Название клуба',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    style: AppTextStyles.h14w4,
                    decoration: InputDecoration(
                      hintText: 'Введите название клуба',
                      hintStyle: AppTextStyles.h14w4Place,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 17,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: _errorFields.contains('name')
                              ? AppColors.error
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: _errorFields.contains('name')
                              ? AppColors.error
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: _errorFields.contains('name')
                              ? AppColors.error
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Вид активности ----------
                  const Text(
                    'Вид активности',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: _errorFields.contains('activity')
                              ? AppColors.error
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: _errorFields.contains('activity')
                              ? AppColors.error
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: _errorFields.contains('activity')
                              ? AppColors.error
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activity,
                        isExpanded: true,
                        hint: const Text(
                          'Выберите вид активности',
                          style: AppTextStyles.h14w4Place,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              activity = newValue;
                              _clearFieldError('activity');
                            });
                          }
                        },
                        dropdownColor: AppColors.surface,
                        menuMaxHeight: 300,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.iconSecondary,
                        ),
                        style: AppTextStyles.h14w4,
                        items: const ['Бег', 'Велосипед', 'Плавание'].map((
                          option,
                        ) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option, style: AppTextStyles.h14w4),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Радиокнопки: Открытое/Закрытое сообщество ----------
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<bool>(
                          value: true,
                          groupValue: isOpenCommunity,
                          onChanged: (v) =>
                              setState(() => isOpenCommunity = v ?? false),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Открытое сообщество'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<bool>(
                          value: false,
                          groupValue: isOpenCommunity,
                          onChanged: (v) =>
                              setState(() => isOpenCommunity = v ?? false),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Закрытое сообщество'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Город ----------
                  const Text(
                    'Город',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _CityAutocompleteField(
                    controller: cityCtrl,
                    suggestions: _cities,
                    hasError: _errorFields.contains('city'),
                    onSelected: (city) {
                      cityCtrl.text = city;
                      _clearFieldError('city');
                    },
                  ),
                  const SizedBox(height: 24),

                  // ---------- Дата основания клуба ----------
                  const Text(
                    'Дата основания клуба',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDateCupertino,
                    child: AbsorbPointer(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 18,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(
                              left: 12,
                              right: 6,
                            ),
                            child: Icon(
                              CupertinoIcons.calendar,
                              size: 18,
                              color: AppColors.iconPrimary,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 18 + 14,
                            minHeight: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(
                              color: _errorFields.contains('foundationDate')
                                  ? AppColors.error
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(
                              color: _errorFields.contains('foundationDate')
                                  ? AppColors.error
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(
                              color: _errorFields.contains('foundationDate')
                                  ? AppColors.error
                                  : AppColors.border,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          foundationDate != null
                              ? _fmtDate(foundationDate!)
                              : 'Выберите дату',
                          style: foundationDate != null
                              ? AppTextStyles.h14w4
                              : AppTextStyles.h14w4Place,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Описание ----------
                  const Text(
                    'Описание',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 12,
                    minLines: 7,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTextStyles.h14w4,
                    decoration: InputDecoration(
                      hintText: 'Введите описание клуба',
                      hintStyle: AppTextStyles.h14w4Place,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Кнопки: Сохранить и Удалить сообщество
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: PrimaryButton(
                          text: 'Сохранить',
                          onPressed: () {
                            if (!_loading && !_deleting) _submit();
                          },
                          expanded: true,
                          isLoading: _loading,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _deleting || _loading
                            ? null
                            : _deleteClub,
                        child: const Text(
                          'Удалить сообщество',
                          style: TextStyle(
                            color: AppColors.error,
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ---------------------------
//

// ── автокомплит для города
class _CityAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSelected;
  final bool hasError;

  const _CityAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? AppColors.error : AppColors.border;

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return suggestions.where((city) {
          return city.toLowerCase().startsWith(query);
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Инициализируем текст из внешнего контроллера
            if (textEditingController.text.isEmpty &&
                controller.text.isNotEmpty) {
              textEditingController.text = controller.text;
            }

            // Синхронизируем изменения в Autocomplete контроллере с внешним
            textEditingController.addListener(() {
              if (textEditingController.text != controller.text) {
                controller.text = textEditingController.text;
              }
            });

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (String value) {
                onFieldSubmitted();
              },
              style: AppTextStyles.h14w4,
              decoration: InputDecoration(
                hintText: 'Введите город',
                hintStyle: AppTextStyles.h14w4Place,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor, width: 1),
                ),
              ),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Text(
                            option,
                            style: AppTextStyles.h14w4,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}

//
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ МЕДИА-ТАЙЛЫ ---------------------------
//

class _MediaTile extends StatelessWidget {
  final File? file;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MediaTile({
    required this.file,
    this.url,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // ── если есть новый файл — показываем его
    if (file != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.file(
                file!,
                fit: BoxFit.cover,
                width: 90,
                height: 90,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 90,
                  height: 90,
                  color: AppColors.background,
                  child: const Icon(
                    CupertinoIcons.photo,
                    size: 24,
                    color: AppColors.iconSecondary,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: onRemove,
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

    // ── если есть URL существующего изображения — показываем его
    if (url != null && url!.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final side = (90 * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: url!,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 120),
                    memCacheWidth: side,
                    maxWidthDiskCache: side,
                    errorWidget: (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      color: AppColors.background,
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 24,
                        color: AppColors.iconSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: onRemove,
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

    // ── если фото ещё нет — плитка с иконкой и рамкой
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: 90,
        height: 90,
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
}

