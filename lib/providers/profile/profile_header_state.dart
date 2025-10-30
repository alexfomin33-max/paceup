// ────────────────────────────────────────────────────────────────────────────
//  PROFILE HEADER STATE
//
//  Модель состояния для header'а профиля пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../../models/user_profile_header.dart';

/// Состояние header'а профиля
@immutable
class ProfileHeaderState {
  /// Данные профиля
  final UserProfileHeader? profile;

  /// Идет ли загрузка
  final bool isLoading;

  /// Ошибка загрузки (если есть)
  final String? error;

  const ProfileHeaderState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  /// Начальное состояние (загрузка)
  factory ProfileHeaderState.initial() =>
      const ProfileHeaderState(profile: null, isLoading: true);

  /// Состояние загрузки
  ProfileHeaderState copyWith({
    UserProfileHeader? profile,
    bool? isLoading,
    String? error,
  }) {
    return ProfileHeaderState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileHeaderState &&
          runtimeType == other.runtimeType &&
          profile == other.profile &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode =>
      Object.hash(profile, isLoading, error);
}
