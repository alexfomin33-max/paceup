// lib/screens/tasks_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bar.dart'; // ← глобальная шапка
import '../../../core/widgets/transparent_route.dart'; // ← для прозрачного перехода
import '../../../core/widgets/segmented_pill.dart'; // ← пилюля для вкладок
import '../../../providers/services/auth_provider.dart'; // ← для проверки userId

// контенты по вкладкам
import 'tabs/active_content.dart';
import 'tabs/available_content.dart';
import 'add_tasks_screen.dart';
import '../providers/tasks_provider.dart';

/// Единые размеры для AppBar в iOS-стиле
const double _kAppBarIconSize = 22.0; // сама иконка ~20–22pt
const double _kAppBarTapTarget = 42.0; // кликабельная область 42×42

// ── Константы для анимации переключения вкладок
const _kTabAnim = Duration(milliseconds: 300);
const _kTabCurve = Curves.easeOut;

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int _index = 0; // 0 — «Активные», 1 — «Доступные»
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
    // Получаем ID текущего пользователя
    final userIdAsync = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.twinBg,

      // ── Глобальная шапка
      appBar: PaceAppBar(
        title: 'Задачи',
        backgroundColor: AppColors.twinBg,
        showBack: false, // на этом экране «назад» не нужен
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 56, // одна иконка слева
        // слева — иконка плюса (только для пользователей с id=1, 16, 17)
        leading: userIdAsync.when(
          data: (userId) {
            // Показываем иконку только если userId == 1, 16 или 17
            if (userId == 1 || userId == 16 || userId == 17) {
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _NavIcon(
                  icon: CupertinoIcons.add_circled,
                  onPressed: () async {
                    // ── открываем экран создания задачи с прозрачным переходом
                    final result =
                        await Navigator.of(
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
                      // Переключаемся на вкладку "Доступные"
                      _onSegChanged(1);
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

      body: Column(
        children: [
          // ── Пилюля под AppBar + контент вкладок со свайпом
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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
                showBorder: true,
                borderColor: AppColors.twinchip,
                borderWidth: 0.7,
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

          // ── Контент с PageView
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
                ActiveContent(
                  key: PageStorageKey('tasks_active'),
                ),
                AvailableContent(
                  key: PageStorageKey('tasks_available'),
                ),
              ],
            ),
          ),
        ],
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
        icon: Icon(icon, size: _kAppBarIconSize, color: AppColors.textPrimary),
        splashRadius: 22,
      ),
    );
  }
}
