import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/local_image_compressor.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Экран персонального чата с конкретным пользователем
/// ────────────────────────────────────────────────────────────────────────
class PersonalChatScreen extends ConsumerStatefulWidget {
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
  ConsumerState<PersonalChatScreen> createState() => _PersonalChatScreenState();
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
class _PersonalChatScreenState extends ConsumerState<PersonalChatScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
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
  String? _fullscreenImageUrl; // URL изображения для полноэкранного просмотра

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
      // При reverse: true "вниз" означает позицию 0 (в пределах 200px)
      final isNearBottom = _scrollController.position.pixels <= 200;

      // Прокручиваем только если пользователь уже внизу
      if (!isNearBottom) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        if (animated) {
          // При reverse: true прокрутка вниз = позиция 0
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          // При reverse: true прокрутка вниз = позиция 0
          _scrollController.jumpTo(0);
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
    final auth = ref.read(authServiceProvider);
    final userId = await auth.getUserId();
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
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
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
        _error = ErrorHandler.format(e);
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
      final api = ref.read(apiServiceProvider);
      final response = await api.get(
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

        // Прокрутка вниз после загрузки (при reverse: true это позиция 0)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
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
        _error = ErrorHandler.format(e);
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
      final api = ref.read(apiServiceProvider);
      final response = await api.get(
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
          // При reverse: true старые сообщения добавляются в конец
          _messages.addAll(newMessages);
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
      );
      if (pickedFile != null && _currentUserId != null) {
        final compressed = await compressLocalImage(
          sourceFile: File(pickedFile.path),
          maxSide: 1600,
          jpegQuality: 80,
        );
        await _sendImage(compressed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ErrorHandler.formatWithContext(e, context: 'выборе изображения'),
            ),
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
        final api = ref.read(apiServiceProvider);
        final createResponse = await api.post(
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
              content: Text(
                ErrorHandler.formatWithContext(e, context: 'создании чата'),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    try {
      // Загружаем изображение на сервер
      final api = ref.read(apiServiceProvider);
      final uploadResponse = await api.postMultipart(
        '/upload_chat_image.php',
        files: {'image': imageFile},
        fields: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
        },
      );

      if (uploadResponse['success'] == true) {
        final imagePath = uploadResponse['image_path'] as String;

        // Отправляем сообщение с изображением
        final api = ref.read(apiServiceProvider);
        final response = await api.post(
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

          // Обновляем last_message_id - polling сам добавит сообщение
          // Это предотвращает дублирование сообщений
          setState(() {
            _lastMessageId = messageId;
          });

          // Небольшая задержка перед проверкой новых сообщений
          // чтобы сервер успел обработать запрос
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _checkNewMessages();
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] as String? ?? 'Ошибка отправки сообщения',
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
            content: Text(
              ErrorHandler.formatWithContext(
                e,
                context: 'отправке изображения',
              ),
            ),
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
      // При reverse: true новые сообщения добавляются в конец списка
      // чтобы они отображались внизу экрана
      _messages.add(tempMessage);
    });

    // Прокрутка вниз (при reverse: true это позиция 0)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Если чат еще не создан, создаем его перед отправкой сообщения
    int chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0 && _currentUserId != null) {
      try {
        final api = ref.read(apiServiceProvider);
        final createResponse = await api.post(
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
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
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
          // Ищем последнее временное сообщение (id == -1) в конце списка
          final index = _messages.lastIndexWhere((m) => m.id == -1);
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
      final api = ref.read(apiServiceProvider);
      await api.post(
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
      final api = ref.read(apiServiceProvider);
      final response = await api.get(
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

          // ─── Защита от дубликатов: проверяем ID перед добавлением ───
          final existingIds = _messages.map((m) => m.id).toSet();
          final uniqueNewMessages = newMessages
              .where((m) => !existingIds.contains(m.id))
              .toList();

          if (uniqueNewMessages.isNotEmpty) {
            setState(() {
              // При reverse: true новые сообщения добавляются в конец списка
              // чтобы они отображались внизу экрана
              _messages.addAll(uniqueNewMessages);
              // Всегда обновляем на максимальный ID, если он больше текущего
              if (maxNewId > (lastId)) {
                _lastMessageId = maxNewId;
              }
            });

            // Отмечаем новые сообщения как прочитанные, если они от другого пользователя
            // и пользователь находится в чате (экран открыт)
            final hasIncomingMessages = uniqueNewMessages.any(
              (msg) => !msg.isMine,
            );
            if (hasIncomingMessages) {
              _markMessagesAsRead();
            }

            // Прокрутка вниз при получении новых сообщений
            // Только если пользователь уже находится внизу списка
            if (_scrollController.hasClients) {
              // При reverse: true "вниз" означает позицию 0 (в пределах 100px)
              final isNearBottom = _scrollController.position.pixels <= 100;

              if (isNearBottom) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && mounted) {
                    // При reverse: true прокрутка вниз = позиция 0
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
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

  /// ─── Показать изображение в полноэкранном режиме ───
  void _showFullscreenImage(String imageUrl) {
    setState(() {
      _fullscreenImageUrl = imageUrl;
    });
  }

  /// ─── Скрыть полноэкранное изображение ───
  void _hideFullscreenImage() {
    setState(() {
      _fullscreenImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.surface
            : AppColors.getBackgroundColor(context),
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
                if (!context.mounted) return;
                Navigator.pop(
                  context,
                  true,
                ); // Возвращаем true для обновления списка
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
                      errorWidget: (context, imageUrl, error) {
                        return Image.asset(
                          'assets/${widget.userAvatar}',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
                        // При reverse: true старые сообщения загружаются при прокрутке вверх
                        // (к позиции maxScrollExtent)
                        if (_scrollController.hasClients) {
                          final isNearTop =
                              _scrollController.position.pixels >=
                              _scrollController.position.maxScrollExtent - 100;
                          if (isNearTop && _hasMore && !_isLoadingMore) {
                            _loadMore();
                          }
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      // ─── Padding: прижимаем сообщения к нижней панели ввода ───
                      // Верхний padding для панели ввода, нижний минимальный
                      padding: EdgeInsets.fromLTRB(
                        12,
                        // Базовый отступ для панели ввода
                        8,
                        12,
                        0,
                      ),
                      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // При reverse: true индексы идут в обратном порядке
                        if (index == _messages.length && _isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CupertinoActivityIndicator()),
                          );
                        }

                        // При reverse: true последний элемент списка - это первый в массиве
                        final messageIndex = _messages.length - 1 - index;
                        final message = _messages[messageIndex];

                        // ─── Фиксированный отступ между всеми пузырями ───
                        // При reverse: true выше на экране = меньший messageIndex в массиве
                        // Проверяем, есть ли сообщение с меньшим messageIndex (которое выше на экране)
                        final hasMessageAbove = messageIndex > 0;
                        final topSpacing = hasMessageAbove ? 8.0 : 0.0;
                        // Нижний отступ только для самого нижнего пузыря (index == 0)
                        final bottomSpacing = index == 0 ? 8.0 : 0.0;

                        return message.isMine
                            ? _BubbleRight(
                                text: message.text,
                                image: message.image,
                                time: _formatTime(message.createdAt),
                                topSpacing: topSpacing,
                                bottomSpacing: bottomSpacing,
                                onImageTap: message.image != null &&
                                        message.image!.isNotEmpty
                                    ? () => _showFullscreenImage(message.image!)
                                    : null,
                              )
                            : _BubbleLeft(
                                text: message.text,
                                image: message.image,
                                time: _formatTime(message.createdAt),
                                avatarUrl: _getAvatarUrl(widget.userAvatar),
                                topSpacing: topSpacing,
                                bottomSpacing: bottomSpacing,
                                onImageTap: message.image != null &&
                                        message.image!.isNotEmpty
                                    ? () => _showFullscreenImage(message.image!)
                                    : null,
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
          // ─── Overlay для полноэкранного просмотра изображения ───
          if (_fullscreenImageUrl != null)
            _FullscreenImageOverlay(
              imageUrl: _fullscreenImageUrl!,
              onClose: _hideFullscreenImage,
            ),
        ],
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
  final double topSpacing;
  final double bottomSpacing;
  final VoidCallback? onImageTap;

  const _BubbleLeft({
    required this.text,
    this.image,
    required this.time,
    required this.avatarUrl,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final max = screenW * 0.72;

    return Padding(
      padding: EdgeInsets.only(
        right: 12,
        left: 0,
        top: topSpacing,
        bottom: bottomSpacing,
      ),
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
                  errorWidget: (context, url, error) => Container(
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
                    GestureDetector(
                      onTap: onImageTap,
                      child: ClipRRect(
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
                              errorWidget: (context, url, error) {
                                return Container(
                                  width: maxW,
                                  height: 200,
                                  color: AppColors.getSurfaceMutedColor(
                                    context,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.photo,
                                    size: 40,
                                    color: AppColors.getIconSecondaryColor(
                                      context,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
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
  final double topSpacing;
  final double bottomSpacing;
  final VoidCallback? onImageTap;

  const _BubbleRight({
    required this.text,
    this.image,
    required this.time,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.75;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 0,
        top: topSpacing,
        bottom: bottomSpacing,
      ),
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
                    ? AppColors.brandPrimary.withValues(alpha: 0.2)
                    : AppColors.blueBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Изображение (если есть) ───
                  if (image != null && image!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: onImageTap,
                      child: ClipRRect(
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
                              errorWidget: (context, url, error) {
                                return Container(
                                  width: maxW,
                                  height: 200,
                                  color: AppColors.getSurfaceMutedColor(
                                    context,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.photo,
                                    size: 40,
                                    color: AppColors.getIconSecondaryColor(
                                      context,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
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

/// ────────────────────────────────────────────────────────────────────────
/// Overlay для полноэкранного просмотра изображения на той же странице
/// ────────────────────────────────────────────────────────────────────────
class _FullscreenImageOverlay extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onClose;

  const _FullscreenImageOverlay({
    required this.imageUrl,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ─── Закрываем при тапе на фон ───
      onTap: onClose,
      child: Container(
        color: AppColors.textPrimary.withValues(alpha: 0.95), // Чёрный фон с прозрачностью
        child: Stack(
          children: [
            // ─── Изображение с возможностью зума ───
            Center(
              child: GestureDetector(
                // ─── Предотвращаем закрытие при тапе на изображение ───
                onTap: () {},
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    fadeInDuration: const Duration(milliseconds: 200),
                    errorWidget: (context, url, error) {
                      return Container(
                        color: AppColors.getSurfaceMutedColor(context),
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 64,
                          color: AppColors.getIconSecondaryColor(context),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ─── Кнопка закрытия (крестик) в верхнем левом углу ───
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  onPressed: onClose,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: AppColors.surface,
                      size: 20,
                    ),
                  ),
                  splashRadius: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
