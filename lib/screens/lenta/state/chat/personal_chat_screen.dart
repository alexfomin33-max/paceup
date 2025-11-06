import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../service/api_service.dart';
import '../../../../service/auth_service.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Экран персонального чата с конкретным пользователем
/// ────────────────────────────────────────────────────────────────────────
class PersonalChatScreen extends StatefulWidget {
  final int chatId;
  final int userId;
  final String userName;
  final String userAvatar;
  final String? lastSeen;

  const PersonalChatScreen({
    super.key,
    required this.chatId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.lastSeen,
  });

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

/// ────────────────────────────────────────────────────────────────────────
/// Модель сообщения из API
/// ────────────────────────────────────────────────────────────────────────
class ChatMessage {
  final int id;
  final int senderId;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Состояние экрана персонального чата
/// ────────────────────────────────────────────────────────────────────────
class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  int? _currentUserId;
  int? _lastMessageId;
  String? _error;
  Timer? _pollingTimer;
  int? _actualChatId; // Реальный chatId (создается если widget.chatId = 0)

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// ─── Инициализация чата ───
  Future<void> _initChat() async {
    final userId = await _auth.getUserId();
    if (userId == null) {
      setState(() {
        _error = 'Пользователь не авторизован';
      });
      return;
    }

    setState(() {
      _currentUserId = userId;
    });

    // Если chatId = 0, создаем новый чат
    if (widget.chatId == 0) {
      await _createChat();
    } else {
      _actualChatId = widget.chatId;
      await _loadInitial();
      _markMessagesAsRead(); // Отмечаем сообщения как прочитанные при открытии
      _startPolling();
    }
  }

  /// ─── Создание нового чата ───
  Future<void> _createChat() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _api.post(
        '/create_chat.php',
        body: {
          'user2_id': widget.userId,
        },
      );

      if (response['success'] == true) {
        final chatId = response['chat_id'] as int;
        
        setState(() {
          _actualChatId = chatId;
          _isLoading = false;
        });

        // После создания чата загружаем сообщения
        await _loadInitial();
        _markMessagesAsRead();
        _startPolling();
      } else {
        setState(() {
          _error = response['message'] as String? ?? 'Ошибка создания чата';
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

  /// ─── Загрузка начальных сообщений ───
  Future<void> _loadInitial() async {
    if (_isLoading || _currentUserId == null) return;
    
    // Если чат еще не создан, не загружаем сообщения
    final chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _offset = 0;
    });

    try {
      final response = await _api.get(
        '/get_messages.php',
        queryParams: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
          'offset': '0',
          'limit': '50',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> messagesJson =
            response['messages'] as List<dynamic>;
        final messages = messagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        // Обновляем last_message_id
        if (messages.isNotEmpty) {
          _lastMessageId = messages.last.id;
        }

        setState(() {
          _messages = messages;
          _hasMore = response['has_more'] as bool? ?? false;
          _offset = messages.length;
          _isLoading = false;
        });

        // Прокрутка вниз после загрузки
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        setState(() {
          _error =
              response['message'] as String? ?? 'Ошибка загрузки сообщений';
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

  /// ─── Загрузка старых сообщений (при прокрутке вверх) ───
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _currentUserId == null) return;
    
    final chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _api.get(
        '/get_messages.php',
        queryParams: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
          'offset': _offset.toString(),
          'limit': '50',
        },
      );

      if (response['success'] == true) {
        final List<dynamic> messagesJson =
            response['messages'] as List<dynamic>;
        final newMessages = messagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        setState(() {
          _messages.insertAll(0, newMessages);
          _hasMore = response['has_more'] as bool? ?? false;
          _offset += newMessages.length;
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

  /// ─── Отправка текстового сообщения ───
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    final messageText = text;
    _ctrl.clear();
    FocusScope.of(context).unfocus();

    // Оптимистичное обновление UI
    final tempMessage = ChatMessage(
      id: -1, // Временный ID
      senderId: _currentUserId!,
      text: messageText,
      createdAt: DateTime.now(),
      isMine: true,
      isRead: false,
    );

    setState(() {
      _messages.add(tempMessage);
    });

    // Прокрутка вниз
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Если чат еще не создан, создаем его перед отправкой сообщения
    int chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0 && _currentUserId != null) {
      try {
        final createResponse = await _api.post(
          '/create_chat.php',
          body: {
            'user2_id': widget.userId,
          },
        );
        
        if (createResponse['success'] == true) {
          chatId = createResponse['chat_id'] as int;
          setState(() {
            _actualChatId = chatId;
          });
        } else {
          // Удаляем временное сообщение при ошибке
          setState(() {
            _messages.removeWhere((m) => m.id == -1);
          });
          return;
        }
      } catch (e) {
        // Удаляем временное сообщение при ошибке
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
        });
        return;
      }
    }

    try {
      final response = await _api.post(
        '/send_message.php',
        body: {
          'chat_id': chatId,
          'user_id': _currentUserId,
          'text': messageText,
        },
      );

      if (response['success'] == true) {
        final messageId = response['message_id'] as int;
        final createdAt = DateTime.parse(response['created_at'] as String);

        // Обновляем временное сообщение с реальными данными
        setState(() {
          final index = _messages.indexWhere((m) => m.id == -1);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: messageId,
              senderId: _currentUserId!,
              text: messageText,
              createdAt: createdAt,
              isMine: true,
              isRead: false,
            );
          }
          _lastMessageId = messageId;
        });
      } else {
        // Удаляем временное сообщение при ошибке
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
        });
      }
    } catch (e) {
      // Удаляем временное сообщение при ошибке
      setState(() {
        _messages.removeWhere((m) => m.id == -1);
      });
    }
  }

