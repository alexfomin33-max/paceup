import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../core/widgets/more_menu_overlay.dart';
import '../../../../features/complaint.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../features/profile/screens/profile_screen.dart';

// ——— Аккуратный показ SnackBar (чтобы не падать без ScaffoldMessenger) ———
void showSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m != null) {
    m.showSnackBar(SnackBar(content: Text(message)));
  }
}

// ────────────────────────────────────────────────────────────────
// 🔹 Helper-функция для плавного открытия bottom sheet с комментариями
// ────────────────────────────────────────────────────────────────
void showCommentsBottomSheet({
  required BuildContext context,
  required String itemType,
  required int itemId,
  required int currentUserId,
  required int lentaId,
  VoidCallback? onCommentAdded,
  VoidCallback? onCommentDeleted,
}) {
  // ────────────────────────────────────────────────────────────────
  // ✅ ВАЖНО: используем штатный showModalBottomSheet
  // Причина: кастомные Route на некоторых прошивках (например, MIUI)
  // могут провоцировать ANR при открытии модальных окон.
  // ────────────────────────────────────────────────────────────────
  //
  // ────────────────────────────────────────────────────────────────
  // 🎞️ ПЛАВНОСТЬ: увеличиваем длительность анимации открытия/закрытия
  // через transitionAnimationController (без изменения визуала).
  // ────────────────────────────────────────────────────────────────
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  final AnimationController? transitionController = overlay == null
      ? null
      : AnimationController(
          vsync: overlay,
          duration: const Duration(milliseconds: 350),
          reverseDuration: const Duration(milliseconds: 250),
        );

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    transitionAnimationController: transitionController,
    builder: (_) => CommentsBottomSheet(
      itemType: itemType,
      itemId: itemId,
      currentUserId: currentUserId,
      lentaId: lentaId,
      onCommentAdded: onCommentAdded,
      onCommentDeleted: onCommentDeleted,
    ),
  );
}

bool isTruthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'ok' || s == 'success' || s == 'yes';
  }
  return false;
}

/// =====================
/// НАСТРОЙКИ API
/// =====================
class ApiConfig {
  static const String base = 'https://api.paceup.ru/';

  static String get commentsList => '${base}comments_list.php';
  static String get commentsAdd => '${base}comments_add.php';

  /// Размер страницы для пагинации
  static const int pageSize = 20;
}

/// Модель комментария
class CommentItem {
  final int id;
  final int userId; // ID автора комментария
  final String userName;
  final String? userAvatar;
  final String text;
  final String createdAt; // строка с датой от сервера

  CommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.userAvatar,
  });

  factory CommentItem.fromApi(Map<String, dynamic> json) {
    return CommentItem(
      id: int.tryParse('${json['id']}') ?? 0,
      userId: int.tryParse('${json['user_id']}') ?? 0,
      userName: (json['user_name'] ?? '').toString(),
      userAvatar: (json['user_avatar']?.toString().isNotEmpty ?? false)
          ? json['user_avatar'].toString()
          : null,
      text: (json['text'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

/// Нижний лист с комментариями (верстка как в примере)
class CommentsBottomSheet extends ConsumerStatefulWidget {
  final String itemType; // 'post' | 'activity'
  final int itemId;
  final int currentUserId;
  final int lentaId; // ID из таблицы lenta для обновления счетчика
  final VoidCallback?
  onCommentAdded; // Callback после успешного добавления комментария
  final VoidCallback?
  onCommentDeleted; // Callback после успешного удаления комментария

  const CommentsBottomSheet({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.currentUserId,
    required this.lentaId,
    this.onCommentAdded,
    this.onCommentDeleted,
  });

  @override
  ConsumerState<CommentsBottomSheet> createState() =>
      _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends ConsumerState<CommentsBottomSheet> {
  final List<CommentItem> _comments = [];

  // загрузка
  bool _initialLoading = true;
  String? _error;

  final int _composerReset = 0;

  // пагинация
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  bool _pageLoading = false;

  // отправка
  late TextEditingController _textCtrl;
  final FocusNode _composerFocus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(); // ← добавь эту строку
    _loadComments(refresh: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _textCtrl.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_pageLoading || !_hasMore) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadComments();
    }
  }

  Future<void> _loadComments({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _error = null;
      _initialLoading = true;
      setState(() {});
    }
    if (!_hasMore) return;

    setState(() => _pageLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/comments_list.php',
        body: {
          'type': widget.itemType,
          'item_id': '${widget.itemId}', // 🔹 PHP ожидает строки
          'page': '$_page', // 🔹 PHP ожидает строки
          'limit': '${ApiConfig.pageSize}', // 🔹 PHP ожидает строки
          'userId': '${widget.currentUserId}', // 🔹 PHP ожидает строки
        },
      );

      if (!(isTruthy(data['success']) || isTruthy(data['status']))) {
        throw Exception((data['error']) ?? 'Ошибка формата данных');
      }

      final List<CommentItem> list = (data['comments'] as List? ?? [])
          .map((e) => CommentItem.fromApi(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _comments
            ..clear()
            ..addAll(list);
        } else {
          _comments.addAll(list);
        }
        _hasMore = list.length >= ApiConfig.pageSize;
        _page += 1;
        _initialLoading = false;
        _pageLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.format(e);
        _initialLoading = false;
        _pageLoading = false;
      });
    }
  }

  Future<void> _sendComment(String text) async {
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/comments_add.php',
        body: {
          'type': widget.itemType,
          'item_id': '${widget.itemId}', // 🔹 PHP ожидает строки
          'text': text,
          'userId': '${widget.currentUserId}', // 🔹 PHP ожидает строки
        },
      );

      final ok = isTruthy(data['success']) || isTruthy(data['status']);
      if (!ok) {
        throw Exception(
          (data['error'] ?? 'Не удалось отправить комментарий').toString(),
        );
      }

      CommentItem? newItem;
      final c = data['comment'];
      if (c is Map<String, dynamic>) {
        newItem = CommentItem.fromApi(c);
      } else if (c is List && c.isNotEmpty && c.first is Map<String, dynamic>) {
        newItem = CommentItem.fromApi(c.first as Map<String, dynamic>);
      }

      if (!mounted) return;
      if (newItem != null) {
        setState(() => _comments.insert(0, newItem!)); // свежие сверху
      } else {
        await _loadComments(refresh: true);
      }
      _scrollToTop();

      // ────────────────────────────────────────────────────────────────
      // 🔔 ОБНОВЛЕНИЕ СЧЕТЧИКА: вызываем callback после успешного добавления
      // ────────────────────────────────────────────────────────────────
      widget.onCommentAdded?.call();

      // НИЧЕГО не чистим здесь — уже очищено в кнопке
    } catch (e) {
      bool refreshOk = false;
      try {
        await _loadComments(refresh: true);
        _scrollToTop();
        refreshOk = true;
      } catch (_) {}
      if (!refreshOk && mounted) showSnack(context, 'Ошибка отправки: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToTop() {
    // После перерисовки анимируем к началу
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🔹 УДАЛЕНИЕ КОММЕНТАРИЯ: удаляет комментарий и обновляет UI
  /// ────────────────────────────────────────────────────────────────
  Future<void> _deleteComment(CommentItem comment) async {
    if (!mounted) return;
    
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/comments_delete.php',
        body: {
          'comment_id': '${comment.id}',
        },
      );

      // Проверяем успешность операции - используем прямую проверку как в других местах
      if (data['success'] != true) {
        final errorMsg = data['error']?.toString() ?? 
                        data['message']?.toString() ?? 
                        'Не удалось удалить комментарий';
        throw Exception(errorMsg);
      }

      // ────────────────────────────────────────────────────────────────
      // 🔄 Динамическое удаление из списка без перезагрузки
      // ────────────────────────────────────────────────────────────────
      if (!mounted) return;
      
      // Проверяем, что комментарий еще в списке перед удалением
      final commentExists = _comments.any((c) => c.id == comment.id);
      if (commentExists) {
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
        });
      }

      // ────────────────────────────────────────────────────────────────
      // 🔔 ОБНОВЛЕНИЕ СЧЕТЧИКА: вызываем callback после удаления
      // ────────────────────────────────────────────────────────────────
      widget.onCommentDeleted?.call();

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        if (scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Комментарий удален')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
        if (scaffoldMessenger != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: ${ErrorHandler.format(e)}'),
            ),
          );
        }
      }
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🔹 ПОКАЗ МЕНЮ КОММЕНТАРИЯ: показывает меню с действиями
  /// ────────────────────────────────────────────────────────────────
  void _showCommentMenu({
    required BuildContext context,
    required CommentItem comment,
    required GlobalKey menuKey,
  }) {
    final items = <MoreMenuItem>[];
    final isOwnComment = comment.userId == widget.currentUserId;

    if (isOwnComment) {
      // ────────────────────────────────────────────────────────────────
      // 🔹 МЕНЮ ДЛЯ СВОЕГО КОММЕНТАРИЯ: удаление
      // ────────────────────────────────────────────────────────────────
      items.add(
        MoreMenuItem(
          text: 'Удалить',
          icon: CupertinoIcons.minus_circle,
          iconColor: AppColors.error,
          textStyle: const TextStyle(color: AppColors.error),
          onTap: () async {
            // Показываем диалог подтверждения сразу
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Удалить комментарий?'),
                content: const Text('Это действие нельзя отменить.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            );

            // Проверяем результат диалога и что виджет еще смонтирован
            if (confirmed == true && mounted) {
              await _deleteComment(comment);
            }
          },
        ),
      );
    } else {
      // ────────────────────────────────────────────────────────────────
      // 🔹 МЕНЮ ДЛЯ ЧУЖОГО КОММЕНТАРИЯ: пожаловаться
      // ────────────────────────────────────────────────────────────────
      items.add(
        MoreMenuItem(
          text: 'Пожаловаться',
          icon: CupertinoIcons.exclamationmark_circle,
          iconColor: AppColors.orange,
          textStyle: const TextStyle(
            color: AppColors.orange,
          ),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              TransparentPageRoute(
                builder: (_) => ComplaintScreen(
                  contentType: widget.itemType == 'post' ? 'post' : 'activity',
                  contentId: widget.itemId,
                ),
              ),
            );
          },
        ),
      );
    }

    MoreMenuOverlay(anchorKey: menuKey, items: items).show(context);
  }

  @override
  Widget build(BuildContext context) {
    // Верстка как в твоем примере: белая карточка, радиус 20, maxHeight = 60% экрана.
    // ────────────────────────────────────────────────────────────────
    // 🔹 SafeArea(top: false): позволяет bottom sheet перекрывать нижнее навигационное меню
    // 🔹 Список комментариев остается на месте, только поле ввода двигается с клавиатурой
    // ────────────────────────────────────────────────────────────────
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: GestureDetector(
          // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ──── Ручка для перетаскивания ────
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10, top: 6),
                decoration: BoxDecoration(
                  color: AppColors.getBorderColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),

              // ──── Заголовок ────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    'Комментарии',
                    style: AppTextStyles.h17w6.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ──── Разделительная линия ────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.getBorderColor(context),
                ),
              ),
              const SizedBox(height: 8),

              // Список комментариев (Flexible как в образце) — остается на месте
              Flexible(child: _buildBody()),
              // ────────────────────────────────────────────────────────────────
              // 🔹 Только нижний блок (разделитель + поле ввода) двигается с клавиатурой
              // ────────────────────────────────────────────────────────────────
              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Разделитель бледно-серого цвета
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Divider(
                        height: 1,
                        color: AppColors.getBorderColor(context),
                      ),
                    ),
                    // Поле ввода — как в примере
                    _ComposerBar(
                      key: ValueKey(
                        'composerBar_$_composerReset',
                      ), // 👈 ключ бара
                      textFieldKey: ValueKey('composerTF_$_composerReset'),
                      controller: _textCtrl,
                      focusNode: _composerFocus,
                      sending: _sending,
                      onSend: _sendComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return _ErrorState(
        message: 'Не удалось загрузить комментарии.\n$_error',
        onRetry: () => _loadComments(refresh: true),
      );
    }

    if (_comments.isEmpty) {
      return const _EmptyState();
    }

    // Стилизуем под твой пример: ListTile со шрифтами из AppTextStyles.
    // Без pull-to-refresh: просто список
    return ListView.builder(
      controller: _scroll,
      physics: const BouncingScrollPhysics(), // iOS-пружинка, без refresh
      padding: EdgeInsets.zero,
      itemCount: _comments.length + (_pageLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _comments.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        final c = _comments[index];
        final humanDate = _formatHumanDate(c.createdAt);

        // ────────────────────────────────────────────────────────────────
        // 🔹 Кастомная верстка вместо ListTile: аватарка выровнена сверху
        // ────────────────────────────────────────────────────────────────
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ──── Аватарка (сверху) ────
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    TransparentPageRoute(
                      builder: (_) => ProfileScreen(userId: c.userId),
                    ),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.getSurfaceMutedColor(context),
                  backgroundImage:
                      (c.userAvatar != null && c.userAvatar!.isNotEmpty)
                      ? NetworkImage(c.userAvatar!)
                      : null,
                  child: (c.userAvatar == null || c.userAvatar!.isEmpty)
                      ? Text(
                          c.userName.isNotEmpty
                              ? c.userName.characters.first
                              : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // ──── Имя, дата и текст ────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Имя пользователя, дата и иконка меню
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  c.userName,
                                  style: AppTextStyles.h14w6.copyWith(
                                    letterSpacing: 0,
                                    color: AppColors.getTextPrimaryColor(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '· $humanDate',
                                style: AppTextStyles.h12w4Ter.copyWith(
                                  color: AppColors.getTextTertiaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ──── Иконка меню с тремя точками (у правого края) ────
                        Builder(
                          builder: (context) {
                            final menuKey = GlobalKey();
                            return GestureDetector(
                              key: menuKey,
                              onTap: () => _showCommentMenu(
                                context: context,
                                comment: c,
                                menuKey: menuKey,
                              ),
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(
                                  CupertinoIcons.ellipsis_vertical,
                                  size: 16,
                                  color: AppColors.getIconSecondaryColor(context),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Текст комментария
                    Text(
                      c.text,
                      style: AppTextStyles.h13w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ====== Форматирование времени: "сегодня, 18:50" / "вчера, 18:50" / "12 июл, 18:50" / "12 июл 2024, 18:50"
  String _formatHumanDate(String raw) {
    final dt = _tryParseDate(raw);
    if (dt == null) return raw;

    final now = DateTime.now();
    final local = dt.toLocal();

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(day).inDays;

    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm';

    if (diffDays == 0) return 'сегодня, $time';
    if (diffDays == 1) return 'вчера, $time';

    final month = _ruMonth(local.month, short: true); // «июл»
    if (local.year == now.year) {
      return '${local.day} $month, $time';
    } else {
      return '${local.day} $month ${local.year}, $time';
    }
  }

  DateTime? _tryParseDate(String s) {
    try {
      // поддержка "YYYY-MM-DD HH:MM[:SS]" → заменим пробел на 'T'
      final t = s.contains(' ') ? s.replaceFirst(' ', 'T') : s;
      return DateTime.parse(t);
    } catch (_) {
      // грубый парсер "YYYY-MM-DD HH:MM:SS"
      try {
        final parts = s.split(' ');
        if (parts.length >= 2) {
          final d = parts[0]
              .split('-')
              .map((e) => int.tryParse(e) ?? 0)
              .toList();
          final tm = parts[1]
              .split(':')
              .map((e) => int.tryParse(e) ?? 0)
              .toList();
          if (d.length >= 3 && tm.length >= 2) {
            return DateTime(
              d[0],
              d[1],
              d[2],
              tm[0],
              tm[1],
              tm.length >= 3 ? tm[2] : 0,
            );
          }
        }
      } catch (_) {}
      return null;
    }
  }

  String _ruMonth(int m, {bool short = false}) {
    const monthsShort = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    const monthsFull = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    if (m < 1 || m > 12) return '';
    return short ? monthsShort[m - 1] : monthsFull[m - 1];
  }
}

/// Поле ввода + кнопка отправки — как в твоём примере
class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final Future<void> Function(String text) onSend; // ← передаём текст наружу
  final Key? textFieldKey;

  const _ComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
    this.textFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 🔹 Отслеживаем изменения текста для активации/деактивации кнопки
    // ────────────────────────────────────────────────────────────────
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final isEnabled = hasText && !sending;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: textFieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: "Написать комментарий...",
                    hintStyle: AppTextStyles.h14w4Place.copyWith(
                      color: AppColors.getTextPlaceholderColor(context),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.getBackgroundColor(context),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: isEnabled
                    ? () async {
                        // 1) аккуратно забираем текст
                        controller.clearComposing();
                        final text = controller.text.trim();
                        if (text.isEmpty) return;

                        // 2) СРАЗУ очищаем поле (до сети)
                        controller.value = const TextEditingValue(
                          text: '',
                          selection: TextSelection.collapsed(offset: 0),
                          composing: TextRange.empty,
                        );

                        // 3) Можно оставить фокус в поле
                        focusNode.requestFocus();

                        // 4) Отправляем наверх уже «снятый» текст
                        await onSend(text);
                      }
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CupertinoActivityIndicator(),
                      )
                    : Icon(
                        Icons.send,
                        size: 22,
                        color: isEnabled
                            ? AppColors.brandPrimary
                            : AppColors.getTextPlaceholderColor(context),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_text,
            size: 28,
            color: AppColors.getIconSecondaryColor(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Пока нет комментариев',
            style: TextStyle(color: AppColors.getTextTertiaryColor(context)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 28,
              color: AppColors.warning,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.getTextTertiaryColor(context)),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
