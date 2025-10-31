// lib/screens/profile/edit_profile_screen.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../providers/avatar_version_provider.dart';
import '../../widgets/app_bar.dart'; // наш глобальный AppBar
import '../../../widgets/interactive_back_swipe.dart';
import '../../service/api_service.dart';

const double kAvatarSize = 88.0;
const double kQrBtnSize = 44.0;
const double kQrIconSize = 24.0;
const double kLabelWidth = 170.0;

/// Экран редактирования профиля
class EditProfileScreen extends StatefulWidget {
  final int userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// ───────────────────────────── Состояния/панели ─────────────────────────────

class _LoadingPane extends StatelessWidget {
  const _LoadingPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: CupertinoActivityIndicator(),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 28,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              'Ошибка загрузки:\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormPane extends StatelessWidget {
  const _FormPane({
    super.key,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.onPickAvatar,
    required this.firstName,
    required this.lastName,
    required this.nickname,
    required this.city,
    required this.height,
    required this.weight,
    required this.hrMax,
    required this.birthDate,
    required this.gender,
    required this.mainSport,
    required this.setBirthDate,
    required this.setGender,
    required this.setSport,
    required this.pickBirthDate,
    required this.pickFromList,
  });

  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final VoidCallback onPickAvatar;

  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController nickname;
  final TextEditingController city;
  final TextEditingController height;
  final TextEditingController weight;
  final TextEditingController hrMax;

  final DateTime? birthDate;
  final String gender;
  final String mainSport;

  final void Function(DateTime) setBirthDate;
  final void Function(String) setGender;
  final void Function(String) setSport;

