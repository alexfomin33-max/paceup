// lib/screens/market/market_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Маркет» с PaceAppBar + SegmentedPill
// Переключение вкладок без анимации и свайпа (как в search_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/segmented_pill.dart';

import 'tabs/slots/slots_content.dart';
import 'tabs/things/things_content.dart';
import 'state/sale_slots_screen.dart';
import 'state/sale_things_screen.dart';
import 'state/alert_creation_screen.dart';
import '../../../core/widgets/transparent_route.dart';
import '../providers/things_provider.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  int _index = 0; // 0 — «Слоты», 1 — «Вещи»
  bool _isSearchVisible = false; // Видимость поля поиска во вкладке «Слоты»
  bool _isFiltersVisible = false; // Видимость меню фильтров во вкладке «Вещи»

  void _onSegChanged(int v) {
    if (_index == v) return;
    setState(() {
      _index = v;
      // Скрываем поле поиска при переключении на другую вкладку
      if (v != 0) {
        _isSearchVisible = false;
      }
      // Скрываем меню фильтров при переключении на другую вкладку
      if (v != 1) {
        _isFiltersVisible = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.twinBg,

      // ─── Верхняя панель: глобальный PaceAppBar ───
      appBar: PaceAppBar(
        backgroundColor: AppColors.twinBg,
        showBottomDivider: false,
        elevation: 0,
        title: 'Маркет',
        showBack: false,
        leadingWidth: 90,
        leading: GestureDetector(
          onTap: () async {
            // ── открываем соответствующий экран продажи в зависимости от текущей вкладки
            final created = await Navigator.of(
              context,
              rootNavigator: true,
            ).push<bool>(
              CupertinoPageRoute(
                builder: (_) => _index == 0
                    ? const SaleSlotsScreen()
                    : const SaleThingsScreen(),
              ),
            );

            // ── если из формы вернулись с успешным созданием и мы на вкладке «Вещи»,
            //     автоматически перезагружаем список, чтобы показать новое объявление
            if (created == true && mounted && _index == 1) {
              await ref.read(thingsProvider.notifier).loadInitial();
            }
            // ── если из формы вернулись с успешным созданием и мы на вкладке «Слоты»,
            //     список слотов обновляется автоматически через slotsProvider в SaleSlotsContent
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'продать',
                style: AppTextStyles.h15w4.copyWith(
                  color: AppColors.brandPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
        actions: [
          // Иконка поиска (только во вкладке «Слоты»)
          if (_index == 0)
            IconButton(
              tooltip: 'Поиск',
              onPressed: () {
                setState(() {
                  _isSearchVisible = !_isSearchVisible;
                });
              },
              icon: Icon(
                CupertinoIcons.search,
                size: 22,
                color: AppColors.getIconPrimaryColor(context),
              ),
              splashRadius: 22,
            ),
          // Иконка уведомлений (только во вкладке «Слоты»)
          if (_index == 0)
            IconButton(
              tooltip: 'Уведомления',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  TransparentPageRoute(
                    builder: (_) => const AlertCreationScreen(),
                  ),
                );
              },
              icon: Icon(
                CupertinoIcons.bell,
                size: 22,
                color: AppColors.getIconPrimaryColor(context),
              ),
              splashRadius: 22,
            ),
          // Иконка фильтров (только во вкладке «Вещи»)
          if (_index == 1)
            IconButton(
              tooltip: 'Фильтры',
              onPressed: () {
                setState(() {
                  _isFiltersVisible = !_isFiltersVisible;
                });
              },
              icon: Icon(
                CupertinoIcons.slider_horizontal_3,
                size: 22,
                color: AppColors.getIconPrimaryColor(context),
              ),
              splashRadius: 22,
            ),
          const SizedBox(width: 6),
        ],
      ),

      // ─── Контент вкладок: пилюля скроллится вместе с контентом ───
      body: _index == 0
          ? SlotsContent(
              key: const PageStorageKey('market_slots'),
              isSearchVisible: _isSearchVisible,
              customHeaderSlivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Center(
                      child: SegmentedPill(
                        left: 'Слоты',
                        right: 'Вещи',
                        value: _index,
                        width: 280,
                        height: 40,
                        duration: Duration.zero,
                        haptics: true,
                        showBorder: true,
                        borderColor: AppColors.twinchip,
                        onChanged: _onSegChanged,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ThingsContent(
              key: const PageStorageKey('market_things'),
              isFiltersVisible: _isFiltersVisible,
              customHeaderSlivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Center(
                      child: SegmentedPill(
                        left: 'Слоты',
                        right: 'Вещи',
                        value: _index,
                        width: 280,
                        height: 40,
                        duration: Duration.zero,
                        haptics: true,
                        showBorder: true,
                        borderColor: AppColors.twinchip,
                        onChanged: _onSegChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
