// ────────────────────────────────────────────────────────────────────────────
//  EDIT EVENT STATE
//
//  Модель состояния для экрана редактирования события
// ────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Состояние экрана редактирования события
@immutable
class EditEventState {
  /// Идет ли загрузка данных события
  final bool isLoadingData;

  /// Идет ли удаление события
  final bool isDeleting;

  /// Ошибка (если есть)
  final String? error;

  /// Список клубов пользователя
  final List<String> clubs;

  /// Выбранный клуб
  final String? selectedClub;

  /// Вид активности ('Бег', 'Велосипед', 'Плавание')
  final String? activity;

  /// Дата события
  final DateTime? date;

  /// Время события
  final TimeOfDay? time;

  /// Координаты выбранного места
  final LatLng? selectedLocation;

  /// Флаг создания из клуба
  final bool createFromClub;

  /// Флаг сохранения шаблона
  final bool saveTemplate;

  /// Логотип (новый файл)
  final File? logoFile;

  /// URL существующего логотипа
  final String? logoUrl;

  /// Имя файла существующего логотипа
  final String? logoFilename;

  /// Фотографии (новые файлы)
  final List<File?> photos;

  /// URL существующих фотографий
  final List<String> photoUrls;

  /// Имена файлов существующих фотографий
  final List<String> photoFilenames;

  const EditEventState({
    this.isLoadingData = true,
    this.isDeleting = false,
    this.error,
    this.clubs = const [],
    this.selectedClub,
    this.activity,
    this.date,
    this.time,
    this.selectedLocation,
    this.createFromClub = false,
    this.saveTemplate = false,
    this.logoFile,
    this.logoUrl,
    this.logoFilename,
    this.photos = const [null, null, null],
    this.photoUrls = const ['', '', ''],
    this.photoFilenames = const ['', '', ''],
  });

  /// Начальное состояние
  static EditEventState initial() => const EditEventState();

  /// Копирование состояния с обновлением полей
  EditEventState copyWith({
    bool? isLoadingData,
    bool? isDeleting,
    String? error,
    List<String>? clubs,
    String? selectedClub,
    String? activity,
    DateTime? date,
    TimeOfDay? time,
    LatLng? selectedLocation,
    bool? createFromClub,
    bool? saveTemplate,
    File? logoFile,
    String? logoUrl,
    String? logoFilename,
    List<File?>? photos,
    List<String>? photoUrls,
    List<String>? photoFilenames,
    bool clearError = false,
    bool clearLogo = false,
    bool clearPhoto = false,
    int? clearPhotoIndex,
  }) {
    return EditEventState(
      isLoadingData: isLoadingData ?? this.isLoadingData,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      clubs: clubs ?? this.clubs,
      selectedClub: selectedClub ?? this.selectedClub,
      activity: activity ?? this.activity,
      date: date ?? this.date,
      time: time ?? this.time,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      createFromClub: createFromClub ?? this.createFromClub,
      saveTemplate: saveTemplate ?? this.saveTemplate,
      logoFile: clearLogo ? null : (logoFile ?? this.logoFile),
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      logoFilename: clearLogo ? null : (logoFilename ?? this.logoFilename),
      photos: () {
        if (clearPhoto) return [null, null, null];
        if (clearPhotoIndex != null) {
          final updated = List<File?>.from(photos ?? this.photos);
          updated[clearPhotoIndex] = null;
          return updated;
        }
        return photos ?? this.photos;
      }(),
      photoUrls: () {
        if (clearPhoto) return ['', '', ''];
        if (clearPhotoIndex != null) {
          final updated = List<String>.from(photoUrls ?? this.photoUrls);
          updated[clearPhotoIndex] = '';
          return updated;
        }
        return photoUrls ?? this.photoUrls;
      }(),
      photoFilenames: () {
        if (clearPhoto) return ['', '', ''];
        if (clearPhotoIndex != null) {
          final updated = List<String>.from(
            photoFilenames ?? this.photoFilenames,
          );
          updated[clearPhotoIndex] = '';
          return updated;
        }
        return photoFilenames ?? this.photoFilenames;
      }(),
    );
  }
}
