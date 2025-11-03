import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/interactive_back_swipe.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Экран персонального чата с конкретным пользователем
/// ────────────────────────────────────────────────────────────────────────
class PersonalChatScreen extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String? lastSeen; // "Был 5 минут назад" и т.д.

  const PersonalChatScreen({
    super.key,
    required this.userName,
    required this.userAvatar,
    this.lastSeen,
  });

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

/// ────────────────────────────────────────────────────────────────────────
/// Модели сообщений
/// ────────────────────────────────────────────────────────────────────────
enum _MsgSide { left, right }

enum _MsgKind { text, image }

class _ChatMsg {
  final _MsgSide side;
  final _MsgKind kind;
  final String time;
  final String? text;
  final File? imageFile;

  const _ChatMsg.text({
    required this.side,
    required this.text,
    required this.time,
  }) : kind = _MsgKind.text,
       imageFile = null;

  const _ChatMsg.image({
    required this.side,
    required this.imageFile,
    required this.time,
  }) : kind = _MsgKind.image,
       text = null;
}

/// ────────────────────────────────────────────────────────────────────────
/// Состояние экрана персонального чата
/// ────────────────────────────────────────────────────────────────────────
class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();

  /// ─── Демо-сообщения (как на скриншоте) ───
  final List<_ChatMsg> _messages = const [
    _ChatMsg.text(
      side: _MsgSide.left,
      text:
          'Hi, the restaurant is quite busy now so the delivery may be late 15 mins. Please wait for me.',
      time: '8:48',
    ),
    _ChatMsg.text(side: _MsgSide.right, text: 'Sure! Thank you', time: '9:34'),
    _ChatMsg.text(
      side: _MsgSide.left,
      text: 'Ты в субботу на коферан или может поедем на карьеры купаться?',
      time: '9:35',
    ),
    _ChatMsg.text(
      side: _MsgSide.right,
      text:
          'Could you please ask the restaurant to give me cutlery? I just need these items.',
      time: '9:34',
    ),
  ].toList();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// ─── Отправка текстового сообщения ───
  void _sendText() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg.text(side: _MsgSide.right, text: t, time: _now()));
      _ctrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  /// ─── Форматирование текущего времени ───
  String _now() {
    final dt = TimeOfDay.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// ─── Выбор изображения из галереи ───
  Future<void> _pickImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _messages.add(
        _ChatMsg.image(
          side: _MsgSide.right,
          imageFile: File(x.path),
          time: _now(),
        ),
      );
    });
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
              onPressed: () => Navigator.pop(context),
              splashRadius: 18,
            ),
          ),
          titleSpacing: -8,
          title: Row(
            children: [
              // Аватар пользователя
              ClipOval(
                child: Image.asset(
                  widget.userAvatar,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                itemCount: _messages.length,
                itemBuilder: (_, index) {
                  final m = _messages[index];
                  if (m.kind == _MsgKind.image) {
                    return m.side == _MsgSide.right
                        ? _BubbleImageRight(file: m.imageFile!, time: m.time)
                        : _BubbleImageLeft(
                            file: m.imageFile!,
                            time: m.time,
                            avatarAsset: widget.userAvatar,
                          );
                  } else {
                    return m.side == _MsgSide.right
                        ? _BubbleRight(text: m.text!, time: m.time)
                        : _BubbleLeft(
                            text: m.text!,
                            time: m.time,
                            avatarAsset: widget.userAvatar,
                          );
                  }
                },
              ),
            ),

            // ─── Неподвижная нижняя панель ввода ───
            _Composer(
              controller: _ctrl,
              onSend: _sendText,
              onPickImage: _pickImage,
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

/// Левый пузырь (сообщения собеседника) — с аватаром и иконкой reply
class _BubbleLeft extends StatelessWidget {
  final String text;
  final String time;
  final String avatarAsset;

  const _BubbleLeft({
    required this.text,
    required this.time,
    required this.avatarAsset,
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
          CircleAvatar(radius: 14, backgroundImage: AssetImage(avatarAsset)),
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
          const SizedBox(width: 6),
          const Icon(
            CupertinoIcons.arrowshape_turn_up_left,
            size: 18,
            color: AppColors.iconSecondary,
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
                color: AppColors.backgroundGreen,
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

/// Пузырь с изображением — слева (собеседник)
class _BubbleImageLeft extends StatelessWidget {
  final File file;
  final String time;
  final String avatarAsset;

  const _BubbleImageLeft({
    required this.file,
    required this.time,
    required this.avatarAsset,
  });

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.6;
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(radius: 14, backgroundImage: AssetImage(avatarAsset)),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Stack(
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        time,
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 11,
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

/// Пузырь с изображением — справа (мои)
class _BubbleImageRight extends StatelessWidget {
  final File file;
  final String time;

  const _BubbleImageRight({required this.file, required this.time});

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.6;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Stack(
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        time,
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 11,
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
