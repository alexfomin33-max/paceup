// lib/screens/tradechat_slots_screen.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/market_models.dart';
import 'widgets/pills.dart'; // GenderPill, PricePill

class TradeChatSlotsScreen extends StatefulWidget {
  final String itemTitle;
  final String? itemThumb; // превью слота (ассет)
  final String distance; // например "21,1 км"
  final Gender gender; // male/female
  final int price; // в рублях
  final String statusText; // например "Бронь"

  const TradeChatSlotsScreen({
    super.key,
    required this.itemTitle,
    this.itemThumb,
    required this.distance,
    required this.gender,
    required this.price,
    this.statusText = 'Бронь',
  });

  @override
  State<TradeChatSlotsScreen> createState() => _TradeChatSlotsScreenState();
}

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

class _TradeChatSlotsScreenState extends State<TradeChatSlotsScreen> {
  final _ctrl = TextEditingController();
  final _picker = ImagePicker();

  final List<_ChatMsg> _messages = const [
    _ChatMsg.text(
      side: _MsgSide.right,
      text:
          'Добрый день, Ирина. Хотела бы приобрести данный слот. Куда перевести деньги?',
      time: '9:34',
    ),
    _ChatMsg.text(
      side: _MsgSide.left,
      text: 'Добрый день! Можно на карту Сбера по номеру +7-905-123-45-67',
      time: '9:35',
    ),
  ].toList();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _today() {
    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return '$dd.$mm.$yyyy';
  }

  String _now() {
    final dt = TimeOfDay.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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
    // 0 дата, 1..4 инфо-строки, 5..6 участники, 7 кнопки, 8 divider+отступ
    const headerCount = 9;

    return Scaffold(
      backgroundColor: Colors.white,
      // ⛔️ никаких bottomNavigationBar — экран отдельный
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1, // как в market_screen.dart
        shadowColor: Colors.black26, // та же маленькая тень
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
            if (widget.itemThumb != null) ...[
              Container(
                width: 36,
                height: 36,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
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
                    'Чат продажи слота',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              itemCount: headerCount + _messages.length,
              itemBuilder: (_, index) {
                // 0 — дата
                if (index == 0) {
                  return _DateSeparator(
                    text: '${_today()}, автоматическое создание чата',
                  );
                }

                // 1..4 — инфо-строки (значение сразу после подписи)
                if (index == 1) {
                  return _KVLine(
                    k: 'Слот переведён в статус',
                    v: _ChipNeutral(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            CupertinoIcons.lock,
                            size: 14,
                            color: Colors.black54,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Бронь',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (index == 2) {
                  return _KVLine(
                    k: 'Дистанция',
                    v: _ChipNeutral(child: Text(widget.distance)),
                  );
                }
                if (index == 3) {
                  return _KVLine(
                    k: 'Пол',
                    v: widget.gender == Gender.male
                        ? const GenderPill.male()
                        : const GenderPill.female(),
                  );
                }
                if (index == 4) {
                  return _KVLine(
                    k: 'Стоимость',
                    v: PricePill(text: _formatPrice(widget.price)),
                  );
                }

                // 5..6 — участники
                if (index == 5) {
                  return const _ParticipantRow(
                    avatarAsset: 'assets/Irina.png',
                    nameAndRole: 'Ирина Селиванова - продавец',
                  );
                }
                if (index == 6) {
                  return const _ParticipantRow(
                    avatarAsset: 'assets/Leyla.png',
                    nameAndRole: 'Лейла Мустафаева - покупатель',
                  );
                }

                // 7 — Кнопки действий (ширина по контенту)
                if (index == 7) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: _ActionsWrap(),
                  );
                }

                // 8 — Divider ПОД кнопками + небольшой отступ
                if (index == 8) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Divider(
                          height: 16,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                        SizedBox(height: 6),
                      ],
                    ),
                  );
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

          // Composer (фиксирован внизу)
          _Composer(
            controller: _ctrl,
            onSend: _sendText,
            onPickImage: _pickImage,
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

/// ─── Инфо-строка: ключ слева, значение сразу справа ───
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
              style: const TextStyle(fontSize: 13, color: Colors.black87),
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

/// Нейтральная «пилюля» без рамки (для статуса и дистанции)
class _ChipNeutral extends StatelessWidget {
  final Widget child;
  const _ChipNeutral({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // без рамки
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        child: child,
      ),
    );
  }
}

/// Кнопки действий:
/// - старт: две кнопки в одной линии, одинаковой ширины, по центру
/// - после нажатия: остаётся одна «пилюля» по центру
class _ActionsWrap extends StatefulWidget {
  const _ActionsWrap();

  @override
  State<_ActionsWrap> createState() => _ActionsWrapState();
}

enum _DealStatus { initial, bought, cancelled }

class _ActionsWrapState extends State<_ActionsWrap> {
  _DealStatus _status = _DealStatus.initial;

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _DealStatus.initial:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _PillButton(
                  text: 'Слот куплен',
                  bg: const Color(0xFFE9F7E3),
                  border: const Color(0xFFD7EDCF),
                  fg: const Color(0xFF2E7D32),
                  onTap: () {
                    setState(() => _status = _DealStatus.bought);
                    // ⛔ Убрали SnackBar
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PillButton(
                  text: 'Отменить сделку',
                  bg: const Color(0xFFFFEBEB),
                  border: const Color(0xFFF6CACA),
                  fg: const Color(0xFFD32F2F),
                  onTap: () {
                    setState(() => _status = _DealStatus.cancelled);
                    // ⛔ Убрали SnackBar
                  },
                ),
              ),
            ],
          ),
        );

      case _DealStatus.bought:
        return Center(
          child: _PillFinal(
            icon: CupertinoIcons.check_mark_circled,
            text: 'Слот куплен',
            bg: const Color(0xFFE9F7E3),
            border: const Color(0xFFD7EDCF),
            fg: const Color(0xFF2E7D32),
          ),
        );

      case _DealStatus.cancelled:
        return Center(
          child: _PillFinal(
            icon: CupertinoIcons.clear_circled,
            text: 'Сделка отменена',
            bg: const Color(0xFFFFEBEB),
            border: const Color(0xFFF6CACA),
            fg: const Color(0xFFD32F2F),
          ),
        );
    }
  }
}

