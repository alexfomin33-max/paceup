// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE NOTIFIER
//
//  Бизнес-логика для экрана редактирования профиля
//  Управляет состоянием формы, загрузкой и сохранением данных
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/services/api_service.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/utils/image_picker_helper.dart';
import '../../../../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset;
import '../../../../../../core/providers/form_state_provider.dart';
import '../../../../../../providers/avatar_version_provider.dart';
import '../../../../providers/profile_header_provider.dart';
import 'edit_profile_state.dart';

/// ───────────────────────────── Notifier ─────────────────────────────

/// Notifier для управления состоянием редактирования профиля
class EditProfileNotifier extends StateNotifier<EditProfileState> {
  final ApiService _api;
  final int userId;
  final Ref _ref;

  EditProfileNotifier({
    required ApiService api,
    required this.userId,
    required Ref ref,
  })  : _api = api,
        _ref = ref,
        super(EditProfileState.initial()) {
    // Загружаем профиль при инициализации
    Future.microtask(() => loadProfile());
  }

  /// Загрузка данных профиля с сервера
  Future<void> loadProfile() async {
    final formNotifier = _ref.read(formStateProvider.notifier);

    await formNotifier.submitWithLoading(
      () async {
        final map = await _api.post(
          '/user_profile_edit.php',
          body: {
            'user_id': '$userId',
            'load': true,
            'edit': false,
          },
          timeout: const Duration(seconds: 12),
        );

        final dynamic raw = map['profile'] ?? map['data'] ?? map;
        if (raw is! Map) {
          throw const FormatException('Bad payload: not a JSON object');
        }
        final j = Map<String, dynamic>.from(raw);

        // Парсим данные
        final firstName = _s(j['name']) ?? '';
        final lastName = _s(j['surname']) ?? '';
        final nickname = _s(j['username']) ?? '';
        final city = _s(j['city']) ?? '';
        final height = _i(j['height']);
        final weight = _i(j['weight']);
        final hrMax = _i(j['pulse']);
        final birthDate = _date(j['dateage']);
        final gender = _mapGender(j['gender']) ?? '';
        final mainSport = _mapSport(j['sport']) ?? '';
        final avatar = _s(j['avatar']);
        final background = _s(j['background_url'] ?? j['background']);

        // Обновляем состояние
        state = state.copyWith(
          firstName: firstName,
          lastName: lastName,
          nickname: nickname,
          city: city,
          height: height?.toString() ?? '',
          weight: weight?.toString() ?? '',
          hrMax: hrMax?.toString() ?? '',
          birthDate: birthDate,
          gender: gender,
          mainSport: mainSport,
          avatarUrl: avatar,
          backgroundUrl: background,
        );
      },
      onError: (error) {
        state = state.copyWith(
          loadError: ErrorHandler.format(error),
        );
      },
    );
  }

  /// Выбор аватара из галереи с обрезкой в пропорции 1:1
  Future<void> pickAvatar(BuildContext context) async {
    // ── выбираем аватарку с обрезкой в фиксированную пропорцию 1:1
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: 1.0,
      maxSide: ImageCompressionPreset.avatar.maxSide,
      jpegQuality: ImageCompressionPreset.avatar.quality,
      cropTitle: 'Обрезка аватарки',
    );
    if (processed == null) return;