  final Future<void> Function() pickBirthDate;
  final Future<void> Function({
    required String title,
    required List<String> options,
    required String current,
    required void Function(String) onPicked,
  })
  pickFromList;

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Шапка: аватар + Имя/Фамилия + QR ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AvatarEditable(
                bytes: avatarBytes,
                avatarUrl: avatarUrl,
                size: kAvatarSize,
                onTap: onPickAvatar,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NameBlock(
                  firstController: firstName,
                  secondController: lastName,
                  firstHint: 'Имя',
                  secondHint: 'Фамилия',
                ),
              ),
              const SizedBox(width: 12),
              _CircleIconBtn(
                icon: CupertinoIcons.qrcode_viewfinder,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Блок 1 ──
          _GroupBlock(
            children: [
              _FieldRow.input(
                label: 'Никнейм',
                controller: nickname,
                hint: 'nickname',
              ),
              _FieldRow.picker(
                label: 'Дата рождения',
                value: _formatDate(birthDate),
                onTap: pickBirthDate,
              ),
              _FieldRow.picker(
                label: 'Пол',
                value: gender,
                onTap: () => pickFromList(
                  title: 'Пол',
                  options: const ['Мужской', 'Женский'],
                  current: gender,
                  onPicked: setGender,
                ),
              ),
              _FieldRow.input(label: 'Город', controller: city, hint: 'Город'),
              _FieldRow.picker(
                label: 'Основной вид спорта',
                value: mainSport,
                onTap: () => pickFromList(
                  title: 'Основной вид спорта',
                  options: const ['Бег', 'Велоспорт', 'Плавание'],
                  current: mainSport,
                  onPicked: setSport,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Параметры',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          _GroupBlock(
            children: [
              _FieldRow.input(
                label: 'Рост, см',
                controller: height,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              _FieldRow.input(
                label: 'Вес, кг',
                controller: weight,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              _FieldRow.input(
                label: 'Максимальный пульс',
                controller: hrMax,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textPlaceholder),
            ),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────────── Логика экрана ─────────────────────────────

class _EditProfileScreenState extends State<EditProfileScreen> {
  // загрузка/ошибка/сохранение
  bool _loadingProfile = false;
  String? _loadError;
  bool _saving = false;

  // аватар
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatarBytes;

  // формы
  final _firstName = TextEditingController(text: '');
  final _lastName = TextEditingController(text: '');
  final _nickname = TextEditingController(text: '');
  final _city = TextEditingController(text: '');
  final _height = TextEditingController(text: '');
  final _weight = TextEditingController(text: '');
  final _hrMax = TextEditingController(text: '');

  // состояние
  DateTime? _birthDate = DateTime(1980, 6, 24);
  String _gender = '';
  String _mainSport = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

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

  // ── JSON/утилиты
  String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? _i(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  DateTime? _date(dynamic v) {
    final s = _s(v);
    if (s == null) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(s);
    if (m != null) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) return DateTime(y, mo, d);
    }
    return null;
  }

  String? _mapGender(dynamic v) {
    final s = _s(v)?.toLowerCase();
    if (s == null) return null;
    if (s == 'm' ||
        s == 'male' ||
        s.contains('муж') ||
        s.contains('Муж') ||
        s.contains('Мужской')) {
      return 'Мужской';
    }
    if (s == 'f' ||
        s == 'female' ||
        s.contains('жен') ||
        s.contains('Жен') ||
        s.contains('Женский')) {
      return 'Женский';
    }
    return 'Другое';
  }

  String? _mapSport(dynamic v) {
    final s = _s(v);
    if (s == null) return null;
    switch (s.toLowerCase()) {
      case 'run':
      case 'running':
      case 'бег':
      case 'Бег':
        return 'Бег';
      case 'bike':
      case 'cycling':
      case 'велоспорт':
      case 'велосипед':
      case 'Велоспорт':
      case 'Велосипед':
        return 'Велоспорт';
      case 'swim':
      case 'swimming':
      case 'плавание':
      case 'Плавание':
        return 'Плавание';
      default:
        return s;
    }
  }

  // ── HTTP: загрузка профиля
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loadingProfile = true;
      _loadError = null;
    });

    try {
      final api = ApiService();
      final map = await api.post(
        '/user_profile_edit.php',
        body: {
          'user_id': '${widget.userId}',
          'load': true,
          'edit': false,
        }, // 🔹 PHP ожидает строки
        timeout: const Duration(seconds: 12),
      );

      final dynamic raw = map['profile'] ?? map['data'] ?? map;
      if (raw is! Map) {
        throw const FormatException('Bad payload: not a JSON object');
      }
      final j = Map<String, dynamic>.from(raw);

      _firstName.text = _s(j['name']) ?? _firstName.text;
      _lastName.text = _s(j['surname']) ?? _lastName.text;
      _nickname.text = _s(j['username']) ?? _nickname.text;
      _city.text = _s(j['city']) ?? _city.text;

      final height = _i(j['height']);
      final weight = _i(j['weight']);
      final hrMax = _i(j['pulse']);

      if (height != null) _height.text = '$height';
      if (weight != null) _weight.text = '$weight';
      if (hrMax != null) _hrMax.text = '$hrMax';

      final bd = _date(j['dateage']);
      final g = _mapGender(j['gender']);
      final sp = _mapSport(j['sport']);
      final avatar = _s(j['avatar']);

      if (!mounted) return;
      setState(() {
        if (bd != null) _birthDate = bd;
        if (g != null) _gender = g;
        if (sp != null) _mainSport = sp;
        if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
      });
    } catch (e, st) {
      debugPrint('❌ [EditProfile] error: $e\n$st');
      if (mounted) {
        setState(() => _loadError = e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки профиля: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  // ── Пикеры/утилиты
  Future<void> _pickAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight:
          2048, // ВАЖНО: задаём одинаковые ограничения для сохранения пропорций
      imageQuality: 98,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _pickBirthDate() async {
    final initial = _birthDate ?? DateTime(1990, 1, 1);
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        return Container(
          height: 260 + bottom,
          color: AppColors.surface,
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

  int? _toInt(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Map<String, dynamic> _buildSavePayload() {
    String formatDateIsoOut(DateTime? d) {
      if (d == null) return '';
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '$y-$m-$dd';
    }

    String canonGenderOut(String g) {
      final s = g.trim().toLowerCase();
      if (s.contains('жен')) return 'Женский';
      if (s.contains('муж')) return 'Мужской';
      if (s == 'f' || s == 'female') return 'Женский';
      if (s == 'm' || s == 'male') return 'Мужской';
      return 'Другое';
    }

    String canonSportOut(String s) {
      final v = s.trim().toLowerCase();
      if (v.contains('вел')) return 'Велоспорт';
      if (v.contains('плав') || v.contains('swim')) return 'Плавание';
      return 'Бег';
    }

    final map = <String, dynamic>{
      'user_id': widget.userId,
      'edit': true,
      'load': false,
      'name': _firstName.text.trim(),
      'surname': _lastName.text.trim(),
      'username': _nickname.text.trim(),
      'city': _city.text.trim(),
      'dateage': formatDateIsoOut(_birthDate),
      'gender': canonGenderOut(_gender),
      'sport': canonSportOut(_mainSport),
      'height': _toInt(_height.text),
      'weight': _toInt(_weight.text),
      'pulse': _toInt(_hrMax.text),
    };

    if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
      map['avatar_base64'] = base64Encode(_avatarBytes!);
      map['avatar_mime'] = 'image/jpeg';
    }

    return map;
  }

  Future<void> _onSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final payload = _buildSavePayload();

    setState(() => _saving = true);
    try {
      final api = ApiService();
      final map = await api.post(
        '/user_profile_edit.php',
        body: payload,
        timeout: const Duration(seconds: 15),
      );

      final ok =
          map['ok'] == true || map['status'] == 'ok' || map['success'] == true;

      if (!ok && map.containsKey('error')) {
        throw Exception(map['error'].toString());
      }

      if (!mounted) return;
      Navigator.of(context).maybePop(true);
    } catch (e, st) {
      debugPrint('❌ [EditProfile] SAVE error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// ── UI ──
  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        // единый фон экрана
        backgroundColor: AppColors.background,

        // глобальная шапка
        appBar: PaceAppBar(
          title: 'Профиль',
          actions: [
            TextButton(
              onPressed: (_saving || _loadingProfile) ? null : _onSave,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: _saving
                  ? const CupertinoActivityIndicator(radius: 8)
                  : const Text('Сохранить'),
            ),
          ],
        ),

        // важное: единая компоновка для всех состояний + «прижатие» к верху
        body: GestureDetector(
          // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: _loadingProfile
                ? const _LoadingPane(key: ValueKey('loading'))
                : (_loadError != null)
                ? _ErrorPane(
                    key: const ValueKey('error'),
                    message: _loadError!,
                    onRetry: _loadProfile,
                  )
                : _FormPane(
                    key: const ValueKey('form'),
                    avatarUrl: _avatarUrl,
                    avatarBytes: _avatarBytes,
                    onPickAvatar: _pickAvatar,
                    firstName: _firstName,
                    lastName: _lastName,
                    nickname: _nickname,
                    city: _city,
                    height: _height,
                    weight: _weight,
                    hrMax: _hrMax,
                    birthDate: _birthDate,
                    gender: _gender,
                    mainSport: _mainSport,
                    setBirthDate: (d) => setState(() => _birthDate = d),
                    setGender: (g) => setState(() => _gender = g),
                    setSport: (s) => setState(() => _mainSport = s),
                    pickBirthDate: _pickBirthDate,
                    pickFromList: _pickFromList,
                  ),
          ),
        ),
      ),
    );
  }
}

/// ───────────────────────────── UI атомы ─────────────────────────────

class _AvatarEditable extends ConsumerWidget {
  const _AvatarEditable({
    required this.bytes,
    required this.avatarUrl,
    required this.size,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? avatarUrl;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (size * dpr).round();

    // Получаем текущую версию аватарки для cache-busting
    final avatarVersion = ref.watch(avatarVersionProvider);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: _buildAvatarImage(
              size: size,
              cacheWidth: cacheW,
              avatarVersion: avatarVersion,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.camera,
                size: 16,
                color: AppColors.iconPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage({
    required double size,
    required int cacheWidth,
    required int avatarVersion,
  }) {
    // 1) Выбранные байты (превью выбранного изображения)
    if (bytes != null && bytes!.isNotEmpty) {
      try {
        return Image.memory(
          bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // НЕ используем cacheWidth/cacheHeight для Image.memory!
          // Они искажают пропорции, если оригинальное изображение не квадратное.
          // BoxFit.cover сам корректно обрежет изображение в квадрат 88×88.
          errorBuilder: (_, _, _) => Image.asset(
            'assets/avatar_0.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        return Image.asset(
          'assets/avatar_0.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    }

    // 2) URL - используем CachedNetworkImage для синхронизации с профилем и лентой
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      // Добавляем версию для cache-busting
      final separator = url.contains('?') ? '&' : '?';
      final versionedUrl = avatarVersion > 0
          ? '$url${separator}v=$avatarVersion'
          : url;

      return CachedNetworkImage(
        imageUrl: versionedUrl,
        // НЕ передаем cacheManager - используется DefaultCacheManager с offline support
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(width: size, height: size, color: AppColors.skeletonBase),
        errorWidget: (context, url, error) => Image.asset(
          'assets/avatar_0.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // 3) Фолбэк-ассет
    return Image.asset(
      'assets/avatar_0.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
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
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.divider,
            indent: 10,
            endIndent: 10,
          ),
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

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.divider,
                indent: 10,
                endIndent: 10,
              ),
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
      color: AppColors.textSecondary,
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          CupertinoIcons.chevron_down,
                          size: 18,
                          color: AppColors.iconTertiary,
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
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: kQrIconSize, color: AppColors.iconPrimary),
      ),
    );
  }
}
