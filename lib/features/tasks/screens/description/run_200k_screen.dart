import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../providers/tasks_provider.dart';

class Run200kScreen extends ConsumerStatefulWidget {
  final int taskId;

  const Run200kScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<Run200kScreen> createState() => _Run200kScreenState();
}

class _Run200kScreenState extends ConsumerState<Run200kScreen> {
  bool _isLoading = false;
  int? _currentUserId;
  int? _lastTaskId; // Отслеживаем последний taskId для обновления провайдеров

  @override
  void initState() {
    super.initState();
    _lastTaskId = widget.taskId;
    _loadCurrentUserId();
    // Принудительно обновляем данные при открытии экрана
    // Используем Future.microtask для выполнения после инициализации виджета
    Future.microtask(() {
      if (mounted) {
        _refreshProviders();
      }
    });
  }

  /// Обновление провайдеров при изменении taskId
  @override
  void didUpdateWidget(Run200kScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если taskId изменился, обновляем провайдеры
    if (oldWidget.taskId != widget.taskId) {
      debugPrint('🔄 Run200kScreen: taskId изменился с ${oldWidget.taskId} на ${widget.taskId}');
      _lastTaskId = widget.taskId;
      _refreshProviders();
    }
  }

  /// Обновление провайдеров для текущего taskId
  void _refreshProviders() {
    if (!mounted) return;
    final taskId = widget.taskId;
    debugPrint('🔄 Run200kScreen: обновление провайдеров для taskId=$taskId');
    // Инвалидируем провайдер для получения свежих данных с сервера
    ref.invalidate(taskParticipantsProvider(taskId));
    ref.invalidate(taskDetailProvider(taskId));
  }

  /// Загрузка ID текущего пользователя из AuthService
  Future<void> _loadCurrentUserId() async {
    final authService = AuthService();
    final userId = await authService.getUserId();
    if (mounted) {
      setState(() => _currentUserId = userId);
    }
  }

  IconData _getTaskIcon(String? taskType) {
    switch (taskType) {
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
        return Icons.flag;
    }
  }

