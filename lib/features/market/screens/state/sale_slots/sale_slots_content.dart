import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../models/market_models.dart' show Gender;
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../providers/slots_provider.dart';

/// Контент вкладки «Продажа слота»
class SaleSlotsContent extends ConsumerStatefulWidget {
  const SaleSlotsContent({super.key});

  @override
  ConsumerState<SaleSlotsContent> createState() => _SaleSlotsContentState();
}

// ─── Модель события для автопоиска ───
class _EventOption {
  final int id;
  final String name;
  final String place;
  final String eventDate;
  final String? logoUrl;

  const _EventOption({
    required this.id,
    required this.name,
    required this.place,
    required this.eventDate,
    this.logoUrl,
  });
}

class _SaleSlotsContentState extends ConsumerState<SaleSlotsContent> {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  Gender _gender = Gender.male;
  int _distanceIndex = 0;
  List<String> _distances = []; // Динамический список дистанций

  // ─── Состояние выбранного события ───
  int? _selectedEventId;
  String? _selectedEventLogoUrl;
  bool _isEventSelectedFromDropdown =
      false; // Флаг: событие выбрано из выпадающего списка
  bool _isSettingEventFromDropdown =
      false; // Флаг: сейчас устанавливаем событие программно
  bool _isLoadingDistances = false;

