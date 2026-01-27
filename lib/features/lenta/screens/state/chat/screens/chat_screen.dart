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
import '../../../../../market/screens/tabs/slots/tradechat_slots_screen.dart';
import '../../../../../market/screens/tabs/things/tradechat_things_screen.dart';

/// Модель чата из API
class ChatItem {
  final int id;
  final String chatType; // 'regular', 'slot' или 'thing'

  // Для обычных чатов
  final int? userId;
  final String? userName;
  final String? userAvatar;

  // Для чатов по продаже слотов
  final int? slotId;
  final String? slotTitle;
  final String? eventLogoUrl;

  // Для чатов по продаже вещей
  final int? thingId;
  final String? thingTitle;
  final String? thingImageUrl;

  final String lastMessage;
  final bool
  lastMessageHasImage; // ─── Флаг наличия изображения в последнем сообщении ───
  final DateTime lastMessageAt;
  final bool unread;
  final DateTime createdAt;

  const ChatItem({
    required this.id,
    required this.chatType,
    this.userId,
    this.userName,
    this.userAvatar,
    this.slotId,
    this.slotTitle,
    this.eventLogoUrl,
    this.thingId,
    this.thingTitle,
    this.thingImageUrl,
    required this.lastMessage,
    required this.lastMessageHasImage,
    required this.lastMessageAt,
    required this.unread,
    required this.createdAt,
  });

