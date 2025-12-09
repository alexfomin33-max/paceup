// lib/screens/market/tabs/slots/slots_content.dart
// Всё, что относится к вкладке «Слоты»: поиск, фильтрация, список, раскрытие карточек.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/api_service.dart';
import '../../../providers/slots_provider.dart';
import '../../../providers/slots_notifier.dart';
import '../../../models/event_option.dart';
import 'widgets/market_slot_card.dart';

class SlotsContent extends ConsumerStatefulWidget {
  const SlotsContent({super.key});

  @override
  ConsumerState<SlotsContent> createState() => _SlotsContentState();
}

class _SlotsContentState extends ConsumerState<SlotsContent> {
  // Поиск событий
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Выбранное событие (null = все слоты, EventOption.mySlots() = мои слоты)
  // Используем ValueNotifier для безопасного обновления без setState
  final ValueNotifier<EventOption?> _selectedEventNotifier =
      ValueNotifier<EventOption?>(null);

  // Геттер для обратной совместимости
  EventOption? get _selectedEvent => _selectedEventNotifier.value;

  // Раскрытые карточки (по индексу)
  final Set<int> _expanded = {};

  // ScrollController для отслеживания прокрутки и подгрузки данных
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Отслеживаем прокрутку для подгрузки данных
    _scrollController.addListener(_onScroll);
  }

  /// Обработка выбора события из списка
  void _onEventSelected(EventOption event) {
    // КРИТИЧНО: Autocomplete вызывает onSelected синхронно во время обработки событий ввода.
    // Проблема: любые синхронные изменения состояния (setState) вызывают перестроение виджета,
    // что удаляет Autocomplete до того, как он успевает закрыть overlay, вызывая ошибку.
    //
    // Решение: НЕ вызываем setState в onSelected вообще. Используем ValueNotifier,
    // который обновляет состояние асинхронно и безопасно, не вызывая немедленного перестроения.

    // Обновляем состояние через ValueNotifier (безопасно, не вызывает перестроение)
    _selectedEventNotifier.value = event;

    // Асинхронные операции запускаем отдельно
    final notifier = ref.read(slotsProvider.notifier);

    if (event.isMySlots) {
      // Для "Мои" получаем user_id из AuthService
      unawaited(
        _loadMySlots(notifier).catchError((error) {
          debugPrint('❌ Ошибка загрузки моих слотов: $error');
        }),
      );
    } else {
      // Для выбранного события фильтруем по event_id
      final newFilter = SlotsFilter(eventId: event.id);
      unawaited(
        notifier.updateFilter(newFilter).catchError((error) {
          debugPrint('❌ Ошибка обновления фильтра: $error');
        }),
      );
    }
  }

  /// Загрузка слотов пользователя
  Future<void> _loadMySlots(SlotsNotifier notifier) async {
    final authService = AuthService();
    final userId = await authService.getUserId();

    if (userId != null) {
      final newFilter = SlotsFilter(userId: userId);
      notifier.updateFilter(newFilter);
    } else {
      // Если не удалось получить user_id, показываем все слоты
      notifier.updateFilter(const SlotsFilter());
    }
  }

  /// Очистка выбранного события
  void _onClear() {
    _selectedEventNotifier.value = null;
    _searchCtrl.clear();

    // Показываем все слоты
    final notifier = ref.read(slotsProvider.notifier);
    notifier.updateFilter(const SlotsFilter());
  }

  void _onScroll() {
    // Загружаем следующую страницу, когда пользователь прокрутил до 80% списка
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final notifier = ref.read(slotsProvider.notifier);
      notifier.loadMore();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _selectedEventNotifier.dispose();
    super.dispose();
  }

  /// Поиск событий для автозаполнения
  Future<Iterable<EventOption>> _searchEvents(String query) async {
    if (query.trim().length < 2) {
      // Если запрос короткий, возвращаем только "Мои"
      return [EventOption.mySlots()];
    }

    try {
      // Прямой вызов API для поиска событий
      final api = ApiService();
      final response = await api.post(
        '/search_events.php',
        body: {'query': query.trim()},
      );

      if (response['success'] == true) {
        final List<dynamic> eventsData = response['events'] ?? [];
        final searchResults = eventsData
            .map((e) => EventOption.fromApi(e as Map<String, dynamic>))
            .toList();

        // Всегда добавляем "Мои" в начало списка
        return [EventOption.mySlots(), ...searchResults];
      }

      // В случае ошибки возвращаем только "Мои"
      return [EventOption.mySlots()];
    } catch (e) {
      // В случае ошибки возвращаем только "Мои"
      debugPrint('❌ Ошибка поиска событий: $e');
      return [EventOption.mySlots()];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Получаем состояние из provider (теперь один стабильный provider без family)
    // Это не вызывает пересоздание виджета при изменении фильтра
    final slotsState = ref.watch(slotsProvider);

    const headerCount = 1; // только строка поиска

    // Состояние загрузки (начальная загрузка)
    if (slotsState.isLoading && slotsState.items.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _EventDropdownField(
              key: const ValueKey('event_dropdown_field'),
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              hintText: 'Поиск события',
              selectedEvent: _selectedEvent,
              onEventSelected: _onEventSelected,
              onClear: _onClear,
              searchFunction: _searchEvents,
            ),
          ),
          const SizedBox(height: 40),
          const CupertinoActivityIndicator(),
          const SizedBox(height: 16),
          Text(
            'Загрузка слотов...',
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      );
    }

    // Состояние ошибки
    if (slotsState.error != null && slotsState.items.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _EventDropdownField(
              key: const ValueKey('event_dropdown_field'),
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              hintText: 'Поиск события',
              selectedEvent: _selectedEvent,
              onEventSelected: _onEventSelected,
              onClear: _onClear,
              searchFunction: _searchEvents,
            ),
          ),
          const SizedBox(height: 40),
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 48,
            color: AppColors.getTextSecondaryColor(context),
          ),
          const SizedBox(height: 16),
          SelectableText.rich(
            TextSpan(
              text: 'Ошибка загрузки слотов:\n',
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
              children: [
                TextSpan(
                  text: slotsState.error!,
                  style: AppTextStyles.h14w4.copyWith(color: Colors.red),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: () {
              final notifier = ref.read(slotsProvider.notifier);
              notifier.loadInitial();
            },
            child: const Text('Повторить'),
          ),
        ],
      );
    }

    // Пустое состояние
    if (slotsState.items.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _EventDropdownField(
              key: const ValueKey('event_dropdown_field'),
              controller: _searchCtrl,
              focusNode: _searchFocusNode,
              hintText: 'Поиск события',
              selectedEvent: _selectedEvent,
              onEventSelected: _onEventSelected,
              onClear: _onClear,
              searchFunction: _searchEvents,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Слоты не найдены',
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      );
    }

    // Основной список слотов с pull-to-refresh
    return RefreshIndicator(
      onRefresh: () async {
        // Обновляем список слотов при pull-to-refresh
        final notifier = ref.read(slotsProvider.notifier);
        await notifier.loadInitial();
      },
      child: ListView.separated(
        key: const ValueKey('slots_list'),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount:
            slotsState.items.length +
            headerCount +
            (slotsState.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          if (index == 0) {
            return RepaintBoundary(
              child: _EventDropdownField(
                key: const ValueKey('event_dropdown_field'),
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                hintText: 'Поиск события',
                selectedEvent: _selectedEvent,
                onEventSelected: _onEventSelected,
                onClear: _onClear,
                searchFunction: _searchEvents,
              ),
            );
          }

          // Индикатор загрузки следующей страницы в конце списка
          if (index == slotsState.items.length + headerCount) {
            return slotsState.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final i = index - headerCount;
          final item = slotsState.items[i];
          final isOpen = _expanded.contains(i);

          return MarketSlotCard(
            item: item,
            expanded: isOpen,
            onToggle: () => setState(() => _expanded.toggle(i)),
            onChatClosed: () {
              // Обновляем список слотов после возврата из экрана чата
              final notifier = ref.read(slotsProvider.notifier);
              notifier.loadInitial();
            },
          );
        },
      ),
    );
  }
}

