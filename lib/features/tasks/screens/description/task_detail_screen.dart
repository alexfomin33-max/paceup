import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../providers/tasks_provider.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  int _segment = 0; // 0 — Все, 1 — Друзья

  /// Получает иконку для типа задачи
  IconData _getIconForTaskType(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run;
      case 'bike':
        return Icons.directions_bike;
      case 'swim':
        return Icons.pool;
      case 'walk':
        return Icons.directions_walk;
      case 'general':
      default:
        return Icons.fitness_center;
    }
  }

  /// Получает цвет для типа задачи
  Color _getColorForTaskType(String type) {
    switch (type) {
      case 'run':
        return AppColors.accentMint;
      case 'bike':
        return AppColors.brandPrimary;
      case 'swim':
        return Colors.blue;
      case 'walk':
        return Colors.green;
      case 'general':
      default:
        return AppColors.gold;
    }
  }

  /// Форматирует прогресс для отображения
  String _formatProgress(double? current, double? target, String unitLabel) {
    if (current == null || target == null || target == 0) {
      final targetStr = target != null
          ? target.toStringAsFixed(target % 1 == 0 ? 0 : 1)
          : '0';
      return '0 из $targetStr $unitLabel';
    }
    final currentFormatted = current.toStringAsFixed(current % 1 == 0 ? 0 : 1);
    final targetFormatted = target.toStringAsFixed(target % 1 == 0 ? 0 : 1);
    return '$currentFormatted из $targetFormatted $unitLabel';
  }

  /// Обработка нажатия на кнопку "Начать"/"Отменить"
  Future<void> _handleTaskAction(bool isParticipating) async {
    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Необходима авторизация')),
          );
        }
        return;
      }

      final action = isParticipating ? 'cancel' : 'start';
      final response = await api.post(
        '/task_action.php',
        body: {'task_id': widget.taskId, 'action': action, 'user_id': userId},
      );

      // Выводим логи в консоль для отладки
      if (response['debug_logs'] != null) {
        final logs = response['debug_logs'] as List? ?? [];
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('TASK ACTION DEBUG LOGS:');
        debugPrint('═══════════════════════════════════════════════════════');
        for (final log in logs) {
          debugPrint('  $log');
        }
        debugPrint(
          'Updated tasks count: ${response['updated_tasks_count'] ?? 0}',
        );
        debugPrint('═══════════════════════════════════════════════════════');
      }

      // Обновляем провайдеры - инвалидируем для принудительного обновления
      ref.invalidate(taskParticipantsProvider(widget.taskId));
      ref.invalidate(taskParticipationProvider(widget.taskId));
      // Обновляем детали задачи, чтобы получить актуальный прогресс
      ref.invalidate(taskDetailProvider(widget.taskId));
      // Обновляем списки задач для динамического отображения
      ref.invalidate(tasksProvider);
      ref.invalidate(userTasksProvider);

      // Принудительно перестраиваем виджет после обновления провайдеров
      if (mounted) {
        // Небольшая задержка, чтобы дать время провайдерам обновиться
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final participantsAsync = ref.watch(
      taskParticipantsProvider(widget.taskId),
    );

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: taskAsync.when(
          data: (task) {
            if (task == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Задача не найдена',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                ),
              );
            }

            final taskColor = _getColorForTaskType(task.type);
            final taskIcon = _getIconForTaskType(task.type);
            final progressPercent = task.progressPercent ?? 0.0;

            // Получаем статус участия текущего пользователя
            final isParticipating =
                participantsAsync.value?.isCurrentUserParticipating ?? false;

            return CustomScrollView(
              slivers: [
                // ─────────── Верхнее фото + кнопка "назад"
                SliverAppBar(
                  pinned: false,
                  floating: false,
                  expandedHeight: 140,
                  elevation: 0,
                  backgroundColor: AppColors.getSurfaceColor(context),
                  leadingWidth: 60,
                  leading: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 10,
                        top: 6,
                        bottom: 6,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.scrim40,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.back,
                              color: AppColors.surface,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background:
                        task.imageUrl != null && task.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: task.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.getBorderColor(context),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.getBorderColor(context),
                              child: Icon(taskIcon, size: 48, color: taskColor),
                            ),
                          )
                        : Container(
                            color: AppColors.getBorderColor(context),
                            child: Center(
                              child: Icon(taskIcon, size: 48, color: taskColor),
                            ),
                          ),
                  ),
                ),

                // ─────────── Круглая иконка наполовину на фото, наполовину на белом блоке
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Белый блок с заголовком, подписью и узким прогресс-баром
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context),
                          boxShadow: [
                            // тонкая тень вниз ~1px
                            BoxShadow(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkShadowSoft
                                  : AppColors.shadowSoft,
                              offset: const Offset(0, 1),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        // добавили +36 сверху, чтобы нижняя половина круга не перекрывала текст
                        padding: const EdgeInsets.fromLTRB(16, 16 + 36, 16, 16),
                        child: Column(
                          children: [
                            Text(
                              task.name,
                              style: AppTextStyles.h17w6.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              task.shortDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.getTextSecondaryColor(context),
                                height: 1.25,
                              ),
                            ),
                            if (task.targetValue != null) ...[
                              const SizedBox(height: 12),
                              // узкий прогресс-бар по центру
                              Center(
                                child: SizedBox(
                                  width: 240,
                                  child: _MiniProgress(
                                    percent: progressPercent.clamp(0.0, 1.0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatProgress(
                                  task.currentValue,
                                  task.targetValue,
                                  task.unitLabel,
                                ),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppColors.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Кнопка "Начать" / "Отменить"
                              Center(
                                child: InkWell(
                                  onTap: () =>
                                      _handleTaskAction(isParticipating),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isParticipating
                                          ? AppColors.getBorderColor(context)
                                          : taskColor,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                    ),
                                    child: Text(
                                      isParticipating ? 'Отменить' : 'Начать',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isParticipating
                                            ? AppColors.getTextPrimaryColor(
                                                context,
                                              )
                                            : AppColors.getSurfaceColor(
                                                context,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Сам круг: центр ровно на границе фото/белого блока
                      Positioned(
                        top:
                            -36, // 72/2 со знаком минус — половина на фото, половина на белом фоне
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: taskColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.getSurfaceColor(context),
                                width: 2,
                              ), // белая рамка 2px
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkShadowSoft
                                      : AppColors.shadowSoft,
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                taskIcon,
                                size: 34,
                                color: AppColors.getSurfaceColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─────────── Сегменты на сером фоне (вынесены из белого блока)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Center(
                      child: _SegmentedPill(
                        left: 'Все',
                        right: 'Друзья',
                        value: _segment,
                        onChanged: (v) => setState(() => _segment = v),
                      ),
                    ),
                  ),
                ),

                // ─────────── Полное описание задачи
                if (task.fullDescription.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Описание'),
                          const SizedBox(height: 8),
                          Text(
                            task.fullDescription,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: AppColors.getTextPrimaryColor(context),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─────────── Контент (прогресс друзей)
                SliverToBoxAdapter(
                  child: participantsAsync.when(
                    data: (participantsData) {
                      final participants = participantsData.participants;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                            child: _SectionTitle('Прогресс друзей'),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.getBorderColor(context),
                                  width: 0.5,
                                ),
                                bottom: BorderSide(
                                  color: AppColors.getBorderColor(context),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: participants.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                      child: Text(
                                        'Пока нет участников',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          color: AppColors.darkTextSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Builder(
                                    builder: (context) {
                                      // Получаем текущего пользователя из провайдера
                                      final currentUserIdAsync = ref.watch(
                                        currentUserIdProvider,
                                      );

                                      return currentUserIdAsync.when(
                                        data: (currentUserId) {
                                          return Column(
                                            children: List.generate(
                                              participants.length,
                                              (i) {
                                                final participant =
                                                    participants[i];

                                                // Определяем, является ли это текущим пользователем
                                                final isCurrentUser =
                                                    currentUserId != null &&
                                                    participant.userId ==
                                                        currentUserId;

                                                return _ParticipantRow(
                                                  rank: i + 1,
                                                  name: participant.fullName,
                                                  value: participant.valueText,
                                                  avatarUrl: participant.avatar,
                                                  highlight: isCurrentUser,
                                                  isLast:
                                                      i ==
                                                      participants.length - 1,
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        loading: () => const SizedBox.shrink(),
                                        error: (_, __) => Column(
                                          children: List.generate(
                                            participants.length,
                                            (i) {
                                              final participant =
                                                  participants[i];
                                              return _ParticipantRow(
                                                rank: i + 1,
                                                name: participant.fullName,
                                                value: participant.valueText,
                                                avatarUrl: participant.avatar,
                                                highlight: false,
                                                isLast:
                                                    i ==
                                                    participants.length - 1,
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: _SectionTitle('Прогресс друзей'),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceColor(context),
                            border: Border(
                              top: BorderSide(
                                color: AppColors.getBorderColor(context),
                                width: 0.5,
                              ),
                              bottom: BorderSide(
                                color: AppColors.getBorderColor(context),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ],
                    ),
                    error: (error, stack) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
                          child: _SectionTitle('Прогресс друзей'),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceColor(context),
                            border: Border(
                              top: BorderSide(
                                color: AppColors.getBorderColor(context),
                                width: 0.5,
                              ),
                              bottom: BorderSide(
                                color: AppColors.getBorderColor(context),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Ошибка загрузки участников',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Ошибка загрузки задачи: ${error.toString()}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───── Вспомогательные виджеты

class _MiniProgress extends StatelessWidget {
  final double percent;
  const _MiniProgress({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (percent.clamp(0.0, 1.0)) * c.maxWidth;
        return Row(
          children: [
            Container(
              width: w,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.accentMint,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xs),
                  bottomLeft: Radius.circular(AppRadius.xs),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getBorderColor(context),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppRadius.xs),
                    bottomRight: Radius.circular(AppRadius.xs),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// одинаковая ширина сегментов, плашка фиксированной ширины
class _SegmentedPill extends StatelessWidget {
  final String left;
  final String right;
  final int value;
  final ValueChanged<int> onChanged;
  const _SegmentedPill({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280, // ширина блока сегментов
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _seg(context, 0, left)),
            Expanded(child: _seg(context, 1, right)),
          ],
        ),
      ),
    );
  }

  Widget _seg(BuildContext context, int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.getTextPrimaryColor(context)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? AppColors.getSurfaceColor(context)
                  : AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark
            ? AppColors.getTextSecondaryColor(context)
            : AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final String avatarUrl;
  final bool highlight;
  final bool isLast;

  const _ParticipantRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.avatarUrl,
    required this.highlight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: highlight
                    ? AppColors.accentMint
                    : AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 32,
                height: 32,
                color: AppColors.getBorderColor(context),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 32,
                height: 32,
                color: AppColors.getBorderColor(context),
                child: const Icon(Icons.person, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: highlight
                  ? AppColors.accentMint
                  : AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        row,
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),
      ],
    );
  }
}
