// ────────────────────────────────────────────────────────────────────────────
//  EDIT EVENT NOTIFIER
//
//  StateNotifier для управления состоянием экрана редактирования события
//  Возможности:
//  • Загрузка данных события
//  • Загрузка списка клубов пользователя
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
import 'edit_event_state.dart';

class EditEventNotifier extends StateNotifier<EditEventState> {
  final ApiService _api;
  final AuthService _auth;
  final int eventId;

  EditEventNotifier({
    required ApiService api,
    required AuthService auth,
    required this.eventId,
  })  : _api = api,
        _auth = auth,
        super(EditEventState.initial());

  /// Загрузка списка клубов пользователя
  Future<void> loadUserClubs() async {
    try {
      final userId = await _auth.getUserId();

      if (userId == null) {
        state = state.copyWith(clubs: []);
        return;
      }

      final data = await _api.get(
        '/get_user_clubs.php',
        queryParams: {'user_id': userId.toString()},
      );

      if (data['success'] == true && data['clubs'] != null) {
        final clubsList = data['clubs'] as List<dynamic>;
        state = state.copyWith(
          clubs: clubsList.map((c) => c.toString()).toList(),
        );
      } else {
        state = state.copyWith(clubs: []);
      }
    } catch (e) {
      state = state.copyWith(clubs: []);
    }
  }

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

        final clubNameStr = event['club_name'] as String? ?? '';
        final parsedCreateFromClub = clubNameStr.isNotEmpty;

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

        final photosList = event['photos'] as List<dynamic>? ?? [];
        final parsedPhotoUrls = ['', '', ''];
        final parsedPhotoFilenames = ['', '', ''];
        for (int i = 0; i < 3 && i < photosList.length; i++) {
          final photo = photosList[i] as Map<String, dynamic>?;
          if (photo != null) {
            parsedPhotoUrls[i] = photo['url'] as String? ?? '';
            parsedPhotoFilenames[i] = photo['filename'] as String? ?? '';
          }
        }

        // Определяем selectedClub
        String? parsedSelectedClub;
        if (parsedCreateFromClub) {
          // Проверим после загрузки клубов
          parsedSelectedClub = clubNameStr;
        }

        // Сохраняем текстовые поля для инициализации контроллеров
        final name = event['name'] as String? ?? '';
        final place = event['place'] as String? ?? '';
        final description = event['description'] as String? ?? '';
        final clubName = event['club_name'] as String? ?? '';
        final templateName = event['template_name'] as String? ?? '';

        state = state.copyWith(
          isLoadingData: false,
          activity: parsedActivity,
          date: parsedDate,
          time: parsedTime,
          selectedLocation: parsedLocation,
          createFromClub: parsedCreateFromClub,
          selectedClub: parsedSelectedClub,
          saveTemplate: templateName.isNotEmpty,
          logoUrl: logoUrl,
          logoFilename: logoFilename,
          photoUrls: parsedPhotoUrls,
          photoFilenames: parsedPhotoFilenames,
        );

        // Возвращаем текстовые поля для заполнения контроллеров
        return {
          'name': name,
          'place': place,
          'description': description,
          'club_name': clubName,
          'template_name': templateName,
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

  /// Установка выбранного клуба
  void setSelectedClub(String? club) {
    state = state.copyWith(selectedClub: club);
  }

  /// Установка флага создания из клуба
  void setCreateFromClub(bool value) {
    state = state.copyWith(createFromClub: value);
  }

  /// Установка флага сохранения шаблона
  void setSaveTemplate(bool value) {
    state = state.copyWith(saveTemplate: value);
  }

  /// Выбор логотипа
  void setLogoFile(File? file) {
    state = state.copyWith(
      logoFile: file,
      logoUrl: file != null ? null : state.logoUrl, // Сбрасываем URL при выборе нового файла
    );
  }

  /// Удаление логотипа
  void removeLogo() {
    state = state.copyWith(clearLogo: true);
  }

  /// Выбор фотографии
  void setPhotoFile(int index, File? file) {
    if (index < 0 || index >= 3) return;
    final updatedPhotos = List<File?>.from(state.photos);
    final updatedUrls = List<String>.from(state.photoUrls);
    final updatedFilenames = List<String>.from(state.photoFilenames);

    updatedPhotos[index] = file;
    if (file != null) {
      updatedUrls[index] = ''; // Сбрасываем URL при выборе нового файла
      updatedFilenames[index] = '';
    }

    state = state.copyWith(
      photos: updatedPhotos,
      photoUrls: updatedUrls,
      photoFilenames: updatedFilenames,
    );
  }

  /// Удаление фотографии
  void removePhoto(int index) {
    if (index < 0 || index >= 3) return;
    state = state.copyWith(clearPhotoIndex: index);
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

