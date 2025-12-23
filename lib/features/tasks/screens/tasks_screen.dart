// lib/screens/tasks_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/segmented_pill.dart';
import '../../../core/widgets/app_bar.dart'; // ← глобальная шапка
import '../../../core/widgets/transparent_route.dart'; // ← для прозрачного перехода
import '../../../providers/services/auth_provider.dart'; // ← для проверки userId

// контенты по вкладкам
import 'tabs/active_content.dart';
import 'tabs/available_content.dart';
import 'add_tasks_screen.dart';
import '../providers/tasks_provider.dart';

/// Единые размеры для AppBar в iOS-стиле
const double _kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double _kAppBarTapTarget = 42.0; // кликабельная область 42×42

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
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
    // Получаем ID текущего пользователя
    final userIdAsync = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),

      // ── Глобальная шапка
      appBar: PaceAppBar(
        title: 'Задачи',
        showBack: false, // на этом экране «назад» не нужен
        leadingWidth: 56, // одна иконка слева
        // слева — иконка плюса (только для пользователя с id=1)
        leading: userIdAsync.when(
          data: (userId) {
            // Показываем иконку только если userId == 1
            if (userId == 1) {
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _NavIcon(
                  icon: CupertinoIcons.add_circled,
                  onPressed: () async {
                    // ── открываем экран создания задачи с прозрачным переходом
                    final result = await Navigator.of(
                      context,
                      rootNavigator: true,
                    ).push<String>(
                      TransparentPageRoute(
                        builder: (_) => const AddTaskScreen(),
                      ),
                    );

                    // ── если задача была успешно создана, можно обновить список
                    if (result == 'created' && mounted) {
                      // Обновляем список задач
                      ref.invalidate(userTasksProvider);
                      ref.invalidate(tasksProvider);
                    }
                  },
                ),
              );
            }
            return null;
          },
          loading: () => null, // Во время загрузки не показываем иконку
          error: (_, _) => null, // При ошибке не показываем иконку
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 14),

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
                  if (_index == i) return; // гард от лишних setState
                  setState(() => _index = i);
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

// ————————————————————————————————————————————————————————————————
//                 Мелкие утилиты UI: иконка
// ————————————————————————————————————————————————————————————————

/// Единый вид для иконок в AppBar — размер 22, tap-target 42×42
class _NavIcon extends StatelessWidget {
  // ignore: unused_element_parameter
  const _NavIcon({super.key, required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kAppBarTapTarget,
      height: _kAppBarTapTarget,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: _kAppBarTapTarget,
          minHeight: _kAppBarTapTarget,
        ),
        icon: Icon(icon, size: _kAppBarIconSize),
        splashRadius: 22,
      ),
    );
  }
}
