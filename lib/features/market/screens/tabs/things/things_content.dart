// lib/screens/market/tabs/things/things_content.dart
// Всё, что относится к вкладке «Вещи»: выбор категории, список, раскрытие карточек.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../providers/services/auth_provider.dart';
import '../../../providers/things_provider.dart';
import '../../../providers/things_notifier.dart';
import 'widgets/market_things_card.dart';

class ThingsContent extends ConsumerStatefulWidget {
  final bool isFiltersVisible;

  const ThingsContent({
    super.key,
    this.isFiltersVisible = false,
  });

  @override
  ConsumerState<ThingsContent> createState() => _ThingsContentState();
}

class _ThingsContentState extends ConsumerState<ThingsContent> {
  final List<String> _categories = const [
    'Все',
    'Мои',
    'Кроссовки',
    'Часы',
    'Одежда',
    'Аксессуары',
  ];
  String _selected = 'Все';

  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    // ── обновляем фильтр при изменении категории
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCategoryFilter();
    });
  }

  Future<void> _updateCategoryFilter() async {
    final notifier = ref.read(thingsProvider.notifier);

    // ── преобразуем выбранную категорию в фильтр
    String? categoryFilter;
    int? sellerId;

    if (_selected == 'Мои') {
      // ── при выборе "Мои" получаем userId из AuthService
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      if (userId != null) {
        sellerId = userId;
      }
    } else if (_selected != 'Все') {
      categoryFilter = _selected;
    }

    // ── создаем новый фильтр
    final newFilter = ThingsFilter(
      category: categoryFilter,
      sellerId: sellerId,
    );
    await notifier.updateFilter(newFilter);
  }

  @override
  Widget build(BuildContext context) {
    final thingsState = ref.watch(thingsProvider);
    final items = thingsState.items;

    // Количество элементов заголовка (селектор категории показывается только если isFiltersVisible)
    final headerCount = widget.isFiltersVisible ? 1 : 0;

    // ── показываем индикатор загрузки
    if (thingsState.isLoading && items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CupertinoActivityIndicator(radius: 10),
        ),
      );
    }

    // ── показываем ошибку
    if (thingsState.error != null && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Ошибка загрузки',
                style: TextStyle(color: AppColors.error, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                thingsState.error!,
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(context),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(thingsProvider.notifier).loadInitial();
      },
      child: ListView.separated(
        key: const ValueKey('things_list'),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: items.length + headerCount + (thingsState.hasMore ? 1 : 0),
        separatorBuilder: (_, index) {
          // Убираем отступ после выпадающего меню
          if (widget.isFiltersVisible && index == 0) {
            return const SizedBox.shrink();
          }
          return const SizedBox(height: 10);
        },
        itemBuilder: (_, index) {
          if (index == 0 && widget.isFiltersVisible) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: _CategoryDropdown(
                value: _selected,
                options: _categories,
                onChanged: (v) async {
                  setState(() => _selected = v ?? 'Все');
                  await _updateCategoryFilter();
                },
              ),
            );
          }

          // Если меню фильтров скрыто, корректируем индекс для элементов списка
          final itemIndex = widget.isFiltersVisible ? index - headerCount : index;

          // ── кнопка загрузки следующей страницы
          if (itemIndex == items.length) {
            if (thingsState.isLoadingMore) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CupertinoActivityIndicator(radius: 10),
                ),
              );
            }
            if (thingsState.hasMore) {
              return Center(
                child: TextButton(
                  onPressed: () {
                    ref.read(thingsProvider.notifier).loadMore();
                  },
                  child: const Text('Загрузить еще'),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          if (itemIndex >= items.length) return const SizedBox.shrink();

          final isOpen = _expanded.contains(items[itemIndex].id);

          // Добавляем отступ над первой карточкой
          final isFirstCard = itemIndex == 0;

          return Padding(
            padding: EdgeInsets.only(top: isFirstCard ? 16 : 0),
            child: GoodsCard(
              item: items[itemIndex],
              expanded: isOpen,
              onToggle: () => setState(() => _expanded.toggle(items[itemIndex].id)),
            ),
          );
        },
      ),
    );
  }
}

// ————————————————— Внутренние UI-компоненты —————————————————

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: const [
          BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 20,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: Icon(
            CupertinoIcons.chevron_down,
            size: 18,
            color: AppColors.getIconSecondaryColor(context),
          ),
          dropdownColor: AppColors.getSurfaceColor(context),
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
          onChanged: onChanged,
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ————————————————— Утилита: Set.toggle —————————————————
extension<T> on Set<T> {
  void toggle(T v) => contains(v) ? remove(v) : add(v);
}
