// lib/screens/tasks_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: 0,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
        showBack: false, // на этом экране «назад» не нужен
        showBottomDivider: false,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          // ── Вкладки: TabBar в стиле communication_screen
          Container(
            color: AppColors.getSurfaceColor(context),
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.getTextSecondaryColor(context),
              indicator: const BoxDecoration(),
              dividerColor: AppColors.getBorderColor(context),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: const [
                Tab(text: 'Активные'),
                Tab(text: 'Доступные'),
              ],
            ),
          ),

          // Контент с TabBarView
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const BouncingScrollPhysics(),
              children: const [
                _KeepAliveWrapper(
                  child: ActiveContent(key: ValueKey('tasks_active')),
                ),
                _KeepAliveWrapper(
                  child: AvailableContent(key: ValueKey('tasks_available')),
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
//                 Мелкие утилиты UI: иконка и обёртки
// ————————————————————————————————————————————————————————————————

/// Обёртка для сохранения состояния вкладок в TabBarView
class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});

  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

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
        icon: Icon(icon, size: _kAppBarIconSize, color: AppColors.brandPrimary),
        splashRadius: 22,
      ),
    );
  }
}
