// lib/screens/chat_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart'; // ← глобальный AppBar
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/transparent_route.dart';
import '../../../../service/api_service.dart';
import '../../../../service/auth_service.dart';
import 'personal_chat_screen.dart';

/// Модель чата из API
class ChatItem {
  final int id;
  final int userId;
  final String userName;
  final String userAvatar;
  final String lastMessage;
  final DateTime lastMessageAt;
  final bool unread;
  final DateTime createdAt;

  const ChatItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.lastMessage,
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
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      unread: json['unread'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final ScrollController _scrollController = ScrollController();

  List<ChatItem> _chats = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      final userId = await _auth.getUserId();
      if (userId == null) {
        setState(() {
          _error = 'Пользователь не авторизован';
          _isLoading = false;
        });
        return;
      }

      final response = await _api.get(
        '/get_chats.php',
        queryParams: {
          'user_id': userId.toString(),
          'offset': '0',
          'limit': '20',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> chatsJson = response['chats'] as List<dynamic>;
        final chats = chatsJson.map((json) => ChatItem.fromJson(json as Map<String, dynamic>)).toList();
        
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
        _error = e.toString();
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
      final userId = await _auth.getUserId();
      if (userId == null) return;

      final response = await _api.get(
        '/get_chats.php',
        queryParams: {
          'user_id': userId.toString(),
          'offset': _offset.toString(),
          'limit': '20',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> chatsJson = response['chats'] as List<dynamic>;
        final newChats = chatsJson.map((json) => ChatItem.fromJson(json as Map<String, dynamic>)).toList();
        
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
  String _getAvatarUrl(String avatar) {
    if (avatar.isEmpty) return 'http://uploads.paceup.ru/defaults/1.webp';
    if (avatar.startsWith('http')) return avatar;
    return 'http://uploads.paceup.ru/avatars/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,

        // ─── Глобальный AppBar ───
        appBar: const PaceAppBar(
          title: 'Чаты',
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                CupertinoIcons.create,
                size: 20,
                color: AppColors.iconPrimary,
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
              return const Center(
                child: CupertinoActivityIndicator(),
              );
            }

            // ─── Пустой список ───
            if (_chats.isEmpty) {
              return const Center(
                child: Text(
                  'Пока чатов нет',
                  style: AppTextStyles.h14w4,
                ),
              );
            }

            // ─── Список чатов ───
            return ListView.separated(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _chats.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.border,
                indent: 57,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Аватар
                      ClipOval(
                        child: Image.network(
                          _getAvatarUrl(chat.userAvatar),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/${chat.userAvatar}',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  width: 40,
                                  height: 40,
                                  color: AppColors.surfaceMuted,
                                  child: const Icon(CupertinoIcons.person, size: 24),
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
                                    style: AppTextStyles.h13w6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatWhen(chat.lastMessageAt),
                                  style: AppTextStyles.h11w4Ter,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Вторая строка: превью сообщения
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chat.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.h12w4Sec,
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
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    final result = await Navigator.of(context).push(
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
              },
            );
          }(),
        ),
      ),
    );
  }
}
