import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/segmented_pill.dart';

import 'sale_slots/sale_slots_content.dart';
import 'sale_things/sale_things_content.dart';

const _kTabAnim = Duration(milliseconds: 300);
const _kTabCurve = Curves.easeOut;

/// Экран продажи: каркас + пилюля + PageView со свайпом
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  int _index = 0; // 0 — Продажа слота, 1 — Продажа вещи
  late final PageController _page = PageController(initialPage: _index);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _onSegChanged(int v) {
    if (v == _index) return;
    setState(() => _index = v);
    _page.animateToPage(v, duration: _kTabAnim, curve: _kTabCurve);
  }

  void _onPageChanged(int v) => setState(() => _index = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),

      appBar: const PaceAppBar(
        title: 'Продажа',
        showBack: true,
        showBottomDivider: true,
      ),

      body: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SegmentedPill(
                left: 'Продажа слота',
                right: 'Продажа вещи',
                value: _index,
                width: 300,
                height: 40,
                duration: _kTabAnim,
                curve: _kTabCurve,
                haptics: true,
                onChanged: _onSegChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              onPageChanged: _onPageChanged,
              children: const [
                SaleSlotsContent(key: ValueKey('sale_slots')),
                SaleThingsContent(key: ValueKey('sale_things')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