  /// ─── Отметка сообщений как прочитанных ───
  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;
    
    final chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) return;

    try {
      await _api.post(
        '/mark_messages_read.php',
        body: {'chat_id': chatId, 'user_id': _currentUserId},
      );
    } catch (e) {
      // Игнорируем ошибки - не критично
    }
  }

  /// ─── Запуск polling для проверки новых сообщений ───
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkNewMessages();
    });
  }

  /// ─── Проверка новых сообщений ───
  Future<void> _checkNewMessages() async {
    if (_currentUserId == null || _lastMessageId == null) return;
    
    final chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) return;

    try {
      final response = await _api.get(
        '/check_new_messages.php',
        queryParams: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
          'last_message_id': _lastMessageId.toString(),
        },
      );

      if (response['success'] == true && response['has_new'] == true) {
        final List<dynamic> newMessagesJson =
            response['new_messages'] as List<dynamic>;
        final newMessages = newMessagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        if (newMessages.isNotEmpty) {
          setState(() {
            _messages.addAll(newMessages);
            _lastMessageId =
                response['last_message_id'] as int? ?? _lastMessageId;
          });

          // Отмечаем новые сообщения как прочитанные, если они от другого пользователя
          // и пользователь находится в чате (экран открыт)
          final hasIncomingMessages = newMessages.any((msg) => !msg.isMine);
          if (hasIncomingMessages) {
            _markMessagesAsRead();
          }

          // Прокрутка вниз при получении новых сообщений
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки polling
    }
  }

  /// ─── Форматирование времени ───
  String _formatTime(DateTime dt) {
    return DateFormat('H:mm').format(dt);
  }

  /// ─── Получение URL аватара ───
  String _getAvatarUrl(String avatar) {
    if (avatar.isEmpty) {
      return 'http://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    // ⚡️ Используем правильный путь: /images/users/avatars/{user_id}/{avatar}
    return 'http://uploads.paceup.ru/images/users/avatars/${widget.userId}/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0.5,
          leadingWidth: 40,
          leading: Transform.translate(
            offset: const Offset(-4, 0),
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(CupertinoIcons.back),
              onPressed: () async {
                // Отмечаем сообщения как прочитанные перед закрытием
                await _markMessagesAsRead();
                if (mounted) {
                  Navigator.pop(
                    context,
                    true,
                  ); // Возвращаем true для обновления списка
                }
              },
              splashRadius: 18,
            ),
          ),
          titleSpacing: -8,
          title: Row(
            children: [
              // Аватар пользователя
              ClipOval(
                child: Builder(
                  builder: (context) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final w = (36 * dpr).round();
                    final h = (36 * dpr).round();
                    final url = _getAvatarUrl(widget.userAvatar);
                    return CachedNetworkImage(
                      imageUrl: url,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      memCacheWidth: w,
                      memCacheHeight: h,
                      maxWidthDiskCache: w,
                      maxHeightDiskCache: h,
                      errorWidget: (_, __, ___) {
                        return Image.asset(
                          'assets/${widget.userAvatar}',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              width: 36,
                              height: 36,
                              color: AppColors.surfaceMuted,
                              child: const Icon(CupertinoIcons.person, size: 20),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Имя и статус "Был N минут назад"
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.lastSeen != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.lastSeen!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ─── Прокручиваемая область с сообщениями ───
            Expanded(
              child: () {
                if (_error != null && _messages.isEmpty) {
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

                if (_isLoading && _messages.isEmpty) {
                  return const Center(child: CupertinoActivityIndicator());
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      if (_scrollController.position.pixels <= 100 &&
                          _hasMore &&
                          !_isLoadingMore) {
                        _loadMore();
                      }
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && _isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CupertinoActivityIndicator()),
                        );
                      }

                      final messageIndex = _isLoadingMore ? index - 1 : index;
                      final message = _messages[messageIndex];

                      return message.isMine
                          ? _BubbleRight(
                              text: message.text,
                              time: _formatTime(message.createdAt),
                            )
                          : _BubbleLeft(
                              text: message.text,
                              time: _formatTime(message.createdAt),
                              avatarUrl: _getAvatarUrl(widget.userAvatar),
                            );
                    },
                  ),
                );
              }(),
            ),

            // ─── Неподвижная нижняя панель ввода ───
            _Composer(
              controller: _ctrl,
              onSend: _sendText,
              onPickImage: () {
                // TODO: Реализовать отправку изображений
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Вспомогательные виджеты
/// ────────────────────────────────────────────────────────────────────────

/// Левый пузырь (сообщения собеседника) — с аватаром
class _BubbleLeft extends StatelessWidget {
  final String text;
  final String time;
  final String avatarUrl;

  const _BubbleLeft({
    required this.text,
    required this.time,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final max = screenW * 0.72;

    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipOval(
            child: Builder(
              builder: (context) {
                final dpr = MediaQuery.of(context).devicePixelRatio;
                final w = (28 * dpr).round();
                final h = (28 * dpr).round();
                return CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 120),
                  memCacheWidth: w,
                  memCacheHeight: h,
                  maxWidthDiskCache: w,
                  maxHeightDiskCache: h,
                  errorWidget: (_, __, ___) => Container(
                    width: 28,
                    height: 28,
                    color: AppColors.surfaceMuted,
                    child: const Icon(CupertinoIcons.person, size: 16),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Правый пузырь (мои сообщения) — без аватара
class _BubbleRight extends StatelessWidget {
  final String text;
  final String time;

  const _BubbleRight({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.75;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 0, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              decoration: BoxDecoration(
                color: AppColors.greenBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.greenBr),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Компонент ввода сообщений
class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final enabled = widget.controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.plus_circle),
              onPressed: widget.onPickImage,
              color: AppColors.iconSecondary,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Сообщение...',
                    hintStyle: TextStyle(color: AppColors.textPlaceholder),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(CupertinoIcons.paperplane_fill),
              onPressed: enabled ? widget.onSend : null,
              color: enabled ? AppColors.brandPrimary : AppColors.iconTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
