// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

const double kToolbarH = 52.0;
const double kAvatarSize = 88.0; // увеличенный аватар
const double kQrBtnSize = 44.0; // круглая кнопка
const double kQrIconSize = 24.0; // увеличенная иконка
const double kLabelWidth = 170.0; // ширина лейбла слева (стиль regstep2)

class EditProfileScreen extends StatefulWidget {
  final int userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
          // ── ШАПКА: аватар + Имя/Фамилия + круглая кнопка QR ──
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

          // ── ГРУППА 1 ──
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

class _EditProfileScreenState extends State<EditProfileScreen> {
  // --- Состояния загрузки/ошибок ---
  bool _loadingProfile = false;
  String? _loadError;
  bool _saving = false;

  // --- Аватар (URL с сервера и/или выбранные байты) ---
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();
  Uint8List? _avatarBytes;

  // --- Контроллеры формы (оставлены как в оригинале) ---
  final _firstName = TextEditingController(text: '');
  final _lastName = TextEditingController(text: '');
  final _nickname = TextEditingController(text: '');
  final _city = TextEditingController(text: '');
  final _height = TextEditingController(text: '');
  final _weight = TextEditingController(text: '');
  final _hrMax = TextEditingController(text: '');

  // --- Поля состояния ---
  DateTime? _birthDate = DateTime(1980, 6, 24);
  String _gender = '';
  String _mainSport = '';

  @override
  void initState() {
    super.initState();
    _loadProfile(); // грузим профиль сразу после открытия
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

  // ──────────────── Утилиты парсинга/логирования ────────────────
  Map<String, dynamic> _safeDecodeJsonAsMap(List<int> bodyBytes) {
    final raw = utf8.decode(bodyBytes, allowMalformed: true);
    final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    final v = json.decode(cleaned);
    if (v is Map<String, dynamic>) return v;
    throw const FormatException('JSON is not an object');
  }

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
    // ISO: YYYY-MM-DD / полноценный ISO
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    // dd.MM.yyyy
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

  // ──────────────── HTTP: Загрузка профиля ────────────────
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loadingProfile = true;
      _loadError = null;
    });

