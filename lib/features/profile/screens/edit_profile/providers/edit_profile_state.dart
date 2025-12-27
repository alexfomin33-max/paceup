// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE STATE
//
//  Модель состояния для экрана редактирования профиля
// ────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Состояние экрана редактирования профиля
@immutable
class EditProfileState {
  /// Личная информация
  final String firstName;
  final String lastName;
  final String nickname;
  final String city;

  /// Физические параметры
  final String height;
  final String weight;
  final String hrMax;

  /// Дополнительная информация
  final DateTime? birthDate;
  final String gender;
  final String mainSport;

  /// Аватар
  final String? avatarUrl;
  final Uint8List? avatarBytes;

  /// Фоновая картинка
  final String? backgroundUrl;
  final Uint8List? backgroundBytes;

  /// Ошибка загрузки
  final String? loadError;

  const EditProfileState({
    this.firstName = '',
    this.lastName = '',
    this.nickname = '',
    this.city = '',
    this.height = '',
    this.weight = '',
    this.hrMax = '',
    this.birthDate,
    this.gender = '',
    this.mainSport = '',
    this.avatarUrl,
    this.avatarBytes,
    this.backgroundUrl,
    this.backgroundBytes,
    this.loadError,
  });

  /// Начальное состояние
  factory EditProfileState.initial() {
    return const EditProfileState();
  }

  /// Копия с обновленными полями
  EditProfileState copyWith({
    String? firstName,
    String? lastName,
    String? nickname,
    String? city,
    String? height,
    String? weight,
    String? hrMax,
    DateTime? birthDate,
    String? gender,
    String? mainSport,
    String? avatarUrl,
    Uint8List? avatarBytes,
    String? backgroundUrl,
    Uint8List? backgroundBytes,
    String? loadError,
  }) {
    return EditProfileState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      nickname: nickname ?? this.nickname,
      city: city ?? this.city,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      hrMax: hrMax ?? this.hrMax,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      mainSport: mainSport ?? this.mainSport,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      backgroundBytes: backgroundBytes ?? this.backgroundBytes,
      loadError: loadError ?? this.loadError,
    );
  }
}

