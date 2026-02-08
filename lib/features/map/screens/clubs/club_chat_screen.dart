// lib/features/map/screens/clubs/club_chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/routes_service.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../features/complaint.dart';
import '../../../../features/profile/screens/profile_screen.dart';
import '../../../../features/lenta/screens/state/chat/widgets/chat_route_card.dart';
import '../../../../features/lenta/screens/state/favorites/tabs/rout_description/rout_description_screen.dart';
import '../../../lenta/screens/state/chat/pinned_chats_api.dart';
import 'club_detail_screen.dart';

/// ─── Экран чата клуба ───
class ClubChatScreen extends ConsumerStatefulWidget {
  final int clubId;

  const ClubChatScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubChatScreen> createState() => _ClubChatScreenState();
}

// ─── Модель сообщения из API ───
class _ChatMessage {
  final int id;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String? senderGender; // Пол отправителя
  final String messageType; // 'text', 'image' или 'route'
  final String? text;
  final String? imageUrl;
  final ChatRouteInfo? route;
  /// ─── ID сообщения, на которое дан ответ ───
  final int? replyToMessageId;
  /// ─── Текст сообщения, на которое дан ответ ───
  final String? replyToText;
  /// ─── Превью ответа (вычисляется один раз) ───
  final String? replyPreviewText;
  final String createdAt;
  final bool isMine;
  final bool isRead;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.senderGender,
    required this.messageType,
    this.text,
    this.imageUrl,
    this.route,
    this.replyToMessageId,
    this.replyToText,
    this.replyPreviewText,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
  });

  // ──────────────────────────────────────────────────────────────
  // ─── Формируем превью ответа (один раз) ───────────────────────
  // ──────────────────────────────────────────────────────────────
  static String? _buildReplyPreviewText({
    required int? replyToMessageId,
    required String? replyToText,
  }) {
    // ─── Если это не ответ, превью не нужно ───
    if (replyToMessageId == null) return null;

    // ─── Берём текст ответа, если он есть ───
    final trimmed = replyToText?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;

    // ─── Фолбэк, если текста нет ───
    return 'Сообщение';
  }

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    // ─── Парсим данные ответа ───
    final replyToMessageId = json['reply_to_message_id'] != null
        ? (json['reply_to_message_id'] as num).toInt()
        : null;
    final replyToText = json['reply_to_text'] as String?;
    final replyPreviewText = _buildReplyPreviewText(
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
    );

    final rawRoute = json['route'];
    final route = rawRoute is Map<String, dynamic>
        ? ChatRouteInfo.fromJson(
            Map<String, dynamic>.from(rawRoute),
          )
        : null;
    final imageUrl = json['image'] as String?;
    var messageType = json['message_type'] ?? 'text';
    if (route != null) {
      messageType = 'route';
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      messageType = 'image';
    }

    return _ChatMessage(
      id: json['id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      senderName: json['sender_name'] ?? 'Пользователь',
      senderAvatar: json['sender_avatar'],
      senderGender: json['sender_gender'],
      messageType: messageType,
      text: json['text'],
      imageUrl: imageUrl,
      route: route,
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      replyPreviewText: replyPreviewText,
      createdAt: json['created_at'] ?? '',
      isMine: json['is_mine'] ?? false,
      isRead: json['is_read'] ?? false,
    );
  }
}

// ─── Данные чата ───
class _ChatData {
  final int chatId;
  final int clubId;
  final String clubName;
  final String? clubLogoUrl;
  final DateTime? chatCreatedAt;

  _ChatData({
    required this.chatId,
    required this.clubId,
    required this.clubName,
    this.clubLogoUrl,
    this.chatCreatedAt,
  });

  factory _ChatData.fromJson(Map<String, dynamic> json) {
    final club = json['club'] as Map<String, dynamic>;
    final chat = json['chat'] as Map<String, dynamic>;
    
    DateTime? chatCreatedAt;
    if (json['chat_created_at'] != null) {
      try {
        chatCreatedAt = DateTime.parse(json['chat_created_at'] as String);
      } catch (_) {}
    }

    return _ChatData(
      chatId: chat['id'] ?? 0,
      clubId: club['id'] ?? 0,
      clubName: club['name'] ?? '',
      clubLogoUrl: club['logo_url'],
      chatCreatedAt: chatCreatedAt,
    );
  }
}

