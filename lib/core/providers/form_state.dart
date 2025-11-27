// ────────────────────────────────────────────────────────────────────────────
//  FORM STATE
//
//  Модель состояния для управления формами
//  Универсальное состояние для всех форм в приложении
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Состояние формы
///
/// Используется для управления состоянием загрузки, ошибок и валидации
/// во всех формах приложения
@immutable
class AppFormState {
  /// Идет ли загрузка/отправка формы
  final bool isLoading;

  /// Идет ли отправка формы (отдельный флаг для случаев, когда нужна
  /// отдельная логика для отправки и загрузки)
  final bool isSubmitting;

  /// Общее сообщение об ошибке (для отображения под формой)
  final String? error;

  /// Ошибки конкретных полей (ключ - имя поля, значение - сообщение)
  /// Используется для подсветки конкретных полей
  final Map<String, String> fieldErrors;

  /// Флаг успешной отправки формы
  final bool isSuccess;

  const AppFormState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.fieldErrors = const {},
    this.isSuccess = false,
  });

  /// Начальное состояние (форма готова к заполнению)
  factory AppFormState.initial() => const AppFormState(
    isLoading: false,
    isSubmitting: false,
    error: null,
    fieldErrors: {},
    isSuccess: false,
  );

  /// Состояние загрузки
  factory AppFormState.loading() => const AppFormState(
    isLoading: true,
    isSubmitting: false,
    error: null,
    fieldErrors: {},
    isSuccess: false,
  );

  /// Состояние отправки
  factory AppFormState.submitting() => const AppFormState(
    isLoading: false,
    isSubmitting: true,
    error: null,
    fieldErrors: {},
    isSuccess: false,
  );

  /// Состояние успеха
  factory AppFormState.success() => const AppFormState(
    isLoading: false,
    isSubmitting: false,
    error: null,
    fieldErrors: {},
    isSuccess: true,
  );

  /// Состояние с ошибкой
  factory AppFormState.error(String error) => AppFormState(
    isLoading: false,
    isSubmitting: false,
    error: error,
    fieldErrors: const {},
    isSuccess: false,
  );

  /// Состояние с ошибками полей
  factory AppFormState.fieldErrors(Map<String, String> fieldErrors) =>
      AppFormState(
        isLoading: false,
        isSubmitting: false,
        error: null,
        fieldErrors: fieldErrors,
        isSuccess: false,
      );

  /// Создает копию с обновленными полями
  AppFormState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    Map<String, String>? fieldErrors,
    bool? isSuccess,
    bool clearError = false,
    bool clearFieldErrors = false,
  }) {
    return AppFormState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      fieldErrors: clearFieldErrors
          ? const {}
          : (fieldErrors ?? this.fieldErrors),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  /// Проверяет, есть ли ошибки (общие или в полях)
  bool get hasErrors => error != null || fieldErrors.isNotEmpty;

  /// Проверяет, можно ли отправить форму (нет загрузки и нет ошибок)
  bool get canSubmit => !isLoading && !isSubmitting && !hasErrors;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFormState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          isSubmitting == other.isSubmitting &&
          error == other.error &&
          mapEquals(fieldErrors, other.fieldErrors) &&
          isSuccess == other.isSuccess;

  @override
  int get hashCode =>
      Object.hash(isLoading, isSubmitting, error, fieldErrors, isSuccess);
}