/// Пилюля без иконки (для стартового состояния)
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
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
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

/// Пилюля с иконкой (финальное состояние)
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
        borderRadius: BorderRadius.circular(20),
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

/// ─── Дальше — чат-компоненты ───

class _DateSeparator extends StatelessWidget {
  final String text;
  const _DateSeparator({required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    alignment: Alignment.center,
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.black45),
    ),
  );
}

class _ParticipantRow extends StatelessWidget {
  final String avatarAsset;
  final String nameAndRole;
  const _ParticipantRow({required this.avatarAsset, required this.nameAndRole});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        CircleAvatar(radius: 14, backgroundImage: AssetImage(avatarAsset)),
        const SizedBox(width: 8),
        Text(
          nameAndRole,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ],
    ),
  );
}

class _BubbleLeft extends StatelessWidget {
  final String text;
  final String time;
  const _BubbleLeft({required this.text, required this.time});
  @override
  Widget build(BuildContext context) {
    final max = MediaQuery.of(context).size.width * 0.72;
    return Padding(
      padding: const EdgeInsets.only(right: 12, left: 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundImage: AssetImage('assets/Irina.png'),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                          color: Colors.black45,
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
            color: Color(0xFF6E6E6E),
          ),
        ],
      ),
    );
  }
}

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
                color: const Color(0xFFE9F7E3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD7EDCF)),
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
                          color: Colors.black45,
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
            backgroundImage: AssetImage('assets/Irina.png'),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _TimeBadge(time: time),
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
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _TimeBadge(time: time),
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

class _TimeBadge extends StatelessWidget {
  final String time;
  const _TimeBadge({required this.time});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      time,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}

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
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.plus_circle),
              onPressed: widget.onPickImage,
              color: Colors.black54,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Сообщение...',
                    hintStyle: TextStyle(color: Colors.black38),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(CupertinoIcons.paperplane_fill),
              onPressed: enabled ? widget.onSend : null,
              color: enabled ? AppColors.primary : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
