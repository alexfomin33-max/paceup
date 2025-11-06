import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../widgets/pills.dart'; // PricePill

class TradeChatScreen extends StatefulWidget {
  final String itemTitle;
  final String? itemThumb; // ассет превью вещи
  final int price; // в рублях

  const TradeChatScreen({
    super.key,
    required this.itemTitle,
    this.itemThumb,
    required this.price,
  });

  @override
  State<TradeChatScreen> createState() => _TradeChatScreenState();
}

/// Модель сообщений
enum _MsgSide { left, right }

enum _MsgKind { text, image }

class _ChatMsg {
  final _MsgSide side;
  final _MsgKind kind;
  final String time;
  final String? text;
  final File? imageFile; // для выбранных из галереи

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

class _TradeChatScreenState extends State<TradeChatScreen> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();

  String _today() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return '$dd.$mm.$yyyy';
  }

  final List<_ChatMsg> _messages = const [
    _ChatMsg.text(
      side: _MsgSide.right,
      text:
          'Добрый день, Екатерина. Хотела бы посмотреть эти кроссовки. Где и когда можно будет увидеться?',
      time: '9:34',
    ),
    _ChatMsg.text(
      side: _MsgSide.left,
      text: 'Добрый день! Давайте я чуть позже отпишусь и всё обсудим',
      time: '9:35',
    ),
  ].toList();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _sendText() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg.text(side: _MsgSide.right, text: t, time: _now()));
      _ctrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  String _now() {
    final dt = TimeOfDay.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

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

  @override
  Widget build(BuildContext context) {
    // ─────────────────────────────────────────────────────────────
    // ВАЖНО: теперь в списке есть «хедеры», которые тоже скроллятся.
    // headerCount = 6 элементов (дата, 2 участника, Стоимость, Divider, SizedBox)
    // ─────────────────────────────────────────────────────────────
    const int headerCount = 6;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface, // фон чата — белый
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
          titleSpacing: -8, // «чуть левее»
          title: Row(
            children: [
              if (widget.itemThumb != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    image: DecorationImage(
                      image: AssetImage(widget.itemThumb!),
                      fit: BoxFit.cover,
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
                      'Чат продажи вещи',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.itemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ─────────────────────────────────────────────────────────
            // Прокручиваемая область: headers + сообщения в одном ListView
            // ─────────────────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                // bottom padding побольше, чтобы последний элемент не прятался за Composer
                itemCount: headerCount + _messages.length,
                itemBuilder: (_, index) {
                  // 0..headerCount-1 — это наши «шапки», которые раньше были над списком.
                  if (index == 0) {
                    return _DateSeparator(
                      text: '${_today()}, автоматическое создание чата',
                    );
                  }
                  if (index == 1) {
                    return const _ParticipantRow(
                      avatarAsset: 'assets/avatar_4.png',
                      nameAndRole: 'Екатерина Виноградова - продавец',
                    );
                  }
                  if (index == 2) {
                    return const _ParticipantRow(
                      avatarAsset: 'assets/avatar_9.png',
                      nameAndRole: 'Анастасия Бутузова - покупатель',
                    );
                  }
                  if (index == 3) {
                    return _KVLine(
                      k: 'Стоимость',
                      v: PricePill(text: _formatPrice(widget.price)),
                    );
                  }
                  if (index == 4) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 16,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                    );
                  }
                  if (index == 5) {
                    return const SizedBox(height: 8);
                  }

                  // дальше — сообщения
                  final m = _messages[index - headerCount];
                  if (m.kind == _MsgKind.image) {
                    return m.side == _MsgSide.right
                        ? _BubbleImageRight(file: m.imageFile!, time: m.time)
                        : _BubbleImageLeft(file: m.imageFile!, time: m.time);
                  } else {
                    return m.side == _MsgSide.right
                        ? _BubbleRight(text: m.text!, time: m.time)
                        : _BubbleLeft(text: m.text!, time: m.time);
                  }
                },
              ),
            ),

            // ─────────────────────────────────────────────────────────
            // Неподвижная нижняя панель ввода (Composer)
            // ─────────────────────────────────────────────────────────
            _Composer(
              controller: _ctrl,
              onSend: _sendText,
              onPickImage: _pickImage, // плюсик — выбор фото из галереи
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── helpers ───

/// Инфо-строка: ключ слева, значение сразу справа
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
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          // ⛔️ НЕТ Spacer — значение идёт сразу после подписи
          v,
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String text;
  const _DateSeparator({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final String avatarAsset;
  final String nameAndRole;

  const _ParticipantRow({required this.avatarAsset, required this.nameAndRole});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundImage: AssetImage(avatarAsset)),
          const SizedBox(width: 8),
          Text(nameAndRole, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// Левый «текстовый» пузырь продавца — с иконкой справа (как в макете)
class _BubbleLeft extends StatelessWidget {
  final String text;
  final String time;
  const _BubbleLeft({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final max = screenW * 0.72; // оставим место под правую иконку

    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundImage: AssetImage('assets/avatar_4.png'),
          ),
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

/// Правый «текстовый» пузырь покупателя — без аватарки
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
                color: AppColors.backgroundGreen, // мягкий зелёный
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

/// Пузырь с изображением — слева
class _BubbleImageLeft extends StatelessWidget {
  final File file;
  final String time;
  const _BubbleImageLeft({required this.file, required this.time});

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.6;
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundImage: AssetImage('assets/avatar_4.png'),
          ),
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

/// Пузырь с изображением — справа
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

/// Компонент ввода: радиус 20, серый плейсхолдер, плюс — выбор фото
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
              onPressed: widget.onPickImage, // открыть галерею
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
