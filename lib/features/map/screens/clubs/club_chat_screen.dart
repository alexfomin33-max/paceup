// lib/features/map/screens/clubs/club_chat_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../core/utils/feed_date.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../features/profile/screens/profile_screen.dart';

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
  final String messageType; // 'text' или 'image'
  final String? text;
  final String? imageUrl;
  final String createdAt;
  final bool isMine;
  final bool isRead;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.messageType,
    this.text,
    this.imageUrl,
    required this.createdAt,
    required this.isMine,
    required this.isRead,
  });

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    return _ChatMessage(
      id: json['id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      senderName: json['sender_name'] ?? 'Пользователь',
      senderAvatar: json['sender_avatar'],
      messageType: json['message_type'] ?? 'text',
      text: json['text'],
      imageUrl: json['image'],
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
  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

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
        });

        _startPolling();

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

  // ─── Загрузка дополнительных сообщений (пагинация) ───
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _chatData == null) return;

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
      if (_lastMessageId == null || _chatData == null) return;

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
            setState(() {
              _messages.addAll(newMessages);
              _lastMessageId = newMessages.last.id;
            });

            // ─── Прокручиваем вниз при получении новых сообщений ───
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
            content: Text('Ошибка удаления сообщения: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ─── Отправка текстового сообщения ───
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _chatData == null) return;

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.post(
        '/send_club_chat_message.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
          'text': text,
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
          messageType: 'text',
          text: text,
          createdAt: response['created_at'] ?? DateTime.now().toIso8601String(),
          isMine: true,
          isRead: false,
        );

        if (mounted) {
          setState(() {
            _messages.add(newMessage);
            _lastMessageId = newMessage.id;
          });

          // ─── Прокручиваем вниз после отправки сообщения ───
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
        },
        timeout: const Duration(seconds: 60),
      );

      if (response['success'] == true) {
        // Перезагружаем сообщения для получения правильного URL изображения
        await _loadChatData();

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

  // ─── Форматирование даты и времени создания чата ───
  String _formatChatDate(DateTime? date) {
    return formatFeedDateText(date: date);
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
    setState(() {
      _fullscreenImageUrl = imageUrl;
    });
  }

  void _hideFullscreenImage() {
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

    return InteractiveBackSwipe(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? AppColors.getSurfaceColor(context)
                : AppColors.getBackgroundColor(context),
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
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 18,
                ),
              ),
              titleSpacing: -8,
              title: Transform.translate(
                offset: const Offset(8, 0),
                child: Row(
                  children: [
                    if (chatData.clubLogoUrl != null &&
                        chatData.clubLogoUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        child: Builder(
                          builder: (context) {
                            final dpr = MediaQuery.of(context).devicePixelRatio;
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
              onTap: () {
                FocusScope.of(context).unfocus();
                // ─── Сбрасываем выбор сообщения для удаления ───
                if (_selectedMessageIdForDelete != null) {
                  setState(() {
                    _selectedMessageIdForDelete = null;
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

                        // ─── Основной контент (дата создания чата) ───
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              // 0 — дата создания чата
                              if (index == 0) {
                                return _DateSeparator(
                                  text: _formatChatDate(chatData.chatCreatedAt),
                                );
                              }

                              return const SizedBox.shrink();
                            }, childCount: 1),
                          ),
                        ),

                        // ─── Divider ───
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                Divider(
                                  height: 16,
                                  thickness: 0.5,
                                  color: AppColors.getDividerColor(context),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ),

                        // ─── Сообщения ───
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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

                              return msg.isMine
                                  ? _BubbleRight(
                                      text: msg.text ?? '',
                                      image: msg.messageType == 'image'
                                          ? msg.imageUrl
                                          : null,
                                      time: _formatTime(msg.createdAt),
                                      messageId: msg.id,
                                      isSelectedForDelete:
                                          _selectedMessageIdForDelete == msg.id,
                                      onLongPress: () {
                                        setState(() {
                                          _selectedMessageIdForDelete = msg.id;
                                        });
                                      },
                                      onDelete: () => _showDeleteConfirmation(msg.id),
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
                                      time: _formatTime(msg.createdAt),
                                      senderName: msg.senderName,
                                      senderId: msg.senderId,
                                      avatarUrl: msg.senderAvatar,
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
                            }, childCount: _calculateTotalItemsCount()),
                          ),
                        ),
                      ],
                    ),
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
  final String time;
  final String senderName;
  final int senderId;
  final String? avatarUrl;
  final double topSpacing;
  final double bottomSpacing;
  final VoidCallback? onImageTap;
  const _BubbleLeft({
    required this.text,
    this.image,
    required this.time,
    required this.senderName,
    required this.senderId,
    this.avatarUrl,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    this.onImageTap,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Имя пользователя (кликабельное) ───
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                TransparentPageRoute(
                  builder: (_) => ProfileScreen(userId: senderId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 4),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                onTap: () {
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceMuted
                            : AppColors.softBg,
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
                                      memCacheWidth: w,
                                      maxWidthDiskCache: w,
                                      placeholder: (context, url) => Container(
                                        width: maxW,
                                        height: 200,
                                        color: AppColors.getSurfaceMutedColor(
                                          context,
                                        ),
                                        child: Center(
                                          child: CupertinoActivityIndicator(
                                            radius: 12,
                                            color: AppColors.getIconSecondaryColor(
                                              context,
                                            ),
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
        ],
      ),
    );
  }
}

class _BubbleRight extends StatelessWidget {
  final String text;
  final String? image;
  final String time;
  final double topSpacing;
  final double bottomSpacing;
  final int messageId;
  final bool isSelectedForDelete;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onImageTap;
  const _BubbleRight({
    required this.text,
    this.image,
    required this.time,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    required this.messageId,
    this.isSelectedForDelete = false,
    this.onLongPress,
    this.onDelete,
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
          // ─── Иконка удаления (показывается при длительном нажатии) ───
          if (isSelectedForDelete)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: const Icon(
                  CupertinoIcons.delete,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: onLongPress,
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
                                  memCacheWidth: w,
                                  maxWidthDiskCache: w,
                                  placeholder: (context, url) => Container(
                                    width: maxW,
                                    height: 200,
                                    color: AppColors.getSurfaceMutedColor(
                                      context,
                                    ),
                                    child: Center(
                                      child: CupertinoActivityIndicator(
                                        radius: 12,
                                        color: AppColors.getIconSecondaryColor(
                                          context,
                                        ),
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
