// lib/screens/tradechat_things_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/utils/local_image_compressor.dart';
import '../../../../../core/utils/feed_date.dart';
import '../../../models/market_models.dart';
import '../../widgets/pills.dart'; // GenderPill, PricePill, CityPill
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../profile/screens/profile_screen.dart';

class TradeChatThingsScreen extends ConsumerStatefulWidget {
  final int thingId;
  final int?
  chatId; // ─── Опциональный chatId для открытия конкретного чата ───

  const TradeChatThingsScreen({super.key, required this.thingId, this.chatId});

  @override
  ConsumerState<TradeChatThingsScreen> createState() =>
      _TradeChatThingsScreenState();
}

// ─── Модель сообщения из API ───
class _ChatMessage {
  final int id;
  final int senderId;
  final String messageType; // 'text' или 'image'
  final String? text;
  final String? imageUrl;
  final String createdAt;
  final bool isMine;
  final bool isRead;

  _ChatMessage({
    required this.id,
    required this.senderId,
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
  final int thingId;
  final String thingTitle;
  final String thingCategory;
  final int thingPrice;
  final Gender? thingGender;
  final String? thingDescription;
  final List<String> thingImages;
  final List<String> thingCities;
  final String thingStatus;
  final int sellerId;
  final String sellerName;
  final String? sellerAvatar;
  final int buyerId;
  final String buyerName;
  final String? buyerAvatar;
  final String? dealStatus; // 'pending', 'sold', 'cancelled'
  final DateTime? chatCreatedAt;

  _ChatData({
    required this.chatId,
    required this.thingId,
    required this.thingTitle,
    required this.thingCategory,
    required this.thingPrice,
    this.thingGender,
    this.thingDescription,
    required this.thingImages,
    required this.thingCities,
    required this.thingStatus,
    required this.sellerId,
    required this.sellerName,
    this.sellerAvatar,
    required this.buyerId,
    required this.buyerName,
    this.buyerAvatar,
    this.dealStatus,
    this.chatCreatedAt,
  });

  factory _ChatData.fromJson(Map<String, dynamic> json) {
    final thing = json['thing'] as Map<String, dynamic>;
    final seller = json['seller'] as Map<String, dynamic>;
    final buyer = json['buyer'] as Map<String, dynamic>;
    final chat = json['chat'] as Map<String, dynamic>;

    // ─── Парсим gender ───
    Gender? gender;
    final genderStr = thing['gender'];
    if (genderStr == 'male') {
      gender = Gender.male;
    } else if (genderStr == 'female') {
      gender = Gender.female;
    }

    // ─── Парсим изображения ───
    final imagesData = thing['images'] as List<dynamic>? ?? [];
    final images = imagesData.map((img) => img.toString()).toList();

    // ─── Парсим города ───
    final citiesData = thing['cities'] as List<dynamic>? ?? [];
    final cities = citiesData.map((city) => city.toString()).toList();

    return _ChatData(
      chatId: chat['id'] ?? 0,
      thingId: thing['id'] ?? 0,
      thingTitle: thing['title'] ?? '',
      thingCategory: thing['category'] ?? '',
      thingPrice: thing['price'] ?? 0,
      thingGender: gender,
      thingDescription: thing['description'],
      thingImages: images,
      thingCities: cities,
      thingStatus: thing['status'] ?? 'available',
      sellerId: seller['id'] ?? 0,
      sellerName: seller['name'] ?? '',
      sellerAvatar: seller['avatar'],
      buyerId: buyer['id'] ?? 0,
      buyerName: buyer['name'] ?? '',
      buyerAvatar: buyer['avatar'],
      dealStatus: chat['deal_status'],
      chatCreatedAt:
          null, // Будет загружено из reserve_thing или get_thing_chat
    );
  }

  _ChatData copyWith({DateTime? chatCreatedAt}) {
    return _ChatData(
      chatId: chatId,
      thingId: thingId,
      thingTitle: thingTitle,
      thingCategory: thingCategory,
      thingPrice: thingPrice,
      thingGender: thingGender,
      thingDescription: thingDescription,
      thingImages: thingImages,
      thingCities: thingCities,
      thingStatus: thingStatus,
      sellerId: sellerId,
      sellerName: sellerName,
      sellerAvatar: sellerAvatar,
      buyerId: buyerId,
      buyerName: buyerName,
      buyerAvatar: buyerAvatar,
      dealStatus: dealStatus,
      chatCreatedAt: chatCreatedAt ?? this.chatCreatedAt,
    );
  }

  // ─── Получаем первый imageUrl для AppBar ───
  String? get firstImageUrl =>
      thingImages.isNotEmpty ? thingImages.first : null;

  // ─── Форматируем города для отображения ───
  String get citiesDisplay {
    if (thingCities.isEmpty) return 'Не указано';
    return thingCities.join(', ');
  }

  // ─── Проверяем, является ли пользователь продавцом ───
  bool isSeller(int userId) => userId == sellerId;
}

class _TradeChatThingsScreenState extends ConsumerState<TradeChatThingsScreen>
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
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

  // ─── Инициализация чата: создание/получение чата и загрузка данных ───
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

      // ─── Если chatId передан, загружаем данные напрямую ───
      if (widget.chatId != null) {
        await _loadChatData(widget.chatId!, null);
        return;
      }

      // ─── Иначе создаём/получаем чат через reserve_thing.php ───
      final reserveResponse = await _api.post(
        '/reserve_thing.php',
        body: {'thing_id': widget.thingId, 'user_id': userId},
      );

      if (reserveResponse['success'] != true) {
        throw Exception(reserveResponse['message'] ?? 'Ошибка создания чата');
      }

      final chatId = reserveResponse['chat_id'] as int;
      final chatCreatedAtStr = reserveResponse['chat_created_at'] as String?;

      // Загружаем данные чата
      await _loadChatData(chatId, chatCreatedAtStr);
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
  Future<void> _loadChatData(int chatId, [String? chatCreatedAtStr]) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.get(
        '/get_thing_chat.php',
        queryParams: {
          'chat_id': chatId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Ошибка загрузки чата');
      }

      final chatData = _ChatData.fromJson(response);

      DateTime? chatCreatedAt;
      if (chatCreatedAtStr != null) {
        try {
          chatCreatedAt = DateTime.parse(chatCreatedAtStr);
        } catch (_) {}
      } else if (response['chat_created_at'] != null) {
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
              ? chatData.copyWith(chatCreatedAt: chatCreatedAt)
              : chatData;
          _messages = messages;
          _isLoading = false;
          _error = null;
        });

        _markMessagesAsRead(chatId, userId);
        _startPolling(chatId);

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

  // ─── Отметка сообщений как прочитанных ───
  Future<void> _markMessagesAsRead(int chatId, int userId) async {
    try {
      await _api.post(
        '/mark_thing_chat_messages_read.php',
        body: {'chat_id': chatId, 'user_id': userId},
      );
    } catch (e) {
      debugPrint('Ошибка отметки сообщений как прочитанных: $e');
    }
  }

  // ─── Периодический опрос новых сообщений ───
  void _startPolling(int chatId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_lastMessageId == null) return;

      try {
        final userId = _currentUserId;
        if (userId == null) return;

        final response = await _api.get(
          '/get_thing_chat_messages.php',
          queryParams: {
            'chat_id': chatId.toString(),
            'user_id': userId.toString(),
            'last_message_id': _lastMessageId.toString(),
          },
        );

        if (response['success'] == true && response['has_new'] == true) {
          final newMessagesData = response['new_messages'] as List<dynamic>;
          final newMessages = newMessagesData
              .map((m) => _ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList();

          if (newMessages.isNotEmpty) {
            setState(() {
              _messages.addAll(newMessages);
              _lastMessageId = newMessages.last.id;
            });

            await _markMessagesAsRead(chatId, userId);

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
        debugPrint('Ошибка опроса новых сообщений: $e');
      }
    });
  }

  // ─── Отправка текстового сообщения ───
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _chatData == null) return;

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.post(
        '/send_thing_chat_message.php',
        body: {'chat_id': _chatData!.chatId, 'user_id': userId, 'text': text},
      );

