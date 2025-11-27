// ────────────────────────────────────────────────────────────────────────────
//  FORM STATE PROVIDER
//
//  Универсальный провайдер для управления состоянием форм
//  Устраняет дублирование кода в 86+ экранах с формами
//
//  Возможности:
//  • Управление состоянием загрузки
//  • Обработка ошибок (API, сеть, валидация)
//  • Валидация полей с подсветкой ошибок
//  • Единый подход к отправке форм
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/error_handler.dart';
import 'form_state.dart';

/// Базовый Notifier для управления состоянием формы
///
/// Использование:
/// ```dart
/// final formState = ref.watch(formStateProvider);
/// final formNotifier = ref.read(formStateProvider.notifier);
///
/// // Отправка формы
/// await formNotifier.submit(() async {
///   await api.post('/endpoint', body: {...});
/// });
///
/// // Проверка состояния
/// if (formState.isLoading) {
///   return CircularProgressIndicator();
/// }
/// if (formState.error != null) {
///   return Text(formState.error!);
/// }
/// ```
class FormStateNotifier extends StateNotifier<AppFormState> {
  FormStateNotifier() : super(AppFormState.initial());

  /// Отправка формы с автоматической обработкой ошибок
  ///
  /// Параметры:
  /// • action — асинхронная функция, которая выполняет отправку формы
  /// • onSuccess — опциональный колбэк при успешной отправке
  /// • onError — опциональный колбэк при ошибке (для кастомной обработки)
  /// • clearErrorOnStart — очищать ли предыдущие ошибки при старте
  ///
  /// Пример:
  /// ```dart
  /// await formNotifier.submit(
  ///   () async {
  ///     final api = ref.read(apiServiceProvider);
  ///     await api.post('/save_form.php', body: {...});
  ///   },
  ///   onSuccess: () {
  ///     Navigator.pop(context);
  ///   },
  /// );
  /// ```
  Future<void> submit(
    Future<void> Function() action, {
    VoidCallback? onSuccess,
    void Function(dynamic error)? onError,
    bool clearErrorOnStart = true,
  }) async {
    // Защита от повторных вызовов
    if (state.isLoading || state.isSubmitting) return;

    // Начинаем загрузку
    state = AppFormState.submitting();

    try {
      // Выполняем действие
      await action();

      // Успех
      state = AppFormState.success();

      // Вызываем колбэк успеха
      onSuccess?.call();
    } catch (error) {
      // Форматируем ошибку
      final errorMessage = ErrorHandler.format(error);

      // Обновляем состояние с ошибкой
      state = AppFormState.error(errorMessage);

      // Вызываем колбэк ошибки (если есть)
      onError?.call(error);
    }
  }

  /// Отправка формы с загрузкой данных (для случаев, когда нужен отдельный
  /// флаг isLoading)
  ///
  /// Используется, когда форма сначала загружает данные, а потом отправляет
  Future<void> submitWithLoading(
    Future<void> Function() action, {
    VoidCallback? onSuccess,
    void Function(dynamic error)? onError,
  }) async {
    if (state.isLoading) return;

    state = AppFormState.loading();

    try {
      await action();
      state = AppFormState.success();
      onSuccess?.call();
    } catch (error) {
      final errorMessage = ErrorHandler.format(error);
      state = AppFormState.error(errorMessage);
      onError?.call(error);
    }
  }

  /// Установка ошибки вручную
  ///
  /// Используется для валидации на клиенте
  void setError(String error) {
    state = state.copyWith(error: error);
  }

  /// Установка ошибок полей
  ///
  /// Параметры:
  /// • fieldErrors — Map с ошибками полей (ключ - имя поля, значение - сообщение)
  ///
  /// Пример:
  /// ```dart
  /// formNotifier.setFieldErrors({
  ///   'email': 'Некорректный формат email',
  ///   'password': 'Пароль должен быть не менее 8 символов',
  /// });
  /// ```
  void setFieldErrors(Map<String, String> fieldErrors) {
    state = AppFormState.fieldErrors(fieldErrors);
  }

  /// Установка ошибки конкретного поля
  ///
  /// Параметры:
  /// • fieldName — имя поля
  /// • error — сообщение об ошибке
  void setFieldError(String fieldName, String error) {
    final updatedErrors = Map<String, String>.from(state.fieldErrors);
    updatedErrors[fieldName] = error;
    state = state.copyWith(fieldErrors: updatedErrors);
  }

  /// Очистка ошибки конкретного поля
  ///
  /// Параметры:
  /// • fieldName — имя поля для очистки
  void clearFieldError(String fieldName) {
    final updatedErrors = Map<String, String>.from(state.fieldErrors);
    updatedErrors.remove(fieldName);
    state = state.copyWith(fieldErrors: updatedErrors);
  }

  /// Очистка всех ошибок
  void clearErrors() {
    state = state.copyWith(
      error: null,
      fieldErrors: const {},
      clearError: true,
      clearFieldErrors: true,
    );
  }

  /// Очистка только общей ошибки (не ошибок полей)
  void clearGeneralError() {
    state = state.copyWith(error: null, clearError: true);
  }

  /// Сброс состояния формы в начальное
  void reset() {
    state = AppFormState.initial();
  }

  /// Установка состояния загрузки вручную
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Установка состояния отправки вручную
  void setSubmitting(bool isSubmitting) {
    state = state.copyWith(isSubmitting: isSubmitting);
  }
}

/// Провайдер для состояния формы
///
/// Использование:
/// ```dart
/// // В виджете
/// final formState = ref.watch(formStateProvider);
/// final formNotifier = ref.read(formStateProvider.notifier);
/// ```
final formStateProvider =
    StateNotifierProvider<FormStateNotifier, AppFormState>((ref) {
  return FormStateNotifier();
});

