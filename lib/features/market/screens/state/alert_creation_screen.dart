// lib/screens/market/state/alert_creation_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Создание оповещения» для уведомлений о новых слотах
// Форма создания в стиле sale_slots_content.dart
// Карточки текущих оповещений в стиле market_slot_card.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/market_models.dart' show Gender;
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../widgets/pills.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../map/screens/events/event_detail_screen2.dart';

/// Модель оповещения о слоте
class AlertItem {
  final int? eventId;
  final String id;
  final String eventName;
  final Gender gender;
  final String distance;
  final String imageUrl;

  const AlertItem({
    required this.eventId,
    required this.id,
    required this.eventName,
    required this.gender,
    required this.distance,
    required this.imageUrl,
  });
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

/// Экран создания оповещений
class AlertCreationScreen extends ConsumerStatefulWidget {
  const AlertCreationScreen({super.key});

  @override
  ConsumerState<AlertCreationScreen> createState() =>
      _AlertCreationScreenState();
}

class _AlertCreationScreenState extends ConsumerState<AlertCreationScreen> {
  final nameCtrl = TextEditingController();

  Gender _gender = Gender.male;
  int _distanceIndex = 0;
  List<String> _distances = []; // Динамический список дистанций

  // ─── Состояние выбранного события ───
  int? _selectedEventId;
  String? _selectedEventLogoUrl;
  bool _isEventSelectedFromDropdown = false; // Флаг: событие выбрано из выпадающего списка
  bool _isSettingEventFromDropdown = false; // Флаг: сейчас устанавливаем событие программно
  bool _isLoadingDistances = false;

  // ─── Состояние загрузки и ошибок ───
  bool _isSubmitting = false;
  bool _isLoadingAlerts = false;
  String? _errorMessage;

  // Данные текущих оповещений из API
  List<AlertItem> _alerts = [];

  bool get _isValid {
    if (nameCtrl.text.trim().isEmpty) return false;
    if (!_isEventSelectedFromDropdown) return false;
    // Если событие выбрано, но дистанции еще не загружены или не выбраны
    if (_selectedEventId != null) {
      if (_isLoadingDistances) return false;
      if (_distances.isEmpty) return false;
      if (_distanceIndex >= _distances.length) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    
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
    super.dispose();
  }

  /// Загрузка оповещений из API
  Future<void> _loadAlerts() async {
    setState(() {
      _isLoadingAlerts = true;
    });

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }

      final api = ApiService();
      final response = await api.post(
        '/get_alerts.php',
        body: {'user_id': userId},
      );

      if (response['success'] == true && mounted) {
        final List<dynamic> alertsData = response['alerts'] ?? [];
        final alerts = alertsData.map((a) {
          final eventId = a['event_id'] == null ? null : int.tryParse(a['event_id'].toString());
          return AlertItem(
            eventId: eventId,
            id: a['id'].toString(),
            eventName: a['event_name'] as String,
            gender: (a['gender'] as String) == 'male' ? Gender.male : Gender.female,
            distance: a['distance'] as String,
            imageUrl: (a['image_url'] as String?) ?? '',
          );
        }).toList();

        setState(() {
          _alerts = alerts;
          _isLoadingAlerts = false;
        });
      } else {
        setState(() {
          _isLoadingAlerts = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError(e);
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
        });
      }
    }
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
        ).toList();

