// lib/screens/market/tabs/slots/slots_content.dart
// Всё, что относится к вкладке «Слоты»: поиск, фильтрация, список, раскрытие карточек.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
  EventOption? _selectedEvent;
  
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
    // КРИТИЧНО: Autocomplete вызывает onSelected синхронно во время обработки
    // событий ввода, поэтому все операции нужно отложить, чтобы не блокировать UI.
    // Используем Future.microtask для немедленного отложения на следующий тик event loop,
    // что позволяет Autocomplete корректно завершить свою работу.
    Future.microtask(() {
      if (!mounted) return;
      
      // Обновляем локальное состояние выбранного события
      setState(() {
        _selectedEvent = event;
      });
      
      // Снимаем фокус с поля поиска
      _searchFocusNode.unfocus();
    });
    
    // Асинхронные операции запускаем отдельно, чтобы не блокировать обновление UI
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
    setState(() {
      _selectedEvent = null;
      _searchCtrl.clear();
    });
    
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
          _EventDropdownField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Поиск события',
            selectedEvent: _selectedEvent,
            onEventSelected: _onEventSelected,
            onClear: _onClear,
            searchFunction: _searchEvents,
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
          _EventDropdownField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Поиск события',
            selectedEvent: _selectedEvent,
            onEventSelected: _onEventSelected,
            onClear: _onClear,
            searchFunction: _searchEvents,
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
                  style: AppTextStyles.h14w4.copyWith(
                    color: Colors.red,
                  ),
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
          _EventDropdownField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Поиск события',
            selectedEvent: _selectedEvent,
            onEventSelected: _onEventSelected,
            onClear: _onClear,
            searchFunction: _searchEvents,
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
        itemCount: slotsState.items.length + headerCount + (slotsState.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
        if (index == 0) {
          return _EventDropdownField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Поиск события',
            selectedEvent: _selectedEvent,
            onEventSelected: _onEventSelected,
            onClear: _onClear,
            searchFunction: _searchEvents,
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
class _EventDropdownField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final EventOption? selectedEvent;
  final ValueChanged<EventOption> onEventSelected;
  final VoidCallback onClear;
  final Future<Iterable<EventOption>> Function(String) searchFunction;

  const _EventDropdownField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.selectedEvent,
    required this.onEventSelected,
    required this.onClear,
    required this.searchFunction,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<EventOption>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.length < 2) {
          // Если запрос короткий, возвращаем только "Мои"
          return [EventOption.mySlots()];
        }
        return await searchFunction(textEditingValue.text);
      },
      onSelected: onEventSelected,
      displayStringForOption: (option) => option.name,
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController textEditingController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        // УБРАНА синхронизация контроллера - Autocomplete сам управляет своим
        // контроллером при выборе. Синхронизация вызывала бесконечные циклы
        // перестроения и зависания на мобильных устройствах.
        // Autocomplete автоматически обновляет textEditingController при выборе
        // через onSelected, поэтому дополнительная синхронизация не нужна.
        
        final hasText = textEditingController.text.isNotEmpty || 
            selectedEvent != null;
        
        return TextField(
          key: const ValueKey('event_search_field'),
          controller: textEditingController,
          focusNode: focusNode,
          onSubmitted: (String value) {
            onFieldSubmitted();
          },
          cursorColor: AppColors.getTextSecondaryColor(context),
          textInputAction: TextInputAction.search,
          enableInteractiveSelection: true,
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: hintText,
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
                    onPressed: onClear,
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
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<EventOption> onSelected,
        Iterable<EventOption> options,
      ) {
        // Если список пустой, не показываем ничего
        if (options.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  final isMySlots = option.isMySlots;
                  
                  return InkWell(
                    onTap: () => onSelected(option),
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
                              color: AppColors.getIconSecondaryColor(context),
                            )
                          else if (option.logoUrl != null && option.logoUrl!.isNotEmpty)
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                                color: AppColors.getBackgroundColor(context),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                option.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    CupertinoIcons.calendar,
                                    size: 18,
                                    color: AppColors.getIconSecondaryColor(context),
                                  );
                                },
                              ),
                            )
                          else
                            Icon(
                              CupertinoIcons.calendar,
                              size: 18,
                              color: AppColors.getIconSecondaryColor(context),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.name,
                                  style: AppTextStyles.h14w4.copyWith(
                                    color: AppColors.getTextPrimaryColor(context),
                                  ),
                                ),
                                if (!isMySlots && option.place.isNotEmpty)
                                  Text(
                                    option.place,
                                    style: AppTextStyles.h12w4.copyWith(
                                      color: AppColors.getTextSecondaryColor(context),
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
        );
      },
    );
  }
}

// ————————————————— Утилита: Set.toggle —————————————————
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}
