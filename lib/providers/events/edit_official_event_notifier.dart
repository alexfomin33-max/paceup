// ────────────────────────────────────────────────────────────────────────────
//  EDIT OFFICIAL EVENT NOTIFIER
//
//  StateNotifier для управления состоянием экрана редактирования официального события
//  Возможности:
//  • Загрузка данных события
//  • Управление полями формы (activity, date, time, location, media)
//  • Сохранение изменений
//  • Удаление события
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/error_handler.dart';
import 'edit_official_event_state.dart';

class EditOfficialEventNotifier
    extends StateNotifier<EditOfficialEventState> {
  final ApiService _api;
  final AuthService _auth;
  final int eventId;

  EditOfficialEventNotifier({
    required ApiService api,
    required AuthService auth,
    required this.eventId,
  })  : _api = api,
        _auth = auth,
        super(EditOfficialEventState.initial());

  /// Загрузка данных события для редактирования
  /// Возвращает Map с текстовыми полями для заполнения контроллеров
  /// Если данные уже загружены, возвращает null (не перезагружает)
  Future<Map<String, String>?> loadEventData() async {
    // Если данные уже загружены, не перезагружаем
    if (!state.isLoadingData && state.activity != null) {
      return null;
    }

    try {
      state = state.copyWith(isLoadingData: true, error: null, clearError: true);

      final userId = await _auth.getUserId();

      if (userId == null) {
        state = state.copyWith(
          isLoadingData: false,
          error: 'Ошибка авторизации',
        );
        return null;
      }

      final data = await _api.get(
        '/update_event.php',
        queryParams: {
          'event_id': eventId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (data['success'] == true && data['event'] != null) {
        final event = data['event'] as Map<String, dynamic>;

        // Парсим данные события
        final activityStr = event['activity'] as String?;
        const allowedActivities = ['Бег', 'Велосипед', 'Плавание'];
        final parsedActivity = (activityStr != null &&
                allowedActivities.contains(activityStr))
            ? activityStr
            : null;

        // Парсим дату
        DateTime? parsedDate;
        final eventDateStr = event['event_date'] as String? ?? '';
        if (eventDateStr.isNotEmpty) {
          try {
            final parts = eventDateStr.split('.');
            if (parts.length == 3) {
              parsedDate = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          } catch (e) {
            // Игнорируем ошибку парсинга
          }
        }

        // Парсим время
        TimeOfDay? parsedTime;
        final eventTimeStr = event['event_time'] as String? ?? '';
        if (eventTimeStr.isNotEmpty) {
          try {
            final parts = eventTimeStr.split(':');
            if (parts.length >= 2) {
              parsedTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          } catch (e) {
            // Игнорируем ошибку парсинга
          }
        }

        // Парсим координаты
        LatLng? parsedLocation;
        final lat = event['latitude'] as num?;
        final lng = event['longitude'] as num?;
        if (lat != null && lng != null) {
          parsedLocation = LatLng(lat.toDouble(), lng.toDouble());
        }

        // Парсим медиа
        final logoUrl = event['logo_url'] as String?;
        final logoFilename = event['logo_filename'] as String?;
        final backgroundUrl = event['background_url'] as String?;
        final backgroundFilename = event['background_filename'] as String?;

        // Сохраняем текстовые поля для инициализации контроллеров
        final name = event['name'] as String? ?? '';
        final place = event['place'] as String? ?? '';
        final description = event['description'] as String? ?? '';
        final link = event['registration_link'] as String? ?? '';
        final templateName = event['template_name'] as String? ?? '';
        final distanceStr = event['distance'] as String? ?? '';

        state = state.copyWith(
          isLoadingData: false,
          activity: parsedActivity,
          date: parsedDate,
          time: parsedTime,
          selectedLocation: parsedLocation,
          saveTemplate: templateName.isNotEmpty,
          logoUrl: logoUrl,
          logoFilename: logoFilename,
          backgroundUrl: backgroundUrl,
          backgroundFilename: backgroundFilename,
        );

        // Возвращаем текстовые поля для заполнения контроллеров
        return {
          'name': name,
          'place': place,
          'description': description,
          'link': link,
          'template_name': templateName,
          'distance': distanceStr,
        };
      } else {
        state = state.copyWith(
          isLoadingData: false,
          error: data['message'] as String? ??
              'Не удалось загрузить данные события',
        );
        return null;
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingData: false,
        error: ErrorHandler.format(e),
      );
      return null;
    }
  }

  /// Установка вида активности
  void setActivity(String? activity) {
    state = state.copyWith(activity: activity);
  }

  /// Установка даты
  void setDate(DateTime? date) {
    state = state.copyWith(date: date);
  }

  /// Установка времени
  void setTime(TimeOfDay? time) {
    state = state.copyWith(time: time);
  }

  /// Установка координат места
  void setLocation(LatLng? location) {
    state = state.copyWith(selectedLocation: location);
  }

  /// Установка флага сохранения шаблона
  void setSaveTemplate(bool value) {
    state = state.copyWith(saveTemplate: value);
  }

  /// Выбор логотипа
  void setLogoFile(File? file) {
    state = state.copyWith(
      logoFile: file,
      logoUrl: file != null ? null : state.logoUrl,
    );
  }

  /// Удаление логотипа
  void removeLogo() {
    state = state.copyWith(clearLogo: true);
  }

  /// Выбор фоновой картинки
  void setBackgroundFile(File? file) {
    state = state.copyWith(
      backgroundFile: file,
      backgroundUrl: file != null ? null : state.backgroundUrl,
    );
  }

  /// Удаление фоновой картинки
  void removeBackground() {
    state = state.copyWith(clearBackground: true);
  }

  /// Удаление события
  Future<bool> deleteEvent() async {
    if (state.isDeleting) return false;

    state = state.copyWith(isDeleting: true);

    try {
      final userId = await _auth.getUserId();
      if (userId == null) {
        state = state.copyWith(
          isDeleting: false,
          error: 'Пользователь не авторизован',
        );
        return false;
      }

      final data = await _api.post(
        '/delete_event.php',
        body: {'event_id': eventId, 'user_id': userId},
      );

      if (data['success'] == true) {
        state = state.copyWith(isDeleting: false);
        return true;
      } else {
        state = state.copyWith(
          isDeleting: false,
          error: data['message'] as String? ?? 'Ошибка при удалении события',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        error: ErrorHandler.format(e),
      );
      return false;
    }
  }
}

