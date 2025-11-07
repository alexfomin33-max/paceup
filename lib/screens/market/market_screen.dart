// lib/screens/market/market_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Экран «Маркет» с PaceAppBar + SegmentedPill (как в tasks_screen.dart)
// Переключение вкладок через PageView со свайпом и синхронизированной пилюлей.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/segmented_pill.dart';

import 'tabs/slots/slots_content.dart';
import 'tabs/things/things_content.dart';
import 'state/sale_screen.dart';
import 'state/alert_creation_screen.dart';
import '../../widgets/transparent_route.dart';

// Те же локальные константы, что и в tasks_screen.dart
const _kTabAnim = Duration(milliseconds: 300);
const _kTabCurve = Curves.easeOut;

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  int _index = 0; // 0 — «Слоты», 1 — «Вещи»
  late final PageController _page = PageController(initialPage: _index);

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
      backgroundColor: AppColors.background,

      // ─── Верхняя панель: глобальный PaceAppBar ───
      appBar: PaceAppBar(
        title: 'Маркет',
        showBack: false,
        leadingWidth: 90,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(CupertinoPageRoute(builder: (_) => const SaleScreen()));
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
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                TransparentPageRoute(
                  builder: (_) => const AlertCreationScreen(),
                ),
              );
            },
            icon: const Icon(
              CupertinoIcons.bell,
              size: 22,
              color: AppColors.iconPrimary,
            ),
            splashRadius: 22,
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ─── Пилюля под AppBar + контент вкладок со свайпом ───
      body: Column(
        children: [
          const SizedBox(height: 14),
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
                onChanged: _onSegChanged,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              allowImplicitScrolling: true,
              onPageChanged: (i) {
                if (_index == i) return; // гард от лишних setState
                setState(() => _index = i);
              },
              children: const [
                SlotsContent(key: PageStorageKey('market_slots')),
                ThingsContent(key: PageStorageKey('market_things')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
