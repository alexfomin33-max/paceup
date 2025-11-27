// lib/screens/.../adding_equipment_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/segmented_pill.dart'; // глобальная пилюля
import 'tabs/adding_bike_content.dart';
import 'tabs/adding_sneakers_content.dart';

/// Экран «Добавить снаряжение»
class AddingEquipmentScreen extends StatefulWidget {
  const AddingEquipmentScreen({super.key});

  @override
  State<AddingEquipmentScreen> createState() => _AddingEquipmentScreenState();
}

class _AddingEquipmentScreenState extends State<AddingEquipmentScreen> {
  // motion-токены для табов (локально, чтобы не ловить undefined)
  static const Duration _kTabAnim = Duration(milliseconds: 300);
  static const Curve _kTabCurve = Curves.easeOutCubic;

  /// 0 = Кроссовки, 1 = Велосипед
  int _index = 0;

  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.getSurfaceColor(context),
        centerTitle: true,
        title: const Text(
          'Добавить снаряжение',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.getIconPrimaryColor(context),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.getBorderColor(context),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

            // ── Пилюля как в segmented_pill.dart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SegmentedPill(
                  left: 'Кроссовки',
                  right: 'Велосипед',
                  value: _index,
                  width: 280,
                  height: 40,
                  duration: _kTabAnim,
                  curve: _kTabCurve,
                  haptics: true,
                  onChanged: (v) {
                    if (_index == v) return;
                    setState(() => _index = v);
                    _page.animateToPage(
                      v,
                      duration: _kTabAnim,
                      curve: _kTabCurve,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Горизонтальный свайп между вкладками
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                allowImplicitScrolling: true,
                onPageChanged: (i) {
                  if (_index != i) setState(() => _index = i);
                },
                children: const [
                  // Внутри каждого таба — вертикальный скролл и горизонтальные отступы
                  _TabScroller(child: AddingSneakersContent()),
                  _TabScroller(child: AddingBikeContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Обёртка таба: вертикальный скролл + единые поля (16 слева/справа, 24 снизу)
class _TabScroller extends StatelessWidget {
  final Widget child;
  const _TabScroller({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: child,
      ),
    );
  }
}
