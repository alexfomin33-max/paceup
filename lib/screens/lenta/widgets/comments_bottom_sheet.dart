import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_theme.dart';

// ——— Безопасный JSON-декодер: чистит BOM/мусор и вырезает { ... } ———
Map<String, dynamic> safeDecodeJsonAsMap(List<int> bodyBytes) {
  final raw = utf8.decode(bodyBytes);
  // уберём BOM и лишние пробелы
  final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  try {
    final v = json.decode(cleaned);
    if (v is Map<String, dynamic>) return v;
    throw const FormatException('JSON is not an object');
  } catch (_) {
    // пробуем вырезать первый '{' и последний '}'
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final sub = cleaned.substring(start, end + 1);
      final v2 = json.decode(sub);
      if (v2 is Map<String, dynamic>) return v2;
    }
    throw FormatException('Invalid JSON: $cleaned');
  }
}

// ——— Аккуратный показ SnackBar (чтобы не падать без ScaffoldMessenger) ———
void showSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m != null) {
    m.showSnackBar(SnackBar(content: Text(message)));
  } else {
    debugPrint('Snack: $message');
  }
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
  static const String base = 'http://api.paceup.ru/';

  static String get commentsList => '${base}comments_list.php';
  static String get commentsAdd => '${base}comments_add.php';

  /// Размер страницы для пагинации
  static const int pageSize = 20;
}

/// Модель комментария
class CommentItem {
  final int id;
  final String userName;
  final String? userAvatar;
  final String text;
  final String createdAt; // строка с датой от сервера

  CommentItem({
    required this.id,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.userAvatar,
  });

  factory CommentItem.fromApi(Map<String, dynamic> json) {
    return CommentItem(
      id: int.tryParse('${json['id']}') ?? 0,
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
class CommentsBottomSheet extends StatefulWidget {
  final String itemType; // 'post' | 'activity'
  final int itemId;
  final int currentUserId;

  const CommentsBottomSheet({
    super.key,
    required this.itemType,
    required this.itemId,
    required this.currentUserId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
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
      // Для PHP-скрипта используем x-www-form-urlencoded (Map)
      final resp = await http.post(
        Uri.parse(ApiConfig.commentsList),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: jsonEncode({
          'type': widget.itemType,
          'item_id': widget.itemId.toString(),
          'page': _page.toString(),
          'limit': ApiConfig.pageSize.toString(),
          'userId': widget.currentUserId.toString(),
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final data = safeDecodeJsonAsMap(resp.bodyBytes);
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
        _error = e.toString();
        _initialLoading = false;
        _pageLoading = false;
      });
    }
  }

  Future<void> _sendComment(String text) async {
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    try {
      final payload = {
        'type': widget.itemType,
        'item_id': widget.itemId.toString(),
        'text': text,
        'userId': widget.currentUserId.toString(), // лучше snake_case
      };

      final resp = await http.post(
        Uri.parse(ApiConfig.commentsAdd),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: jsonEncode(payload), // НЕ jsonEncode
      );

      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final data = safeDecodeJsonAsMap(resp.bodyBytes);
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

  @override
  Widget build(BuildContext context) {
    // Верстка как в твоем примере: белая карточка, радиус 20, maxHeight = 60% экрана.
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Список комментариев (Flexible как в образце)
              Flexible(child: _buildBody()),
              // Разделитель бледно-серого цвета
              const Divider(height: 1, color: AppColors.border),
              // Поле ввода — как в примере
              _ComposerBar(
                key: ValueKey('composerBar_$_composerReset'), // 👈 ключ бара
                textFieldKey: ValueKey('composerTF_$_composerReset'),
                controller: _textCtrl,
                focusNode: _composerFocus,
                sending: _sending,
                onSend: _sendComment,
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
      return _EmptyState(onRefresh: () => _loadComments(refresh: true));
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

        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundImage: (c.userAvatar != null && c.userAvatar!.isNotEmpty)
                ? NetworkImage(c.userAvatar!)
                : null,
            child: (c.userAvatar == null || c.userAvatar!.isEmpty)
                ? Text(
                    c.userName.isNotEmpty ? c.userName.characters.first : '?',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )
                : null,
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  c.userName,
                  style: AppTextStyles.normaltext,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· $humanDate',
                style: AppTextStyles.commenttext.copyWith(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          subtitle: Text(c.text, style: AppTextStyles.commenttext),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: textFieldKey,
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: "Написать комментарий...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: sending
                ? null
                : () async {
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
                  },
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(10),
              elevation: 0,
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CupertinoActivityIndicator(),
                  )
                : const Icon(Icons.send, size: 22, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.chat_bubble_text,
            size: 28,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          const Text(
            'Пока нет комментариев',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRefresh,
            child: const Text('Обновить'),
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
              color: Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
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

/*class CommentsBottomSheet extends StatelessWidget {
  const CommentsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Список комментариев
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage("assets/Avatar_3.png"),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Татьяна Капуста", style: AppTextStyles.name),
                          const SizedBox(width: 6),
                          Text(
                            "· вчера, 18:50",
                            style: AppTextStyles.commenttext.copyWith(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Text(
                        "Что-то совсем маловато пробежал",
                        style: AppTextStyles.commenttext,
                      ),
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage("assets/Avatar_1.png"),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Алексей Лукашин", style: AppTextStyles.name),
                          const SizedBox(width: 6),
                          Text(
                            "· вчера, 19:15",
                            style: AppTextStyles.commenttext.copyWith(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Text(
                        "Лёха Фомин и то намного больше и быстрее бегает. Я лучше с ним на эстафету поеду.",
                        style: AppTextStyles.commenttext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Разделитель бледно-серого цвета
            Divider(height: 1, color: AppColors.border),
            // Поле ввода
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Написать комментарий...",
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6, // уменьшили высоту поля
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xlarge),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(
                        10,
                      ), // уменьшили отступ кнопки
                      elevation: 0,
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 22,
                      color: AppColors.secondary,
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
}*/
