import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_image_compressor.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../providers/chat/personal_chat_provider.dart';

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
  Timer? _pollingTimer;
  double _previousKeyboardHeight = 0; // Для отслеживания изменений клавиатуры
  bool _hasScrolledToBottom = false; // Флаг для отслеживания первой прокрутки

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// ─── Запуск polling для проверки новых сообщений ───
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        final args = PersonalChatArgs(
          chatId: widget.chatId,
          userId: widget.userId,
        );
        final notifier = ref.read(personalChatProvider(args).notifier);
        final stateBefore = ref.read(personalChatProvider(args));
        notifier.checkNewMessages().then((_) {
          if (!mounted) return;
          final stateAfter = ref.read(personalChatProvider(args));
          // Если появились новые сообщения, прокручиваем вниз
          if (stateAfter.messages.length > stateBefore.messages.length) {
            final hasIncomingMessages = stateAfter.messages
                .where((m) => !m.isMine)
                .any((m) => !stateBefore.messages.any((old) => old.id == m.id));
            if (hasIncomingMessages) {
              // Отмечаем как прочитанные
              notifier.markMessagesAsRead();
              // ─── Прокрутка вниз при получении новых сообщений ───
              // При reverse: true "вниз" - это позиция 0
              if (_scrollController.hasClients) {
                final isNearBottom = _scrollController.position.pixels <= 100;
                if (isNearBottom) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients && mounted) {
                      _scrollController.animateTo(
                        0, // ─── При reverse: true позиция 0 - это последние сообщения ───
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                }
              }
            }
          }
        });
      }
    });
  }

  /// ─── Прокрутка вниз к последним сообщениям ───
  void _scrollToBottom({bool animated = true, bool force = false}) {
    if (!_scrollController.hasClients || !mounted) return;

    // Если force = true, всегда прокручиваем (например, при открытии клавиатуры)
    if (!force) {
      // ─── Проверяем, находится ли пользователь уже внизу ───
      // При reverse: true "вниз" - это позиция 0 (последние сообщения)
      final isNearBottom = _scrollController.position.pixels <= 200;

      // Прокручиваем только если пользователь уже внизу
      if (!isNearBottom) return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        if (animated) {
          _scrollController.animateTo(
            0, // ─── При reverse: true позиция 0 - это последние сообщения ───
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
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
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // ─── Обновляем сообщения при возврате приложения из фона ───
    if (lifecycleState == AppLifecycleState.resumed) {
      final args = PersonalChatArgs(
        chatId: widget.chatId,
        userId: widget.userId,
      );
      final chatState = ref.read(personalChatProvider(args));
      if (chatState.actualChatId != null && chatState.currentUserId != null) {
        // Проверяем новые сообщения при возврате
        ref.read(personalChatProvider(args).notifier).checkNewMessages();
        // Отмечаем сообщения как прочитанные
        ref.read(personalChatProvider(args).notifier).markMessagesAsRead();
      }
    }
  }

  /// ─── Выбор изображения из галереи ───
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        final compressed = await compressLocalImage(
          sourceFile: File(pickedFile.path),
          maxSide: 1600,
          jpegQuality: 80,
        );
        final args = PersonalChatArgs(
          chatId: widget.chatId,
          userId: widget.userId,
        );
        final success = await ref
            .read(personalChatProvider(args).notifier)
            .sendImage(compressed);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка отправки изображения'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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

  /// ─── Отправка текстового сообщения ───
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    _ctrl.clear();
    FocusScope.of(context).unfocus();

    final args = PersonalChatArgs(chatId: widget.chatId, userId: widget.userId);
    final success = await ref
        .read(personalChatProvider(args).notifier)
        .sendText(text);

    // ─── Прокрутка вниз после отправки ───
    // При reverse: true позиция 0 - это последние сообщения
    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // ─── При reverse: true позиция 0 - это последние сообщения ───
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
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
        // ─── Белый фон для лучшего контраста с пузырями сообщений ───
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.surface,
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
                final args = PersonalChatArgs(
                  chatId: widget.chatId,
                  userId: widget.userId,
                );
                await ref
                    .read(personalChatProvider(args).notifier)
                    .markMessagesAsRead();
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
                child: Builder(
                  builder: (context) {
                    final args = PersonalChatArgs(
                      chatId: widget.chatId,
                      userId: widget.userId,
                    );
                    final chatState = ref.watch(personalChatProvider(args));

                    // ─── Автоматическая прокрутка вниз при первой загрузке сообщений ───
                    // При reverse: true прокрутка к 0 означает прокрутку к последним сообщениям
                    if (!chatState.isLoading &&
                        chatState.messages.isNotEmpty &&
                        !_hasScrolledToBottom) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _scrollController.hasClients) {
                          _scrollController.jumpTo(0);
                          _hasScrolledToBottom = true;
                        }
                      });
                    }

                    if (chatState.error != null && chatState.messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ошибка: ${chatState.error}',
                                style: const TextStyle(color: AppColors.error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(personalChatProvider(args).notifier)
                                      .loadInitial();
                                },
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (chatState.isLoading && chatState.messages.isEmpty) {
                      return const Center(child: CupertinoActivityIndicator());
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification) {
                          // ─── Загрузка старых сообщений при прокрутке вверх ───
                          // При reverse: true прокрутка вверх означает увеличение pixels
                          if (_scrollController.position.pixels >=
                                  _scrollController.position.maxScrollExtent -
                                      100 &&
                              chatState.hasMore &&
                              !chatState.isLoadingMore) {
                            ref
                                .read(personalChatProvider(args).notifier)
                                .loadMore();
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        reverse:
                            true, // ─── Сообщения прижаты к низу (к панели ввода) ───
                        controller: _scrollController,
                        // ─── Padding: небольшой нижний отступ для панели ввода ───
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          // ─── Небольшой нижний отступ между сообщениями и панелью ввода ───
                          8,
                        ),
                        itemCount:
                            chatState.messages.length +
                            (chatState.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // ─── Индикатор загрузки старых сообщений в конце списка (сверху) ───
                          if (index == chatState.messages.length &&
                              chatState.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            );
                          }

                          // ─── Разворачиваем список, чтобы при reverse: true новые сообщения были внизу ───
                          final reversedIndex =
                              chatState.messages.length - 1 - index;
                          final message = chatState.messages[reversedIndex];

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
                  },
                ),
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
                // ─── Нейтральный серый фон для сообщений собеседника (более контрастный) ───
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceMuted
                    : AppColors
                          .softBg, // ─── Более темный серый для лучшего контраста на белом фоне ───
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Изображение (если есть) ───
                  if (image != null && image!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        // ─── Открываем изображение в полный размер ───
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                _FullscreenImageView(imageUrl: image!),
                          ),
                        );
                      },
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

  const _BubbleRight({required this.text, this.image, required this.time});

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
                // ─── Брендовый синий цвет для моих сообщений (стандарт для чатов) ───
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.brandPrimary.withValues(alpha: 0.25)
                    : AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Изображение (если есть) ───
                  if (image != null && image!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        // ─── Открываем изображение в полный размер ───
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                _FullscreenImageView(imageUrl: image!),
                          ),
                        );
                      },
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
/// Полноэкранный просмотр изображения
/// ────────────────────────────────────────────────────────────────────────
class _FullscreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary, // Чёрный фон
      body: Stack(
        children: [
          // ─── Изображение с возможностью зума ───
          Center(
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

          // ─── Кнопка закрытия (крестик) в верхнем левом углу ───
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
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
    );
  }
}
