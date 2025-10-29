// lib/screens/lenta/activity/together/together_screen.dart
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

// 🔹 глобальные виджеты
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/segmented_pill.dart';

// вкладки
import 'tabs/members/member_content.dart';
import 'tabs/adding/adding_content.dart';

class TogetherScreen extends StatefulWidget {
  const TogetherScreen({super.key});

  @override
  State<TogetherScreen> createState() => _TogetherScreenState();
}

class _TogetherScreenState extends State<TogetherScreen> {
  int _index = 0; // 0 — Участники, 1 — Добавить
  late final PageController _page = PageController(initialPage: _index);

  // такие же значения анимации, как на других экранах
  static const _kTabAnim = Duration(milliseconds: 300);
  static const Curve _kTabCurve = Curves.easeOutCubic;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,

      appBar: const PaceAppBar(
        title: 'Совместная тренировка',
        showBottomDivider: false,
      ),

      // верх: пилюля; низ: PageView со свайпами
      body: Column(
        children: [
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SegmentedPill(
                left: 'Участники',
                right: 'Добавить',
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
          const SizedBox(height: 14),

          Expanded(
            child: PageView(
              controller: _page,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              children: const [
                _PageWrapper(
                  key: PageStorageKey('together_members'),
                  child: MemberContent(),
                ),
                _PageWrapper(
                  key: PageStorageKey('together_adding'),
                  child: AddingContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Обёртка, чтобы каждая вкладка имела собственный вертикальный скролл и нижний отступ
class _PageWrapper extends StatelessWidget {
  final Widget child;
  const _PageWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: child), // ← вот его и не хватало
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
