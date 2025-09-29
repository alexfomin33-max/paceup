// lib/screens/profile/edit_profile_screen.dart
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Экран редактирования профиля (iOS-стиль)
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Контроллеры полей
  final _firstName = TextEditingController(text: 'Константин');
  final _lastName = TextEditingController(text: 'Разумовский');
  final _nickname = TextEditingController(text: 'bladerunner');
  final _city = TextEditingController(text: 'Санкт-Петербург');
  final _height = TextEditingController(text: '182');
  final _weight = TextEditingController(text: '78');
  final _hrMax = TextEditingController(text: '190');

  DateTime? _birthDate = DateTime(1987, 6, 24);
  String _gender = 'Мужской';
  String _mainSport = 'Бег';

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _nickname.dispose();
    _city.dispose();
    _height.dispose();
    _weight.dispose();
    _hrMax.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString().padLeft(4, '0');
    return '$dd.$mm.$yy';
  }

  Future<void> _pickBirthDate() async {
    final initial = _birthDate ?? DateTime(1990, 1, 1);
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return _BottomPickerShell(
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: initial,
            maximumYear: DateTime.now().year,
            minimumYear: 1900,
            onDateTimeChanged: (d) => setState(() => _birthDate = d),
          ),
        );
      },
    );
  }

  Future<void> _pickGender() async {
    final res = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => _ActionSheet<String>(
        title: 'Пол',
        options: const ['Мужской', 'Женский', 'Другое'],
        selected: _gender,
      ),
    );
    if (res != null) setState(() => _gender = res);
  }

  Future<void> _pickMainSport() async {
    final res = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => _ActionSheet<String>(
        title: 'Основной вид спорта',
        options: const [
          'Бег',
          'Триатлон',
          'Велоспорт',
          'Плавание',
          'Функц. тренинг',
        ],
        selected: _mainSport,
      ),
    );
    if (res != null) setState(() => _mainSport = res);
  }

  void _onSave() {
    // TODO: отправка на сервер
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: Colors.white.withValues(alpha: 0.50),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        shape: const Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 0.6),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Профиль',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _onSave,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 12,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Шапка: аватар + Имя/Фамилия + кнопка (QR/изменить)
                  _Card(
                    child: Row(
                      children: [
                        _Avatar(
                          size: 56,
                          image: const AssetImage('assets/Avatar_1.png'),
                          onChange: () {
                            // TODO: выбор аватара / фотопикер
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              _LabeledField(
                                label: null, // без лейбла — как на макете
                                child: _Input(
                                  textController: _firstName,
                                  hint: 'Имя',
                                ),
                              ),
                              const SizedBox(height: 6),
                              _LabeledField(
                                label: null,
                                child: _Input(
                                  textController: _lastName,
                                  hint: 'Фамилия',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SquareIconButton(
                          icon: CupertinoIcons.qrcode_viewfinder,
                          onPressed: () {
                            // TODO: открыть QR/визитку
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Блок «Никнейм»
                  _LabeledField(
                    label: 'Никнейм',
                    child: _Input(textController: _nickname, hint: 'nickname'),
                  ),
                  const SizedBox(height: 12),

                  // Дата рождения
                  _LabeledField(
                    label: 'Дата рождения',
                    child: _PickerTile(
                      value: _formatDate(_birthDate),
                      onTap: _pickBirthDate,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Пол
                  _LabeledField(
                    label: 'Пол',
                    child: _PickerTile(value: _gender, onTap: _pickGender),
                  ),
                  const SizedBox(height: 12),

                  // Город
                  _LabeledField(
                    label: 'Город',
                    child: _Input(textController: _city, hint: 'Город'),
                  ),
                  const SizedBox(height: 12),

                  // Основной вид спорта
                  _LabeledField(
                    label: 'Основной вид спорта',
                    child: _PickerTile(
                      value: _mainSport,
                      onTap: _pickMainSport,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Подзаголовок «Параметры»
                  const Text(
                    'Параметры',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Рост / Вес / Максимальный пульс
                  _LabeledField(
                    label: 'Рост, см',
                    child: _Input(
                      textController: _height,
                      hint: 'Рост',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _LabeledField(
                    label: 'Вес, кг',
                    child: _Input(
                      textController: _weight,
                      hint: 'Вес',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _LabeledField(
                    label: 'Максимальный пульс',
                    child: _Input(
                      textController: _hrMax,
                      hint: 'Макс. пульс',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────────────── UI атомы ─────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.child, this.label});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
        ],
        _Card(child: child),
      ],
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.textController, this.hint, this.keyboardType});

  final TextEditingController textController;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textController,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
      ),
      style: const TextStyle(fontSize: 16),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? 'Выбрать' : value,
                style: TextStyle(
                  fontSize: 16,
                  color: value.isEmpty
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111827),
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, required this.image, this.onChange});

  final double size;
  final ImageProvider image;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(radius: size / 2, backgroundImage: image),
        if (onChange != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onChange,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.camera,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Icon(icon, size: 20, color: const Color(0xFF111827)),
        ),
      ),
    );
  }
}

/// Общая обёртка для iOS-пикеров снизу
class _BottomPickerShell extends StatelessWidget {
  const _BottomPickerShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      height: 260 + bottom,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _ActionSheet<T> extends StatelessWidget {
  const _ActionSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      title: Text(title),
      actions: options
          .map(
            (o) => CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, o),
              isDefaultAction: o == selected,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(o),
                  if (o == selected) ...[
                    const SizedBox(width: 6),
                    const Icon(CupertinoIcons.checkmark_alt, size: 16),
                  ],
                ],
              ),
            ),
          )
          .toList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        isDestructiveAction: true,
        child: const Text('Отмена'),
      ),
    );
  }
}
