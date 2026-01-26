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
  final List<Widget>? customHeaderSlivers;

  const ThingsContent({
    super.key,
    this.isFiltersVisible = false,
    this.customHeaderSlivers,
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

    // ── функция обновления при pull-to-refresh
    Future<void> onRefresh() async {
      await ref.read(thingsProvider.notifier).loadInitial();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── кастомные слайверы (пилюля) из родительского экрана
          if (widget.customHeaderSlivers != null) ...widget.customHeaderSlivers!,
          if (widget.customHeaderSlivers != null)
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── состояние загрузки
          if (thingsState.isLoading && items.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CupertinoActivityIndicator(radius: 10),
                ),
              ),
            )
          // ── состояние ошибки
          else if (thingsState.error != null && items.isEmpty)
            SliverToBoxAdapter(
              child: Center(
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
              ),
            )
          // ── основной список
          else ...[
            // ── селектор категории (если видим)
            if (widget.isFiltersVisible)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: _CategoryDropdown(
                    value: _selected,
                    options: _categories,
                    onChanged: (v) async {
                      setState(() => _selected = v ?? 'Все');
                      await _updateCategoryFilter();
                    },
                  ),
                ),
              ),
            // ── список карточек
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              sliver: SliverList.separated(
                itemCount: items.length + (thingsState.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  // ── кнопка загрузки следующей страницы
                  if (index == items.length) {
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

                  final isOpen = _expanded.contains(items[index].id);
                  final isFirstCard = index == 0;

                  return Padding(
                    padding: EdgeInsets.only(top: isFirstCard ? 0 : 0),
                    child: GoodsCard(
                      item: items[index],
                      expanded: isOpen,
                      onToggle: () => setState(() => _expanded.toggle(items[index].id)),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        boxShadow: const [
            BoxShadow(
            color: AppColors.twinchip,
            blurRadius: 10,
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
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
