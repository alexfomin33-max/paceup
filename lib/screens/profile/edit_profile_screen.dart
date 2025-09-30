// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';

const double kToolbarH = 52.0;
const double kAvatarSize = 88.0; // увеличенный аватар
const double kQrBtnSize = 44.0; // круглая кнопка
const double kQrIconSize = 24.0; // увеличенная иконка
const double kLabelWidth = 170.0; // ширина лейбла слева (стиль regstep2)

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Контроллеры
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

  // Выбранная пользователем аватарка (байты)
  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatarBytes;

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
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  Future<void> _pickBirthDate() async {
    final initial = _birthDate ?? DateTime(1990, 1, 1);
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return Container(
          height: 260 + bottom,
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: initial,
              maximumYear: DateTime.now().year,
              minimumYear: 1900,
              onDateTimeChanged: (d) => setState(() => _birthDate = d),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFromList({
    required String title,
    required List<String> options,
    required String current,
    required void Function(String) onPicked,
  }) async {
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: options
            .map(
              (o) => CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx, o),
                isDefaultAction: o == current,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(o),
                    if (o == current) ...[
                      const SizedBox(width: 6),
                      const Icon(CupertinoIcons.checkmark_alt, size: 16),
                    ],
                  ],
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          isDestructiveAction: true,
          child: const Text('Отмена'),
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  void _onSave() {
    // TODO: собрать данные (включая _avatarBytes) и отправить на API
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ЕДИНЫЙ СТИЛЬ: AppBar статичный, белый, без blur и теней
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        toolbarHeight: kToolbarH,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          splashRadius: 22,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Профиль',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _onSave,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondary, // ✅ цвет «Сохранить»
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Сохранить'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: Color(0xFFE5E7EB)), // тонкая нижняя линия
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ШАПКА: аватар + Имя/Фамилия в белом блоке + круглая белая кнопка QR ──
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center, // ✅ центр по высоте блока имени
                children: [
                  _AvatarEditable(
                    bytes: _avatarBytes,
                    size: kAvatarSize,
                    onTap: _pickAvatar, // ✅ выбор новой аватарки
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NameBlock(
                      firstController: _firstName,
                      secondController: _lastName,
                      firstHint: 'Имя',
                      secondHint: 'Фамилия',
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleIconBtn(
                    icon: CupertinoIcons.qrcode_viewfinder,
                    onTap: () {
                      // TODO: открыть визитку/QR
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── ГРУППА 1: Ник/Дата/Пол/Город/Спорт ──
              _GroupBlock(
                children: [
                  _FieldRow.input(
                    label: 'Никнейм',
                    controller: _nickname,
                    hint: 'nickname',
                  ),
                  _FieldRow.picker(
                    label: 'Дата рождения',
                    value: _formatDate(_birthDate),
                    onTap: _pickBirthDate,
                  ),
                  _FieldRow.picker(
                    label: 'Пол',
                    value: _gender,
                    onTap: () => _pickFromList(
                      title: 'Пол',
                      options: const ['Мужской', 'Женский'],
                      current: _gender,
                      onPicked: (v) => setState(() => _gender = v),
                    ),
                  ),
                  _FieldRow.input(
                    label: 'Город',
                    controller: _city,
                    hint: 'Город',
                  ),
                  _FieldRow.picker(
                    label: 'Основной вид спорта',
                    value: _mainSport,
                    onTap: () => _pickFromList(
                      title: 'Основной вид спорта',
                      options: const ['Бег', 'Велоспорт', 'Плавание'],
                      current: _mainSport,
                      onPicked: (v) => setState(() => _mainSport = v),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── ГРУППА 2: Параметры ──
              const Text(
                'Параметры',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              _GroupBlock(
                children: [
                  _FieldRow.input(
                    label: 'Рост, см',
                    controller: _height,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _FieldRow.input(
                    label: 'Вес, кг',
                    controller: _weight,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _FieldRow.input(
                    label: 'Максимальный пульс',
                    controller: _hrMax,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
                  textAlign: TextAlign.center, // ✅ по центру
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ───────────────────────────── UI атомы ─────────────────────────────

/// Кликабельный аватар с индикатором «камера» снизу справа.
class _AvatarEditable extends StatelessWidget {
  const _AvatarEditable({
    required this.bytes,
    required this.size,
    required this.onTap,
  });

  final Uint8List? bytes;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: bytes != null
                ? Image.memory(
                    bytes!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/Avatar_0.png',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.camera,
                size: 16,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Белый блок для Имя/Фамилия со своим разделителем (как у групп ниже)
class _NameBlock extends StatelessWidget {
  const _NameBlock({
    required this.firstController,
    required this.secondController,
    required this.firstHint,
    required this.secondHint,
  });

  final TextEditingController firstController;
  final TextEditingController secondController;
  final String firstHint;
  final String secondHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 46,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BareTextField(
                  controller: firstController,
                  hint: firstHint,
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 46,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BareTextField(
                  controller: secondController,
                  hint: secondHint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Белая группа с разделителями (как regstep2): без теней
class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// Одна строка группы: либо input, либо picker
class _FieldRow extends StatelessWidget {
  const _FieldRow._({
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.value,
    this.onTap,
    required this.isPicker,
  });

  factory _FieldRow.input({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) => _FieldRow._(
    label: label,
    controller: controller,
    hint: hint,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    isPicker: false,
  );

  factory _FieldRow.picker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) => _FieldRow._(label: label, value: value, onTap: onTap, isPicker: true);

  final String label;

  // input
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  // picker
  final String? value;
  final VoidCallback? onTap;

  final bool isPicker;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 13,
      color: Color(0xFF6B7280),
      fontWeight: FontWeight.w500,
    );

    return SizedBox(
      height: 50,
      child: Row(
        children: [
          SizedBox(
            width: kLabelWidth,
            child: Text(label, style: labelStyle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isPicker
                ? InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onTap,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            (value ?? '').isEmpty ? 'Выбрать' : value!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: (value ?? '').isEmpty
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
                  )
                : TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hint,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Текстовое поле без бордеров/фона, для шапки (Имя/Фамилия)
class _BareTextField extends StatelessWidget {
  const _BareTextField({required this.controller, this.hint});

  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

/// Круглая белая кнопка для QR (без теней)
class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: kQrBtnSize,
        height: kQrBtnSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: kQrIconSize, color: const Color(0xFF111827)),
      ),
    );
  }
}