      if (response['success'] == true) {
        if (!mounted) return;
        _ctrl.clear();

        // Добавляем сообщение сразу в список
        final newMessage = _ChatMessage(
          id: response['message_id'] ?? 0,
          senderId: userId,
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
      debugPrint('Ошибка отправки сообщения: $e');
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
        '/send_thing_chat_message.php',
        files: {'image': compressedFile},
        fields: {
          'chat_id': _chatData!.chatId.toString(),
          'user_id': userId.toString(),
        },
        timeout: const Duration(seconds: 60),
      );

      if (response['success'] == true) {
        // Перезагружаем сообщения для получения правильного URL изображения
        await _loadChatData(_chatData!.chatId);

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
      debugPrint('Ошибка отправки изображения: $e');
    }
  }

  // ─── Обновление данных чата ───
  Future<void> _refreshChatData() async {
    if (_chatData == null) return;
    try {
      await _loadChatData(_chatData!.chatId);
    } catch (e) {
      debugPrint('Ошибка обновления данных чата: $e');
    }
  }

  // ─── Обновление статуса товара на "sold" ───
  Future<void> _updateThingStatus() async {
    if (_chatData == null) return;

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.post(
        '/update_thing_status.php',
        body: {'thing_id': _chatData!.thingId, 'user_id': userId},
      );

      if (response['success'] == true) {
        await _loadChatData(_chatData!.chatId);
      }
    } catch (e) {
      debugPrint('Ошибка обновления статуса товара: $e');
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

  // ─── Форматирование цены ───
  String _formatPrice(int price) {
    final s = price.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      b.write(s[i]);
      if (pos > 1 && pos % 3 == 1) b.write(' ');
    }
    return '${b.toString()} ₽';
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
    final isSeller =
        _currentUserId != null && chatData.isSeller(_currentUserId!);

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
                    if (chatData.firstImageUrl != null &&
                        chatData.firstImageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        child: Builder(
                          builder: (context) {
                            final dpr = MediaQuery.of(context).devicePixelRatio;
                            final w = (36 * dpr).round();
                            return CachedNetworkImage(
                              imageUrl: chatData.firstImageUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 120),
                              memCacheWidth: w,
                              maxWidthDiskCache: w,
                              errorWidget: (context, imageUrl, error) {
                                return Container(
                                  width: 36,
                                  height: 36,
                                  color: AppColors.getSurfaceMutedColor(
                                    context,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.photo,
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
                            'Чат продажи вещи',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chatData.thingTitle,
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
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // ─── Основной контент (дата, инфо, участники) ───
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              // 0 — дата
                              if (index == 0) {
                                return _DateSeparator(
                                  text: _formatChatDate(chatData.chatCreatedAt),
                                );
                              }

                              // 1 — стоимость
                              if (index == 1) {
                                return _KVLine(
                                  k: 'Стоимость',
                                  v: PricePill(
                                    text: _formatPrice(chatData.thingPrice),
                                  ),
                                );
                              }

                              // 2 — категория
                              if (index == 2) {
                                return _KVLine(
                                  k: 'Категория',
                                  v: _ChipNeutral(
                                    child: Text(chatData.thingCategory),
                                  ),
                                );
                              }

                              // 3 — пол (если указан)
                              if (index == 3 && chatData.thingGender != null) {
                                return _KVLine(
                                  k: 'Пол',
                                  v: chatData.thingGender == Gender.male
                                      ? const GenderPill.male()
                                      : const GenderPill.female(),
                                );
                              }

                              // 4 — города передачи (если пол указан, иначе индекс 3)
                              final citiesIndex = chatData.thingGender != null
                                  ? 4
                                  : 3;
                              if (index == citiesIndex) {
                                return _KVLine(
                                  k: 'Город передачи',
                                  v: CityPill(text: chatData.citiesDisplay),
                                );
                              }

                              // 5..6 или 4..5 — участники (с учетом того, что пол может быть пропущен)
                              final participantIndex =
                                  chatData.thingGender != null ? 5 : 4;
                              if (index == participantIndex) {
                                return _ParticipantRow(
                                  avatarUrl: chatData.sellerAvatar,
                                  nameAndRole:
                                      '${chatData.sellerName} - продавец',
                                  userId: chatData.sellerId,
                                );
                              }
                              if (index == participantIndex + 1) {
                                return _ParticipantRow(
                                  avatarUrl: chatData.buyerAvatar,
                                  nameAndRole:
                                      '${chatData.buyerName} - покупатель',
                                  userId: chatData.buyerId,
                                );
                              }

                              return const SizedBox.shrink();
                            }, childCount: chatData.thingGender != null ? 7 : 6),
                          ),
                        ),

                        // ─── Закреплённый блок кнопок (только для продавца) ───
                        if (isSeller && chatData.thingStatus != 'sold')
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _ActionsHeaderDelegate(
                              child: Container(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppColors.getSurfaceColor(context)
                                    : AppColors.getBackgroundColor(context),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: _ActionsWrap(
                                  dealStatus: chatData.dealStatus,
                                  onUpdateStatus: _updateThingStatus,
                                ),
                              ),
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

                              final isFromSeller =
                                  msg.senderId == chatData.sellerId;
                              final otherUserAvatar = isFromSeller
                                  ? chatData.sellerAvatar
                                  : chatData.buyerAvatar;

                              return msg.isMine
                                  ? _BubbleRight(
                                      text: msg.text ?? '',
                                      image: msg.messageType == 'image'
                                          ? msg.imageUrl
                                          : null,
                                      time: _formatTime(msg.createdAt),
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
                                      avatarUrl: otherUserAvatar,
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
                    isDisabled: chatData.thingStatus == 'sold',
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

class _KVLine extends StatelessWidget {
  final String k;
  final Widget v;
  const _KVLine({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.getTextPrimaryColor(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          v,
        ],
      ),
    );
  }
}

class _ChipNeutral extends StatelessWidget {
  final Widget child;
  const _ChipNeutral({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.background
            : AppColors.getSurfaceMutedColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.getTextPrimaryColor(context),
        ),
        child: child,
      ),
    );
  }
}

class _ActionsWrap extends StatelessWidget {
  final String? dealStatus;
  final VoidCallback onUpdateStatus;

  const _ActionsWrap({required this.dealStatus, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    // Если товар уже продан
    if (dealStatus == 'sold') {
      return Center(
        child: _PillFinal(
          icon: CupertinoIcons.check_mark_circled,
          text: 'Товар продан',
          bg: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.backgroundGreen,
          border: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.borderaccept,
          fg: AppColors.success,
        ),
      );
    }

    // Начальное состояние — только одна кнопка "Товар продан"
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.of(context).size.width - 40 - 12) / 2,
                ),
                child: _PillButton(
                  text: 'Товар продан',
                  bg: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurfaceMuted
                      : AppColors.backgroundGreen,
                  border: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.borderaccept,
                  fg: AppColors.success,
                  onTap: onUpdateStatus,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String text;
  final Color bg;
  final Color border;
  final Color fg;
  final VoidCallback onTap;

  const _PillButton({
    required this.text,
    required this.bg,
    required this.border,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PillFinal extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color border;
  final Color fg;

  const _PillFinal({
    required this.icon,
    required this.text,
    required this.bg,
    required this.border,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
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

class _ParticipantRow extends StatelessWidget {
  final String? avatarUrl;
  final String nameAndRole;
  final int userId;
  const _ParticipantRow({
    required this.avatarUrl,
    required this.nameAndRole,
    required this.userId,
  });
  @override
  Widget build(BuildContext context) {
    final parts = nameAndRole.split(' - ');
    final name = parts.isNotEmpty ? parts[0] : nameAndRole;
    final role = parts.length > 1 ? ' - ${parts[1]}' : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            TransparentPageRoute(builder: (_) => ProfileScreen(userId: userId)),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Icon(
                        CupertinoIcons.person_fill,
                        size: 14,
                        color: AppColors.getIconSecondaryColor(context),
                      )
                    : null,
                onBackgroundImageError: (error, stackTrace) {},
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  text: name,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.getTextPrimaryColor(context),
                  ),
                  children: [
                    if (role.isNotEmpty)
                      TextSpan(
                        text: role,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleLeft extends StatelessWidget {
  final String text;
  final String? image;
  final String time;
  final String? avatarUrl;
  final double topSpacing;
  final double bottomSpacing;
  final VoidCallback? onImageTap;
  const _BubbleLeft({
    required this.text,
    this.image,
    required this.time,
    this.avatarUrl,
    this.topSpacing = 0.0,
    this.bottomSpacing = 0.0,
    this.onImageTap,
  });
  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.75;
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
          CircleAvatar(
            radius: 14,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(
                    CupertinoIcons.person_fill,
                    size: 14,
                    color: AppColors.getIconSecondaryColor(context),
                  )
                : null,
            onBackgroundImageError: (error, stackTrace) {},
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

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final bool isDisabled;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
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
                  icon: const Icon(CupertinoIcons.plus_circle),
                  onPressed: isDisabled ? null : onPickImage,
                  color: isDisabled
                      ? AppColors.getTextPlaceholderColor(context)
                      : AppColors.getIconSecondaryColor(context),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isDisabled,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: AppTextStyles.h14w4.copyWith(
                      color: isDisabled
                          ? AppColors.getTextPlaceholderColor(context)
                          : AppColors.getTextPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: isDisabled ? 'Товар продан' : 'Сообщение...',
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
                      fillColor:
                          Theme.of(context).brightness == Brightness.light
                          ? AppColors.background
                          : AppColors.getSurfaceMutedColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: (isEnabled && !isDisabled) ? onSend : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.send,
                    size: 22,
                    color: (isEnabled && !isDisabled)
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

class _ActionsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ActionsHeaderDelegate({required this.child});

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_ActionsHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
