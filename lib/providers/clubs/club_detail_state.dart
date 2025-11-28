// ────────────────────────────────────────────────────────────────────────────
//  CLUB DETAIL STATE
//
//  Модель состояния для экрана детальной информации о клубе
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Состояние экрана детальной информации о клубе
@immutable
class ClubDetailState {
  /// Данные клуба (JSON из API)
  final Map<String, dynamic>? clubData;

  /// Идет ли загрузка данных
  final bool isLoading;

  /// Ошибка загрузки (если есть)
  final String? error;

  /// Права на редактирование (только создатель может редактировать)
  final bool canEdit;

  /// Является ли текущий пользователь участником клуба
  final bool isMember;

  /// Подана ли заявка (для закрытых клубов)
  final bool isRequest;

  /// Идет ли процесс вступления/выхода из клуба
  final bool isJoining;

  /// Текущая вкладка (0 — Фото, 1 — Участники, 2 — Статистика, 3 — Зал славы)
  final int tab;

  const ClubDetailState({
    this.clubData,
    this.isLoading = true,
    this.error,
    this.canEdit = false,
    this.isMember = false,
    this.isRequest = false,
    this.isJoining = false,
    this.tab = 0,
  });

  /// Начальное состояние
  static ClubDetailState initial() => const ClubDetailState();

  /// Копирование состояния с обновлением полей
  ClubDetailState copyWith({
    Map<String, dynamic>? clubData,
    bool? isLoading,
    String? error,
    bool? canEdit,
    bool? isMember,
    bool? isRequest,
    bool? isJoining,
    int? tab,
    bool clearError = false,
  }) {
    return ClubDetailState(
      clubData: clubData ?? this.clubData,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      canEdit: canEdit ?? this.canEdit,
      isMember: isMember ?? this.isMember,
      isRequest: isRequest ?? this.isRequest,
      isJoining: isJoining ?? this.isJoining,
      tab: tab ?? this.tab,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClubDetailState &&
          runtimeType == other.runtimeType &&
          mapEquals(clubData, other.clubData) &&
          isLoading == other.isLoading &&
          error == other.error &&
          canEdit == other.canEdit &&
          isMember == other.isMember &&
          isRequest == other.isRequest &&
          isJoining == other.isJoining &&
          tab == other.tab;

  @override
  int get hashCode => Object.hash(
    clubData,
    isLoading,
    error,
    canEdit,
    isMember,
    isRequest,
    isJoining,
    tab,
  );
}