  // ─── Состояние загрузки и ошибок ───
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isValid =>
      nameCtrl.text.trim().isNotEmpty && priceCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // ─── Сбрасываем флаг выбора из списка, если пользователь редактирует текст вручную ───
    nameCtrl.addListener(() {
      // Если сейчас устанавливаем событие программно - игнорируем
      if (_isSettingEventFromDropdown) return;

      // Если флаг установлен, но текст изменился - значит пользователь редактирует вручную
      if (_isEventSelectedFromDropdown && mounted) {
        setState(() {
          _isEventSelectedFromDropdown = false;
          _selectedEventId = null;
          _selectedEventLogoUrl = null;
          _distances = [];
          _distanceIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  /// Загрузка дистанций события
  Future<void> _loadEventDistances(int eventId) async {
    setState(() {
      _isLoadingDistances = true;
      _distances = [];
      _distanceIndex = 0;
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
          _distanceIndex = 0;
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

        // ─── Логирование для отладки ───
        if (kDebugMode) {
          debugPrint(
            '🔍 Поиск событий: запрос="$query", найдено в ответе: ${eventsData.length}',
          );

          if (eventsData.isNotEmpty) {
            debugPrint('📋 Первые 3 события:');
            for (int i = 0; i < eventsData.length && i < 3; i++) {
              debugPrint(
                '  ${i + 1}. ID=${eventsData[i]['id']}, название="${eventsData[i]['name']}"',
              );
            }
          }
        }

        // ─── Явно преобразуем в List для корректной работы Autocomplete ───
        final result = eventsData.map(
          (e) {
            return _EventOption(
              id: e['id'] as int,
              name: e['name'] as String,
              place: e['place'] as String? ?? '',
              eventDate: e['event_date'] as String? ?? '',
              logoUrl: (e['logo_url'] ?? e['logo'] ?? '') as String?,
            );
          },
        ).toList(); // ─── Преобразуем ленивый Iterable в материализованный List

        if (kDebugMode) {
          debugPrint('✅ Обработано событий в список: ${result.length}');
        }

        return result;
      }
    } catch (e) {
      ErrorHandler.logError(e);
      if (kDebugMode) {
        debugPrint('❌ Ошибка при поиске событий: $e');
      }
    }

    return const [];
  }

  /// Отправка формы создания слота на сервер
  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;

    // ─── Проверяем, что если введено название события, то оно выбрано из выпадающего списка ───
    final eventNameText = nameCtrl.text.trim();
    if (eventNameText.isNotEmpty && !_isEventSelectedFromDropdown) {
      setState(() {
        _errorMessage =
            'Пожалуйста, выберите событие из списка предложенных вариантов';
        _isSubmitting = false;
      });
      return;
    }

    // ─── Сброс предыдущей ошибки ───
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    try {
      // ─── Получаем user_id из AuthService ───
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

      // ─── Проверяем, что дистанция выбрана (только если событие выбрано) ───
      String? distance;
      if (_selectedEventId != null) {
        if (_distances.isEmpty || _distanceIndex >= _distances.length) {
          throw Exception('Выберите дистанцию');
        }
        // ─── Получаем выбранную дистанцию ───
        distance = _distances[_distanceIndex];
      }

      // ─── Преобразуем Gender в строку для API ───
      final genderString = _gender == Gender.male ? 'male' : 'female';

      // ─── Отправляем данные на сервер ───
      final api = ApiService();
      final response = await api.post(
        '/create_slot.php',
        body: {
          'user_id': userId,
          if (_selectedEventId != null) 'event_id': _selectedEventId,
          'title': nameCtrl.text.trim(),
          if (distance != null) 'distance': distance,
          'price': price,
          'gender': genderString,
          'description': descCtrl.text.trim(),
        },
      );

      // ─── Проверяем успешность ответа ───
      if (response['success'] == true) {
        // ─── Успешно создан слот ───
        if (mounted) {
          // ─── Обновляем список слотов без перезагрузки экрана ───
          final slotsNotifier = ref.read(slotsProvider.notifier);
          await slotsNotifier.loadInitial();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Объявление о продаже слота успешно размещено'),
              ),
            );
            Navigator.pop(context);
          }
        }
      } else {
        // ─── Ошибка от сервера ───
        final errorMsg =
            response['message']?.toString() ??
            'Не удалось создать слот. Попробуйте ещё раз';
        setState(() {
          _errorMessage = errorMsg;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      // ─── Обработка ошибок ───
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

  @override
  Widget build(BuildContext context) {
    // ── снимаем фокус с текстовых полей при клике вне их
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventAutocompleteField(
              label: 'Название события',
              hint: 'Начните вводить название события',
              controller: nameCtrl,
              selectedLogoUrl: _selectedEventLogoUrl,
              onEventSelected: (event) {
                // Устанавливаем флаг, чтобы слушатель не сработал
                _isSettingEventFromDropdown = true;
                setState(() {
                  _selectedEventId = event.id;
                  _isEventSelectedFromDropdown =
                      true; // Устанавливаем флаг, что выбрано из списка
                  _selectedEventLogoUrl = event.logoUrl;
                  // Устанавливаем текст события
                  if (nameCtrl.text != event.name) {
                    nameCtrl.text = event.name;
                  }
                });
                // Сбрасываем флаг после небольшой задержки
                Future.microtask(() {
                  _isSettingEventFromDropdown = false;
                });
                _loadEventDistances(event.id);
              },
              searchFunction: _searchEvents,
              onClear: () {
                setState(() {
                  _isEventSelectedFromDropdown = false;
                  _selectedEventId = null;
                  _distances = [];
                  _distanceIndex = 0;
                  _isLoadingDistances = false;
                  _selectedEventLogoUrl = null;
                });
              },
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
              minLines: 7, // ── минимальная высота поля 7 строк
              maxLines: 12,
            ),
            const SizedBox(height: 24),

            // ─── Отображение ошибки ───
            if (_errorMessage != null) ...[
              SelectableText.rich(
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
              const SizedBox(height: 16),
            ],

            Center(
              child: PrimaryButton(
                text: 'Разместить продажу',
                onPressed: _isSubmitting ? () {} : () => _submit(),
                width: 220,
                isLoading: _isSubmitting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ——— Локальные UI-компоненты ———

/// Поле автозаполнения для поиска событий
class _EventAutocompleteField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? selectedLogoUrl;
  final ValueChanged<_EventOption> onEventSelected;
  final Future<Iterable<_EventOption>> Function(String) searchFunction;
  final VoidCallback onClear;

  const _EventAutocompleteField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.selectedLogoUrl,
    required this.onEventSelected,
    required this.searchFunction,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 8),
        Autocomplete<_EventOption>(
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
                // Синхронизируем контроллер Autocomplete с внешним контроллером
                if (textEditingController.text != controller.text) {
                  textEditingController.value = controller.value;
                }

                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: textEditingController,
                  builder: (context, value, _) {
                    final hasText = value.text.isNotEmpty;
                    final hasLogo =
                        selectedLogoUrl != null && selectedLogoUrl!.isNotEmpty;
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      onFieldSubmitted: (String _) {
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
                        // Показываем мини-лого выбранного события в поле
                        prefixIcon: hasLogo
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  left: 6,
                                  right: 6,
                                  top: 6,
                                  bottom: 6,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: selectedLogoUrl!,
                                    width: 30,
                                    height: 30,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 30,
                                      height: 30,
                                      color: AppColors.getBackgroundColor(
                                        context,
                                      ),
                                      child: Center(
                                        child: CupertinoActivityIndicator(
                                          radius: 8,
                                          color: AppColors.getIconSecondaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      CupertinoIcons.calendar,
                                      size: 18,
                                      color: AppColors.getIconSecondaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 17,
                        ),
                        suffixIcon: hasText
                            ? IconButton(
                                icon: Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  size: 18,
                                  color: AppColors.getIconSecondaryColor(
                                    context,
                                  ),
                                ),
                                onPressed: () {
                                  textEditingController.clear();
                                  controller.clear();
                                  onClear();
                                  focusNode.requestFocus();
                                },
                              )
                            : null,
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
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<_EventOption> onSelected,
                Iterable<_EventOption> options,
              ) {
                // ─── Преобразуем Iterable в List для использования в ListView ───
                final optionsList = options.toList();

                // ─── Логирование для отладки отображения ───
                if (kDebugMode) {
                  debugPrint(
                    '🎨 optionsViewBuilder: получено ${optionsList.length} опций',
                  );
                }

                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: optionsList.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = optionsList[index];
                          final hasLogo =
                              option.logoUrl != null &&
                              option.logoUrl!.isNotEmpty;
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 16,
                                top: 10,
                                bottom: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xs,
                                      ),
                                      color: AppColors.getBackgroundColor(
                                        context,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: hasLogo
                                        ? CachedNetworkImage(
                                            imageUrl: option.logoUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              width: 40,
                                              height: 40,
                                              color: AppColors.getBackgroundColor(
                                                context,
                                              ),
                                              child: Center(
                                                child:
                                                    CupertinoActivityIndicator(
                                                  radius: 8,
                                                  color: AppColors
                                                      .getIconSecondaryColor(
                                                    context,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, url, error) => Icon(
                                              CupertinoIcons.calendar,
                                              size: 18,
                                              color: AppColors
                                                  .getIconSecondaryColor(
                                                context,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            CupertinoIcons.calendar,
                                            size: 18,
                                            color:
                                                AppColors.getIconSecondaryColor(
                                                  context,
                                                ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.name,
                                          style: AppTextStyles.h14w5.copyWith(
                                            color:
                                                AppColors.getTextPrimaryColor(
                                                  context,
                                                ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (option.place.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            option.place,
                                            style: AppTextStyles.h12w4.copyWith(
                                              color:
                                                  AppColors.getTextSecondaryColor(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
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
  final int minLines;
  final int maxLines;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.minLines = 1,
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
          minLines: minLines,
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
    // Используем ту же логику, что и в alert_creation_screen.dart
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