  factory ChatItem.fromJson(Map<String, dynamic> json) {
    final chatType = json['chat_type'] as String? ?? 'regular';

    if (chatType == 'slot') {
      return ChatItem(
        id: (json['id'] as num).toInt(),
        chatType: chatType,
        slotId: json['slot_id'] != null
            ? (json['slot_id'] as num).toInt()
            : null,
        slotTitle: json['slot_title'] as String?,
        eventLogoUrl: json['event_logo_url'] as String?,
        lastMessage: json['last_message'] as String? ?? '',
        lastMessageHasImage: json['last_message_has_image'] as bool? ?? false,
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        unread: json['unread'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } else if (chatType == 'thing') {
      return ChatItem(
        id: (json['id'] as num).toInt(),
        chatType: chatType,
        thingId: json['thing_id'] != null
            ? (json['thing_id'] as num).toInt()
            : null,
        thingTitle: json['thing_title'] as String?,
        thingImageUrl: json['thing_image_url'] as String?,
        lastMessage: json['last_message'] as String? ?? '',
        lastMessageHasImage: json['last_message_has_image'] as bool? ?? false,
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        unread: json['unread'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } else {
      return ChatItem(
        id: (json['id'] as num).toInt(),
        chatType: chatType,
        userId: json['user_id'] != null
            ? (json['user_id'] as num).toInt()
            : null,
        userName: json['user_name'] as String?,
        userAvatar: json['user_avatar'] as String?,
        lastMessage: json['last_message'] as String? ?? '',
        lastMessageHasImage: json['last_message_has_image'] as bool? ?? false,
        lastMessageAt: DateTime.parse(json['last_message_at'] as String),
        unread: json['unread'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    }
  }

  bool get isSlotChat => chatType == 'slot';
  bool get isThingChat => chatType == 'thing';
  bool get isRegularChat => chatType == 'regular';
}

/// ─── Обертка для навигации к TradeChatSlotsScreen ───
class _SlotChatScreenWrapper extends StatelessWidget {
  final int slotId;
  final int? chatId; // ─── chatId для открытия конкретного чата ───

  const _SlotChatScreenWrapper({required this.slotId, this.chatId});

  @override
  Widget build(BuildContext context) {
    return TradeChatSlotsScreen(slotId: slotId, chatId: chatId);
  }
}

/// ─── Обертка для навигации к TradeChatThingsScreen ───
class _ThingChatScreenWrapper extends StatelessWidget {
  final int thingId;
  final int? chatId; // ─── chatId для открытия конкретного чата ───

  const _ThingChatScreenWrapper({required this.thingId, this.chatId});

  @override
  Widget build(BuildContext context) {
    return TradeChatThingsScreen(thingId: thingId, chatId: chatId);
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

        // ─── Фильтруем пустые чаты (без сообщений) ───
        final filteredChats = _filterEmptyChats(newChats);

        // ─── Обновляем список, сохраняя позицию скролла ───
        final currentScrollPosition = _scrollController.hasClients
            ? _scrollController.position.pixels
            : 0.0;

        setState(() {
          _chats = filteredChats;
          _hasMore = response['has_more'] as bool? ?? false;
          _offset = filteredChats.length;
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

        // ─── Фильтруем пустые чаты (без сообщений) ───
        final filteredChats = _filterEmptyChats(chats);

        setState(() {
          _chats = filteredChats;
          _hasMore = response['has_more'] as bool? ?? false;
          _offset = filteredChats.length;
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

        // ─── Фильтруем пустые чаты (без сообщений) ───
        final filteredChats = _filterEmptyChats(newChats);

        setState(() {
          _chats.addAll(filteredChats);
          _hasMore = response['has_more'] as bool? ?? false;
          _offset += filteredChats.length;
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

  /// ─── Получение URL аватара или logo события ───
  String? _getImageUrl(ChatItem chat) {
    if (chat.isSlotChat) {
      // Для slot чатов возвращаем URL logo события
      return chat.eventLogoUrl;
    } else if (chat.isThingChat) {
      // Для thing чатов возвращаем URL изображения вещи
      return chat.thingImageUrl;
    } else {
      // Для обычных чатов возвращаем URL аватара пользователя
      if (chat.userAvatar == null || chat.userAvatar!.isEmpty) {
        return 'https://uploads.paceup.ru/images/users/avatars/def.png';
      }
      if (chat.userAvatar!.startsWith('http')) {
        return chat.userAvatar;
      }
      // ⚡️ Используем правильный путь: /images/users/avatars/{user_id}/{avatar}
      return 'https://uploads.paceup.ru/images/users/avatars/${chat.userId}/${chat.userAvatar}';
    }
  }

  /// ─── Получение названия для отображения ───
  String _getDisplayName(ChatItem chat) {
    if (chat.isSlotChat) {
      return chat.slotTitle ?? 'Слот';
    } else if (chat.isThingChat) {
      return chat.thingTitle ?? 'Вещь';
    } else {
      return chat.userName ?? 'Пользователь';
    }
  }

  /// ─── Проверка, является ли чат пустым (нет ни одного сообщения) ───
  bool _isEmptyChat(ChatItem chat) {
    return chat.lastMessage.isEmpty && !chat.lastMessageHasImage;
  }

  /// ─── Фильтрация пустых чатов из списка ───
  List<ChatItem> _filterEmptyChats(List<ChatItem> chats) {
    return chats.where((chat) => !_isEmptyChat(chat)).toList();
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
          showBottomDivider: true,
          elevation: 0,
          scrolledUnderElevation: 0,
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
            return ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              itemCount: _chats.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, i) {
                // Индикатор загрузки в конце списка
                if (i == _chats.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                final chat = _chats[i];
                final imageUrl = _getImageUrl(chat);
                final displayName = _getDisplayName(chat);

                Widget chatRow = Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Аватар или logo события/вещи
                      (chat.isSlotChat || chat.isThingChat)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Builder(
                                builder: (context) {
                                  final dpr = MediaQuery.of(
                                    context,
                                  ).devicePixelRatio;
                                  final w = (52 * dpr).round();
                                  if (imageUrl == null || imageUrl.isEmpty) {
                                    return Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.surfaceMuted,
                                      child: Icon(
                                        chat.isSlotChat
                                            ? CupertinoIcons.calendar
                                            : CupertinoIcons.bag,
                                        size: 24,
                                      ),
                                    );
                                  }
                                  return CachedNetworkImage(
                                    key: ValueKey(
                                      '${chat.isSlotChat ? 'slot' : 'thing'}_logo_${chat.id}_$imageUrl',
                                    ),
                                    imageUrl: imageUrl,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    // ── Встроенная анимация fade-in работает по умолчанию
                                    memCacheWidth: w,
                                    maxWidthDiskCache: w,
                                    placeholder: (context, url) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.surfaceMuted,
                                      child: const Center(
                                        child: CupertinoActivityIndicator(
                                          radius: 10,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        width: 52,
                                        height: 52,
                                        color: AppColors.surfaceMuted,
                                        child: Icon(
                                          chat.isSlotChat
                                              ? CupertinoIcons.calendar
                                              : CupertinoIcons.bag,
                                          size: 24,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            )
                          : ClipOval(
                              child: Builder(
                                builder: (context) {
                                  final dpr = MediaQuery.of(
                                    context,
                                  ).devicePixelRatio;
                                  final w = (52 * dpr).round();
                                  final url =
                                      imageUrl ??
                                      'https://uploads.paceup.ru/images/users/avatars/def.png';
                                  return CachedNetworkImage(
                                    key: ValueKey(
                                      'avatar_${chat.id}_${chat.userId}_$url',
                                    ),
                                    imageUrl: url,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    // ── Встроенная анимация fade-in работает по умолчанию
                                    memCacheWidth: w,
                                    maxWidthDiskCache: w,
                                    placeholder: (context, url) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.surfaceMuted,
                                      child: const Center(
                                        child: CupertinoActivityIndicator(
                                          radius: 10,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      return Container(
                                        width: 52,
                                        height: 52,
                                        color: AppColors.surfaceMuted,
                                        child: const Icon(
                                          CupertinoIcons.person,
                                          size: 24,
                                        ),
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
                            const SizedBox(height: 3),
                            // Первая строка: имя + время
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
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
                    dynamic result;

                    if (chat.isSlotChat) {
                      // Для slot чатов открываем TradeChatSlotsScreen
                      if (chat.slotId != null) {
                        result =
                            await Navigator.of(
                              context,
                              rootNavigator: true,
                            ).push(
                              TransparentPageRoute(
                                builder: (_) => _SlotChatScreenWrapper(
                                  slotId: chat.slotId!,
                                  chatId: chat
                                      .id, // ─── Передаем chatId для открытия конкретного чата ───
                                ),
                              ),
                            );
                      }
                    } else if (chat.isThingChat) {
                      // Для thing чатов открываем TradeChatThingsScreen
                      if (chat.thingId != null) {
                        result =
                            await Navigator.of(
                              context,
                              rootNavigator: true,
                            ).push(
                              TransparentPageRoute(
                                builder: (_) => _ThingChatScreenWrapper(
                                  thingId: chat.thingId!,
                                  chatId: chat
                                      .id, // ─── Передаем chatId для открытия конкретного чата ───
                                ),
                              ),
                            );
                      }
                    } else {
                      // Для обычных чатов открываем PersonalChatScreen
                      result = await Navigator.of(context, rootNavigator: true)
                          .push(
                            TransparentPageRoute(
                              builder: (_) => PersonalChatScreen(
                                chatId: chat.id,
                                userId: chat.userId ?? 0,
                                userName: chat.userName ?? 'Пользователь',
                                userAvatar: chat.userAvatar ?? '',
                              ),
                            ),
                          );
                    }

                    // Обновляем список чатов после возврата из чата
                    if (result == true && mounted) {
                      await _loadInitial();
                    }
                  },
                  child: chatRow,
                );

                // ─── Добавляем отступ сверху для первой карточки ───
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: item,
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
