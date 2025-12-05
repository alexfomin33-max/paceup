// lib/screens/tradechat_slots_screen.dart
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
import '../../../models/market_models.dart';
import '../../widgets/pills.dart'; // GenderPill, PricePill
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../profile/screens/profile_screen.dart';

class TradeChatSlotsScreen extends ConsumerStatefulWidget {
  final int slotId;
  final int? chatId; // ─── Опциональный chatId для открытия конкретного чата ───

  const TradeChatSlotsScreen({
    super.key,
    required this.slotId,
    this.chatId,
  });

  @override
  ConsumerState<TradeChatSlotsScreen> createState() =>
      _TradeChatSlotsScreenState();
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
  final int slotId;
  final String slotTitle;
  final String slotDistance;
  final int slotPrice;
  final Gender slotGender;
  final String slotStatus;
  final bool isSlotDeleted; // ─── Флаг удаления слота ───
  final String? slotImageUrl;
  final String? slotDateText;
  final String? slotPlaceText;
  final String? slotTypeText;
  final String? slotDescription;
  final int sellerId;
  final String sellerName;
  final String? sellerAvatar;
  final int buyerId;
  final String buyerName;
  final String? buyerAvatar;
  final String? dealStatus; // 'pending', 'bought', 'cancelled'
  final DateTime? chatCreatedAt;

