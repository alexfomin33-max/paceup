// lib/screens/profile/edit_profile_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/avatar_version_provider.dart';
import '../../providers/profile/profile_header_provider.dart';
import '../../core/utils/local_image_compressor.dart';
import '../../core/widgets/app_bar.dart'; // наш глобальный AppBar
import '../../../core/widgets/interactive_back_swipe.dart';
import '../../core/services/api_service.dart';

const double kAvatarSize = 88.0;
const double kQrBtnSize = 44.0;
const double kQrIconSize = 24.0;
const double kLabelWidth = 170.0;

/// Экран редактирования профиля
class EditProfileScreen extends ConsumerStatefulWidget {
  final int userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
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
              _FieldRow.dropdown(
                label: 'Пол',
                value: gender.isEmpty ? null : gender,
                items: const ['Мужской', 'Женский'],
                onChanged: setGender,
              ),
              _FieldRow.input(label: 'Город', controller: city, hint: 'Город'),
              _FieldRow.dropdown(
                label: 'Основной вид спорта',
                value: mainSport.isEmpty ? null : mainSport,
                items: const ['Бег', 'Велоспорт', 'Плавание'],
                onChanged: setSport,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            'Параметры',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondaryColor(context),
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
          Center(
            child: Text(
              'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.getTextPlaceholderColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ───────────────────────────── Логика экрана ─────────────────────────────

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
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
    );
    if (file == null) return;
    final compressed = await compressLocalImage(
      sourceFile: File(file.path),
      maxSide: 1600,
      jpegQuality: 85,
    );
    final bytes = await compressed.readAsBytes();
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
          color: AppColors.getSurfaceColor(context),
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

      // Обновляем данные профиля в шапке сразу после сохранения
      ref.read(profileHeaderProvider(widget.userId).notifier).reload();

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
        backgroundColor: AppColors.getBackgroundColor(context),

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
              context: context,
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
                color: AppColors.getSurfaceColor(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getBorderColor(context),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                CupertinoIcons.camera,
                size: 16,
                color: AppColors.getIconPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage({
    required BuildContext context,
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

      final dpr = MediaQuery.of(context).devicePixelRatio;
      final w = (size * dpr).round();
      return CachedNetworkImage(
        imageUrl: versionedUrl,
        // НЕ передаем cacheManager - используется DefaultCacheManager с offline support
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: w,
        maxWidthDiskCache: w,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.skeletonBase,
        ),
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
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
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
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
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
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkShadowSoft
                : AppColors.shadowSoft,
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.getDividerColor(context),
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
    this.dropdownItems,
    this.onDropdownChanged,
    required this.type,
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
    type: _FieldRowType.input,
  );

  factory _FieldRow.picker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) => _FieldRow._(
    label: label,
    value: value,
    onTap: onTap,
    type: _FieldRowType.picker,
  );

  factory _FieldRow.dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String) onChanged,
  }) => _FieldRow._(
    label: label,
    value: value,
    dropdownItems: items,
    onDropdownChanged: onChanged,
    type: _FieldRowType.dropdown,
  );

  final String label;

  // input
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  // picker
  final String? value;
  final VoidCallback? onTap;

  // dropdown
  final List<String>? dropdownItems;
  final void Function(String)? onDropdownChanged;

  final _FieldRowType type;

  Widget _buildFieldContent(BuildContext context) {
    switch (type) {
      case _FieldRowType.input:
        return TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hint,
          ),
          style: const TextStyle(fontSize: 14),
        );

      case _FieldRowType.picker:
        return InkWell(
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
                        ? AppColors.getTextTertiaryColor(context)
                        : AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: AppColors.getIconSecondaryColor(context),
              ),
            ],
          ),
        );

      case _FieldRowType.dropdown:
        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.md),
            style: TextStyle(
              color: value == null || value!.isEmpty
                  ? AppColors.getTextTertiaryColor(context)
                  : AppColors.getTextPrimaryColor(context),
              fontFamily: 'Inter',
              fontSize: 14,
            ),
            hint: Text(
              'Выбрать',
              style: TextStyle(
                color: AppColors.getTextTertiaryColor(context),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            onChanged: (String? newValue) {
              if (newValue != null && onDropdownChanged != null) {
                onDropdownChanged!(newValue);
              }
            },
            items: dropdownItems?.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(
                    color: AppColors.getTextPrimaryColor(context),
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 13,
      color: AppColors.getTextSecondaryColor(context),
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
          Expanded(child: _buildFieldContent(context)),
        ],
      ),
    );
  }
}

enum _FieldRowType { input, picker, dropdown }

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
          color: AppColors.getSurfaceColor(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: kQrIconSize,
          color: AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}
