// lib/screens/chat_screen.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import 'personal_chat_screen.dart';
import 'start_chat_screen.dart';

/// Модель чата из API
class ChatItem {
  final int id;
  final int userId;
  final String userName;
  final String userAvatar;
  final String lastMessage;
  final bool
  lastMessageHasImage; // ─── Флаг наличия изображения в последнем сообщении ───
  final DateTime lastMessageAt;
  final bool unread;
  final DateTime createdAt;

  const ChatItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.lastMessage,
    required this.lastMessageHasImage,
    required this.lastMessageAt,
    required this.unread,
    required this.createdAt,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    return ChatItem(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String,
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageHasImage: json['last_message_has_image'] as bool? ?? false,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      unread: json['unread'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  List<ChatItem> _chats = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  // ─── Polling для автоматического обновления списка чатов ───
  Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
    _scrollController.addListener(_onScroll);
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ─── Обновляем список при возврате приложения из фона ───
    if (state == AppLifecycleState.resumed) {
      _softRefresh();
    }
  }

  /// ─── Запуск таймера для периодического обновления ───
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) {
        _softRefresh();
      }
    });
  }

  /// ─── Мягкое обновление: обновляет данные без сброса позиции скролла ───
  Future<void> _softRefresh() async {
    // Не обновляем, если идет загрузка или загрузка следующей страницы
    if (_isLoading || _isLoadingMore) return;

    try {
      final auth = ref.read(authServiceProvider);
      final api = ref.read(apiServiceProvider);
      final userId = await auth.getUserId();
      if (userId == null) return;

      final response = await api.get(
        '/get_chats.php',
        queryParams: {
          'user_id': userId.toString(),
          'offset': '0',
          'limit': '20',
        },
      );

      if (response['success'] == true && mounted) {
        final List<dynamic> chatsJson = response['chats'] as List<dynamic>;
        final newChats = chatsJson
            .map((json) => ChatItem.fromJson(json as Map<String, dynamic>))
            .toList();

        // ─── Обновляем список, сохраняя позицию скролла ───
        final currentScrollPosition = _scrollController.hasClients
            ? _scrollController.position.pixels
            : 0.0;

        setState(() {
          _chats = newChats;
          _hasMore = response['has_more'] as bool? ?? false;
          _offset = newChats.length;
        });

        // ─── Восстанавливаем позицию скролла после обновления ───
        if (_scrollController.hasClients && currentScrollPosition > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(currentScrollPosition);
            }
          });
        }
      }
    } catch (e) {
      // Игнорируем ошибки при мягком обновлении, чтобы не мешать пользователю
      // Ошибки будут показаны только при полной загрузке
    }
  }

  /// ─── Загрузка начального списка чатов ───
  Future<void> _loadInitial() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _offset = 0;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final api = ref.read(apiServiceProvider);
      final userId = await auth.getUserId();
      if (userId == null) {
        setState(() {
          _error = 'Пользователь не авторизован';
          _isLoading = false;
        });
        return;
      }

      final response = await api.get(
        '/get_chats.php',
        queryParams: {
          'user_id': userId.toString(),
          'offset': '0',
          'limit': '20',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> chatsJson = response['chats'] as List<dynamic>;
        final chats = chatsJson
            .map((json) => ChatItem.fromJson(json as Map<String, dynamic>))
            .toList();

        setState(() {
          _chats = chats;
          _hasMore = response['has_more'] as bool? ?? false;
          _offset = chats.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] as String? ?? 'Ошибка загрузки чатов';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ErrorHandler.format(e);
        _isLoading = false;
      });
    }
  }

  /// ─── Загрузка следующей страницы чатов ───
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final api = ref.read(apiServiceProvider);
      final userId = await auth.getUserId();
      if (userId == null) return;

      final response = await api.get(
        '/get_chats.php',
        queryParams: {
          'user_id': userId.toString(),
          'offset': _offset.toString(),
          'limit': '20',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> chatsJson = response['chats'] as List<dynamic>;
        final newChats = chatsJson
            .map((json) => ChatItem.fromJson(json as Map<String, dynamic>))
            .toList();

        setState(() {
          _chats.addAll(newChats);
          _hasMore = response['has_more'] as bool? ?? false;
          _offset += newChats.length;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// ─── Обработчик скролла для пагинации ───
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// ─── Форматирование даты/времени ───
  String _formatWhen(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diffDays = day.difference(today).inDays;

    if (diffDays == 0) return DateFormat('H:mm').format(d);
    if (diffDays == -1) return 'Вчера, ${DateFormat('H:mm').format(d)}';
    if (diffDays == -2) return 'Позавчера, ${DateFormat('H:mm').format(d)}';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  /// ─── Получение URL аватара ───
  String _getAvatarUrl(String avatar, int userId) {
    if (avatar.isEmpty) {
      return 'http://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    // ⚡️ Используем правильный путь: /images/users/avatars/{user_id}/{avatar}
    return 'http://uploads.paceup.ru/images/users/avatars/$userId/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),

        // ─── Глобальный AppBar ───
        appBar: PaceAppBar(
          title: 'Чаты',
          actions: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final result = await Navigator.of(context).push(
                  TransparentPageRoute(builder: (_) => const StartChatScreen()),
                );
                // Обновляем список чатов после создания нового чата
                if (result == true && mounted) {
                  await _loadInitial();
                }
              },
              child: SizedBox(
                width: 48,
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    CupertinoIcons.add_circled,
                    size: 22,
                    color: AppColors.getIconPrimaryColor(context),
                  ),
                ),
              ),
            ),
          ],
        ),

        body: RefreshIndicator.adaptive(
          onRefresh: _loadInitial,
          child: () {
            // ─── Ошибка ───
            if (_error != null && _chats.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ошибка: $_error',
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadInitial,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ─── Загрузка ───
            if (_isLoading && _chats.isEmpty) {
              return const Center(child: CupertinoActivityIndicator());
            }

            // ─── Пустой список ───
            if (_chats.isEmpty) {
              return const Center(
                child: Text('Пока чатов нет', style: AppTextStyles.h14w4),
              );
            }

            // ─── Список чатов ───
            return ListView.separated(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _chats.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.getBorderColor(context)
                    : AppColors.border,
                indent: 62,
                endIndent: 8,
              ),
              itemBuilder: (context, i) {
                // Индикатор загрузки в конце списка
                if (i == _chats.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                final chat = _chats[i];

                Widget chatRow = Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Аватар
                      ClipOval(
                        child: Builder(
                          builder: (context) {
                            final dpr = MediaQuery.of(context).devicePixelRatio;
                            final w = (44 * dpr).round();
                            final url = _getAvatarUrl(
                              chat.userAvatar,
                              chat.userId,
                            );
                            return CachedNetworkImage(
                              key: ValueKey(
                                'avatar_${chat.id}_${chat.userId}_$url',
                              ),
                              imageUrl: url,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 120),
                              memCacheWidth: w,
                              maxWidthDiskCache: w,
                              errorWidget: (context, imageUrl, error) {
                                return Image.asset(
                                  'assets/${chat.userAvatar}',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 44,
                                      height: 44,
                                      color: AppColors.surfaceMuted,
                                      child: const Icon(
                                        CupertinoIcons.person,
                                        size: 24,
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Контент
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Первая строка: имя + время
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chat.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    // ─── Жирный стиль для непрочитанных сообщений ───
                                    style: AppTextStyles.h14w5.copyWith(
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatWhen(chat.lastMessageAt),
                                  style: AppTextStyles.h11w5Sec.copyWith(
                                    color: AppColors.getTextSecondaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Вторая строка: превью сообщения
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    // ─── Показываем "Изображение" если последнее сообщение - изображение без текста ───
                                    chat.lastMessageHasImage &&
                                            chat.lastMessage.isEmpty
                                        ? 'Изображение'
                                        : chat.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    // ─── Жирный стиль для непрочитанных сообщений ───
                                    style: chat.unread
                                        ? AppTextStyles.h13w6.copyWith(
                                            color:
                                                AppColors.getTextPrimaryColor(
                                                  context,
                                                ),
                                          )
                                        : AppTextStyles.h13w4Sec.copyWith(
                                            color:
                                                AppColors.getTextSecondaryColor(
                                                  context,
                                                ),
                                          ),
                                  ),
                                ),
                                if (chat.unread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.brandPrimary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                // ─── Оборачиваем в GestureDetector для навигации ───
                final item = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final result =
                        await Navigator.of(context, rootNavigator: true).push(
                          TransparentPageRoute(
                            builder: (_) => PersonalChatScreen(
                              chatId: chat.id,
                              userId: chat.userId,
                              userName: chat.userName,
                              userAvatar: chat.userAvatar,
                            ),
                          ),
                        );

                    // Обновляем список чатов после возврата из чата
                    if (result == true && mounted) {
                      await _loadInitial();
                    }
                  },
                  child: chatRow,
                );

                // Нижняя граница под самой последней карточкой
                final isLastVisible = i == _chats.length - 1 && !_isLoadingMore;
                if (isLastVisible) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item,
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.getBorderColor(context)
                            : AppColors.border,
                      ),
                    ],
                  );
                }

                return item;
              },
            );
          }(),
        ),
      ),
    );
  }
}
