import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
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
    // headerCount = 6 элементов (дата, Стоимость, 2 участника, Divider, SizedBox)
    // ─────────────────────────────────────────────────────────────
    const int headerCount = 6;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getSurfaceColor(context)
            : AppColors.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: AppColors.getSurfaceColor(context),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: GestureDetector(
          // Снятие фокуса с поля ввода при тапе на любое место экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Column(
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
                    return _KVLine(
                      k: 'Стоимость',
                      v: PricePill(text: _formatPrice(widget.price)),
                    );
                  }
                  if (index == 2) {
                    return const _ParticipantRow(
                      avatarAsset: 'assets/avatar_4.png',
                      nameAndRole: 'Екатерина Виноградова - продавец',
                    );
                  }
                  if (index == 3) {
                    return const _ParticipantRow(
                      avatarAsset: 'assets/avatar_9.png',
                      nameAndRole: 'Анастасия Бутузова - покупатель',
                    );
                  }
                  if (index == 4) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 16,
                        thickness: 1,
                        color: AppColors.getBorderColor(context),
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
        style: TextStyle(
          fontSize: 12,
          color: AppColors.getTextTertiaryColor(context),
        ),
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
    // Разделяем имя и роль
    final parts = nameAndRole.split(' - ');
    final name = parts.isNotEmpty ? parts[0] : nameAndRole;
    final role = parts.length > 1 ? ' - ${parts[1]}' : '';
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundImage: AssetImage(avatarAsset)),
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
    );
  }
}

/// Левый «текстовый» пузырь продавца — без иконки справа
class _BubbleLeft extends StatelessWidget {
  final String text;
  final String time;
  const _BubbleLeft({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.75;

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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.getTextTertiaryColor(context),
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.greenBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.getTextTertiaryColor(context),
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
                        color: AppColors.getTextSecondaryColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.getTextPrimaryColor(context),
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
                        color: AppColors.getTextSecondaryColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          color: AppColors.getSurfaceColor(context),
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

/// ─── Компонент ввода сообщений (в стиле comments_bottom_sheet) ───
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
                      fillColor: AppColors.getSurfaceMutedColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: isEnabled ? onSend : null,
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