        return result;
      }
    } catch (e) {
      ErrorHandler.logError(e);
    }

    return const [];
  }

  /// Открытие экрана события
  void _openEvent(int eventId) {
    if (!mounted) return;
    Navigator.of(context).push(
      TransparentPageRoute(
        builder: (_) => EventDetailScreen2(eventId: eventId),
      ),
    );
  }

  /// Создание оповещения через API
  Future<void> _createAlert() async {
    if (!_isValid || _isSubmitting) return;

    // ─── Проверяем, что событие выбрано из выпадающего списка ───
    final eventNameText = nameCtrl.text.trim();
    if (eventNameText.isEmpty || !_isEventSelectedFromDropdown) {
      setState(() {
        _errorMessage = 'Пожалуйста, выберите событие из списка предложенных вариантов';
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

      // ─── Проверяем, что дистанция выбрана (обязательна если событие выбрано) ───
      String distance;
      if (_selectedEventId != null) {
        if (_distances.isEmpty || _distanceIndex >= _distances.length) {
          throw Exception('Выберите дистанцию');
        }
        distance = _distances[_distanceIndex];
      } else {
        // Если событие не выбрано из списка, дистанция не требуется
        // Но по логике приложения событие всегда должно быть выбрано
        throw Exception('Выберите событие из списка');
      }

      // ─── Преобразуем Gender в строку для API ───
      final genderString = _gender == Gender.male ? 'male' : 'female';

      // ─── Отправляем данные на сервер ───
      final api = ApiService();
      final response = await api.post(
        '/create_alert.php',
        body: {
          'user_id': userId,
          if (_selectedEventId != null) 'event_id': _selectedEventId,
          'event_name': eventNameText,
          'distance': distance,
          'gender': genderString,
        },
      );

      // ─── Проверяем успешность ответа ───
      if (response['success'] == true) {
        // ─── Успешно создано оповещение ───
        if (mounted) {
          // Очищаем форму
          nameCtrl.clear();
          setState(() {
            _selectedEventId = null;
            _selectedEventLogoUrl = null;
            _isEventSelectedFromDropdown = false;
            _distances = [];
            _distanceIndex = 0;
            _gender = Gender.male;
            _isSubmitting = false;
          });

          // Загружаем обновленный список оповещений
          await _loadAlerts();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Оповещение создано'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // ─── Ошибка от сервера ───
        final errorMsg =
            response['message']?.toString() ??
            'Не удалось создать оповещение. Попробуйте ещё раз';
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

  /// Удаление оповещения через API
  Future<void> _deleteAlert(String id) async {
    try {
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }

      final api = ApiService();
      final response = await api.post(
        '/delete_alert.php',
        body: {
          'user_id': userId,
          'alert_id': int.parse(id),
        },
      );

      if (response['success'] == true) {
        // Загружаем обновленный список оповещений
        await _loadAlerts();
      } else {
        final errorMsg =
            response['message']?.toString() ??
            'Не удалось удалить оповещение';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ErrorHandler.logError(e);
      final errorMsg = ErrorHandler.format(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Создание оповещения',
          backgroundColor: AppColors.twinBg,
          showBack: true,
          showBottomDivider: false,
          elevation: 0,
        ),
        body: GestureDetector(
          // ── снимаем фокус с текстовых полей при клике вне их
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Контейнер формы с фоном surface ───
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.twinBg,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── Информационное сообщение ───
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Text(
                          'Вам придёт оповещение, если кто-то разместит слот, '
                          'соответствующий указанным критериям',
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Форма создания оповещения ───
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
                            _isEventSelectedFromDropdown = true;
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

                      // ─── Пол и дистанции показываем только после выбора события ───
                      if (_selectedEventId != null) ...[
                        const _SmallLabel('Пол'),
                        const SizedBox(height: 8),
                        _GenderRow(
                          maleSelected: _gender == Gender.male,
                          femaleSelected: _gender == Gender.female,
                          onMaleTap: () => setState(() => _gender = Gender.male),
                          onFemaleTap: () =>
                              setState(() => _gender = Gender.female),
                        ),
                        const SizedBox(height: 20),

                        // ─── Показываем список дистанций только если выбрано событие ───
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
                        const SizedBox(height: 30),
                      ],

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
                          text: 'Создать оповещение',
                          onPressed: _isSubmitting ? () {} : () => _createAlert(),
                          width: 220,
                          isLoading: _isSubmitting,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Раздел «Текущие оповещения» ───
              // Показываем только если идет загрузка или есть оповещения
              if (_isLoadingAlerts || _alerts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _SmallLabel('Текущие оповещения'),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingAlerts)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CupertinoActivityIndicator(),
                          ),
                        )
                      else
                        ..._alerts.map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AlertCard(
                              alert: alert,
                              onOpen: alert.eventId != null
                                  ? () => _openEvent(alert.eventId!)
                                  : null,
                              onDelete: () => _deleteAlert(alert.id),
                            ),
                          ),
                        ),
                    ],
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

/// ——— Локальные UI-компоненты ———

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.getTextPrimaryColor(context),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      ),
    );
  }
}

/// Поле автозаполнения для поиска событий (как в sale_slots_content.dart)
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
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: [
                          const BoxShadow(
                            color: AppColors.twinshadow,
                            blurRadius: 20,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: TextFormField(
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
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
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
                final optionsList = options.toList();

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
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.xl),
              ),
              border: sel
                  ? Border.all(
                      color: AppColors.brandPrimary,
                    )
                  : null,
              boxShadow: sel
                  ? null
                  : [
                      const BoxShadow(
                        color: AppColors.twinshadow,
                        blurRadius: 20,
                        offset: Offset(0, 1),
                      ),
                    ],
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
    // Используем ту же логику, что и в PrimaryButton
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
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xl)),
          border: selected
              ? Border.all(
                  color: AppColors.brandPrimary,
                )
              : null,
          boxShadow: selected
              ? null
              : [
                  const BoxShadow(
                    color: AppColors.twinshadow,
                    blurRadius: 20,
                    offset: Offset(0, 1),
                  ),
                ],
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

/// Карточка оповещения в стиле market_slot_card.dart
class _AlertCard extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onOpen;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.onDelete,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
        boxShadow: [
          const BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 20,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Миниатюра слева (кликабельная при наличии экрана события)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.xs),
                ),
                color: AppColors.getBackgroundColor(context),
              ),
              clipBehavior: Clip.antiAlias,
              child: alert.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: alert.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 58,
                        height: 58,
                        color: AppColors.getBackgroundColor(context),
                        child: Center(
                          child: CupertinoActivityIndicator(
                            radius: 10,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        CupertinoIcons.calendar,
                        size: 24,
                        color: AppColors.getIconSecondaryColor(context),
                      ),
                    )
                  : Icon(
                      CupertinoIcons.calendar,
                      size: 24,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
            ),
          ),
          const SizedBox(width: 8),

          // Текстовая часть
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Text(
                    alert.eventName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DistancePill(text: alert.distance),
                    const SizedBox(width: 6),
                    alert.gender == Gender.male
                        ? const GenderPill.male()
                        : const GenderPill.female(),
                    const Spacer(),
                    // Кнопка удаления
                    _DeleteButton(onPressed: onDelete),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка удаления в стиле _BuyButtonText из market_slot_card.dart
class _DeleteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: SizedBox(
        height: 28,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.getSurfaceMutedColor(context)
                : AppColors.redBg,
            foregroundColor: AppColors.red,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.xs)),
            ),
          ),
          child: const Text(
            'Удалить',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.red,
            ),
          ),
        ),
      ),
    );
  }
}
