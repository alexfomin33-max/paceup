import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../providers/tasks_provider.dart';
import '../edit_tasks_screen.dart';

class Run200kScreen extends ConsumerStatefulWidget {
  final int taskId;

  const Run200kScreen({super.key, required this.taskId});

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
      if (kDebugMode) {
        debugPrint(
          '🔄 Run200kScreen: taskId изменился с ${oldWidget.taskId} на ${widget.taskId}',
        );
      }
      _lastTaskId = widget.taskId;
      _refreshProviders();
    }
  }

  /// Обновление провайдеров для текущего taskId
  void _refreshProviders() {
    if (!mounted) return;
    final taskId = widget.taskId;
    if (kDebugMode) {
      debugPrint('🔄 Run200kScreen: обновление провайдеров для taskId=$taskId');
    }
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

  /// Обработка действия принятия/отмены задачи
  /// Полностью полагается на данные из API через провайдеры
  Future<void> _handleTaskAction() async {
    if (_isLoading || _currentUserId == null) return;

    final taskId = widget.taskId;
    if (kDebugMode) {
      debugPrint(
        '🎯 Run200kScreen: обработка действия для taskId=$taskId, userId=$_currentUserId',
      );
    }

    // Получаем актуальное состояние из провайдера
    final participantsData = await ref.read(
      taskParticipantsProvider(taskId).future,
    );
    final wasParticipating = participantsData.isCurrentUserParticipating;
    if (kDebugMode) {
      debugPrint(
        '📊 Run200kScreen: текущее состояние участия=$wasParticipating для taskId=$taskId',
      );
    }

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final action = wasParticipating ? 'cancel' : 'start';
      if (kDebugMode) {
        debugPrint(
          '📤 Run200kScreen: отправка запроса task_action.php с taskId=$taskId, action=$action',
        );
      }

      // Выполняем действие на сервере
      final response = await api.post(
        '/task_action.php',
        body: {'task_id': taskId, 'action': action},
      );

      if (kDebugMode) {
        debugPrint('✅ Run200kScreen: ответ от task_action.php: $response');
      }

      // Инвалидируем провайдеры для получения свежих данных из API
      ref.invalidate(taskParticipantsProvider(taskId));
      ref.invalidate(taskDetailProvider(taskId));
      
      // Инвалидируем провайдеры списков задач, чтобы экраны active_content и available_content обновились при возврате
      ref.invalidate(userTasksProvider);
      ref.invalidate(tasksProvider);

      // Ждем обновления данных из API
      // Это гарантирует, что UI отобразит актуальное состояние из базы данных
      final updatedData = await ref.read(
        taskParticipantsProvider(taskId).future,
      );
      if (kDebugMode) {
        debugPrint(
          '🔄 Run200kScreen: обновленные данные участников для taskId=$taskId: isParticipating=${updatedData.isCurrentUserParticipating}, participantsCount=${updatedData.participants.length}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ Run200kScreen: ошибка при обработке действия для taskId=$taskId: $e',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${e.toString()}')));
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
      if (kDebugMode) {
        debugPrint(
          '🔄 Run200kScreen.build: taskId изменился с $_lastTaskId на $taskId',
        );
      }
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
    if (kDebugMode) {
      participantsAsync.whenData((data) {
        debugPrint(
          '📊 Run200kScreen.build: taskId=$taskId, isParticipating=${data.isCurrentUserParticipating}, participantsCount=${data.participants.length}',
        );
      });
    }

    // Получаем актуальное состояние участия из провайдера
    // Провайдер - единственный источник правды, данные загружаются из API
    // Используем when вместо maybeWhen, чтобы правильно обработать состояние loading
    final currentIsParticipating = participantsAsync.when(
      data: (data) => data.isCurrentUserParticipating,
      loading: () => null, // null означает, что данные еще загружаются
      error: (_, __) => false, // При ошибке считаем, что не участвует
    );

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: CustomScrollView(
          slivers: [
            // ─────────── Фоновая картинка + кнопка "назад" + логотип
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) => Container(
                  color: AppColors.getSurfaceColor(
                    context,
                  ), // Цвет полоски для нижней половины логотипа
                  padding: const EdgeInsets.only(
                    bottom: 46,
                  ), // Место для нижней половины логотипа с обводкой
                  child: Stack(
                    clipBehavior: Clip
                        .none, // Разрешаем отображение элементов за пределами Stack
                    children: [
                      // Фоновая картинка из базы данных
                      Builder(
                        builder: (context) {
                          final taskAsyncValue =
                              ref.watch(taskDetailProvider(widget.taskId));
                          return taskAsyncValue.when(
                            data: (task) => _BackgroundImage(
                              imageUrl: task?.imageUrl,
                            ),
                            loading: () => const _BackgroundImage(),
                            error: (_, _) => const _BackgroundImage(),
                          );
                        },
                      ),
                      // Верхние кнопки "назад" и "редактировать"
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Builder(
                            builder: (context) {
                              final taskAsyncValue =
                                  ref.watch(taskDetailProvider(widget.taskId));
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _CircleIconBtn(
                                    icon: CupertinoIcons.back,
                                    semantic: 'Назад',
                                    onTap: () => Navigator.of(context).pop(),
                                  ),
                                  taskAsyncValue.when(
                                    data: (task) {
                                      // Показываем кнопку редактирования только если задача существует и user_id = 1
                                      if (task == null || _currentUserId != 1) {
                                        return const SizedBox(
                                          width: 34,
                                          height: 34,
                                        );
                                      }
                                      return _CircleIconBtn(
                                        icon: CupertinoIcons.pencil,
                                        semantic: 'Редактировать',
                                        onTap: () async {
                                          final result = await Navigator.of(
                                            context,
                                          ).push<String>(
                                            MaterialPageRoute(
                                              builder: (_) => EditTaskScreen(
                                                taskId: widget.taskId,
                                              ),
                                            ),
                                          );
                                          // Если задача была обновлена, обновляем провайдеры
                                          if (result == 'updated' && mounted) {
                                            _refreshProviders();
                                          }
                                          // Если задача была удалена, закрываем экран
                                          if (result == 'deleted' && mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                      );
                                    },
                                    loading: () => const SizedBox(
                                      width: 34,
                                      height: 34,
                                    ),
                                    error: (_, _) => const SizedBox(
                                      width: 34,
                                      height: 34,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      // Логотип из базы данных наполовину на фоне (позиционирован внизу фона)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom:
                            -46, // Половина логотипа с обводкой (92/2 = 46) выходит за границу фона
                        child: Center(
                          child: Builder(
                            builder: (context) {
                              final taskAsyncValue =
                                  ref.watch(taskDetailProvider(widget.taskId));
                              return Container(
                                width:
                                    92, // 90 + 1*2 (логотип + обводка с двух сторон)
                                height: 92,
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceColor(context),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(
                                  1,
                                ), // Толщина обводки
                                child: ClipOval(
                                  child: taskAsyncValue.when(
                                    data: (task) => _HeaderLogo(
                                      logoUrl: task?.logoUrl,
                                    ),
                                    loading: () => const _HeaderLogo(),
                                    error: (_, _) => const _HeaderLogo(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        // добавили +46 сверху, чтобы нижняя половина логотипа не перекрывала текст
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          children: [
                            Text(
                              task.name,
                              style: AppTextStyles.h17w6.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              task.fullDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.getTextPrimaryColor(context),
                                height: 1.5,
                              ),
                            ),
                            if (task.targetValue != null) ...[
                              const SizedBox(height: 16),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CupertinoActivityIndicator(radius: 10)),
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

            // ─────────── Кнопка "Начать"
            // Показываем кнопку только если пользователь еще не участвует
            // Не показываем кнопку, пока данные загружаются (currentIsParticipating == null)
            if (currentIsParticipating != null && !currentIsParticipating)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Center(
                    child: SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleTaskAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CupertinoActivityIndicator(
                                  radius: 10,
                                  color: AppColors.surface,
                                ),
                              )
                            : const Text(
                                'Начать',
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
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
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
                                  fontSize: 14,
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
                                  : '${participant.name} ${participant.surname}'
                                        .trim(),
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
                        child: Center(child: CupertinoActivityIndicator(radius: 10)),
                      ),
                      error: (error, stackTrace) {
                        if (kDebugMode) {
                          debugPrint(
                            '❌ Run200kScreen: ошибка загрузки участников: $error',
                          );
                          debugPrint('❌ Run200kScreen: stackTrace: $stackTrace');
                        }

                        // Проверяем, не является ли это ошибкой "HTML вместо JSON"
                        final errorMessage = error.toString();
                        final isServerError =
                            errorMessage.contains('HTML вместо JSON') ||
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

/// Фоновая картинка из базы данных (соотношение сторон 2.1:1)
class _BackgroundImage extends StatelessWidget {
  final String? imageUrl;

  const _BackgroundImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final calculatedHeight =
        screenW / 2.1; // Вычисляем высоту по соотношению 2.1:1

    // Если есть URL из базы данных, используем его с fade-анимацией
    if ((imageUrl?.isNotEmpty ?? false)) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: double.infinity,
        height: calculatedHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: double.infinity,
          height: calculatedHeight,
          color: AppColors.getBackgroundColor(context),
          child: Center(
            child: CupertinoActivityIndicator(
              radius: 10,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          height: calculatedHeight,
          color: AppColors.getBackgroundColor(context),
          child: Icon(
            CupertinoIcons.photo,
            size: 48,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      );
    }

    // Если URL еще не загружен, показываем placeholder без статичной картинки
    return Container(
      width: double.infinity,
      height: calculatedHeight,
      color: AppColors.getBackgroundColor(context),
      child: Center(
        child: CupertinoActivityIndicator(
          radius: 10,
          color: AppColors.getIconSecondaryColor(context),
        ),
      ),
    );
  }
}

/// Круглый логотип из базы данных 90×90 с обводкой
class _HeaderLogo extends StatelessWidget {
  final String? logoUrl;

  const _HeaderLogo({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    // Если есть URL из базы данных, используем его с fade-анимацией
    if ((logoUrl?.isNotEmpty ?? false)) {
      return CachedNetworkImage(
        imageUrl: logoUrl!,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 90,
          height: 90,
          color: AppColors.getBackgroundColor(context),
          child: Center(
            child: CupertinoActivityIndicator(
              radius: 10,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 90,
          height: 90,
          color: AppColors.getBackgroundColor(context),
          child: Icon(
            CupertinoIcons.photo,
            size: 32,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      );
    }

    // Если URL еще не загружен, показываем placeholder без статичной картинки
    return Container(
      width: 90,
      height: 90,
      color: AppColors.getBackgroundColor(context),
      child: Center(
        child: CupertinoActivityIndicator(
          radius: 10,
          color: AppColors.getIconSecondaryColor(context),
        ),
      ),
    );
  }
}

/// Полупрозрачная круглая кнопка-иконка
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final String? semantic;
  final VoidCallback onTap;
  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    // В светлой теме иконки светлые (белые), в темной — как обычно
    final brightness = Theme.of(context).brightness;
    final iconColor = brightness == Brightness.light
        ? Colors.white
        : AppColors.getIconPrimaryColor(context);

    // В темной теме увеличиваем непрозрачность кружочка
    final backgroundColor = brightness == Brightness.dark
        ? AppColors.scrim60
        : AppColors.scrim40;

    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final double percent;
  const _MiniProgress({required this.percent});

  /// ── Определяет цвет индикатора прогресса в зависимости от процента выполнения
  /// 0-25%: красный (error)
  /// 25-99%: желтый (yellow)
  /// 100%: зеленый (success)
  Color _getProgressColor(double percent) {
    if (percent >= 1.0) {
      return AppColors.success; // 100% - зеленый
    } else if (percent >= 0.25) {
      return AppColors.yellow; // 25-99% - желтый
    } else {
      return AppColors.error; // 0-25% - красный
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final clampedPercent = percent.clamp(0.0, 1.0).toDouble();
        final w = clampedPercent * c.maxWidth;
        final isFull = clampedPercent >= 1.0;
        return Row(
          children: [
            Container(
              width: w,
              height: 4,
              decoration: BoxDecoration(
                color: _getProgressColor(clampedPercent),
                borderRadius: isFull
                    ? BorderRadius.circular(AppRadius.xs)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.xs),
                        bottomLeft: Radius.circular(AppRadius.xs),
                        topRight: Radius.circular(AppRadius.xs),
                        bottomRight: Radius.circular(AppRadius.xs),
                      ),
              ),
            ),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getBorderColor(context),
                  borderRadius: isFull
                      ? BorderRadius.zero
                      : const BorderRadius.only(
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: highlight
                    ? AppColors.success
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
                color: AppColors.getBackgroundColor(context),
                child: Center(
                  child: CupertinoActivityIndicator(
                    radius: 8,
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 32,
                height: 32,
                color: AppColors.getBackgroundColor(context),
                child: Icon(
                  CupertinoIcons.person_fill,
                  size: 20,
                  color: AppColors.getIconSecondaryColor(context),
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
                fontSize: 14,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: highlight
                  ? AppColors.success
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
