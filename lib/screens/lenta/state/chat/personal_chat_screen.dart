import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
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
  final String? image; // URL изображения
  final DateTime createdAt;
  final bool isMine;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.image,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      text: json['text'] as String,
      image: json['image'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}

/// ────────────────────────────────────────────────────────────────────────
/// Состояние экрана персонального чата
/// ────────────────────────────────────────────────────────────────────────
class _PersonalChatScreenState extends State<PersonalChatScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final ImagePicker _picker = ImagePicker();

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
  double _previousKeyboardHeight = 0; // Для отслеживания изменений клавиатуры

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// ─── Прокрутка вниз к последним сообщениям ───
  void _scrollToBottom({bool animated = true, bool force = false}) {
    if (!_scrollController.hasClients || !mounted) return;

    // Если force = true, всегда прокручиваем (например, при открытии клавиатуры)
    if (!force) {
      // Проверяем, находится ли пользователь уже внизу (в пределах 200px от конца)
      final isNearBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200;

      // Прокручиваем только если пользователь уже внизу
      if (!isNearBottom) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // ─── Отслеживаем изменения клавиатуры через didChangeMetrics ───
    // Этот метод вызывается при изменении размеров экрана, включая появление клавиатуры
    if (!mounted) return;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardHeight > 0 && _previousKeyboardHeight == 0) {
      // Клавиатура только что открылась - прокручиваем вниз с задержкой
      // Делаем две прокрутки: быструю и затем еще одну после полного появления клавиатуры
      // force = true, чтобы всегда прокручивать при открытии клавиатуры
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom(force: true);
        }
      });
      // Дополнительная прокрутка после полного появления клавиатуры
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _scrollToBottom(force: true);
        }
      });
    }
    _previousKeyboardHeight = keyboardHeight;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ─── Обновляем сообщения при возврате приложения из фона ───
    if (state == AppLifecycleState.resumed) {
      final chatId = _actualChatId ?? widget.chatId;
      if (chatId != 0 && _currentUserId != null) {
        // Проверяем новые сообщения при возврате
        _checkNewMessages();
        // Отмечаем сообщения как прочитанные
        _markMessagesAsRead();
      }
    }
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
        body: {'user2_id': widget.userId},
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

        // Обновляем last_message_id (берем самый последний ID)
        if (messages.isNotEmpty) {
          // Находим максимальный ID среди всех сообщений
          _lastMessageId = messages
              .map((m) => m.id)
              .reduce((a, b) => a > b ? a : b);
        } else {
          // Если сообщений нет, устанавливаем last_message_id в 0
          _lastMessageId = 0;
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

  /// ─── Выбор изображения из галереи ───
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Сжатие на клиенте
      );
      if (pickedFile != null && _currentUserId != null) {
        await _sendImage(File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора изображения: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// ─── Отправка изображения в чат ───
  Future<void> _sendImage(File imageFile) async {
    if (_currentUserId == null) return;

    // Если чат еще не создан, создаем его перед отправкой изображения
    int chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) {
      try {
        final createResponse = await _api.post(
          '/create_chat.php',
          body: {'user2_id': widget.userId},
        );

        if (createResponse['success'] == true) {
          chatId = createResponse['chat_id'] as int;
          setState(() {
            _actualChatId = chatId;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  createResponse['message'] as String? ??
                      'Ошибка создания чата',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка создания чата: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    try {
      // Загружаем изображение на сервер
      final uploadResponse = await _api.postMultipart(
        '/upload_chat_image.php',
        files: {'image': imageFile},
        fields: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
        },
      );

      if (uploadResponse['success'] == true) {
        final imagePath = uploadResponse['image_path'] as String;
        final imageUrl = uploadResponse['image_url'] as String;

        // Отправляем сообщение с изображением
        final response = await _api.post(
          '/send_message.php',
          body: {
            'chat_id': chatId,
            'user_id': _currentUserId,
            'text': '', // Пустой текст для сообщения с изображением
            'image': imagePath, // Относительный путь к изображению
          },
        );

        if (response['success'] == true) {
          final messageId = response['message_id'] as int;
          final createdAt = DateTime.parse(response['created_at'] as String);

          // Добавляем сообщение в список
          setState(() {
            _messages.add(ChatMessage(
              id: messageId,
              senderId: _currentUserId!,
              text: '',
              image: imageUrl,
              createdAt: createdAt,
              isMine: true,
              isRead: false,
            ));
            _lastMessageId = messageId;
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
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] as String? ??
                      'Ошибка отправки сообщения',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uploadResponse['message'] as String? ??
                    'Ошибка загрузки изображения',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки изображения: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
          body: {'user2_id': widget.userId},
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
      if (mounted) {
        _checkNewMessages();
      }
    });
  }

  /// ─── Проверка новых сообщений ───
  Future<void> _checkNewMessages() async {
    if (_currentUserId == null) return;

    final chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) return;

    // Если last_message_id еще не установлен, используем 0
    final lastId = _lastMessageId ?? 0;

    try {
      final response = await _api.get(
        '/check_new_messages.php',
        queryParams: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
          'last_message_id': lastId.toString(),
        },
      );

      if (response['success'] == true && response['has_new'] == true) {
        final List<dynamic> newMessagesJson =
            response['new_messages'] as List<dynamic>;
        final newMessages = newMessagesJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        if (newMessages.isNotEmpty && mounted) {
          // Обновляем last_message_id на максимальный ID среди новых сообщений
          final maxNewId = newMessages
              .map((m) => m.id)
              .reduce((a, b) => a > b ? a : b);

          setState(() {
            _messages.addAll(newMessages);
            // Всегда обновляем на максимальный ID, если он больше текущего
            if (maxNewId > (lastId)) {
              _lastMessageId = maxNewId;
            }
          });

          // Отмечаем новые сообщения как прочитанные, если они от другого пользователя
          // и пользователь находится в чате (экран открыт)
          final hasIncomingMessages = newMessages.any((msg) => !msg.isMine);
          if (hasIncomingMessages) {
            _markMessagesAsRead();
          }

          // Прокрутка вниз при получении новых сообщений
          // Только если пользователь уже находится внизу списка
          if (_scrollController.hasClients) {
            final isNearBottom =
                _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 100;

            if (isNearBottom) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients && mounted) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          }
        }
      }
    } catch (e) {
      // Игнорируем ошибки polling, чтобы не мешать пользователю
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
    // ─── Получаем высоту клавиатуры для адаптации ───
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.getSurfaceColor(context)
              : AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0.5,
          scrolledUnderElevation: 0, // ─── Убираем тень при скролле ───
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
                    final url = _getAvatarUrl(widget.userAvatar);
                    return CachedNetworkImage(
                      imageUrl: url,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      memCacheWidth: w,
                      maxWidthDiskCache: w,
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
                              color: AppColors.getSurfaceMutedColor(context),
                              child: Icon(
                                CupertinoIcons.person,
                                size: 20,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    if (widget.lastSeen != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.lastSeen!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // ─── Нижняя граница под AppBar ───
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(
              height: 0.5,
              thickness: 0.5,
              color: AppColors.getBorderColor(context),
            ),
          ),
        ),
        body: GestureDetector(
          // ─── Убираем фокус с поля ввода при тапе на экран ───
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.translucent,
          child: Column(
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
                      // ─── Динамический padding: учитываем высоту клавиатуры и панели ввода ───
                      // Панель ввода (_Composer) имеет минимальную высоту ~100px
                      // При открытой клавиатуре добавляем небольшой дополнительный отступ
                      padding: EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        // Базовый отступ для панели ввода, при открытой клавиатуре немного больше
                        keyboardHeight > 0 ? 50 : 50,
                      ),
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
                                image: message.image,
                                time: _formatTime(message.createdAt),
                              )
                            : _BubbleLeft(
                                text: message.text,
                                image: message.image,
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
                onPickImage: _pickImage,
                onFocus: () {
                  // ─── Прокручиваем вниз при фокусе на поле ввода ───
                  // Небольшая задержка, чтобы клавиатура успела появиться
                  // force = true, чтобы всегда прокручивать при фокусе
                  Future.delayed(const Duration(milliseconds: 150), () {
                    if (mounted) {
                      _scrollToBottom(force: true);
                    }
                  });
                },
              ),
            ],
          ),
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
  final String? image;
  final String time;
  final String avatarUrl;

  const _BubbleLeft({
    required this.text,
    this.image,
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
                return CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 120),
                  memCacheWidth: w,
                  maxWidthDiskCache: w,
                  errorWidget: (_, __, ___) => Container(
                    width: 28,
                    height: 28,
                    color: AppColors.getSurfaceMutedColor(context),
                    child: Icon(
                      CupertinoIcons.person,
                      size: 16,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceMuted
                    : AppColors.softBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Изображение (если есть) ───
                  if (image != null && image!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Builder(
                        builder: (context) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final maxW = max * 0.9;
                          final w = (maxW * dpr).round();
                          return CachedNetworkImage(
                            imageUrl: image!,
                            width: maxW,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            memCacheWidth: w,
                            maxWidthDiskCache: w,
                            errorWidget: (_, __, ___) {
                              return Container(
                                width: maxW,
                                height: 200,
                                color: AppColors.getSurfaceMutedColor(context),
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 40,
                                  color: AppColors.getIconSecondaryColor(context),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  // ─── Текст (если есть) ───
                  if (text.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  // ─── Время ───
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextTertiaryColor(context),
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
  final String? image;
  final String time;

  const _BubbleRight({
    required this.text,
    this.image,
    required this.time,
  });

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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.greenBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Изображение (если есть) ───
                  if (image != null && image!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Builder(
                        builder: (context) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final maxW = max * 0.9;
                          final w = (maxW * dpr).round();
                          return CachedNetworkImage(
                            imageUrl: image!,
                            width: maxW,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            memCacheWidth: w,
                            maxWidthDiskCache: w,
                            errorWidget: (_, __, ___) {
                              return Container(
                                width: maxW,
                                height: 200,
                                color: AppColors.getSurfaceMutedColor(context),
                                child: Icon(
                                  CupertinoIcons.photo,
                                  size: 40,
                                  color: AppColors.getIconSecondaryColor(context),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  // ─── Текст (если есть) ───
                  if (text.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                  // ─── Время ───
                  Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextTertiaryColor(context),
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

/// ─── Компонент ввода сообщений (в стиле comments_bottom_sheet) ───
class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback? onFocus;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    this.onFocus,
  });

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // ─── Вызываем колбэк при получении фокуса ───
    if (_focusNode.hasFocus && widget.onFocus != null) {
      widget.onFocus!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          // ─── Нижняя граница, как у AppBar ───
          border: Border(
            top: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 0.5,
            ),
          ),
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            final isEnabled = hasText;

            return Row(
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.plus_circle),
                  onPressed: widget.onPickImage,
                  color: AppColors.getIconSecondaryColor(context),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
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
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceMuted
                          : AppColors.softBg,
                    ),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: isEnabled ? widget.onSend : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.send,
                    size: 22,
                    color: isEnabled
                        ? AppColors.brandPrimary
                        : AppColors.getTextPlaceholderColor(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