// ————————————————— Внутренние UI-компоненты —————————————————

/// Поле выпадающего списка с поиском событий
/// Использует TextField с ручным управлением overlay вместо Autocomplete
/// для предотвращения ошибок overlay
class _EventDropdownField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final EventOption? selectedEvent;
  final ValueChanged<EventOption> onEventSelected;
  final VoidCallback onClear;
  final Future<Iterable<EventOption>> Function(String) searchFunction;

  const _EventDropdownField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.selectedEvent,
    required this.onEventSelected,
    required this.onClear,
    required this.searchFunction,
  });

  @override
  State<_EventDropdownField> createState() => _EventDropdownFieldState();
}

class _EventDropdownFieldState extends State<_EventDropdownField> {
  // Результаты поиска
  List<EventOption> _options = [];
  bool _isLoading = false;

  // OverlayEntry для отображения списка результатов
  OverlayEntry? _overlayEntry;

  // LayerLink для позиционирования overlay относительно TextField
  final LayerLink _layerLink = LayerLink();

  // GlobalKey для получения позиции TextField
  final GlobalKey _fieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Синхронизируем текст контроллера с selectedEvent
    if (widget.selectedEvent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.controller.text != widget.selectedEvent!.name) {
          widget.controller.text = widget.selectedEvent!.name;
        }
      });
    }

    // Слушаем изменения текста для поиска
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_EventDropdownField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Синхронизируем текст при изменении selectedEvent
    if (widget.selectedEvent != oldWidget.selectedEvent) {
      if (widget.selectedEvent != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.controller.text != widget.selectedEvent!.name) {
            widget.controller.text = widget.selectedEvent!.name;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _hideOptions();
    super.dispose();
  }

  void _onTextChanged() {
    final query = widget.controller.text.trim();

    if (query.isEmpty) {
      // Если поле пустое, скрываем overlay
      setState(() {
        _options = [];
        _isLoading = false;
      });
      _hideOptions();
      return;
    }

    if (query.length < 2) {
      // Если запрос короткий, показываем только "Мои"
      setState(() {
        _options = [EventOption.mySlots()];
        _isLoading = false;
      });
      _showOptionsIfFocused();
      return;
    }

    // Запускаем поиск
    _performSearch(query);
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      // При получении фокуса показываем "Мои" сразу, если поле пустое
      if (widget.controller.text.trim().isEmpty) {
        setState(() {
          _options = [EventOption.mySlots()];
          _isLoading = false;
        });
      }
      _showOptionsIfFocused();
    } else {
      // Скрываем overlay при потере фокуса
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !widget.focusNode.hasFocus) {
          _hideOptions();
        }
      });
    }
  }

  Future<void> _performSearch(String query) async {
    // Показываем индикатор загрузки
    setState(() {
      _isLoading = true;
      _options = []; // Очищаем старые результаты
    });
    _showOptionsIfFocused(); // Показываем overlay с индикатором загрузки

    try {
      final results = await widget.searchFunction(query);
      if (mounted && widget.controller.text.trim() == query) {
        // Проверяем, что текст не изменился во время поиска
        setState(() {
          _options = results.toList();
          _isLoading = false;
        });
        _showOptionsIfFocused(); // Обновляем overlay с результатами
      }
    } catch (e) {
      debugPrint('❌ Ошибка поиска событий: $e');
      if (mounted && widget.controller.text.trim() == query) {
        setState(() {
          _options = [
            EventOption.mySlots(),
          ]; // Показываем хотя бы "Мои" при ошибке
          _isLoading = false;
        });
        _showOptionsIfFocused();
      }
    }
  }

  void _showOptionsIfFocused() {
    if (!widget.focusNode.hasFocus) {
      _hideOptions();
      return;
    }

    // Если overlay уже показан, обновляем его (пересоздаем)
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    // Показываем overlay только если есть результаты или идет загрузка
    if (_options.isNotEmpty || _isLoading) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _hideOptions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        // Получаем размер TextField динамически
        final RenderBox? renderBox =
            _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? const Size(200, 50); // Fallback размер

        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.getSurfaceColor(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    : _options.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = _options[index];
                          final isMySlots = option.isMySlots;

                          return InkWell(
                            onTap: () {
                              _hideOptions();
                              widget.focusNode.unfocus();
                              widget.onEventSelected(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  // Изображение события или иконка
                                  if (isMySlots)
                                    Icon(
                                      CupertinoIcons.person_fill,
                                      size: 18,
                                      color: AppColors.getIconSecondaryColor(
                                        context,
                                      ),
                                    )
                                  else if (option.logoUrl != null &&
                                      option.logoUrl!.isNotEmpty)
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
                                      child: Image.network(
                                        option.logoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            CupertinoIcons.calendar,
                                            size: 18,
                                            color:
                                                AppColors.getIconSecondaryColor(
                                                  context,
                                                ),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Icon(
                                      CupertinoIcons.calendar,
                                      size: 18,
                                      color: AppColors.getIconSecondaryColor(
                                        context,
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
                                          style: AppTextStyles.h14w4.copyWith(
                                            color:
                                                AppColors.getTextPrimaryColor(
                                                  context,
                                                ),
                                          ),
                                        ),
                                        if (!isMySlots &&
                                            option.place.isNotEmpty)
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText =
        widget.controller.text.isNotEmpty || widget.selectedEvent != null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        key: _fieldKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        onSubmitted: (String value) {
          _hideOptions();
        },
        cursorColor: AppColors.getTextSecondaryColor(context),
        textInputAction: TextInputAction.search,
        enableInteractiveSelection: true,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 17,
          ),
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 18,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    _hideOptions();
                    widget.onClear();
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
      ),
    );
  }
}

// ————————————————— Утилита: Set.toggle —————————————————
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}
