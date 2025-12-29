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
  const ThingsContent({super.key});

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

    const headerCount = 1; // только селектор категории

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
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          if (index == 0) {
            return _CategoryDropdown(
              value: _selected,
              options: _categories,
              onChanged: (v) async {
                setState(() => _selected = v ?? 'Все');
                await _updateCategoryFilter();
              },
            );
          }

          // ── кнопка загрузки следующей страницы
          if (index == items.length + headerCount) {
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

          final i = index - headerCount;
          if (i >= items.length) return const SizedBox.shrink();

          final isOpen = _expanded.contains(items[i].id);

          return GoodsCard(
            item: items[i],
            expanded: isOpen,
            onToggle: () => setState(() => _expanded.toggle(items[i].id)),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final dropdownWidth = screenWidth * 0.3;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          width: dropdownWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: AppColors.getBorderColor(context),
                width: 0.7,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                icon: Icon(
                  CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.getIconPrimaryColor(context),
                ),
                dropdownColor: AppColors.getSurfaceColor(context),
                menuMaxHeight: 300,
                borderRadius: BorderRadius.circular(AppRadius.md),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.getTextPrimaryColor(context),
                ),
                onChanged: onChanged,
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.getTextPrimaryColor(context),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
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
