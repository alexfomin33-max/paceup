// lib/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/segmented_pill.dart';
import '../../widgets/app_bar.dart'; // ← глобальная шапка

// контенты по вкладкам
import 'tabs/active_content.dart';
import 'tabs/available_content.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const Duration _kTabAnim = Duration(milliseconds: 300);
  static const Curve _kTabCurve = Curves.easeOutCubic;

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
      backgroundColor: AppColors.background,

      // ── Глобальная шапка
      appBar: const PaceAppBar(
        title: 'Задачи',
        showBack: false, // на этом экране «назад» не нужен
        // showBottomDivider: true, // по умолчанию включён
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Пилюля как глобальный виджет
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SegmentedPill(
                  left: 'Активные',
                  right: 'Доступные',
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

            // PageView БЕЗ внешнего padding (жесты по краю работают)
            Expanded(
              child: PageView(
                controller: _page,
                physics: const BouncingScrollPhysics(),
                allowImplicitScrolling: true,
                onPageChanged: (i) {
                  if (_index != i) setState(() => _index = i);
                },
                children: const [
                  ActiveContent(key: PageStorageKey('tasks_active')),
                  AvailableContent(key: PageStorageKey('tasks_available')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
