// lib/screens/market/market_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Маркет» с PaceAppBar + SegmentedPill (как в tasks_screen.dart)
// Переключение вкладок через PageView со свайпом и синхронизированной пилюлей.
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

// Те же локальные константы, что и в tasks_screen.dart
const _kTabAnim = Duration(milliseconds: 300);
const _kTabCurve = Curves.easeOut;

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  int _index = 0; // 0 — «Слоты», 1 — «Вещи»
  late final PageController _page = PageController(initialPage: _index);
  bool _isSearchVisible = false; // Видимость поля поиска во вкладке «Слоты»
  bool _isFiltersVisible = false; // Видимость меню фильтров во вкладке «Вещи»

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _onSegChanged(int v) {
    if (_index == v) return;
    setState(() => _index = v);
    _page.animateToPage(v, duration: _kTabAnim, curve: _kTabCurve);
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

      // ─── Пилюля под AppBar + контент вкладок со свайпом ───
      body: Column(
        children: [
       
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SegmentedPill(
                left: 'Слоты',
                right: 'Вещи',
                value: _index,
                width: 280,
                height: 40,
                duration: _kTabAnim,
                curve: _kTabCurve,
                haptics: true,
                showBorder: true,
                borderColor: AppColors.twinchip,
                // boxShadow: const [
                //   BoxShadow(
                //     color: AppColors.twinshadow,
                //     blurRadius: 20,
                //     offset: Offset(0, 1),
                //   ),
                // ],
                onChanged: _onSegChanged,
              ),
            ),
          ),
          

          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (i) {
                if (_index == i) return; // гард от лишних setState
                setState(() {
                  _index = i;
                  // Скрываем поле поиска при переключении на другую вкладку
                  if (i != 0) {
                    _isSearchVisible = false;
                  }
                  // Скрываем меню фильтров при переключении на другую вкладку
                  if (i != 1) {
                    _isFiltersVisible = false;
                  }
                });
              },
              children: [
                SlotsContent(
                  key: const PageStorageKey('market_slots'),
                  isSearchVisible: _isSearchVisible,
                ),
                ThingsContent(
                  key: const PageStorageKey('market_things'),
                  isFiltersVisible: _isFiltersVisible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