class _ClubChatScreenState extends ConsumerState<ClubChatScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final _api = ApiService();
  final _auth = AuthService();
  final _scrollController = ScrollController();
  /// ─── Ключи сообщений для скролла к ответу ───
  final Map<int, GlobalKey> _messageKeys = {};
  /// ─── Сет текущих ID сообщений ───
  final Set<int> _messageIds = {};
  /// ─── Счетчики ответов по ID сообщения ───
  final Map<int, int> _replyTargetCounts = {};

  _ChatData? _chatData;
  List<_ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;
  int? _lastMessageId;
  Timer? _pollTimer;
  String? _fullscreenImageUrl;
  bool _wasPaused = false;
  DateTime? _lastVisibleTime;
  int? _selectedMessageIdForDelete;
  /// ─── Сообщение, на которое отвечаем (плашка над вводом) ───
  _ChatMessage? _replyMessage;
  /// ─── ID сообщения, которое редактируем (плашка над вводом) ───
  int? _editingMessageId;
  int? _messageIdWithMenuOpen;
  int? _messageIdWithRightMenuOpen;
  Rect? _bubbleDimRect;
  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  /// Закреплён ли чат клуба для отображения в списке «Чаты» (Лента).
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = DateTime.now();
    if (_lastVisibleTime != null &&
        _chatData != null &&
        now.difference(_lastVisibleTime!).inSeconds > 1) {
      _refreshChatData();
    }
    _lastVisibleTime = now;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _scrollController.dispose();
    _pollTimer?.cancel();
    _bubbleDimRect = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      if (_chatData != null) {
        _refreshChatData();
      }
    } else if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    }
  }

  // ─── Обработчик скролла для пагинации ───
  void _onScroll() {
    if (_scrollController.position.pixels <= 200 && _hasMore && !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  // ─── Инициализация чата ───
  Future<void> _initializeChat() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = await _auth.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }
      if (!mounted) return;
      _currentUserId = userId;

      await _loadChatData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── Загрузка данных чата ───
  Future<void> _loadChatData() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.get(
        '/get_club_chat.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
          'offset': '0',
          'limit': '20',
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Ошибка загрузки чата');
      }

      final chatData = _ChatData.fromJson(response);

      DateTime? chatCreatedAt;
      if (response['chat_created_at'] != null) {
        try {
          chatCreatedAt = DateTime.parse(response['chat_created_at'] as String);
        } catch (_) {}
      }

      final messagesData = response['messages'] as List<dynamic>;
      final messages = messagesData
          .map((m) => _ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      if (messages.isNotEmpty) {
        _lastMessageId = messages.last.id;
      }

      if (mounted) {
        setState(() {
          _chatData = chatCreatedAt != null
              ? _ChatData(
                  chatId: chatData.chatId,
                  clubId: chatData.clubId,
                  clubName: chatData.clubName,
                  clubLogoUrl: chatData.clubLogoUrl,
                  chatCreatedAt: chatCreatedAt,
                )
              : chatData;
          _messages = messages;
          _isLoading = false;
          _error = null;
          _offset = messages.length;
          _hasMore = response['has_more'] as bool? ?? false;
          _rebuildReplyTargets();
        });

        _startPolling();

        // ─── Закреплён ли чат (БД, тот же API что и для событий) ───
        final pinned = await PinnedChatsApi.isPinned(
          chatType: 'club',
          referenceId: widget.clubId,
        );
        if (mounted) {
          setState(() => _isPinned = pinned);
        }

        // ─── Прокручиваем вниз после загрузки сообщений ───
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && _messages.isNotEmpty) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Результат для передачи при pop: обновление превью в списке «Чаты».
  Map<String, dynamic>? _buildPopResult() {
    final data = _chatData;
    if (data == null) return null;
    String lastMessage = '';
    DateTime lastMessageAt = data.chatCreatedAt ?? DateTime.now();
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      lastMessage = last.messageType == 'image' &&
              (last.text == null || last.text!.isEmpty)
          ? 'Изображение'
          : (last.text ?? '');
      try {
        lastMessageAt = DateTime.parse(last.createdAt);
      } catch (_) {}
    }
    return {
      'clubId': widget.clubId,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'unpinned': !_isPinned,
    };
  }

  // ─── Загрузка дополнительных сообщений (пагинация) ───
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _chatData == null) return;
    if (!mounted) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.get(
        '/get_club_chat.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
          'offset': _offset.toString(),
          'limit': '20',
        },
      );

      if (response['success'] == true) {
        final messagesData = response['messages'] as List<dynamic>;
        final newMessages = messagesData
            .map((m) => _ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();

        if (mounted) {
          final oldScrollPosition = _scrollController.hasClients
              ? _scrollController.position.pixels
              : 0.0;

          setState(() {
            _messages.insertAll(0, newMessages);
            _offset += newMessages.length;
            _hasMore = response['has_more'] as bool? ?? false;
            _isLoadingMore = false;
            _applyAddedMessages(newMessages);
          });

          // ─── Восстанавливаем позицию скролла ───
          if (_scrollController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final newScrollPosition =
                    _scrollController.position.maxScrollExtent - oldScrollPosition;
                _scrollController.jumpTo(newScrollPosition);
              }
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // ─── Периодический опрос новых сообщений ───
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _lastMessageId == null || _chatData == null) return;

      try {
        final userId = _currentUserId;
        if (userId == null) return;

        final response = await _api.get(
          '/get_club_chat_messages.php',
          queryParams: {
            'club_id': widget.clubId.toString(),
            'user_id': userId.toString(),
            'last_message_id': _lastMessageId.toString(),
          },
        );

        if (response['success'] == true && response['has_new'] == true) {
          final newMessagesData = response['new_messages'] as List<dynamic>;
          final newMessages = newMessagesData
              .map((m) => _ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList();

          if (newMessages.isNotEmpty && mounted) {
            // ─── Дедупликация и пересчет последнего ID ───
            final uniqueNewMessages = _filterUniqueMessages(newMessages);
            final maxNewId = newMessages
                .map((m) => m.id)
                .reduce((a, b) => a > b ? a : b);

            setState(() {
              if (uniqueNewMessages.isNotEmpty) {
                _messages.addAll(uniqueNewMessages);
                _applyAddedMessages(uniqueNewMessages);
              }
              if (_lastMessageId == null || maxNewId > _lastMessageId!) {
                _lastMessageId = maxNewId;
              }
            });

            // ─── Прокручиваем вниз при получении новых сообщений ───
            if (uniqueNewMessages.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Ошибка опроса новых сообщений: $e');
        }
      }
    });
  }

  // ─── Показ диалога подтверждения удаления ───
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

  void _showBubbleDimOverlay(Rect bubbleRect) {
    setState(() => _bubbleDimRect = bubbleRect);
  }

  void _hideBubbleDimOverlay() {
    if (!mounted) return;
    setState(() => _bubbleDimRect = null);
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Ответ, редактирование и копирование ───────────────────────
  // ──────────────────────────────────────────────────────────────
  /// ─── Формируем текст для плашки ответа ───
  String _buildReplyPreview(_ChatMessage message) {
    // ─── Берём текст, если он есть, иначе показываем "Изображение" ───
    final trimmed = (message.text ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (message.messageType == 'route') {
      final routeName = message.route?.name.trim() ?? '';
      return routeName.isNotEmpty ? routeName : 'Маршрут';
    }
    if (message.messageType == 'image') return 'Изображение';
    return 'Сообщение';
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Переход на экран маршрута из сообщения ───────────────────
  // ──────────────────────────────────────────────────────────────
  void _openRouteFromMessage(ChatRouteInfo route) {
    if (route.id <= 0) return;
    final userId = _currentUserId ?? 0;
    final initialRoute = SavedRouteItem(
      id: route.id,
      name: route.name,
      difficulty: route.difficulty,
      distanceKm: route.distanceKm,
      ascentM: route.ascentM,
      routeMapUrl: route.routeMapUrl,
    );
    Navigator.of(context).push(
      TransparentPageRoute(
        builder: (_) => RouteDescriptionScreen(
          routeId: route.id,
          userId: userId,
          initialRoute: initialRoute,
          isInitiallySaved: false,
        ),
      ),
    );
  }

  /// ─── Активируем режим ответа на сообщение ───
  void _startReply(_ChatMessage message) {
    // ─── Снимаем режим редактирования, чтобы не смешивать состояния ───
    if (!mounted) return;
    setState(() {
      _editingMessageId = null;
      _replyMessage = message;
    });
  }

  /// ─── Активируем режим редактирования сообщения ───
  void _startEdit(_ChatMessage message) {
    // ─── Снимаем режим ответа и подставляем текст в поле ввода ───
    if (!mounted) return;
    setState(() {
      _replyMessage = null;
      _editingMessageId = message.id;
    });
    final newText = message.text ?? '';
    _ctrl
      ..text = newText
      ..selection = TextSelection.collapsed(
        offset: newText.length,
      );
  }

  /// ─── Отменяем режим ответа ───
  void _cancelReply() {
    if (!mounted) return;
    setState(() {
      _replyMessage = null;
    });
  }

  /// ─── Отменяем режим редактирования ───
  void _cancelEdit() {
    if (!mounted) return;
    setState(() {
      _editingMessageId = null;
    });
    _ctrl.clear();
  }

  /// ─── Копируем текст сообщения в буфер обмена ───
  Future<void> _copyMessageText(String? text) async {
    // ─── Не копируем пустые строки ───
    final trimmed = (text ?? '').trim();
    if (trimmed.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: trimmed),
    );
  }

  /// ─── Текст для копирования: маршрут → название, иначе → текст ───
  String _resolveCopyText(_ChatMessage message) {
    if (message.messageType == 'route') {
      final routeName = message.route?.name.trim() ?? '';
      return routeName.isNotEmpty ? routeName : 'Маршрут';
    }
    return message.text ?? '';
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Скролл к сообщению (для ответов) ─────────────────────────
  // ──────────────────────────────────────────────────────────────
  void _scrollToMessage(int messageId) {
    // ─── Находим контекст сообщения по ключу ───
    final key = _messageKeys[messageId];
    final targetContext = key?.currentContext;
    if (targetContext == null) return;

    // ─── Плавно скроллим к нужному сообщению ───
    Scrollable.ensureVisible(
      targetContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Полная пересборка ключей для ответов ─────────────────────
  // ──────────────────────────────────────────────────────────────
  void _rebuildReplyTargets() {
    // ─── Пересобираем сет ID сообщений ───
    _messageIds
      ..clear()
      ..addAll(_messages.map((m) => m.id));

    // ─── Пересобираем счетчики ответов ───
    _replyTargetCounts.clear();
    for (final message in _messages) {
      final targetId = message.replyToMessageId;
      if (targetId != null) {
        _replyTargetCounts[targetId] = (_replyTargetCounts[targetId] ?? 0) + 1;
      }
    }

    // ─── Удаляем лишние ключи ───
    _messageKeys.removeWhere(
      (messageId, _) =>
          !_messageIds.contains(messageId) ||
          !_replyTargetCounts.containsKey(messageId),
    );

    // ─── Добавляем ключи для нужных сообщений ───
    for (final targetId in _replyTargetCounts.keys) {
      if (_messageIds.contains(targetId)) {
        _messageKeys.putIfAbsent(targetId, () => GlobalKey());
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Инкрементальное добавление сообщений ─────────────────────
  // ──────────────────────────────────────────────────────────────
  void _applyAddedMessages(Iterable<_ChatMessage> newMessages) {
    // ─── Сначала добавляем ID ───
    for (final message in newMessages) {
      _messageIds.add(message.id);
    }

    // ─── Обновляем счетчики ответов и ключи ───
    for (final message in newMessages) {
      final targetId = message.replyToMessageId;
      if (targetId != null) {
        _replyTargetCounts[targetId] = (_replyTargetCounts[targetId] ?? 0) + 1;
        if (_messageIds.contains(targetId)) {
          _messageKeys.putIfAbsent(targetId, () => GlobalKey());
        }
      }

      // ─── Если новое сообщение является целью ответа ───
      if (_replyTargetCounts.containsKey(message.id)) {
        _messageKeys.putIfAbsent(message.id, () => GlobalKey());
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Инкрементальное удаление сообщений ───────────────────────
  // ──────────────────────────────────────────────────────────────
  void _applyRemovedMessages(Iterable<_ChatMessage> removedMessages) {
    for (final message in removedMessages) {
      // ─── Убираем ID сообщения ───
      _messageIds.remove(message.id);
      _messageKeys.remove(message.id);

      // ─── Обновляем счетчик цели ответа ───
      final targetId = message.replyToMessageId;
      if (targetId != null) {
        final current = _replyTargetCounts[targetId] ?? 0;
        if (current <= 1) {
          _replyTargetCounts.remove(targetId);
          _messageKeys.remove(targetId);
        } else {
          _replyTargetCounts[targetId] = current - 1;
        }
      }
    }

    // ─── Чистим ключи без сообщений ───
    _messageKeys.removeWhere(
      (messageId, _) => !_messageIds.contains(messageId),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Дедупликация новых сообщений ─────────────────────────────
  // ──────────────────────────────────────────────────────────────
  List<_ChatMessage> _filterUniqueMessages(
    Iterable<_ChatMessage> messages,
  ) {
    // ─── Отбрасываем уже присутствующие и дубли в пачке ───
    final unique = <_ChatMessage>[];
    final seen = <int>{};
    for (final message in messages) {
      if (_messageIds.contains(message.id)) {
        continue;
      }
      if (!seen.add(message.id)) {
        continue;
      }
      unique.add(message);
    }
    return unique;
  }

  void _showLeftBubbleMoreMenu(
    BuildContext bubbleContext,
    _ChatMessage message,
  ) {
    final box = bubbleContext.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;
    final overlayBox =
        overlay.context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;
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
          value: 'report',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 22,
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
          _startReply(message);
          break;
        case 'copy':
          _copyMessageText(_resolveCopyText(message));
          break;
        case 'report':
          // ─── Открываем экран жалобы на сообщение ───
          final chatId = _chatData?.chatId ?? 0;
          if (chatId == 0) return;
          Navigator.of(context, rootNavigator: true).push(
            TransparentPageRoute(
              builder: (_) => ComplaintScreen(
                contentType: 'chat_message',
                contentId: message.id,
                chatType: 'club',
                chatId: chatId,
                messageId: message.id,
              ),
            ),
          );
          break;
      }
    });
  }

  void _showRightBubbleMoreMenu(
    BuildContext bubbleContext,
    _ChatMessage message,
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
    // ──────────────────────────────────────────────────────────
    // 🔹 Формируем пункты меню (редактирование только для текста)
    // ──────────────────────────────────────────────────────────
    final items = <PopupMenuEntry<String>>[
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
    ];
    final canEdit = message.messageType == 'text' &&
        (message.text ?? '').trim().isNotEmpty;
    if (canEdit) {
      items.add(
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
      );
    }
    items.add(
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
      items: items,
    ).then((value) {
      if (mounted) setState(() => _messageIdWithRightMenuOpen = null);
      _hideBubbleDimOverlay();
      if (value == null) return;
      switch (value) {
        case 'reply':
          _startReply(message);
          break;
        case 'copy':
          _copyMessageText(_resolveCopyText(message));
          break;
        case 'edit':
          _startEdit(message);
          break;
        case 'delete':
          _showDeleteConfirmation(message.id);
          break;
      }
    });
  }

  // ─── Удаление сообщения ───
  Future<void> _deleteMessage(int messageId) async {
    if (_currentUserId == null || _chatData == null) return;

    try {
      final response = await _api.post(
        '/delete_club_chat_message.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': _currentUserId.toString(),
          'message_id': messageId.toString(),
        },
      );

      if (response['success'] == true) {
        if (!mounted) return;
        setState(() {
          final removed = _messages.where((m) => m.id == messageId).toList();
          _messages.removeWhere((m) => m.id == messageId);
          _selectedMessageIdForDelete = null;
          _applyRemovedMessages(removed);
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
            content: Text('Ошибка удаления сообщения: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // ─── Редактирование сообщения (API) ────────────────────────────
  // ──────────────────────────────────────────────────────────────
  Future<void> _editMessageText({
    required int messageId,
    required String newText,
  }) async {
    // ─── Проверяем базовые условия ───
    if (_currentUserId == null || _chatData == null) return;

    try {
      // ─── Отправляем запрос на редактирование ───
      final response = await _api.post(
        '/edit_club_chat_message.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': _currentUserId.toString(),
          'message_id': messageId.toString(),
          'text': newText,
        },
      );

      if (response['success'] == true) {
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final old = _messages[index];
            _messages[index] = _ChatMessage(
              id: old.id,
              senderId: old.senderId,
              senderName: old.senderName,
              senderAvatar: old.senderAvatar,
              senderGender: old.senderGender,
              messageType: old.messageType,
              text: newText,
              imageUrl: old.imageUrl,
              replyToMessageId: old.replyToMessageId,
              replyToText: old.replyToText,
              replyPreviewText: old.replyPreviewText,
              createdAt: old.createdAt,
              isMine: old.isMine,
              isRead: old.isRead,
            );
          }
          // ─── Сбрасываем режим редактирования ───
          _editingMessageId = null;
        });
        _ctrl.clear();
      }
    } catch (_) {
      // ─── Мягко игнорируем ошибки, чтобы не ломать UI ───
    }
  }

  // ─── Отправка текстового сообщения ───
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _chatData == null) return;

    // ─── Если активен режим редактирования, обновляем сообщение ───
    if (_editingMessageId != null) {
      await _editMessageText(
        messageId: _editingMessageId!,
        newText: text,
      );
      return;
    }

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      // ─── Сохраняем данные ответа до очистки состояния ───
      final replyMessage = _replyMessage;
      final replyToMessageId = replyMessage?.id;
      final replyToText = replyMessage != null
          ? _buildReplyPreview(replyMessage)
          : null;

      final response = await _api.post(
        '/send_club_chat_message.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
          'text': text,
          if (replyToMessageId != null)
            'reply_to_message_id': replyToMessageId,
        },
      );

      if (response['success'] == true) {
        if (!mounted) return;
        _ctrl.clear();

        // Добавляем сообщение сразу в список
        final newMessage = _ChatMessage(
          id: response['message_id'] ?? 0,
          senderId: userId,
          senderName: 'Вы',
          senderGender: null,
          messageType: 'text',
          text: text,
          replyToMessageId: replyToMessageId,
          replyToText: replyToText,
          replyPreviewText: replyToText,
          createdAt: response['created_at'] ?? DateTime.now().toIso8601String(),
          isMine: true,
          isRead: false,
        );

        if (mounted) {
          // ─── Дедупликация, если polling уже добавил сообщение ───
          final uniqueNewMessages = _filterUniqueMessages([newMessage]);
          final nextLastId = newMessage.id;

          setState(() {
            if (uniqueNewMessages.isNotEmpty) {
              _messages.addAll(uniqueNewMessages);
              _applyAddedMessages(uniqueNewMessages);
            }
            if (_lastMessageId == null || nextLastId > _lastMessageId!) {
              _lastMessageId = nextLastId;
            }
            // ─── Сбрасываем плашку ответа после успешной отправки ───
            _replyMessage = null;
          });

          // ─── Прокручиваем вниз после отправки сообщения ───
          if (uniqueNewMessages.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ошибка отправки сообщения: $e');
      }
    }
  }

  // ─── Отправка изображения ───
  Future<void> _pickImage() async {
    if (_chatData == null) return;

    try {
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x == null) return;

      final userId = _currentUserId;
      if (userId == null) return;

      // ─── Сохраняем данные ответа для изображения ───
      final replyToMessageId = _replyMessage?.id;

      // ─── Сжимаем изображение на клиенте ───
      final compressedFile = await compressLocalImage(
        sourceFile: File(x.path),
        maxSide: ImageCompressionPreset.chat.maxSide,
        jpegQuality: ImageCompressionPreset.chat.quality,
      );

      // ─── Отправляем изображение через multipart ───
      final response = await _api.postMultipart(
        '/send_club_chat_message.php',
        files: {'image': compressedFile},
        fields: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
          if (replyToMessageId != null)
            'reply_to_message_id': replyToMessageId.toString(),
        },
        timeout: const Duration(seconds: 60),
      );

      if (response['success'] == true) {
        // Перезагружаем сообщения для получения правильного URL изображения
        await _loadChatData();

        // ─── Сбрасываем плашку ответа после успешной отправки ───
        if (mounted) {
          setState(() {
            _replyMessage = null;
          });
        }

        // ─── Прокручиваем вниз после отправки изображения ───
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ошибка отправки изображения: $e');
      }
    }
  }

  // ─── Обновление данных чата ───
  Future<void> _refreshChatData() async {
    if (_chatData == null) return;
    try {
      await _loadChatData();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Ошибка обновления данных чата: $e');
      }
    }
  }

  // ─── Форматирование времени ───
  String _formatTime(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return '';
    }
  }

  // ─── Форматирование даты сообщения (без времени) ───
  String _formatMessageDate(String dateTimeStr) {
    try {
      final dt = DateTime.parse(dateTimeStr);
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
    } catch (_) {
      return '';
    }
  }

  // ─── Получение названия месяца в родительном падеже ───
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

  // ─── Проверка, нужно ли показывать разделитель даты между сообщениями ───
  bool _shouldShowDateSeparator(int currentIndex) {
    if (currentIndex == 0) return false; // Первое сообщение
    if (currentIndex >= _messages.length) return false;

    try {
      final currentMsg = _messages[currentIndex];
      final previousMsg = _messages[currentIndex - 1];

      final currentDate = DateTime.parse(currentMsg.createdAt);
      final previousDate = DateTime.parse(previousMsg.createdAt);

      final currentDay = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      );
      final previousDay = DateTime(
        previousDate.year,
        previousDate.month,
        previousDate.day,
      );

      return currentDay != previousDay;
    } catch (_) {
      return false;
    }
  }

  // ─── Подсчет общего количества элементов (сообщения + разделители дат) ───
  int _calculateTotalItemsCount() {
    if (_messages.isEmpty) return 0;
    int count = _messages.length;
    // Добавляем разделитель даты перед первым сообщением
    count++;
    // Добавляем разделители дат перед каждым сообщением, кроме первого
    for (int i = 1; i < _messages.length; i++) {
      if (_shouldShowDateSeparator(i)) {
        count++;
      }
    }
    return count;
  }

  void _showFullscreenImage(String imageUrl) {
    if (!mounted) return;
    setState(() {
      _fullscreenImageUrl = imageUrl;
    });
  }

  void _hideFullscreenImage() {
    if (!mounted) return;
    setState(() {
      _fullscreenImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getSurfaceColor(context)
            : AppColors.getBackgroundColor(context),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_error != null || _chatData == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getSurfaceColor(context)
            : AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.getSurfaceColor(context),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: SelectableText.rich(
            TextSpan(
              text: 'Ошибка загрузки чата:\n',
              style: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
              children: [
                TextSpan(
                  text: _error ?? 'Неизвестная ошибка',
                  style: AppTextStyles.h14w4.copyWith(color: Colors.red),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final chatData = _chatData!;
    // ─── Высота клавиатуры для сдвига чата ───
    final viewInsets = MediaQuery.of(context).viewInsets;

    return InteractiveBackSwipe(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? AppColors.getSurfaceColor(context)
                : AppColors.getBackgroundColor(context),
            // ─── Ручной сдвиг под клавиатуру ───
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface
                  : AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
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
                  onPressed: () {
                    Navigator.pop(context, _buildPopResult());
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
                            ClubDetailScreen(clubId: widget.clubId),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      if (chatData.clubLogoUrl != null &&
                          chatData.clubLogoUrl!.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          child: Builder(
                            builder: (context) {
                              final dpr =
                                  MediaQuery.of(context).devicePixelRatio;
                              final w = (36 * dpr).round();
                              return CachedNetworkImage(
                                imageUrl: chatData.clubLogoUrl!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                memCacheWidth: w,
                                maxWidthDiskCache: w,
                                placeholder: (context, url) => Container(
                                  width: 36,
                                  height: 36,
                                  color: AppColors.getSurfaceMutedColor(
                                    context,
                                  ),
                                  child: Center(
                                    child: CupertinoActivityIndicator(
                                      radius: 8,
                                      color: AppColors.getIconSecondaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, imageUrl, error) {
                                  return Container(
                                    width: 36,
                                    height: 36,
                                    color: AppColors.getSurfaceMutedColor(
                                      context,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.group,
                                      size: 20,
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
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Чат клуба',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chatData.clubName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isPinned ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    size: 22,
                    color: _isPinned ? AppColors.orange : null,
                  ),
                  onPressed: () async {
                    if (_chatData == null) return;
                    if (_isPinned) {
                      // Удаление из БД (user_pinned_chats)
                      final ok = await PinnedChatsApi.removePinnedChat(
                        chatType: 'club',
                        referenceId: widget.clubId,
                      );
                      if (mounted && ok) setState(() => _isPinned = false);
                    } else {
                      String lastMessage = '';
                      DateTime lastMessageAt =
                          _chatData!.chatCreatedAt ?? DateTime.now();
                      if (_messages.isNotEmpty) {
                        final last = _messages.last;
                        lastMessage = last.messageType == 'image' &&
                                (last.text == null || last.text!.isEmpty)
                            ? 'Изображение'
                            : (last.text ?? '');
                        try {
                          lastMessageAt = DateTime.parse(last.createdAt);
                        } catch (_) {}
                      }
                      // Добавление в БД (user_pinned_chats), тот же API что для событий
                      final ok = await PinnedChatsApi.addPinnedChat(
                        chatType: 'club',
                        referenceId: widget.clubId,
                        chatId: _chatData!.chatId,
                        title: _chatData!.clubName,
                        logoUrl: _chatData!.clubLogoUrl,
                        lastMessage: lastMessage,
                        lastMessageAt: lastMessageAt,
                      );
                      if (mounted && ok) setState(() => _isPinned = true);
                    }
                  },
                  color: AppColors.getIconSecondaryColor(context),
                  splashRadius: 22,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0.5),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: AppColors.getBorderColor(context),
                ),
              ),
            ),
            // ─── Сдвигаем чат вверх при появлении клавиатуры ───
            body: AnimatedPadding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  // ─── Сбрасываем выбор сообщения для удаления ───
                  if ((_selectedMessageIdForDelete != null ||
                          _messageIdWithMenuOpen != null ||
                          _messageIdWithRightMenuOpen != null) &&
                      mounted) {
                    setState(() {
                      _selectedMessageIdForDelete = null;
                      _messageIdWithMenuOpen = null;
                      _messageIdWithRightMenuOpen = null;
                    });
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                        // ─── Индикатор загрузки при подгрузке старых сообщений ───
                        if (_isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                          ),

                        // ─── Сообщения ───
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              // ─── Вычисляем, какой элемент показывать ───
                              int messageIndex = 0;
                              int currentItem = 0;

                              for (int i = 0; i < _messages.length; i++) {
                                // ─── Показываем разделитель даты перед первым сообщением ───
                                if (i == 0) {
                                  if (currentItem == index) {
                                    // Это разделитель даты перед первым сообщением
                                    return _DateSeparator(
                                      text: _formatMessageDate(
                                        _messages[i].createdAt,
                                      ),
                                      topPadding: 4,
                                      bottomPadding: 12,
                                    );
                                  }
                                  currentItem++;
                                }

                                // ─── Показываем разделитель даты перед сообщением (кроме первого) ───
                                if (i > 0 && _shouldShowDateSeparator(i)) {
                                  if (currentItem == index) {
                                    // Это разделитель даты
                                    return _DateSeparator(
                                      text: _formatMessageDate(
                                        _messages[i].createdAt,
                                      ),
                                      topPadding: 16,
                                      bottomPadding: 4,
                                    );
                                  }
                                  currentItem++;
                                }

                                // ─── Показываем само сообщение ───
                                if (currentItem == index) {
                                  messageIndex = i;
                                  break;
                                }
                                currentItem++;
                              }

                              if (messageIndex >= _messages.length) {
                                return const SizedBox.shrink();
                              }

                              final msg = _messages[messageIndex];
                              // ─── Данные ответа для превью и скролла ───
                              final replyPreviewText =
                                  msg.replyPreviewText;
                              final replyToMessageId = msg.replyToMessageId;
                              final messageKey = _messageKeys[msg.id];

                              // ─── Определяем отступы между пузырями ───
                              // Проверяем, есть ли предыдущее сообщение (не разделитель даты)
                              bool hasMessageAbove = false;
                              for (int i = messageIndex - 1; i >= 0; i--) {
                                if (!_shouldShowDateSeparator(i)) {
                                  hasMessageAbove = true;
                                  break;
                                }
                              }
                              final topSpacing = hasMessageAbove ? 8.0 : 0.0;

                              // ─── Проверяем, является ли это последним сообщением ───
                              final isLastMessage =
                                  messageIndex == _messages.length - 1;
                              final bottomSpacing = isLastMessage ? 8.0 : 0.0;

                              final bubble = msg.isMine
                                  ? _BubbleRight(
                                      text: msg.text ?? '',
                                      image: msg.messageType == 'image'
                                          ? msg.imageUrl
                                          : null,
                                      messageType: msg.messageType,
                                      route: msg.route,
                                      time: _formatTime(msg.createdAt),
                                      messageId: msg.id,
                                      replyText: replyPreviewText,
                                      onReplyTap: replyToMessageId != null
                                          ? () => _scrollToMessage(
                                              replyToMessageId,
                                            )
                                          : null,
                                      isSelectedForDelete:
                                          _messageIdWithRightMenuOpen == msg.id,
                                      onTap: (bubbleContext) =>
                                          _showRightBubbleMoreMenu(
                                            bubbleContext,
                                            msg,
                                          ),
                                      onRouteTap: msg.route != null
                                          ? () => _openRouteFromMessage(
                                              msg.route!,
                                            )
                                          : null,
                                      topSpacing: topSpacing,
                                      bottomSpacing: bottomSpacing,
                                      onImageTap:
                                          msg.messageType == 'image' &&
                                              msg.imageUrl != null
                                          ? () => _showFullscreenImage(
                                              msg.imageUrl!,
                                            )
                                          : null,
                                    )
                                  : _BubbleLeft(
                                      text: msg.text ?? '',
                                      image: msg.messageType == 'image'
                                          ? msg.imageUrl
                                          : null,
                                      messageType: msg.messageType,
                                      route: msg.route,
                                      time: _formatTime(msg.createdAt),
                                      senderName: msg.senderName,
                                      senderId: msg.senderId,
                                      avatarUrl: msg.senderAvatar,
                                      senderGender: msg.senderGender,
                                      messageId: msg.id,
                                      replyText: replyPreviewText,
                                      onReplyTap: replyToMessageId != null
                                          ? () => _scrollToMessage(
                                              replyToMessageId,
                                            )
                                          : null,
                                      isSelectedForReply:
                                          _messageIdWithMenuOpen == msg.id,
                                      onTap: (bubbleContext) =>
                                          _showLeftBubbleMoreMenu(
                                            bubbleContext,
                                            msg,
                                          ),
                                      onRouteTap: msg.route != null
                                          ? () => _openRouteFromMessage(
                                              msg.route!,
                                            )
                                          : null,
                                      topSpacing: topSpacing,
                                      bottomSpacing: bottomSpacing,
                                      onImageTap:
                                          msg.messageType == 'image' &&
                                              msg.imageUrl != null
                                          ? () => _showFullscreenImage(
                                              msg.imageUrl!,
                                            )
                                          : null,
                                    );

                              // ─── Оборачиваем ключом только нужные сообщения ───
                              return messageKey != null
                                  ? KeyedSubtree(
                                      key: messageKey,
                                      child: bubble,
                                    )
                                  : bubble;
                            }, childCount: _calculateTotalItemsCount()),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Плашка ответа/редактирования над вводом ───
                  if (_replyMessage != null || _editingMessageId != null)
                    _ComposerContextBanner(
                      text: _editingMessageId != null
                          ? 'Редактирование'
                          : _buildReplyPreview(_replyMessage!),
                      onClose: _editingMessageId != null
                          ? _cancelEdit
                          : _cancelReply,
                    ),

                  // Composer
                  _Composer(
                    controller: _ctrl,
                    onSend: _sendText,
                    onPickImage: _pickImage,
                  ),
                  ],
                ),
              ),
            ),
          ),
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

// ─── Компоненты UI ───

class _BubbleDimPainter extends CustomPainter {
  final Rect bubbleRect;
  final Color color;

  const _BubbleDimPainter({
    required this.bubbleRect,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
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

class _DateSeparator extends StatelessWidget {
  final String text;
  final double? topPadding;
  final double? bottomPadding;
  const _DateSeparator({
    required this.text,
    this.topPadding,
    this.bottomPadding,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: topPadding ?? 12,
      bottom: bottomPadding ?? 12,
    ),
    child: Container(
      alignment: Alignment.center,
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

class _BubbleLeft extends StatelessWidget {
  final String text;
  final String? image;
  final String messageType;
  final ChatRouteInfo? route;
  final String time;
  final String senderName;
  final int senderId;
  final String? avatarUrl;
  final String? senderGender;
  final double topSpacing;
  final double bottomSpacing;
  final int messageId;
  /// ─── Текст ответа (если сообщение является ответом) ───
  final String? replyText;
  /// ─── Тап по ответу — скролл к исходному сообщению ───
  final VoidCallback? onReplyTap;
  final bool isSelectedForReply;
  final void Function(BuildContext bubbleContext)? onTap;
  final VoidCallback? onRouteTap;
  final VoidCallback? onImageTap;
  const _BubbleLeft({
    required this.text,
    this.image,
    required this.messageType,
    this.route,
    required this.time,
    required this.senderName,
    required this.senderId,
    this.avatarUrl,
    this.senderGender,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    required this.messageId,
    this.replyText,
    this.onReplyTap,
    this.isSelectedForReply = false,
    this.onTap,
    this.onRouteTap,
    this.onImageTap,
  });

  // ─── Проверка, является ли пол женским ───
  bool get _isFemale {
    if (senderGender == null) return false;
    final gender = senderGender!.toLowerCase();
    return gender == 'женский' ||
        gender == 'female' ||
        gender == 'f' ||
        gender.contains('жен');
  }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipOval(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      TransparentPageRoute(
                        builder: (_) => ProfileScreen(userId: senderId),
                      ),
                    );
                  },
                  child: Builder(
                    builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final w = (28 * dpr).round();
                      final url = avatarUrl ?? '';
                      return CachedNetworkImage(
                        imageUrl: url.isNotEmpty ? url : 'https://uploads.paceup.ru/images/users/avatars/def.png',
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
                onTap: onTap != null
                    ? () => onTap!(context)
                    : () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => ProfileScreen(userId: senderId),
                          ),
                        );
                      },
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
                          // ─── Имя пользователя внутри пузыря ───
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                TransparentPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: senderId,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              senderName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _isFemale
                                    ? AppColors.nameFemale
                                    : AppColors.nameMale,
                              ),
                            ),
                          ),
                          // ─── Плашка ответа (если есть) ───
                          if (replyText != null &&
                              replyText!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _ReplyPreview(
                              text: replyText!,
                              onTap: onReplyTap,
                            ),
                          ],
                          // ────────────────────────────────────────
                          // 🔹 Контент сообщения: маршрут или медиа/текст
                          // ────────────────────────────────────────
                          if (messageType == 'route' && route != null) ...[
                            ChatRouteCard(
                              route: route!,
                              onTap: onRouteTap,
                              onLongPress: onTap != null
                                  ? () => onTap!(context)
                                  : null,
                            ),
                          ] else ...[
                            // ─── Изображение (если есть) ───
                            if ((image?.isNotEmpty ?? false)) ...[
                              GestureDetector(
                                onTap: onImageTap,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xl,
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final dpr = MediaQuery.of(context)
                                          .devicePixelRatio;
                                      final maxW = max * 0.9;
                                      final w = (maxW * dpr).round();
                                      return CachedNetworkImage(
                                        imageUrl: image!,
                                        width: maxW,
                                        fit: BoxFit.cover,
                                        memCacheWidth: w,
                                        maxWidthDiskCache: w,
                                        placeholder: (context, url) =>
                                            Container(
                                          width: maxW,
                                          height: 200,
                                          color:
                                              AppColors.getSurfaceMutedColor(
                                            context,
                                          ),
                                          child: Center(
                                            child: CupertinoActivityIndicator(
                                              radius: 12,
                                              color:
                                                  AppColors.getIconSecondaryColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) {
                                          return Container(
                                            width: maxW,
                                            height: 200,
                                            color:
                                                AppColors.getSurfaceMutedColor(
                                              context,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.photo,
                                              size: 40,
                                              color:
                                                  AppColors.getIconSecondaryColor(
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
                                        color:
                                            AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          AppColors.getTextTertiaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BubbleRight extends StatelessWidget {
  final String text;
  final String? image;
  final String messageType;
  final ChatRouteInfo? route;
  final String time;
  final double topSpacing;
  final double bottomSpacing;
  final int messageId;
  /// ─── Текст ответа (если сообщение является ответом) ───
  final String? replyText;
  /// ─── Тап по ответу — скролл к исходному сообщению ───
  final VoidCallback? onReplyTap;
  final bool isSelectedForDelete;
  final void Function(BuildContext bubbleContext)? onTap;
  final VoidCallback? onRouteTap;
  final VoidCallback? onImageTap;
  const _BubbleRight({
    required this.text,
    this.image,
    required this.messageType,
    this.route,
    required this.time,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    required this.messageId,
    this.replyText,
    this.onReplyTap,
    this.isSelectedForDelete = false,
    this.onTap,
    this.onRouteTap,
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
                      // ─── Плашка ответа (если есть) ───
                      if (replyText != null && replyText!.isNotEmpty) ...[
                        _ReplyPreview(
                          text: replyText!,
                          onTap: onReplyTap,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      // ────────────────────────────────────────
                      // 🔹 Контент сообщения: маршрут или медиа/текст
                      // ────────────────────────────────────────
                      if (messageType == 'route' && route != null) ...[
                        ChatRouteCard(
                          route: route!,
                          onTap: onRouteTap,
                          onLongPress: onTap != null
                              ? () => onTap!(context)
                              : null,
                        ),
                      ] else ...[
                        // ─── Изображение (если есть) ───
                        if ((image?.isNotEmpty ?? false)) ...[
                          GestureDetector(
                            onTap: onImageTap,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.xl,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final dpr = MediaQuery.of(context)
                                      .devicePixelRatio;
                                  final maxW = max * 0.9;
                                  final w = (maxW * dpr).round();
                                  return CachedNetworkImage(
                                    imageUrl: image!,
                                    width: maxW,
                                    fit: BoxFit.cover,
                                    memCacheWidth: w,
                                    maxWidthDiskCache: w,
                                    placeholder: (context, url) =>
                                        Container(
                                      width: maxW,
                                      height: 200,
                                      color:
                                          AppColors.getSurfaceMutedColor(
                                        context,
                                      ),
                                      child: Center(
                                        child: CupertinoActivityIndicator(
                                          radius: 12,
                                          color:
                                              AppColors.getIconSecondaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        width: maxW,
                                        height: 200,
                                        color:
                                            AppColors.getSurfaceMutedColor(
                                          context,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          size: 40,
                                          color:
                                              AppColors.getIconSecondaryColor(
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
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      AppColors.getTextTertiaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
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

/// ──────────────────────────────────────────────────────────────
/// Плашка ответа внутри пузыря сообщения
/// ──────────────────────────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _ReplyPreview({
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ─── Используем жест для перехода к исходному сообщению ───
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceMutedColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border(
            left: BorderSide(
              color: AppColors.brandPrimary,
              width: AppSpacing.xs,
            ),
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h12w4Sec.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Плашка контекста (ответ/редактирование) над полем ввода
/// ──────────────────────────────────────────────────────────────
class _ComposerContextBanner extends StatelessWidget {
  final String text;
  final VoidCallback onClose;

  const _ComposerContextBanner({
    required this.text,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // ─── Контейнер плашки над полем ввода ───
    return Container(
      color: AppColors.getSurfaceColor(context),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          // ─── Текст контекста (ответ или редактирование) ───
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h13w4.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ─── Кнопка закрытия плашки ───
          IconButton(
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              CupertinoIcons.xmark,
              size: 18,
              color: AppColors.getIconSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          border: Border(
            top: BorderSide(
              color: AppColors.getBorderColor(context),
              width: 0.5,
            ),
          ),
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            final isEnabled = hasText;

            return Row(
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.plus_circle, size: 28),
                  onPressed: onPickImage,
                  color: AppColors.getIconSecondaryColor(context),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
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
                  ),
                ),
                const SizedBox(width: 0),
                IconButton(
                  onPressed: isEnabled ? onSend : null,
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
      onTap: onClose,
      child: Container(
        color: AppColors.textPrimary.withValues(alpha: 0.95),
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onTap: () {},
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
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
