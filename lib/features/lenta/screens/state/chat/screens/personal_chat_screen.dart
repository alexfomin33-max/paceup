import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../features/profile/screens/profile_screen.dart';

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
  final String? date; // Отформатированная дата с бэкенда (формат: 20.01.2026)

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.image,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
    this.date,
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
      date: json['date'] as String?,
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
  int? _selectedMessageIdForDelete; // ID сообщения, выбранного для удаления
  int? _selectedMessageIdForReply; // ID сообщения, выбранного для ответа
  /// ID сообщения, для которого открыто меню по тапу (подсветка как при long press)
  int? _messageIdWithMenuOpen;
  /// ID сообщения правого пузыря, для которого открыто меню по тапу
  int? _messageIdWithRightMenuOpen;
  /// Прямоугольник пузыря для затемнения фона
  Rect? _bubbleDimRect;

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
    _bubbleDimRect = null;
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
      if (!mounted) return;
      setState(() {
        _error = 'Пользователь не авторизован';
      });
      return;
    }

    if (!mounted) return;
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
    if (!mounted) return;

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

        if (!mounted) return;
        setState(() {
          _actualChatId = chatId;
          _isLoading = false;
        });

        // После создания чата загружаем сообщения
        await _loadInitial();
        _markMessagesAsRead();
        _startPolling();
      } else {
        if (!mounted) return;
        setState(() {
          _error = response['message'] as String? ?? 'Ошибка создания чата';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
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
        // API возвращает ORDER BY created_at DESC (сначала новые) — используем как есть:
        // при reverse: true индекс 0 рисуется внизу, т.о. сверху старые, снизу новые
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

        if (!mounted) return;
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
        if (!mounted) return;
        setState(() {
          _error =
              response['message'] as String? ?? 'Ошибка загрузки сообщений';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
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
            .toList(); // Старые сообщения добавляем в начало списка

        if (!mounted) return;
        setState(() {
          // При reverse: true и порядке newest-first старые сообщения
          // добавляем в конец списка (отображаются выше на экране)
          _messages.addAll(newMessages);
          _hasMore = response['has_more'] as bool? ?? false;
          _offset += newMessages.length;
          _isLoadingMore = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
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
          maxSide: ImageCompressionPreset.chat.maxSide,
          jpegQuality: ImageCompressionPreset.chat.quality,
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
          if (!mounted) return;
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
        // Получаем полный URL изображения для оптимистичного обновления
        final imageUrl =
            uploadResponse['image_url'] as String? ??
            'https://uploads.paceup.ru/$imagePath';

        // ─── Оптимистичное обновление: добавляем временное сообщение ───
        final now = DateTime.now();
        final tempMessage = ChatMessage(
          id: -1, // Временный ID
          senderId: _currentUserId!,
          text: '', // Пустой текст для сообщения с изображением
          image: imageUrl, // Полный URL изображения
          createdAt: now,
          isMine: true,
          isRead: false,
          date: _formatDateForBackend(now), // Форматируем дату на клиенте для временного сообщения
        );

        setState(() {
          // При reverse: true индекс 0 внизу — добавляем в начало,
          // чтобы новое сообщение сразу отображалось внизу
          _messages.insert(0, tempMessage);
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
          final createdAt = DateTime.parse(response['created_at'] as String);
          final date = response['date'] as String? ??
              _formatDateForBackend(createdAt);

        // Обновляем временное сообщение с реальными данными
        if (!mounted) return;
        setState(() {
          // Ищем временное сообщение (id == -1), при insert(0) оно в начале
          final index = _messages.indexWhere((m) => m.id == -1);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: messageId,
              senderId: _currentUserId!,
              text: '',
              image: imageUrl, // Используем тот же URL
              createdAt: createdAt,
              isMine: true,
              isRead: false,
              date: date,
            );
          }
          _lastMessageId = messageId;
          // Дедупликация по id: polling мог уже добавить это сообщение
          final seen = <int>{};
          _messages.removeWhere((m) => !seen.add(m.id));
        });
        } else {
          // Удаляем временное сообщение при ошибке
          if (!mounted) return;
          setState(() {
            _messages.removeWhere((m) => m.id == -1);
          });
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
      // Удаляем временное сообщение при ошибке (если было добавлено)
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == -1);
      });
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

        // Оптимистичное обновление UI
        final now = DateTime.now();
        final tempMessage = ChatMessage(
          id: -1, // Временный ID
          senderId: _currentUserId!,
          text: messageText,
          createdAt: now,
          isMine: true,
          isRead: false,
          date: _formatDateForBackend(now), // Форматируем дату на клиенте для временного сообщения
        );

        setState(() {
          // При reverse: true индекс 0 внизу — добавляем в начало,
          // чтобы новое сообщение сразу отображалось внизу
          _messages.insert(0, tempMessage);
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
          if (!mounted) return;
          setState(() {
            _actualChatId = chatId;
          });
        } else {
          // Удаляем временное сообщение при ошибке
          if (!mounted) return;
          setState(() {
            _messages.removeWhere((m) => m.id == -1);
          });
          return;
        }
      } catch (e) {
        // Удаляем временное сообщение при ошибке
        if (!mounted) return;
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
        final date = response['date'] as String? ??
            _formatDateForBackend(createdAt);

        // Обновляем временное сообщение с реальными данными
        if (!mounted) return;
        setState(() {
          // Ищем временное сообщение (id == -1), при insert(0) оно в начале
          final index = _messages.indexWhere((m) => m.id == -1);
          if (index != -1) {
            _messages[index] = ChatMessage(
              id: messageId,
              senderId: _currentUserId!,
              text: messageText,
              createdAt: createdAt,
              isMine: true,
              isRead: false,
              date: date,
            );
          }
          _lastMessageId = messageId;
          // Дедупликация по id: polling мог уже добавить это сообщение,
          // оставляем первое вхождение по id
          final seen = <int>{};
          _messages.removeWhere((m) => !seen.add(m.id));
        });
      } else {
        // Удаляем временное сообщение при ошибке
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == -1);
        });
      }
    } catch (e) {
      // Удаляем временное сообщение при ошибке
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == -1);
      });
    }
  }

  /// ─── Показ диалога подтверждения удаления ───
  Future<void> _showDeleteConfirmation(int messageId) async {
    if (!mounted) return;
    
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Это действие нельзя отменить'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMessage(messageId);
    }
  }

  // ────────────────────────────────────────────────────────────────
  // ─── Затемнение фона при открытом меню пузыря ───────────────────
  // ────────────────────────────────────────────────────────────────
  void _showBubbleDimOverlay(Rect bubbleRect) {
    setState(() => _bubbleDimRect = bubbleRect);
  }

  void _hideBubbleDimOverlay() {
    if (!mounted) return;
    setState(() => _bubbleDimRect = null);
  }

  /// ─── Меню по тапу на левый пузырь: Ответить, Копировать, Пожаловаться ───
  void _showLeftBubbleMoreMenu(BuildContext bubbleContext, ChatMessage message) {
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;
    final overlayBox =
        overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    // Подсветка пузыря как при долгом нажатии
    setState(() => _messageIdWithMenuOpen = message.id);
    final bubbleRect = Rect.fromPoints(
      box.localToGlobal(Offset.zero),
      box.localToGlobal(box.size.bottomRight(Offset.zero)),
    );
    _showBubbleDimOverlay(bubbleRect);
    final position = RelativeRect.fromRect(
      bubbleRect,
      Offset.zero & overlayBox.size,
    );
    showMenu<String>(
      context: context,
      position: position,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xll),
      ),
      color: AppColors.surface,
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.arrowshape_turn_up_left,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'Ответить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_on_doc,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'Копировать',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'report',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'Пожаловаться',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (mounted) setState(() => _messageIdWithMenuOpen = null);
      _hideBubbleDimOverlay();
      if (value == null) return;
      switch (value) {
        case 'reply':
        case 'copy':
        case 'report':
          break;
      }
    });
  }

  /// ─── Меню по тапу на правый пузырь: Ответить, Копировать, Изменить, Удалить ───
  void _showRightBubbleMoreMenu(
    BuildContext bubbleContext,
    ChatMessage message,
  ) {
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;
    final overlayBox =
        overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
    setState(() => _messageIdWithRightMenuOpen = message.id);
    final bubbleRect = Rect.fromPoints(
      box.localToGlobal(Offset.zero),
      box.localToGlobal(box.size.bottomRight(Offset.zero)),
    );
    _showBubbleDimOverlay(bubbleRect);
    final position = RelativeRect.fromRect(
      bubbleRect,
      Offset.zero & overlayBox.size,
    );
    showMenu<String>(
      context: context,
      position: position,
      useRootNavigator: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xll),
      ),
      color: AppColors.surface,
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.arrowshape_turn_up_left,
                size: 22,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'Ответить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_on_doc,
                size: 22,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'Копировать',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 22,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 12),
              Text(
                'Изменить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.delete,
                size: 22,
                color: AppColors.error,
              ),
              SizedBox(width: 12),
              Text(
                'Удалить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (mounted) setState(() => _messageIdWithRightMenuOpen = null);
      _hideBubbleDimOverlay();
      if (value == null) return;
      switch (value) {
        case 'reply':
          break;
        case 'copy':
          break;
        case 'edit':
          break;
        case 'delete':
          _showDeleteConfirmation(message.id);
          break;
      }
    });
  }

  /// ─── Удаление сообщения ───
  Future<void> _deleteMessage(int messageId) async {
    if (_currentUserId == null) return;

    final chatId = _actualChatId ?? widget.chatId;
    if (chatId == 0) return;

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.post(
        '/delete_message.php',
        body: {
          'chat_id': chatId.toString(),
          'user_id': _currentUserId.toString(),
          'message_id': messageId.toString(),
        },
      );

      if (response['success'] == true) {
        if (!mounted) return;
        setState(() {
          _messages.removeWhere((m) => m.id == messageId);
          _selectedMessageIdForDelete = null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] as String? ?? 'Ошибка удаления сообщения',
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
              ErrorHandler.formatWithContext(e, context: 'удалении сообщения'),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
              .toList(); // Новые сообщения добавляем в конец списка

          if (uniqueNewMessages.isNotEmpty) {
            setState(() {
              // Порядок newest-first: новые с сервера (хронология) вставляем
              // в начало, чтобы отображались внизу при reverse: true
              _messages.insertAll(
                0,
                uniqueNewMessages.reversed,
              );
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

  /// ─── Форматирование даты для бэкенда (формат: дд.мм.гггг) ───
  /// Используется для временных сообщений до получения ответа от сервера
  String _formatDateForBackend(DateTime dt) {
    return DateFormat('dd.MM.yyyy').format(dt);
  }

  /// ─── Форматирование даты сообщения (без времени) ───
  String _formatMessageDate(DateTime dt) {
    final now = DateTime.now();
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDate == today) {
      return 'Сегодня';
    }
    if (messageDate == yesterday) {
      return 'Вчера';
    }

    // Иначе — полная дата с месяцем (родительный падеж)
    final monthName = _getMonthNameGenitive(dt.month);

    // Если тот же год — год не показываем
    if (dt.year == now.year) {
      return '${dt.day} $monthName';
    }

    // Если другой год — показываем год
    return '${dt.day} $monthName ${dt.year}';
  }

  /// ─── Получение названия месяца в родительном падеже ───
  String _getMonthNameGenitive(int month) {
    const months = [
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
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  /// ─── Проверка, нужно ли показывать разделитель даты после сообщения ───
  /// При reverse: true дата показывается ПОСЛЕ последнего сообщения за эту дату,
  /// чтобы визуально отображаться НАД всеми сообщениями за эту дату
  bool _shouldShowDateSeparator(int currentIndex) {
    if (currentIndex >= _messages.length) return false;

    try {
      final currentMsg = _messages[currentIndex];
      
      // Если у сообщения нет даты с бэкенда, не показываем разделитель
      if (currentMsg.date == null || currentMsg.date!.isEmpty) {
        return false;
      }

      // Если это последнее сообщение в списке, показываем дату после него
      if (currentIndex == _messages.length - 1) {
        return true;
      }

      // Если следующее сообщение имеет другую дату, показываем дату после текущего
      // (это последнее сообщение за текущую дату)
      final nextMsg = _messages[currentIndex + 1];
      
      // Сравниваем даты по полю date (если оно есть)
      if (nextMsg.date != null && nextMsg.date!.isNotEmpty) {
        return currentMsg.date != nextMsg.date;
      }

      // Если у следующего сообщения нет date, сравниваем по createdAt
      final currentDay = DateTime(
        currentMsg.createdAt.year,
        currentMsg.createdAt.month,
        currentMsg.createdAt.day,
      );
      final nextDay = DateTime(
        nextMsg.createdAt.year,
        nextMsg.createdAt.month,
        nextMsg.createdAt.day,
      );

      return currentDay != nextDay;
    } catch (_) {
      return false;
    }
  }

  /// ─── Подсчет общего количества элементов (сообщения + разделители дат) ───
  int _calculateTotalItemsCount() {
    int count = _messages.length;
    // Добавляем разделители дат над первым сообщением каждой даты
    for (int i = 0; i < _messages.length; i++) {
      if (_shouldShowDateSeparator(i)) {
        count++;
      }
    }
    return count;
  }

  /// ─── Получение URL аватара ───
  String _getAvatarUrl(String avatar) {
    if (avatar.isEmpty) {
      return 'https://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    // ⚡️ Используем правильный путь: /images/users/avatars/{user_id}/{avatar}
    return 'https://uploads.paceup.ru/images/users/avatars/${widget.userId}/$avatar';
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
              
              elevation: 0,
              scrolledUnderElevation: 0, // ─── Убираем тень при скролле ───
              leadingWidth: 40,
              leading: Transform.translate(
                offset: const Offset(0, 0),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
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
              title: Transform.translate(
                offset: const Offset(8, 0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) =>
                            ProfileScreen(userId: widget.userId),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
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
                            // ── Встроенная анимация fade-in работает по умолчанию
                            memCacheWidth: w,
                            maxWidthDiskCache: w,
                            placeholder: (context, url) => Container(
                              width: 36,
                              height: 36,
                              color: AppColors.getSurfaceMutedColor(context),
                              child: Center(
                                child: CupertinoActivityIndicator(
                                  radius: 8,
                                  color: AppColors.getIconSecondaryColor(context),
                                ),
                              ),
                            ),
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
                                    color: AppColors.getSurfaceMutedColor(
                                      context,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.person,
                                      size: 20,
                                      color: AppColors.getIconSecondaryColor(
                                        context,
                                      ),
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
              ),
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
                // ─── Сбрасываем выбор сообщения для удаления, ответа и меню ───
                if (_selectedMessageIdForDelete != null ||
                    _selectedMessageIdForReply != null ||
                    _messageIdWithMenuOpen != null ||
                    _messageIdWithRightMenuOpen != null) {
                  setState(() {
                    _selectedMessageIdForDelete = null;
                    _selectedMessageIdForReply = null;
                    _messageIdWithMenuOpen = null;
                    _messageIdWithRightMenuOpen = null;
                  });
                }
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
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
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
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }

                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollStartNotification) {
                            // При reverse: true старые сообщения загружаются при прокрутке вверх
                            // (к позиции maxScrollExtent)
                            if (_scrollController.hasClients) {
                              final isNearTop =
                                  _scrollController.position.pixels >=
                                  _scrollController.position.maxScrollExtent -
                                      100;
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
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            // Базовый отступ для панели ввода
                            8,
                            12,
                            0,
                          ),
                          itemCount:
                              _calculateTotalItemsCount() +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // При reverse: true индексы идут в обратном порядке
                            final totalItems = _calculateTotalItemsCount();
                            if (index == totalItems && _isLoadingMore) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: CupertinoActivityIndicator(),
                                ),
                              );
                            }

                            // ─── Вычисляем, какой элемент показывать ───
                            // При reverse: true элементы отображаются снизу вверх
                            // Поэтому дата должна идти ПОСЛЕ сообщения в коде,
                            // чтобы визуально отображаться НАД ним на экране
                            int messageIndex = 0;
                            int currentItem = 0;

                            for (int i = 0; i < _messages.length; i++) {
                              // ─── Показываем само сообщение ───
                              if (currentItem == index) {
                                messageIndex = i;
                                break;
                              }
                              currentItem++;

                              // ─── Показываем разделитель даты НАД сообщением ───
                              // При reverse: true дата показывается ПОСЛЕ сообщения в коде,
                              // чтобы визуально отображаться НАД ним на экране
                              if (_shouldShowDateSeparator(i)) {
                                if (currentItem == index) {
                                  // Это разделитель даты
                                  final dateText = _messages[i].date ??
                                      _formatMessageDate(
                                        _messages[i].createdAt,
                                      );
                                  return _DateSeparator(text: dateText);
                                }
                                currentItem++;
                              }
                            }

                            if (messageIndex >= _messages.length) {
                              return const SizedBox.shrink();
                            }

                            // При reverse: true последний элемент списка - это первый в массиве
                            final message = _messages[messageIndex];

                            // ─── Отступы между пузырями ───
                            // При reverse: true проверяем, есть ли следующее сообщение
                            // (которое визуально будет выше на экране)
                            bool hasMessageBelow = false;
                            for (int i = messageIndex + 1; i < _messages.length; i++) {
                              if (!_shouldShowDateSeparator(i)) {
                                hasMessageBelow = true;
                                break;
                              }
                            }
                            
                            // Восстанавливаем нормальные отступы между сообщениями
                            // При reverse: true:
                            // - top padding визуально снизу (отступ от нижней панели)
                            // - bottom padding визуально сверху (отступ между сообщениями)
                            final topSpacing = 0.0;
                            // Всегда добавляем отступ снизу (визуально сверху) для разделения сообщений
                            final bottomSpacing = 8.0;

                            return message.isMine
                                ? _BubbleRight(
                                    text: message.text,
                                    image: message.image,
                                    time: _formatTime(message.createdAt),
                                    topSpacing: topSpacing,
                                    bottomSpacing: bottomSpacing,
                                    messageId: message.id,
                                    isSelectedForDelete:
                                        _messageIdWithRightMenuOpen == message.id,
                                    onTap: (bubbleContext) =>
                                        _showRightBubbleMoreMenu(
                                          bubbleContext,
                                          message,
                                        ),
                                    onImageTap:
                                        (message.image?.isNotEmpty ?? false)
                                        ? () => _showFullscreenImage(
                                            message.image!,
                                          )
                                        : null,
                                  )
                                : _BubbleLeft(
                                    text: message.text,
                                    image: message.image,
                                    time: _formatTime(message.createdAt),
                                    avatarUrl: _getAvatarUrl(widget.userAvatar),
                                    messageId: message.id,
                                    isSelectedForReply:
                                        _messageIdWithMenuOpen == message.id,
                                    onTap: (bubbleContext) =>
                                        _showLeftBubbleMoreMenu(
                                          bubbleContext,
                                          message,
                                        ),
                                    onAvatarTap: () {
                                      Navigator.of(context).push(
                                        TransparentPageRoute(
                                          builder: (_) => ProfileScreen(
                                            userId: widget.userId,
                                          ),
                                        ),
                                      );
                                    },
                                    topSpacing: topSpacing,
                                    bottomSpacing: bottomSpacing,
                                    onImageTap:
                                        (message.image?.isNotEmpty ?? false)
                                        ? () => _showFullscreenImage(
                                            message.image!,
                                          )
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
          // ─── Затемнение фона при открытом меню пузыря ───
          if (_bubbleDimRect != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BubbleDimPainter(
                    bubbleRect: _bubbleDimRect!,
                    color: AppColors.scrim40,
                  ),
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

// ────────────────────────────────────────────────────────────────
// ─── Затемнение экрана с «дыркой» под пузырь ────────────────────
// ────────────────────────────────────────────────────────────────
class _BubbleDimPainter extends CustomPainter {
  final Rect bubbleRect;
  final Color color;

  const _BubbleDimPainter({
    required this.bubbleRect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ─── Рисуем затемнение по всему экрану, исключая область пузыря ───
    final fullPath = Path()..addRect(Offset.zero & size);
    final cutoutRect = Rect.fromLTRB(
      bubbleRect.left,
      bubbleRect.top - 4,
      size.width,
      bubbleRect.bottom - 4,
    );
    final bubblePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          cutoutRect,
          const Radius.circular(AppRadius.xl),
        ),
      );
    final diffPath = Path.combine(
      PathOperation.difference,
      fullPath,
      bubblePath,
    );
    final paint = Paint()..color = color;
    canvas.drawPath(diffPath, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleDimPainter oldDelegate) {
    return oldDelegate.bubbleRect != bubbleRect || oldDelegate.color != color;
  }
}

/// ─── Разделитель даты над сообщениями каждой даты ───
/// Дата отображается по центру серым цветом (как время в сообщениях)
class _DateSeparator extends StatelessWidget {
  final String text;
  const _DateSeparator({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Container(
      alignment: Alignment.center,
      width: double.infinity,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.getTextTertiaryColor(context),
        ),
      ),
    ),
  );
}

/// Левый пузырь (сообщения собеседника) — с аватаром
class _BubbleLeft extends StatelessWidget {
  final String text;
  final String? image;
  final String time;
  final String avatarUrl;
  final double topSpacing;
  final double bottomSpacing;
  final int messageId;
  /// Подсветка пузыря (при открытом меню по тапу)
  final bool isSelectedForReply;
  /// Тап по пузырю — открытие меню (Ответить, Копировать, Пожаловаться, Удалить)
  final void Function(BuildContext bubbleContext)? onTap;
  final VoidCallback? onImageTap;
  /// Клик по аватару — переход в профиль собеседника
  final VoidCallback? onAvatarTap;

  const _BubbleLeft({
    required this.text,
    this.image,
    required this.time,
    required this.avatarUrl,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    required this.messageId,
    this.isSelectedForReply = false,
    this.onTap,
    this.onImageTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final max = screenW * 0.75;

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
          GestureDetector(
            onTap: onAvatarTap,
            child: ClipOval(
              child: Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final w = (28 * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    memCacheWidth: w,
                    maxWidthDiskCache: w,
                    placeholder: (context, url) => Container(
                      width: 28,
                      height: 28,
                      color: AppColors.getSurfaceMutedColor(context),
                      child: Center(
                        child: CupertinoActivityIndicator(
                          radius: 6,
                          color: AppColors.getIconSecondaryColor(context),
                        ),
                      ),
                    ),
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
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap != null ? () => onTap!(context) : null,
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: max),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: isSelectedForReply
                        ? Color.lerp(
                            Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurfaceMuted
                                : AppColors.softBg,
                            Colors.black,
                            0.1,
                          )
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceMuted
                            : AppColors.softBg),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.xl),
                      topRight: Radius.circular(AppRadius.xl),
                      bottomLeft: Radius.zero,
                      bottomRight: Radius.circular(AppRadius.xl),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Изображение (если есть) ───
                      if ((image?.isNotEmpty ?? false)) ...[
                        GestureDetector(
                          onTap: onImageTap,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: Builder(
                              builder: (context) {
                                final dpr = MediaQuery.of(context).devicePixelRatio;
                                final maxW = max * 0.9;
                                final w = (maxW * dpr).round();
                                return CachedNetworkImage(
                                  imageUrl: image!,
                                  width: maxW,
                                  fit: BoxFit.cover,
                                  // ── Встроенная анимация fade-in работает по умолчанию
                                  memCacheWidth: w,
                                  maxWidthDiskCache: w,
                                  placeholder: (context, url) => Container(
                                    width: maxW,
                                    height: 200,
                                    color: AppColors.getSurfaceMutedColor(context),
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 12,
                                        color: AppColors.getIconSecondaryColor(context),
                                      ),
                                    ),
                                  ),
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
                      // ─── Текст и время на одной строке ───
                      if (text.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.getTextTertiaryColor(context),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
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
  final int messageId;
  /// Подсветка пузыря (при открытом меню по тапу)
  final bool isSelectedForDelete;
  /// Тап по пузырю — открытие меню (Ответить, Копировать, Изменить, Удалить)
  final void Function(BuildContext bubbleContext)? onTap;
  final VoidCallback? onImageTap;

  const _BubbleRight({
    required this.text,
    this.image,
    required this.time,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    required this.messageId,
    this.isSelectedForDelete = false,
    this.onTap,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onTap != null ? () => onTap!(context) : null,
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: max),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                  decoration: BoxDecoration(
                    color: isSelectedForDelete
                        ? const Color(0xFFe0ffbc)
                        : AppColors.ownBubble,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.xl),
                      topRight: Radius.circular(AppRadius.xl),
                      bottomLeft: Radius.circular(AppRadius.xl),
                      bottomRight: Radius.zero,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Изображение (если есть) ───
                      if ((image?.isNotEmpty ?? false)) ...[
                        GestureDetector(
                          onTap: onImageTap,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: Builder(
                              builder: (context) {
                                final dpr = MediaQuery.of(context).devicePixelRatio;
                                final maxW = max * 0.9;
                                final w = (maxW * dpr).round();
                                return CachedNetworkImage(
                                  imageUrl: image!,
                                  width: maxW,
                                  fit: BoxFit.cover,
                                  // ── Встроенная анимация fade-in работает по умолчанию
                                  memCacheWidth: w,
                                  maxWidthDiskCache: w,
                                  placeholder: (context, url) => Container(
                                    width: maxW,
                                    height: 200,
                                    color: AppColors.getSurfaceMutedColor(context),
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 12,
                                        color: AppColors.getIconSecondaryColor(context),
                                      ),
                                    ),
                                  ),
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
                      // ─── Текст и время на одной строке ───
                      if (text.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.getTextTertiaryColor(context),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
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
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
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
                  icon: const Icon(CupertinoIcons.plus_circle, size: 28),
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
                      fontSize: 15,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Сообщение...',
                      hintStyle: AppTextStyles.h14w4Place.copyWith(
                        fontSize: 15,
                        color: AppColors.getTextPlaceholderColor(context),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xll),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).brightness == Brightness.light
                          ? AppColors.background
                          : AppColors.getSurfaceMutedColor(context),
                    ),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
                const SizedBox(width: 0),
                IconButton(
                  onPressed: isEnabled ? widget.onSend : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    CupertinoIcons.arrow_up_circle_fill,
                    size: 28,
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
        color: AppColors.textPrimary.withValues(
          alpha: 0.95,
        ), // Чёрный фон с прозрачностью
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
                    // ── Встроенная анимация fade-in работает по умолчанию
                    placeholder: (context, url) => Container(
                      color: AppColors.getSurfaceMutedColor(context),
                      child: Center(
                        child: CupertinoActivityIndicator(
                          radius: 16,
                          color: AppColors.getIconSecondaryColor(context),
                        ),
                      ),
                    ),
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
