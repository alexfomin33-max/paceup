// lib/screens/market/state/edit_slot/edit_slot_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../models/market_models.dart' show Gender;
import '../../../providers/slots_provider.dart';

/// Экран редактирования слота
class EditSlotScreen extends ConsumerStatefulWidget {
  final int slotId;

  const EditSlotScreen({super.key, required this.slotId});

  @override
  ConsumerState<EditSlotScreen> createState() => _EditSlotScreenState();
}

class _EditSlotScreenState extends ConsumerState<EditSlotScreen> {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final _nameFocusNode = FocusNode();

  Gender _gender = Gender.male;
  int _distanceIndex = 0;
  List<String> _distances = []; // Динамический список дистанций
  String? _currentDistance; // Текущая дистанция слота (если событие не выбрано)

  // ─── Состояние выбранного события ───
  int? _selectedEventId;
  bool _isLoadingDistances = false;

  // ─── Состояние загрузки и ошибок ───
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  String? _errorMessage;

  bool get _isValid =>
      nameCtrl.text.trim().isNotEmpty && priceCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadSlotData();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// Загрузка данных слота из API
  Future<void> _loadSlotData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }

      final api = ApiService();
      final response = await api.get(
        '/get_slot.php',
        queryParams: {
          'slot_id': widget.slotId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Ошибка загрузки данных слота');
      }

      final slot = response['slot'] as Map<String, dynamic>;

      // Заполняем форму данными слота
      final eventId = slot['event_id'];
      final eventName = slot['event_name'];
      final eventPlace = slot['event_place'] ?? '';
      final eventDate = slot['event_date'] ?? '';

      // Устанавливаем базовые данные формы
      setState(() {
        // ── форматируем цену с пробелами
        final price = (slot['price'] ?? 0) as int;
        priceCtrl.text = _formatPrice(price);
        descCtrl.text = slot['description'] ?? '';
        _gender = (slot['gender'] ?? 'male') == 'female'
            ? Gender.female
            : Gender.male;
      });

      // Если есть event_id и event_name, "выбираем" событие
      // Это нужно, чтобы все параметры были установлены правильно
      if (eventId != null &&
          eventName != null &&
          eventName.toString().isNotEmpty &&
          eventId is int) {
        final eventOption = _EventOption(
          id: eventId,
          name: eventName as String,
          place: eventPlace as String,
          eventDate: eventDate as String,
        );

        // Устанавливаем название события в контроллер напрямую
        nameCtrl.text = eventOption.name;

        setState(() {
          _selectedEventId = eventOption.id;
          _isLoading = false;
        });

        // Загружаем дистанции для выбранного события
        await _loadEventDistances(eventOption.id);

        // Находим индекс текущей дистанции
        final currentDistance = slot['distance'] ?? '';
        final index = _distances.indexWhere((d) => d == currentDistance);
        if (index >= 0) {
          setState(() {
            _distanceIndex = index;
          });
        }
      } else {
        // Если события нет, просто устанавливаем название слота
        nameCtrl.text = slot['title'] ?? '';
        final currentDistance = slot['distance'] ?? '';
        setState(() {
          _selectedEventId = null;
          _currentDistance = currentDistance.isNotEmpty
              ? currentDistance
              : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError(e);
      if (mounted) {
        setState(() {
          _errorMessage = ErrorHandler.format(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Загрузка дистанций события
  Future<void> _loadEventDistances(int eventId) async {
    setState(() {
      _isLoadingDistances = true;
    });

    try {
      final api = ApiService();
      final response = await api.post(
        '/get_event_distances.php',
        body: {'event_id': eventId},
      );

      if (response['success'] == true && mounted) {
        final List<dynamic> distancesData = response['distances'] ?? [];
        final distances = distancesData
            .map((d) => d['formatted'] as String)
            .toList();

        setState(() {
          _distances = distances;
          _isLoadingDistances = false;
        });
      } else {
        setState(() {
          _isLoadingDistances = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError(e);
      if (mounted) {
        setState(() {
          _isLoadingDistances = false;
        });
      }
    }
  }

  /// Поиск событий для автозаполнения
  Future<Iterable<_EventOption>> _searchEvents(String query) async {
    if (query.length < 2) {
      return const [];
    }

    try {
      final api = ApiService();
      final response = await api.post(
        '/search_events.php',
        body: {'query': query},
      );

      if (response['success'] == true) {
        final List<dynamic> eventsData = response['events'] ?? [];
        return eventsData.map((e) {
          return _EventOption(
            id: e['id'] as int,
            name: e['name'] as String,
            place: e['place'] as String? ?? '',
            eventDate: e['event_date'] as String? ?? '',
          );
        });
      }
    } catch (e) {
      ErrorHandler.logError(e);
    }

    return const [];
  }

  /// Сохранение изменений слота
  Future<void> _save() async {
    if (!_isValid || _isSubmitting) return;

    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }

      // ─── Парсим цену ───
      final priceText = priceCtrl.text.replaceAll(' ', '');
      final price = int.tryParse(priceText);
      if (price == null || price <= 0) {
        throw Exception('Некорректная цена. Введите число больше нуля');
      }

      // ─── Определяем дистанцию ───
      String distance = '';
      if (_selectedEventId != null) {
        // Если событие выбрано, проверяем, что дистанция выбрана из списка
        if (_distances.isEmpty || _distanceIndex >= _distances.length) {
          throw Exception('Выберите дистанцию');
        }
        distance = _distances[_distanceIndex];
      } else {
        // Если событие не выбрано, используем текущую дистанцию слота
        // или название слота, если дистанция не была сохранена
        distance = _currentDistance ?? nameCtrl.text.trim();
        if (distance.isEmpty) {
          throw Exception('Укажите дистанцию');
        }
      }

      // ─── Преобразуем Gender в строку для API ───
      final genderString = _gender == Gender.male ? 'male' : 'female';

      // ─── Отправляем данные на сервер ───
      // ВАЖНО: Всегда передаём event_id (даже если null), чтобы бэкенд правильно обновил текущий слот
      // и не создавал новую запись и не удалял текущую
      final api = ApiService();
      final response = await api.post(
        '/update_slot.php',
        body: {
          'slot_id': widget.slotId,
          'user_id': userId,
          'event_id':
              _selectedEventId, // Передаём null, если событие не выбрано
          'title': nameCtrl.text.trim(),
          'distance': distance,
          'price': price,
          'gender': genderString,
          'description': descCtrl.text.trim(),
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          // ─── Обновляем список слотов ───
          final slotsNotifier = ref.read(slotsProvider.notifier);
          await slotsNotifier.loadInitial();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Слот успешно обновлён')),
            );
            Navigator.pop(context);
          }
        }
      } else {
        final errorMsg =
            response['message']?.toString() ??
            'Не удалось обновить слот. Попробуйте ещё раз';
        setState(() {
          _errorMessage = errorMsg;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError(e);
      final errorMsg = ErrorHandler.format(e);
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _isSubmitting = false;
        });
      }
    }
  }

  /// Удаление слота
  Future<void> _handleDelete() async {
    if (_isDeleting || _isSubmitting) return;

    // ─── Подтверждение удаления ───
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удаление слота'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Вы уверены, что хотите удалить этот слот? Это действие нельзя отменить.',
            style: TextStyle(fontSize: 15),
          ),
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

    if (confirmed != true) return;

    setState(() {
      _errorMessage = null;
      _isDeleting = true;
    });

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }

      final api = ApiService();
      final response = await api.post(
        '/delete_slot.php',
        body: {'slot_id': widget.slotId, 'user_id': userId},
      );

      if (response['success'] == true) {
        if (mounted) {
          // ─── Обновляем список слотов ───
          final slotsNotifier = ref.read(slotsProvider.notifier);
          await slotsNotifier.loadInitial();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Слот успешно удалён')),
            );
            Navigator.pop(context);
          }
        }
      } else {
        final errorMsg =
            response['message']?.toString() ??
            'Не удалось удалить слот. Попробуйте ещё раз';
        setState(() {
          _errorMessage = errorMsg;
          _isDeleting = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError(e);
      final errorMsg = ErrorHandler.format(e);
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: PaceAppBar(
            title: 'Редактирование слота',
            showBack: true,
            showBottomDivider: true,
            actions: [
              IconButton(
                splashRadius: 22,
                icon: const Icon(
                  CupertinoIcons.delete,
                  size: 20,
                  color: AppColors.error,
                ),
                onPressed: _handleDelete,
              ),
            ],
          ),
          body: const Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    // 🔻 умный нижний паддинг: клавиатура (viewInsets) > 0 ? берём её : берём safe-area
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom; // клавиатура
    final safeBottom = media.viewPadding.bottom; // «борода»/ноутч
    final bottomPad = (bottomInset > 0 ? bottomInset : safeBottom) + 20;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Редактирование слота',
          showBack: true,
          showBottomDivider: true,
          actions: [
            IconButton(
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.delete,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: _handleDelete,
            ),
          ],
        ),
        body: GestureDetector(
          // ── снимаем фокус с текстовых полей при клике вне их
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12, 20, 12, bottomPad),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventAutocompleteField(
                  label: 'Название события',
                  hint: 'Начните вводить название события',
                  controller: nameCtrl,
                  focusNode: _nameFocusNode,
                  onEventSelected: (event) {
                    setState(() {
                      _selectedEventId = event.id;
                      nameCtrl.text = event.name;
                    });
                    _loadEventDistances(event.id);
                  },
                  searchFunction: _searchEvents,
                ),
                const SizedBox(height: 20),

                const _SmallLabel('Пол'),
                const SizedBox(height: 8),
                _GenderRow(
                  maleSelected: _gender == Gender.male,
                  femaleSelected: _gender == Gender.female,
                  onMaleTap: () => setState(() => _gender = Gender.male),
                  onFemaleTap: () => setState(() => _gender = Gender.female),
                ),
                const SizedBox(height: 20),

                // ─── Показываем список дистанций только если выбрано событие ───
                if (_selectedEventId != null) ...[
                  const _SmallLabel('Дистанция'),
                  const SizedBox(height: 8),
                  if (_isLoadingDistances)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CupertinoActivityIndicator(),
                      ),
                    )
                  else if (_distances.isEmpty)
                    Text(
                      'У этого события нет доступных дистанций',
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    )
                  else
                    _ChipsRow(
                      items: _distances,
                      selectedIndex: _distanceIndex,
                      onSelected: (i) => setState(() => _distanceIndex = i),
                    ),
                  const SizedBox(height: 20),
                ],

                _PriceField(
                  controller: priceCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                _LabeledTextField(
                  label: 'Описание',
                  hint:
                      'Опишите варианты передачи слота, кластер и другую информацию',
                  controller: descCtrl,
                  maxLines: 5,
                ),
                const SizedBox(height: 24),

                // ─── Отображение ошибки ───
                if (_errorMessage != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SelectableText.rich(
                      TextSpan(
                        text: _errorMessage,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // ────────────────────────────────────────────────────────────────
                // 💾 КНОПКА СОХРАНЕНИЯ
                // ────────────────────────────────────────────────────────────────
                Center(
                  child: PrimaryButton(
                    text: 'Сохранить изменения',
                    onPressed: _isSubmitting || _isDeleting
                        ? () {}
                        : () => _save(),
                    width: 230,
                    isLoading: _isSubmitting,
                    enabled: _isValid && !_isSubmitting && !_isDeleting,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Локальные UI-компоненты (скопированы из sale_slots_content.dart) ───

// Модель события для автопоиска
class _EventOption {
  final int id;
  final String name;
  final String place;
  final String eventDate;

  const _EventOption({
    required this.id,
    required this.name,
    required this.place,
    required this.eventDate,
  });
}

/// Поле автозаполнения для поиска событий
class _EventAutocompleteField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<_EventOption> onEventSelected;
  final Future<Iterable<_EventOption>> Function(String) searchFunction;

  const _EventAutocompleteField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.onEventSelected,
    required this.searchFunction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 8),
        Autocomplete<_EventOption>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.length < 2) {
              return const Iterable<_EventOption>.empty();
            }
            return await searchFunction(textEditingValue.text);
          },
          onSelected: onEventSelected,
          displayStringForOption: (option) => option.name,
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onFieldSubmitted: (String value) {
                    onFieldSubmitted();
                  },
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTextStyles.h14w4Place.copyWith(
                      color: AppColors.getTextPlaceholderColor(context),
                    ),
                    filled: true,
                    fillColor: AppColors.getSurfaceColor(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: AppColors.getBorderColor(context),
                        width: 1,
                      ),
                    ),
                  ),
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<_EventOption> onSelected,
                Iterable<_EventOption> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceColor(context),
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.getBorderColor(context),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.name,
                                    style: AppTextStyles.h14w5.copyWith(
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                  if (option.place.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      option.place,
                                      style: AppTextStyles.h14w4.copyWith(
                                        color: AppColors.getTextSecondaryColor(
                                          context,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        ),
      ],
    );
  }
}

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.h14w4Place.copyWith(
              color: AppColors.getTextPlaceholderColor(context),
            ),
            filled: true,
            fillColor: AppColors.getSurfaceColor(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 17,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(
                color: AppColors.getBorderColor(context),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Форматирует цену с пробелами каждые 3 цифры
String _formatPrice(int price) {
  final s = price.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final pos = s.length - i;
    buffer.write(s[i]);
    if (pos > 1 && pos % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
}

/// Форматтер для форматирования цены с пробелами каждые 3 цифры
class _PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // ── удаляем все нецифровые символы
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // ── форматируем число с пробелами каждые 3 цифры
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      final pos = digitsOnly.length - i;
      buffer.write(digitsOnly[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write(' ');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _PriceField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel('Цена'),
        const SizedBox(height: 8),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 24 - 12) / 2,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [_PriceInputFormatter()],
            onChanged: onChanged,
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppTextStyles.h14w4Place.copyWith(
                color: AppColors.getTextPlaceholderColor(context),
              ),
              suffixText: '₽',
              suffixStyle: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
              filled: true,
              fillColor: AppColors.getSurfaceColor(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 17,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(
                  color: AppColors.getBorderColor(context),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(
                  color: AppColors.getBorderColor(context),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(
                  color: AppColors.getBorderColor(context),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderRow extends StatelessWidget {
  final bool maleSelected;
  final bool femaleSelected;
  final VoidCallback onMaleTap;
  final VoidCallback onFemaleTap;

  const _GenderRow({
    required this.maleSelected,
    required this.femaleSelected,
    required this.onMaleTap,
    required this.onFemaleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OvalToggle(label: 'Мужской', selected: maleSelected, onTap: onMaleTap),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Женский',
          selected: femaleSelected,
          onTap: onFemaleTap,
        ),
      ],
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _ChipsRow({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(items.length, (i) {
        final sel = selectedIndex == i;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.brandPrimary
                  : AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: sel
                    ? AppColors.brandPrimary
                    : AppColors.getBorderColor(context),
              ),
            ),
            child: Text(
              items[i],
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: sel
                    ? (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surface
                          : AppColors.getSurfaceColor(context))
                    : AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OvalToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OvalToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    final fg = selected
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.surface
              : AppColors.getSurfaceColor(context))
        : AppColors.getTextPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected
                ? AppColors.brandPrimary
                : AppColors.getBorderColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}