  /// Обработка действия принятия/отмены задачи
  /// Полностью полагается на данные из API через провайдеры
  Future<void> _handleTaskAction() async {
    if (_isLoading || _currentUserId == null) return;

    final taskId = widget.taskId;
    debugPrint('🎯 Run200kScreen: обработка действия для taskId=$taskId, userId=$_currentUserId');

    // Получаем актуальное состояние из провайдера
    final participantsData = await ref.read(taskParticipantsProvider(taskId).future);
    final wasParticipating = participantsData.isCurrentUserParticipating;
    debugPrint('📊 Run200kScreen: текущее состояние участия=$wasParticipating для taskId=$taskId');

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final action = wasParticipating ? 'cancel' : 'start';
      debugPrint('📤 Run200kScreen: отправка запроса task_action.php с taskId=$taskId, action=$action');

      // Выполняем действие на сервере
      final response = await api.post(
        '/task_action.php',
        body: {
          'task_id': taskId,
          'action': action,
        },
      );

      debugPrint('✅ Run200kScreen: ответ от task_action.php: $response');

      // Инвалидируем провайдер для получения свежих данных из API
      ref.invalidate(taskParticipantsProvider(taskId));
      
      // Ждем обновления данных из API
      // Это гарантирует, что UI отобразит актуальное состояние из базы данных
      final updatedData = await ref.read(taskParticipantsProvider(taskId).future);
      debugPrint('🔄 Run200kScreen: обновленные данные участников для taskId=$taskId: isParticipating=${updatedData.isCurrentUserParticipating}, participantsCount=${updatedData.participants.length}');
    } catch (e) {
      debugPrint('❌ Run200kScreen: ошибка при обработке действия для taskId=$taskId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.taskId;
    
    // Логируем, если taskId изменился
    if (_lastTaskId != null && _lastTaskId != taskId) {
      debugPrint('🔄 Run200kScreen.build: taskId изменился с $_lastTaskId на $taskId');
      _lastTaskId = taskId;
      // Обновляем провайдеры при изменении taskId
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshProviders();
        }
      });
    }

    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final participantsAsync = ref.watch(taskParticipantsProvider(taskId));

    // Логируем состояние провайдеров для отладки
    participantsAsync.whenData((data) {
      debugPrint('📊 Run200kScreen.build: taskId=$taskId, isParticipating=${data.isCurrentUserParticipating}, participantsCount=${data.participants.length}');
    });

    // Получаем актуальное состояние участия из провайдера
    // Провайдер - единственный источник правды, данные загружаются из API
    final currentIsParticipating = participantsAsync.maybeWhen(
      data: (data) => data.isCurrentUserParticipating,
      orElse: () => false, // По умолчанию не участвует, если данные еще загружаются
    );

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: CustomScrollView(
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
                  padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
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
              flexibleSpace: taskAsync.when(
                data: (task) {
                  if (task?.imageUrl != null && task!.imageUrl!.isNotEmpty) {
                    return FlexibleSpaceBar(
                      background: CachedNetworkImage(
                        imageUrl: task.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.skeletonBase,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.skeletonBase,
                        ),
                      ),
                    );
                  }
                  return const FlexibleSpaceBar(
                    background: ColoredBox(color: AppColors.skeletonBase),
                  );
                },
                loading: () => const FlexibleSpaceBar(
                  background: ColoredBox(color: AppColors.skeletonBase),
                ),
                error: (_, __) => const FlexibleSpaceBar(
                  background: ColoredBox(color: AppColors.skeletonBase),
                ),
              ),
            ),

            // ─────────── Круглая иконка наполовину на фото, наполовину на белом блоке
            taskAsync.when(
              data: (task) {
                if (task == null) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_circle,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Задача не найдена',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverToBoxAdapter(
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
                              color: Theme.of(context).brightness == Brightness.dark
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
                              task.fullDescription.isNotEmpty
                                  ? task.fullDescription
                                  : task.shortDescription,
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
                                    percent: task.progressPercent ?? 0.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  task.formattedProgress,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: AppColors.getTextSecondaryColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Сам круг: центр ровно на границе фото/белого блока
                      Positioned(
                        top: -36, // 72/2 со знаком минус — половина на фото, половина на белом фоне
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.getSurfaceColor(context),
                                width: 2,
                              ), // белая рамка 2px
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkShadowSoft
                                      : AppColors.shadowSoft,
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _getTaskIcon(task.type),
                                size: 34,
                                color: AppColors.getSurfaceColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ─────────── Кнопка "Начать" / "Отменить"
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Center(
                  child: SizedBox(
                    width: 280,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleTaskAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentIsParticipating
                            ? AppColors.error
                            : AppColors.accentMint,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.surface,
                                ),
                              ),
                            )
                          : Text(
                              currentIsParticipating ? 'Отменить' : 'Начать',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.surface,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // ─────────── Контент
            SliverToBoxAdapter(
              child: Column(
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
                    child: participantsAsync.when(
                      data: (data) {
                        // Используем данные из провайдера - они загружаются из API
                        // После выполнения действия провайдер автоматически обновляется
                        final participants = data.participants;

                        if (participants.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                'Пока нет участников',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }

                        // Отображаем список участников из API
                        // Если пользователь принял задачу, он автоматически появится в списке
                        return Column(
                          children: List.generate(participants.length, (i) {
                            final participant = participants[i];
                            final isMe = participant.userId == _currentUserId;
                            return _FriendRow(
                              rank: i + 1,
                              name: participant.fullName.isNotEmpty
                                  ? participant.fullName
                                  : '${participant.name} ${participant.surname}'.trim(),
                              value: participant.valueText,
                              avatar: participant.avatar,
                              highlight: isMe,
                              isLast: i == participants.length - 1,
                            );
                          }),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) {
                        debugPrint('❌ Run200kScreen: ошибка загрузки участников: $error');
                        debugPrint('❌ Run200kScreen: stackTrace: $stackTrace');
                        
                        // Проверяем, не является ли это ошибкой "HTML вместо JSON"
                        final errorMessage = error.toString();
                        final isServerError = errorMessage.contains('HTML вместо JSON') ||
                            errorMessage.contains('Сервер вернул HTML');
                        
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_triangle,
                                  size: 32,
                                  color: AppColors.error,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isServerError
                                      ? 'Ошибка на сервере'
                                      : 'Ошибка загрузки участников',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.error,
                                  ),
                                ),
                                if (isServerError) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Попробуйте обновить страницу',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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

class _FriendRow extends StatelessWidget {
  final int rank;
  final String name;
  final String value;
  final String avatar;
  final bool highlight;
  final bool isLast;

  const _FriendRow({
    required this.rank,
    required this.name,
    required this.value,
    required this.avatar,
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
              imageUrl: avatar,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 32,
                height: 32,
                color: AppColors.skeletonBase,
              ),
              errorWidget: (context, url, error) => Container(
                width: 32,
                height: 32,
                color: AppColors.skeletonBase,
                child: const Icon(
                  CupertinoIcons.person_fill,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
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
