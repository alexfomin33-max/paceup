// lib/features/map/screens/clubs/tabs/lenta_content.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../domain/models/activity_lenta.dart';
import '../../../../lenta/screens/widgets/post/post_card.dart';
import '../../../../lenta/screens/widgets/activity/activity_block.dart';
import '../../../../lenta/screens/widgets/comments_bottom_sheet.dart';
import '../../../../../providers/services/auth_provider.dart';

/// Контент вкладки "Лента" для детальной страницы клуба
/// Отображает активность участников клуба
class ClubLentaContent extends ConsumerStatefulWidget {
  final int clubId;
  final ScrollController scrollController;

  const ClubLentaContent({
    super.key,
    required this.clubId,
    required this.scrollController,
  });

  @override
  ConsumerState<ClubLentaContent> createState() => ClubLentaContentState();
}

class ClubLentaContentState extends ConsumerState<ClubLentaContent> {
  List<Activity> _activities = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 20;
  String? _error;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadActivities();
    // ───── Подписываемся на скролл родительского контроллера ─────
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ClubLentaContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ───── Если контроллер скролла изменился, переназначаем слушатель ─────
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  /// Загружает ID текущего пользователя
  Future<void> _loadCurrentUserId() async {
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
  }

  @override
  void dispose() {
    // ───── Отписываемся от родительского контроллера ─────
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  /// ──────────────────────── Загрузка активностей клуба ────────────────────────
  Future<void> _loadActivities({bool reset = false}) async {
    if (_isLoading) return;

    if (reset) {
      setState(() {
        _activities.clear();
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore && !reset) return;

    try {
      setState(() => _isLoading = true);

      // Получаем user_id текущего пользователя
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      
      if (userId == null) {
        setState(() {
          _error = 'Необходима авторизация';
          _isLoading = false;
        });
        return;
      }

      final api = ref.read(apiServiceProvider);
      final data = await api.get(
        '/get_club_activities.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

      if (data['success'] == true && mounted) {
        final activitiesRaw = data['activities'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;

        // Преобразуем Map в объекты Activity
        final activities = activitiesRaw
            .map((item) {
              try {
                return Activity.fromApi(item as Map<String, dynamic>);
              } catch (e) {
                // Игнорируем некорректные записи
                return null;
              }
            })
            .whereType<Activity>()
            .toList();

        setState(() {
          if (reset) {
            _activities = activities;
          } else {
            _activities.addAll(activities);
          }
          _currentPage++;
          _hasMore = hasMore;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] as String? ?? 'Ошибка загрузки ленты';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHandler.formatWithContext(
            e,
            context: 'загрузке ленты клуба',
          );
          _isLoading = false;
        });
      }
    }
  }

  /// ──────────────────────── Обработка скролла для пагинации ────────────────────────
  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    if (widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadActivities();
    }
  }

  /// ──────────────────────── Обновление ленты ────────────────────────
  Future<void> refreshLenta() => _loadActivities(reset: true);

  @override
  Widget build(BuildContext context) {
    if (_error != null && _activities.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 48,
                  color: AppColors.getIconSecondaryColor(context),
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadActivities(reset: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    foregroundColor: AppColors.getSurfaceColor(context),
                  ),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ───── Белый блок-плейсхолдер высотой 400 с индикатором загрузки ─────
    if (_activities.isEmpty && _isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          height: 400,
          color: AppColors.getSurfaceColor(context),
          child: Center(
            child: CupertinoActivityIndicator(
              radius: 12,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ),
      );
    }

    // ───── Белый блок высотой 400, когда лента пуста ─────
    if (_activities.isEmpty && !_isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          height: 400,
          color: AppColors.getSurfaceColor(context),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.news,
                    size: 32,
                    color: AppColors.getTextPlaceholderColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Пока в ленте пусто',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPlaceholderColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Отображаем список постов (скролл управляется родителем)
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= _activities.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CupertinoActivityIndicator(radius: 10),
                ),
              );
            }

            final activity = _activities[index];

            if (_currentUserId == null) {
              return const SizedBox.shrink();
            }

            // Отображаем пост или активность в зависимости от типа
            if (activity.type == 'post') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PostCard(
                  post: activity,
                  currentUserId: _currentUserId!,
                  onEdit: () {
                    // TODO: Реализовать редактирование поста
                  },
                  onDelete: () {
                    // Удаляем пост из списка после успешного удаления
                    setState(() {
                      _activities.removeAt(index);
                    });
                  },
                  onOpenComments: () {
                    // Открываем bottom sheet с комментариями к посту
                    showCommentsBottomSheet(
                      context: context,
                      itemType: 'post',
                      itemId: activity.id,
                      currentUserId: _currentUserId!,
                      lentaId: activity.lentaId,
                      onCommentAdded: () {
                        setState(() {
                          final idx = _activities
                              .indexWhere((a) => a.lentaId == activity.lentaId);
                          if (idx >= 0) {
                            _activities[idx] = _activities[idx]
                                .copyWithComments(
                                    _activities[idx].comments + 1);
                          }
                        });
                      },
                      onCommentDeleted: () {
                        setState(() {
                          final idx = _activities
                              .indexWhere((a) => a.lentaId == activity.lentaId);
                          if (idx >= 0) {
                            final newCount = (_activities[idx].comments - 1)
                                .clamp(0, 0x7FFFFFFF);
                            _activities[idx] = _activities[idx]
                                .copyWithComments(newCount);
                          }
                        });
                      },
                    );
                  },
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActivityBlock(
                  activity: activity,
                  currentUserId: _currentUserId!,
                ),
              );
            }
          },
          childCount: _activities.length + (_hasMore ? 1 : 0),
        ),
      ),
    );
  }
}