    try {
      // ПРАВЬ URL под свой бэкенд при необходимости
      final uri = Uri.parse('http://api.paceup.ru/user_profile_edit.php');
      final payload = {'user_id': widget.userId, 'load': true, 'edit': false};

      debugPrint('➡️ [EditProfile] POST $uri\npayload=${jsonEncode(payload)}');

      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint('⬅️ [EditProfile] status=${res.statusCode}');
      final bodyStr = utf8.decode(res.bodyBytes, allowMalformed: true);
      final bodyPreview = bodyStr.substring(
        0,
        bodyStr.length < 600 ? bodyStr.length : 600,
      );
      debugPrint('[EditProfile] bodyPreview: $bodyPreview');

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final map = _safeDecodeJsonAsMap(res.bodyBytes);
      final dynamic raw = map['profile'] ?? map['data'] ?? map;
      if (raw is! Map) {
        throw const FormatException('Bad payload: not a JSON object');
      }
      final j = Map<String, dynamic>.from(raw);

      // Контроллеры
      _firstName.text = _s(j['name']) ?? _firstName.text;
      _lastName.text = _s(j['surname']) ?? _lastName.text;
      _nickname.text = _s(j['username']) ?? _nickname.text;
      _city.text = _s(j['city']) ?? _city.text;

      final height = _i(j['height']) ?? _i(j['height']);
      final weight = _i(j['weight']) ?? _i(j['weight']);
      final hrMax = _i(j['pulse']) ?? _i(j['pulse']);

      if (height != null) _height.text = '$height';
      if (weight != null) _weight.text = '$weight';
      if (hrMax != null) _hrMax.text = '$hrMax';

      // Поля состояния
      final bd = _date(j['dateage'] ?? j['dateage']);
      final g = _mapGender(j['gender']);
      final sp = _mapSport(j['sport'] ?? j['sport']);
      final avatar = _s(j['avatar']); // полный URL

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

  // ──────────────── Хелперы UI ────────────────
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

  String _formatDateIsoOut(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd'; // YYYY-MM-DD
  }

  String _canonGenderOut(String g) {
    final s = g.trim().toLowerCase();
    if (s.contains('жен')) return 'Женский';
    if (s.contains('муж')) return 'Мужской';
    if (s == 'f' || s == 'female') return 'Женский';
    if (s == 'm' || s == 'male') return 'Мужской';
    return 'Другое';
  }

  String _canonSportOut(String s) {
    final v = s.trim().toLowerCase();
    if (v.contains('вел')) return 'Велоспорт';
    if (v.contains('плав') || v.contains('swim')) return 'Плавание';
    return 'Бег'; // дефолт — Бег
  }

  int? _toInt(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  /// Собираем полезную нагрузку (двойные ключи для совместимости бекенда)
  Map<String, dynamic> _buildSavePayload() {
    final birthIso = _formatDateIsoOut(_birthDate);
    final gender = _canonGenderOut(_gender);
    final sport = _canonSportOut(_mainSport);

    final height = _toInt(_height.text);
    final weight = _toInt(_weight.text);
    final hrMax = _toInt(_hrMax.text);

    final map = <String, dynamic>{
      'user_id': widget.userId,
      'edit': true,
      'load': false,

      // Имя/фамилия/ник
      'name': _firstName.text.trim(),
      'surname': _lastName.text.trim(),
      'username': _nickname.text.trim(),

      // Прочее
      'city': _city.text.trim(),
      'dateage': birthIso, // дубль
      'gender': gender,
      'sport': sport,

      'height': height, // дубль
      'weight': weight, // дубль
      'pulse': hrMax, // дубль
    };

    // Если пользователь выбрал новый аватар — отправим base64.
    if (_avatarBytes != null && _avatarBytes!.isNotEmpty) {
      map['avatar_base64'] = base64Encode(_avatarBytes!);
      // по желанию можно указать mime
      map['avatar_mime'] = 'image/jpeg';
    }

    return map;
  }

  Future<void> _pickAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 98,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _onSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final uri = Uri.parse('http://api.paceup.ru/user_profile_edit.php');
    final payload = _buildSavePayload();

    setState(() => _saving = true);
    try {
      debugPrint(
        '➡️ [EditProfile] SAVE POST $uri\npayload=${jsonEncode(payload)}',
      );

      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('⬅️ [EditProfile] SAVE status=${res.statusCode}');
      final bodyStr = utf8.decode(res.bodyBytes, allowMalformed: true);
      debugPrint(
        '[EditProfile] SAVE bodyPreview: ${bodyStr.length > 600 ? bodyStr.substring(0, 600) : bodyStr}',
      );

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      // Пытаемся понять ответ (универсально)
      Map<String, dynamic>? map;
      try {
        map = _safeDecodeJsonAsMap(res.bodyBytes);
      } catch (_) {}

      final ok =
          (map != null &&
              (map['ok'] == true ||
                  map['status'] == 'ok' ||
                  map['success'] == true)) ||
          (map != null && map['error'] == null);

      if (!ok && map != null && map.containsKey('error')) {
        throw Exception(map['error'].toString());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль сохранён')));

      // Возврат назад после успешного сохранения
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

  // ──────────────── UI ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        toolbarHeight: kToolbarH,
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          splashRadius: 22,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Профиль', style: AppTextStyles.h17w6),
        actions: [
          TextButton(
            onPressed: (_saving || _loadingProfile)
                ? null
                : _onSave, // ← добавили _loadingProfile
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
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: SizedBox(
            height: 0.5,
            child: ColoredBox(color: AppColors.divider),
          ),
        ),
      ),

      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _loadingProfile
              ? const Center(
                  key: ValueKey('loading'),
                  child: CupertinoActivityIndicator(),
                )
              : (_loadError != null)
              ? _ErrorPane(
                  key: const ValueKey('error'),
                  message: _loadError!,
                  onRetry: _loadProfile,
                )
              : _FormPane(
                  key: const ValueKey('form'),
                  // ↓ передаём всё, что нужно внутрь формы
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
    );
  }
}

/// ───────────────────────────── UI атомы ─────────────────────────────

/// Кликабельный аватар: байты -> URL -> ассет. Безопасный декодер.
class _AvatarEditable extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = (size * dpr).round();

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: _buildAvatarImage(size: size, cacheWidth: cacheW),
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

  Widget _buildAvatarImage({required double size, required int cacheWidth}) {
    // 1) Выбранные байты — приоритет
    if (bytes != null && bytes!.isNotEmpty) {
      try {
        return Image.memory(
          bytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
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

    // 2) URL с сервера
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => Image.asset(
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

/// Белый блок Имя/Фамилия (как в исходнике)
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
        border: Border.all(color: AppColors.border, width: 1),
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
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
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

/// Белая группа с разделителями
class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
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
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: kQrIconSize, color: AppColors.iconPrimary),
      ),
    );
  }
}