  _ChatData({
    required this.chatId,
    required this.slotId,
    required this.slotTitle,
    required this.slotDistance,
    required this.slotPrice,
    required this.slotGender,
    required this.slotStatus,
    required this.isSlotDeleted,
    this.slotImageUrl,
    this.slotDateText,
    this.slotPlaceText,
    this.slotTypeText,
    this.slotDescription,
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
    final slot = json['slot'] as Map<String, dynamic>;
    final seller = json['seller'] as Map<String, dynamic>;
    final buyer = json['buyer'] as Map<String, dynamic>;
    final chat = json['chat'] as Map<String, dynamic>;

    final genderStr = slot['gender'] ?? 'male';
    final gender = genderStr == 'female' ? Gender.female : Gender.male;
    // ─── Проверяем, удален ли слот ───
    final isDeleted = (slot['del'] as int? ?? 0) == 1;

    return _ChatData(
      chatId: chat['id'] ?? 0,
      slotId: slot['id'] ?? 0,
      slotTitle: slot['title'] ?? '',
      slotDistance: slot['distance'] ?? '',
      slotPrice: slot['price'] ?? 0,
      slotGender: gender,
      slotStatus: slot['status'] ?? 'available',
      isSlotDeleted: isDeleted,
      slotImageUrl: slot['image_url'],
      slotDateText: slot['date_text'],
      slotPlaceText: slot['place_text'],
      slotTypeText: slot['type_text'],
      slotDescription: slot['description'],
      sellerId: seller['id'] ?? 0,
      sellerName: seller['name'] ?? '',
      sellerAvatar: seller['avatar'],
      buyerId: buyer['id'] ?? 0,
      buyerName: buyer['name'] ?? '',
      buyerAvatar: buyer['avatar'],
      dealStatus: chat['deal_status'],
      chatCreatedAt: null, // Будет загружено из reserve_slot или get_slot_chat
    );
  }

  _ChatData copyWith({DateTime? chatCreatedAt, bool? isSlotDeleted}) {
    return _ChatData(
      chatId: chatId,
      slotId: slotId,
      slotTitle: slotTitle,
      slotDistance: slotDistance,
      slotPrice: slotPrice,
      slotGender: slotGender,
      slotStatus: slotStatus,
      isSlotDeleted: isSlotDeleted ?? this.isSlotDeleted,
      slotImageUrl: slotImageUrl,
      slotDateText: slotDateText,
      slotPlaceText: slotPlaceText,
      slotTypeText: slotTypeText,
      slotDescription: slotDescription,
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
}

class _TradeChatSlotsScreenState extends ConsumerState<TradeChatSlotsScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  final _api = ApiService();
  final _auth = AuthService();

  _ChatData? _chatData;
  List<_ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;
  int? _lastMessageId;
  Timer? _pollTimer;
  String? _fullscreenImageUrl; // URL изображения для полноэкранного просмотра
  bool _wasPaused = false; // Флаг для отслеживания паузы приложения
  DateTime? _lastVisibleTime; // Время последнего показа экрана

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем данные при возврате на экран (если прошло больше 1 секунды с последнего показа)
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
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Обновляем данные при возврате приложения из фонового режима
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      if (_chatData != null) {
        _refreshChatData();
      }
    } else if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    }
  }

  // ─── Инициализация чата: резервирование слота и загрузка данных ───
  Future<void> _initializeChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Получаем user_id
      final userId = await _auth.getUserId();
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }
      _currentUserId = userId;

      // ─── Если chatId передан, загружаем данные напрямую ───
      if (widget.chatId != null) {
        await _loadChatData(widget.chatId!, null);
        return;
      }

      // ─── Иначе резервируем слот и создаём/получаем чат ───
      final reserveResponse = await _api.post(
        '/reserve_slot.php',
        body: {'slot_id': widget.slotId, 'user_id': userId},
      );

      if (reserveResponse['success'] != true) {
        throw Exception(
          reserveResponse['message'] ?? 'Ошибка резервирования слота',
        );
      }

      final chatId = reserveResponse['chat_id'] as int;
      final chatCreatedAtStr = reserveResponse['chat_created_at'] as String?;

      // Загружаем данные чата
      await _loadChatData(chatId, chatCreatedAtStr);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─── Загрузка данных чата ───
  Future<void> _loadChatData(int chatId, [String? chatCreatedAtStr]) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.get(
        '/get_slot_chat.php',
        queryParams: {
          'chat_id': chatId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Ошибка загрузки чата');
      }

      final chatData = _ChatData.fromJson(response);

      // Если created_at передан из reserve_slot, используем его, иначе из response
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

      // Обновляем last_message_id
      if (messages.isNotEmpty) {
        _lastMessageId = messages.last.id;
      }

      setState(() {
        _chatData = chatCreatedAt != null
            ? chatData.copyWith(chatCreatedAt: chatCreatedAt)
            : chatData;
        _messages = messages;
        _isLoading = false;
        _error = null;
      });

      // Отмечаем сообщения как прочитанные при открытии чата
      _markMessagesAsRead(chatId, userId);

      // Запускаем периодический опрос новых сообщений
      _startPolling(chatId);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─── Отметка сообщений как прочитанных ───
  Future<void> _markMessagesAsRead(int chatId, int userId) async {
    try {
      await _api.post(
        '/mark_slot_chat_messages_read.php',
        body: {'chat_id': chatId, 'user_id': userId},
      );
    } catch (e) {
      // Игнорируем ошибки при отметке как прочитанных
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
          '/get_slot_chat_messages.php',
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

            // Отмечаем новые сообщения как прочитанные, так как чат открыт
            await _markMessagesAsRead(chatId, userId);
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
        '/send_slot_chat_message.php',
        body: {'chat_id': _chatData!.chatId, 'user_id': userId, 'text': text},
      );

      if (response['success'] == true) {
        _ctrl.clear();
        FocusScope.of(context).unfocus();

        // Перезагружаем сообщения
        await _loadChatData(_chatData!.chatId);
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

      // Загружаем изображение
      final uploadResponse = await _api.postMultipart(
        '/upload_slot_chat_image.php',
        files: {'image': File(x.path)},
        fields: {
          'chat_id': _chatData!.chatId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (uploadResponse['success'] == true) {
        final imagePath = uploadResponse['image_path'] as String;

        // Отправляем сообщение с изображением
        await _api.post(
          '/send_slot_chat_message.php',
          body: {
            'chat_id': _chatData!.chatId,
            'user_id': userId,
            'image': imagePath,
          },
        );

        // Перезагружаем сообщения
        await _loadChatData(_chatData!.chatId);
      }
    } catch (e) {
      debugPrint('Ошибка отправки изображения: $e');
    }
  }

  // ─── Обновление данных чата (для pull-to-refresh) ───
  Future<void> _refreshChatData() async {
    if (_chatData == null) return;

    try {
      await _loadChatData(_chatData!.chatId);
    } catch (e) {
      debugPrint('Ошибка обновления данных чата: $e');
    }
  }

  // ─── Обновление статуса сделки ───
  Future<void> _updateDealStatus(String dealStatus) async {
    if (_chatData == null) return;

    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final response = await _api.post(
        '/update_slot_deal_status.php',
        body: {
          'chat_id': _chatData!.chatId,
          'user_id': userId,
          'deal_status': dealStatus,
        },
      );

      if (response['success'] == true) {
        // Перезагружаем данные чата
        await _loadChatData(_chatData!.chatId);
      }
    } catch (e) {
      debugPrint('Ошибка обновления статуса сделки: $e');
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

  // ─── Показать изображение в полноэкранном режиме ───
  void _showFullscreenImage(String imageUrl) {
    setState(() {
      _fullscreenImageUrl = imageUrl;
    });
  }

  // ─── Скрыть полноэкранное изображение ───
  void _hideFullscreenImage() {
    setState(() {
      _fullscreenImageUrl = null;
    });
  }

  // ─── Форматирование даты создания чата ───
  String _formatChatDate(DateTime? date) {
    if (date == null) {
      final now = DateTime.now();
      final dd = now.day.toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final yyyy = now.year.toString();
      return '$dd.$mm.$yyyy';
    }
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd.$mm.$yyyy';
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
                offset: const Offset(-4, 0),
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
              title: Row(
                children: [
                  if (chatData.slotImageUrl != null &&
                      chatData.slotImageUrl!.isNotEmpty) ...[
                    Container(
                      width: 36,
                      height: 36,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        image: DecorationImage(
                          image: NetworkImage(chatData.slotImageUrl!),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Чат продажи слота',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          chatData.slotTitle,
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
                      slivers: [
                        // ─── Основной контент (дата, инфо, участники) ───
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          sliver: Builder(
                            builder: (context) {
                              // ─── Определяем, нужно ли показывать строку статуса ───
                              // Показываем ТОЛЬКО в трех случаях:
                              // 1. Слот продан (status == 'sold')
                              // 2. Сделка отменена (dealStatus == 'cancelled')
                              // 3. Слот снят с продажи (isSlotDeleted == true)
                              // НЕ показываем для 'available', 'reserved' и других обычных статусов
                              final showStatusLine = chatData.slotStatus == 'sold' ||
                                  chatData.dealStatus == 'cancelled' ||
                                  chatData.isSlotDeleted;

                              // ─── Вычисляем количество элементов списка ───
                              // 0 - дата
                              // 1 - статус (опционально)
                              // 2-4 - дистанция, пол, стоимость (3 элемента)
                              // 5-6 - участники (2 элемента)
                              final itemCount = 1 + // дата
                                  (showStatusLine ? 1 : 0) + // статус (опционально)
                                  3 + // дистанция, пол, стоимость
                                  2; // участники

                              return SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    // 0 — дата
                                    if (index == 0) {
                                      return _DateSeparator(
                                        text:
                                            '${_formatChatDate(chatData.chatCreatedAt)}, автоматическое создание чата',
                                      );
                                    }

                                    // ─── 1 — строка статуса (показываем только если нужно) ───
                                    if (showStatusLine && index == 1) {
                                      // ─── Определяем текст статуса ───
                                      String statusText;
                                      IconData statusIcon;
                                      
                                      if (chatData.slotStatus == 'sold') {
                                        statusText = 'Продано';
                                        statusIcon = CupertinoIcons.check_mark_circled;
                                      } else if (chatData.isSlotDeleted) {
                                        statusText = 'Снят с продажи';
                                        statusIcon = CupertinoIcons.xmark_circle_fill;
                                      } else if (chatData.dealStatus == 'cancelled') {
                                        statusText = 'Отменено';
                                        statusIcon = CupertinoIcons.clear_circled;
                                      } else {
                                        // Не должно происходить, но на всякий случай
                                        return const SizedBox.shrink();
                                      }

                                      return _KVLine(
                                        k: 'Слот переведён в статус',
                                        v: _ChipNeutral(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                statusIcon,
                                                size: 14,
                                                color:
                                                    AppColors.getIconSecondaryColor(
                                                  context,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontWeight:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? FontWeight.w500
                                                      : FontWeight.w400,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppColors.darkTextSecondary
                                                      : AppColors.getTextPrimaryColor(
                                                          context,
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    // ─── Корректируем индекс: вычитаем 1 для даты, и еще 1 если есть строка статуса ───
                                    final adjustedIndex = index - 1 - (showStatusLine ? 1 : 0);

                                    // ─── 2-4 — инфо-строки (дистанция, пол, стоимость) ───
                                    if (adjustedIndex == 1) {
                                      return _KVLine(
                                        k: 'Дистанция',
                                        v: _ChipNeutral(
                                          child: Text(chatData.slotDistance),
                                        ),
                                      );
                                    }
                                    if (adjustedIndex == 2) {
                                      return _KVLine(
                                        k: 'Пол',
                                        v: chatData.slotGender == Gender.male
                                            ? const GenderPill.male()
                                            : const GenderPill.female(),
                                      );
                                    }
                                    if (adjustedIndex == 3) {
                                      return _KVLine(
                                        k: 'Стоимость',
                                        v: PricePill(
                                          text: _formatPrice(chatData.slotPrice),
                                        ),
                                      );
                                    }

                                    // ─── 5-6 — участники ───
                                    if (adjustedIndex == 4) {
                                      return _ParticipantRow(
                                        avatarUrl: chatData.sellerAvatar,
                                        nameAndRole:
                                            '${chatData.sellerName} - продавец',
                                        userId: chatData.sellerId,
                                      );
                                    }
                                    if (adjustedIndex == 5) {
                                      return _ParticipantRow(
                                        avatarUrl: chatData.buyerAvatar,
                                        nameAndRole:
                                            '${chatData.buyerName} - покупатель',
                                        userId: chatData.buyerId,
                                      );
                                    }

                                    return const SizedBox.shrink();
                                  },
                                  childCount: itemCount,
                                ),
                              );
                            },
                          ),
                        ),

                        // ─── Закреплённый блок кнопок (для продавца и покупателя) ───
                        // ─── Скрываем кнопки, если слот удален ───
                        if (!chatData.isSlotDeleted)
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
                                  onUpdateStatus: _updateDealStatus,
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
                          // bottom padding = 0, отступ создаётся через bottomSpacing последнего сообщения
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final msg = _messages[index];

                              // ─── Определяем отступы между пузырями ───
                              // topSpacing: отступ сверху, если есть предыдущее сообщение
                              final hasMessageAbove = index > 0;
                              final topSpacing = hasMessageAbove ? 8.0 : 0.0;
                              // bottomSpacing: отступ снизу только для последнего сообщения
                              final isLastMessage =
                                  index == _messages.length - 1;
                              final bottomSpacing = isLastMessage ? 8.0 : 0.0;

                              // ─── Определяем аватар для сообщений от другого пользователя ───
                              // Если sender_id совпадает с seller_id, то это сообщение от продавца
                              // Если sender_id совпадает с buyer_id, то это сообщение от покупателя
                              final isFromSeller =
                                  msg.senderId == chatData.sellerId;
                              final otherUserAvatar = isFromSeller
                                  ? chatData.sellerAvatar
                                  : chatData.buyerAvatar;

                              // Используем единые виджеты для текста и изображений
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
                            }, childCount: _messages.length),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Composer (неактивен, если слот удален)
                  _Composer(
                    controller: _ctrl,
                    onSend: _sendText,
                    onPickImage: _pickImage,
                    isDisabled: chatData.isSlotDeleted,
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
  final Function(String) onUpdateStatus;

  const _ActionsWrap({required this.dealStatus, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    // Если сделка уже завершена
    if (dealStatus == 'bought') {
      return Center(
        child: _PillFinal(
          icon: CupertinoIcons.check_mark_circled,
          text: 'Слот куплен',
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

    if (dealStatus == 'cancelled') {
      return Center(
        child: _PillFinal(
          icon: CupertinoIcons.clear_circled,
          text: 'Сделка отменена',
          bg: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.bgfemale,
          border: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.bordercancel,
          fg: AppColors.error,
        ),
      );
    }

    // Начальное состояние
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _PillButton(
              text: 'Слот куплен',
              bg: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.backgroundGreen,
              border: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.borderaccept,
              fg: AppColors.success,
              onTap: () => onUpdateStatus('bought'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PillButton(
              text: 'Отменить сделку',
              bg: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.bgfemale,
              border: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.bordercancel,
              fg: AppColors.error,
              onTap: () => onUpdateStatus('cancelled'),
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
  const _DateSeparator({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    alignment: Alignment.center,
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.getTextTertiaryColor(context),
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
            TransparentPageRoute(
              builder: (_) => ProfileScreen(userId: userId),
            ),
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
                onBackgroundImageError: (_, __) {},
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
            onBackgroundImageError: (_, __) {},
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

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final bool isDisabled; // ─── Флаг неактивности (для удаленных слотов) ───

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
                    enabled: !isDisabled, // ─── Отключаем поле, если слот удален ───
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
                      hintText: isDisabled
                          ? 'Слот удален'
                          : 'Сообщение...',
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

/// ────────────────────────────────────────────────────────────────────────
/// Delegate для закреплённого заголовка с кнопками действий
/// ────────────────────────────────────────────────────────────────────────
class _ActionsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ActionsHeaderDelegate({required this.child});

  @override
  double get minExtent => 48.0; // Минимальная высота (padding + минимальная высота кнопок)

  @override
  double get maxExtent => 48.0; // Максимальная высота

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
