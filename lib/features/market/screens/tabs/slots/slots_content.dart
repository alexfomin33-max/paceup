// lib/screens/market/tabs/slots/slots_content.dart
// Всё, что относится к вкладке «Слоты»: поиск, фильтрация, список, раскрытие карточек.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../providers/slots_provider.dart';
import '../../../providers/slots_notifier.dart';
import 'widgets/market_slot_card.dart';

class SlotsContent extends ConsumerStatefulWidget {
  const SlotsContent({super.key});

  @override
  ConsumerState<SlotsContent> createState() => _SlotsContentState();
}

class _SlotsContentState extends ConsumerState<SlotsContent> {
  // Поиск по названию события
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _debouncedSearchQuery = ''; // Для debounce поиска

  // Раскрытые карточки (по индексу)
  final Set<int> _expanded = {};

  // ScrollController для отслеживания прокрутки и подгрузки данных
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Debounce для поиска - обновляем _debouncedSearchQuery через 500ms после последнего изменения
    _searchCtrl.addListener(_onSearchChanged);

    // Отслеживаем прокрутку для подгрузки данных
    _scrollController.addListener(_onScroll);
  }

  void _onSearchChanged() {
    final newQuery = _searchCtrl.text.trim().toLowerCase();
    // Обновляем debounced query через 500ms
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchCtrl.text.trim().toLowerCase() == newQuery) {
        // Проверяем, изменился ли запрос
        if (_debouncedSearchQuery != newQuery) {
          _debouncedSearchQuery = newQuery;
          
          // Обновляем фильтр через notifier (без пересоздания provider)
          final newFilter = SlotsFilter(
            search: newQuery.isNotEmpty ? newQuery : null,
          );
          
          // Обновляем фильтр в notifier - это не вызовет пересоздание виджета
          final notifier = ref.read(slotsProvider.notifier);
          notifier.updateFilter(newFilter);
        }
      }
    });
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
          _SearchField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Название спортивного мероприятия',
            onChanged: (value) {
              // Изменение обрабатывается через listener в initState
            },
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _debouncedSearchQuery = '';
              });
              final notifier = ref.read(slotsProvider.notifier);
              notifier.updateFilter(const SlotsFilter());
            },
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
          _SearchField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Название спортивного мероприятия',
            onChanged: (value) {
              // Изменение обрабатывается через listener в initState
            },
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _debouncedSearchQuery = '';
              });
              final notifier = ref.read(slotsProvider.notifier);
              notifier.updateFilter(const SlotsFilter());
            },
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
          _SearchField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Название спортивного мероприятия',
            onChanged: (value) {
              // Изменение обрабатывается через listener в initState
            },
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _debouncedSearchQuery = '';
              });
              final notifier = ref.read(slotsProvider.notifier);
              notifier.updateFilter(const SlotsFilter());
            },
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
          return _SearchField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            hintText: 'Название спортивного мероприятия',
            onChanged: (value) {
              // Изменение обрабатывается через listener в initState
            },
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _debouncedSearchQuery = '';
              });
              final notifier = ref.read(slotsProvider.notifier);
              notifier.updateFilter(const SlotsFilter());
            },
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

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Listener(
      // При повторном тапе на поле, если оно уже в фокусе, снимаем фокус
      onPointerDown: (_) {
        // Сохраняем состояние фокуса ДО обработки тапа TextField
        final wasFocused = widget.focusNode.hasFocus;

        // Если поле уже было в фокусе, снимаем фокус после обработки тапа
        if (wasFocused) {
          // Используем небольшую задержку, чтобы дать TextField обработать тап
          // (например, для установки курсора), затем снимаем фокус
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted || !context.mounted || !widget.focusNode.hasFocus) {
              return;
            }
            FocusScope.of(context).unfocus();
          });
        }
      },
      child: TextField(
        key: const ValueKey('search_field'), // Ключ для сохранения состояния
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        cursorColor: AppColors.getTextSecondaryColor(context),
        textInputAction: TextInputAction.search,
        // Отключаем автоматическое снятие фокуса при изменении
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
                  onPressed: widget.onClear,
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