    final bytes = await processed.readAsBytes();
    state = state.copyWith(avatarBytes: bytes);
  }

  /// Выбор фоновой картинки из галереи с обрезкой в фиксированную высоту 180.0
  Future<void> pickBackground(BuildContext context) async {
    // ── вычисляем aspectRatio на основе фиксированной высоты 180.0 и ширины экрана
    final screenWidth = MediaQuery.of(context).size.width;
    const fixedHeight = 180.0;
    final aspectRatio = screenWidth / fixedHeight;
    
    // ── выбираем фоновую картинку с обрезкой в вычисленную пропорцию
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: aspectRatio,
      maxSide: ImageCompressionPreset.background.maxSide,
      jpegQuality: ImageCompressionPreset.background.quality,
      cropTitle: 'Обрезка фонового фото',
    );
    if (processed == null) return;

    final bytes = await processed.readAsBytes();
    state = state.copyWith(backgroundBytes: bytes);
  }

  /// Обновление даты рождения (вызывается из UI при выборе даты)
  void updateBirthDateFromPicker(DateTime date) {
    state = state.copyWith(birthDate: date);
  }

  /// Сохранение профиля
  Future<void> save() async {
    final formNotifier = _ref.read(formStateProvider.notifier);

    if (formNotifier.state.isSubmitting) return;

    final payload = _buildSavePayload();

    await formNotifier.submit(
      () async {
        final map = await _api.post(
          '/user_profile_edit.php',
          body: payload,
          timeout: const Duration(seconds: 15),
        );

        final ok =
            map['ok'] == true ||
            map['status'] == 'ok' ||
            map['success'] == true;

        if (!ok && map.containsKey('error')) {
          throw Exception(map['error'].toString());
        }
      },
      onSuccess: () {
        // ────────────────────────────────────────────────────────────────
        // ШАГ 1: Обновляем версию аватара и фона СРАЗУ после сохранения
        // Это гарантирует, что все виджеты с аватаркой и фоном обновятся
        // и загрузят новое изображение с cache-busting параметром
        // ────────────────────────────────────────────────────────────────
        _ref.read(avatarVersionProvider.notifier).bump();
        
        // ────────────────────────────────────────────────────────────────
        // ШАГ 2: Обновляем данные профиля в шапке (включая очистку кэша)
        // Это загрузит свежие данные с сервера и очистит старый кэш
        // ────────────────────────────────────────────────────────────────
        _ref.read(profileHeaderProvider(userId).notifier).reload();
      },
    );
  }

  /// Обновление поля имени
  void updateFirstName(String value) {
    state = state.copyWith(firstName: value);
  }

  /// Обновление поля фамилии
  void updateLastName(String value) {
    state = state.copyWith(lastName: value);
  }

  /// Обновление поля никнейма
  void updateNickname(String value) {
    state = state.copyWith(nickname: value);
  }

  /// Обновление поля города
  void updateCity(String value) {
    state = state.copyWith(city: value);
  }

  /// Обновление поля роста
  void updateHeight(String value) {
    state = state.copyWith(height: value);
  }

  /// Обновление поля веса
  void updateWeight(String value) {
    state = state.copyWith(weight: value);
  }

  /// Обновление поля максимального пульса
  void updateHrMax(String value) {
    state = state.copyWith(hrMax: value);
  }

  /// Обновление даты рождения
  void updateBirthDate(DateTime? value) {
    state = state.copyWith(birthDate: value);
  }

  /// Обновление пола
  void updateGender(String value) {
    state = state.copyWith(gender: value);
  }

  /// Обновление основного вида спорта
  void updateMainSport(String value) {
    state = state.copyWith(mainSport: value);
  }

  /// Обновление фоновой картинки (байты)
  void updateBackgroundBytes(Uint8List? value) {
    // ── Для явной установки null используем прямой вызов конструктора
    if (value == null) {
      state = EditProfileState(
        firstName: state.firstName,
        lastName: state.lastName,
        nickname: state.nickname,
        city: state.city,
        height: state.height,
        weight: state.weight,
        hrMax: state.hrMax,
        birthDate: state.birthDate,
        gender: state.gender,
        mainSport: state.mainSport,
        avatarUrl: state.avatarUrl,
        avatarBytes: state.avatarBytes,
        backgroundUrl: null, // ── при удалении также очищаем URL
        backgroundBytes: null, // ── явно устанавливаем null
        loadError: state.loadError,
      );
    } else {
      state = state.copyWith(backgroundBytes: value);
    }
  }

  // ── Утилиты для парсинга JSON ──

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
      case 'ski':
      case 'skiing':
      case 'лыжи':
      case 'Лыжи':
        return 'Лыжи';
      default:
        return s;
    }
  }

  // ── Утилиты для сохранения ──

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
      if (v.contains('лыж') || v.contains('ski')) return 'Лыжи';
      return 'Бег';
    }

    final map = <String, dynamic>{
      'user_id': userId,
      'edit': true,
      'load': false,
      'name': state.firstName.trim(),
      'surname': state.lastName.trim(),
      'username': state.nickname.trim(),
      'city': state.city.trim(),
      'dateage': formatDateIsoOut(state.birthDate),
      'gender': canonGenderOut(state.gender),
      'sport': canonSportOut(state.mainSport),
      'height': _toInt(state.height),
      'weight': _toInt(state.weight),
      'pulse': _toInt(state.hrMax),
    };

    if (state.avatarBytes != null && state.avatarBytes!.isNotEmpty) {
      map['avatar_base64'] = base64Encode(state.avatarBytes!);
      map['avatar_mime'] = 'image/jpeg';
    }

    // Фоновая картинка: либо новая картинка, либо удаление
    if (state.backgroundBytes != null && state.backgroundBytes!.isNotEmpty) {
      map['background_base64'] = base64Encode(state.backgroundBytes!);
      map['background_mime'] = 'image/jpeg';
    } else if (state.backgroundUrl == null && state.backgroundBytes == null) {
      // Если backgroundUrl стал null (был удален), отправляем пустую строку для удаления
      // Это происходит только если пользователь явно удалил картинку
      map['background_base64'] = '';
    }

    return map;
  }
}

